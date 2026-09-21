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
  # 空きマス記号「・」、筋番号ヘッダー(１〜９)専用グリフ。ベースフォント
  # 任せの文字だと駒グリフと幅が一致せず盤面の列・ヘッダーがズレることが
  # あるため、駒と同じ幅で作った専用のPUAグリフを使う(font/README.md 参照)。
  PUA_EMPTY_CODEPOINT = 0xE200
  PUA_DIGIT_BASE = 0xE201 # 0xE201='1' 〜 0xE209='9'

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
    lines << "  #{header_digits}"
    lines << border_line
    parsed[:board].each_with_index do |rank_cells, rank_index|
      cells = rank_cells.map { |cell| cell.nil? ? empty_glyph : piece_glyph(cell.owner, cell.kind) }
      lines << "| #{cells.join(' ')}|#{Sfen::RANK_KANJI[rank_index]}"
    end
    lines << border_line
    lines << format_hand_line(parsed[:hand], :sente)
    lines.join("\n")
  end

  # 罫線の長さ: 駒・空きマス・ヘッダー数字のPUAコードポイントは、Unicodeの
  # East Asian Width が未定義(Ambiguous)のため、ターミナル側の設定次第で
  # 全角2カラムとして描画されたり半角1カラムとして描画されたりする。
  # 全角2カラム前提(iTerm2で「Ambiguous characters are double-width」を
  # 有効にした場合など)なら「| 」(2)+9マス×2(18)+区切りスペース8個(8)+
  # 「|」(1)=29カラム。半角1カラム扱い(Terminal.appの既定)の場合は
  # 20カラムになる(font/README.md 参照)。ここでは全角2カラムを前提にする。
  BOARD_BORDER = "+---------------------------+".freeze

  def border_line
    BOARD_BORDER
  end

  def empty_glyph
    @theme == :pua ? [PUA_EMPTY_CODEPOINT].pack("U") : "・"
  end

  FULL_WIDTH_DIGITS = "０１２３４５６７８９".freeze

  def digit_glyph(n)
    @theme == :pua ? [PUA_DIGIT_BASE + n - 1].pack("U") : FULL_WIDTH_DIGITS[n]
  end

  def header_digits
    9.downto(1).map { |n| digit_glyph(n) }.join(" ")
  end

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
