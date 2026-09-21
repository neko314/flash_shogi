require "json"

Puzzle = Data.define(
  :id, :title, :difficulty, :sfen, :board_text,
  :answer, :wrong_choices, :concept, :explanation, :verification
)

class PuzzleStore
  def self.load(path)
    raise "問題データが見つかりません: #{path}" unless File.exist?(path)

    raw = JSON.parse(File.read(path))
    raw.map { |entry| Puzzle.new(**entry.transform_keys(&:to_sym)) }
  rescue JSON::ParserError => e
    raise "問題データの読み込みに失敗しました: #{e.message}"
  end
end
