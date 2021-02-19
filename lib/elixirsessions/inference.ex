defmodule ElixirSessions.Inference do
  require Logger
  require ElixirSessions.Common

  @moduledoc """
  Performs session type inference of a given AST.


  ## Examples
          iex> ast = quote do
          ...>   def ping(pid) do
          ...>     send(pid, {:label})
          ...>     receive do
          ...>       {:do_something} -> :ok
          ...>       {:do_something_else, value} -> send(pid, {:label2, value})
          ...>     end
          ...>
          ...>     a = true
          ...>     case a do
          ...>       true -> send(pid, {:first_branch})
          ...>       false -> send(pid, {:other_branch})
          ...>     end
          ...>   end
          ...> end
          ...>
          ...> ElixirSessions.Inference.infer_session_type(:ping, ast)
          [
            send: 'type',
            branch: %{
              do_something: [recv: 'type'],
              do_something_else: [recv: 'type', send: 'type']
            },
            choice: %{
              first_branch: [send: 'type'],
              other_branch: [send: 'type']
            }
          ]


  todo: AST comparison (not just inference) with the expected session types.
  Add runtime check for types: e.g. is_integer, is_atom, ...
  """
  @typedoc false
  @type ast :: ElixirSessions.Common.ast()
  @typedoc false
  @type info :: ElixirSessions.Common.info()
  @typedoc false
  @type session_type :: ElixirSessions.Common.session_type()

  @doc """
  Given a function (and its body), it is compared to a session type. `fun` is the function name and `body` is the function body as AST.

  ## Examples
          iex> ast = quote do
          ...>   def ping() do
          ...>     send(self(), {:hello})
          ...>   end
          ...> end
          ...> ElixirSessions.Inference.infer_session_type(:ping, ast)
          [send: 'type']
  """
  @spec infer_session_type(atom(), ast()) :: session_type()
  def infer_session_type(fun, body) do
    # IO.inspect(fun)
    # IO.inspect(body)

    infer_session_type_incl_recursion(fun, body)
  end

  @doc """
  Uses `infer_session_type_ast/2` to infer the session type (includes recursion).

  ## Examples
          iex> ast = quote do
          ...>   def ping(pid) do
          ...>     send(pid, {:label})
          ...>     ping()
          ...>   end
          ...> end
          ...>
          ...> ElixirSessions.Inference.infer_session_type(:ping, ast)
          [
            {:recurse, :X, [{:send, 'type'}, {:call_recurse, :X}]}
          ]
  """
  @spec infer_session_type_incl_recursion(atom(), ast()) :: session_type()
  def infer_session_type_incl_recursion(fun, body) do
    info = %{
      call_recursion: :X,
      function_name: fun,
      arity: 0 # todo fix with proper arity
    }

    inferred_session_type = infer_session_type_ast(body, info)

    case contains_recursion?(inferred_session_type) do
      true -> [{:recurse, :X, inferred_session_type}]
      false -> inferred_session_type
    end
  end

  @doc """
  Given an AST, `infer_session_type_ast/2` infers its session type (excluding recursion).

  ## Examples
          iex> ast = quote do
          ...>   def ping() do
          ...>     send(self(), {:label})
          ...>     receive do
          ...>       {:do_something} -> :ok
          ...>       {:do_something_else, value} -> send(self(), {:label2, value})
          ...>     end
          ...>   end
          ...> end
          ...>
          ...> ElixirSessions.Inference.infer_session_type_ast(ast, %{})
          [
            send: 'type',
            branch: %{
              do_something: [recv: 'type'],
              do_something_else: [recv: 'type', send: 'type']
            }
          ]
  """
  def infer_session_type_ast(node, info)
  @spec infer_session_type_ast(ast, info) :: session_type()
  #### Checking for AST literals
  # :atoms, 123, 3.12 (numbers), [1,2,3] (list), "string", {:ok, 1} (short tuples)
  def infer_session_type_ast(x, _info) when is_atom(x) or is_number(x) or is_binary(x) do
    # IO.puts("\nAtom/Number/String: #{IO.inspect(x)}")

    []
  end

  def infer_session_type_ast({_a, _b}, _info) do
    # IO.puts("\nTuple: ")

    # todo check if ok, maybe check each element
    []
  end

  def infer_session_type_ast(args, info) when is_list(args) do
    # IO.puts("\nlist:")

    Enum.reduce(args, [], fn x, acc -> acc ++ infer_session_type_ast(x, info) end)
    |> remove_nils()
  end

  #### AST checking for non literals
  def infer_session_type_ast({:__block__, _meta, args}, info) do
    # IO.puts("\nBlock: ")

    infer_session_type_ast(args, info)
  end

  def infer_session_type_ast({:case, _meta, [_what_you_are_checking, body]}, info)
      when is_list(body) do
    # IO.puts("\ncase:")

    cases = body[:do]

    case length(cases) do
      0 ->
        []

      1 ->
        # todo check if ok with just 1 options
        infer_session_type_ast(cases, info)

      _ ->
        # Greater than 1

        keys = Enum.map(cases, fn {:->, _, [_head | body]} -> get_label_of_first_send(body) end)

        choice_session_type =
          Enum.map(cases, fn x -> infer_session_type_ast(x, info) end)
          # Remove any :nils
          |> Enum.map(fn x -> remove_nils(x) end)

        # Ensure that all cases start with a 'send'

        case ensure_send(choice_session_type) do
          :ok ->
            choice_session_type
            # Add indices
            |> Enum.with_index()
            # Fetch keys by index
            |> Enum.map(fn {x, y} -> {Enum.at(keys, y, y), x} end)
            # Convert to map
            |> Map.new()
            # {:choice, map}
            |> to_choice
            # [{:choice, map}]
            |> to_list

          :error ->
            # _ =
            #   Logger.error(
            #     "When making a choice (in case statement), you need to have a 'send' as the first item"
            #   )

            []
        end
    end
  end

  def infer_session_type_ast({:=, _meta, [_left, right]}, info) do
    # IO.puts("\npattern matchin (=):")
    # IO.inspect(right)

    infer_session_type_ast(right, info)
  end

  def infer_session_type_ast({:send, _meta, _}, _info) do
    # todo fix type
    [{:send, 'type'}]
  end

  def infer_session_type_ast({:receive, _meta, [body]}, info) do
    # body contains [do: [ {:->, _, [ [ when/condition ], work ]}, other_cases... ] ]

    # IO.puts("\nRECEIVE")

    cases = body[:do]

    # IO.puts("Receive body size = #{length(cases)}")

    case length(cases) do
      0 ->
        []

      1 ->
        [{:recv, 'type'}] ++ infer_session_type_ast(cases, info)

      _ ->
        # Greater than 1
        keys =
          Enum.map(cases, fn
            {:->, _, [[{:{}, _, matching_name}] | _]} ->
              # IO.inspect(hd(matching_name))
              hd(matching_name)

            {:->, _, [[{matching_name, _}] | _]} ->
              # IO.inspect(matching_name)
              matching_name

            {:->, _, [[{matching_name}] | _]} ->
              _ = Logger.warn("Warning: Receiving only {:label}, without value ({:label, value})")

              # IO.inspect(matching_name)
              matching_name

            # todo add line number in error
            _ ->
              _ =
                Logger.error(
                  "Error: Pattern matching in 'receive' is incorrect. Should be in the following format: {:label, value}."
                )
          end)

        Enum.map(cases, fn x -> [{:recv, 'type'}] ++ infer_session_type_ast(x, info) end)
        # Remove any :nils
        |> Enum.map(fn x -> remove_nils(x) end)
        # Add indices
        |> Enum.with_index()
        # Fetch keys by index
        |> Enum.map(fn {x, y} -> {Enum.at(keys, y, y), x} end)
        # Convert to map
        |> Map.new()
        # {:branch, map}
        |> to_branch
        # [{:branch, map}]
        |> to_list
    end
  end

  def infer_session_type_ast({:->, _meta, [_head | body]}, info) do
    # IO.puts("\n->:")
    infer_session_type_ast(body, info)

    # IO.puts("\n-> (result):")
    # IO.inspect(res)
    # res
  end

  def infer_session_type_ast({function_name, _meta, _}, %{
        function_name: function_name,
        call_recursion: recurse
      }) do
    # IO.puts("\nRecurse on #{IO.inspect(function_name)}:")

    # todo replace instead of (only) X
    [{:call_recurse, recurse}]
  end

  def infer_session_type_ast({:|>, _meta, args}, info) do
    # Pipe operator
    infer_session_type_ast(args, info)
  end

  def infer_session_type_ast({fun, _meta, [_function_name, body]}, info)
      when fun in [:def, :defp] do
    # todo compare function_name to info[:function_name]
    infer_session_type_ast(body[:do], info)
  end

  def infer_session_type_ast(_, _info) do
    # IO.puts("\nUnknown:")
    []
  end

  # todo macro expand (including expand if statements)

  #########################################################

  ### Returns the label of the first send encountered: send(pid, {:label, data, ...})
  @spec get_label_of_first_send(ast()) :: atom()
  defp get_label_of_first_send(ast)

  defp get_label_of_first_send({:case, _, [_what_you_are_checking, body]})
       when is_list(body) do
    # [do: [ {:->, _, [ [ when/condition ], body ]}, other_cases... ] ]

    stuff =
      case List.keyfind(body, :do, 0) do
        {:do, x} -> x
        _ -> []
      end

    get_label_of_first_send(stuff)
  end

  defp get_label_of_first_send(args) when is_list(args) do
    Enum.map(args, fn x -> get_label_of_first_send(x) end)
    |> first_non_nil()
  end

  defp get_label_of_first_send({:->, _, [_head | body]}) do
    # head contains info related to 'when'
    get_label_of_first_send(body)
  end

  defp get_label_of_first_send({:send, _meta, [_to, data]}) do
    case first_elem_in_tuple_node(data) do
      nil ->
        _ = Logger.error("The data in send should be of the format: {:label, ...}")

      x ->
        x
    end
  end

  defp get_label_of_first_send({:__block__, _meta, args}) when is_list(args) do
    get_label_of_first_send(args)
  end

  defp get_label_of_first_send(_) do
    nil
  end

  # Check if a given  contains {call_recurse, :X}
  @spec contains_recursion?(session_type()) :: boolean()
  defp contains_recursion?(session_type)

  defp contains_recursion?(x) when is_list(x) do
    Enum.reduce(x, false, fn elem, acc -> acc || contains_recursion?(elem) end)
  end

  defp contains_recursion?({x, _}) when x in [:send, :recv] do
    false
  end

  defp contains_recursion?({x, args}) when x in [:branch, :choice] and is_map(args) do
    # args = %{label1: [do_stuff, ...], ...}
    args
    # {[label1, ...], [[do_stuff, ...]]}
    |> Enum.unzip()
    # [[do_stuff, ...]]
    |> elem(1)
    # [do_stuff, ...]
    |> List.flatten()
    |> contains_recursion?()
  end

  defp contains_recursion?({:call_recurse, _}) do
    true
  end

  defp contains_recursion?(_) do
    _ = Logger.error("Unknown input for contains_recursion?/1")
    false
  end

  ####### Helper functions

  defp to_list(x) do
    [x]
  end

  defp to_branch(x) do
    {:branch, x}
  end

  defp to_choice(x) do
    {:choice, x}
  end

  defp remove_nils(x) when is_list(x) do
    x
    |> Enum.filter(fn elem -> !is_nil(elem) end)
  end

  # Returns the first element from a tuple in AST form
  # :atom                    # :atom
  # {:{}, [], []}            # {}
  # {:{}, [], [1]}           # {1}
  # {1, 2}                   # {1,2}
  # {:{}, [], [1, 2, 3]}     # {1,2,3}
  # {:{}, [], [1, 2, 3, 4]}  # {1,2,3,4}
  @doc false
  @spec first_elem_in_tuple_node(ast()) :: atom()
  def first_elem_in_tuple_node(x) when is_atom(x), do: x
  def first_elem_in_tuple_node({x, _}), do: x
  def first_elem_in_tuple_node({:{}, _, x}) when is_list(x), do: hd(x)
  def first_elem_in_tuple_node(_), do: nil

  # Returns first non nil element in a list
  defp first_non_nil(a) when is_list(a) do
    Enum.reduce(a, nil, fn x, acc ->
      if acc == nil do
        x
      else
        acc
      end
    end)
  end

  @doc false
  # Given a list (of list), checks each inner list and ensure that it contains {:send, type} as the first element
  @spec ensure_send(ast()) :: :error | :ok
  def ensure_send(cases) do
    check =
      Enum.map(cases, fn
        [x] ->
          if elem(x, 0) == :send do
            :ok
          else
            :error
          end

        [x | _] ->
          if elem(x, 0) == :send do
            :ok
          else
            :error
          end

        _ ->
          :error
      end)

    if :error in check do
      :error
    else
      :ok
    end
  end

  @doc """
  Runs a self-contained example.

  `recompile && ElixirSessions.Inference.run`
  """
  @spec run :: session_type()
  def run() do
    fun = :ping

    body =
      quote do
        send(self(), {:ping, self()})
        send(self(), {:ping, self()})

        a = true

        case a do
          true ->
            :okkkk
            a = 1 + 3

            send(self(), {:ok1})

            receive do
              {:message_type, value} ->
                :jksdfsdn
            end

            send(self(), :ok2ddd)

          # false -> :kdnfkjs
          _ ->
            send(self(), {:abc, 12, :jhidf})

            send(self(), {:ok2, 12, 23, 4, 45, 535, 63_463_453, 8, :okkdsnjdf})
        end

        send(self(), {:ping, self()})

        case true do
          true -> :ok
          false -> :not_okkkk
        end

        receive do
          {:pong, 1, 2, 3} ->
            IO.puts("Received pong!")
            send(self(), {:ping, self()})
            send(self(), {:ping, self()})
            send(self(), {:ping, self()})

            receive do
              {:pong, 1, 2, 3} ->
                IO.puts("Received pong!")
                send(self(), {:ping, self()})
                send(self(), {:ping, self()})
                send(self(), {:ping, self()})
                send(self(), {:ping, self()})

              {:ponng} ->
                IO.puts("Received ponnng!")
            end

            send(self(), {:ping, self()})

          {:ponng} ->
            IO.puts("Received ponnng!")
        end

        send(self(), {:ping, self()})
        ping()
      end

    infer_session_type(fun, body)
    # body
  end
end
