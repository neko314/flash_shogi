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

OUT_DIR = File.join(__dir__, "svg")

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

FONT_STACK = "'Hiragino Mincho ProN', 'Hiragino Sans', 'Yu Mincho', serif"

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

# 五角形の視覚的な重心はバウンディングボックス中央(y=50)より下にある。
# text-anchor="middle" + dominant-baseline="central" で、指定した y を
# 文字そのものの中心として扱わせ、その y を重心に合わせている。
GLYPH_CENTER_Y = 57
BADGE_Y = 21
BADGE_SIZE = 15
MAIN_SIZE = 46

def text_node(char, y:, size:, color:)
  %(<text x="50" y="#{y}" font-size="#{size}" font-family="#{FONT_STACK}" font-weight="700" fill="#{color}" text-anchor="middle" dominant-baseline="central">#{char}</text>)
end

def text_markup(label, color:)
  if label.is_a?(Hash)
    [
      text_node(label.fetch(:badge), y: BADGE_Y, size: BADGE_SIZE, color: color),
      text_node(label.fetch(:main), y: GLYPH_CENTER_Y, size: MAIN_SIZE, color: color),
    ].join("\n")
  else
    text_node(label, y: GLYPH_CENTER_Y, size: MAIN_SIZE, color: color)
  end
end

def plain_label(label)
  label.is_a?(Hash) ? "#{label[:badge]}#{label[:main]}" : label
end

def svg_document(label, promoted:, rotate:)
  transform = rotate ? %( transform="rotate(180 50 50)") : ""
  color = promoted ? PROMOTED_INK : INK
  <<~SVG
    <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
      <g#{transform}>
        <path d="#{PENTAGON_PATH}" fill="#{FILL}" stroke="#{STROKE}" stroke-width="3" stroke-linejoin="round"/>
        #{text_markup(label, color: color).strip}
      </g>
    </svg>
  SVG
end

FileUtils.mkdir_p(OUT_DIR)

manifest = []

PIECES.each do |piece|
  sente_cp = SENTE_BASE + piece[:codepoint_offset]
  gote_cp = GOTE_BASE + piece[:codepoint_offset]

  sente_name = "sente-#{piece[:key]}"
  gote_name = "gote-#{piece[:key]}"

  File.write(File.join(OUT_DIR, "#{sente_name}.svg"), svg_document(piece[:label], promoted: piece[:promoted], rotate: false))
  File.write(File.join(OUT_DIR, "#{gote_name}.svg"), svg_document(piece[:label], promoted: piece[:promoted], rotate: true))

  manifest << { name: sente_name, codepoint: sente_cp, label: plain_label(piece[:label]) }
  manifest << { name: gote_name, codepoint: gote_cp, label: plain_label(piece[:label]) }
end

puts "generated #{manifest.size} svg files into #{OUT_DIR}"
manifest.each do |m|
  puts format("  U+%04X  %-14s %s", m[:codepoint], m[:name], m[:label])
end
