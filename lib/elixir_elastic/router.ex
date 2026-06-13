defmodule ElixirElastic.Router do
  @moduledoc false

  use Plug.Router

  alias ElixirElastic.ElasticSearch

  plug Plug.Static, at: "/static", from: :elixir_elastic

  plug Plug.Parsers,
    parsers: [:urlencoded, :json],
    pass: ["application/json"],
    json_decoder: Jason

  plug :match
  plug :dispatch

  get "/" do
    send_static_index(conn)
  end

  post "/" do
    filters = normalize_filters(conn.body_params)
    redirect(conn, "/?#{URI.encode_query(filters)}")
  end

  get "/clear" do
    redirect(conn, "/")
  end

  get "/health" do
    json(conn, %{
      ok: ElasticSearch.ping(),
      elasticsearch_url: Application.fetch_env!(:elixir_elastic, :elasticsearch_url),
      index: Application.fetch_env!(:elixir_elastic, :elasticsearch_index)
    })
  end

  get "/api/logs" do
    conn = fetch_query_params(conn)
    filters = normalize_filters(conn.query_params)
    logs = ElasticSearch.search_logs(filters)
    json(conn, %{filters: filters, count: length(logs), logs: logs})
  end

  post "/api/logs" do
    filters = normalize_filters(conn.body_params)
    logs = ElasticSearch.search_logs(filters)
    json(conn, %{filters: filters, count: length(logs), logs: logs})
  end

  get "/api/log-types" do
    json(conn, %{log_types: ElasticSearch.log_types()})
  end

  match _ do
    send_resp(conn, 404, "Not found")
  end

  def normalize_filters(params) do
    %{
      "time_from" => clean(params["time_from"]),
      "time_to" => clean(params["time_to"]),
      "log_type" => clean(params["log_type"]),
      "host" => clean(params["host"]),
      "program" => clean(params["program"]),
      "message" => clean(params["message"])
    }
  end

  defp clean(nil), do: ""
  defp clean(value), do: String.trim(to_string(value))

  defp send_static_index(conn) do
    conn
    |> put_resp_content_type("text/html; charset=utf-8")
    |> send_file(200, static_path("index.html"))
  end

  defp static_path(file) do
    :elixir_elastic
    |> :code.priv_dir()
    |> Path.join("static/#{file}")
  end

  defp json(conn, payload) do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, Jason.encode!(payload))
  end

  defp redirect(conn, path) do
    conn
    |> put_resp_header("location", path)
    |> send_resp(302, "")
  end
end
