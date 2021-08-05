defmodule Mix.Tasks.Sessions do
  use Mix.Task

  # @moduledoc false
  @spec run([binary]) :: list
  def run(args) do
    # ElixirSessions.SessionTypechecking.run
    {opts, argv} = OptionParser.parse!(args, switches: [expression_typing: :boolean])
    expression_typing = Keyword.get(opts, :expression_typing, true)

    load_paths = Mix.Project.compile_path()

    paths =
      if length(argv) > 0 do
        Enum.map(argv, fn path -> Path.wildcard(load_paths <> "/Elixir*." <> path <> ".beam") end)
        |> List.flatten()
      else
        # or Path.wildcard("projects/*/ebin/**/*.beam")
        Path.wildcard(load_paths <> "/Elixir.*.beam")
      end

    if length(paths) == 0 do
      throw("No paths found for module: #{Enum.join(argv, ", ")}")
    end

    files =
      for path <- paths do
        case File.read(path) do
          {:ok, file} -> file
          {:error, _} -> throw("Could not read #{path}.")
        end
      end

    for file <- files do
      ElixirSessions.Retriever.process(file, expression_typing: expression_typing)
    end
  end
end
