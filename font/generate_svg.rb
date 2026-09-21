#!/usr/bin/env ruby
# frozen_string_literal: true

# PUA(私用領域)グリフフォント用の SVG を28種類生成するスクリプト。
# いらすとや「将棋駒34点セット」の雰囲気を参考にした、クリーム地・丸みを
# 抑えた五角形・明朝体のデザイン(プレビューのQ1/Q7案)を採用している。
#
# 使い方:
#   ruby font/generate_svg.rb
#
# 出力先: font/svg/<glyph-name>.svg (例: sente-fu.svg, gote-gyoku.svg)
# 命名・コードポイント対応は引き継ぎ仕様書 4-6 節に準拠する。

require "fileutils"
require "json"

OUT_DIR = File.join(__dir__, "svg")
LAYER_DIR = File.join(__dir__, "svg_layers")
GLYPH_PATHS_FILE = File.join(__dir__, "glyph_paths.json")
GLYPH_PATHS = JSON.parse(File.read(GLYPH_PATHS_FILE)) if File.exist?(GLYPH_PATHS_FILE)

# 4-6-2: 駒種インデックス順
# 成香・成桂・成銀は「小さい"成" + 大きい地の文字」のバッジ方式にする。
# 二文字を均等な大きさで積むと、実際のフォントサイズで表示したときに
# 判別の決め手になる地の文字(香/桂/銀)が小さくなりすぎて読み取りにくいため。
# と・成香・成桂・成銀・馬・龍(成駒全般)は文字色を赤にして、駒の地色・枠は
# 変えずに「成っている」ことを一目で分かるようにする。
PIECES = [
  { key: "fu",       label: "歩",                         promoted: false },
  { key: "kyo",      label: "香",                         promoted: false },
  { key: "kei",      label: "桂",                         promoted: false },
  { key: "gin",      label: "銀",                         promoted: false },
  { key: "kin",      label: "金",                         promoted: false },
  { key: "kaku",     label: "角",                         promoted: false },
  { key: "hisha",    label: "飛",                         promoted: false },
  { key: "gyoku",    label: "玉",                         promoted: false },
  { key: "to",       label: "と",                         promoted: true },
  { key: "narikyo",  label: { badge: "成", main: "香" }, promoted: true },
  { key: "narikei",  label: { badge: "成", main: "桂" }, promoted: true },
  { key: "narigin",  label: { badge: "成", main: "銀" }, promoted: true },
  { key: "uma",      label: "馬",                         promoted: true },
  { key: "ryu",      label: "龍",                         promoted: true },
].freeze
PIECES.each_with_index { |p, i| p[:codepoint_offset] = i }
PIECES.freeze

SENTE_BASE = 0xE000
GOTE_BASE = 0xE100
# 空きマス記号「・」、筋番号ヘッダー(全角１〜９)専用のコードポイント。
# 駒(U+E000台/U+E100台)とは別枠。先手/後手の区別が無い(回転不要)ので
# それぞれ1つずつ。ヘッダーの全角数字はベースフォント側の物に頼ると幅が
# 駒グリフと一致せず、盤面上部の筋番号と実際の列がズレるため
# (要検証で発生を確認)。
EMPTY_CODEPOINT = 0xE200
DIGIT_BASE = 0xE201 # 0xE201='1' 〜 0xE209='9'

FILL = "#f5e2b8"    # クリーム地
STROKE = "#b9824a"  # 木の縁
INK = "#4a3016"     # 通常駒の文字色(こげ茶)
PROMOTED_INK = "#c0392b" # 成駒の文字色(赤)

# --- 角を丸めすぎない五角形(先手=正位置、駒尖が上)のパス。100x100基準。-----
# 各頂点を半径 radius だけ手前で切り、頂点そのものを制御点にした二次ベジェで結ぶ。

PENTAGON_POINTS = [[50, 4], [88, 26], [93, 96], [7, 96], [12, 26]].freeze
ROUND_RADIUS = 4

def rounded_polygon_path(points, radius)
  n = points.size
  before = []
  after = []
  points.each_with_index do |(x, y), i|
    px, py = points[(i - 1) % n]
    nx, ny = points[(i + 1) % n]

    d1 = Math.sqrt(((x - px)**2) + ((y - py)**2))
    before << [x + (px - x) / d1 * radius, y + (py - y) / d1 * radius]

    d2 = Math.sqrt(((nx - x)**2) + ((ny - y)**2))
    after << [x + (nx - x) / d2 * radius, y + (ny - y) / d2 * radius]
  end

  path = +"M #{after[0][0].round(2)},#{after[0][1].round(2)} "
  n.times do |i|
    j = (i + 1) % n
    path << "L #{before[j][0].round(2)},#{before[j][1].round(2)} "
    path << "Q #{points[j][0]},#{points[j][1]} #{after[j][0].round(2)},#{after[j][1].round(2)} "
  end
  path << "Z"
  path
end

PENTAGON_PATH = rounded_polygon_path(PENTAGON_POINTS, ROUND_RADIUS)
# 後手は実行時の <g transform="rotate(180 50 50)"> に頼らず、180°回転後の
# 座標をあらかじめ計算しておく(下記の理由により)。
PENTAGON_PATH_GOTE = rounded_polygon_path(PENTAGON_POINTS.map { |x, y| [100 - x, 100 - y] }, ROUND_RADIUS)

# 文字は <text> ではなく、extract_glyphs.py がヒラギノ明朝 ProN W6 から
# 抽出済みの輪郭パス(font/glyph_paths.json)を使う。FontForge の SVG 取り込みは
# <text> を文字として認識しないため、あらかじめパス化しておく必要がある。
# 位置(main=中央寄り重心、badge=五角形の肩)は extract_glyphs.py 側の
# MAIN_Y/BADGE_Y と対応している。
#
# 後手側は <g transform="rotate(180 50 50)"> を使わず、extract_glyphs.py で
# あらかじめ180°回転させた座標(main_gote/badge_gote)を使う。FontForge の
# SVG取り込みがトランスフォーム適用前のバウンディングボックスを基準に
# auto-scale してしまい、回転後の座標が大きくずれる不具合を確認したため。

# CHAR_BOLD_STROKE: 文字の輪郭に同色のstrokeを足して疑似ボールド化する太さ。
# fill と stroke が同じ色(同じCOLRレイヤー)なので重なっても問題にならない。
CHAR_BOLD_STROKE = 1.6

def path_node(char, slot, color)
  raise "no extracted path for #{char.inspect}(#{slot}). run: font/.venv/bin/python3 font/extract_glyphs.py" unless GLYPH_PATHS&.dig(char, slot)

  %(<path d="#{GLYPH_PATHS[char][slot]}" fill="#{color}" stroke="#{color}" stroke-width="#{CHAR_BOLD_STROKE}" stroke-linejoin="round"/>)
end

def text_markup(label, color:, rotate:)
  suffix = rotate ? "_gote" : ""
  if label.is_a?(Hash)
    [
      path_node(label.fetch(:badge), "badge#{suffix}", color),
      path_node(label.fetch(:main), "main#{suffix}", color),
    ].join("\n")
  else
    path_node(label, "main#{suffix}", color)
  end
end

def plain_label(label)
  label.is_a?(Hash) ? "#{label[:badge]}#{label[:main]}" : label
end

def svg_document(label, promoted:, rotate:)
  color = promoted ? PROMOTED_INK : INK
  pentagon = rotate ? PENTAGON_PATH_GOTE : PENTAGON_PATH
  # FontForge の SVG 取り込みは、塗り(fill)同士が重なると重なった部分の
  # 巻き方向次第で文字が駒の塗りに埋もれて消えてしまう(要検証で確認済み)。
  # 一方 stroke(線)は取り込み時に中空のリング形状として正しく変換される。
  # そこで五角形は「線のみ・塗りなし」にし、文字(塗りのみ)と重ならせない
  # ことで、単色フォントでも両方がちゃんと見えるようにしている。
  # クリーム地(#{FILL})や赤字は、実フォントに反映するには別途 COLR/CPAL
  # カラーフォント化が必要(font/README.md 参照)。色の値自体はSVGソースに
  # 残しておき、その際の参照用にする。
  <<~SVG
    <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
      <g>
        <path d="#{pentagon}" fill="none" stroke="#{STROKE}" stroke-width="3" stroke-linejoin="round"/>
        #{text_markup(label, color: color, rotate: rotate).strip}
      </g>
    </svg>
  SVG
end

# --- COLR/CPAL用のレイヤー別SVG -------------------------------------------
# COLRはレイヤー(=別グリフ)ごとに1色を割り当てて重ね描きする方式なので、
# 「塗りの地色」「線の縁取り」「文字」を独立した3枚のSVG(=3グリフ)として
# 書き出す。この方式なら重なり(fillの巻き方向)を気にする必要がない。
PALETTE = {
  body: FILL,
  border: STROKE,
  ink: INK,
  promoted_ink: PROMOTED_INK,
}.freeze

def body_svg(rotate:)
  pentagon = rotate ? PENTAGON_PATH_GOTE : PENTAGON_PATH
  <<~SVG
    <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
      <path d="#{pentagon}" fill="#000"/>
    </svg>
  SVG
end

def border_svg(rotate:)
  pentagon = rotate ? PENTAGON_PATH_GOTE : PENTAGON_PATH
  <<~SVG
    <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
      <path d="#{pentagon}" fill="none" stroke="#000" stroke-width="3" stroke-linejoin="round"/>
    </svg>
  SVG
end

def char_svg(label, rotate:)
  <<~SVG
    <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
      <g>
        #{text_markup(label, color: "#000", rotate: rotate).strip}
      </g>
    </svg>
  SVG
end

# --- 盤面まわりの記号(空きマス「・」、筋番号ヘッダー) -----------------------
# 駒グリフ(先手14+後手14)とは独立して、ちょうど同じ幅(全角2文字分)になる
# 専用グリフを用意する。ベースフォント側の文字に頼ると、フォントによって
# 幅が駒グリフと一致せず盤面の列や筋番号ヘッダーがズレるため
# (要検証で発生を確認)。

def symbol_svg(char, color)
  <<~SVG
    <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
      #{path_node(char, "main", color)}
    </svg>
  SVG
end

FileUtils.mkdir_p(OUT_DIR)
FileUtils.mkdir_p(LAYER_DIR)

manifest = []

BOARD_SYMBOLS = { "board-empty" => [EMPTY_CODEPOINT, "・"] }
("1".."9").each { |d| BOARD_SYMBOLS["board-digit#{d}"] = [DIGIT_BASE + d.to_i - 1, "０１２３４５６７８９"[d.to_i]] }

BOARD_SYMBOLS.each do |name, (codepoint, char)|
  File.write(File.join(OUT_DIR, "#{name}.svg"), symbol_svg(char, INK))
  File.write(File.join(LAYER_DIR, "#{name}.char.svg"), symbol_svg(char, "#000"))
  manifest << {
    name: name, codepoint: codepoint, label: char,
    layers: [{ glyph: "#{name}.char", color: :ink }],
  }
end

PIECES.each do |piece|
  sente_cp = SENTE_BASE + piece[:codepoint_offset]
  gote_cp = GOTE_BASE + piece[:codepoint_offset]

  sente_name = "sente-#{piece[:key]}"
  gote_name = "gote-#{piece[:key]}"
  ink_role = piece[:promoted] ? :promoted_ink : :ink

  [[sente_name, false], [gote_name, true]].each do |name, rotate|
    # 単色版(フォールバック用の輪郭 + プレビュー用)
    File.write(File.join(OUT_DIR, "#{name}.svg"), svg_document(piece[:label], promoted: piece[:promoted], rotate: rotate))

    # COLR用レイヤー3枚
    File.write(File.join(LAYER_DIR, "#{name}.body.svg"), body_svg(rotate: rotate))
    File.write(File.join(LAYER_DIR, "#{name}.border.svg"), border_svg(rotate: rotate))
    File.write(File.join(LAYER_DIR, "#{name}.char.svg"), char_svg(piece[:label], rotate: rotate))
  end

  manifest << {
    name: sente_name, codepoint: sente_cp, label: plain_label(piece[:label]),
    layers: [
      { glyph: "#{sente_name}.body", color: :body },
      { glyph: "#{sente_name}.border", color: :border },
      { glyph: "#{sente_name}.char", color: ink_role },
    ],
  }
  manifest << {
    name: gote_name, codepoint: gote_cp, label: plain_label(piece[:label]),
    layers: [
      { glyph: "#{gote_name}.body", color: :body },
      { glyph: "#{gote_name}.border", color: :border },
      { glyph: "#{gote_name}.char", color: ink_role },
    ],
  }
end

manifest_path = File.join(__dir__, "glyph_manifest.json")
File.write(manifest_path, JSON.pretty_generate({ palette: PALETTE, glyphs: manifest }))

puts "generated #{manifest.size} glyphs (single-color + 3-layer) "
puts "wrote manifest to #{manifest_path}"
manifest.each do |m|
  puts format("  U+%04X  %-14s %s", m[:codepoint], m[:name], m[:label])
end
