# 1問分の出題進行(選択肢の組み立てと正誤判定)を受け持つ。
# タイマーや画面表示は CLI/Renderer 側の責務とし、ここではロジックのみ扱う。
class Game
  Round = Data.define(:puzzle, :choices, :correct_index)

  def initialize(puzzles)
    @puzzles = puzzles
  end

  def total
    @puzzles.size
  end

  def each_round
    @puzzles.each_with_index do |puzzle, i|
      yield build_round(puzzle), i + 1
    end
  end

  def build_round(puzzle)
    options = [puzzle.answer] + puzzle.wrong_choices
    shuffled = options.shuffle
    correct_index = shuffled.index(puzzle.answer)
    Round.new(puzzle, shuffled, correct_index)
  end
end
