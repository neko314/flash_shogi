require "io/console"

# 60秒間の盤面表示待機を担当する。Enterキーで早送りできる。
module Timer
  POLL_INTERVAL = 0.1
  POLLS_PER_SECOND = (1.0 / POLL_INTERVAL).round

  # seconds 秒間、1秒ごとにカウントダウンを再描画しながら待つ。
  # Enter が押されたら即座に戻る。
  def self.countdown(seconds, out: $stdout)
    begin
      $stdin.raw(intr: true) do |raw_stdin|
        catch(:skip) do
          seconds.downto(1) do |remaining|
            out.print "\r残り #{remaining.to_s.rjust(2)} 秒 (Enterで次へ進めます) "
            out.flush

            POLLS_PER_SECOND.times do
              ready = IO.select([raw_stdin], nil, nil, POLL_INTERVAL)
              next unless ready

              key = raw_stdin.getc
              # key が nil の場合は標準入力の EOF。以後 select が即座に
              # 真を返し続けて空回りするだけなので、待機自体を打ち切る。
              throw :skip if key.nil? || key == "\r" || key == "\n"
            end
          end
        end
      end
    rescue Errno::ENOTTY, IOError
      # 標準入力が tty ではない(パイプ/リダイレクト)場合は raw モードにできないため
      # 単純に sleep して待機する。
      sleep(seconds)
    end
    out.print "\r" + (" " * 50) + "\r"
  end
end
