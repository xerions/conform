defmodule IntegrationTest do
  use ExUnit.Case

  test "effective configuration" do
    config = Path.join(["test", "example_app", "config.exs"]) |> Mix.Config.read!
    conf   = Path.join(["test", "example_app", "test.conf"]) |> Conform.Parse.file!
    schema = Path.join(["test", "example_app", "test.schema.exs"]) |> Conform.Schema.load!
    effective = Conform.Translate.to_config(config, conf, schema)
    expected = [{:logger,
               [{:format,<<"$time $metadata[$level] $levelpad$message\n">>}]},
           {:sasl,[{:errlog_type, :error}]},
           {:test,
            [{:servers,
              [{:proxy,
                [{{:eradius_proxy,'proxy',
                   [{:default_route,
                     {{127,0,0,1},1813,"secret"}},
                    {:options,
                     [{:type,:realm},
                      {:strip,:true},
                      {:separator, '@'}]},
                    {:routes,
                     [{'test',
                       {{127,0,0,1},1815,"secret"}}]}]},
                  [{'127.0.0.1', "secret"}]}]}]},
             {:env,:test},
             {:another_val,:none},
             {:debug_level,:info}]}]
    assert effective == expected
    assert Keyword.equal?(expected, effective)
  end

  test "merging and stringifying master/dep schemas" do
    master = Path.join(["test", "schemas", "merge_master.schema.exs"]) |> Conform.Schema.read!
    dep    = Path.join(["test", "schemas", "merge_dep.schema.exs"]) |> Conform.Schema.read!
    saved  = Path.join(["test", "schemas", "merged_schema.exs"])

    # Get schemas from all dependencies
    schema   = Conform.Schema.coalesce([dep, master])
    contents = schema |> Conform.Schema.stringify
    saved |> File.write!(contents)

    expected = File.read!(saved)
    assert expected == contents
  end

  test "can accumulate values in transforms" do
    conf   = Path.join(["test", "confs", "lager_example.conf"]) |> Conform.Parse.file!
    schema = Path.join(["test", "schemas", "merge_master.schema.exs"]) |> Conform.Schema.load

    effective = Conform.Translate.to_config([], conf, schema)
    expected  =  [{:myapp,
                   [{:some,
                    [{:important,
                      [{:setting,
                        [{"127.0.0.1", "80"},
                         {"127.0.0.2", "81"}]}]}]}]},
                  {:lager,
                   [{:handlers,
                     [{:lager_console_backend, :info},
                      {:lager_file_backend,
                       [{:file, "/var/log/error.log"}, {:level,:error}]},
                      {:lager_file_backend,
                       [{:file, "/var/log/console.log"}, {:level,:info}]}
                     ]}]}]
    assert expected == effective
  end

  test "for the complex data types" do
    conf   = Path.join(["test", "confs", "complex_example.conf"]) |> Conform.Parse.file!
    schema = Path.join(["test", "schemas", "complex_schema.exs"]) |> Conform.Schema.load
    effective = Conform.Translate.to_config([], conf, schema)
    expected = [my_app:
                [
                    complex_another_list:
                    [
                        second0: %{id: 101, username: "test_username2", age: 40, dbid: 1},
                        first3: %{id: 5, username: "test_username", age: 20, dbid: 100},
                        first0: %{id: 100, username: "test_username5", age: 20, dbid: 100 },
                        first1: %{id: 0, username: "test_username3", age: 20, dbid: 100}
                    ],
                    complex_list: [
                      fido: %{type: :dog, age: 5}, buzz: %{age: 25, type: :person}
                    ],
                    some_val: :foo, some_val2: 2.1, some_bool_val: true
                ]]
    assert expected == effective
  end

  test "test for the custom data type" do
    conf   = Path.join(["test", "confs", "test.conf"]) |> Conform.Parse.file!
    schema = Path.join(["test", "schemas", "test.schema.exs"]) |> Conform.Schema.load
    effective = Conform.Translate.to_config([], conf, schema)
    expected = [myapp: [{:db, [hosts: [{"127.0.0.1", "8001"}]]},
                        {:some_val, :bar}, {:another_val, {:on, [data: %{log: :warn}]}}, {Some.Module, [val: :foo]},
                        {:"Custom.Enum", :prod}], logger: [format: "$time $metadata[$level] $levelpad$message\n"],
                sasl: [errlog_type: :all],
                log: [error_file: "/var/log/error.log", console_file: "/var/log/console.log", syslog: :on]]
    assert effective == expected
  end
end
