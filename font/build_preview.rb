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

# --- イラスト調(いらすとや参考、色付き・丸み)試作 ---------------------------
# 五角形の角を丸めたパスを作る(各頂点を半径 radius だけ手前で切り、
# 頂点そのものを制御点にした二次ベジェで結ぶ)。

MINCHO = "'Hiragino Mincho ProN', 'Hiragino Sans', 'Yu Mincho', serif"

def rounded_polygon_path(points, radius)
  n = points.size
  before = []
  after = []
  points.each_with_index do |(x, y), i|
    px, py = points[(i - 1) % n]
    nx, ny = points[(i + 1) % n]

    d1 = Math.sqrt((x - px)**2 + (y - py)**2)
    before << [x + (px - x) / d1 * radius, y + (py - y) / d1 * radius]

    d2 = Math.sqrt((nx - x)**2 + (ny - y)**2)
    after << [x + (nx - x) / d2 * radius, y + (ny - y) / d2 * radius]
  end

  path = +"M #{after[0][0].round(1)},#{after[0][1].round(1)} "
  n.times do |i|
    j = (i + 1) % n
    path << "L #{before[j][0].round(1)},#{before[j][1].round(1)} "
    path << "Q #{points[j][0]},#{points[j][1]} #{after[j][0].round(1)},#{after[j][1].round(1)} "
  end
  path << "Z"
  path
end

PENTAGON_POINTS = [[50, 4], [88, 26], [93, 96], [7, 96], [12, 26]].freeze
# 角を丸めすぎない(尖っていてよい)ので半径は小さめに留める。
ROUNDED_PENTAGON = rounded_polygon_path(PENTAGON_POINTS, 4)

def illust_svg(main:, badge: nil, fill: "#f5e2b8", stroke: "#b9824a", ink: "#4a3016", badge_ink: nil)
  badge_ink ||= ink
  badge_markup = badge ? %(<text x="50" y="21" font-size="19" font-family="#{MINCHO}" font-weight="700" fill="#{badge_ink}" text-anchor="middle" dominant-baseline="central">#{badge}</text>) : ""
  <<~SVG
    <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
      <g>
        <path d="#{ROUNDED_PENTAGON}" fill="#{fill}" stroke="#{stroke}" stroke-width="3" stroke-linejoin="round"/>
        #{badge_markup}
        <text x="50" y="57" font-size="46" font-family="#{MINCHO}" font-weight="700" fill="#{ink}" text-anchor="middle" dominant-baseline="central">#{main}</text>
      </g>
    </svg>
  SVG
end

ILLUST_VARIANTS = [
  { id: "Q1", title: "基本形(歩)", desc: "クリーム地+明朝、枠は細め・角は控えめ", svg: illust_svg(main: "歩") },
  { id: "Q2", title: "玉", desc: "同じ配色で玉将", svg: illust_svg(main: "玉") },
  { id: "Q3", title: "飛", desc: "同じ配色で飛車", svg: illust_svg(main: "飛") },
  { id: "Q4", title: "成香(バッジ方式と併用)", desc: "小さい成+地の文字、いずれも明朝", svg: illust_svg(main: "香", badge: "成") },
  { id: "Q5", title: "配色違い(白木)", desc: "より白っぽい木地", svg: illust_svg(main: "歩", fill: "#f8efd8", stroke: "#c9a877", ink: "#5c4526") },
  { id: "Q6", title: "配色違い(濃いめ)", desc: "コントラスト強め", svg: illust_svg(main: "歩", fill: "#eccf8f", stroke: "#8a5a28", ink: "#3a230f") },
  { id: "Q7", title: "成香 + 赤字", desc: "木地・枠はそのまま、成の文字(バッジ+地の文字)だけ赤に", svg: illust_svg(main: "香", badge: "成", ink: "#c0392b", badge_ink: "#c0392b") },
].freeze

def illust_card(v)
  sizes = [72, 40, 28, 20]
  cells = sizes.map do |px|
    <<~HTML
      <div class="size-cell">
        <div class="variant-glyph" style="width:#{px}px;height:#{px}px">#{v[:svg]}</div>
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

illust_rows = ILLUST_VARIANTS.map { |v| illust_card(v) }.join

# --- 成駒バッジの改善案比較 -------------------------------------------------

GOTHIC = "'Hiragino Sans', 'Yu Gothic', sans-serif"
SOSHO = "'Yuji Boku', serif"
SOSHO_LIGHT = "'Yuji Syuku', serif"
SOSHO_FLOW = "'Yuji Mai', serif"
PENTAGON = "M 50,4 L 88,26 L 93,96 L 7,96 L 12,26 Z"

def variant_svg(main:, badge: nil, badge_font: MINCHO, badge_size: 15, badge_x: 50, badge_y: 21,
                main_size: 46, main_y: 57, main_font: MINCHO, main_style: nil,
                double_border: false, tint: nil, divider: false, notch: false)
  # 輪郭(border)は常にテーマの標準色(currentColor)。tint は文字色だけに効く。
  # ※ 実フォントで枠と文字を別色にするには単色グリフでは不可能で、COLR/CPAL
  #   のようなカラーフォント形式が要る。ここではプレビュー上の見た目確認用。
  border_color = "currentColor"
  text_color = tint || "currentColor"

  border = if double_border
             %(<path d="#{PENTAGON}" fill="none" stroke="#{border_color}" stroke-width="3"/>
               <path d="M 50,10 L 82,29 L 87,91 L 13,91 L 18,29 Z" fill="none" stroke="#{border_color}" stroke-width="2"/>)
           elsif notch
             %(<path d="M 50,4 L 88,26 L 93,96 L 76,96 L 76,88 L 24,88 L 24,96 L 7,96 L 12,26 Z" fill="none" stroke="#{border_color}" stroke-width="4" stroke-linejoin="round"/>)
           else
             %(<path d="#{PENTAGON}" fill="none" stroke="#{border_color}" stroke-width="4" stroke-linejoin="round"/>)
           end

  style_attr = main_style ? %( font-style="#{main_style}") : ""

  badge_markup = if badge
                   %(<text x="#{badge_x}" y="#{badge_y}" font-size="#{badge_size}" font-family="#{badge_font}" font-weight="800" fill="#{text_color}" text-anchor="middle" dominant-baseline="central">#{badge}</text>)
                 else
                   ""
                 end
  divider_markup = divider ? %(<line x1="32" y1="31" x2="68" y2="31" stroke="#{text_color}" stroke-width="2"/>) : ""

  <<~SVG
    <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
      <g>
        #{border}
        #{badge_markup}
        #{divider_markup}
        <text x="50" y="#{main_y}" font-size="#{main_size}" font-family="#{main_font}" font-weight="700" fill="#{text_color}" text-anchor="middle" dominant-baseline="central"#{style_attr}>#{main}</text>
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
  { id: "H", title: "色分け(レンダラー案)", desc: "バッジなし、枠は黒のまま文字だけ色を変える(フォントとは別レイヤー)", svg: variant_svg(main: "香", tint: "#b0402c") },
  { id: "I", title: "斜体(バッジなし)", desc: "成り駒だけ字を傾ける", svg: variant_svg(main: "香", main_style: "italic") },
  { id: "J", title: "草書体バッジ", desc: "「成」だけ毛筆(Yuji Boku)に、地の文字は明朝のまま", svg: variant_svg(main: "香", badge: "成", badge_font: SOSHO, badge_size: 19, badge_y: 20) },
  { id: "K", title: "草書体(駒全体)", desc: "「成」も地の文字も毛筆に。実物の駒に近い雰囲気", svg: variant_svg(main: "香", badge: "成", badge_font: SOSHO, badge_size: 19, badge_y: 20, main_font: SOSHO) },
  { id: "L", title: "草書体のみ(バッジなし)", desc: "バッジを足さず、字そのものを毛筆にして差別化", svg: variant_svg(main: "香", main_font: SOSHO) },
  { id: "M", title: "細字の草書(駒全体)", desc: "Yuji Syuku。繊細・行書寄りの崩し", svg: variant_svg(main: "香", badge: "成", badge_font: SOSHO_LIGHT, badge_size: 19, badge_y: 20, main_font: SOSHO_LIGHT) },
  { id: "N", title: "流れる草書(駒全体)", desc: "Yuji Mai。舞うような、より大きく崩れた字形", svg: variant_svg(main: "香", badge: "成", badge_font: SOSHO_FLOW, badge_size: 19, badge_y: 20, main_font: SOSHO_FLOW) },
  { id: "O", title: "流れる草書(バッジなし)", desc: "Yuji Mai を地の文字だけに使う", svg: variant_svg(main: "香", main_font: SOSHO_FLOW) },
  { id: "P", title: "M案 + 赤字", desc: "Yuji Syuku、枠は黒のまま「成」と地の文字だけ赤色に", svg: variant_svg(main: "香", badge: "成", badge_font: SOSHO_LIGHT, badge_size: 19, badge_y: 20, main_font: SOSHO_LIGHT, tint: "#c0392b") },
].freeze

def variant_card(v)
  sizes = [56, 32, 22, 16]
  cells = sizes.map do |px|
    <<~HTML
      <div class="size-cell">
        <div class="variant-glyph" style="width:#{px}px;height:#{px}px">#{v[:svg]}</div>
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
    .variant-glyph { color: var(--ink); }
    .variant-glyph svg { width: 100%; height: 100%; display: block; }
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
        <h2>イラスト調(色付き・丸み)試作</h2>
        <span>いらすとやの将棋駒イラストの雰囲気を参考に</span>
      </div>
      <div class="variant-list">
        #{illust_rows}
      </div>
    </section>

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
