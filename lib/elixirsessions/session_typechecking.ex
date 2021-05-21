defmodule ElixirSessions.SessionTypechecking do
  require ST

  @moduledoc """
  Given a session type and Elixir code, the Elixir code is typechecked against the session type.
  """

  # todo correctly print atoms in error messages
  # todo improve error messages
  # todo do logger levels w/ options!
  # todo ignore variable type starting with _
  # todo use aliases
  # todo unfold multiple
  # todo erlang <=> elixir converter for custom operators
  # todo force session_check regardless of previous results
  # todo maybe ^x
  # todo todo remove subtypes
  # todo prettify type outputs
  # todo todo match labels with receive (allow multiple pattern matching cases)
  # todo remaining: function call
  ### todo case
  ### todo remaining: send
  ### todo remaining: receive
  ### todo remaining: case
  ### todo remaining: tuple
  ### todo remaining: if/unless

  @typedoc false
  @type ast :: ST.ast()
  @typedoc false
  @type session_type :: ST.session_type()

  # Session type checking a whole module, which may include multiple functions with multiple session type definitions
  @spec session_typecheck_module(
          %{
            functions: %{{ST.label(), non_neg_integer()} => ST.Function.t()},
            function_session_type: %{{ST.label(), non_neg_integer()} => session_type()},
            module_name: atom()
          },
          list
        ) :: list
  def session_typecheck_module(
        %{
          functions: all_functions,
          function_session_type: function_session_type,
          module_name: _module_name
        },
        _options \\ []
      ) do
    # IO.puts("Starting session type checking #{inspect(function_session_type)}")

    for {{name, arity}, expected_session_type} <- function_session_type do
      function = lookup_function!(all_functions, {name, arity})

      %ST.Function{
        types_known?: types_known?
      } = function

      if not types_known? do
        throw("Function #{name}/#{arity} has unknown return type. Use @spec to set parameter and return types.")
      end

      env = %{
        # :ok or :error or :warning
        :state => :ok,
        # error message
        :error_data => nil,
        # :x => :atom
        :variable_ctx => %{},
        # Expected session type
        # rec X.(!A().X)
        :session_type => expected_session_type,
        # Expected type
        :type => :any,
        # {name, arity} => %ST.Function
        :functions => all_functions,
        # {name, arity} => rec X.(!A().X)
        :function_session_type_ctx => function_session_type
      }

      result_env = session_typecheck_by_function(function, env)

      IO.puts("Results for: #{name}/#{arity}")

      %{
        state: result_env[:state],
        error_data: result_env[:error_data],
        variable_ctx: result_env[:variable_ctx],
        session_type: ST.st_to_string(result_env[:session_type]),
        type: result_env[:type],
        functions: result_env[:functions],
        function_session_type_ctx: result_env[:function_session_type_ctx]
      }
      |> IO.inspect()

      result_env
    end
  end

  @spec session_typecheck_by_function(ST.Function.t(), map()) :: map()
  def session_typecheck_by_function(%ST.Function{} = function, env) do
    %ST.Function{
      name: name,
      arity: arity,
      bodies: bodies,
      return_type: expected_return_type,
      parameters: parameters,
      param_types: param_types
    } = function

    all_results =
      for {ast, parameters} <- List.zip([bodies, parameters]) do
        # Initialize the variable context with the parameters and their types
        variable_ctx =
          Enum.zip(parameters, param_types)
          |> remove_nils()
          |> Enum.into(%{})

        env = %{env | variable_ctx: variable_ctx}

        {_ast, res_env} = Macro.prewalk(ast, env, &typecheck/2)

        res_env
      end

      Enum.reduce_while(all_results, hd(all_results), fn result, _acc ->
        case result[:state] do
          :error ->
            {:halt, result}

          _ ->
            # Check return type
            common_type = ElixirSessions.TypeOperations.greatest_lower_bound(result[:type], expected_return_type)

            cond do
              result[:session_type] != %ST.Terminate{} ->
                {:halt,
                 %{
                   result
                   | state: :error,
                     error_data: "Function #{name}/#{arity} terminates with remaining session type " <> ST.st_to_string(result[:session_type])
                 }}

              common_type == :error ->
                {:halt,
                 %{
                   result
                   | state: :error,
                     error_data: "Return type for #{name}/#{arity} is #{inspect(result[:type])} but expected" <> inspect(expected_return_type)
                 }}

              true ->
                {:cont, result}
            end
        end
      end)


  end

  @spec typecheck(ast(), map()) :: {ast(), map()}
  def typecheck(
        node,
        %{
          state: :error,
          error_data: _error_data,
          variable_ctx: _,
          session_type: _,
          type: _,
          functions: _,
          function_session_type_ctx: _
        } = env
      ) do
    # IO.warn("Error!" <> inspect(error_data))
    # throw("ERROR" <> inspect(error_data))
    {node, env}
  end

  # Block
  def typecheck({:__block__, meta, args}, env) do
    IO.puts("# Block #{inspect(args)}")
    node = {:__block__, meta, args}

    {node, env}
  end

  # Literals
  def typecheck(node, env)
      when is_atom(node) or is_number(node) or is_binary(node) or is_boolean(node) or
             is_float(node) or is_integer(node) or is_nil(node) or is_pid(node) do
    IO.puts("# Literal: #{inspect(node)} #{ElixirSessions.TypeOperations.typeof(node)}")

    {node, %{env | type: ElixirSessions.TypeOperations.typeof(node)}}
  end

  # Tuples
  def typecheck({:{}, meta, args}, env) when is_list(args) do
    node = {:{}, meta, []}

    {types_list, new_env} =
      Enum.map(args, fn arg -> elem(Macro.prewalk(arg, env, &typecheck/2), 1) end)
      |> Enum.reduce_while({[], env}, fn result, {types_list, env_acc} ->
        case result[:state] do
          :error ->
            {:halt, {[], result}}

          _ ->
            {:cont, {types_list ++ [result[:type]], %{env_acc | variable_ctx: Map.merge(env_acc[:variable_ctx], result[:variable_ctx] || %{})}}}
        end
      end)

    {node, %{new_env | type: {:tuple, types_list}}}
  end

  # Tuples (of size 2)
  def typecheck({arg1, arg2}, env) do
    node = {:{}, [], [arg1, arg2]}
    typecheck(node, env)
  end

  # List
  def typecheck(node, env) when is_list(node) do
    IO.puts("# List")

    # todo
    {node, env}
  end

  # Operations
  def typecheck({{:., meta1, [:erlang, operator]}, meta2, [arg1, arg2]}, env)
      when operator in [:+, :-, :*, :/] do
    IO.puts("# Erlang #{operator}")
    node = {{:., meta1, []}, meta2, []}

    process_binary_operations(node, meta2, operator, arg1, arg2, :number, false, env)
  end

  # too complex in extended elixir: [:and, :or]

  # Elixir format:          [:==, :!=,   :===,   :!== ,  :>, :<, :<=,   :>=  ]
  # Extended Elixir format: [:==, :"/=", :"=:=", :"=/=", :>, :<, :"=<", :">="]
  def typecheck({{:., meta1, [:erlang, operator]}, meta2, [arg1, arg2]}, env)
      when operator in [:==, :"/=", :"=:=", :"=/=", :>, :<, :"=<", :>=] do
    node = {{:., meta1, []}, meta2, []}
    # todo convert operator from extened elixir to elixir
    process_binary_operations(node, meta2, operator, arg1, arg2, :any, true, env)
  end

  # Not
  def typecheck({{:., _meta1, [:erlang, :not]}, meta2, [arg]} = node, env) do
    process_unary_operations(node, meta2, arg, :boolean, env)
  end

  # Negate
  def typecheck({{:., _meta1, [:erlang, :-]}, meta2, [arg]}, env) do
    IO.puts("# Erlang negation")

    node = {nil, meta2, []}
    process_unary_operations(node, meta2, arg, :number, env)
  end

  def typecheck({{:., _meta1, [:erlang, erlang_function]}, meta2, _arg}, env)
      when erlang_function not in [:send, :self] do
    IO.puts("# Erlang others #{erlang_function} (not supported)")
    node = {nil, meta2, []}

    {node, %{env | state: :error, error_data: error_message("Unknown erlang function #{inspect(erlang_function)}", meta2)}}
  end

  # Binding operator
  def typecheck({:=, meta, [pattern, expr]}, env) do
    IO.puts("# Binding op")
    node = {:=, meta, []}

    {_expr_ast, expr_env} = Macro.prewalk(expr, env, &typecheck/2)

    case expr_env[:state] do
      :error ->
        {node, expr_env}

      _ ->
        pattern = if is_list(pattern), do: pattern, else: [pattern]
        pattern_vars = ElixirSessions.TypeOperations.var_pattern(pattern, [expr_env[:type]])

        case pattern_vars do
          {:error, msg} -> {node, %{expr_env | state: :error, error_data: error_message(msg, meta)}}
          _ -> {node, %{expr_env | variable_ctx: Map.merge(expr_env[:variable_ctx], pattern_vars || %{})}}
        end
    end
  end

  # Variables
  def typecheck({x, meta, arg}, env) when is_atom(arg) do
    IO.puts("# Variable #{inspect(x)}: #{inspect(env[:variable_ctx][x])}")
    node = {x, meta, arg}

    case env[:variable_ctx][x] do
      nil -> {node, %{env | state: :error, error_data: error_message("Variable #{x} was not found", meta)}}
      type -> {node, %{env | type: type}}
    end
  end

  # Case
  def typecheck({:case, meta, [expr, body | _]}, env) do
    # body contains [do: [ {:->, _, [ [ when/condition ], work ]}, other_cases... ] ]
    node = {:case, meta, []}
    cases = process_cases(body[:do])

    {_expr_ast, expr_env} = Macro.prewalk(expr, env, &typecheck/2)

    result =
      case expr_env[:state] do
        :error ->
          {:error, {:inner_error, expr_env[:error_data]}}

        _ ->
          # Get label, parameters and remaining ast from the source ast
          all_cases_result =
            Enum.map(cases, fn {lhs, rhs} ->
              pattern_vars = ElixirSessions.TypeOperations.var_pattern([lhs], [expr_env[:type]]) || %{}

              case pattern_vars do
                {:error, msg} ->
                  {:error, msg}

                _ ->
                  env = %{env | variable_ctx: Map.merge(env[:variable_ctx], pattern_vars)}

                  {_case_ast, case_env} = Macro.prewalk(rhs, env, &typecheck/2)

                  case case_env[:state] do
                    :error -> {:error, case_env[:error_data]}
                    _ -> case_env
                  end
              end
            end)

          process_cases_result(all_cases_result)
      end

    case result do
      {:error, _} = error -> {node, append_error(env, error, meta)}
      _ -> {node, %{env | session_type: result[:session_type], type: result[:type]}}
    end
  end

  # Send Function
  def typecheck({{:., _meta1, [:erlang, :send]}, meta2, [send_destination, send_body | _]}, env) do
    IO.puts("# Erlang send")

    node = {nil, meta2, []}

    {_ast1, send_destination_env} = Macro.prewalk(send_destination, env, &typecheck/2)
    {_ast2, send_body_env} = Macro.prewalk(send_body, env, &typecheck/2)

    try do
      if send_destination_env[:state] == :error do
        throw({:error, send_destination_env[:error_data]})
      end

      if send_body_env[:state] == :error do
        throw({:error, send_body_env[:error_data]})
      end

      if ElixirSessions.TypeOperations.subtype?(send_destination_env[:type], :pid) == false do
        throw({:error, "Expected pid in send statement, but found #{inspect(send_destination_env[:type])}"})
      end

      if ElixirSessions.TypeOperations.subtype?(send_body_env[:type], {:tuple, :any}) == false do
        throw({:error, "Expected a tuple in send statement containing {:label, ...}"})
      end

      {:tuple, [label_type | parameter_types]} = send_body_env[:type]

      [label | parameters] = tuple_to_list(send_body)

      if ElixirSessions.TypeOperations.subtype?(label_type, :atom) == false do
        throw({:error, "First item in tuple should be a literal/atom"})
      end

      # Unfold if session type starts with rec X.
      session_type = ST.unfold_current(env[:session_type])

      %ST.Send{label: expected_label, types: expected_types, next: remaining_session_types} =
        case session_type do
          %ST.Send{} = st ->
            st

          %ST.Choice{choices: choices} ->
            if choices[label] do
              choices[label]
            else
              throw(
                {:error,
                 "Cannot match send statement `#{Macro.to_string(send_body)}` " <>
                   "with #{ST.st_to_string_current(session_type)}"}
              )
            end

          x ->
            throw({:error, "Found a send/choice, but expected #{ST.st_to_string(x)}."})
        end

      if expected_label != label do
        throw({:error, "Expected send with label #{inspect(expected_label)} but found #{inspect(label)}."})
      end

      if length(expected_types) != length(parameter_types) do
        throw(
          {:error,
           "Session type parameter length mismatch. Expected " <>
             "#{ST.st_to_string_current(session_type)} (length = " <>
             "#{length(expected_types)}), but found #{Macro.to_string(send_body)} " <>
             "(length = #{length(parameter_types)})."}
        )
      end

      if ElixirSessions.TypeOperations.subtype?(parameter_types, expected_types) == false do
        throw(
          {:error,
           "Incorrect parameter types. Expected " <>
             "#{ST.st_to_string_current(session_type)} " <>
             "but found #{Macro.to_string(parameters)} with type/s #{inspect(parameter_types)}"}
        )
      end

      {node, %{send_body_env | session_type: remaining_session_types}}
    catch
      {:error, message} ->
        {node, %{env | state: :error, error_data: error_message(message, meta2)}}

      x ->
        throw("Unknown error: " <> inspect(x))
    end
  end

  # Receive
  def typecheck({:receive, meta, [body | _]}, env) do
    # body contains [do: [ {:->, _, [ [ when/condition ], work ]}, other_cases... ] ]

    node = {:receive, meta, []}
    cases = process_cases(body[:do])

    try do
      # In case of one receive branch, it should match with a %ST.Recv{}
      # In case of more than one receive branch, it should match with a %ST.Branch{}
      # Unfold if session type starts with rec X.(...)
      session_type = ST.unfold_current(env[:session_type])

      branches_session_types =
        case session_type do
          %ST.Branch{branches: branches} -> branches
          %ST.Recv{label: label, types: types, next: next} -> %{label => %ST.Recv{label: label, types: types, next: next}}
          x -> throw({:error, "Found a receive/branch, but expected #{ST.st_to_string(x)}."})
        end

      # Each branch from the session type should have an equivalent branch in the receive cases
      if map_size(branches_session_types) != length(cases) do
        throw(
          {:error,
           "[in branch/receive] Mismatch in number of receive and & branches. " <>
             "Expected session type #{ST.st_to_string_current(session_type)}"}
        )
      end

      # Get label, parameters and remaining AST from the source AST
      all_branches_result =
        Enum.map(cases, fn {lhs, rhs} ->
          [head | _] = tuple_to_list(lhs)

          if branches_session_types[head] do
            %ST.Recv{types: expected_types, next: remaining_st} = branches_session_types[head]

            pattern_vars = ElixirSessions.TypeOperations.var_pattern([lhs], [{:tuple, [:atom] ++ expected_types}]) || %{}

            case pattern_vars do
              {:error, msg} ->
                {:error, msg}

              _ ->
                env = %{
                  env
                  | session_type: remaining_st,
                    variable_ctx: Map.merge(env[:variable_ctx], pattern_vars)
                }

                {_branch_ast, branch_env} = Macro.prewalk(rhs, env, &typecheck/2)

                case branch_env[:state] do
                  :error -> {:error, {:inner_error, branch_env[:error_data]}}
                  _ -> branch_env
                end
            end
          else
            throw({:error, "Receive branch with label #{inspect(head)} did not match session type"})
          end
        end)

      case process_cases_result(all_branches_result) do
        {:error, message} ->
          throw({:error, message})

        result ->
          {node, %{env | session_type: result[:session_type], type: result[:type]}}
      end
    catch
      {:error, _} = error ->
        {node, append_error(env, error, meta)}

      x ->
        throw("Unknown error: " <> inspect(x))
    end
  end

  # Hardcoded stuff (cheating)
  def typecheck({{:., _meta1, [:erlang, :self]}, meta2, []}, env) do
    IO.puts("# erlang self")
    node = {nil, meta2, []}
    {node, %{env | type: :pid}}
  end

  def typecheck({{:., _meta, _}, meta2, _}, env) do
    IO.puts("# Remote function call")
    node = {nil, meta2, []}

    {node, %{env | state: :error, error_data: error_message("Remote functions not allowed.", meta2)}}
  end

  def typecheck({:., meta, _}, env) do
    node = {nil, meta, []}
    {node, env}
  end

  # Functions
  def typecheck({name, meta, args}, env) when is_list(args) do
    IO.puts("# Function #{inspect(name)}")
    node = {name, meta, []}

    name_arity = {name, length(args)}

    try do
      function =
        case lookup_function(env[:functions], name_arity) do
          {:error, message} ->
            # Function does not exist in current module
            throw({:error, message})

          {:ok, function} ->
            function
        end

      if not function.types_known? do
        throw({:error, "Function #{name}/#{length(args)} has unknown return type. Use @spec to set parameter and return types."})
      end

      if env[:function_session_type_ctx][name_arity] do
        # Function with known session type (i.e. def with @session)
        function_session_type = env[:function_session_type_ctx][name_arity]
        expected_session_type = env[:session_type]

        if ST.equal?(function_session_type, expected_session_type) do
          {node, %{env | session_type: %ST.Terminate{}, type: function.return_type}}
        else
          throw(
            {:error,
             "Function #{name}/#{length(args)} has session type #{ST.st_to_string(function_session_type)} " <>
               "but was expecting #{ST.st_to_string_current(expected_session_type)}."}
          )
        end
      else
        # Function with unknown session type (i.e. defp)
        new_env = %{
          env
          | variable_ctx: %{},
            function_session_type_ctx: Map.merge(env[:function_session_type_ctx], %{name_arity => env[:session_type]})
        }

        new_env = session_typecheck_by_function(function, new_env)

        cond do
          new_env[:state] == :error ->
            throw({:error, new_env[:error_data]})

          new_env[:session_type] != %ST.Terminate{} ->
            throw({:error, "Function #{name}/#{length(args)} does not match the session type " <> ST.st_to_string(env[:session_type])})

          true ->
            {node, %{env | session_type: new_env[:session_type], type: new_env[:type]}}
        end
      end
    catch
      {:error, _} = error ->
        {node, append_error(env, error, meta)}

      x ->
        throw("Unknown error: " <> inspect(x))
    end
  end

  def typecheck(other, env) do
    IO.puts("# other #{inspect(other)}")
    {other, env}
  end

  # recompile && ElixirSessions.SessionTypechecking.run
  def run() do
    # &{?hello1(boolean), ?hello2(number)}
    ast =
      quote do
        a = p

        receive do
          {:hello, value} ->
            x = not value
            a = a < 4
            send(self(), {:abc, a, x})
        end

        a
      end

    st = ST.string_to_st("?hello(boolean).!abc(boolean, boolean)")

    env = %{
      :state => :ok,
      :error_data => nil,
      :variable_ctx => %{},
      :session_type => st,
      :type => :any,
      :functions => %{},
      :function_session_type_ctx => %{}
    }

    ElixirSessions.Helper.expanded_quoted(ast)
    |> IO.inspect()
    |> Macro.prewalk(env, &typecheck/2)

    # |> elem(0)
  end

  # Returns the lhs and rhs for all cases (i.e. lhs -> rhs)
  defp process_cases(cases) do
    Enum.map(cases, fn
      {:->, _, [[{:when, _, [var, _cond | _]}] | rhs]} ->
        {var, rhs}

      {:->, _, [[lhs] | rhs]} ->
        {lhs, rhs}
    end)
  end

  # Reduces a list of environments, ensuring that the type and session type are the same
  defp process_cases_result(all_cases) when is_list(all_cases) do
    Enum.reduce_while(all_cases, hd(all_cases), fn curr_case, acc ->
      case curr_case do
        {:error, message} ->
          {:halt, {:error, message}}

        _ ->
          common_type = ElixirSessions.TypeOperations.greatest_lower_bound(curr_case[:type], acc[:type])

          if common_type == :error do
            {:halt,
             {:error,
              "Types #{inspect(curr_case[:type])} and #{inspect(acc[:type])} do not match. Different " <>
                "cases should have end up with the same type."}}
          else
            if ST.equal?(curr_case[:session_type], acc[:session_type]) do
              {:cont, %{curr_case | type: common_type}}
            else
              {:halt,
               {:error,
                "Mismatch in session type following the case: " <>
                  "#{ST.st_to_string(curr_case[:session_type])} and " <>
                  "#{ST.st_to_string(acc[:session_type])}"}}
            end
          end
      end
    end)
  end

  defp append_error(env, {:error, {:inner_error, message}}, _meta) do
    %{env | state: :error, error_data: message}
  end

  defp append_error(env, {:error, message}, meta) do
    %{env | state: :error, error_data: error_message(message, meta)}
  end

  defp process_binary_operations(node, meta, operator, arg1, arg2, max_type, is_comparison, env) do
    {_op1_ast, op1_env} = Macro.prewalk(arg1, env, &typecheck/2)
    {_op2_ast, op2_env} = Macro.prewalk(arg2, env, &typecheck/2)

    try do
      if op1_env[:state] == :error do
        throw({:error, {:inner_error, op1_env[:error_data]}})
      end

      if op2_env[:state] == :error do
        throw({:error, {:inner_error, op2_env[:error_data]}})
      end

      if is_comparison do
        {node,
         %{
           op1_env
           | type: :boolean,
             variable_ctx: Map.merge(op1_env[:variable_ctx], op2_env[:variable_ctx] || %{})
         }}
      else
        common_type = ElixirSessions.TypeOperations.greatest_lower_bound(op1_env[:type], op2_env[:type])

        if common_type == :error do
          {node,
           %{
             op1_env
             | state: :error,
               error_data:
                 error_message(
                   "Operator type problem in #{inspect(operator)}: #{inspect(op1_env[:type])}, #{inspect(op2_env[:type])} are not of the same type",
                   meta
                 )
           }}
        end

        if ElixirSessions.TypeOperations.subtype?(common_type, max_type) do
          {node,
           %{
             op1_env
             | type: common_type,
               variable_ctx: Map.merge(op1_env[:variable_ctx], op2_env[:variable_ctx] || %{})
           }}
        else
          throw(
            {:error,
             "Operator type problem in #{inspect(operator)}: #{inspect(op1_env[:type])}, " <>
               "#{inspect(op2_env[:type])} is not of type #{inspect(max_type)}"}
          )
        end
      end
    catch
      {:error, message} ->
        {node, %{env | state: :error, error_data: error_message(message, meta)}}

      x ->
        throw("Unknown error: " <> inspect(x))
    end
  end

  defp process_unary_operations(node, meta, arg1, max_type, env) do
    {_op1_ast, op1_env} = Macro.prewalk(arg1, env, &typecheck/2)

    case op1_env[:state] do
      :error ->
        {node, op1_env}

      _ ->
        expected_type = ElixirSessions.TypeOperations.greatest_lower_bound(op1_env[:type], max_type)

        case expected_type do
          :error ->
            {node,
             %{
               op1_env
               | state: :error,
                 error_data:
                   error_message(
                     "Type problem: Found #{inspect(op1_env[:type])} but expected a #{inspect(max_type)}",
                     meta
                   )
             }}

          _ ->
            {node, op1_env}
        end
    end
  end

  defp tuple_to_list({arg1, arg2}) do
    [arg1, arg2]
  end

  defp tuple_to_list({:{}, _, args}) do
    args
  end

  defp remove_nils(list) do
    Enum.filter(
      list,
      fn
        {nil, _} -> false
        _ -> true
      end
    )
  end

  # @doc """
  # Given a function (and its body), it is compared to a session type. `fun` is
  # the function name and `body` is the function body as AST.
  # """
  # # todo remove
  # @spec session_typecheck(atom(), arity(), ast(), session_type()) :: :ok
  # def session_typecheck(fun, arity, body, session_type) do
  #   IO.puts("Session typechecking of &#{to_string(fun)}/#{arity}")

  #   IO.puts("Session typechecking: #{ST.st_to_string(session_type)}")

  #   {_, _, remaining_session_type} =
  #     session_typecheck_ast(body, session_type, %{}, %{}, %{})

  #   case remaining_session_type do
  #     %ST.Terminate{} ->
  #       IO.puts("Session type checking was successful.")
  #       :ok

  #     # todo what if call_recursive
  #     _ ->
  #       throw("Remaining session type: #{ST.st_to_string(remaining_session_type)}")
  #   end

  #   # case contains_recursion?(inferred_session_type) do
  #   #   true -> [{:recurse, :X, inferred_session_type}]
  #   #   false -> inferred_session_type
  #   # end
  # end

  # @doc """
  # Traverses the given Elixir `ast` and session-typechecks it with respect to the `session_type`.
  # """
  # # @spec session_typecheck_ast(ast(), session_type(), %{}, %{}, %{}) ::
  # #         {%{}, %{}, session_type()}
  # def session_typecheck_ast(body, session_type, rec_var, function_st_context, module_context)

  # def session_typecheck_ast(
  #       body,
  #       %ST.Recurse{} = recurse,
  #       rec_var,
  #       function_st_context,
  #       module_context
  #     ) do
  #   %ST.Recurse{label: label, body: session_type_body} = recurse

  #   if Map.has_key?(rec_var, label) do
  #     if not ST.equal?(recurse, Map.get(rec_var, label, %ST.Terminate{})) do
  #       IO.puts(
  #         "Replacing the recursive variable #{label} with new " <>
  #           "session type #{ST.st_to_string(Map.get(rec_var, label, %ST.Terminate{}))}"
  #       )
  #     end
  #   end

  #   rec_var = Map.put(rec_var, label, recurse)

  #   session_typecheck_ast(body, session_type_body, rec_var, function_st_context, module_context)
  # end

  # def session_typecheck_ast(
  #       body,
  #       %ST.Call_Recurse{label: label},
  #       rec_var,
  #       function_st_context,
  #       module_context
  #     ) do
  #   session_type_body =
  #     case Map.fetch(rec_var, label) do
  #       {:ok, session_type} -> session_type
  #       :error -> throw("Calling unbound variable: #{label} #{inspect(rec_var)}.")
  #     end

  #   session_typecheck_ast(body, session_type_body, rec_var, function_st_context, module_context)
  # end

  # # literals
  # def session_typecheck_ast(x, session_type, rec_var, function_st_context, _module_context)
  #     when is_atom(x) or is_number(x) or is_binary(x) do
  #   # IO.puts("\literal: ")
  #   {rec_var, function_st_context, session_type}
  # end

  # def session_typecheck_ast({a, b}, session_type, rec_var, function_st_context, module_context) do
  #   # IO.puts("\nTuple: ")

  #   {rec_var, function_st_context, remaining_session_type} =
  #     session_typecheck_ast(a, session_type, rec_var, function_st_context, module_context)

  #   session_typecheck_ast(b, remaining_session_type, rec_var, function_st_context, module_context)
  # end

  # def session_typecheck_ast(
  #       [head | tail],
  #       session_type,
  #       rec_var,
  #       function_st_context,
  #       module_context
  #     ) do
  #   # IO.puts("\nlist:")

  #   # Split the session type in two.
  #   # First, perform session type checking for the first operation (head).
  #   # Then, do the remaining session type checking for the remaining statements (tail).
  #   {rec_var, function_st_context, remaining_session_type} =
  #     session_typecheck_ast(head, session_type, rec_var, function_st_context, module_context)

  #   session_typecheck_ast(
  #     tail,
  #     remaining_session_type,
  #     rec_var,
  #     function_st_context,
  #     module_context
  #   )
  # end

  # # Non literals
  # def session_typecheck_ast(
  #       {:__block__, _meta, args},
  #       session_type,
  #       rec_var,
  #       function_st_context,
  #       module_context
  #     ) do
  #   session_typecheck_ast(args, session_type, rec_var, function_st_context, module_context)
  # end

  # def session_typecheck_ast(
  #       {:=, _meta, [_left, right]},
  #       session_type,
  #       rec_var,
  #       function_st_context,
  #       module_context
  #     ) do
  #   # Session type check the right part of the pattern matching operator (i.e. =)
  #   session_typecheck_ast(right, session_type, rec_var, function_st_context, module_context)
  # end

  # def session_typecheck_ast(
  #       {:send, meta, [a, send_body | _]},
  #       session_type,
  #       rec_var,
  #       function_st_context,
  #       module_context
  #     ) do
  #   # todo make ast expand -> then remove this shit
  #   session_typecheck_ast(
  #     {{:., [], [:erlang, :send]}, meta, [a, send_body]},
  #     session_type,
  #     rec_var,
  #     function_st_context,
  #     module_context
  #   )
  # end

  # def session_typecheck_ast(
  #       {{:., _, [:erlang, :send]}, meta, [_, send_body | _]} = ast,
  #       session_type,
  #       rec_var,
  #       function_st_context,
  #       module_context
  #     ) do
  #   # IO.puts("[in send] #{inspect(session_type)}")

  #   line =
  #     if meta[:line] do
  #       "[Line #{meta[:line]}]"
  #     else
  #       "[Line unknown]"
  #     end

  #   {actual_label, actual_parameters} = parse_options(send_body)

  #   case session_type do
  #     %ST.Send{label: expected_label, types: expected_types, next: next} ->
  #       # todo ensure types correctness for parameters

  #       if expected_label != actual_label do
  #         throw("#{line} Expected send with label :#{expected_label} but found :#{actual_label}.")
  #       end

  #       if length(expected_types) != length(actual_parameters) do
  #         throw(
  #           "#{line} Session type parameter length mismatch. Expected " <>
  #             "#{ST.st_to_string_current(session_type)} (length = " <>
  #             "#{length(expected_types)}), but found #{Macro.to_string(send_body)} " <>
  #             "(length = #{List.to_string(actual_parameters)})."
  #         )
  #       end

  #       {rec_var, function_st_context, next}

  #     %ST.Choice{choices: choices} ->
  #       case Map.fetch(choices, actual_label) do
  #         {:ok, expected_send_sessiontype} ->
  #           # Recurse with the '!' session type inside the '+'
  #           session_typecheck_ast(
  #             ast,
  #             expected_send_sessiontype,
  #             rec_var,
  #             function_st_context,
  #             module_context
  #           )

  #         :error ->
  #           throw(
  #             "#{line} Cannot match send statement `#{Macro.to_string(ast)}` " <>
  #               "with #{ST.st_to_string_current(session_type)}."
  #           )
  #       end

  #     _ ->
  #       throw(
  #         "#{line} Cannot match send statement `#{Macro.to_string(ast)}` " <>
  #           "with #{ST.st_to_string_current(session_type)}."
  #       )
  #   end
  # end

  # def session_typecheck_ast(
  #       {:receive, meta, [body | _]},
  #       session_type,
  #       rec_var,
  #       function_st_context,
  #       module_context
  #     ) do
  #   # body contains [do: [ {:->, _, [ [ when/condition ], work ]}, other_cases... ] ]
  #   # IO.puts("[in recv] #{inspect(session_type)}")

  #   line =
  #     if meta[:line] do
  #       "[Line #{meta[:line]}]"
  #     else
  #       "[Line unknown]"
  #     end

  #   cases = body[:do]

  #   if length(cases) == 0 do
  #     throw("Should not happen [receive statements need to have 1 or more cases]")
  #   end

  #   # 1 or more receive branches
  #   # In case of one receive branch, it should match with a %ST.Recv{}
  #   # In case of more than one receive branch, it should match with a %ST.Branch{}
  #   branches_session_types =
  #     case session_type do
  #       %ST.Branch{branches: branches} ->
  #         branches

  #       %ST.Recv{label: label, types: types, next: next} ->
  #         %{label => %ST.Recv{label: label, types: types, next: next}}

  #       x ->
  #         throw("#{line} Found a receive/branch, but expected #{ST.st_to_string(x)}.")
  #     end

  #   # Each branch from the session type should have an equivalent branch in the receive cases
  #   if map_size(branches_session_types) != length(cases) do
  #     throw(
  #       "#{line} [in branch/receive] Mismatch in number of receive and & branches. " <>
  #         "Expected session type #{ST.st_to_string_current(session_type)}"
  #     )
  #   end

  #   # Get label, parameters and remaining ast from the source ast
  #   # label_types_ast = %{{label1 => {parameters1, remaining_ast1}}, ...}
  #   label_parameters_ast =
  #     Enum.map(cases, fn
  #       {:->, _, [[lhs] | rhs]} ->
  #         # Given: {:a, b} when is_atom(b) -> do_something()
  #         # lhs contains data related to '{:a, b} when is_atom(b)'
  #         # rhs contains the body, e.g. 'do_something()'
  #         {label, parameters} = parse_options(lhs)
  #         {label, {parameters, rhs}}
  #     end)
  #     |> Enum.into(%{})

  #   # Compare the actual branches (from label_parameters_ast)
  #   # with the branch session type (in branches_session_types)
  #   Enum.map(
  #     branches_session_types,
  #     fn {st_label, branch_session_type} ->
  #       # Match the label with the correct branch
  #       case Map.fetch(label_parameters_ast, st_label) do
  #         {:ok, {actual_parameters, inside_ast}} ->
  #           # Match the number of parameters found (in ast) and expected (in st)
  #           %ST.Recv{types: expected_types, next: inside_branch_session_type} =
  #             branch_session_type

  #           if length(expected_types) != length(actual_parameters) do
  #             throw(
  #               "#{line} Session type parameter length mismatch. Expected " <>
  #                 "#{ST.st_to_string_current(session_type)} (length = #{length(expected_types)}), " <>
  #                 "but found #{inspect(actual_parameters)} (length = #{length(actual_parameters)})."
  #             )
  #           end

  #           # Recursively session typecheck the inside of the branch
  #           session_typecheck_ast(
  #             inside_ast,
  #             inside_branch_session_type,
  #             rec_var,
  #             function_st_context,
  #             module_context
  #           )

  #         :error ->
  #           throw(
  #             "Receive branch with label :#{st_label} expected but not found. Session type " <>
  #               "#{ST.st_to_string_current(%ST.Branch{branches: branches_session_types})}."
  #           )
  #       end
  #     end
  #   )
  #   # Ensure that allnodet in remaining_branches_session_types are the same, and return the last one
  #   |> Enum.reduce(fn full_st, full_acc ->
  #     {rec_var, function_st_context, st} = full_st
  #     {_, _, acc} = full_acc

  #     if ST.equal?(st, acc) do
  #       {rec_var, function_st_context, st}
  #     else
  #       throw(
  #         "#{line} Mismatch in session type following the branch: " <>
  #           "#{ST.st_to_string(st)} and #{ST.st_to_string(acc)}"
  #       )
  #     end
  #   end)
  # end

  # def session_typecheck_ast(
  #       {:case, meta, [_what_you_are_checking, body | _]},
  #       session_type,
  #       rec_var,
  #       function_st_context,
  #       module_context
  #     ) do
  #   # body contains [do: [ {:->, _, [ [ when/condition ], work ]}, other_cases... ] ]
  #   # IO.puts("[in case/choice] #{inspect(session_type)}")

  #   line =
  #     if meta[:line] do
  #       "[Line #{meta[:line]}]"
  #     else
  #       "[Line unknown]"
  #     end

  #   cases = body[:do]

  #   if length(cases) == 0 do
  #     throw("Should not happen [case statements need to have 1 or more cases]")
  #   end

  #   inner_ast =
  #     Enum.map(cases, fn
  #       {:->, _, [[_lhs] | rhs]} ->
  #         # Given: {:a, b} when is_atom(b) -> do_something()
  #         # lhs contains data related to '{:a, b} when is_atom(b)'
  #         # rhs contains the body, e.g. 'do_something()'
  #         # {label, parameters} = parse_options(lhs)
  #         rhs
  #     end)

  #   # Do session type checking with each branch in the case.
  #   # All branches need to be correct (no violations), and
  #   # all branches need to end up in the same session type state.
  #   Enum.map(
  #     inner_ast,
  #     fn ast ->
  #       session_typecheck_ast(
  #         ast,
  #         session_type,
  #         rec_var,
  #         function_st_context,
  #         module_context
  #       )
  #     end
  #   )
  #   # Ensure that all session types are in the same, and return the last one
  #   |> Enum.reduce(fn full_st, full_acc ->
  #     {rec_var, function_st_context, st} = full_st
  #     {_, _, acc} = full_acc

  #     if ST.equal?(st, acc) do
  #       {rec_var, function_st_context, st}
  #     else
  #       throw(
  #         "#{line} Mismatch in session type following the choice: #{ST.st_to_string(st)} " <>
  #           "and #{ST.st_to_string(acc)}"
  #       )
  #     end
  #   end)
  # end

  # def session_typecheck_ast(
  #       {:|>, _meta, _args},
  #       session_type,
  #       rec_var,
  #       function_st_context,
  #       _module_context
  #     ) do
  #   {rec_var, function_st_context, session_type}
  #   # todo
  # end

  # def session_typecheck_ast(
  #       {{:., _, _args}, _meta, _},
  #       session_type,
  #       rec_var,
  #       function_st_context,
  #       _module_context
  #     ) do
  #   # Remote function call, ignore
  #   {rec_var, function_st_context, session_type}
  # end

  # # Function call
  # def session_typecheck_ast(
  #       {function_name, meta, parameters},
  #       session_type,
  #       rec_var,
  #       function_st_context,
  #       module_context
  #     )
  #     when is_list(parameters) do
  #   arity = length(parameters)

  #   %{
  #     functions: functions,
  #     function_session_type: _function_session_type,
  #     file: _file,
  #     relative_file: _relative_file,
  #     line: _line,
  #     module_name: _module_name
  #   } = module_context

  #   line =
  #     if meta[:line] do
  #       "[Line #{meta[:line]}]"
  #     else
  #       "[Line unknown]"
  #     end

  #   # Call to other function (in same module)
  #   # Check if a session type already exists for the current function call
  #   case Map.fetch(function_st_context, {function_name, arity}) do
  #     {:ok, found_session_type} ->
  #       # IO.puts(
  #       #   "#{line} From function_st_context found mapping from #{inspect({function_name, arity})} " <>
  #       #     "to session type #{ST.st_to_string(found_session_type)}."
  #       # )

  #       # IO.puts("#{line} Expanding #{ST.st_to_string(session_type)} #{inspect(rec_var)}.")

  #       unfolded_st = ST.unfold_unknown(session_type, rec_var)

  #       # IO.puts(
  #       #   "#{line} Comparing session-typed function #{inspect({function_name, arity})} with session type " <>
  #       #     "#{ST.st_to_string(found_session_type)} to the expected session type: " <>
  #       #     "#{ST.st_to_string(unfolded_st)}."
  #       # )

  #       case ST.session_subtraction(unfolded_st, found_session_type) do
  #         {:ok, remaining_session_type} ->
  #           {rec_var, function_st_context, remaining_session_type}

  #         {:error, error} ->
  #           throw(error)
  #       end

  #     :error ->
  #       # Call to un-(session)-typed function
  #       # Session type check the ast of this function

  #       # IO.puts(
  #       #   "#{line} Call to un-(session)-typed function. Comparing function " <>
  #       #     "#{inspect({function_name, arity})} with session type " <>
  #       #     "#{ST.st_to_string(session_type)}."
  #       # )

  #       case lookup_function(functions, function_name, arity) do
  #         {:ok, %ST.Function{bodies: bodies}} ->
  #           # IO.puts(
  #           #   "#{line} Comparing #{ST.st_to_string(session_type)} to " <>
  #           #     "#{inspect({function_name, arity})}"
  #           # )

  #           unfolded_session_type = ST.unfold_unknown(session_type, rec_var)

  #           # IO.puts(
  #           #   "#{line} Unfolded #{ST.st_to_string(session_type)} to " <>
  #           #     "#{ST.st_to_string(unfolded_session_type)}"
  #           # )

  #           function_st_context =
  #             Map.put(function_st_context, {function_name, arity}, unfolded_session_type)

  #           {rec_var, function_st_context, remaining_session_type} =
  #             Enum.map(bodies, fn ast ->
  #               session_typecheck_ast(
  #                 ast,
  #                 unfolded_session_type,
  #                 # rec_var set to empty
  #                 %{},
  #                 function_st_context,
  #                 module_context
  #               )
  #             end)
  #             # todo ensure all bodies reach the same results
  #             |> hd

  #           unfolded_remaining_session_type = ST.unfold_unknown(remaining_session_type, rec_var)

  #           # IO.puts(
  #           #   "Subtracting #{ST.st_to_string(unfolded_remaining_session_type)} from #{
  #           #     ST.st_to_string(unfolded_session_type)
  #           #   }"
  #           # )

  #           case ST.session_tail_subtraction(
  #                  unfolded_session_type,
  #                  unfolded_remaining_session_type
  #                ) do
  #             {:ok, fixed_session_type} ->
  #               # IO.puts(
  #               #   "#{line} session_tail_subtraction for #{function_name}/#{arity} = #{
  #               #     ST.st_to_string(fixed_session_type)
  #               #   }"
  #               # )

  #               function_st_context_updated =
  #                 Map.put(function_st_context, {function_name, arity}, fixed_session_type)

  #               {rec_var, function_st_context_updated, remaining_session_type}

  #             # {rec_var, function_st_context_updated, unfolded_remaining_session_type}

  #             {:error, error} ->
  #               throw("#{line} #{inspect(error)}")
  #           end

  #         :error ->
  #           throw(
  #             "#{line} Should not happen. Couldn't find ast for unknown (local) call " <>
  #               "to function #{inspect({function_name, arity})}"
  #           )
  #       end
  #   end
  # end

  # # end

  # def session_typecheck_ast(_, session_type, rec_var, function_st_context, _) do
  #   # IO.puts("Other input")
  #   {rec_var, function_st_context, session_type}
  # end

  defp error_message(message, meta) do
    line =
      if meta[:line] do
        "[Line #{meta[:line]}] "
      else
        ""
      end

    line <> message
  end

  # @doc false
  # # Takes case of :-> and returns the label and number of values as ':any' type.
  # # e.g. {:label, value1, value2} -> do_something()
  # # or   {:label, value1, value2} when is_number(value1) -> do_something()
  # # returns {:label, [value1, value2]}
  # def parse_options(x) do
  #   x =
  #     case x do
  #       {:when, _, data} ->
  #         # throw("Problem while typechecking: 'when' not implemented yet")
  #         hd(data)

  #       x ->
  #         x
  #     end

  #   {label, types} =
  #     case x do
  #       # Size 0, e.g. {:do_something}
  #       {:{}, _, [label]} ->
  #         {label, []}

  #       # Size 1, e.g. {:value, 545}
  #       {label, type} ->
  #         {label, [Macro.to_string(type)]}

  #       # Size > 2, e.g. {:add, 3, 5}
  #       {:{}, _, [label | types]} ->
  #         {label, Enum.map(types, fn x -> String.to_atom(Macro.to_string(x)) end)}

  #       x ->
  #         throw(
  #           "Needs to be a tuple contain at least a label. E.g. {:do_something} or {:value, 54}. " <>
  #             "Found #{inspect(x)}."
  #         )
  #     end

  #   case is_atom(label) do
  #     true ->
  #       :ok

  #     false ->
  #       throw("First item in tuple needs to be a label/atom. (#{inspect(label)})")
  #   end

  #   {label, types}
  # end

  defp lookup_function(all_functions, {name, arity}) do
    try do
      {:ok, lookup_function!(all_functions, {name, arity})}
    catch
      {:error, x} -> {:error, x}
    end
  end

  defp lookup_function!(all_functions, {name, arity}) do
    if all_functions[{name, arity}] do
      all_functions[{name, arity}]
    else
      # Function does not exist in current module
      throw({:error, "Function #{name}/#{arity} was not found in the current module."})
    end
  end

  # recompile && ElixirSessions.SessionTypechecking.run
  # def run() do
  #   # fun = :ping

  #   # body =
  #   #   quote do
  #   #     pid =
  #   #       receive do
  #   #         {:address, pid} ->
  #   #           pid
  #   #       end

  #   #     send(pid, {:a111})

  #   #     ping()

  #   #     # receive do
  #   #     #   {:option1} ->
  #   #     #     a = 1
  #   #     #     send(pid, {:A, a})
  #   #     #     send(pid, {:B, a + 1})

  #   #     #   {:option2} ->
  #   #     #     _b = 2
  #   #     #     send(pid, {:X})

  #   #     #   {:option3, value} ->
  #   #     #     b = 3
  #   #     #     send(pid, {:Y, b})
  #   #     #     case value do
  #   #     #       true -> send(pid, {:hello})
  #   #     #       false -> send(pid, {:hello2})
  #   #     #       _ -> send(pid, {:not_hello, 3})
  #   #     #     end
  #   #     # end
  #   #   end

  #   # st = "rec X.(?address(any).!a111().X)"
  #   # &{?option1().!A(any).!B(any),
  #   #   ?option2().!X(),
  #   #   ?option3(any).!Y(any).
  #   #         +{!hello(),
  #   #           !hello2(),
  #   #           !not_hello(any)
  #   #         }
  #   #   }"

  #   # session_type = ST.string_to_st(st)

  #   # session_typecheck(fun, 0, body, session_type)

  #   :ok
  # end
end
