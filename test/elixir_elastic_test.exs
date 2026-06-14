defmodule ElixirElasticTest do
  use ExUnit.Case, async: true

  alias ElixirElastic.ElasticSearch
  alias ElixirElastic.Router

  test "format_timestamp converts epoch millis to JST" do
    assert ElasticSearch.format_timestamp(1_780_398_715_000) == "2026/06/02 20:11:55 JST"
  end

  test "datetime_local_to_iso treats input as JST" do
    assert ElasticSearch.datetime_local_to_iso("2026-06-02T20:11") == "2026-06-02T11:11:00Z"
  end

  test "detect_log_type from index name" do
    assert ElasticSearch.detect_log_type(".ds-logs-syslog-2026.06.02-000001") == "syslog"
    assert ElasticSearch.detect_log_type(".ds-logs-authlog-2026.06.02-000001") == "authlog"
    assert ElasticSearch.detect_log_type("metrics-2026.06.02") == "unknown"
  end

  test "build_query with message and exact program host filters and time range" do
    filters = %{
      "time_from" => "2026-06-02T20:00",
      "time_to" => "2026-06-02T21:00",
      "log_type" => "syslog",
      "host" => "flink1",
      "program" => "systemd",
      "message" => "sshd"
    }

    query = ElasticSearch.build_query(filters)

    assert get_in(query, [:bool, :must]) |> hd() ==
             %{
               bool: %{
                 should: [
                   %{match: %{"msg" => %{query: "sshd", operator: "and"}}},
                   %{match_phrase: %{"msg" => %{query: "sshd"}}},
                   %{wildcard: %{"msg.keyword" => %{value: "*sshd*", case_insensitive: true}}},
                   %{wildcard: %{"msg" => %{value: "*sshd*", case_insensitive: true}}}
                 ],
                 minimum_should_match: 1
               }
             }

    assert %{
             bool: %{
               should: [
                 %{term: %{"host" => "flink1"}},
                 %{term: %{"host.keyword" => "flink1"}}
               ],
               minimum_should_match: 1
             }
           } in query.bool.filter

    assert %{
             bool: %{
               should: [
                 %{term: %{"program" => "systemd"}},
                 %{term: %{"program.keyword" => "systemd"}}
               ],
               minimum_should_match: 1
             }
           } in query.bool.filter

    assert %{
             range: %{
               "@timestamp" => %{"gte" => "2026-06-02T11:00:00Z", "lte" => "2026-06-02T12:00:00Z"}
             }
           } in query.bool.filter
  end

  test "build_query searches all message terms when message contains spaces" do
    query = ElasticSearch.build_query(%{"message" => "authlog forward test from"})

    assert get_in(query, [:bool, :must]) ==
             [
               %{
                 bool: %{
                   should: [
                     %{match: %{"msg" => %{query: "authlog forward test from", operator: "and"}}},
                     %{match_phrase: %{"msg" => %{query: "authlog forward test from"}}},
                     %{
                       wildcard: %{
                         "msg.keyword" => %{
                           value: "*authlog forward test from*",
                           case_insensitive: true
                         }
                       }
                     },
                     %{
                       wildcard: %{
                         "msg" => %{
                           value: "*authlog forward test from*",
                           case_insensitive: true
                         }
                       }
                     }
                   ],
                   minimum_should_match: 1
                 }
               }
             ]
  end

  test "build_query supports partial IP address message searches" do
    query = ElasticSearch.build_query(%{"message" => "192.168.11."})
    should = query |> get_in([:bool, :must]) |> hd() |> get_in([:bool, :should])

    assert %{
             wildcard: %{
               "msg.keyword" => %{value: "*192.168.11.*", case_insensitive: true}
             }
           } in should

    assert %{
             wildcard: %{
               "msg" => %{value: "*192.168.11.*", case_insensitive: true}
             }
           } in should
  end

  test "index pattern switches by log type" do
    assert ElasticSearch.index_pattern_for_log_type("syslog") == "logs-syslog-*"
    assert ElasticSearch.index_pattern_for_log_type("authlog") == "logs-authlog-*"
    assert ElasticSearch.index_pattern_for_log_type("") == "logs-*"
  end

  test "normalize_filters trims missing and submitted values" do
    assert Router.normalize_filters(%{"program" => " systemd ", "message" => " sshd "}) == %{
             "time_from" => "",
             "time_to" => "",
             "log_type" => "",
             "host" => "",
             "program" => "systemd",
             "message" => "sshd"
           }
  end

  test "static index page includes search UI hooks" do
    html = File.read!("priv/static/index.html")

    assert html =~ ~s(method="post")
    assert html =~ ~s(id="search-form")
    assert html =~ ~s(id="results-summary")
    assert html =~ ~s(id="results-body")
    assert html =~ ~s(src="/static/search.js")
  end

  test "static search script posts search filters as json" do
    js = File.read!("priv/static/search.js")

    assert js =~ ~S|fetch("/api/logs"|
    assert js =~ ~S|method: "POST"|
    assert js =~ ~S|"Content-Type": "application/json"|
    assert js =~ ~S|body: JSON.stringify(paramsObject(params))|
    refute js =~ ~S|fetch(`/api/logs?|
    refute js =~ ~S|`/?${params.toString()}`|
  end
end
