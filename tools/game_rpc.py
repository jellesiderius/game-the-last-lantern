"""Send a local GDScript file to the already-running Godot MCP interaction server."""
import json
from pathlib import Path
import socket
import sys

code = Path(sys.argv[1]).read_text() if len(sys.argv) > 1 else sys.stdin.read()
request = {"id": 1, "command": "eval", "params": {"code": code}}
with socket.create_connection(("127.0.0.1", 9090), timeout=10) as connection:
    connection.sendall((json.dumps(request) + "\n").encode())
    data = b""
    while b"\n" not in data:
        data += connection.recv(1024 * 1024)
result = json.loads(data.split(b"\n")[0])
print(json.dumps(result, indent=2))
sys.exit(0 if result.get("success") else 1)
