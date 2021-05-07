defmodule Mix.Tasks.SessionCheck do
  @dialyzer {:nowarn_function}
  use Mix.Task

  @moduledoc false
  def run(_args) do
    load_paths = Mix.Project.compile_path()
    paths = Path.wildcard(load_paths <> "/Elixir.*.beam")

    files =
      for path <- paths do
          case File.read(path) do
            {:ok, file} -> file
            {:error, _} -> throw("Could not read #{path}.")
          end
      end

    Enum.each(files, &ElixirSessions.Retriever.process/1)
  end
end
