#!/usr/bin/env ruby
# frozen_string_literal: true

# PUA(私用領域)グリフフォント用のプレースホルダー SVG を28種類生成する開発用スクリプト。
# 実際の手描きデザインに差し替えるまでの土台として使う。
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
PIECES = [
  { key: "fu",       label: "歩",                         codepoint_offset: 0x00 },
  { key: "kyo",      label: "香",                         codepoint_offset: 0x01 },
  { key: "kei",      label: "桂",                         codepoint_offset: 0x02 },
  { key: "gin",      label: "銀",                         codepoint_offset: 0x03 },
  { key: "kin",      label: "金",                         codepoint_offset: 0x04 },
  { key: "kaku",     label: "角",                         codepoint_offset: 0x05 },
  { key: "hisha",    label: "飛",                         codepoint_offset: 0x06 },
  { key: "gyoku",    label: "玉",                         codepoint_offset: 0x07 },
  { key: "to",       label: "と",                         codepoint_offset: 0x08 },
  { key: "narikyo",  label: { badge: "成", main: "香" }, codepoint_offset: 0x09 },
  { key: "narikei",  label: { badge: "成", main: "桂" }, codepoint_offset: 0x0A },
  { key: "narigin",  label: { badge: "成", main: "銀" }, codepoint_offset: 0x0B },
  { key: "uma",      label: "馬",                         codepoint_offset: 0x0C },
  { key: "ryu",      label: "龍",                         codepoint_offset: 0x0D },
].freeze

SENTE_BASE = 0xE000
GOTE_BASE = 0xE100

FONT_STACK = "'Hiragino Mincho ProN', 'Hiragino Sans', 'Yu Mincho', serif"

# 将棋駒らしい五角形(先手=正位置、駒尖が上)のパス。100x100のビューポート基準。
def pentagon_path
  "M 50,4 L 88,26 L 93,96 L 7,96 L 12,26 Z"
end

# 五角形(駒尖が上・底辺がy=96)の視覚的な重心はバウンディングボックス中央(y=50)より
# 下にある。text-anchor="middle" + dominant-baseline="central" で、指定した y を
# 文字そのものの中心として扱わせ、その y を重心に合わせることで駒の中に文字が
# 収まって見えるようにする。
GLYPH_CENTER_Y = 57
BADGE_Y = 21
BADGE_SIZE = 15
MAIN_SIZE = 46

def text_node(char, y:, size:)
  %(<text x="50" y="#{y}" font-size="#{size}" font-family="#{FONT_STACK}" font-weight="700" fill="#000" text-anchor="middle" dominant-baseline="central">#{char}</text>)
end

def text_markup(label)
  if label.is_a?(Hash)
    [
      text_node(label.fetch(:badge), y: BADGE_Y, size: BADGE_SIZE),
      text_node(label.fetch(:main), y: GLYPH_CENTER_Y, size: MAIN_SIZE),
    ].join("\n")
  else
    text_node(label, y: GLYPH_CENTER_Y, size: MAIN_SIZE)
  end
end

def plain_label(label)
  label.is_a?(Hash) ? "#{label[:badge]}#{label[:main]}" : label
end

def svg_document(label, rotate:)
  transform = rotate ? %( transform="rotate(180 50 50)") : ""
  <<~SVG
    <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
      <g#{transform}>
        <path d="#{pentagon_path}" fill="none" stroke="#000" stroke-width="4" stroke-linejoin="round"/>
        #{text_markup(label).strip}
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

  File.write(File.join(OUT_DIR, "#{sente_name}.svg"), svg_document(piece[:label], rotate: false))
  File.write(File.join(OUT_DIR, "#{gote_name}.svg"), svg_document(piece[:label], rotate: true))

  manifest << { name: sente_name, codepoint: sente_cp, label: plain_label(piece[:label]) }
  manifest << { name: gote_name, codepoint: gote_cp, label: plain_label(piece[:label]) }
end

puts "generated #{manifest.size} svg files into #{OUT_DIR}"
manifest.each do |m|
  puts format("  U+%04X  %-14s %s", m[:codepoint], m[:name], m[:label])
end
