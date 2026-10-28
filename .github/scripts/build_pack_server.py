#!/usr/bin/env python3
"""Build and reopen packs through RPFM 5.3's MCP/server API v2."""
import json
import os
from pathlib import Path
import time
import urllib.request


def decode_response(raw):
    text = raw.decode("utf-8")
    if text.lstrip().startswith("{"):
        return json.loads(text)
    for event in text.replace("\r\n", "\n").split("\n\n"):
        data = "\n".join(line[5:].lstrip() for line in event.splitlines()
                         if line.startswith("data:"))
        if data:
            value = json.loads(data)
            if "result" in value or "error" in value:
                return value
    raise RuntimeError("No JSON-RPC result in response")


class Client:
    def __init__(self, base):
        self.base = base.rstrip("/")
        self.session = None
        self.protocol = None
        self.counter = 0

    def request(self, method, params=None, notification=False):
        message = {"jsonrpc": "2.0", "method": method}
        if params is not None:
            message["params"] = params
        if not notification:
            self.counter += 1
            message["id"] = self.counter
        headers = {"Content-Type": "application/json",
                   "Accept": "application/json, text/event-stream"}
        if self.session:
            headers["Mcp-Session-Id"] = self.session
        if self.protocol:
            headers["MCP-Protocol-Version"] = self.protocol
        request = urllib.request.Request(self.base + "/mcp",
                                         data=json.dumps(message).encode(),
                                         headers=headers, method="POST")
        with urllib.request.urlopen(request, timeout=90) as response:
            self.session = response.headers.get("Mcp-Session-Id", self.session)
            raw = response.read()
        if notification:
            return None
        result = decode_response(raw)
        if "error" in result:
            raise RuntimeError(result["error"])
        return result["result"]

    def tool(self, name, arguments=None):
        result = self.request("tools/call", {"name": name,
                                             "arguments": arguments or {}})
        if result.get("isError"):
            raise RuntimeError(f"{name}: {result}")
        if "structuredContent" in result:
            return result["structuredContent"]
        for block in result.get("content", []):
            if block.get("type") == "text":
                try:
                    return json.loads(block["text"])
                except json.JSONDecodeError:
                    continue
        raise RuntimeError(f"{name}: No structured tool result")

    def job(self, name, arguments=None, timeout=180):
        deadline = time.monotonic() + timeout
        status = self.tool(name, arguments)
        while status["state"] in {"queued", "running"}:
            remaining = deadline - time.monotonic()
            if remaining <= 0:
                raise RuntimeError(f"{name}: Job timed out: {status}")
            status = self.tool("wait_for_job", {
                "job": status["job"],
                "timeout_secs": min(30, max(1, int(remaining)))})
        if status["state"] != "finished":
            raise RuntimeError(f"{name}: Job did not finish successfully: {status}")
        return status["result"]


def select_files():
    import glob
    included, excluded = set(), set()
    for pattern in os.environ["PACK_PATHS"].split(os.environ["PACK_SEPARATOR"]):
        pattern = pattern.strip()
        if not pattern:
            continue
        exclude = pattern.startswith("!")
        for match in glob.glob(pattern[1:] if exclude else pattern, recursive=True):
            path = Path(match)
            if path.is_file() and not path.is_absolute() and ".." not in path.parts:
                (excluded if exclude else included).add(path.as_posix())
    files = sorted(included - excluded)
    if not files:
        raise RuntimeError("No game files matched the selected patterns")
    return files


def pack_destination(path):
    if path.endswith(".tsv"):
        lines = Path(path).read_text(encoding="utf-8-sig").splitlines()
        return lines[1].split("\t")[0].split(";")[2]
    return path


def verify_pack(client, key, expected):
    """Check every reopened path, including inventories larger than one API page."""
    entries = []
    while True:
        page = client.tool("list_files", {
            "source": {"pack": key}, "offset": len(entries), "limit": 500})
        entries.extend(page["files"])
        if len(entries) >= page["total"]:
            break
        if not page["files"]:
            raise RuntimeError("RPFM returned an incomplete file listing")
    paths = [entry["path"] for entry in entries]
    if len(paths) != len(expected) or set(paths) != set(expected):
        raise RuntimeError("Saved pack inventory differs from selection")
    tables = [entry for entry in entries
              if entry["path"].startswith("db/") or entry["path"].endswith(".loc")]
    for entry in tables:
        # This also rejects TSV imports silently falling back to plain text.
        expected_type = "DB" if entry["path"].startswith("db/") else "Loc"
        if entry["file_type"] != expected_type:
            raise RuntimeError(f"Expected {expected_type}: {entry}")
        client.tool("table_info", {
            "file": {"source": {"pack": key}, "path": entry["path"]}})
    return len(tables)


def build_pack(client, files, output, container_root):
    expected = [pack_destination(path) for path in files]
    if len(expected) != len(set(expected)):
        raise RuntimeError("Duplicate pack destination")
    key = client.tool("new_pack", {"name": output.name})["key"]
    try:
        for start in range(0, len(files), 64):
            batch = files[start:start + 64]
            imported = client.tool("add_files_from_disk", {
                "pack": key, "paths": [container_root + path for path in batch],
                "pack_paths": batch})
            if imported.get("error") or imported.get("not_added"):
                raise RuntimeError(f"RPFM import failed: {imported}")
            wanted = expected[start:start + len(batch)]
            if (len(imported["added"]) != len(wanted)
                    or set(imported["added"]) != set(wanted)):
                raise RuntimeError("RPFM did not import the expected native paths")
        container_output = container_root + output.as_posix()
        client.tool("save_pack", {"pack": key, "path": container_output})
        with output.open("rb") as stream:
            if not stream.read(4).startswith(b"PFH"):
                raise RuntimeError("Missing pack header")
        client.tool("close_pack", {"pack": key})
        key = None
        reopened = client.tool("open_pack", {
            "paths": [container_output], "lazy_loading": False})
        key = reopened["key"]
        if reopened["file_count"] != len(expected):
            raise RuntimeError("Saved pack file count differs from selection")
        return verify_pack(client, key, expected)
    finally:
        if key is not None:
            client.tool("close_pack", {"pack": key})


def main():
    source_root = Path(os.environ.get("PACK_SOURCE_ROOT", "."))
    if source_root.is_absolute() or ".." in source_root.parts:
        raise RuntimeError("PACK_SOURCE_ROOT must stay inside the checkout")
    container_root = "/work/" + (source_root.as_posix().rstrip("/") + "/"
                                 if source_root != Path(".") else "")
    os.chdir(source_root)
    files = select_files()
    output = Path(os.environ["PACKFILE"])
    if output.name != str(output):
        raise RuntimeError("PACKFILE must be a filename")
    base = os.environ["RPFM_URL"]
    expected_version = os.environ["RPFM_VERSION"]
    with urllib.request.urlopen(base + "/version", timeout=10) as response:
        version = json.load(response)
    if version["version"] != expected_version:
        raise RuntimeError(f"Expected RPFM {expected_version}: {version}")
    client = Client(base)
    initialized = client.request("initialize", {
        "protocolVersion": "2025-03-26", "capabilities": {},
        "clientInfo": {"name": "arkhan-pack-builder", "version": "2.0"}})
    client.protocol = initialized["protocolVersion"]
    client.request("notifications/initialized", notification=True)
    status = client.job("set_game", {
        "game": os.environ["PACK_GAME"], "rebuild_dependencies": False})
    if status["game"] != os.environ["PACK_GAME"] or not status["schema_loaded"]:
        raise RuntimeError(f"Game schema failed to load: {status}")
    tables = build_pack(client, files, output, container_root)
    summary = (f"Built and reopened {output} with RPFM {version['version']} "
               f"(API v2): {len(files)} files, {tables} DB/LOC files decoded.")
    print(summary)
    with open(os.environ["GITHUB_STEP_SUMMARY"], "a", encoding="utf-8") as stream:
        stream.write(summary + "\n")


if __name__ == "__main__":
    main()
