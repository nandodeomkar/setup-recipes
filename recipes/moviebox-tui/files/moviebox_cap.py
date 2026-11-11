"""Run moviebox-tui with its download speed capped.

moviebox-tui (Rust, reqwest 0.12) honours HTTPS_PROXY / HTTP_PROXY. This starts
a small throttling proxy on 127.0.0.1, points the app at it, and the proxy dies
when the app exits. One shared token bucket covers every connection the app
(and any yt-dlp it spawns) opens, so the cap holds no matter how many parallel
download workers it uses.

  Cap:          MOVIEBOX_CAP env var, in MB/s (default below; 0 = no cap)
  Uncapped:     run moviebox-tui.exe directly
  Proxy only:   python moviebox_cap.py --serve PORT   (for testing)
  Log:          speedcap.log next to this file
"""
import asyncio
import os
import signal
import socket
import subprocess
import sys
import threading
import time
from urllib.parse import urlsplit

DEFAULT_CAP_MB = 1.5          # MB/s; the link gives 2.3-3.4 MB/s (~19-28 Mbps), so this leaves room for everyone else
MB = 1024 * 1024
CHUNK = 64 * 1024
RCVBUF = 512 * 1024           # fixes each upstream TCP window so the throttle bites at once
EXE = os.path.join(os.environ["LOCALAPPDATA"], "Programs", "MovieBox-Tui", "bin", "moviebox-tui.exe")
LOG = os.path.join(os.path.dirname(os.path.abspath(__file__)), "speedcap.log")


def log(msg):
    try:
        with open(LOG, "a", encoding="utf-8") as f:
            f.write(time.strftime("%Y-%m-%d %H:%M:%S ") + msg + "\n")
    except OSError:
        pass


def trim_log(limit=1_000_000, keep=200_000):
    try:
        if os.path.getsize(LOG) > limit:
            with open(LOG, "rb") as f:
                f.seek(-keep, os.SEEK_END)
                tail = f.read()
            with open(LOG, "wb") as f:
                f.write(tail[tail.find(b"\n") + 1:])
    except OSError:
        pass


class Bucket:
    """Token bucket shared by every tunnel. The lock is FIFO, so takers queue fairly."""

    def __init__(self, rate):
        self.rate = rate
        self.burst = max(CHUNK, rate / 4)
        self.tokens = self.burst
        self.stamp = time.monotonic()
        self.lock = asyncio.Lock()

    async def take(self, n):
        async with self.lock:
            now = time.monotonic()
            self.tokens = min(self.burst, self.tokens + (now - self.stamp) * self.rate)
            self.stamp = now
            self.tokens -= n
            if self.tokens < 0:
                await asyncio.sleep(-self.tokens / self.rate)


def split_hostport(target, default_port):
    if target.startswith("["):
        host, _, rest = target[1:].partition("]")
        return host, int(rest[1:]) if rest.startswith(":") else default_port
    host, sep, port = target.rpartition(":")
    return (host, int(port)) if sep else (target, default_port)


class Proxy:
    def __init__(self, rate):
        self.bucket = Bucket(rate) if rate > 0 else None
        self.down = 0
        self.tunnels = 0

    async def connect(self, host, port):
        loop = asyncio.get_running_loop()
        err = None
        for family, kind, proto, _, addr in await loop.getaddrinfo(host, port, type=socket.SOCK_STREAM):
            sock = socket.socket(family, kind, proto)
            try:
                sock.setsockopt(socket.SOL_SOCKET, socket.SO_RCVBUF, RCVBUF)
                sock.setblocking(False)
                await asyncio.wait_for(loop.sock_connect(sock, addr), 10)
                return await asyncio.open_connection(sock=sock, limit=CHUNK)
            except Exception as e:
                sock.close()
                err = e
        raise err or OSError(f"no address for {host}")

    async def pump(self, reader, writer, moved=None):
        """Copy until EOF. `moved` (a one-item list) marks the throttled, counted direction."""
        try:
            while data := await reader.read(CHUNK):
                if moved is not None:
                    if self.bucket:
                        await self.bucket.take(len(data))
                    self.down += len(data)
                    moved[0] += len(data)
                writer.write(data)
                await writer.drain()
        except (ConnectionError, OSError):
            pass

    async def handle(self, creader, cwriter):
        uwriter = None
        try:
            head = await asyncio.wait_for(creader.readuntil(b"\r\n\r\n"), 30)
            line, _, rest = head.partition(b"\r\n")
            method, target, version = line.decode("latin-1").split(" ", 2)
            if method.upper() == "CONNECT":
                host, port = split_hostport(target, 443)
                ureader, uwriter = await self.connect(host, port)
                cwriter.write(b"HTTP/1.1 200 Connection Established\r\n\r\n")
            else:
                # Plain http:// via the proxy: send the request line in origin-form.
                url = urlsplit(target)
                if url.scheme.lower() != "http" or not url.hostname:
                    raise ValueError(f"unsupported proxy request: {method} {target[:80]}")
                host, port = url.hostname, url.port or 80
                path = (url.path or "/") + ("?" + url.query if url.query else "")
                ureader, uwriter = await self.connect(host, port)
                uwriter.write(f"{method} {path} {version}\r\n".encode("latin-1") + rest)
        except Exception as e:
            try:
                cwriter.write(b"HTTP/1.1 502 Bad Gateway\r\nContent-Length: 0\r\nConnection: close\r\n\r\n")
                await cwriter.drain()
            except Exception:
                pass
            log(f"connect failed: {type(e).__name__}: {e}")
            for w in (cwriter, uwriter):
                if w:
                    w.close()
            return

        self.tunnels += 1
        start = time.monotonic()
        moved = [0]
        down = asyncio.create_task(self.pump(ureader, cwriter, moved))
        up = asyncio.create_task(self.pump(creader, uwriter))
        await asyncio.wait({down, up}, return_when=asyncio.FIRST_COMPLETED)
        for w in (cwriter, uwriter):
            w.close()
        for t in (down, up):
            t.cancel()
        self.tunnels -= 1
        got = moved[0]
        if got >= MB:
            secs = time.monotonic() - start
            log(f"closed {host}:{port}  {got / MB:.1f} MB in {secs:.0f}s  avg {got / MB / max(secs, 1e-3):.2f} MB/s")

    async def report(self, every=10):
        last = self.down
        while True:
            await asyncio.sleep(every)
            if self.down != last:
                log(f"rate {(self.down - last) / MB / every:.2f} MB/s over {self.tunnels} connection(s)")
                last = self.down


def quiet_errors(loop, context):
    """asyncio's default handler prints tracebacks to the console the TUI is drawing on.

    Peer resets are routine (Windows' proactor raises WinError 10054 from shutdown()
    when a server drops a connection), so drop those and log anything else.
    """
    exc = context.get("exception")
    if isinstance(exc, (ConnectionResetError, ConnectionAbortedError, BrokenPipeError)):
        return
    log(f"asyncio: {context.get('message')} {type(exc).__name__ if exc else ''} {exc or ''}")


def start_proxy(cap_mb, port=0):
    """Run the proxy on a background thread; returns the bound port (or None)."""
    box, ready = {}, threading.Event()

    def run():
        loop = asyncio.new_event_loop()
        asyncio.set_event_loop(loop)
        loop.set_exception_handler(quiet_errors)
        try:
            proxy = Proxy(cap_mb * MB)
            server = loop.run_until_complete(asyncio.start_server(proxy.handle, "127.0.0.1", port))
            box["port"] = server.sockets[0].getsockname()[1]
            loop.create_task(proxy.report())
        except Exception as e:
            box["error"] = e
            return
        finally:
            ready.set()
        loop.run_forever()

    threading.Thread(target=run, daemon=True).start()
    ready.wait(10)
    if "error" in box:
        log(f"proxy failed to start: {box['error']}")
    return box.get("port")


def main():
    trim_log()
    try:
        cap = float(os.environ.get("MOVIEBOX_CAP", DEFAULT_CAP_MB))
    except ValueError:
        cap = DEFAULT_CAP_MB

    if sys.argv[1:2] == ["--serve"]:
        port = start_proxy(cap, int(sys.argv[2]))
        print(f"proxy on 127.0.0.1:{port}, cap {cap} MB/s", flush=True)
        log(f"serve mode on {port}, cap {cap} MB/s")
        threading.Event().wait()

    if not os.path.isfile(EXE):
        sys.exit(f"moviebox-tui.exe not found at {EXE}")

    env = dict(os.environ)
    port = start_proxy(cap) if cap > 0 else None
    if port:
        url = f"http://127.0.0.1:{port}"
        env.update(HTTPS_PROXY=url, HTTP_PROXY=url, NO_PROXY="localhost,127.0.0.1,::1")
        env.pop("ALL_PROXY", None)
        log(f"session start, cap {cap} MB/s, proxy {port}")
    elif cap > 0:
        print("speed cap proxy failed to start - running UNCAPPED (see speedcap.log)", file=sys.stderr)
        time.sleep(3)

    # From here on the console belongs to the TUI. Anything Python still wants to
    # print goes to the log; the child inherits the real console handles regardless.
    try:
        sys.stdout = sys.stderr = open(LOG, "a", encoding="utf-8", buffering=1)
    except OSError:
        sys.stdout = sys.stderr = open(os.devnull, "w")

    # Ctrl+C belongs to the TUI; don't let it kill the proxy underneath it.
    signal.signal(signal.SIGINT, signal.SIG_IGN)
    rc = subprocess.call([EXE, *sys.argv[1:]], env=env)
    if port:
        log("session end")
    sys.exit(rc)


if __name__ == "__main__":
    main()
