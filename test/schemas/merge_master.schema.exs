[
  mappings: [
    "lager.handlers.*": [
      to: "lager.handlers",
      datatype: [:complex],
      default: [],
      doc: """
      Settings for the available logging backends.
      """
    ],
    "lager.handlers.*.level": [
      to: "lager.handlers",
      datatype: [enum: [:info, :error]],
      default: :info,
      doc: """
      Choose the logging level for the console backend.
      """
    ],
    "lager.handlers.file.error": [
      to: "lager.handlers.file.error",
      datatype: :binary,
      default: "/var/log/error.log",
      doc: """
      Specify the path to the error log for the file backend
      """
    ],
    "lager.handlers.file.info": [
      to: "lager.handlers.file.info",
      datatype: :binary,
      default: "/var/log/console.log",
      doc: """
      Specify the path to the console log for the file backend
      """
    ],
    "myapp.some.important.setting": [
      to: "myapp.some.important.setting",
      datatype: [list: :ip],
      default: [{"127.0.0.1", "8001"}],
      doc: "Seriously, super important."
    ]
  ],
  translations: [
    "lager.handlers.*": fn
      _mapping, {:console, value_map}, handlers ->
        level = case value_map[:level] do
          nil -> :info
          l when l in [:info, :error] -> l
          invalid ->
            IO.puts("Unsupported console logging level: #{invalid}")
            exit(1)
        end
        [{:lager_console_backend, level} | handlers]
      _mapping, {:file, settings}, handlers ->
        [{:lager_file_backend, settings} | handlers]
      _mapping, {type, type_definition}, handlers ->
        IO.inspect {type, type_definition}
        IO.puts("Unrecognized lager backend: #{type}")
        exit(1)
    end,
    "lager.handlers.file.info": fn
      _mapping, {level, log_path}, acc when level in [:info, :error] and is_binary(log_path) ->
        [[level: level, file: log_path]|acc]
      _mapping, {level, log_path}, _ ->
        IO.puts("Invalid log level for the lager file backend: #{level}")
        exit(1)
    end
  ]
]
