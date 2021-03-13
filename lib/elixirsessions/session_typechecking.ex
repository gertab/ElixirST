defmodule ElixirSessions.SessionTypechecking do
  require ST

  @moduledoc """
  Given a session type and Elixir code, the Elixir code is typechecked against the session type.
  """
  @typedoc false
  @type ast :: ST.ast()
  @typedoc false
  @type session_type :: ST.session_type()
  @typep module_context :: ST.Module.t()
  @typep function_context :: ST.Function.t()
  @type st_module :: ST.Module.t()

  # Session type checking a whole module, which may include multiple functions with multiple session type definitions
  @spec session_typecheck_module(st_module) :: any
  def session_typecheck_module(%ST.Module{} = module_context) do
    %ST.Module{
      functions: functions,
      function_mapped_st: function_mapped_st,
      session_types: session_types,
      file: _file,
      relative_file: _relative_file,
      line: _line,
      module_name: _module_name
    } = module_context

    IO.puts("Starting session type checking #{inspect(function_mapped_st)}")

    function_mapped_st
    # |> Enum.to_list()
    # |> hd()
    # |> (fn x -> [x] end).()
    # Session type check all (matched) functions
    |> Enum.each(fn
      {{name, arity}, name_arity_st} ->
        ast = Map.fetch!(functions, {name, arity})
        expected_session_type = Map.fetch!(session_types, name_arity_st)
        session_typecheck_by_function(ast, expected_session_type, {name, arity}, module_context)
        :ok
    end)
  end

  @spec session_typecheck_by_function(
          ast(),
          session_type(),
          {atom(), integer()},
          module_context()
        ) ::
          :ok
  def session_typecheck_by_function(ast, expected_session_type, {name, arity}, module_context) do
    IO.inspect(ast)
    # IO.inspect(expected_session_type)
    # IO.inspect(module_context)

    IO.puts(
      "Session type checking #{inspect(name)}/#{arity}: #{ST.st_to_string(expected_session_type)}"
    )

    function_context = %ST.Function{
      name: name,
      arity: arity
    }

    {_, remaining_session_type} =
      session_typecheck_ast(ast, expected_session_type, function_context, module_context)

    case remaining_session_type do
      %ST.Terminate{} ->
        IO.puts("Session type checking was successful.")
        :ok

      # todo what if call_recursive
      _ ->
        throw("Remaining session type: #{ST.st_to_string(remaining_session_type)}")
    end
  end

  @doc """
  Given a function (and its body), it is compared to a session type. `fun` is
  the function name and `body` is the function body as AST.
  """
  # todo remove
  @spec session_typecheck(atom(), arity(), ast(), session_type()) :: :ok
  def session_typecheck(fun, arity, body, session_type) do
    IO.puts("Session typechecking of &#{to_string(fun)}/#{arity}")

    function_context = %ST.Function{
      name: fun,
      arity: arity
    }

    IO.puts("Session typechecking: #{ST.st_to_string(session_type)}")

    {_, remaining_session_type} =
      session_typecheck_ast(body, session_type, function_context, %ST.Module{})

    case remaining_session_type do
      %ST.Terminate{} ->
        IO.puts("Session type checking was successful.")
        :ok

      # todo what if call_recursive
      _ ->
        throw("Remaining session type: #{ST.st_to_string(remaining_session_type)}")
    end

    # case contains_recursion?(inferred_session_type) do
    #   true -> [{:recurse, :X, inferred_session_type}]
    #   false -> inferred_session_type
    # end
  end

  @doc """
  Traverses the given Elixir `ast` and session-typechecks it with respect to the `session_type`.
  """
  @spec session_typecheck_ast(ast(), session_type(), function_context(), module_context()) ::
          {boolean(), session_type()}
  def session_typecheck_ast(body, session_type, function_context, module_context)

  def session_typecheck_ast(body, %ST.Recurse{} = recurse, function_context, module_context) do
    %ST.Recurse{label: _label, body: session_type_body} = recurse

    # todo fix
    # module_context =
    #   if Map.has_key?(module_context, label) do
    #     # confirm that body is the same
    #     module_context
    #   else
    #     Map.put(module_context, label, session_type_body)
    #   end

    session_typecheck_ast(body, session_type_body, function_context, module_context)
  end

  # todo
  # def session_typecheck_ast(body, %ST.Call_Recurse{label: label}, _function_context, module_context) do
  #   {found_label, _, _parameters} = body
  #   # _arity = length(parameters)
  #   # todo what about __module__.label
  #   if Map.has_key?(module_context, found_label) do
  #     {false, %ST.Terminate{}}
  #   else
  #     throw("Expected recursion on #{label}")
  #   end
  #   # session_typecheck_ast(body, call_recurse, function_context, module_context)
  # end

  # literals
  def session_typecheck_ast(x, session_type, _function_context, _module_context)
      when is_atom(x) or is_number(x) or is_binary(x) do
    # IO.puts("\literal: ")
    {false, session_type}
  end

  def session_typecheck_ast({a, b}, session_type, function_context, module_context) do
    # IO.puts("\nTuple: ")

    {_, remaining_session_type} =
      session_typecheck_ast(a, session_type, function_context, module_context)

    session_typecheck_ast(b, remaining_session_type, function_context, module_context)
  end

  def session_typecheck_ast([head | tail], session_type, function_context, module_context) do
    # IO.puts("\nlist:")

    # Split the session type in two.
    # First, perform session type checking for the first operation (head).
    # Then, do the remaining session type checking for the remaining statements (tail).
    {_, remaining_session_type} =
      session_typecheck_ast(head, session_type, function_context, module_context)

    session_typecheck_ast(tail, remaining_session_type, function_context, module_context)
  end

  # Non literals
  def session_typecheck_ast(
        {:__block__, _meta, args},
        session_type,
        function_context,
        module_context
      ) do
    session_typecheck_ast(args, session_type, function_context, module_context)
  end

  def session_typecheck_ast(
        {:=, _meta, [_left, right]},
        session_type,
        function_context,
        module_context
      ) do
    # Session type check the right part of the pattern matching operator (i.e. =)
    session_typecheck_ast(right, session_type, function_context, module_context)
  end

  def session_typecheck_ast(
        {:send, meta, [a, send_body | _]},
        session_type,
        function_context,
        module_context
      ) do
    # todo make ast expand -> then remove this shit
    session_typecheck_ast(
      {{:., [], [:erlang, :send]}, meta, [a, send_body]},
      session_type,
      function_context,
      module_context
    )
  end

  def session_typecheck_ast(
        {{:., _, [:erlang, :send]}, meta, [_, send_body | _]} = ast,
        # {:send, meta, [_, send_body | _]} = ast,
        session_type,
        function_context,
        module_context
      ) do
    # IO.puts("[in send] #{inspect(session_type)}")

    line =
      if meta[:line] do
        "[Line #{meta[:line]}]"
      else
        "[Line unknown]"
      end

    {actual_label, actual_parameters} = parse_options(send_body)

    case session_type do
      %ST.Send{label: expected_label, types: expected_types, next: next} ->
        # todo ensure types correctness for parameters

        if expected_label != actual_label do
          throw("#{line} Expected send with label :#{expected_label} but found :#{actual_label}.")
        end

        if length(expected_types) != length(actual_parameters) do
          throw(
            "#{line} Session type parameter length mismatch. Expected " <>
              "#{ST.st_to_string_current(session_type)} (length = " <>
              "#{length(expected_types)}), but found #{Macro.to_string(send_body)} " <>
              "(length = #{List.to_string(actual_parameters)})."
          )
        end

        {false, next}

      %ST.Choice{choices: choices} ->
        case Map.fetch(choices, actual_label) do
          {:ok, expected_send_sessiontype} ->
            # Recurse with the '!' session type inside the '+'
            session_typecheck_ast(
              ast,
              expected_send_sessiontype,
              function_context,
              module_context
            )

          :error ->
            throw(
              "#{line} Cannot match send statment `#{Macro.to_string(ast)}` " <>
                "with #{ST.st_to_string_current(session_type)}."
            )
        end

      _ ->
        throw(
          "#{line} Cannot match send statment `#{Macro.to_string(ast)}` " <>
            "with #{ST.st_to_string_current(session_type)}."
        )
    end
  end

  def session_typecheck_ast(
        {:receive, meta, [body | _]},
        session_type,
        function_context,
        module_context
      ) do
    # body contains [do: [ {:->, _, [ [ when/condition ], work ]}, other_cases... ] ]
    # IO.puts("[in recv] #{inspect(session_type)}")

    line =
      if meta[:line] do
        "[Line #{meta[:line]}]"
      else
        "[Line unknown]"
      end

    cases = body[:do]

    if length(cases) == 0 do
      throw("Should not happen [receive statements need to have 1 or more cases]")
    end

    # 1 or more receive branches
    # In case of one receive branch, it should match with a %ST.Recv{}
    # In case of more than one receive branch, it should match with a %ST.Branch{}
    branches_session_types =
      case session_type do
        %ST.Branch{branches: branches} ->
          branches

        %ST.Recv{label: label, types: types, next: next} ->
          %{label => %ST.Recv{label: label, types: types, next: next}}

        x ->
          throw("#{line} Found a receive/branch, but expected #{ST.st_to_string(x)}.")
      end

    # Each branch from the session type should have an equivalent branch in the receive cases
    if map_size(branches_session_types) != length(cases) do
      throw(
        "#{line} [in branch/receive] Mismatch in number of receive and & branches. " <>
          "Expected session type #{ST.st_to_string_current(session_type)}"
      )
    end

    # Get label, parameters and remaining ast from the source ast
    # label_types_ast = %{{label1 => {parameters1, remaining_ast1}}, ...}
    label_parameters_ast =
      Enum.map(cases, fn
        {:->, _, [[lhs] | rhs]} ->
          # Given: {:a, b} when is_atom(b) -> do_something()
          # lhs contains data related to '{:a, b} when is_atom(b)'
          # rhs contains the body, e.g. 'do_something()'
          {label, parameters} = parse_options(lhs)
          {label, {parameters, rhs}}
      end)
      |> Enum.into(%{})

    # Compare the actual branches (from label_parameters_ast)
    # with the branch session type (in branches_session_types)
    Enum.map(
      branches_session_types,
      fn {st_label, branch_session_type} ->
        # Match the label with the correct branch
        case Map.fetch(label_parameters_ast, st_label) do
          {:ok, {actual_parameters, inside_ast}} ->
            # Match the number of parameters found (in ast) and expected (in st)
            %ST.Recv{types: expected_types, next: inside_branch_session_type} =
              branch_session_type

            if length(expected_types) != length(actual_parameters) do
              throw(
                "#{line} Session type parameter length mismatch. Expected " <>
                  "#{ST.st_to_string_current(session_type)} (length = #{length(expected_types)}), " <>
                  "but found #{inspect(actual_parameters)} (length = #{length(actual_parameters)})."
              )
            end

            # Recursively session typecheck the inside of the branch
            session_typecheck_ast(
              inside_ast,
              inside_branch_session_type,
              function_context,
              module_context
            )

          :error ->
            throw(
              "Receive branch with label :#{st_label} expected but not found. Session type " <>
                "#{ST.st_to_string_current(%ST.Branch{branches: branches_session_types})}."
            )
        end
      end
    )
    # Ensure that all element in remaining_branches_session_types are the same, and return the last one
    |> Enum.reduce(fn full_st, full_acc ->
      {x, st} = full_st
      {_, acc} = full_acc

      if st == acc do
        {x, st}
      else
        throw(
          "#{line} Mismatch in session type following the branch: " <>
            "#{ST.st_to_string(st)} and #{ST.st_to_string(acc)}"
        )
      end
    end)
  end

  def session_typecheck_ast(
        {:case, meta, [_what_you_are_checking, body | _]},
        session_type,
        function_context,
        module_context
      ) do
    # body contains [do: [ {:->, _, [ [ when/condition ], work ]}, other_cases... ] ]
    # IO.puts("[in case/choice] #{inspect(session_type)}")

    line =
      if meta[:line] do
        "[Line #{meta[:line]}]"
      else
        "[Line unknown]"
      end

    cases = body[:do]

    if length(cases) == 0 do
      throw("Should not happen [case statements need to have 1 or more cases]")
    end

    # 1 or more case option (assume that it is a choice)
    # choices_session_types is of type %{label() => session_type()}
    choices_session_types =
      case session_type do
        %ST.Choice{choices: choices} ->
          choices

        x ->
          throw("Found a choice, but expected #{ST.st_to_string(x)}")
      end

    # Each branch from the session type could have (up to) one equivalent choice in
    # the case statements
    if map_size(choices_session_types) < length(cases) do
      throw(
        "#{line} [in case/choice] More cases found (#{length(cases)}) than expected " <>
          "(#{map_size(choices_session_types)}). Expected session type " <>
          "#{ST.st_to_string_current(%ST.Choice{choices: choices_session_types})}"
      )
    end

    inner_ast =
      Enum.map(cases, fn
        {:->, _, [[_lhs] | rhs]} ->
          # Given: {:a, b} when is_atom(b) -> do_something()
          # lhs contains data related to '{:a, b} when is_atom(b)'
          # rhs contains the body, e.g. 'do_something()'
          # {label, parameters} = parse_options(lhs)
          rhs
      end)

    # Compare the actual choices (from label_parameters_ast)
    # with the choice session type (in choices_session_types)

    Enum.map(
      inner_ast,
      fn ast ->
        # Compare the current branch to all possible session types (in the choice map)
        tentative_remaining_session_types =
          Enum.map(
            choices_session_types,
            fn
              {_l, potential_session_type} ->
                try do
                  session_typecheck_ast(
                    ast,
                    potential_session_type,
                    function_context,
                    module_context
                  )
                catch
                  error -> {:error, error}
                end
            end
          )

        # remaining_session_type_list may contain either [] or
        # a list with one element containing the matching session type
        remaining_session_type_list =
          Enum.filter(tentative_remaining_session_types, fn
            {:error, _} -> false
            _ -> true
          end)

        # errors_session_type_list contains a list of all erros caught
        errors_session_type_list =
          Enum.filter(tentative_remaining_session_types, fn
            {:error, _} -> true
            _ -> false
          end)
          |> Enum.map(fn {:error, x} -> x end)

        # If all return nils (meaning that all choice threw an error), then this case fails
        remaining_session_type =
          case remaining_session_type_list do
            [] ->
              throw(
                "Couldn't match case with session type: " <>
                  "#{ST.st_to_string_current(%ST.Choice{choices: choices_session_types})}. The following " <>
                  "errors were found: #{inspect(Enum.join(errors_session_type_list, ", or "))}."
              )

            x ->
              hd(x)
          end

        remaining_session_type
      end
    )
    # Ensure that all element in remaining_branches_session_types are the same, and return the last one
    |> Enum.reduce(fn full_st, full_acc ->
      {x, st} = full_st
      {_, acc} = full_acc

      if st == acc do
        {x, st}
      else
        throw(
          "#{line} Mismatch in session type following the choice: #{ST.st_to_string(st)} " <>
            "and #{ST.st_to_string(acc)}"
        )
      end
    end)
  end

  def session_typecheck_ast({:|>, _meta, _args}, session_type, _function_context, _module_context) do
    {false, session_type}
    # todo
  end

  def session_typecheck_ast(
        {{:., _, _args}, _meta, _},
        session_type,
        _function_context,
        _module_context
      ) do
    # Remote function call, ignore
    {false, session_type}
  end

  # Function call
  def session_typecheck_ast(
        {function_name, meta, parameters},
        session_type,
        function_context,
        module_context
      )
      when is_list(parameters) do
    arity = length(parameters)

    %ST.Function{
      name: function_cxt_name,
      arity: function_cxt_arity
    } = function_context

    %ST.Module{
      functions: functions,
      function_mapped_st: function_mapped_st,
      session_types: session_types,
      module_name: _module_name
    } = module_context

    line =
      if meta[:line] do
        "[Line #{meta[:line]}]"
      else
        "[Line unknown]"
      end

    if function_cxt_name == function_name and function_cxt_arity == arity do
      throw("#{line} Doing recursion")
    else
      # Call to other function (in same module)
      # Check if a session type already exists for the current function call
      case Map.fetch(function_mapped_st, {function_name, arity}) do
        {:ok, session_type_name} ->
          IO.puts(
            "#{line} From function_mapped_st found mapping from #{inspect({function_name, arity})} " <>
              "to session type with label #{inspect(session_type_name)}."
          )

          case session_type do
            %ST.Call_Session_Type{label: label} ->
              if label == session_type_name do
                # session type matches expected label

                IO.puts("#{line} Matched call to st: #{ST.st_to_string(session_type)}.")
                {false, %ST.Terminate{}}
              else
                throw(
                  "#{line} Expected call to function with session type labelled #{inspect(label)}. " <>
                    "Instead found a call to function #{inspect({function_name, arity})} with session type " <>
                    "labelled #{session_type_name}."
                )
              end

            _ ->
              case Map.fetch(session_types, session_type_name) do
                {:ok, session_type_internal_function} ->
                  IO.puts(
                    "#{line} Comparing session-typed function #{inspect({function_name, arity})} with session type " <>
                      "#{ST.st_to_string(session_type_internal_function)} to the expected session type: " <>
                      "#{ST.st_to_string(session_type)}."
                  )

                  case ST.compare_session_types(session_type, session_type_internal_function) do
                    {:ok, remaining_session_type} ->
                      {false, remaining_session_type}

                    {:error, error} ->
                      throw(error)
                  end

                :error ->
                  throw(
                    "#{line} Should not happen. Couldn't find ast for unknown (local) call " <>
                      "to function #{inspect({function_name, arity})}"
                  )
              end
          end

        :error ->
          # Call to un-(session)-typed function
          # Session type check the ast of this function

          IO.puts(
            "#{line} Call to un-(session)-typed function. Comparing function " <>
              "#{inspect({function_name, arity})} with session type " <>
              "#{ST.st_to_string(session_type)}."
          )

          case Map.fetch(functions, {function_name, arity}) do
            {:ok, ast} ->
              IO.puts(
                "#{line} Comparing #{ST.st_to_string(session_type)} to " <>
                  "#{inspect({function_name, arity})}"
              )

              session_typecheck_ast(ast, session_type, function_context, module_context)

            :error ->
              throw(
                "#{line} Should not happen. Couldn't find ast for unknown (local) call " <>
                  "to function #{inspect({function_name, arity})}"
              )
          end
      end
    end

    # {false, session_type}
    # todo
  end

  # def session_typecheck_ast(
  #       {fun, _meta, [_function_name, _body]},
  #       session_type,
  #       _function_context,
  #       _module_context
  #     )
  #     when fun in [:def, :defp] do
  #   {false, session_type}
  # end

  def session_typecheck_ast(_, session_type, _function_context, _module_context) do
    # IO.puts("Other input")
    {false, session_type}
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

  # recompile && ElixirSessions.SessionTypechecking.run
  def run() do
    fun = :ping

    body =
      quote do
        pid =
          receive do
            {:address, pid} ->
              pid
          end

        send(pid, {:O111})

        ping()

        # receive do
        #   {:option1} ->
        #     a = 1
        #     send(pid, {:A, a})
        #     send(pid, {:B, a + 1})

        #   {:option2} ->
        #     _b = 2
        #     send(pid, {:X})

        #   {:option3, value} ->
        #     b = 3
        #     send(pid, {:Y, b})
        #     case value do
        #       true -> send(pid, {:hello})
        #       false -> send(pid, {:hello2})
        #       _ -> send(pid, {:not_hello, 3})
        #     end
        # end
      end

    st = "rec X.(?address(any).
                    +{!O111(), !O222(), !O333().X})"
    # &{?option1().!A(any).!B(any),
    #   ?option2().!X(),
    #   ?option3(any).!Y(any).
    #         +{!hello(),
    #           !hello2(),
    #           !not_hello(any)
    #         }
    #   }"

    session_type = ST.string_to_st(st)

    session_typecheck(fun, 0, body, session_type)

    :ok
  end
end
