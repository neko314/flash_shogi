#!/usr/bin/env python3
"""
システムフォント(ヒラギノ明朝 ProN W6)から必要な漢字の輪郭を抽出し、
100x100ビューポート基準の <path> d文字列(地の文字位置/バッジ位置それぞれ)
として JSON に書き出す開発用スクリプト。CID方式のフォントでも fontTools の
cmap 解決はUnicodeで引けるため、FontForge直接操作より確実。

文字ごとに実際の見た目のバウンディングボックスを測り、駒の中の「安全な
範囲」いっぱいに収まるよう個別に拡大・中央寄せする(固定サイズ・固定位置
だと、文字によって余白や重心のズレが出るため)。

使い方:
  font/.venv/bin/python3 font/extract_glyphs.py
出力: font/glyph_paths.json
"""
import json
import os
import re

from fontTools.ttLib import TTFont
from fontTools.pens.boundsPen import BoundsPen
from fontTools.pens.svgPathPen import SVGPathPen
from fontTools.pens.transformPen import TransformPen

# 明朝体は線の太さに強弱があり、小さいサイズだと潰れて読みにくかったため、
# 線の太さが均一なゴシック体に変更(視認性重視)。
FONT_PATH = "/System/Library/Fonts/ヒラギノ角ゴシック W6.ttc"
FONT_NUMBER = 0  # Hiragino Sans / Kaku Gothic ProN W6 (太め)

CHARS = list("歩香桂銀金角飛玉と馬龍成")

OUT_PATH = os.path.join(os.path.dirname(__file__), "glyph_paths.json")

# 100x100 ビューポート内で、文字を安全に収めてよい範囲(五角形の内側、
# 駒尖や縁取りに触れない余白を見込んだ領域)。地の文字は五角形の肩から下、
# バッジは五角形の尖った先端の下あたりに収める。
MAIN_BOX = (10, 25, 90, 87)   # (x0, y0, x1, y1)
BADGE_BOX = (36, 8, 64, 27)


def fit_transform(bbox, target, rotate180):
    """bbox(font単位) を target(SVG単位の矩形) いっぱいに収まるよう、
    アスペクト比を保って拡大し中央寄せする変換行列を返す。"""
    xmin, ymin, xmax, ymax = bbox
    bw, bh = xmax - xmin, ymax - ymin
    bcx, bcy = (xmin + xmax) / 2, (ymin + ymax) / 2

    tx0, ty0, tx1, ty1 = target
    tw, th = tx1 - tx0, ty1 - ty0
    tcx, tcy = (tx0 + tx1) / 2, (ty0 + ty1) / 2

    s = min(tw / bw, th / bh)

    if rotate180:
        # 180°回転(x,y)->(100-x,100-y)まで含めて合成しておく。理由は
        # 「実行時transformはFontForgeのauto-scaleとズレる」を参照
        # (generate_svg.rb 側の同種コメント)。
        return (-s, 0, 0, s, 100 - (tcx - s * bcx), 100 - (tcy + s * bcy))
    return (s, 0, 0, -s, tcx - s * bcx, tcy + s * bcy)


def extract(glyphset, gname, target, rotate180):
    bp = BoundsPen(glyphset)
    glyphset[gname].draw(bp)
    transform = fit_transform(bp.bounds, target, rotate180)

    pen = SVGPathPen(glyphset)
    tpen = TransformPen(pen, transform)
    glyphset[gname].draw(tpen)
    d = pen.getCommands()
    return re.sub(r"-?\d+\.\d+", lambda m: f"{float(m.group()):.2f}", d)


def main():
    tt = TTFont(FONT_PATH, fontNumber=FONT_NUMBER)
    cmap = tt.getBestCmap()
    glyphset = tt.getGlyphSet()

    result = {}
    for ch in CHARS:
        gname = cmap[ord(ch)]
        result[ch] = {
            "main": extract(glyphset, gname, MAIN_BOX, False),
            "badge": extract(glyphset, gname, BADGE_BOX, False),
            "main_gote": extract(glyphset, gname, MAIN_BOX, True),
            "badge_gote": extract(glyphset, gname, BADGE_BOX, True),
        }

    with open(OUT_PATH, "w") as f:
        json.dump(result, f, ensure_ascii=False, indent=2)
    print(f"wrote {OUT_PATH} ({len(result)} chars)")


if __name__ == "__main__":
    main()
