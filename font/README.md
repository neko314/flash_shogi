# PUA駒グリフ (開発中)

将棋駒を PUA (Private Use Area, `U+E000`–`U+E10D`) に割り当てた自作フォント用の
素材置き場。引き継ぎ仕様書 4-3〜4-6 節の方針に沿っている。

## 現状

- **COLR/CPALカラーフォントとして実際に動くところまで完成**(`font/build/FlashShogiPua.ttf`)
- 先手14種・後手14種、計28コードポイントすべてに、クリーム地・木の縁・
  こげ茶/赤の文字という色付きデザインが入っている
- macOSにインストール済み、Terminal.appでの表示も確認済み
  (`~/Library/Fonts/` に配置。インストール方法・注意点は下記)
- `../lib/renderer.rb` の `pua` テーマは、このコードポイント表と同じ規則
  (`SENTE_BASE=0xE000` / `GOTE_OFFSET=0x0100`) で実装済みなので、フォントさえ
  導入すればアプリ側の対応は不要
- **普段使いのフォントに駒グリフを合体させるツール(`merge_glyphs.py`)も完成**。
  Terminal.appは1プロファイルにつき1フォントしか設定できず、PUAフォント単体を
  指定すると他の文字の見た目が崩れる問題があったため、Nerd Fontsと同じ要領で
  普段使っているフォント(Fira Code, Menloで動作確認済み)に駒グリフだけを
  追加注入する方式にした。詳細は「普段使っているフォントと合体させる」節
- 空きマス記号「・」・筋番号ヘッダー(全角１〜９)も、駒と同じ幅を保証する
  専用PUAグリフ(`U+E200`〜`U+E209`)にしている。ベースフォント任せだと
  幅が合わず盤面がズレたため
- **重要な既知の制約**: 駒・空きマス・ヘッダー数字はPUA(Private Use Area)の
  ため Unicode の East Asian Width が未定義(Ambiguous)で、ターミナルが
  全角2カラムとして扱うか半角1カラムとして扱うかは実装依存。
  **Terminal.appは半角1カラム固定でこれを変更する設定が無い**。
  **iTerm2は「Profiles → Text → Ambiguous characters are
  double-width」で全角2カラム扱いに切り替えられ、これで正しく表示できる
  ことを確認済み**。そのためPUAテーマは iTerm2(要Ambiguous Width設定)を
  推奨とする。Terminal.appで使う場合は罫線幅の調整が必要
  (`lib/renderer.rb` の `BOARD_BORDER` 参照)

## デザイン仕様(確定)

`preview.html` の「イラスト調(色付き・丸み)試作」Q1(通常駒)/Q7(成駒)案がベース。

- 地色 `#f5e2b8`(クリーム)、縁 `#b9824a`(木の色)、縁の太さ 3px
- 五角形の角は丸めすぎない(半径4、ほぼ尖った形を保つ)
- 文字はヒラギノ明朝 ProN W6 の輪郭を抽出して使用(太めのウェイト)
  - さらに疑似ボールド化のため、文字の輪郭に同色の縁取り(`CHAR_BOLD_STROKE`、
    SVG座標で1.6)を足して太くしている
  - 文字サイズは駒との余白ができるだけ小さくなるよう大きめ(地の文字46→62、
    バッジ15→20、`extract_glyphs.py` の `MAIN_SIZE`/`BADGE_SIZE`)
- 通常駒の文字色は `#4a3016`(こげ茶)
- **成駒(と・成香・成桂・成銀・馬・龍)は文字色だけ `#c0392b`(赤)にする**。
  地色・縁は変えない。COLR/CPALのレイヤー分けで実現(下記参照)
- 成香・成桂・成銀は「小さい"成"バッジ + 通常サイズの地の文字」方式
  (二文字を均等に積むと小さいサイズで読みにくいため)

## ビルドパイプライン

自動生成なので、`.svg`/`.ttf` 系のファイルは直接編集せず、必ずスクリプト経由で
再生成すること。フロー:

```
extract_glyphs.py  (システムフォントから漢字の輪郭をパス抽出)
        ↓ font/glyph_paths.json
generate_svg.rb     (五角形+文字のSVGを組み立て。単色版とCOLR用レイヤー版の両方)
        ↓ font/svg/*.svg (単色フォールバック用)
        ↓ font/svg_layers/*.svg (COLR用レイヤー: body/border/char)
        ↓ font/glyph_manifest.json (コードポイント・レイヤー構成)
build_font_color.py stage1  (FontForge: SVGを輪郭としてTTFに詰める。色はまだ無い)
        ↓ font/build/FlashShogiPua.stage1.ttf
build_font_color.py stage2  (fontTools: COLR/CPALテーブルを追加)
        ↓ font/build/FlashShogiPua.ttf  ← 最終成果物
```

再生成する場合:

```bash
# 1. 文字の輪郭を(必要なら)再抽出
font/.venv/bin/python3 font/extract_glyphs.py

# 2. SVGを組み立て直す
ruby font/generate_svg.rb

# 3. FontForgeで輪郭をTTFに(fontforgeコマンドが必要: brew install fontforge)
fontforge -script font/build_font_color.py stage1

# 4. COLR/CPALを追加して完成
font/.venv/bin/python3 font/build_font_color.py stage2

# 5. インストール(上書き)
cp font/build/FlashShogiPua.ttf ~/Library/Fonts/FlashShogiPua.ttf
```

`font/.venv/` は `fontTools` 用の venv(`python3 -m venv font/.venv && font/.venv/bin/pip install fonttools`
で作成済み)。FontForge自体は Homebrew の CLI 版(`brew install fontforge`、
GUIアプリは別、CLIのみで足りる)。

### なぜこんなに手順が分かれているか(ハマったポイント)

- **SVGの `<text>` はFontForgeに取り込めない**。文字はあらかじめ輪郭(パス)化
  しておく必要がある。`extract_glyphs.py` がヒラギノ明朝からfontToolsで
  直接パスを抽出している(FontForge自身のCID/CJKフォントへのUnicodeアクセスは
  不安定だったため、fontToolsのcmap解決を使うほうが確実だった)
- **FontForgeのSVG取り込みは、塗り(fill)同士が重なると重なった側が消える**。
  巻き方向次第で文字が駒の地色に埋もれて見えなくなる不具合を確認した。
  そのため単色フォールバック版は「五角形は線のみ(塗りなし)、文字は塗りのみ」
  にして重ならせないことで回避している
- **`<g transform="rotate(180 50 50)">` はFontForgeのauto-scale計算と噛み合わず、
  後手側の座標が大きくずれる**。回転はSVGのtransformに任せず、
  `extract_glyphs.py`/`generate_svg.rb` 側であらかじめ180°回転した座標を
  計算して埋め込んでいる
- **COLR/CPALはFontForge単体では組みにくい**ので、輪郭の取り込みまでは
  FontForge、色レイヤー(COLR)とパレット(CPAL)の追加は `fontTools.colorLib.builder`
  という2段階構成にした
- **macOSのフォントキャッシュ**: 同じフォント名のままファイルだけ上書きすると、
  Terminal.appや他アプリが古い描画をキャッシュしたままで変更が反映されない
  ことがある(実際に発生した)。対処法は次の節を参照

## macOSでの表示確認・キャッシュ対策

1. `.ttf` を `~/Library/Fonts/` に置く(コピーするだけでよい。Font Book経由の
   ダブルクリックインストールでも可)
2. ターミナルのプロファイル設定でフォントを `Flash Shogi PUA` に指定する
3. `ruby bin/flash_shogi --theme=pua` を実行して確認する

**更新しても変化が見えないとき**(フォント名・ファイルは同じまま中身だけ
差し替えた場合に発生しやすい):

- Terminal.appを完全に終了(`Cmd+Q`)してから開き直す
- それでも変わらなければ、Font Bookで一旦削除→ `.ttf` をダブルクリックして
  再インストール
- それでも変わらなければ、**フォント内部名を一時的に変える**のが一番確実。
  開発中は `FlashShogiPuaDevN` のように末尾に版数を振って、ターミナル側の
  フォント指定をその都度切り替えるとキャッシュを踏まずに確認できる
  (本セッションでもこれで解決した)
- 恒久的には `sudo pkill -9 fontd` でフォントデーモンを再起動させる方法もある
  (要sudo、ユーザー自身の実行推奨)

## 普段使っているフォントと合体させる

Terminal.appは1プロファイルにつき1フォントしか選べない。`Flash Shogi PUA`
単体を指定すると、駒以外の文字(アルファベット・記号など)がOS任せの代替
フォントで表示されて見た目が崩れる。

**Ghostty / kitty / iTerm2 を使っている場合はこの節は不要**。これらは
「特定のUnicode範囲だけ別フォントを使う」設定ができる(例: kittyの
`symbol_map`)。普段のフォント + `Flash Shogi PUA` を設定ファイルに数行
書くだけで済み、フォントを合体させる必要はない。具体的な設定例は
「次の工程」に追記予定。

Terminal.appの場合は、Nerd Fontsと同じ要領で **普段使っているフォントに
駒グリフだけを追加注入した1本のフォント** を作るのが確実。

```bash
font/.venv/bin/python3 font/merge_glyphs.py <普段使っているフォントのパス> [出力先]
```

例:

```bash
# Fira Code (可変フォント) の例
font/.venv/bin/python3 font/merge_glyphs.py \
  ~/Library/Fonts/FiraCode-VariableFont_wght.ttf \
  font/build/FiraCodeShogi.ttf

# .ttc(複数書体入りコレクション)の場合は先にfontToolsで1書体を取り出す
font/.venv/bin/python3 -c "
from fontTools.ttLib import TTFont
TTFont('/System/Library/Fonts/Menlo.ttc', fontNumber=0).save('font/build/MenloRegular.ttf')
"
font/.venv/bin/python3 font/merge_glyphs.py font/build/MenloRegular.ttf font/build/MenloShogi.ttf

cp font/build/FiraCodeShogi.ttf ~/Library/Fonts/
```

出来上がるフォントは「(元のフォント名) Shogi」という名前になり(例:
`Fira Code Light Shogi`)、元のフォントとは別物として選べる。普段の文字は
元のフォントと完全に同じ見た目のまま、U+E000–U+E10DだけPUAフォントの
色付きグリフに置き換わる。

### ハマったポイント

- **グリフ名の衝突**: FontForgeが自動生成する `.notdef`/`.null`/
  `nonmarkingreturn` は多くのフォントに同名グリフとしてすでに存在する。
  `merge_glyphs.py` は `sente-`/`gote-` で始まるグリフだけを対象にすることで回避している
- **可変フォントの`gvar`テーブル**: `gvar` はフォント内の全グリフ分の
  エントリが揃っている前提で読み書きされる。追加したPUAグリフの分を
  登録せずにいると、グリフ数の不一致で `gvar` の解釈全体が壊れ、
  COLR(色)や一部グリフの表示がおかしくなる(実際にこれで色化けと
  文字の欠落が起きた)。追加グリフには空の変形データ(`variations[name] = []`
  = ウェイトを変えても形が変わらない)を明示的に登録して回避している
- **CPALのColorは(blue, green, red, alpha)の並び**: fontToolsの
  `Color` namedtupleは、CPALバイナリ形式に合わせてBGRA順のフィールドを
  持つ。位置的に`tuple(c for c in color)`のようにタプル展開するとRとBが
  入れ替わって色化けする。`.red`/`.green`/`.blue`/`.alpha`のように
  フィールド名でアクセスすること
- ベースフォントの実際の等幅セル幅は `hmtx` の 'A' 等から推定している
  (`unitsPerEm`はフォントごとに異なるので、駒グリフはその比率でスケールし、
  半角文字ちょうど2つ分の送り幅になるよう調整している)

## コードポイント対応表

| 駒種 | key | 先手 | 後手 |
|---|---|---|---|
| 歩 | fu | U+E000 | U+E100 |
| 香 | kyo | U+E001 | U+E101 |
| 桂 | kei | U+E002 | U+E102 |
| 銀 | gin | U+E003 | U+E103 |
| 金 | kin | U+E004 | U+E104 |
| 角 | kaku | U+E005 | U+E105 |
| 飛 | hisha | U+E006 | U+E106 |
| 玉 | gyoku | U+E007 | U+E107 |
| と | to | U+E008 | U+E108 |
| 成香 | narikyo | U+E009 | U+E109 |
| 成桂 | narikei | U+E00A | U+E10A |
| 成銀 | narigin | U+E00B | U+E10B |
| 馬 | uma | U+E00C | U+E10C |
| 龍 | ryu | U+E00D | U+E10D |

後手 = 先手 + `0x0100`。後手グリフは先手グリフを180°回転したもの(同じ輪郭・同じ文字)。

盤面まわりの記号(先手/後手の区別なし、回転不要):

| 記号 | コードポイント |
|---|---|
| 空きマス「・」 | U+E200 |
| ヘッダー数字「１」 | U+E201 |
| ヘッダー数字「２」 | U+E202 |
| ヘッダー数字「３」 | U+E203 |
| ヘッダー数字「４」 | U+E204 |
| ヘッダー数字「５」 | U+E205 |
| ヘッダー数字「６」 | U+E206 |
| ヘッダー数字「７」 | U+E207 |
| ヘッダー数字「８」 | U+E208 |
| ヘッダー数字「９」 | U+E209 |

## デザインを調整する

- 色・線の太さ・角の丸み: `generate_svg.rb` の `FILL`/`STROKE`/`INK`/`PROMOTED_INK`/
  `ROUND_RADIUS` を編集
- 文字サイズ・位置・太さ: `extract_glyphs.py` の `MAIN_Y`/`MAIN_SIZE`/`BADGE_Y`/
  `BADGE_SIZE`、`generate_svg.rb` の `CHAR_BOLD_STROKE` を編集
- 編集したら上記「ビルドパイプライン」の1〜5を再実行する
- ブラウザでの見た目確認だけなら `ruby build_preview.rb` で `preview.html` を
  再生成すれば十分(FontForgeのビルドは不要)。実際の色付きレンダリングを
  ブラウザで見たい場合は `font/colr_test.html` のように
  `@font-face` で `font/build/FlashShogiPua.ttf` を読み込むテストページを使う

## 検討過程のメモ

デザインが固まるまでに比較した案。`preview.html` に比較セクションとして残してある。

- 絵柄の方向性: 当初は線画(輪郭のみ)だったが、いらすとや(irasutofree.com)の
  「将棋駒34点セット」イラスト(著作権の都合で素材そのものは使わない、雰囲気の
  み参考)を見て、クリーム〜薄茶色の暖色・イラスト調に転換。丸ゴシックも試したが
  最終的に明朝体に戻した
- バッジ/地の文字の書体は草書体系(Yuji Boku/Syuku/Mai)も試したが、最終的には
  通常の明朝体(Hiragino Mincho)を採用
- 成り駒の色分け方法(枠ごと赤にする案・文字だけ赤にする案)を比較し、
  「枠は変えず文字だけ赤」に確定
- **保留**: 本物の「行書体」が欲しくなった場合、Google Fonts には行書体として
  明示されたフォントが無い。SCREEN/モリサワの商用フォント「ヒラギノ行書」
  (StdN W4/W8)は本物の行書体だが有料でこのMacには未インストール。使いたく
  なったら購入して `extract_glyphs.py` の `FONT_PATH`/`FONT_NUMBER` を
  差し替えて字形のトレース元にする

## 次の工程(未着手)

1. Ghostty / kitty でも「Ambiguous Width」相当の設定と表示を確認する
   (iTerm2・Terminal.appは確認済み。iTerm2が現状の最有力)
2. デザインが最終確定したら、開発用の `FlashShogiPuaDevN` ではなく正式名で
   ビルドし直す
3. 気になる駒(特に画数の多い龍・馬など)があれば個別に調整する
4. 配布(公開)する場合、`merge_glyphs.py` の使い方と対応表・iTerm2の
   Ambiguous Width設定を独立したユーザー向け手順としてまとめる

推奨ターミナル優先順位: Ghostty > kitty > iTerm2 > Terminal.app(補助的)。
