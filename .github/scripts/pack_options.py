"""Build safely quoted RPFM arguments from workflow glob inputs."""
import glob
import os
from pathlib import Path
import shlex

patterns = os.environ["PACK_PATHS"].split(os.environ["PACK_SEPARATOR"])
included, excluded = set(), set()
for pattern in patterns:
    pattern = pattern.strip()
    if not pattern:
        continue
    exclude = pattern.startswith("!")
    matches = glob.glob(pattern[1:] if exclude else pattern, recursive=True)
    for match in matches:
        path = Path(match)
        if path.is_file() and not path.is_absolute() and ".." not in path.parts:
            (excluded if exclude else included).add(path.as_posix())
paths = sorted(included - excluded)
if not paths:
    raise SystemExit("No game files matched the selected patterns")
if any(";" in path or "\n" in path or "\r" in path for path in paths):
    raise SystemExit("A selected path contains an unsupported RPFM separator")
arguments = " ".join("-f " + shlex.quote(f"{path};{path}") for path in paths)
with open(os.environ["GITHUB_OUTPUT"], "a", encoding="utf-8") as output:
    output.write(f"rpfm-add-paths={arguments}\n")
print(f"Selected {len(paths)} game files")
