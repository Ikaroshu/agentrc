#!/usr/bin/env python3
"""Add Radar's icons to the four MesloLGS NF faces; keep their existing glyphs."""

import argparse
from pathlib import Path

from fontTools.ttLib import TTFont
from fontTools.ttLib.scaleUpem import scale_upem


def build_font(source: Path, icons_path: Path, output: Path, style: str) -> None:
    base = TTFont(source)
    icons = TTFont(icons_path)
    scale_upem(icons, base['head'].unitsPerEm)
    cmap = base.getBestCmap()
    width = base['hmtx'][cmap[ord('A')]][0]
    for codepoint, name in icons.getBestCmap().items():
        glyph = f'herdr.{name}'
        base['glyf'][glyph] = icons['glyf'][name]
        base['hmtx'][glyph] = (width, icons['hmtx'][name][1])
        for table in base['cmap'].tables:
            if table.isUnicode():
                table.cmap[codepoint] = glyph
    family = 'MesloLGS NF Herdr'
    names = {
        1: family,
        3: f'{family} {style}; {source.name}; {icons_path.name}',
        4: f'{family} {style}',
        6: f'MesloLGSNFHerdr-{style.replace(" ", "")}',
        16: family,
    }
    for record in base['name'].names:
        if record.nameID in names:
            record.string = names[record.nameID].encode(record.getEncoding())
    base.save(output)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('meslo_dir', type=Path)
    parser.add_argument('radar_icons', type=Path)
    parser.add_argument('output_dir', type=Path)
    args = parser.parse_args()
    args.output_dir.mkdir(parents=True, exist_ok=True)
    for style in ('Regular', 'Bold', 'Italic', 'Bold Italic'):
        destination = args.output_dir / f'MesloLGSNFHerdr-{style.replace(" ", "")}.ttf'
        build_font(args.meslo_dir / f'MesloLGS NF {style}.ttf', args.radar_icons, destination, style)
        print(destination)


if __name__ == '__main__':
    main()
