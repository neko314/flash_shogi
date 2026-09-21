require_relative "puzzle_store"
require_relative "renderer"
require_relative "timer"
require_relative "game"

class CLI
  DEFAULT_DATA_PATH = File.join(__dir__, "..", "data", "puzzles.json")
  DISPLAY_SECONDS = 60

  def initialize(theme: :text, data_path: DEFAULT_DATA_PATH, seconds: DISPLAY_SECONDS)
    @renderer = Renderer.new(theme: theme)
    @puzzles = PuzzleStore.load(data_path)
    @game = Game.new(@puzzles)
    @seconds = seconds
    @score = 0
  end

  def run
    print_intro
    @game.each_round do |round, index|
      play_round(round, index)
    end
    print_result
  end

  private

  def print_intro
    @renderer.clear_screen
    puts "フラッシュ詰将棋 CLI"
    puts "盤面が #{@seconds} 秒表示されたあと、3択で正解を選んでください。"
    puts "Enter キーで表示を早送りできます。準備ができたら Enter を押してください。"
    $stdin.gets
  end

  def play_round(round, index)
    puzzle = round.puzzle

    @renderer.clear_screen
    puts @renderer.render_progress(index, @game.total)
    puts "[#{puzzle.title}] 難易度: #{puzzle.difficulty}"
    puts
    puts @renderer.render_board(puzzle)
    puts
    Timer.countdown(@seconds)

    @renderer.clear_screen
    puts @renderer.render_progress(index, @game.total)
    puts @renderer.render_choices(round.choices)
    selected = read_choice
    judge(round, selected)

    puts
    puts "Enter で次の問題へ進みます..."
    $stdin.gets
  end

  def read_choice
    loop do
      print "> "
      $stdout.flush
      key = read_single_key
      if key.nil?
        puts
        abort "入力が終了したため中断します。"
      end

      if %w[1 2 3].include?(key)
        puts key
        return key.to_i
      end

      puts key.inspect
      puts "1・2・3 のいずれかを入力してください。"
    end
  end

  # 1文字を返す。標準入力が EOF に達した場合は nil を返す。
  def read_single_key
    $stdin.raw { |raw_stdin| raw_stdin.getc }
  rescue Errno::ENOTTY, IOError
    $stdin.gets&.strip
  end

  def judge(round, selected_number)
    selected_index = selected_number - 1
    correct = selected_index == round.correct_index
    @score += 1 if correct

    puts
    puts(correct ? "正解！" : "不正解")
    puts "正解手: #{round.puzzle.answer}"
    puts "解説: #{round.puzzle.explanation}"
  end

  def print_result
    @renderer.clear_screen
    puts "全#{@game.total}問終了"
    puts "正解数: #{@score} / #{@game.total}"
  end
end
