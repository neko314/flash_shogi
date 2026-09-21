#!/usr/bin/env python3
"""
普段使っているフォント(例: Fira Code)に、PUA駒グリフ(font/build/FlashShogiPua.ttf)
を合体させる。Nerd Fontsのアイコン合体と同じ考え方: ベースフォントの通常の文字は
一切変更せず、U+E000-U+E00D/U+E100-U+E10Dのグリフだけを追加する。

可変フォント(variable font)のベースにも対応する。追加するグリフは gvar に
エントリを作らないため、ウェイト軸を動かしても見た目は変わらない(固定デザイン)
ままになる。これは Nerd Font パッチャーと同じ扱い。

使い方:
  font/.venv/bin/python3 font/merge_glyphs.py <ベースフォントのパス> [出力パス]

例:
  font/.venv/bin/python3 font/merge_glyphs.py \
      ~/Library/Fonts/FiraCode-VariableFont_wght.ttf \
      font/build/FiraCodeShogi.ttf
"""
import os
import sys

from fontTools.colorLib.builder import buildCOLR, buildCPAL
from fontTools.ttLib import TTFont, newTable

HERE = os.path.dirname(os.path.abspath(__file__))
SHOGI_FONT_PATH = os.path.join(HERE, "build", "FlashShogiPua.ttf")


def hex_to_rgba(h):
    h = h.lstrip("#")
    r, g, b = (int(h[i:i + 2], 16) / 255 for i in (0, 2, 4))
    return (r, g, b, 1.0)


def normal_advance_width(base):
    """ベースフォントの「半角1文字分」の送り幅を推定する。等幅フォント前提で
    'A' や 'space' など基本ラテン文字の幅を見る。"""
    hmtx = base["hmtx"]
    for name in ("A", "space", "zero", "0"):
        if name in hmtx.metrics:
            return hmtx.metrics[name][0]
    # 最後の手段: cmapから最初に見つかったASCII文字の幅
    cmap = base.getBestCmap()
    for cp in range(0x21, 0x7F):
        if cp in cmap and cmap[cp] in hmtx.metrics:
            return hmtx.metrics[cmap[cp]][0]
    raise RuntimeError("could not determine base font's normal advance width")


def scale_glyph(glyph, factor):
    """glyfのTTGlyphを factor 倍する(単純拡大、原点基準)。"""
    if glyph.numberOfContours == 0:
        return glyph
    if glyph.isComposite():
        for comp in glyph.components:
            comp.x = int(round(comp.x * factor))
            comp.y = int(round(comp.y * factor))
        return glyph
    glyph.coordinates = glyph.coordinates.copy()
    glyph.coordinates.scale((factor, factor))
    glyph.recalcBounds(None)
    return glyph


def rename_font(font, new_name):
    """name テーブルの主要な名前を書き換え、ベースフォントと同名にならない
    (=フォント選択メニューで衝突しない)ようにする。"""
    name_table = font["name"]
    ps_name = new_name.replace(" ", "")
    plat_combos = {(r.platformID, r.platEncID, r.langID) for r in name_table.names}
    for plat_id, enc_id, lang_id in plat_combos:
        name_table.setName(new_name, 1, plat_id, enc_id, lang_id)   # Family
        name_table.setName(new_name, 4, plat_id, enc_id, lang_id)   # Full name
        name_table.setName(ps_name, 6, plat_id, enc_id, lang_id)    # PostScript name
        name_table.setName(new_name, 16, plat_id, enc_id, lang_id)  # Typographic family


def merge(base_path, out_path, new_name):
    base = TTFont(base_path)
    shogi = TTFont(SHOGI_FONT_PATH)

    base_upm = base["head"].unitsPerEm
    shogi_upm = shogi["head"].unitsPerEm
    scale = base_upm / shogi_upm

    normal_width = normal_advance_width(base)
    double_width = normal_width * 2
    print(f"base unitsPerEm={base_upm} shogi unitsPerEm={shogi_upm} scale={scale}")
    print(f"normal advance width={normal_width} -> shogi glyph width={double_width}")

    existing_names = set(base.getGlyphOrder())

    shogi_glyf = shogi["glyf"]
    base_glyf = base["glyf"]
    base_hmtx = base["hmtx"]
    base_gvar = base["gvar"] if "gvar" in base else None

    added_names = []

    def copy_glyph(name):
        if name in existing_names:
            raise RuntimeError(f"glyph name collision: {name!r} already exists in base font")
        glyph = shogi_glyf[name]
        # TTGlyphコピー: 座標配列を持つ場合は複製してから拡大する。
        glyph = scale_glyph(glyph, scale)
        # glyf の __setitem__ が glyphOrder への追加も面倒を見てくれるので、
        # ここでグリフ順序を自前で並行管理しない(食い違いの原因になるため)。
        base_glyf[name] = glyph
        base_hmtx.metrics[name] = (double_width, 0)
        if base_gvar is not None:
            # 可変フォント(gvar)は全グリフ分のエントリが揃っている前提で
            # decompile/compileされる。空リスト = ウェイト軸を動かしても
            # 変形しない(常に同じ絵柄のまま)という意味になり、今回の
            # 用途(固定デザインのアイコン)にちょうど合う。これを足さないと
            # gvarのグリフ数と実際のグリフ数がズレて、フォント全体の解釈が
            # 不安定になる(色・文字が表示されない不具合の原因だった)。
            base_gvar.variations[name] = []
        existing_names.add(name)
        added_names.append(name)

    # 1) 符号化されたベースグリフ(28個、フォールバック輪郭)+ cmap登録
    # FontForgeが自動で足す .notdef/.null/nonmarkingreturn 等は対象外にする
    # (ベースフォント側に同名グリフがあると衝突するため)。
    cmap_additions = {}
    for glyph_name in shogi.getGlyphOrder():
        if not glyph_name.startswith(("sente-", "gote-")):
            continue
        copy_glyph(glyph_name)

    shogi_cmap = shogi.getBestCmap()
    for codepoint, glyph_name in shogi_cmap.items():
        cmap_additions[codepoint] = glyph_name

    # glyf テーブル自身が正しく更新した glyphOrder を正として、
    # フォント全体・hmtx 側の順序をそれに合わせる。
    final_order = base_glyf.glyphOrder
    base.setGlyphOrder(final_order)
    base["hmtx"].glyphOrder = final_order
    base["maxp"].numGlyphs = len(final_order)

    # cmap: 既存のUnicodeサブテーブルに追加する(既存文字は一切変更しない)。
    for table in base["cmap"].tables:
        if table.isUnicode():
            table.cmap.update(cmap_additions)

    # COLR/CPAL: ベースには存在しない前提で新規追加する。
    # レイヤー構成はglyph_manifest.jsonそのものではなく、shogiフォント自身の
    # COLRテーブルから読み取る(常に一次情報と一致させるため)。
    src_colr = shogi["COLR"]
    src_cpal = shogi["CPAL"]
    # CPALのColorは内部的に (blue, green, red, alpha) 順のnamedtupleで、
    # 0-255の整数。位置的にタプル展開するとR/Bが入れ替わってしまうため、
    # 必ずフィールド名で読み、buildCPALが要求する0-1floatのRGBA順に変換する。
    palette = [(c.red / 255, c.green / 255, c.blue / 255, c.alpha / 255) for c in src_cpal.palettes[0]]

    color_layers = {}
    for glyph_name, layers in src_colr.ColorLayers.items():
        color_layers[glyph_name] = [(layer.name, layer.colorID) for layer in layers]

    base["CPAL"] = buildCPAL([palette])
    base["COLR"] = buildCOLR(color_layers)

    rename_font(base, new_name)

    os.makedirs(os.path.dirname(out_path), exist_ok=True)
    base.save(out_path)
    print(f"added {len(added_names)} glyphs, {len(cmap_additions)} cmap entries")
    print(f"wrote {out_path}")


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(1)
    base_path = os.path.expanduser(sys.argv[1])

    probe = TTFont(base_path)
    family = probe["name"].getDebugName(1) or os.path.splitext(os.path.basename(base_path))[0]
    del probe

    new_name = f"{family} Shogi"
    out_path = sys.argv[2] if len(sys.argv) > 2 else os.path.join(HERE, "build", f"{family.replace(' ', '')}Shogi.ttf")
    merge(base_path, out_path, new_name)
