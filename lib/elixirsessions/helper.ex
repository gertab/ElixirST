defmodule ElixirSessions.Helper do
  @moduledoc false

  # recompile && ElixirSessions.Helper.get_BEAM()
  def get_BEAM() do
    module = "ElixirSessions.SmallExample"
    load_paths = Mix.Project.compile_path()
    paths = Path.wildcard(load_paths <> "/Elixir*." <> module <> ".beam")

    if length(paths) == 0 do
      throw("No paths found for module: #{module}")
    end

    files =
      for path <- paths do
        case File.read(path) do
          {:ok, file} -> file
          {:error, _} -> throw("Could not read #{path}.")
        end
      end

    for file <- files do
      # Gets debug_info chunk from BEAM file
      chunks =
        case :beam_lib.chunks(file, [:debug_info]) do
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

      dbgi_map[:attributes]
      |> IO.inspect()

      dbgi_map
      |> IO.inspect()
    end
  end

  def ast() do
    quote do
        x = 7

        case x do
          z ->
            :ok
            :ok

          _ ->
            :jkjk
        end

    end
  end

  # recompile && ElixirSessions.Helper.quoted
  def quoted() do
    ast()
    |> Macro.to_string()
    |> Code.format_string!()
    |> IO.puts()
  end

  # recompile && ElixirSessions.Helper.quoted_prettify
  def quoted_prettify() do
    quoted()
    |> Macro.to_string()
    |> Code.format_string!()
    |> IO.puts()
  end

  # Expands fully the quoted AST (including macros and erlang function calls)
  # recompile && ElixirSessions.Helper.expanded_quoted
  def expanded_quoted() do
    expanded_quoted(ast())
  end

  def expanded_quoted(ast) do
    {ast, %Macro.Env{}} = :elixir_expand.expand(ast, __ENV__)

    ast
  end

  # recompile && ElixirSessions.Helper.expanded_quoted_prettify
  def expanded_quoted_prettify() do
    expanded_quoted_prettify(ast())
  end

  def expanded_quoted_prettify(ast) do
    expanded_quoted(ast)
    |> Macro.to_string()
    |> Code.format_string!()
    |> IO.puts()
  end
end
