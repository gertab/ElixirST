defmodule Mix.Tasks.SessionCheck do
  use Mix.Task

  @moduledoc false
  # @shortdoc "Simply calls the ElixirSessions.Inference.run/0 function."
  def run(_args) do
    load_paths = Mix.Project.compile_path()
    paths = Path.wildcard(load_paths <> "/Elixir.*.beam")

    for path <- paths do
      bytecode =
        case File.read(path) do
          {:ok, file} -> file
          {:error, _} -> throw("Could not read #{path}.")
        end

      # Gets debug_info chunk from BEAM file
      chunks =
        case :beam_lib.chunks(bytecode, [:debug_info]) do
          {:ok, {_mod, chunks}} -> chunks
          {:error, _, error} -> throw("Error: #{inspect(error)}")
        end

      # Gets the (extended) Elixir abstract syntax tree from debug_info chunk
      dbgi_map =
        case chunks[:debug_info] do
          {:debug_info_v1, :elixir_erl, metadata} ->
            case metadata do
              {:elixir_v1, map, _} ->
                # Erlang extended AST available
                map

              {version, _, _} ->
                throw("Found version #{version} but expected :elixir_v1.")
            end

          x ->
            throw("Error: #{inspect(x)}")
        end

      # |> IO.inspect()

      # {:ok,{_,[{:abstract_code,{_, ac}}]}} = :beam_lib.chunks(Beam,[abstract_code]).
      # erl_syntax:form_list(AC)

      # Gets the list of session types, which were stored as attributes in the module
      raw_session_types = Keyword.get_values(dbgi_map[:attributes], :session)

      dbgi_map[:attributes]
      # |> IO.inspect
    end
    |> IO.inspect()
  end
end
