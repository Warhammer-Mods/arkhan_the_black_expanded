#!/usr/bin/env python3
"""Check HTTP, MCP negotiation, schemas and basic pack lifecycle using stdlib."""
import json
import os
from pathlib import Path
import tempfile
import time
import urllib.error
import urllib.request


def decode_response(raw):
    text = raw.decode("utf-8")
    if text.lstrip().startswith("{"):
        return json.loads(text)
    # Streamable HTTP may return JSON-RPC in Server-Sent Events.
    for event in text.replace("\r\n", "\n").split("\n\n"):
        data = "\n".join(line[5:].lstrip() for line in event.splitlines()
                         if line.startswith("data:"))
        if data:
            value = json.loads(data)
            if "result" in value or "error" in value:
                return value
    raise AssertionError("No JSON-RPC result in response")


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
            raise AssertionError(result["error"])
        return result["result"]

    def tool(self, name, arguments=None):
        result = self.request("tools/call", {"name": name,
                                             "arguments": arguments or {}})
        if result.get("isError"):
            raise AssertionError(f"{name}: {result}")
        # RPFM can wrap an IPC Error inside an otherwise successful MCP result.
        for block in result.get("content", []):
            if block.get("type") == "text":
                try:
                    value = json.loads(block["text"])
                except json.JSONDecodeError:
                    continue
                if isinstance(value, dict) and ("Error" in value or "error" in value):
                    raise AssertionError(f"{name}: {value}")
        return result


def unpack(result):
    for block in result.get("content", []):
        if block.get("type") == "text":
            return json.loads(block["text"])
    raise RuntimeError("RPFM returned no structured text response")


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


def main():
    source_root = Path(os.environ.get("PACK_SOURCE_ROOT", "."))
    if source_root.is_absolute() or ".." in source_root.parts:
        raise RuntimeError("PACK_SOURCE_ROOT must stay inside the checkout")
    container_root = "/work/" + (source_root.as_posix().rstrip("/") + "/" if source_root != Path(".") else "")
    os.chdir(source_root)
    files = select_files()
    expected, tables = [], []
    for path in files:
        target = path
        if path.endswith(".tsv"):
            lines = Path(path).read_text(encoding="utf-8-sig").splitlines()
            target = lines[1].split("\t")[0].split(";")[2]
            tables.append(target)
        if target in expected:
            raise RuntimeError(f"Duplicate pack destination: {target}")
        expected.append(target)
    output = Path(os.environ["PACKFILE"])
    if output.name != str(output):
        raise RuntimeError("PACKFILE must be a filename")
    base = os.environ["RPFM_URL"]
    with urllib.request.urlopen(base + "/version", timeout=10) as response:
        version = json.load(response)
    if version["version"] != "5.1.1":
        raise RuntimeError(f"Expected RPFM 5.1.1: {version}")
    client = Client(base)
    initialized = client.request("initialize", {
        "protocolVersion": "2025-03-26", "capabilities": {},
        "clientInfo": {"name": "arkhan-pack-builder", "version": "1.0"}})
    client.protocol = initialized["protocolVersion"]
    client.request("notifications/initialized", notification=True)
    client.tool("set_game_selected", {
        "game_name": os.environ["PACK_GAME"], "rebuild_dependencies": False})
    key = unpack(client.tool("new_pack"))["String"]
    for start in range(0, len(files), 64):
        batch = files[start:start + 64]
        result = unpack(client.tool("add_packed_files", {
            "pack_key": key,
            "source_paths": [container_root + path for path in batch],
            "destination_paths": json.dumps([{"File": path} for path in batch])}))
        added, error = result["VecContainerPathOptionString"]
        if error:
            raise RuntimeError(error)
        if len(added) != len(batch):
            raise RuntimeError("RPFM did not import every selected file")
    container_output = container_root + str(output)
    client.tool("save_pack_as", {"pack_key": key, "path": container_output})
    if not output.read_bytes().startswith(b"PFH"):
        raise RuntimeError("Missing pack header")
    client.tool("close_all_packs")
    client.tool("open_packfiles", {"paths": [container_output]})
    opened = unpack(client.tool("list_open_packs"))["VecStringContainerInfo"]
    if len(opened) != 1:
        raise RuntimeError("Expected one reopened pack")
    key = opened[0][0]
    info = unpack(client.tool("open_pack_info", {"pack_key": key}))
    _, packed_files = info["ContainerInfoVecRFileInfo"]
    if len(packed_files) != len(expected):
        raise RuntimeError("Saved pack inventory count differs from selection")
    for start in range(0, len(expected), 128):
        batch = expected[start:start + 128]
        info = unpack(client.tool("get_packed_files_info", {
            "pack_key": key, "values": batch}))["VecRFileInfo"]
        if len(info) != len(batch):
            raise RuntimeError("Saved pack has missing or unexpected paths")
    # insert_file can fall back to plain TSV on conversion errors. Require
    # every exported DB/LOC to exist at its binary path and decode successfully.
    for path in tables:
        client.tool("decode_packed_file", {
            "pack_key": key, "path": path, "source": "PackFile"})
    client.tool("close_all_packs")
    summary = (f"Built and reopened {output} with RPFM 5.1.1: "
               f"{len(expected)} files, {len(tables)} DB/LOC exports decoded.")
    print(summary)
    with open(os.environ["GITHUB_STEP_SUMMARY"], "a", encoding="utf-8") as stream:
        stream.write(summary + "\n")


if __name__ == "__main__":
    main()

