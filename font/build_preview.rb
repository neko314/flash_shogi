#!/usr/bin/env ruby
# frozen_string_literal: true

# font/svg/*.svg を読み込み、ブラウザ確認用のプレビューHTML(font/preview.html)を組み立てる開発用スクリプト。
# アプリ本体には含めない。

require "fileutils"

SVG_DIR = File.join(__dir__, "svg")
OUT_PATH = File.join(__dir__, "preview.html")

ORDER = %w[fu kyo kei gin kin kaku hisha gyoku to narikyo narikei narigin uma ryu].freeze
LABELS = {
  "fu" => "歩", "kyo" => "香", "kei" => "桂", "gin" => "銀", "kin" => "金",
  "kaku" => "角", "hisha" => "飛", "gyoku" => "玉", "to" => "と",
  "narikyo" => "成香", "narikei" => "成桂", "narigin" => "成銀", "uma" => "馬", "ryu" => "龍"
}.freeze
SENTE_BASE = 0xE000
GOTE_BASE = 0xE100
OFFSET = { "fu" => 0x00, "kyo" => 0x01, "kei" => 0x02, "gin" => 0x03, "kin" => 0x04,
           "kaku" => 0x05, "hisha" => 0x06, "gyoku" => 0x07, "to" => 0x08,
           "narikyo" => 0x09, "narikei" => 0x0A, "narigin" => 0x0B, "uma" => 0x0C, "ryu" => 0x0D }.freeze

def read_svg(name)
  File.read(File.join(SVG_DIR, "#{name}.svg")).strip
end

def card(key, owner)
  name = "#{owner}-#{key}"
  cp = (owner == "sente" ? SENTE_BASE : GOTE_BASE) + OFFSET.fetch(key)
  svg = read_svg(name)
  <<~HTML
    <figure class="cell">
      <div class="glyph">#{svg}</div>
      <figcaption>
        <span class="label">#{LABELS.fetch(key)}</span>
        <span class="meta">#{name}<br>U+#{format('%04X', cp)}</span>
      </figcaption>
    </figure>
  HTML
end

sente_cells = ORDER.map { |k| card(k, "sente") }.join
gote_cells = ORDER.map { |k| card(k, "gote") }.join

html = <<~HTML
  <title>駒グリフ台帳</title>
  <style>
    @import url('https://fonts.googleapis.com/css2?family=Shippori+Mincho:wght@600;800&family=Noto+Sans+JP:wght@400;500;700&display=swap');

    :root {
      --paper: #f3ede0;
      --paper-raised: #fbf7ee;
      --ink: #241d14;
      --ink-soft: #6b5f4c;
      --line: #d8cdb4;
      --accent: #9c3b28;
      --accent-soft: #c98a3a;
    }

    @media (prefers-color-scheme: dark) {
      :root:not([data-theme="light"]) {
        --paper: #1c1712;
        --paper-raised: #262019;
        --ink: #f0e8d8;
        --ink-soft: #b7a98d;
        --line: #4a4033;
        --accent: #e07a5f;
        --accent-soft: #e0a84c;
      }
    }
    :root[data-theme="dark"] {
      --paper: #1c1712;
      --paper-raised: #262019;
      --ink: #f0e8d8;
      --ink-soft: #b7a98d;
      --line: #4a4033;
      --accent: #e07a5f;
      --accent-soft: #e0a84c;
    }

    * { box-sizing: border-box; }
    body {
      margin: 0;
      background: var(--paper);
      color: var(--ink);
      font-family: 'Noto Sans JP', sans-serif;
      padding-inline: max(20px, env(safe-area-inset-left, 0px));
      padding-block: 32px 64px;
    }

    .wrap { max-width: 1040px; margin: 0 auto; }

    header { margin-bottom: 36px; }
    .eyebrow {
      font-size: 12px;
      letter-spacing: .12em;
      color: var(--accent-soft);
      text-transform: uppercase;
      font-weight: 700;
      margin: 0 0 10px;
    }
    h1 {
      font-family: 'Shippori Mincho', serif;
      font-weight: 800;
      font-size: clamp(28px, 4vw, 40px);
      margin: 0 0 12px;
      text-wrap: balance;
    }
    header p {
      color: var(--ink-soft);
      max-width: 62ch;
      line-height: 1.7;
      margin: 0;
      font-size: 14.5px;
    }

    section { margin-top: 40px; }
    .section-head {
      display: flex;
      align-items: baseline;
      gap: 12px;
      margin-bottom: 16px;
      padding-bottom: 10px;
      border-bottom: 1px solid var(--line);
    }
    .section-head h2 {
      font-family: 'Shippori Mincho', serif;
      font-size: 20px;
      font-weight: 700;
      margin: 0;
    }
    .section-head span {
      font-size: 12px;
      color: var(--ink-soft);
    }

    .grid {
      display: grid;
      grid-template-columns: repeat(auto-fill, minmax(92px, 1fr));
      gap: 14px;
    }

    .cell {
      margin: 0;
      background: var(--paper-raised);
      border: 1px solid var(--line);
      border-radius: 6px;
      padding: 10px 8px 8px;
      text-align: center;
    }
    .glyph {
      width: 56px;
      height: 56px;
      margin: 0 auto 8px;
    }
    .glyph svg { width: 100%; height: 100%; display: block; }
    .glyph svg path { stroke: var(--ink); }
    .glyph svg text { fill: var(--ink); }

    figcaption .label {
      display: block;
      font-size: 11px;
      color: var(--ink-soft);
    }
    figcaption .meta {
      display: block;
      font-size: 10px;
      color: var(--ink-soft);
      opacity: .75;
      margin-top: 4px;
      line-height: 1.4;
      font-variant-numeric: tabular-nums;
    }

    footer {
      margin-top: 48px;
      padding-top: 16px;
      border-top: 1px solid var(--line);
      font-size: 12px;
      color: var(--ink-soft);
    }
  </style>

  <div class="wrap">
    <header>
      <p class="eyebrow">flash_shogi / PUA glyphs</p>
      <h1>駒グリフ台帳 — プレースホルダー版</h1>
      <p>
        U+E000–U+E00D(先手14種)と U+E100–U+E10D(後手14種、180°回転)のプレースホルダーです。
        まだ五角形の輪郭+システムフォントの漢字を組んだだけの仮デザインで、FontForge に取り込む前段階の確認用。
        ここから SVG を手描きデザインに差し替えて、同じファイル名で font/svg/ を上書きすれば見た目が更新されます。
      </p>
    </header>

    <section>
      <div class="section-head">
        <h2>先手(正位置)</h2>
        <span>U+E000–U+E00D</span>
      </div>
      <div class="grid">
        #{sente_cells}
      </div>
    </section>

    <section>
      <div class="section-head">
        <h2>後手(180°回転)</h2>
        <span>U+E100–U+E10D</span>
      </div>
      <div class="grid">
        #{gote_cells}
      </div>
    </section>

    <footer>
      駒種インデックス: 0=歩 1=香 2=桂 3=銀 4=金 5=角 6=飛 7=玉 8=と 9=成香 10=成桂 11=成銀 12=馬 13=龍(引き継ぎ仕様書 4-6-2)
    </footer>
  </div>
HTML

File.write(OUT_PATH, html)
puts "wrote #{OUT_PATH}"
