import os
from datetime import date
from http.server import BaseHTTPRequestHandler, HTTPServer


def _env_int(name: str, default: int) -> int:
    value = os.environ.get(name, "").strip()
    if not value:
        return default
    try:
        return int(value)
    except ValueError:
        return default


class _Handler(BaseHTTPRequestHandler):
    server_version = "ThkTreeHostLogServer/1.0"

    def do_GET(self):
        if self.path.startswith("/health"):
            body = f"OK\nlog={self.server.current_log_path()}\n"
            data = body.encode("utf-8")
            self.send_response(200)
            self.send_header("Content-Type", "text/plain; charset=utf-8")
            self.send_header("Content-Length", str(len(data)))
            self.end_headers()
            self.wfile.write(data)
            return

        self.send_response(404)
        self.end_headers()

    def do_POST(self):
        n = int(self.headers.get("Content-Length", "0"))
        data = self.rfile.read(n) if n > 0 else b""
        log_path = self.server.current_log_path()
        os.makedirs(os.path.dirname(log_path), exist_ok=True)
        with open(log_path, "ab") as f:
            f.write(data)
        try:
            import json
            text = data.decode("utf-8")
            m = json.loads(text)
            lid = m.get("id", "")
            ts = m.get("ts", "")
            level = m.get("level", "")
            msg = m.get("msg", "")
            attrs = m.get("attrs", {})
            err = m.get("err", None)
            print(f"=== LOG [{ts}][{level}] id={lid[:10]}... ===")
            if msg:
                print(f"  msg: {msg}")
            if attrs:
                print(f"  attrs: {json.dumps(attrs, ensure_ascii=False)}")
            if err:
                print(f"  err: {err.get('msg', '')}")
                stack = err.get("stack", "")
                if stack:
                    print(f"  stack:\n{stack}")
            print("=== END LOG ===")
        except Exception:
            print(f"=== RAW POST ({len(data)} bytes) ===")
            print(data.decode("utf-8", errors="replace"), end="")
            print("=== END RAW ===")
        self.send_response(204)
        self.end_headers()

    def log_message(self, format, *args):
        return


class _Server(HTTPServer):
    def __init__(self, server_address, RequestHandlerClass, log_prefix: str):
        super().__init__(server_address, RequestHandlerClass)
        self.log_prefix = log_prefix

    def current_log_path(self) -> str:
        dir_name = os.path.dirname(self.log_prefix)
        base = os.path.basename(self.log_prefix)
        name, ext = os.path.splitext(base)
        today = date.today().isoformat()
        return os.path.join(dir_name, f"{name}-{today}{ext}")


def main() -> None:
    host = os.environ.get("THKTREE_HOST", "127.0.0.1").strip() or "127.0.0.1"
    port = _env_int("THKTREE_PORT", 8787)
    default_log_prefix = os.path.join(os.path.dirname(__file__), "thktree-host.log")
    log_prefix = os.environ.get("THKTREE_HOST_LOG", default_log_prefix).strip() or default_log_prefix

    server = _Server((host, port), _Handler, log_prefix=log_prefix)
    print(f"listening on http://{host}:{port}/health")
    print(f"log prefix: {log_prefix}")
    server.serve_forever()


if __name__ == "__main__":
    main()
