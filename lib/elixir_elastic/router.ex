defmodule ElixirElastic.Router do
  @moduledoc false

  use Plug.Router

  alias ElixirElastic.ElasticSearch
  alias ElixirElastic.HTML

  plug Plug.Static, at: "/static", from: :elixir_elastic

  plug :put_session_secret

  plug Plug.Session,
    store: :cookie,
    key: "_elixir_elastic_key",
    signing_salt: "log-search",
    encryption_salt: "log-search-enc"

  plug :fetch_session

  plug Plug.Parsers,
    parsers: [:urlencoded, :json],
    pass: ["application/json"],
    json_decoder: Jason

  plug :match
  plug :dispatch

  get "/" do
    conn = fetch_query_params(conn)

    {conn, filters, searched} =
      cond do
        conn.query_params != %{} ->
          {conn, normalize_filters(conn.query_params), true}

        get_session(conn, "searched") ->
          filters = normalize_filters(get_session(conn, "filters") || %{})

          conn =
            conn
            |> delete_session("searched")
            |> delete_session("filters")

          {conn, filters, true}

        true ->
          {conn, normalize_filters(%{}), false}
      end

    {logs, error} =
      if searched do
        try do
          {ElasticSearch.search_logs(filters), nil}
        rescue
          exception -> {[], Exception.message(exception)}
        end
      else
        {[], nil}
      end

    send_html(conn, HTML.render_index(filters, logs, searched, error))
  end

  post "/" do
    conn
    |> put_session("filters", normalize_filters(conn.body_params))
    |> put_session("searched", true)
    |> redirect("/")
  end

  get "/clear" do
    conn
    |> delete_session("filters")
    |> delete_session("searched")
    |> redirect("/")
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

  match _ do
    send_resp(conn, 404, "Not found")
  end

  defp put_session_secret(conn, _opts) do
    %{conn | secret_key_base: session_secret()}
  end

  defp session_secret do
    secret = Application.fetch_env!(:elixir_elastic, :session_secret)

    if byte_size(secret) < 64 do
      :crypto.hash(:sha512, secret) |> Base.encode64()
    else
      secret
    end
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

  defp send_html(conn, html) do
    conn
    |> put_resp_content_type("text/html; charset=utf-8")
    |> send_resp(200, html)
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
