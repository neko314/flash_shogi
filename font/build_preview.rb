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

# --- 成駒バッジの改善案比較 -------------------------------------------------

MINCHO = "'Hiragino Mincho ProN', 'Hiragino Sans', 'Yu Mincho', serif"
GOTHIC = "'Hiragino Sans', 'Yu Gothic', sans-serif"
SOSHO = "'Yuji Boku', serif"
SOSHO_LIGHT = "'Yuji Syuku', serif"
SOSHO_FLOW = "'Yuji Mai', serif"
PENTAGON = "M 50,4 L 88,26 L 93,96 L 7,96 L 12,26 Z"

def variant_svg(main:, badge: nil, badge_font: MINCHO, badge_size: 15, badge_x: 50, badge_y: 21,
                main_size: 46, main_y: 57, main_font: MINCHO, main_style: nil,
                double_border: false, tint: nil, divider: false, notch: false)
  # tint はターミナル側のANSI色指定を模したもの: 実際のフォントでは駒の輪郭も
  # 文字も同じグリフの一部(単色インク)なので、色を変えるなら両方変わる。
  color = tint || "#000"

  border = if double_border
             %(<path d="#{PENTAGON}" fill="none" stroke="#{color}" stroke-width="3"/>
               <path d="M 50,10 L 82,29 L 87,91 L 13,91 L 18,29 Z" fill="none" stroke="#{color}" stroke-width="2"/>)
           elsif notch
             %(<path d="M 50,4 L 88,26 L 93,96 L 76,96 L 76,88 L 24,88 L 24,96 L 7,96 L 12,26 Z" fill="none" stroke="#{color}" stroke-width="4" stroke-linejoin="round"/>)
           else
             %(<path d="#{PENTAGON}" fill="none" stroke="#{color}" stroke-width="4" stroke-linejoin="round"/>)
           end

  style_attr = main_style ? %( font-style="#{main_style}") : ""

  badge_markup = if badge
                   %(<text x="#{badge_x}" y="#{badge_y}" font-size="#{badge_size}" font-family="#{badge_font}" font-weight="800" fill="#{color}" text-anchor="middle" dominant-baseline="central">#{badge}</text>)
                 else
                   ""
                 end
  divider_markup = divider ? %(<line x1="32" y1="31" x2="68" y2="31" stroke="#{color}" stroke-width="2"/>) : ""

  <<~SVG
    <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
      <g>
        #{border}
        #{badge_markup}
        #{divider_markup}
        <text x="50" y="#{main_y}" font-size="#{main_size}" font-family="#{main_font}" font-weight="700" fill="#{color}" text-anchor="middle" dominant-baseline="central"#{style_attr}>#{main}</text>
      </g>
    </svg>
  SVG
end

VARIANTS = [
  { id: "A", title: "現行案", desc: "明朝バッジ、そのまま", svg: variant_svg(main: "香", badge: "成") },
  { id: "B", title: "ゴシックバッジ", desc: "バッジだけ太いゴシック体に", svg: variant_svg(main: "香", badge: "成", badge_font: GOTHIC, badge_size: 16) },
  { id: "C", title: "バッジ拡大+地の文字縮小", desc: "成=19px / 香=40px", svg: variant_svg(main: "香", badge: "成", badge_font: GOTHIC, badge_size: 19, badge_y: 20, main_size: 40, main_y: 60) },
  { id: "D", title: "仕切り線", desc: "バッジの下に区切り線", svg: variant_svg(main: "香", badge: "成", badge_font: GOTHIC, badge_size: 16, divider: true, main_y: 60, main_size: 42) },
  { id: "E", title: "二重枠線(バッジなし)", desc: "文字はそのまま、外枠を二重線に", svg: variant_svg(main: "香", double_border: true) },
  { id: "F", title: "角を切り欠く(バッジなし)", desc: "五角形の下角を落として差別化", svg: variant_svg(main: "香", notch: true) },
  { id: "G", title: "傍点のみ", desc: "「成」の代わりに点ひとつ", svg: variant_svg(main: "香", badge: "・", badge_size: 26, badge_y: 18) },
  { id: "H", title: "色分け(レンダラー案)", desc: "バッジなし、色だけ変える(フォントとは別レイヤー)", svg: variant_svg(main: "香", tint: "#b0402c") },
  { id: "I", title: "斜体(バッジなし)", desc: "成り駒だけ字を傾ける", svg: variant_svg(main: "香", main_style: "italic") },
  { id: "J", title: "草書体バッジ", desc: "「成」だけ毛筆(Yuji Boku)に、地の文字は明朝のまま", svg: variant_svg(main: "香", badge: "成", badge_font: SOSHO, badge_size: 19, badge_y: 20) },
  { id: "K", title: "草書体(駒全体)", desc: "「成」も地の文字も毛筆に。実物の駒に近い雰囲気", svg: variant_svg(main: "香", badge: "成", badge_font: SOSHO, badge_size: 19, badge_y: 20, main_font: SOSHO) },
  { id: "L", title: "草書体のみ(バッジなし)", desc: "バッジを足さず、字そのものを毛筆にして差別化", svg: variant_svg(main: "香", main_font: SOSHO) },
  { id: "M", title: "細字の草書(駒全体)", desc: "Yuji Syuku。繊細・行書寄りの崩し", svg: variant_svg(main: "香", badge: "成", badge_font: SOSHO_LIGHT, badge_size: 19, badge_y: 20, main_font: SOSHO_LIGHT) },
  { id: "N", title: "流れる草書(駒全体)", desc: "Yuji Mai。舞うような、より大きく崩れた字形", svg: variant_svg(main: "香", badge: "成", badge_font: SOSHO_FLOW, badge_size: 19, badge_y: 20, main_font: SOSHO_FLOW) },
  { id: "O", title: "流れる草書(バッジなし)", desc: "Yuji Mai を地の文字だけに使う", svg: variant_svg(main: "香", main_font: SOSHO_FLOW) },
  { id: "P", title: "M案 + 赤字", desc: "Yuji Syuku(駒全体)を赤色に。輪郭も文字も同じインクなので両方赤くなる想定", svg: variant_svg(main: "香", badge: "成", badge_font: SOSHO_LIGHT, badge_size: 19, badge_y: 20, main_font: SOSHO_LIGHT, tint: "#c0392b") },
].freeze

def variant_card(v)
  sizes = [56, 32, 22, 16]
  cells = sizes.map do |px|
    <<~HTML
      <div class="size-cell">
        <div class="size-glyph" style="width:#{px}px;height:#{px}px">#{v[:svg]}</div>
        <span>#{px}px</span>
      </div>
    HTML
  end.join
  <<~HTML
    <div class="variant-row">
      <div class="variant-label">
        <span class="variant-id">#{v[:id]}</span>
        <span class="variant-title">#{v[:title]}</span>
        <span class="variant-desc">#{v[:desc]}</span>
      </div>
      <div class="size-cells">#{cells}</div>
    </div>
  HTML
end

variant_rows = VARIANTS.map { |v| variant_card(v) }.join

def size_check_row(key)
  svg = read_svg("sente-#{key}")
  sizes = [56, 32, 22, 16]
  cells = sizes.map do |px|
    <<~HTML
      <div class="size-cell">
        <div class="size-glyph" style="width:#{px}px;height:#{px}px">#{svg}</div>
        <span>#{px}px</span>
      </div>
    HTML
  end.join
  <<~HTML
    <div class="size-row">
      <span class="size-row-label">#{LABELS.fetch(key)}</span>
      <div class="size-cells">#{cells}</div>
    </div>
  HTML
end

size_check_rows = %w[narikyo narikei narigin].map { |k| size_check_row(k) }.join

html = <<~HTML
  <title>駒グリフ台帳</title>
  <style>
    @import url('https://fonts.googleapis.com/css2?family=Shippori+Mincho:wght@600;800&family=Noto+Sans+JP:wght@400;500;700&family=Yuji+Boku&family=Yuji+Syuku&family=Yuji+Mai&display=swap');

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

    .size-check {
      background: var(--paper-raised);
      border: 1px solid var(--line);
      border-radius: 8px;
      padding: 18px 20px;
      display: flex;
      flex-direction: column;
      gap: 14px;
    }
    .size-row {
      display: flex;
      align-items: center;
      gap: 18px;
      flex-wrap: wrap;
    }
    .size-row-label {
      width: 44px;
      flex: 0 0 auto;
      font-size: 13px;
      color: var(--ink-soft);
    }
    .size-cells {
      display: flex;
      align-items: flex-end;
      gap: 22px;
      flex-wrap: wrap;
    }
    .size-cell {
      display: flex;
      flex-direction: column;
      align-items: center;
      gap: 6px;
    }
    .size-glyph svg { width: 100%; height: 100%; display: block; }
    .size-glyph svg path { stroke: var(--ink); }
    .size-glyph svg text { fill: var(--ink); }
    .size-cell span {
      font-size: 10px;
      color: var(--ink-soft);
      font-variant-numeric: tabular-nums;
    }

    .variant-list {
      display: flex;
      flex-direction: column;
      gap: 4px;
    }
    .variant-row {
      display: flex;
      align-items: center;
      gap: 20px;
      flex-wrap: wrap;
      background: var(--paper-raised);
      border: 1px solid var(--line);
      border-radius: 8px;
      padding: 14px 18px;
    }
    .variant-label {
      width: 220px;
      flex: 0 0 auto;
      display: flex;
      flex-direction: column;
      gap: 2px;
    }
    .variant-id {
      display: inline-flex;
      align-items: center;
      justify-content: center;
      width: 20px;
      height: 20px;
      border-radius: 50%;
      background: var(--accent);
      color: var(--paper-raised);
      font-size: 11px;
      font-weight: 700;
      margin-bottom: 4px;
    }
    .variant-title {
      font-weight: 700;
      font-size: 13.5px;
    }
    .variant-desc {
      font-size: 11.5px;
      color: var(--ink-soft);
      line-height: 1.5;
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
        <h2>成駒バッジの改善案比較</h2>
        <span>「成香」で9パターン試作</span>
      </div>
      <div class="variant-list">
        #{variant_rows}
      </div>
    </section>

    <section>
      <div class="section-head">
        <h2>成香・成桂・成銀の縮小確認(現行案)</h2>
        <span>ターミナルの文字サイズを想定</span>
      </div>
      <div class="size-check">
        #{size_check_rows}
      </div>
    </section>

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
