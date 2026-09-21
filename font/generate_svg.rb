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
PIECES = [
  { key: "fu",       label: %w[歩],   codepoint_offset: 0x00 },
  { key: "kyo",       label: %w[香],   codepoint_offset: 0x01 },
  { key: "kei",       label: %w[桂],   codepoint_offset: 0x02 },
  { key: "gin",       label: %w[銀],   codepoint_offset: 0x03 },
  { key: "kin",       label: %w[金],   codepoint_offset: 0x04 },
  { key: "kaku",      label: %w[角],   codepoint_offset: 0x05 },
  { key: "hisha",     label: %w[飛],   codepoint_offset: 0x06 },
  { key: "gyoku",     label: %w[玉],   codepoint_offset: 0x07 },
  { key: "to",        label: %w[と],   codepoint_offset: 0x08 },
  { key: "narikyo",   label: %w[成 香], codepoint_offset: 0x09 },
  { key: "narikei",   label: %w[成 桂], codepoint_offset: 0x0A },
  { key: "narigin",   label: %w[成 銀], codepoint_offset: 0x0B },
  { key: "uma",       label: %w[馬],   codepoint_offset: 0x0C },
  { key: "ryu",       label: %w[龍],   codepoint_offset: 0x0D },
].freeze

SENTE_BASE = 0xE000
GOTE_BASE = 0xE100

FONT_STACK = "'Hiragino Mincho ProN', 'Hiragino Sans', 'Yu Mincho', serif"

# 将棋駒らしい五角形(先手=正位置、駒尖が上)のパス。100x100のビューポート基準。
def pentagon_path
  "M 50,4 L 88,26 L 93,96 L 7,96 L 12,26 Z"
end

def text_markup(label)
  if label.size == 1
    <<~SVG
      <text x="50" y="66" font-size="46" font-family="#{FONT_STACK}" font-weight="700" fill="#000" text-anchor="middle">#{label[0]}</text>
    SVG
  else
    <<~SVG
      <text x="50" y="42" font-size="30" font-family="#{FONT_STACK}" font-weight="700" fill="#000" text-anchor="middle">#{label[0]}</text>
      <text x="50" y="78" font-size="30" font-family="#{FONT_STACK}" font-weight="700" fill="#000" text-anchor="middle">#{label[1]}</text>
    SVG
  end
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

  manifest << { name: sente_name, codepoint: sente_cp, label: piece[:label].join }
  manifest << { name: gote_name, codepoint: gote_cp, label: piece[:label].join }
end

puts "generated #{manifest.size} svg files into #{OUT_DIR}"
manifest.each do |m|
  puts format("  U+%04X  %-14s %s", m[:codepoint], m[:name], m[:label])
end
