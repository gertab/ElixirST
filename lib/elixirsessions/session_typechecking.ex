defmodule ElixirSessions.SessionTypechecking do
  require ST

  @moduledoc """
  Given a session type and Elixir code, the Elixir code is typechecked against the session type.
  """

  @typedoc false
  @type ast :: ST.ast()
  @typedoc false
  @type session_type :: ST.session_type()
  @typedoc false
  @type accepted_types :: any()

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
          functions: functions,
          function_session_type: function_session_type,
          module_name: _module_name
        } = module_context,
        _options \\ []
      ) do
    # IO.puts("Starting session type checking #{inspect(function_session_type)}")

    for {{name, arity}, expected_session_type} <- function_session_type do
      function = lookup_function!(functions, name, arity)

      session_typecheck_by_function(
        function,
        expected_session_type,
        module_context
      )
    end
  end

  @spec session_typecheck_by_function(ST.Function.t(), session_type(), %{
          functions: [ST.Function.t()],
          function_session_type: %{{ST.label(), non_neg_integer()} => session_type()},
          module_name: atom()
        }) :: :ok
  def session_typecheck_by_function(
        %ST.Function{
          bodies: bodies,
          return_type: return_type,
          parameters: parameters,
          param_types: param_types
        },
        expected_session_type,
        module_context
      ) do
    for {ast, parameters} <- List.zip([bodies, parameters]) do
      # Initialize the variable context with the parameters and their types
      variable_ctx =
        Enum.zip(parameters, param_types)
        # Remove any nils
        |> Enum.filter(fn
          {nil, _} -> false
          _ -> true
        end)
        |> Enum.into(%{})

      # IO.warn(inspect(variable_ctx))

      env = %{
        # :ok or :error or :warning
        :state => :ok,
        # error message
        :error_data => nil,
        # :x => :atom
        :variable_ctx => variable_ctx,
        # Expected session type
        # rec X.(!A().X)
        :session_type => expected_session_type,
        # Expected type
        :type => return_type,
        # {name, arity} => %ST.Function
        :functions => module_context[:functions],
        # {name, arity} => rec X.(!A().X)
        :function_session_type__ctx => module_context[:function_session_type]
      }

      Macro.prewalk(ast, env, &typecheck/2)
      |> IO.inspect()
    end

    :ok
  end

  # def typecheck(
  #       node,
  #       %{
  #         state: :error,
  #         error_data: _,
  #         error: _,
  #         variable_ctx: _,
  #         session_type: _,
  #         type: _,
  #         functions: _,
  #         function_session_type__ctx: _
  #       } = env
  #     ) do
  #   IO.warn("Error!")
  #   throw("ERROR")
  #   {node, env}
  # end

  # Block
  def typecheck({:__block__, meta, args}, env) do
    IO.puts("# Block #{inspect(args)}")
    node = {:__block__, [checked: :block, type: env[:type]] ++ meta, args}
    {node, env}
  end

  # Literals
  def typecheck(node, env)
      when is_atom(node) or is_number(node) or is_binary(node) or is_boolean(node) or
             is_float(node) or is_integer(node) or is_nil(node) or is_pid(node) do
    IO.puts("# Literal: #{inspect(node)} #{ElixirSessions.TypeOperations.typeof(node)}")

    {{:literal, [checked: :literal, type: ElixirSessions.TypeOperations.typeof(node)], nil},
     %{env | type: ElixirSessions.TypeOperations.typeof(node)}}

    # {node, %{env | type: ElixirSessions.TypeOperations.typeof(node)}}
  end

  def typecheck(node, env) when is_list(node) do
    IO.puts("# List}")

    {node, env}
  end

  # Operations
  def typecheck({{:., meta1, [:erlang, operator]}, meta2, [arg1, arg2]}, env)
      when operator in [:+, :-, :*] do
    IO.puts("# erlang #{operator}")
    node = {{:., meta1, []}, meta2, []}

    process_binary_operations(node, meta2, operator, arg1, arg2, :number, false, env)
  end

  def typecheck({{:., meta1, [:erlang, :/]}, meta2, [arg1, arg2]}, env) do
    IO.puts("# erlang /")
    node = {{:., meta1, []}, meta2, []}

    process_binary_operations(node, meta2, :/, arg1, arg2, :number, false, env)
  end

  # too complex in extended elixir
  # [:and, :or]

  # Elixir format:          [:==, :!=,   :===,   :!== ,  :>, :<, :<=,   :>=  ]
  # Extended Elixir format: [:==, :"/=", :"=:=", :"=/=", :>, :<, :"=<", :">="]
  def typecheck({{:., meta1, [:erlang, operator]}, meta2, [arg1, arg2]}, env)
      when operator in [:==, :"/=", :"=:=", :"=/=", :>, :<, :"=<", :">="] do
    node = {{:., meta1, []}, meta2, []}
    # todo convert operator from extened elixir to elixir
    process_binary_operations(node, meta2, operator, arg1, arg2, :any, true, env)
  end

  # not
  def typecheck({{:., _meta1, [:erlang, :not]}, meta2, [arg]} = node, env) do
    process_unary_operations(node, meta2, arg, :boolean, env)
  end

  def typecheck({{:., _meta1, [:erlang, :-]}, meta2, [arg]}, env) do
    IO.puts("# erlang negation")

    node = {nil, meta2, []}
    process_unary_operations(node, meta2, arg, :number, env)
  end

  def typecheck({{:., _meta1, [:erlang, erlang_function]}, meta2, _arg}, env) do
    IO.puts("# erlang others #{erlang_function} (not supported)")
    node = {nil, meta2, []}
    # {{{:., [], [:erlang, erlang_function]}, [], arg}, %{env | type: :any}}
    # {node, %{env | type: :any}}
    {node, %{env | state: :error, error_data: error_message("Unknown erlang function #{inspect erlang_function}", meta2)}}
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
          {:error, msg} ->
            {node, %{expr_env | state: :error, error_data: error_message(msg, meta)}}

          _ ->
            {node, %{expr_env | variable_ctx: Map.merge(expr_env[:variable_ctx], pattern_vars)}}
        end
    end
  end

  # Variables
  def typecheck({x, meta, arg}, env) when is_atom(arg) do
    IO.puts("# Variable #{inspect(x)}: #{inspect(env[:variable_ctx][x])}")
    node = {x, meta, arg}

    case env[:variable_ctx][x] do
      nil ->
        {node,
         %{env | state: :error, error_data: error_message("Variable #{x} was not found", meta)}}

      type ->
        {node, %{env | type: type}}
    end
  end

  # Functions
  def typecheck({x, meta, args}, env) when is_list(args) do
    IO.puts("# Function #{inspect(x)}")
    node = {x, meta, []}
    {node, env}
  end

  def typecheck(other, env) do
    IO.puts("# other #{inspect(other)}")

    {other, env}
  end

  # recompile && ElixirSessions.SessionTypechecking.run
  def run() do
    ast =
      quote do
        a = 7
        b = a + 99 + 9.9
        c = a
        a + b        # # xxx = 76
        # # _ = xxx and false
        # # @session "!A().rec X.(!A().X)"
        # send(pid, {:A})
        # # @session "rec X.(!A().X)"
        # # @session "!A().rec X.(!A().X)"
        # aaa = 11111 + 2222 * 33333 + 44444 + 55555
        # _ = aaa * 7
        # example(pid)
      end

    env = %{
      :state => :ok,
      :error_data => nil,
      :variable_ctx => %{},
      :session_type => %ST.Terminate{},
      :type => :any,
      :functions => %{},
      :function_session_type__ctx => %{}
    }

    ElixirSessions.Helper.expanded_quoted(ast)
    |> IO.inspect()
    |> Macro.prewalk(env, &typecheck/2)

    # |> elem(0)
  end

  defp process_binary_operations(node, meta, operator, arg1, arg2, max_type, is_comparison, env) do
    {_op1_ast, op1_env} = Macro.prewalk(arg1, env, &typecheck/2)
    {_op2_ast, op2_env} = Macro.prewalk(arg2, env, &typecheck/2)

    case op1_env[:state] do
      :error ->
        {node, op1_env}

      _ ->
        case op2_env[:state] do
          :error ->
            {node, op2_env}

          _ ->
            if is_comparison do
              # todo merge var from op1 to op2
              {node, %{op1_env | type: :boolean}}
            else
              common_type =
                ElixirSessions.TypeOperations.greatest_lower_bound(op1_env[:type], op2_env[:type])

              case common_type do
                :error ->
                  {node,
                   %{
                     op1_env
                     | state: :error,
                       error_data:
                         error_message(
                           "Operator type problem in #{inspect(operator)}: #{
                             inspect(op1_env[:type])
                           }, #{inspect(op2_env[:type])} are not of the same type",
                           meta
                         )
                   }}

                _ ->
                  if ElixirSessions.TypeOperations.subtype?(common_type, max_type) do
                    # todo merge var from op1 to op2
                    {node, %{op1_env | type: common_type}}
                  else
                    {node,
                     %{
                       op1_env
                       | state: :error,
                         error_data:
                           error_message(
                             "Operator type problem in #{inspect(operator)}: #{
                               inspect(op1_env[:type])
                             }, #{inspect(op2_env[:type])} is not of type #{inspect(max_type)}",
                             meta
                           )
                     }}
                  end
              end
            end
        end
    end
  end

  defp process_unary_operations(node, meta, arg1, max_type, env) do
    {_op1_ast, op1_env} = Macro.prewalk(arg1, env, &typecheck/2)

    case op1_env[:state] do
      :error ->
        {node, op1_env}

      _ ->
        expected_type =
          ElixirSessions.TypeOperations.greatest_lower_bound(op1_env[:type], max_type)

        case expected_type do
          :error ->
            {node,
             %{
               op1_env
               | state: :error,
                 error_data:
                   error_message(
                     "Unary type problem: #{inspect(op1_env[:type])} is not a #{inspect(max_type)}",
                     meta
                   )
             }}

          _ ->
            {node, op1_env}
        end
    end
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
  #             "#{line} Cannot match send statment `#{Macro.to_string(ast)}` " <>
  #               "with #{ST.st_to_string_current(session_type)}."
  #           )
  #       end

  #     _ ->
  #       throw(
  #         "#{line} Cannot match send statment `#{Macro.to_string(ast)}` " <>
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
        "[Line #{meta[:line]}]"
      else
        ""
      end

    message <> line
  end

  @doc false
  # Takes case of :-> and returns the label and number of values as ':any' type.
  # e.g. {:label, value1, value2} -> do_something()
  # or   {:label, value1, value2} when is_number(value1) -> do_something()
  # returns {:label, [value1, value2]}
  def parse_options(x) do
    x =
      case x do
        {:when, _, data} ->
          # throw("Problem while typechecking: 'when' not implemented yet")
          hd(data)

        x ->
          x
      end

    {label, types} =
      case x do
        # Size 0, e.g. {:do_something}
        {:{}, _, [label]} ->
          {label, []}

        # Size 1, e.g. {:value, 545}
        {label, type} ->
          {label, [Macro.to_string(type)]}

        # Size > 2, e.g. {:add, 3, 5}
        {:{}, _, [label | types]} ->
          {label, Enum.map(types, fn x -> String.to_atom(Macro.to_string(x)) end)}

        x ->
          throw(
            "Needs to be a tuple contain at least a label. E.g. {:do_something} or {:value, 54}. " <>
              "Found #{inspect(x)}."
          )
      end

    case is_atom(label) do
      true ->
        :ok

      false ->
        throw("First item in tuple needs to be a label/atom. (#{inspect(label)})")
    end

    {label, types}
  end

  # defp lookup_function(all_functions, name, arity) do
  #   try do
  #     {:ok, lookup_function!(all_functions, name, arity)}
  #   catch
  #     _ -> :error
  #   end
  # end

  defp lookup_function!(all_functions, name, arity) do
    res = Map.get(all_functions, {name, arity}, nil)

    if is_nil(res) do
      throw("Function #{name}/#{arity} was not found.")
    end

    res

    # matches =
    #   Enum.map(
    #     all_functions,
    #     fn
    #       %ST.Function{name: ^name, arity: ^arity} = function -> function
    #       _ -> nil
    #     end
    #   )
    #   |> Enum.filter(fn elem -> !is_nil(elem) end)

    # case length(matches) do
    #   0 -> throw("Function #{name}/#{arity} was not found.")
    #   1 -> hd(matches)
    #   _ -> throw("Multiple function with the name #{name}/#{arity}.")
    # end
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
