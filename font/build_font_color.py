#!/usr/bin/env python3
"""
COLR/CPAL対応のカラーPUAフォントを2段階で組み立てる。

  1段目 (FontForge, `fontforge -script` で実行):
    font/svg/*.svg            -> 各コードポイントの「フォールバック輪郭」
    font/svg_layers/*.svg     -> COLR用のレイヤーグリフ(名前付き、符号化なし)
    をすべて1つのTTFに詰め込む(色は付かない、輪郭だけ)。

  2段目 (fontTools, 通常のpython3で実行。font/.venv/bin/python3 を想定):
    1段目のTTFを読み込み、fontTools.colorLib.builder でCOLR/CPALテーブルを
    追加し、最終的なカラーフォントを書き出す。

使い方:
  fontforge -script font/build_font_color.py stage1
  font/.venv/bin/python3 font/build_font_color.py stage2
"""
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
SVG_DIR = os.path.join(HERE, "svg")
LAYER_DIR = os.path.join(HERE, "svg_layers")
MANIFEST_PATH = os.path.join(HERE, "glyph_manifest.json")
OUT_DIR = os.path.join(HERE, "build")
STAGE1_PATH = os.path.join(OUT_DIR, "FlashShogiPua.stage1.ttf")
FINAL_PATH = os.path.join(OUT_DIR, "FlashShogiPua.ttf")

FULL_WIDTH = 1000


def stage1():
    import fontforge

    os.makedirs(OUT_DIR, exist_ok=True)
    with open(MANIFEST_PATH) as f:
        manifest = json.load(f)

    font = fontforge.font()
    font.fontname = "FlashShogiPua"
    font.familyname = "Flash Shogi PUA"
    font.fullname = "Flash Shogi PUA"
    font.version = "0.2"
    font.copyright = "flash_shogi project (private, unpublished)"
    font.encoding = "UnicodeFull"

    for entry in manifest["glyphs"]:
        name = entry["name"]
        codepoint = entry["codepoint"]

        # フォールバック(非COLR環境向け)の輪郭。符号化されたベースグリフ。
        base = font.createChar(codepoint, name)
        base.importOutlines(os.path.join(SVG_DIR, f"{name}.svg"))
        base.width = FULL_WIDTH

        # COLRレイヤー用の名前付き非符号化グリフ。
        for layer in entry["layers"]:
            gname = layer["glyph"]
            g = font.createChar(-1, gname)
            g.importOutlines(os.path.join(LAYER_DIR, f"{gname}.svg"))
            g.width = FULL_WIDTH

    font.generate(STAGE1_PATH)
    print(f"[stage1] wrote {STAGE1_PATH}")


def stage2():
    from fontTools.ttLib import TTFont
    from fontTools.colorLib.builder import buildCOLR, buildCPAL

    with open(MANIFEST_PATH) as f:
        manifest = json.load(f)
    palette = manifest["palette"]

    tt = TTFont(STAGE1_PATH)

    # CPAL: パレット色のリスト。COLRレイヤーは (r,g,b,a) 0-1 float のタプルで指定する。
    def hex_to_rgba(h):
        h = h.lstrip("#")
        r, g, b = (int(h[i:i + 2], 16) / 255 for i in (0, 2, 4))
        return (r, g, b, 1.0)

    color_names = list(palette.keys())  # body, border, ink, promoted_ink
    color_index = {name: i for i, name in enumerate(color_names)}
    palette_colors = [hex_to_rgba(palette[name]) for name in color_names]

    color_layers = {}
    for entry in manifest["glyphs"]:
        layers = [(layer["glyph"], color_index[layer["color"]]) for layer in entry["layers"]]
        color_layers[entry["name"]] = layers

    tt["CPAL"] = buildCPAL([palette_colors])
    tt["COLR"] = buildCOLR(color_layers)

    os.makedirs(OUT_DIR, exist_ok=True)
    tt.save(FINAL_PATH)
    print(f"[stage2] wrote {FINAL_PATH}")


if __name__ == "__main__":
    if len(sys.argv) != 2 or sys.argv[1] not in ("stage1", "stage2"):
        print(__doc__)
        sys.exit(1)
    if sys.argv[1] == "stage1":
        stage1()
    else:
        stage2()
