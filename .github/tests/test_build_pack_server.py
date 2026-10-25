"""Regression checks for the documented RPFM 5.3 MCP API v2 contract."""
import importlib.util
import io
import json
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import Mock, patch

SCRIPT = Path(__file__).resolve().parents[1] / "scripts/build_pack_server.py"
spec = importlib.util.spec_from_file_location("build_pack_server", SCRIPT)
builder = importlib.util.module_from_spec(spec)
spec.loader.exec_module(builder)


class ClientTests(unittest.TestCase):
    def test_structured_content_is_used_before_display_text(self):
        client = builder.Client("http://localhost")
        client.request = Mock(return_value={
            "structuredContent": {"key": "pack-id"},
            "content": [{"type": "text", "text": "Display summary"}]})
        self.assertEqual(client.tool("new_pack"), {"key": "pack-id"})

    def test_text_fallback_and_tool_errors(self):
        client = builder.Client("http://localhost")
        client.request = Mock(return_value={"content": [
            {"type": "text", "text": "summary"},
            {"type": "text", "text": '{"key":"pack-id"}'}]})
        self.assertEqual(client.tool("new_pack"), {"key": "pack-id"})
        client.request.return_value = {"isError": True,
                                       "structuredContent": {"message": "bad table"}}
        with self.assertRaisesRegex(RuntimeError, "bad table"):
            client.tool("table_info")

    def test_queued_and_running_jobs_are_waited_for(self):
        client = builder.Client("http://localhost")
        client.tool = Mock(side_effect=[
            {"job": "job-id", "state": "queued"},
            {"job": "job-id", "state": "running"},
            {"job": "job-id", "state": "finished",
             "result": {"schema_loaded": True}}])
        self.assertEqual(client.job("set_game", {"game": "warhammer_3"}),
                         {"schema_loaded": True})
        for call in client.tool.call_args_list[1:]:
            self.assertEqual(call.args[0], "wait_for_job")
            self.assertEqual(call.args[1]["job"], "job-id")
            self.assertLessEqual(call.args[1]["timeout_secs"], 30)

    def test_finished_failed_cancelled_and_timed_out_jobs(self):
        client = builder.Client("http://localhost")
        client.tool = Mock(return_value={"state": "finished", "result": 42})
        self.assertEqual(client.job("set_game"), 42)
        for state in ("failed", "cancelled"):
            client.tool.return_value = {"state": state}
            with self.assertRaisesRegex(RuntimeError, "did not finish"):
                client.job("set_game")
        client.tool.return_value = {"job": "job-id", "state": "running"}
        with patch.object(builder.time, "monotonic", side_effect=[0, 2]):
            with self.assertRaisesRegex(RuntimeError, "timed out"):
                client.job("set_game", timeout=1)

    def test_http_session_headers_and_sse_response(self):
        class Response(io.BytesIO):
            headers = {"Mcp-Session-Id": "session-id"}

        response = Response(
            b'event: message\ndata: {"method":"notifications/progress"}\n\n'
            b'event: message\ndata: {"result":{"key":"pack-id"}}\n\n')
        client = builder.Client("http://localhost/")
        client.protocol = "2025-03-26"
        with patch.object(builder.urllib.request, "urlopen", return_value=response) as send:
            self.assertEqual(client.request("tools/call", {"name": "new_pack"}),
                             {"key": "pack-id"})
        request = send.call_args.args[0]
        self.assertEqual(request.full_url, "http://localhost/mcp")
        self.assertEqual(request.get_header("Mcp-protocol-version"), "2025-03-26")
        self.assertEqual(json.loads(request.data)["id"], 1)
        self.assertEqual(client.session, "session-id")


class DocumentedV2Server:
    """Small protocol fixture, not an RPFM encoder or live-server substitute."""
    def __init__(self, destinations, container_root="/work/"):
        self.destinations = destinations
        self.container_root = container_root
        self.entries = []
        self.calls = []
        self.partial = False
        self.fallback_tsv = False
        self.bad_table = False
        self.extra_after_reopen = False

    def tool(self, name, arguments=None):
        args = arguments or {}
        self.calls.append((name, args))
        if name == "new_pack":
            return {"key": "created-pack", "name": args["name"], "file_count": 0}
        if name == "add_files_from_disk":
            assert set(args) == {"pack", "paths", "pack_paths"}
            assert args["pack"] == "created-pack"
            assert args["paths"] == [self.container_root + p for p in args["pack_paths"]]
            added = []
            for source in args["pack_paths"]:
                path = source if self.fallback_tsv else self.destinations[source]
                kind = "DB" if path.startswith("db/") else (
                    "Loc" if path.endswith(".loc") else "Image")
                self.entries.append({"path": path, "file_type": kind})
                added.append(path)
            return {"added": added[:-1] if self.partial else added,
                    "not_added": [], "error": None}
        if name == "save_pack":
            assert args["path"].startswith(self.container_root)
            Path(args["path"][len(self.container_root):]).write_bytes(b"PFH5-fixture")
            return {"key": args["pack"], "path": args["path"]}
        if name == "close_pack":
            assert args["pack"] in {"created-pack", "reopened-pack"}
            return {}
        if name == "open_pack":
            assert args == {"paths": [self.container_root + "test.pack"],
                            "lazy_loading": False}
            if self.extra_after_reopen:
                self.entries.append({"path": "unexpected.png", "file_type": "Image"})
            return {"key": "reopened-pack", "file_count": len(self.entries)}
        if name == "list_files":
            assert args["source"] == {"pack": "reopened-pack"}
            entries = sorted(self.entries, key=lambda row: row["path"])
            offset = args["offset"]
            return {"files": entries[offset:offset + args["limit"]],
                    "folders": [], "total": len(entries)}
        if name == "table_info":
            assert args["file"]["source"] == {"pack": "reopened-pack"}
            if self.bad_table:
                raise RuntimeError("Native table failed to decode")
            return {"table_name": "fixture", "version": 0, "row_count": 1,
                    "columns": []}
        raise AssertionError(f"Unexpected/legacy API call: {name}")


class PackTests(unittest.TestCase):
    def setUp(self):
        self.previous = Path.cwd()
        self.folder = tempfile.TemporaryDirectory()
        os.chdir(self.folder.name)
        self.files = ["db/example_tables/export.tsv", "db/colours_tables/native",
                      "text/db/native.loc", "ui/campaign ui/example.png"]
        for name in self.files:
            path = Path(name)
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(b"fixture")
        Path(self.files[0]).write_text(
            "key\n#example_tables;0;db/example_tables/renamed\nvalue\n",
            encoding="utf-8")
        self.destinations = dict(zip(self.files, ["db/example_tables/renamed",
                                    *self.files[1:]]))

    def tearDown(self):
        os.chdir(self.previous)
        self.folder.cleanup()

    def test_roundtrip_uses_v2_paths_and_decodes_native_and_imported_tables(self):
        server = DocumentedV2Server(self.destinations)
        self.assertEqual(builder.build_pack(server, self.files, Path("test.pack"),
                                            "/work/"), 3)
        checked = {args["file"]["path"] for name, args in server.calls
                   if name == "table_info"}
        self.assertEqual(checked, {"db/example_tables/renamed",
                                  "db/colours_tables/native", "text/db/native.loc"})

    def test_submod_root_and_spaces_are_preserved(self):
        root = "/work/submods/example/"
        server = DocumentedV2Server(self.destinations, root)
        self.assertEqual(builder.build_pack(server, self.files, Path("test.pack"), root), 3)

    def test_partial_import_tsv_fallback_extra_file_and_decode_failure_fail(self):
        for attribute in ("partial", "fallback_tsv", "extra_after_reopen", "bad_table"):
            with self.subTest(attribute=attribute):
                server = DocumentedV2Server(self.destinations)
                setattr(server, attribute, True)
                with self.assertRaises(RuntimeError):
                    builder.build_pack(server, self.files, Path("test.pack"), "/work/")
                self.assertEqual(server.calls[-1][0], "close_pack")

    def test_large_inventories_are_paginated(self):
        files = [f"ui/image_{i}.png" for i in range(503)]
        server = DocumentedV2Server({name: name for name in files})
        self.assertEqual(builder.build_pack(server, files, Path("test.pack"), "/work/"), 0)
        offsets = [args["offset"] for name, args in server.calls if name == "list_files"]
        self.assertEqual(offsets, [0, 500])

    def test_duplicate_destinations_and_wrong_server_version_are_rejected(self):
        with self.assertRaisesRegex(RuntimeError, "Duplicate"):
            builder.build_pack(DocumentedV2Server(self.destinations),
                               [self.files[0], self.files[0]], Path("test.pack"), "/work/")
        env = {"PACK_SOURCE_ROOT": ".", "PACK_PATHS": "db/**", "PACK_SEPARATOR": " ",
               "PACKFILE": "test.pack", "RPFM_URL": "http://localhost",
               "RPFM_VERSION": "5.3.1"}
        with patch.dict(os.environ, env), patch.object(builder, "Client") as client:
            with patch.object(builder.urllib.request, "urlopen",
                              return_value=io.BytesIO(b'{"version":"5.2.0"}')):
                with self.assertRaisesRegex(RuntimeError, "Expected RPFM 5.3.1"):
                    builder.main()
            client.assert_not_called()


if __name__ == "__main__":
    unittest.main()
