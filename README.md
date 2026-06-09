# elixir_elastic

既存の Elasticsearch に保存したログを Elixir からキーワード検索するアプリです。
参照元の Flask 版 `naritomo08/flask_elastic` と同じく、デフォルトでは `http://elastic1:9200` の `logs-*` を検索します。

検索対象フィールドは `msg`、ログ種別は `logs-syslog-*` / `logs-authlog-*` から判定します。
Compose では `elastic1` を `192.168.11.20` に解決する設定を入れています。

## 起動

```bash
docker compose up --build
```

ブラウザで http://localhost:5002 を開きます。

Elasticsearch / Kibana はこの Compose には含めず、既存の Elasticsearch を利用します。

## API

ログ検索:

```bash
curl -X POST http://localhost:5002/api/logs \
  -H "Content-Type: application/json" \
  -d '{"message":"timeout","log_type":"syslog"}'
```

ヘルスチェック:

```bash
curl http://localhost:5002/health
```

## テスト

テストは `test/elixir_elastic_test.exs` にまとめています。外部の Elasticsearch には接続せず、以下のようなアプリ内部の処理を確認します。

- epoch millis から JST 表示への変換
- `datetime-local` 入力を JST として扱い、Elasticsearch 用の UTC ISO 文字列へ変換する処理
- インデックス名や検索条件からのログ種別判定
- メッセージ、ホスト、プログラム、時刻範囲を含む Elasticsearch クエリ生成
- 検索画面 HTML にフォーム、静的 JS、検索結果が含まれること

ローカルに Elixir がある場合:

```bash
mix deps.get
mix test
```

Docker で実行する場合:

```bash
docker build --target build -t elixir-elastic-build .
docker run --rm elixir-elastic-build sh -c "MIX_ENV=test mix deps.get && mix test"
```

## 設定

`docker-compose.yml` の環境変数で接続先とインデックス名を変更できます。

- `ELASTICSEARCH_URL`: Elasticsearch の URL
- `ELASTICSEARCH_INDEX`: 検索対象のインデックスパターン
- `SESSION_SECRET`: 画面検索条件をセッションに保存するための秘密鍵
