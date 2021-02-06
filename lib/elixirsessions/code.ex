defmodule ElixirSessions.Code do
  require Logger

  @moduledoc """
  Performs the AST comparison with the session types.
  """

  @type ast() :: Macro.t()
  @type info() :: %{
          # recursion: boolean(),
          call_recursion: String.t(),
          function_name: any
          # session_type: any
          # todo maybe add __module__
        }
  @type branch_type() :: %{atom => session_type}
  @type choice_type() :: %{atom => session_type}
  @type session_type() ::
          [
            {:recv, any}
            | {:send, any}
            | {:branch, branch_type}
            | {:call_recurse, any}
            | {:choice, choice_type}
            | {:recurse, any, session_type}
          ]

  @doc """
  Given a function (and its body), it is compared to a session type. `fun` is the function name and `body` is the function body as AST.
  """
  @spec walk_ast(atom(), ast(), session_type()) :: session_type()
  def walk_ast(fun, body, _session_type) do
    IO.inspect(fun)
    IO.inspect(body)

    infer_session_type_incl_recursion(fun, body)
  end

  @doc """
  Infers the session type of the function `fun` given its `body` (including recursion).
  """
  @spec infer_session_type_incl_recursion(atom(), ast()) :: session_type()
  def infer_session_type_incl_recursion(fun, body) do
    info = %{
      call_recursion: "X",
      function_name: fun
    }

    inferred_session_type = infer_session_type(body, info)

    case contains_recursion?(inferred_session_type) do
      true -> [{:recurse, X, inferred_session_type}]
      false -> inferred_session_type
    end
  end

  @doc """
  Given an AST and the info, `infer_session_type/2` infers its session type (excluding recursion).
  """
  def infer_session_type(node, info)
  @spec infer_session_type(ast, info) :: session_type()
  #### Checking for AST literals
  # :atoms, 123, 3.12 (numbers), [1,2,3] (list), "string", {:ok, 1} (short tuples)
  def infer_session_type(x, _info) when is_atom(x) or is_number(x) or is_binary(x) do
    IO.puts("\nAtom/Number/String: #{IO.inspect(x)}")

    []
  end

  def infer_session_type({_a, _b}, _info) do
    IO.puts("\nTuple: ")

    # todo check if ok, maybe check each element
    []
  end

  def infer_session_type(args, info) when is_list(args) do
    IO.puts("\nlist:")

    Enum.reduce(args, [], fn x, acc -> acc ++ infer_session_type(x, info) end)
    |> remove_nils()
  end

  #### AST checking for non literals
  def infer_session_type({:__block__, _meta, args}, info) do
    IO.puts("\nBlock: ")

    infer_session_type(args, info)
  end

  def infer_session_type({:case, _meta, [_what_you_are_checking, body]}, info)
      when is_list(body) do
    IO.puts("\ncase:")

    cases =
      case List.keyfind(body, :do, 0) do
        {:do, x} ->
          x

        _ ->
          # should never happen
          _ = Logger.error("In 'case', cannot find 'do'")
          []
      end

    case length(cases) do
      0 ->
        []

      1 ->
        # todo check if ok with just 1 options
        infer_session_type(cases, info)

      _ ->
        # Greater than 1

        keys = Enum.map(cases, fn {:->, _, [_head | body]} -> get_label_of_first_send(body) end)

        choice_session_type =
          Enum.map(cases, fn x -> infer_session_type(x, info) end)
          # Remove any :nils
          |> Enum.map(fn x -> remove_nils(x) end)

        # Ensure that all cases start with a 'send'

        case ensure_send(choice_session_type) do
          :ok ->
            choice_session_type
            # Add indices
            |> Enum.with_index()
            # Fetch keys by index
            # |> Enum.map(fn {x, y} -> {y, x} end)
            |> Enum.map(fn {x, y} -> {Enum.at(keys, y, y), x} end)
            # Convert to map
            |> Map.new()
            # {:choice, map}
            |> to_choice
            # [{:choice, map}]
            |> to_list

          :error ->
            _ =
              Logger.error(
                "When making a choice (in case statement), you need to have a 'send' as the first item"
              )

            []
        end
    end
  end

  def infer_session_type({:=, _meta, [_left, right]}, info) do
    IO.puts("\npattern matchin (=):")
    # IO.inspect(right)

    infer_session_type(right, info)
  end

  def infer_session_type({:send, _meta, _}, _info) do
    # todo fix type
    [{:send, 'type'}]
  end

  def infer_session_type({:receive, _meta, [body]}, info) do
    # body contains [do: [ {:->, _, [ [ when/condition ], work ]}, other_cases... ] ]

    IO.puts("\nRECEIVE")

    stuff =
      case List.keyfind(body, :do, 0) do
        {:do, x} -> x
        _ -> []
      end

    IO.puts("Receive body size = #{length(stuff)}")

    result =
      case length(stuff) do
        0 ->
          []

        1 ->
          [{:recv, 'type'}]

        _ ->
          # Greater than 1
          keys =
            Enum.map(stuff, fn
              {:->, _, [[{:{}, _, matching_name}] | _]} ->
                # IO.inspect(hd(matching_name))
                hd(matching_name)

              {:->, _, [[{matching_name, _}] | _]} ->
                # IO.inspect(matching_name)
                matching_name

              {:->, _, [[{matching_name}] | _]} ->
                _ =
                  Logger.warn("Warning: Receiving only {:label}, without value ({:label, value})")

                # IO.inspect(matching_name)
                matching_name

              # todo add line number in error
              _ ->
                _ =
                  Logger.error(
                    "Error: Pattern matching in 'receive' is incorrect. Should be in the following format: {:label, value}."
                  )
            end)

          Enum.map(stuff, fn x -> [{:recv, 'type'}] ++ infer_session_type(x, info) end)
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

    IO.puts("RESULT for receive")
    # IO.inspect(result)
    result
  end

  def infer_session_type({:->, _meta, [_head | body]}, info) do
    IO.puts("\n->:")
    res = infer_session_type(body, info)

    IO.puts("\n-> (result):")
    # IO.inspect(res)
    res
  end

  def infer_session_type({function_name, _meta, _}, %{function_name: function_name}) do
    IO.puts("\nRecurse on #{IO.inspect(function_name)}:")

    # todo replace instead of (only) X
    [{:call_recurse, :X}]
  end

  def infer_session_type({:|>, _meta, args}, info) do
    # Pipe operator
    infer_session_type(args, info)
  end

  def infer_session_type(_, _info) do
    IO.puts("\nUnknown:")
    # IO.inspect(x)

    []
  end

  # todo macro expand (including expand if statements)

  #########################################################

  ### Returns the label of the first send encountered: send(pid, {:label, data, ...})
  @spec get_label_of_first_send(ast()) :: atom()
  def get_label_of_first_send(ast)

  def get_label_of_first_send({:case, _, [_what_you_are_checking, body]})
      when is_list(body) do
    # [do: [ {:->, _, [ [ when/condition ], body ]}, other_cases... ] ]

    stuff =
      case List.keyfind(body, :do, 0) do
        {:do, x} -> x
        _ -> []
      end

    get_label_of_first_send(stuff)
  end

  def get_label_of_first_send(args) when is_list(args) do
    Enum.map(args, fn x -> get_label_of_first_send(x) end)
    |> first_non_nil()
  end

  def get_label_of_first_send({:->, _meta, args}) do
    # head contains info related to 'when'
    [_head | tail] = args
    get_label_of_first_send(tail)
  end

  def get_label_of_first_send({:send, _meta, [_to, data]}) do
    case first_elem_in_tuple_node(data) do
      nil ->
        _ = Logger.error("The data in send should be of the format: {:label, ...}")

      x ->
        x
    end
  end

  def get_label_of_first_send({:__block__, _meta, args}) when is_list(args) do
    get_label_of_first_send(args)
  end

  def get_label_of_first_send(_) do
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

  defp remove_nils(args) when is_list(args) do
    args
    |> Enum.filter(fn x -> !is_nil(x) end)
  end

  # Returns the first element from a tuple in AST form
  # :atom                    # :atom
  # {:{}, [], []}            # {}
  # {:{}, [], [1]}           # {1}
  # {1, 2}                   # {1,2}
  # {:{}, [], [1, 2, 3]}     # {1,2,3}
  # {:{}, [], [1, 2, 3, 4]}  # {1,2,3,4}
  @spec first_elem_in_tuple_node(ast()) :: atom()
  def first_elem_in_tuple_node(x) when is_atom(x), do: x
  def first_elem_in_tuple_node({x, _}), do: x
  def first_elem_in_tuple_node({:{}, [], [x]}), do: x
  def first_elem_in_tuple_node({:{}, [], [x | _]}), do: x
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

  # recompile && ElixirSessions.Code.run
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

    session_type = [send: '{:ping, pid}', recv: '{:pong}']

    walk_ast(fun, body, session_type)
    # body
  end
end
