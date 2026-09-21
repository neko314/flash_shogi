# PUA駒グリフ (開発中)

将棋駒を PUA (Private Use Area, `U+E000`–`U+E10D`) に割り当てた自作フォント用の
素材置き場。引き継ぎ仕様書 4-3〜4-6 節の方針に沿っている。

## 現状

- `svg/` に先手14種・後手14種、計28個のプレースホルダー SVG を生成済み
- まだ「五角形の輪郭 + システムフォントの漢字」だけの仮デザイン
- `../lib/renderer.rb` の `pua` テーマは、このコードポイント表と同じ規則
  (`SENTE_BASE=0xE000` / `GOTE_OFFSET=0x0100`) で実装済みなので、フォントさえ
  導入すればアプリ側の対応は不要

## ファイル

- `generate_svg.rb` — プレースホルダー SVG 28個を `svg/` に生成するスクリプト
- `build_preview.rb` — `svg/` の中身を読み込んでブラウザ確認用の `preview.html` を組み立てるスクリプト
- `svg/<sente|gote>-<key>.svg` — 個々のグリフ(1グリフ1ファイル)
- `preview.html` — 生成物のプレビュー(要 `ruby build_preview.rb` で再生成)

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

後手 = 先手 + `0x0100`。後手グリフは先手グリフを180°回転しただけ(同じ輪郭・同じ文字)。

## デザインを差し替える

1. `svg/sente-fu.svg` など、差し替えたいグリフと同じファイル名で SVG を上書きする
   - `viewBox="0 0 100 100"` を保つと他のグリフと比率が揃う
   - 後手版は `gote-<key>.svg` を個別に用意する(単純な180°回転で機械生成してもよいし、
     手描きで別グリフにしてもよい)
2. `ruby build_preview.rb` で `preview.html` を再生成して見た目を確認する

## 次の工程(未着手)

1. SVG を手描きデザインに差し替える(今回はここから)
2. FontForge で SVG を読み込み、上表のコードポイントに割り当てて OTF/TTF を生成する
   - SVG の `<text>` はそのままだとフォント側に文字として取り込まれない可能性があるため、
     取り込み時にアウトライン化(パス化)するか、FontForge 側で該当漢字のグリフを
     複製して五角形と合成する方法を検討する
3. macOS に Font Book 経由でインストールする
4. Ghostty / kitty / iTerm2 などで `ruby bin/flash_shogi --theme=pua` を実行して確認する

推奨ターミナル優先順位: Ghostty > kitty > iTerm2 > Terminal.app(補助的)。
