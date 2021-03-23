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

    # IO.inspect(function_mapped_st)
    # IO.inspect(functions)
    # IO.inspect(session_types)

    function_mapped_st
    # |> Enum.to_list()
    # |> hd()
    # |> (fn x -> [x] end).()
    # Session type check all (matched) functions
    |> Enum.each(fn
      {{name, arity}, name_arity_st} ->
        ast = Map.fetch!(functions, {name, arity})
        expected_session_type = Map.fetch!(session_types, name_arity_st)

        modified_module_context = %ST.Module{
          module_context
          | cur_function: %ST.Function{name: name, arity: arity}
        }

        session_typecheck_by_function(ast, expected_session_type, %{}, modified_module_context)
        :ok
    end)
  end

  @spec session_typecheck_by_function(
          ast(),
          session_type(),
          %{},
          module_context()
        ) ::
          :ok
  def session_typecheck_by_function(ast, expected_session_type, rec_var, module_context) do
    # IO.inspect(ast)
    # IO.inspect(expected_session_type)
    # IO.inspect(module_context)

    %ST.Module{cur_function: %ST.Function{name: name, arity: arity}} = module_context

    IO.puts(
      "Session type checking #{inspect(name)}/#{arity}: #{ST.st_to_string(expected_session_type)}"
    )

    cur_function = %ST.Function{
      name: name,
      arity: arity
    }

    {_, remaining_session_type} =
      session_typecheck_ast(ast, expected_session_type, rec_var, %ST.Module{
        module_context
        | cur_function: cur_function
      })

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
      session_typecheck_ast(body, session_type, %{}, %ST.Module{cur_function: function_context})

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
  @spec session_typecheck_ast(ast(), session_type(), %{}, module_context()) ::
          {boolean(), session_type()}
  def session_typecheck_ast(body, session_type, rec_var, module_context)

  def session_typecheck_ast(body, %ST.Recurse{} = recurse, rec_var, module_context) do
    %ST.Recurse{label: label, body: session_type_body} = recurse

    # todo fix
    rec_var =
      if Map.has_key?(rec_var, label) do
        # confirm that body is the same
        rec_var
      else
        Map.put(rec_var, label, session_type_body)
        # Map.put(rec_var, label, recurse)
      end

    session_typecheck_ast(body, session_type_body, rec_var, module_context)
  end

  def session_typecheck_ast(body, %ST.Call_Session_Type{} = call, rec_var, module_context) do
    %ST.Call_Session_Type{label: label} = call

    %ST.Module{
      session_types: session_types
    } = module_context

    case Map.fetch(session_types, label) do
      {:ok, session_type_call} ->
        session_typecheck_ast(body, session_type_call, rec_var, module_context)

      :error ->
        throw("Session type '#{label}' not found.")
    end
  end

  # literals
  def session_typecheck_ast(x, session_type, _rec_var, _module_context)
      when is_atom(x) or is_number(x) or is_binary(x) do
    # IO.puts("\literal: ")
    {false, session_type}
  end

  def session_typecheck_ast({a, b}, session_type, rec_var, module_context) do
    # IO.puts("\nTuple: ")

    {_, remaining_session_type} = session_typecheck_ast(a, session_type, rec_var, module_context)

    session_typecheck_ast(b, remaining_session_type, rec_var, module_context)
  end

  def session_typecheck_ast([head | tail], session_type, rec_var, module_context) do
    # IO.puts("\nlist:")

    # Split the session type in two.
    # First, perform session type checking for the first operation (head).
    # Then, do the remaining session type checking for the remaining statements (tail).
    {_, remaining_session_type} =
      session_typecheck_ast(head, session_type, rec_var, module_context)

    session_typecheck_ast(tail, remaining_session_type, rec_var, module_context)
  end

  # Non literals
  def session_typecheck_ast(
        {:__block__, _meta, args},
        session_type,
        rec_var,
        module_context
      ) do
    session_typecheck_ast(args, session_type, rec_var, module_context)
  end

  def session_typecheck_ast(
        {:=, _meta, [_left, right]},
        session_type,
        rec_var,
        module_context
      ) do
    # Session type check the right part of the pattern matching operator (i.e. =)
    session_typecheck_ast(right, session_type, rec_var, module_context)
  end

  def session_typecheck_ast(
        {:send, meta, [a, send_body | _]},
        session_type,
        rec_var,
        module_context
      ) do
    # todo make ast expand -> then remove this shit
    session_typecheck_ast(
      {{:., [], [:erlang, :send]}, meta, [a, send_body]},
      session_type,
      rec_var,
      module_context
    )
  end

  def session_typecheck_ast(
        {{:., _, [:erlang, :send]}, meta, [_, send_body | _]} = ast,
        session_type,
        rec_var,
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
              rec_var,
              module_context
            )

          :error ->
            throw(
              "#{line} Cannot match send statment `#{Macro.to_string(ast)}` " <>
                "with #{ST.st_to_string_current(session_type)}."
            )
        end

      %ST.Call_Recurse{label: label} ->
        case Map.fetch(rec_var, label) do
          {:ok, recurse_type} ->
            session_typecheck_ast(
              ast,
              recurse_type,
              rec_var,
              module_context
            )

          :error ->
            throw("#{line} Found send but expected (unknown) recurse variable #{label}.")
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
        rec_var,
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

        %ST.Call_Recurse{label: label} ->
          case Map.fetch(rec_var, label) do
            {:ok, %ST.Branch{branches: branches}} ->
              branches

            {:ok, %ST.Recv{label: label, types: types, next: next}} ->
              %{label => %ST.Recv{label: label, types: types, next: next}}

            :error ->
              throw("#{line} Found receive but expected (unknown) recurse variable #{label}.")
          end

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
              rec_var,
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

      if ST.equal(st, acc) do
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
        rec_var,
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

    inner_ast =
      Enum.map(cases, fn
        {:->, _, [[_lhs] | rhs]} ->
          # Given: {:a, b} when is_atom(b) -> do_something()
          # lhs contains data related to '{:a, b} when is_atom(b)'
          # rhs contains the body, e.g. 'do_something()'
          # {label, parameters} = parse_options(lhs)
          rhs
      end)

    # Do session type checking with each branch in the case.
    # All branches need to be correct (no violations), and
    # all branches need to end up in the same session type state.
    Enum.map(
      inner_ast,
      fn ast ->
        session_typecheck_ast(
          ast,
          session_type,
          rec_var,
          module_context
        )
      end
    )
    # Ensure that all session types are in the same, and return the last one
    |> Enum.reduce(fn full_st, full_acc ->
      {x, st} = full_st
      {_, acc} = full_acc

      # todo ensure that session type equality is correct
      if ST.equal(st, acc) do
        {x, st}
      else
        throw(
          "#{line} Mismatch in session type following the choice: #{ST.st_to_string(st)} " <>
            "and #{ST.st_to_string(acc)}"
        )
      end
    end)
  end

  def session_typecheck_ast({:|>, _meta, _args}, session_type, _rec_var, _module_context) do
    {false, session_type}
    # todo
  end

  def session_typecheck_ast(
        {{:., _, _args}, _meta, _},
        session_type,
        _rec_var,
        _module_context
      ) do
    # Remote function call, ignore
    {false, session_type}
  end

  # Function call
  def session_typecheck_ast(
        {function_name, meta, parameters},
        session_type,
        rec_var,
        module_context
      )
      when is_list(parameters) do
    arity = length(parameters)

    %ST.Module{
      functions: functions,
      function_mapped_st: function_mapped_st,
      session_types: session_types,
      module_name: _module_name,
      cur_function: %ST.Function{
        name: function_cxt_name,
        arity: function_cxt_arity
      }
    } = module_context

    line =
      if meta[:line] do
        "[Line #{meta[:line]}]"
      else
        "[Line unknown]"
      end

    # if function_cxt_name == function_name and function_cxt_arity == arity do
    #   case session_type do
    #     %ST.Call_Recurse{label: _label} ->
    #       # todo
    #       # case Map.fetch(rec_var, label) do
    #       #   {:ok, _} ->
    #       #   :error =>
    #       # end

    #       IO.puts("#{line} Doing recursion for function #{inspect({function_name, arity})}.")
    #       {false, %ST.Terminate{}}

    #     x ->
    #       throw(
    #         "#{line} Doing recursion for function #{inspect({function_name, arity})}. " <>
    #           "Expected #{ST.st_to_string_current(x)}."
    #       )
    #   end
    # else
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

                case ST.session_remainder(session_type, session_type_internal_function) do
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

            session_typecheck_ast(ast, session_type, rec_var, module_context)

          :error ->
            throw(
              "#{line} Should not happen. Couldn't find ast for unknown (local) call " <>
                "to function #{inspect({function_name, arity})}"
            )
        end
    end
  end

  # end

  def session_typecheck_ast(_, session_type, _, _) do
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

        send(pid, {:a111})

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

    st = "rec X.(?address(any).!a111().X)"
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
