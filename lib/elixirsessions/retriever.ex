defmodule ElixirSessions.Retriever do
  @moduledoc false
  def run do
    module = ElixirSessions.PingPong
    # IO.inspect module.module_info()

    info = module.module_info(:compile)
    path = Keyword.get(info, :source)
    # |> IO.inspect

    File.exists?(path)
    # |> IO.inspect

    beam_chunks =
      :code.which(module)
      |> :beam_lib.chunks([:debug_info])
      |> IO.inspect()


    # beam_chunks_ast_erlang =
    #   :code.which(module)
    #   |> :beam_lib.chunks([:abstract_code])
    #   |> IO.inspect()

    chunks =
      case beam_chunks do
        {:ok, {_mod, chunks}} -> chunks
        {:error, :beam_lib, error} -> throw(error)
      end

    {:debug_info_v1, backend, metadata} = chunks[:debug_info]

    # {:ok,{_,[{:abstract_code,{_, ac}}]}} = :beam_lib.chunks(Beam,[abstract_code]).
    # io:fwrite("~s~n", [erl_prettypr:format(erl_syntax:form_list(AC))]).

    map =
      case backend do
        :elixir_erl ->
          # Erlang extended AST available
          {:elixir_v1, map, _} = metadata
          map
      end

    # Code.compiler_options(ignore_module_conflict: true)

    # Code.compile_quoted({:__block, [line: 1], map[:definitions]})
    # {:__block, [line: 1], map[:definitions]}

    add =
      {:__block__, [],
       [
         {{:., [], [ST, :string_to_st]}, [], ["!Hellll()"]},
         {{:., [], [:erlang, :throw]}, [], ["HEELLELELOOO"]}
       ]}

    def_defp =
      map[:definitions]
      |> Enum.reduce(
        {%{}, %{}},
        fn
          {{function_name, arity}, :def, _meta, [{_line, _, _, function_body}]},
          {acc_def, acc_defp} ->
            {Map.put(acc_def, {function_name, arity}, function_body), acc_defp}

          {{function_name, arity}, :defp, _meta, [{_line, _, _, function_body}]},
          {acc_def, acc_defp} ->
            {acc_def, Map.put(acc_defp, {function_name, arity}, function_body)}

          _, acc ->
            acc
        end
      )

      # defmacro __using__(_) do
      #   [
      #     (quote do: Module.register_attribute __MODULE__,
      #       :langs, accumulate: true) |
      #     for lang <- ["es", "en"] do
      #       quote do
      #         def lang(unquote(lang)), do: unquote(lang)
      #         Module.put_attribute __MODULE__,
      #           :"lang_#{unquote(lang)}", unquote(lang)
      #         Module.put_attribute __MODULE__,
      #           :langs, unquote(lang)
      #       end
      #     end
      #   ]
      # end

    def_defp
    |> IO.inspect()

    # {{function_name, arity}, :def, meta, [{line, _, _, function_body}]}

    new_module =
      quote do
        defmodule unquote(map[:module]) do
          def hello() do
            unquote(add)
          end
        end
      end

    File.write!(Mix.Project.compile_path <> "/aa.ex", Macro.to_string(new_module))
    # Code.require_file(Mix.Project.compile_path <> "/aa.ex")
    Kernel.ParallelCompiler.compile_to_path([Mix.Project.compile_path <> "/aa.ex"], Mix.Project.compile_path)

    # Code.compile_quoted(new_module, map[:file])
    # map[:file]
    # path = map[:file]
    # path
    #   |> File.read!()
    #   |> Code.string_to_quoted()
    # |> Insert.print()

    # path
    #   |> get_file
    #   |> get_ast
    #   |> replace_function_that_matches_name
    #   |> ast_to_string
    #   |> string_to_file
    #   |> format_file
  end
end
