#!/usr/bin/env python3
"""Render the first JSON example of every docs/types/*.md with `tjuvkik preview`,
to docs/types/images/<type>-<size>.png. Run after changing an example or how a type draws.

Needs the app's command line tool on PATH (scripts/bundle.sh links it).
"""

import json
import re
import shutil
import subprocess
import sys
import tempfile
from datetime import datetime, timedelta, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
TYPES = ROOT / "docs" / "types"
OUT = TYPES / "images"
SIZES = ["1x1", "2x1", "2x2"]

# A tile title per type, as someone would name the panel.
TITLES = {
    "chart": "CPU",
    "checklist": "Release 5.3",
    "feed": "Mentions",
    "grid": "Uptime, 24h",
    "keyvalue": "Environment",
    "markdown": "On call",
    "meters": "Disk",
    "stats": "App health",
    "table": "Pods",
    "timeline": "Today",
}

# Examples with times are written for a moment on 16 Nov; the tile is drawn at the real now.
# Move every time by (now - that moment), so the example reads as written whenever it's rendered.
WRITTEN_AT = {
    "timeline": datetime(2026, 11, 16, 13, 40),
    "feed": datetime(2026, 11, 16, 13, 40, tzinfo=timezone.utc),
}

ISO = re.compile(r'"(\d{4}-\d\d-\d\dT\d\d:\d\d(?::\d\d)?(Z)?)"')
CLOCK = re.compile(r'"(from|to)": "(\d\d:\d\d)"')


def shift(text: str, written: datetime) -> str:
    now = datetime.now(written.tzinfo)
    delta = now - written

    def iso(m: re.Match) -> str:
        utc = bool(m.group(2))
        t = datetime.fromisoformat(m.group(1).replace("Z", "+00:00")) + delta
        if utc:
            return '"' + t.astimezone(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ") + '"'
        return '"' + t.strftime("%Y-%m-%dT%H:%M") + '"'

    def clock(m: re.Match) -> str:
        h, mi = map(int, m.group(2).split(":"))
        t = (datetime(2000, 1, 1, h, mi) + timedelta(seconds=delta.total_seconds() % 86400)).strftime("%H:%M")
        return f'"{m.group(1)}": "{t}"'

    return CLOCK.sub(clock, ISO.sub(iso, text))


def first_json(md: str) -> str:
    m = re.search(r"^```json\n(.*?)^```", md, re.S | re.M)
    if not m:
        raise SystemExit("no ```json example")
    return m.group(1)


def main() -> None:
    if not shutil.which("tjuvkik"):
        sys.exit("tjuvkik isn't on PATH; run scripts/bundle.sh first")
    only = set(sys.argv[1:])
    OUT.mkdir(exist_ok=True)
    with tempfile.TemporaryDirectory() as tmp:
        config = Path(tmp)
        (config / "config.jsonc").write_text('{ "theme": "dark-glass", "panels": [] }\n')
        for doc in sorted(TYPES.glob("*.md")):
            name = doc.stem
            if only and name not in only:
                continue
            example = first_json(doc.read_text())
            if name in WRITTEN_AT:
                example = shift(example, WRITTEN_AT[name])
            json.loads(example)  # fail early on a broken example
            panel = config / "panels" / name
            panel.mkdir(parents=True)
            (panel / "out.json").write_text(example)
            title = TITLES.get(name, name.title())
            (panel / "panel.jsonc").write_text(
                json.dumps({"type": name, "title": title, "command": "cat out.json", "every": "1m"}) + "\n"
            )
            for size in SIZES:
                out = OUT / f"{name}-{size}.png"
                subprocess.run(
                    ["tjuvkik", "preview", name, "--config", str(config), "--size", size, "-o", str(out)],
                    check=True,
                )


if __name__ == "__main__":
    main()
