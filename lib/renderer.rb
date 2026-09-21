require_relative "sfen"

# 盤面・持ち駒・選択肢などターミナル表示を一手に引き受けるクラス。
# 駒グリフの文字マッピングはテーマ(text/pua)ごとに分離してあり、
# ゲームロジック側はテーマの詳細を意識しなくてよい。
class Renderer
  CLEAR_SCREEN = "\e[2J\e[H".freeze

  KIND_ORDER = %i[fu kyo kei gin kin kaku hisha gyoku to narikyo narikei narigin uma ryu].freeze

  TEXT_KANJI = {
    fu: "歩", kyo: "香", kei: "桂", gin: "銀", kin: "金", kaku: "角", hisha: "飛", gyoku: "玉",
    to: "と", narikyo: "成香", narikei: "成桂", narigin: "成銀", uma: "馬", ryu: "龍"
  }.freeze

  PUA_SENTE_BASE = 0xE000
  PUA_GOTE_OFFSET = 0x0100
  PUA_KIND_INDEX = {
    fu: 0, kyo: 1, kei: 2, gin: 3, kin: 4, kaku: 5, hisha: 6, gyoku: 7,
    to: 8, narikyo: 9, narikei: 10, narigin: 11, uma: 12, ryu: 13
  }.freeze
  def initialize(theme: :text)
    @theme = theme
  end

  def clear_screen
    print CLEAR_SCREEN
  end

  # theme が :text のときは仕様書に確定済みの board_text をそのまま使う。
  # :pua のときは SFEN から組み立てて PUA コードポイントで描画する。
  def render_board(puzzle)
    if @theme == :pua
      render_pua_board(puzzle)
    else
      puzzle.board_text
    end
  end

  def render_pua_board(puzzle)
    parsed = Sfen.parse(puzzle.sfen)
    lines = []
    lines << format_hand_line(parsed[:hand], :gote)
    lines << "  ９ ８ ７ ６ ５ ４ ３ ２ １"
    lines << BOARD_BORDER
    parsed[:board].each_with_index do |rank_cells, rank_index|
      cells = rank_cells.map { |cell| cell.nil? ? "・" : piece_glyph(cell.owner, cell.kind) }
      lines << "| #{cells.join(' ')}|#{Sfen::RANK_KANJI[rank_index]}"
    end
    lines << BOARD_BORDER
    lines << format_hand_line(parsed[:hand], :sente)
    lines.join("\n")
  end

  # 駒(PUAコードポイント)は Unicode East Asian Width が未定義(Ambiguous)
  # で、全角2カラムとして描画されるかはターミナル側の設定次第(iTerm2の
  # 「Ambiguous characters are double-width」推奨。font/README.md 参照)。
  # 一方「・」や全角数字はUnicode上 Wide/Fullwidth に確定分類されており、
  # 上記設定と関係なく常に全角2カラムで描画されるため、駒専用フォントに
  # 頼らずシステムフォント任せのままでよい。罫線はこの前提(駒もAmbiguous
  # 設定により全角2カラム)で「| 」(2)+9マス×2(18)+区切りスペース8個(8)+
  # 「|」(1)=29カラムに合わせている。
  BOARD_BORDER = "+---------------------------+".freeze

  def piece_glyph(owner, kind)
    if @theme == :pua
      base = owner == :gote ? PUA_SENTE_BASE + PUA_GOTE_OFFSET : PUA_SENTE_BASE
      [base + PUA_KIND_INDEX.fetch(kind)].pack("U")
    else
      kanji = TEXT_KANJI.fetch(kind)
      owner == :gote ? "v#{kanji}" : kanji
    end
  end

  def format_hand_line(hand, owner)
    label = owner == :gote ? "後手の持駒：" : "先手の持駒："
    pieces = KIND_ORDER.map do |kind|
      count = hand[[owner, kind]]
      next if count.nil? || count.zero?

      count > 1 ? "#{piece_glyph(owner, kind)}#{count}" : piece_glyph(owner, kind)
    end.compact
    return "#{label}　なし" if pieces.empty?

    "#{label}　#{pieces.join(' ')}"
  end

  def render_progress(index, total)
    "第#{index}問 / 全#{total}問"
  end

  def render_choices(choices)
    lines = ["次の一手は?"]
    choices.each_with_index { |choice, i| lines << "  #{i + 1}. #{choice}" }
    lines.join("\n")
  end
end
