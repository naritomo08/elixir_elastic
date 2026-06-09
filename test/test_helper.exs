ExUnit.start()

Application.put_env(:elixir_elastic, :elasticsearch_url, "http://elastic1:9200")
Application.put_env(:elixir_elastic, :elasticsearch_index, "logs-*")
Application.put_env(:elixir_elastic, :session_secret, "dev-secret-key")
Application.put_env(:elixir_elastic, :port, 5000)
