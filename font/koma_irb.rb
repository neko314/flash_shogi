# irb起動時にコードポイント対応表を読み込んでおくためのヘルパー。
#
# 使い方:
#   irb -r ./font/koma_irb.rb
#   irb(main)> koma("sente-gyoku")
#   irb(main)> koma_list  # 名前一覧を確認したいとき

require "json"

MANIFEST_PATH = File.join(__dir__, "glyph_manifest.json")
KOMA_CODEPOINTS = JSON.parse(File.read(MANIFEST_PATH))["glyphs"].each_with_object({}) do |g, h|
  h[g["name"]] = g["codepoint"]
end

def koma(name)
  codepoint = KOMA_CODEPOINTS.fetch(name.to_s) do
    raise "不明な駒名です: #{name.inspect}（koma_list で一覧を確認できます）"
  end
  [codepoint].pack("U")
end

def koma_list
  KOMA_CODEPOINTS.each { |name, cp| puts format("%-16s U+%04X  %s", name, cp, [cp].pack("U")) }
  nil
end

IRB.conf[:INSPECT_MODE] = false if defined?(IRB) # 結果表示からクオーテーションを外す(to_s表示にする)

puts "koma(\"sente-gyoku\") のように駒名を指定すると表示されます。koma_list で一覧表示できます。"
