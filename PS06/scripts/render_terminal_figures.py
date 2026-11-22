#!/usr/bin/env python3
"""Render the collected Linux transcript as readable terminal figures."""

from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_INPUT = ROOT / "results" / "complete_linux_output.txt"
DEFAULT_OUTPUT = ROOT / "figures"


SECTIONS = {
    "free_overview.png": [
        "FREE - BASIC",
        "FREE - HELP",
        "FREE - HUMAN READABLE",
    ],
    "free_samples.png": [
        "FREE - HUMAN READABLE",
        "FREE - FIVE SAMPLES, TWO SECONDS APART",
    ],
    "vmstat_overview.png": [
        "VMSTAT - BASIC",
        "VMSTAT - HELP",
        "VMSTAT - STATISTICS",
    ],
    "vmstat_samples.png": [
        "VMSTAT - STATISTICS",
        "VMSTAT - FIVE SAMPLES, TWO SECONDS APART",
    ],
    "swap_experiment.png": [
        "SWAP - BEFORE",
        "SWAP - BEFORE (FREE)",
        "SWAP - CREATE AND ENABLE 1 GIB FILE",
        "SWAP - AFTER INCREASE",
        "SWAP - AFTER INCREASE (FREE)",
        "SWAP - AFTER DECREASE",
    ],
}


def read_sections(path: Path) -> dict[str, list[str]]:
    sections: dict[str, list[str]] = {}
    current: str | None = None
    for line in path.read_text(encoding="utf-8", errors="replace").splitlines():
        if any(line == title for titles in SECTIONS.values() for title in titles):
            current = line
            sections.setdefault(current, [])
            continue
        if current is not None:
            sections[current].append(line)
    return sections


def font(size: int) -> ImageFont.FreeTypeFont | ImageFont.ImageFont:
    candidates = [
        Path(r"C:\Windows\Fonts\consola.ttf"),
        Path(r"C:\Windows\Fonts\cour.ttf"),
        Path("/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf"),
    ]
    for candidate in candidates:
        if candidate.exists():
            return ImageFont.truetype(str(candidate), size)
    return ImageFont.load_default()


def render(name: str, titles: list[str], sections: dict[str, list[str]], output: Path) -> None:
    title_font = font(24)
    body_font = font(18)
    line_height = 27
    margin_x = 34
    margin_y = 30
    header_height = 58
    lines: list[tuple[str, str]] = []
    for title in titles:
        lines.append(("section", title))
        for line in sections.get(title, []):
            kind = "command" if line.startswith("$ ") else "body"
            lines.append((kind, line))
        lines.append(("body", ""))

    longest = max((len(line) for _, line in lines), default=1)
    width = max(1500, min(2600, margin_x * 2 + longest * 11))
    height = max(500, margin_y * 2 + header_height + line_height * len(lines))
    image = Image.new("RGB", (width, height), "#10151b")
    draw = ImageDraw.Draw(image)
    draw.rectangle((0, 0, width, header_height), fill="#1d2733")
    draw.text((margin_x, 17), f"PS06 Linux capture  |  {name}", font=title_font, fill="#f2c14e")

    y = margin_y + header_height
    for kind, line in lines:
        if kind == "section":
            draw.text((margin_x, y), line, font=body_font, fill="#f2c14e")
        elif kind == "command":
            draw.text((margin_x, y), line, font=body_font, fill="#71d7ff")
        else:
            draw.text((margin_x, y), line, font=body_font, fill="#e1e7ef")
        y += line_height

    image.save(output, format="PNG", optimize=True)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", type=Path, default=DEFAULT_INPUT)
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    args = parser.parse_args()
    sections = read_sections(args.input)
    args.output.mkdir(parents=True, exist_ok=True)
    for name, titles in SECTIONS.items():
        render(name, titles, sections, args.output / name)
        print(f"wrote {args.output / name}")


if __name__ == "__main__":
    main()
