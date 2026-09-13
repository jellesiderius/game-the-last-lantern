"""Run a Python file through the existing local Cascadeur script runner."""
import argparse
import json
from pathlib import Path
import urllib.request


def run(code):
    payload = {"jsonrpc": "2.0", "id": 1, "method": "tools/call",
               "params": {"name": "run_script", "arguments": {"code": code}}}
    request = urllib.request.Request(
        "http://127.0.0.1:8765/mcp", data=json.dumps(payload).encode(),
        headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(request, timeout=180) as response:
        result = json.load(response)
    for block in result.get("result", {}).get("content", []):
        if block.get("type") == "text":
            try:
                value = json.loads(block["text"])
            except json.JSONDecodeError:
                print(block["text"])
                continue
            print(json.dumps(value, indent=2))
            if value.get("ok") is False:
                raise RuntimeError("Cascadeur script failed")
    if "error" in result or result.get("result", {}).get("isError"):
        raise RuntimeError(result)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("script", type=Path)
    args = parser.parse_args()
    run(args.script.read_text())
