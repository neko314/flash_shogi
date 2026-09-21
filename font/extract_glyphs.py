#!/usr/bin/env python3
"""
システムフォント(ヒラギノ明朝 ProN W6)から必要な漢字の輪郭を抽出し、
100x100ビューポート基準の <path> d文字列(地の文字位置/バッジ位置それぞれ)
として JSON に書き出す開発用スクリプト。CID方式のフォントでも fontTools の
cmap 解決はUnicodeで引けるため、FontForge直接操作より確実。

使い方:
  font/.venv/bin/python3 font/extract_glyphs.py
出力: font/glyph_paths.json
"""
import json
import os
import re

from fontTools.ttLib import TTFont
from fontTools.pens.svgPathPen import SVGPathPen
from fontTools.pens.transformPen import TransformPen

FONT_PATH = "/System/Library/Fonts/ヒラギノ明朝 ProN.ttc"
FONT_NUMBER = 2  # Hiragino Mincho ProN W6 (太め)

CHARS = list("歩香桂銀金角飛玉と馬龍成")

OUT_PATH = os.path.join(os.path.dirname(__file__), "glyph_paths.json")

# 100x100 ビューポート内での配置。駒との余白を減らすため、以前(46/15)より
# 大きめのサイズにしている。
MAIN_Y = 58
MAIN_SIZE = 62
BADGE_Y = 20
BADGE_SIZE = 20


def extract(tt, cmap, glyphset, ch, cy, size, units_per_em, em_center_y, rotate180):
    gname = cmap[ord(ch)]
    glyph = glyphset[gname]
    s = size / units_per_em
    # SVG座標(y下向き)に合わせて反転しつつ、指定位置(50, cy)を中心に配置する。
    # 変換: (x,y) -> (50 + s*(x-500), cy - s*(y-em_center_y))
    tx = 50 - s * 500
    ty = cy + s * em_center_y
    if rotate180:
        # FontForgeのSVG取り込みは <g transform="rotate(180 50 50)"> を
        # auto-scale計算の後に適用してしまい、後手側の座標が大きくずれる
        # 不具合を確認した(要検証で判明)。そのため実行時transformに頼らず、
        # 180°回転(x,y)->(100-x,100-y)をあらかじめ座標に合成しておく。
        transform = (-s, 0, 0, s, 100 - tx, 100 - ty)
    else:
        transform = (s, 0, 0, -s, tx, ty)
    pen = SVGPathPen(glyphset)
    tpen = TransformPen(pen, transform)
    glyph.draw(tpen)
    d = pen.getCommands()
    return re.sub(r"-?\d+\.\d+", lambda m: f"{float(m.group()):.2f}", d)


def main():
    tt = TTFont(FONT_PATH, fontNumber=FONT_NUMBER)
    units_per_em = tt["head"].unitsPerEm
    hhea = tt["hhea"]
    em_center_y = (hhea.ascent + hhea.descent) / 2
    cmap = tt.getBestCmap()
    glyphset = tt.getGlyphSet()

    result = {}
    for ch in CHARS:
        result[ch] = {
            "main": extract(tt, cmap, glyphset, ch, MAIN_Y, MAIN_SIZE, units_per_em, em_center_y, False),
            "badge": extract(tt, cmap, glyphset, ch, BADGE_Y, BADGE_SIZE, units_per_em, em_center_y, False),
            "main_gote": extract(tt, cmap, glyphset, ch, MAIN_Y, MAIN_SIZE, units_per_em, em_center_y, True),
            "badge_gote": extract(tt, cmap, glyphset, ch, BADGE_Y, BADGE_SIZE, units_per_em, em_center_y, True),
        }

    with open(OUT_PATH, "w") as f:
        json.dump(result, f, ensure_ascii=False, indent=2)
    print(f"wrote {OUT_PATH} ({len(result)} chars)")


if __name__ == "__main__":
    main()
