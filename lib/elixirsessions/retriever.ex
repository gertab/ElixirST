defmodule ElixirSessions.Retriever do
  @moduledoc """
  Retrieves bytecode and (session) typechecks it
  """

  @doc """
  Input as bytecode from a BEAM file, takes the Elixir AST from the debug_info
  and forwards it to the typechecker/s.
  """
  # todo fix: if called using mix session_check SmallExample, then process/2 is reached twice (in task and after_compile)
  @spec process(binary, list) :: list
  def process(bytecode, options \\ []) do
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

    # Gets the list of session types, which were stored as attributes in the module
    session_types = Keyword.get_values(dbgi_map[:attributes], :session_marked)

    session_types_parsed =
      session_types
      |> Enum.map(fn {{name, arity}, session_type_string} ->
        {{name, arity}, ST.string_to_st(session_type_string)}
      end)

    all_functions = get_all_functions!(dbgi_map)

    dbgi_map[:attributes]
    |> IO.inspect()

    # dbgi_map
    # |> IO.inspect()

    %{
      functions: all_functions,
      function_session_type: to_map(session_types_parsed),
      module_name: dbgi_map[:module]
    }
    |> ElixirSessions.SessionTypechecking.session_typecheck_module(options)
  end

  # todo add call to session typecheck a module explicitly from beam (rather than rely on @after_compile), e.g. kinda similar to ExUnit

  defp to_map(list) do
    list
    |> Enum.into(%{})
  end

  # Given the debug info chunk from the Beam files,
  # return a list of all functions

  # Structure of [Elixir] functions in Beam
  # {{name, arity}, :def_or_p, meta, [{meta, parameters, guards, body}, case2, ...]}
  # E.g.
  # {{:function1, 1}, :def, [line: 36],
  #  [
  #    {[line: 36], [7777],                       [],       {:__block__, [], [...]}}, # Case 1
  #    {[line: 47], [{:server, [line: 47], nil}], [guards], {...}                  }, # Case 2
  #    ...
  #  ]
  # }
  defp get_all_functions!(dbgi_map) do
    dbgi_map[:definitions]
    |> Enum.map(fn
      {{name, arity}, def_p, meta, function_body} ->
        # Unzipping function_body
        {metas, parameters, guards, bodies} =
          Enum.reduce(function_body, {[], [], [], []}, fn {curr_m, curr_p, curr_g, curr_b},
                                                          {accu_m, accu_p, accu_g, accu_b} ->
            {[curr_m | accu_m], [curr_p | accu_p], [curr_g | accu_g], [curr_b | accu_b]}
          end)

          kkk = parameters

          _ = kkk
        %ST.Function{
          name: name,
          arity: arity,
          def_p: def_p,
          meta: meta,
          cases: length(bodies),
          case_metas: metas,
          parameters: parameters,
          guards: guards,
          bodies: bodies
        }

      x ->
        throw("Unknown info for #{inspect(x)}")
    end)
  end
# To edit get a module, edit it, recompile it and reload it
  # def run do
    # module = ElixirSessions.PingPong
    # # IO.inspect module.module_info()

    # info = module.module_info(:compile)
    # path = Keyword.get(info, :source)
    # # |> IO.inspect

    # File.exists?(path)
    # # |> IO.inspect

    # beam_chunks =
    #   :code.which(module)
    #   |> :beam_lib.chunks([:debug_info])
    #   |> IO.inspect()


    # # beam_chunks_ast_erlang =
    # #   :code.which(module)
    # #   |> :beam_lib.chunks([:abstract_code])
    # #   |> IO.inspect()

    # chunks =
    #   case beam_chunks do
    #     {:ok, {_mod, chunks}} -> chunks
    #     {:error, :beam_lib, error} -> throw(error)
    #   end

    # {:debug_info_v1, backend, metadata} = chunks[:debug_info]

    # # {:ok,{_,[{:abstract_code,{_, ac}}]}} = :beam_lib.chunks(Beam,[abstract_code]).
    # # io:fwrite("~s~n", [erl_prettypr:format(erl_syntax:form_list(AC))]).

    # map =
    #   case backend do
    #     :elixir_erl ->
    #       # Erlang extended AST available
    #       {:elixir_v1, map, _} = metadata
    #       map
    #   end

    # # Code.compiler_options(ignore_module_conflict: true)

    # # Code.compile_quoted({:__block, [line: 1], map[:definitions]})
    # # {:__block, [line: 1], map[:definitions]}

    # add =
    #   {:__block__, [],
    #    [
    #      {{:., [], [ST, :string_to_st]}, [], ["!Hellll()"]},
    #      {{:., [], [:erlang, :throw]}, [], ["HEELLELELOOO"]}
    #    ]}

    # def_defp =
    #   map[:definitions]
    #   |> Enum.reduce(
    #     {%{}, %{}},
    #     fn
    #       {{function_name, arity}, :def, _meta, [{_line, _, _, function_body}]},
    #       {acc_def, acc_defp} ->
    #         {Map.put(acc_def, {function_name, arity}, function_body), acc_defp}

    #       {{function_name, arity}, :defp, _meta, [{_line, _, _, function_body}]},
    #       {acc_def, acc_defp} ->
    #         {acc_def, Map.put(acc_defp, {function_name, arity}, function_body)}

    #       _, acc ->
    #         acc
    #     end
    #   )

    #   # defmacro __using__(_) do
    #   #   [
    #   #     (quote do: Module.register_attribute __MODULE__,
    #   #       :langs, accumulate: true) |
    #   #     for lang <- ["es", "en"] do
    #   #       quote do
    #   #         def lang(unquote(lang)), do: unquote(lang)
    #   #         Module.put_attribute __MODULE__,
    #   #           :"lang_#{unquote(lang)}", unquote(lang)
    #   #         Module.put_attribute __MODULE__,
    #   #           :langs, unquote(lang)
    #   #       end
    #   #     end
    #   #   ]
    #   # end

    # def_defp
    # |> IO.inspect()

    # # {{function_name, arity}, :def, meta, [{line, _, _, function_body}]}

    # new_module =
    #   quote do
    #     defmodule unquote(map[:module]) do
    #       def hello() do
    #         unquote(add)
    #       end
    #     end
    #   end

    # File.write!(Mix.Project.compile_path <> "/aa.ex", Macro.to_string(new_module))
    # # Code.require_file(Mix.Project.compile_path <> "/aa.ex")
    # Kernel.ParallelCompiler.compile_to_path([Mix.Project.compile_path <> "/aa.ex"], Mix.Project.compile_path)

    # # Code.compile_quoted(new_module, map[:file])
    # # map[:file]
    # # path = map[:file]
    # # path
    # #   |> File.read!()
    # #   |> Code.string_to_quoted()
    # # |> Insert.print()

    # # path
    # #   |> get_file
    # #   |> get_ast
    # #   |> replace_function_that_matches_name
    # #   |> ast_to_string
    # #   |> string_to_file
    # #   |> format_file
  # end

end
