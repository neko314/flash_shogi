require "minitest/autorun"
require_relative "../lib/puzzle_store"
require_relative "../lib/sfen"
require_relative "../lib/renderer"
require_relative "../lib/game"
require_relative "../lib/cli"

class FlashShogiTest < Minitest::Test
  DATA_PATH = File.join(__dir__, "..", "data", "puzzles.json")

  def setup
    @puzzles = PuzzleStore.load(DATA_PATH)
  end

  def test_loads_all_puzzles
    assert_equal 20, @puzzles.size
  end

  def test_each_puzzle_has_required_fields
    @puzzles.each do |puzzle|
      assert puzzle.id
      assert puzzle.answer
      assert_equal 2, puzzle.wrong_choices.size
      refute_includes puzzle.wrong_choices, puzzle.answer
    end
  end

  def test_sfen_parses_gote_king_position_for_p1
    p1 = @puzzles.find { |p| p.id == "P1" }
    parsed = Sfen.parse(p1.sfen)
    king = parsed[:board][0][1]
    assert_equal :gote, king.owner
    assert_equal :gyoku, king.kind
    assert_equal 1, parsed[:hand][[:sente, :kin]]
  end

  def test_text_theme_matches_stored_board_text
    renderer = Renderer.new(theme: :text)
    @puzzles.each do |puzzle|
      assert_equal puzzle.board_text, renderer.render_board(puzzle)
    end
  end

  def test_pua_theme_uses_expected_codepoint_for_sente_gyoku
    renderer = Renderer.new(theme: :pua)
    assert_equal [0xE007].pack("U"), renderer.piece_glyph(:sente, :gyoku)
    assert_equal [0xE107].pack("U"), renderer.piece_glyph(:gote, :gyoku)
  end

  def test_build_round_shuffles_but_keeps_answer_present
    game = Game.new(@puzzles)
    puzzle = @puzzles.first
    round = game.build_round(puzzle)

    assert_equal 3, round.choices.size
    assert_includes round.choices, puzzle.answer
    assert_equal puzzle.answer, round.choices[round.correct_index]
  end

  def test_cli_defaults_to_five_random_puzzles
    cli = CLI.new(data_path: DATA_PATH)
    puzzles = cli.instance_variable_get(:@puzzles)

    assert_equal 5, puzzles.size
    assert_equal puzzles.map(&:id).uniq.size, puzzles.size
  end

  def test_cli_accepts_custom_question_count
    cli = CLI.new(data_path: DATA_PATH, question_count: 3)

    assert_equal 3, cli.instance_variable_get(:@puzzles).size
  end

  def test_cli_accepts_custom_seconds
    cli = CLI.new(data_path: DATA_PATH, seconds: 10)

    assert_equal 10, cli.instance_variable_get(:@seconds)
  end
end
