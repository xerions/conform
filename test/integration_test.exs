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

    # Get schemas from all dependencies
    schema   = Conform.Schema.coalesce([dep, master])
    merged_mappings = Keyword.get(schema, :mappings)
    merged_translations = Keyword.get(schema, :translations)
    master_mappings = Keyword.get(master, :mappings)
    dep_mappings = Keyword.get(dep, :mappings)
    master_translations = Keyword.get(master, :translations)
    dep_translations = Keyword.get(dep, :translations)
    # here we check that merged schemas contains all mappings and
    # translations from the master and dep schemas
    Enum.each(master_mappings, fn({mapping_name, mapping_data}) ->
      assert true = Keyword.has_key?(merged_mappings, mapping_name)
      merged_mapping_data = Keyword.get(merged_mappings, mapping_name)
      assert mapping_data == merged_mapping_data
    end)
    Enum.each(dep_mappings, fn({mapping_name, mapping_data}) ->
      assert true = Keyword.has_key?(merged_mappings, mapping_name)
      merged_mapping_data = Keyword.get(merged_mappings, mapping_name)
      assert mapping_data == merged_mapping_data
    end)
    Enum.each(master_translations, fn({translation_name, _fun_ast}) ->
      assert true = Keyword.has_key?(merged_translations, translation_name)
    end)
    Enum.each(dep_translations, fn({translation_name, _fun_ast}) ->
      assert true = Keyword.has_key?(merged_translations, translation_name)
    end)
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
