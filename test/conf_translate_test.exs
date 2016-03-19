defmodule ConfTranslateTest do
  use ExUnit.Case
  import ExUnit.CaptureIO

  test "can generate default conf from schema" do
    path   = Path.join(["test", "schemas", "test.schema.exs"])
    schema = path |> Conform.Schema.load
    conf   = Keyword.delete(schema, :import) |> Conform.Translate.to_conf
    expected = """
    # The location of the error log. Should be a full path, i.e. /var/log/error.log.
    log.error.file = "/var/log/error.log"

    # The location of the console log. Should be a full path, i.e. /var/log/console.log.
    log.console.file = "/var/log/console.log"

    # This setting determines whether to use syslog or not. Valid values are :on and :off.
    # Allowed values: on, off
    log.syslog = on

    # Restricts the error logging performed by the specified
    # `sasl_error_logger` to error reports, progress reports, or
    # both. Default is all. Just testing "nested strings".
    # Allowed values: error, progress, all
    sasl.log.level = all

    # The format to use for Logger.
    logger.format = "$time $metadata[$level] $levelpad$message\n"

    # Remote db hosts
    myapp.db.hosts = 127.0.0.1:8001

    # Just some atom.
    myapp.some_val = foo

    # Determine the type of thing.
    # * active: it's going to be active
    # * passive: it's going to be passive
    # * active-debug: it's going to be active, with verbose debugging information
    # Allowed values: active, passive, active-debug
    myapp.another_val = active

    # Atom module name
    myapp.Elixir.Some.Module.val = foo

    # Provide documentation for myapp.Custom.Enum here.
    # Allowed values: dev, prod, test
    myapp.Custom.Enum = dev

    """

    assert ^expected = conf
  end

  test "can generate config as Elixir terms from .conf and schema with imports" do
    {:ok, cwd} = File.cwd
    script = cwd <> "/conform"
    example_app_path = "#{cwd}/"  <> Path.join(["test", "fixtures", "example_app"])
    sys_config_path = "#{cwd}/"  <> Path.join(["test", "fixtures", "example_app", "config"])
    conf_path = "#{cwd}/"  <> Path.join(["test", "fixtures", "example_app", "config", "test.conf"])
    schema_path = "#{cwd}/"  <> Path.join(["test", "fixtures", "example_app", "config", "test.schema.exs"])

    File.touch(sys_config_path <> "/sys.config")
    capture_io(fn ->
      {:ok, zip_path, _build_files} = Mix.Project.in_project(:example_app, example_app_path,
        fn _ ->
          Mix.Task.run("deps.get")
          Mix.Task.run("deps.compile")
          Mix.Task.run("compile")
          Mix.Task.run("conform.archive", [schema_path])
        end)
      expected = [{:test, [{:env, :prod}, {:another_val, 2}, {:debug_level, :info}]}]
      :ok = Mix.Task.run("escript.build", [path: script])
      _ = :os.cmd("#{script} --schema #{schema_path} --conf #{conf_path} --output-dir #{sys_config_path}" |> to_char_list)
      {:ok, [sysconfig]} = :file.consult(sys_config_path <> "/sys.config")
      assert Path.basename(zip_path) == "test.schema.ez"
      assert sysconfig == expected
      File.rm(sys_config_path <> "/sys.config")
      File.rm(script)
    end)
  end

  test "can generate config as Elixir terms from .conf and schema" do
    path   = Path.join(["test", "schemas", "test.schema.exs"])
    schema = path |> Conform.Schema.load
    conf   = schema |> Conform.Translate.to_conf
    parsed = Conform.Parse.parse!(conf)
    config = Conform.Translate.to_config([], parsed, Keyword.delete(schema, :import))
    expect = [{:myapp,[{:db,[{:hosts,[{"127.0.0.1", "8001"}]}]},
               {:some_val, :bar},
               {:another_val, {:on, [{:data, %{log: :warn}}]}},
               {Some.Module, [{:val,:foo}]},
               {:'Custom.Enum',:dev}]},
       {:logger,[{:format, "$time $metadata[$level] $levelpad$message\n"}]},
       {:sasl,[{:errlog_type,:all}]},
       {:log,[{:error_file,"/var/log/error.log"},
             {:console_file,"/var/log/console.log"},
             {:syslog,:on}]}]
    assert expect == config
  end

  test "can generate config as Elixir terms from existing config, .conf and schema" do
    config = [sasl: [errlog_type: :error], log: [syslog: :off]]
    path   = Path.join(["test", "schemas", "test.schema.exs"])
    schema = path |> Conform.Schema.load
    conf = """
    # Restricts the error logging performed by the specified
    # `sasl_error_logger` to error reports, progress reports, or
    # both. Default is all. Just testing "nested strings".
    sasl.log.level = progress

    # Determine the type of thing.
    # * active: it's going to be active
    # * passive: it's going to be passive
    # * active-debug: it's going to be active, with verbose debugging information
    myapp.another_val = active
    """
    parsed = Conform.Parse.parse!(conf)
    config = Conform.Translate.to_config(config, parsed, schema)
    expect = [{:myapp,[{:db,[{:hosts,[{"127.0.0.1","8001"}]}]},
                       {:some_val,:bar},
                       {:another_val,{:on,[{:data,%{log: :warn}}]}},
                       {Some.Module,[{:val,:foo}]},
                       {:'Custom.Enum',:dev}]},
              {:logger,[{:format,"$time $metadata[$level] $levelpad$message\n"}]},
              {:sasl, [{:errlog_type,:progress}]},
              {:log, [{:error_file,"/var/log/error.log"},
                      {:console_file,"/var/log/console.log"},
                      {:syslog,:on}]}]
    assert expect == config
  end

  test "can write config to disk as Erlang terms in valid app/sys.config format" do
    path   = Path.join(["test", "schemas", "test.schema.exs"])
    schema = path |> Conform.Schema.load
    conf   = schema |> Conform.Translate.to_conf
    parsed = Conform.Parse.parse!(conf)
    config = Conform.Translate.to_config([], parsed, Keyword.delete(schema, :import))
    config_path = Path.join(System.tmp_dir!, "conform_test.config")
    :ok    = config_path |> Conform.Config.write(config)
    result = config_path |> String.to_char_list |> :file.consult
    config_path |> File.rm!
    assert {:ok, [^config]} = result
  end

  test "can translate with nested lists to conf" do
    path   = Path.join(["test", "configs", "nested_list.exs"])
    config = path |> Mix.Config.read! |> Macro.escape
    schema = Conform.Schema.from_config(config)
    conf   = Conform.Translate.to_conf(Keyword.delete(schema, :import))
    expected = """
    # Provide documentation for my_app.sublist here.
    my_app.sublist = [opt1 = \"val1\", opt2 = \"val4\"], [opt1 = \"val3\", opt2 = \"val4\"]

    """
    assert expected == conf
  end
end
