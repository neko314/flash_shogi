# irb起動時にコードポイント対応表を読み込んでおくためのヘルパー。
#
# 使い方:
#   irb -r ./font/koma_irb.rb
#   irb(main)> sente_gyoku       # 括弧・クオーテーションなしで直接呼べる
#   irb(main)> koma("sente-gyoku") # 駒名(ハイフン区切り)を文字列で渡す版
#   irb(main)> koma_list          # 名前一覧を確認したいとき

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

# ハイフンはRubyの演算子と衝突するため、駒名ごとに sente_gyoku のような
# アンダースコア区切りのメソッドを動的に定義し、括弧なしで直接呼べるようにする。
KOMA_CODEPOINTS.each_key do |name|
  define_singleton_method(name.tr("-", "_")) { koma(name) }
end

IRB.conf[:INSPECT_MODE] = false if defined?(IRB) # 結果表示からクオーテーションを外す(to_s表示にする)

puts "sente_gyoku のように駒名(アンダースコア区切り)を直接打つと表示されます。koma_list で一覧表示できます。"
