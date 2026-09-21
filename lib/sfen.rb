# SFEN(盤面)文字列を内部表現(9x9グリッド + 持ち駒)へ変換する。
# board[rank][file] の rank は 0="一"〜8="九"、file は 0=九筋〜8=一筋。
module Sfen
  PIECE_KIND_BY_LETTER = {
    "P" => :fu, "L" => :kyo, "N" => :kei, "S" => :gin,
    "G" => :kin, "B" => :kaku, "R" => :hisha, "K" => :gyoku
  }.freeze

  PROMOTED_KIND = {
    fu: :to, kyo: :narikyo, kei: :narikei, gin: :narigin,
    kaku: :uma, hisha: :ryu
  }.freeze

  RANK_KANJI = %w[一 二 三 四 五 六 七 八 九].freeze

  Piece = Data.define(:owner, :kind)

  def self.parse(sfen)
    board_part, turn_part, hand_part, = sfen.split(" ")
    { board: parse_board(board_part), turn: (turn_part == "b" ? :sente : :gote), hand: parse_hand(hand_part) }
  end

  def self.parse_board(board_part)
    board_part.split("/").map { |rank_str| parse_rank(rank_str) }
  end

  def self.parse_rank(rank_str)
    cells = []
    chars = rank_str.chars
    i = 0
    while i < chars.length
      c = chars[i]
      if c =~ /\d/
        num = c
        while i + 1 < chars.length && chars[i + 1] =~ /\d/
          i += 1
          num += chars[i]
        end
        num.to_i.times { cells << nil }
      elsif c == "+"
        i += 1
        letter = chars[i]
        owner = letter =~ /[A-Z]/ ? :sente : :gote
        base_kind = PIECE_KIND_BY_LETTER.fetch(letter.upcase)
        cells << Piece.new(owner, PROMOTED_KIND.fetch(base_kind))
      else
        owner = c =~ /[A-Z]/ ? :sente : :gote
        kind = PIECE_KIND_BY_LETTER.fetch(c.upcase)
        cells << Piece.new(owner, kind)
      end
      i += 1
    end
    cells
  end

  def self.parse_hand(hand_part)
    hand = Hash.new(0)
    return hand if hand_part.nil? || hand_part == "-"

    chars = hand_part.chars
    i = 0
    while i < chars.length
      c = chars[i]
      if c =~ /\d/
        num = c
        while i + 1 < chars.length && chars[i + 1] =~ /\d/
          i += 1
          num += chars[i]
        end
        count = num.to_i
        i += 1
        letter = chars[i]
        owner = letter =~ /[A-Z]/ ? :sente : :gote
        kind = PIECE_KIND_BY_LETTER.fetch(letter.upcase)
        hand[[owner, kind]] += count
      else
        owner = c =~ /[A-Z]/ ? :sente : :gote
        kind = PIECE_KIND_BY_LETTER.fetch(c.upcase)
        hand[[owner, kind]] += 1
      end
      i += 1
    end
    hand
  end
end
