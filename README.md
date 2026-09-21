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
6. 全5問終了後、正解数が表示されます。

## 表示テーマ

```bash
ruby bin/flash_shogi --theme=text   # 通常の漢字駒表示（デフォルト）
ruby bin/flash_shogi --theme=pua    # PUA(私用領域)の自作グリフフォントで表示
```

`--theme=pua` は、PUA (`U+E000`–`U+E10D`) に将棋駒グリフを割り当てた
自作フォントが端末側に導入済みであることを前提としています。
未導入の環境では文字化け（豆腐や空白）として表示されるため、
その場合は `--theme=text` を使ってください。

### 自作フォントの導入ワークフロー（想定）

1. SVG 等で将棋駒グリフを作成する（先手用14種・後手用14種＝計28グリフ）
2. FontForge 等で PUA グリフ入りフォント(OTF/TTF)を作成する
3. macOS の Font Book 経由でインストールする
4. 対応ターミナルで、インストールしたフォントを使って本アプリを実行する

推奨ターミナル優先順位: Ghostty > kitty > iTerm2 > Terminal.app（補助的）

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
│   └── puzzles.json      # 5問の問題データ(非公開・自作)
├── test/
│   └── test_flash_shogi.rb
└── README.md
```

## テスト

```bash
ruby -Ilib test/test_flash_shogi.rb
```

## 問題データについて

`data/puzzles.json` の5問は自作の一手詰め問題です。正誤判定は固定解答方式
（将棋エンジンによるその場判定ではなく、データに持たせた正解と照合する方式）
のため、`answer` と `wrong_choices` を正しく用意すれば新しい問題を追加できます。
現時点では非公開運用を前提としています。

## 既知の制約（MVPスコープ外）

- 汎用的な将棋ルールエンジン・合法手生成は実装していません
- 問題の自動生成やネットワーク取得は行いません
- Windows / Linux は対象外です
