defmodule ElixirST.Retriever do
  require Logger
  alias ElixirST.ST

  @moduledoc """
  Retrieves bytecode and (session) typechecks it.
  """

  @doc """
  Input as bytecode from a BEAM file, takes the Elixir AST from the debug_info
  and forwards it to the typechecker.
  """
  @spec process(binary, list) :: list
  def process(bytecode, options \\ []) do
    try do
      # Gets debug_info chunk from BEAM file
      chunks =
        case :beam_lib.chunks(bytecode, [:debug_info]) do
          {:ok, {_mod, chunks}} -> chunks
          {:error, _, error} -> throw({:error, inspect(error)})
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
                throw({:error, "Found version #{version} but expected :elixir_v1."})
            end

          x ->
            throw({:error, inspect(x)})
        end

      # Gets the list of session types, which were stored as attributes in the module
      session_types = Keyword.get_values(dbgi_map[:attributes], :session_type_collection)

      session_types_parsed =
        for {{name, arity}, session_type_string} <- Keyword.values(session_types) do
          {{name, arity}, ST.string_to_st(session_type_string)}
        end

      # Retrieve dual session types (as labels)
      duals = Keyword.get_values(dbgi_map[:attributes], :dual_unprocessed_collection)

      # Retrieve errors created within the @session/@dual/@spec attributes
      invalid_collection = Keyword.get_values(dbgi_map[:attributes], :invalid_collection)

      function_types = Keyword.get_values(dbgi_map[:attributes], :type_specs)

      all_functions =
        get_all_functions!(dbgi_map)
        |> add_types_to_functions(to_map(function_types))

      # If there were any errors collected in the invalid_collection attribute, then expose them
      for {{name, arity}, error_message} <- invalid_collection do
        # Match the function name/arity with its line number in file
        # for better error localization
        line = get_function_line(all_functions, name, arity)
        raise ElixirSTError, message: error_message, lines: [line || 1]
      end

      dual_session_types_parsed =
        for {{name, arity}, dual_label} <- duals do
          case Keyword.fetch(session_types, dual_label) do
            {:ok, {{_dual_name, _dual_arity}, session_type}} ->
              dual =
                ST.string_to_st(session_type)
                |> ST.dual()

              {{name, arity}, dual}

            :error ->
              error_message = "Dual session type '#{dual_label}' does not exist"
              line = get_function_line(all_functions, name, arity)
              raise ElixirSTError, message: error_message, lines: [line || 1]
          end
        end

      # Session typechecking of each individual function
      ElixirST.SessionTypechecking.session_typecheck_module(
        all_functions,
        to_map(session_types_parsed ++ dual_session_types_parsed),
        dbgi_map[:module],
        options
      )
    catch
      {:error, message} ->
        raise ElixirSTError, message: "Error while reading BEAM files: " <> message, lines: [1]

      :error, error = %ElixirSTError{} ->
        raise ElixirSTError, message: error.message, lines: error.lines
    end
  end

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
          Enum.reduce(function_body, {[], [], [], []}, fn {curr_m, curr_p, curr_g, curr_b}, {accu_m, accu_p, accu_g, accu_b} ->
            {[curr_m | accu_m], [curr_p | accu_p], [curr_g | accu_g], [curr_b | accu_b]}
          end)

        {{name, arity},
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
         }}

      x ->
        throw({:error, "Unknown info for #{inspect(x)}"})
    end)
    |> to_map()
  end

  defp add_types_to_functions(all_functions, function_types) do
    for {{name, arity}, function} <- all_functions do
      types = Map.get(function_types, {name, arity}, nil)

      if not is_nil(types) do
        {param_types, return_type} = types

        {{name, arity}, %{function | types_known?: true, return_type: return_type, param_types: param_types}}
      else
        {{name, arity}, function}
      end
    end
    |> to_map()
  end

  # Returns the line where a function is defined within a files
  defp get_function_line(all_functions, name, arity) do
    function_with_issues = Map.get(all_functions, {name, arity}, nil)

    if function_with_issues do
      function_with_issues.meta[:line]
    else
      nil
    end
  end
end
