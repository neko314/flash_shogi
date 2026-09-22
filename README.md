# フラッシュ詰将棋 CLI

ターミナル上で遊ぶ、一手詰めフラッシュ詰将棋ゲームです。
盤面を60秒間表示したあと消去し、正解手を3択(番号入力)で答えます。

## 必要環境

- macOS
- Ruby **3.2 以上**（`Data.define` を使用しているため）
  - 推奨は最新安定版。本リポジトリの `.ruby-version` は `4.0.7` を指定しています
  - Homebrew でのインストール例: `brew install ruby`
    （インストール後、`/opt/homebrew/bin` が `/usr/bin` より `PATH` の前方に
    あることを確認してください。`which ruby` が `/opt/homebrew/bin/ruby` を
    指せば OK です）
  - `rbenv` / `rvm` / `asdf` 等のバージョンマネージャを使っていない環境では
    `.ruby-version` は参照されないため、`ruby -v` で実際に使われる
    バージョンを確認してください
- 外部 gem は不要（標準ライブラリの `json` / `io/console` のみ使用）

## 遊び方

```bash
cd flash_shogi
ruby bin/flash_shogi
```

1. 問題番号・盤面・持ち駒が表示されます。
2. 60秒間そのまま表示されます（`Enter` キーで早送りできます）。
3. 60秒経過後、盤面が消え「次の一手は?」と3択が表示されます。
4. `1` / `2` / `3` のいずれかのキーを押して回答します（Enter不要）。
5. 正誤と正解手・解説が表示されます。`Enter` で次の問題へ進みます。
6. 全5問(保存済み20問からランダムに出題)終了後、正解数が表示されます。

いつでも `Ctrl+C` を押すとその時点でゲームを中断し、終了できます。

## 表示テーマ

```bash
ruby bin/flash_shogi --theme=text   # 通常の漢字駒表示（デフォルト）
ruby bin/flash_shogi --theme=pua    # PUA(私用領域)の自作グリフフォントで表示
```

## 表示秒数の変更

```bash
ruby bin/flash_shogi --seconds=30   # 盤面の表示時間を30秒にする（デフォルト: 60秒）
```

`--theme=pua` は、PUA (`U+E000`–`U+E10D` ほか) に将棋駒グリフを割り当てた
自作フォント(`font/build/FlashShogiPua.ttf`、COLR/CPALカラーフォントとして
完成済み)が端末側に導入済みであることを前提としています。
未導入の環境では文字化け（豆腐や空白）として表示されるため、
その場合は `--theme=text` を使ってください。

### 導入手順(iTerm2推奨)

1. `font/build/FlashShogiPua.ttf` を `~/Library/Fonts/` に置く
2. iTerm2の環境設定 → Profiles → Text で:
   - 「Font」は普段使っているフォントのままでよい
   - 「Use a different font for non-ASCII text」を有効にし、
     Non-ASCII Fontを `Flash Shogi PUA` にする(駒以外の非ASCII文字は
     さらにOSのフォールバックに進むので、漢字等の表示は崩れない)
   - 「Ambiguous characters are double-width」を有効にする。駒グリフは
     Unicode の East Asian Width が未定義(Ambiguous)で、この設定が無いと
     半角(1カラム)扱いになり盤面がズレる
3. **iTerm2の Preferences → General → Magic で Metal(GPU)レンダラを無効化する。**
   iTerm2のMetalレンダラはCOLR/CPALカラーフォントを正しく描画できないバグが
   あり、有効なままだと駒が色なし・崩れた小さい塊として表示される。
   Metalを無効化(レガシーレンダラを使用)すると正しく色付きで表示される
   (実機で確認済み)。
4. `ruby bin/flash_shogi --theme=pua` を実行して確認する

Terminal.appには上記の「非ASCIIだけ別フォント」「Ambiguous Width」設定が
無く、駒グリフが常に半角扱いになってしまう。Terminal.appを使う場合は
`font/merge_glyphs.py` で普段のフォントに駒グリフを合体させる方法がある
(Nerd Fontsと同じ要領。詳細は `font/README.md`)。

推奨ターミナル優先順位: iTerm2(Ambiguous Width設定あり) > Ghostty / kitty
(要確認) > Terminal.app(半角扱いのため罫線がズレる、補助的)

開発中のグリフ素材・コードポイント対応表・作業状況は [`font/README.md`](font/README.md) を参照。
駒の文字は OFL ライセンスの M PLUS 1p Black から輪郭を抽出して作成しており
(ライセンス全文: [`font/third_party_licenses/OFL-MPLUS1p.txt`](font/third_party_licenses/OFL-MPLUS1p.txt))、
生成物を含めてこのリポジトリに同梱・公開して問題ありません。

PUAのコードポイント割り当ては `lib/renderer.rb` の `PUA_SENTE_BASE` /
`PUA_GOTE_OFFSET` / `PUA_KIND_INDEX` にまとまっています。詳細な割り当て表は
引き継ぎ仕様書の 4-6 節を参照してください。

## ディレクトリ構成

```text
flash_shogi/
├── bin/
│   └── flash_shogi      # 実行エントリポイント
├── lib/
│   ├── cli.rb            # 入力受付・画面遷移の統括
│   ├── game.rb           # 選択肢の組み立て・正誤判定ロジック
│   ├── puzzle_store.rb   # data/puzzles.json の読み込み
│   ├── renderer.rb       # 盤面・持ち駒の表示(テーマ切り替え含む)
│   ├── sfen.rb           # SFEN文字列 → 盤面グリッドへの変換
│   └── timer.rb          # 60秒カウントダウンとEnter早送り
├── data/
│   └── puzzles.json      # 問題データ(リポジトリには含まれない。後述)
├── test/
│   └── test_flash_shogi.rb
└── README.md
```

## テスト

```bash
ruby -Ilib test/test_flash_shogi.rb
```

## 問題データについて

`data/puzzles.json` は**このリポジトリには含まれていません**（`.gitignore`
済み）。外部サイトの問題を基にしたデータが含まれており、出典サイトの
利用規約・転載可否が不明なため、非公開・自己責任の個人利用に限定して
手元でのみ保持する方針にしている。

動かすには自分で `data/puzzles.json` を用意する必要がある。配列の各要素が
1問分のデータで、フォーマットは次の通り:

```json
{
  "id": "P1",
  "title": "第1問",
  "difficulty": "易",
  "sfen": "Bk7/9/1N7/9/9/9/9/4K4/9 b G 1",
  "board_text": "（テーマ text での盤面表示そのままの文字列）",
  "answer": "8二金打",
  "wrong_choices": ["7二金打", "9二金打"],
  "concept": "（一言解説の見出し。現状の画面表示には未使用）",
  "explanation": "（正誤判定後に表示する解説文）",
  "verification": "verified"
}
```

正誤判定は固定解答方式（将棋エンジンによるその場判定ではなく、データに持たせた
`answer` と `wrong_choices` を照合する方式）なので、この形式で用意すれば
自作の問題をいくつでも追加できる。

いずれも本リポジトリの `tsume_verifier` 相当のロジック(合法手生成・王手判定・
詰み判定の総当たり検証)で「一手詰めとして唯一の正解になっているか」を機械的に
確認済み。現時点では非公開運用を前提としている。

## 既知の制約（MVPスコープ外）

- 汎用的な将棋ルールエンジン・合法手生成は実装していません
- 問題の自動生成やネットワーク取得は行いません
- Windows / Linux は対象外です
