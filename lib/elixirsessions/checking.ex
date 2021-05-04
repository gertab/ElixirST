defmodule ElixirSessions.Checking do
  require Logger

  @moduledoc false
  # @moduledoc """
  # This module is the starting point of ElixirSessions. It parses the `@session` attribute and starts the AST code comparison with the session type.
  # """

  defmacro __using__(_) do
    quote do
      import ElixirSessions.Checking

      Module.register_attribute(__MODULE__, :session_typing, accumulate: false, persist: true)
      Module.register_attribute(__MODULE__, :session, accumulate: false, persist: false)
      Module.register_attribute(__MODULE__, :dual, accumulate: false, persist: false)
      Module.register_attribute(__MODULE__, :session_marked, accumulate: true, persist: true)
      @session_typing true
      @compile :debug_info

      @on_definition ElixirSessions.Checking
      @after_compile ElixirSessions.Checking

      IO.puts("ElixirSession started in #{IO.inspect(__MODULE__)}")
    end
  end

  def __on_definition__(env, kind, _name, _args, _guards, _body) do
    session = Module.get_attribute(env.module, :session)
    dual = Module.get_attribute(env.module, :dual)
    {name, arity} = env.function
    # spec = Module.get_attribute(env.module, :spec)
    # if not is_nil(spec) do
    #   IO.warn("Found spec: " <> inspect(spec))
    # end

    if not is_nil(session) do
      # @session_marked contains a list of functions with session types
      # E.g. [{{:pong, 0}, "?ping()"}, ...]
      # Ensure that only one session type is set for each function (in case of multiple cases)
      duplicate_session_types =
        Module.get_attribute(env.module, :session_marked)
        |> Enum.find(nil, fn
          {{^name, ^arity}, _} -> true
          _ -> false
        end)

      if not is_nil(duplicate_session_types) do
        throw("Cannot set multiple session types for the same function #{name}/#{arity}.")
      end

      if kind != :def do
        throw(
          "Session types can only be added to def function. " <>
            "#{name}/#{arity} is defined as defp."
        )
      end

      # Ensure that the session type is valid
      :ok = ST.validate!(session)

      Module.put_attribute(env.module, :session_marked, {{name, arity}, session})
      Module.delete_attribute(env.module, :session)
    end

    if not is_nil(dual) do
      if not is_function(dual) do
        throw("Expected function name but found #{inspect(dual)}.")
      end

      function = Function.info(dual)

      # dual_module = function[:module] # todo should be the same as current module
      dual_name = function[:name]
      dual_arity = function[:arity]
      # dual_type = function[:type] # should be :external (not :local = anon)

      dual_session =
        Module.get_attribute(env.module, :session_marked)
        |> Enum.find(nil, fn
          {{^dual_name, ^dual_arity}, _} -> true
          _ -> false
        end)

      if is_nil(dual_session) do
        throw("No dual match found for #{inspect dual}.")
      end

      {_name_arity, dual_session} = dual_session

      expected_dual_session =
        ST.string_to_st(dual_session)
        |> ST.dual()
        |> ST.st_to_string()

      Module.put_attribute(env.module, :session_marked, {{name, arity}, expected_dual_session})
      Module.delete_attribute(env.module, :dual)
    end
  end

  def __after_compile__(_env, bytecode) do
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
    session_types = Keyword.get_values(dbgi_map[:attributes], :session_marked)

    session_types_parsed =
      session_types
      |> Enum.map(fn {{name, arity}, session_type_string} ->
        {{name, arity}, ST.string_to_st(session_type_string)}
      end)

    all_functions = get_all_functions!(dbgi_map)

    # dbgi_map[:attributes]
    # |> IO.inspect()

    # dbgi_map
    # |> IO.inspect()

    %{
      functions: all_functions,
      function_session_type: to_map(session_types_parsed),
      file: dbgi_map[:file],
      relative_file: dbgi_map[:relative_file],
      line: dbgi_map[:line], #todo remove
      module_name: dbgi_map[:module]
    }
    |> ElixirSessions.SessionTypechecking.session_typecheck_module()
  end

  # todo add call to session typecheck a module explicitly from beam (rather than rely on @after_compile)

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

        %ST.Function{
          name: name,
          arity: arity,
          def_p: def_p,
          meta: meta,
          cases: length(bodies),
          metas: metas,
          parameters: parameters,
          guards: guards,
          bodies: bodies
        }

      x ->
        throw("Unknown info for #{inspect(x)}")
    end)
  end

  # todo
  # defmacro left ::: right do
  # end
end
