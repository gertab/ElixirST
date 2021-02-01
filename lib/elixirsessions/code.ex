defmodule ElixirSessions.Code do
  require Logger

  @moduledoc """
  Performs the AST comparison with the session types.
  """

  @doc """
  Given a function (and its body), it is compared to a session type. `fun` is the function name and `body` is the function body as AST.
  """
  def walk_ast(fun, body, session_type) do
    IO.inspect(fun)
    IO.inspect(body)
    # IO.puts(Macro.to_string(body))

    IO.inspect(session_type)

    # Macro.prewalk(body, fn x -> IO.inspect x end)

    result = infer_session_type_incl_recursion(fun, body, session_type)
    IO.inspect(result)
    result
  end

  @doc """
  Infers the session type of the function `fun` given its `body`.
  """
  def infer_session_type_incl_recursion(fun, body, expected_session_type) do
    recursion = contains_recursion?(body, fun)
    # todo maybe add __module__
    info = %{
      recursion: recursion,
      call_recursion: "X",
      function_name: fun,
      session_type: expected_session_type
    }

    case recursion do
      true -> [{:recurse, X, infer_session_type(body, info)}]
      false -> infer_session_type(body, info)
    end
  end

  @type ast() :: Macro.t()
  @type info() :: %{
          recursion: boolean(),
          call_recursion: String.t(),
          function_name: any,
          session_type: any()
        }
  @spec infer_session_type(ast, info) :: any
  def infer_session_type(node, info)

  #### Checking for AST literals
  # :atoms, 123, 3.12 (numbers), [1,2,3] (list), "string", {:ok, 1} (short tuples)
  def infer_session_type(x, _info) when is_atom(x) do
    IO.puts("\n~~ Atom: #{IO.inspect(x)}")

    []
  end

  def infer_session_type(x, _info) when is_number(x) do
    IO.puts("\n~~ Number: #{IO.puts(x)}")

    []
  end

  def infer_session_type(x, _info) when is_binary(x) do
    IO.puts("\n~~ Binary/string:")

    []
  end

  def infer_session_type({_a, _b}, _info) do
    IO.puts("\n~~Tuple: ")

    # todo check if ok
    []
  end

  def infer_session_type([a], info) do
    IO.puts("\n~~Short list (1):")
    # IO.inspect(a)

    infer_session_type(a, info)
    |> Enum.filter(&(!is_nil(&1)))
  end

  def infer_session_type([a, b], info) do
    IO.puts("\n~~Short list (2):")
    # IO.inspect(a)
    # IO.inspect(b)

    (infer_session_type(a, info) ++ infer_session_type(b, info))
    |> Enum.filter(&(!is_nil(&1)))
  end

  def infer_session_type([a, b, c], info) do
    IO.puts("\n~~Short list (3):")
    # IO.inspect(a)
    # IO.inspect(b)
    # IO.inspect(c)

    (infer_session_type(a, info) ++ infer_session_type(b, info) ++ infer_session_type(c, info))
    |> Enum.filter(&(!is_nil(&1)))
  end

  #### AST checking for non literals
  def infer_session_type({:__block__, _meta, args}, info) do
    IO.puts("\n~~Block: ")
    # IO.inspect(args)

    res =
      Enum.reduce(args, [], fn x, acc -> acc ++ infer_session_type(x, info) end)
      |> Enum.filter(&(!is_nil(&1)))

    IO.puts("\n~~Block (result): ")
    # IO.inspect(res)

    res
  end

  # todo: when checking for case AST; if it does not contain send/receive, skip
  def infer_session_type({:case, _, [_what_you_are_checking, body]} = ast, info)
      when is_list(body) do
    IO.puts("\n~~case:")

    if contains_send_receive?(ast) do
      IO.puts("\nCONTAINS SEND/RECEIVE")
      # todo check if all cases neen to have send/receive
      stuff =
        case List.keyfind(body, :do, 0) do
          {:do, x} ->
            _ = Logger.warn("WARNING: function not finished yet.")
            x

          _ ->
            # should never happen
            _ = Logger.error("In case, cannot find 'do'")
            []
        end

      result =
        case length(stuff) do
          0 ->
            []

          1 ->
            # todo check if ok with just 1 options
            infer_session_type(stuff, info)

          _ ->
            # Greater than 1

            keys =
              Enum.map(stuff, fn {:->, _, [_head | body]} -> get_label_of_first_send(body) end)

            choice_session_type =
              Enum.map(stuff, fn x -> infer_session_type(x, info) end)
              # Remove any :nils
              |> Enum.map(fn x -> Enum.filter(x, &(!is_nil(&1))) end)

            # Ensure that all cases start with a 'send'

            if ensure_send(choice_session_type) == :ok do
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
            else
              _ =
                Logger.error(
                  "When making a choice (in case statement), you have a 'send' as the first item"
                )
            end
        end

      result
    else
      IO.puts("\nDOES NOT CONTAIN SEND/RECEIVE")

      []
    end
  end

  def infer_session_type({:=, _meta, [_left, right]}, info) do
    IO.puts("\n~~pattern matchin (=):")
    # IO.inspect(right)

    infer_session_type(right, info)
  end

  def infer_session_type({:send, _, _}, _info) do
    # todo fix type
    [{:send, 'type'}]
  end

  def infer_session_type({:receive, _, [body]}, info) do
    # body contains [do: [ {:->, _, [ [ when/condition ], body ]}, other_cases... ] ]

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
          |> Enum.map(fn x -> Enum.filter(x, &(!is_nil(&1))) end)
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

  def infer_session_type({:->, _, [_head | body]}, info) do
    IO.puts("\n~~->:")
    res = infer_session_type(body, info)

    IO.puts("\n~~-> (result):")
    # IO.inspect(res)
    res
  end

  def infer_session_type({function_name, _, _}, %{recursion: true, function_name: function_name}) do
    IO.puts("\nRecurse on #{IO.inspect(function_name)}:")

    # todo replace instead of (only) X
    [{:call_recurse, :X}]
  end

  def infer_session_type({function_name, _, _}, %{recursion: false, function_name: function_name}) do
    # Should never be called
    _ = Logger.error("Error while recursing")

    []
  end

  def infer_session_type({:|>, _, [left, right]}, info) do
    # Pipe operator
    (infer_session_type(left, info) ++ infer_session_type(right, info))
    |> Enum.filter(&(!is_nil(&1)))
  end

  def infer_session_type(_, _info) do
    IO.puts("\n~~Unknown:")
    # IO.inspect(x)

    []
  end

  # todo macro expand (including expand if statements)

  #########################################################

  # todo: replace contains_send_receive? and contains_recursion? with Macro.prewalk()
  ### Checks if (case) contains send/receive
  defp contains_send_receive?({:case, _, [_what_you_are_checking, body]})
       when is_list(body) do
    # [do: [ {:->, _, [ [ when/condition ], body ]}, other_cases... ] ]

    stuff =
      case List.keyfind(body, :do, 0) do
        {:do, x} -> x
        _ -> []
      end

    IO.puts("\nCHECKING IF CONTAINS SEND RECEIVE")
    # IO.inspect(stuff)
    contains_send_receive?(stuff)
  end

  defp contains_send_receive?([a]) do
    contains_send_receive?(a)
  end

  defp contains_send_receive?([a, b]) do
    contains_send_receive?(a) || contains_send_receive?(b)
  end

  defp contains_send_receive?([a, b, c]) do
    contains_send_receive?(a) || contains_send_receive?(b) || contains_send_receive?(c)
  end

  defp contains_send_receive?({:->, _meta, args}) do
    # head contains info related to 'when'
    [_head | tail] = args
    # IO.puts("Checking tail:")
    # IO.inspect(tail)
    contains_send_receive?(tail)
  end

  defp contains_send_receive?({:__block__, _meta, args}) when is_list(args) do
    {_, result} =
      Enum.map_reduce(args, false, fn x, acc ->
        {contains_send_receive?(x), acc || contains_send_receive?(x)}
      end)

    result
  end

  defp contains_send_receive?({definition, _, _}) when definition in [:send, :receive] do
    true
  end

  defp contains_send_receive?(_) do
    false
  end

  ### Checks if contains send/receive
  defp contains_recursion?({:case, _, [_what_you_are_checking, body]}, function_name)
       when is_list(body) do
    # [do: [ {:->, _, [ [ when/condition ], body ]}, other_cases... ] ]

    stuff =
      case List.keyfind(body, :do, 0) do
        {:do, x} -> x
        _ -> []
      end

    # IO.puts("\nCHECKING IF CONTAINS RECURSION")
    # IO.inspect(stuff)
    contains_recursion?(stuff, function_name)
  end

  defp contains_recursion?([a], function_name) do
    contains_recursion?(a, function_name)
  end

  defp contains_recursion?([a, b], function_name) do
    contains_recursion?(a, function_name) || contains_recursion?(b, function_name)
  end

  defp contains_recursion?([a, b, c], function_name) do
    contains_recursion?(a, function_name) || contains_recursion?(b, function_name) ||
      contains_recursion?(c, function_name)
  end

  defp contains_recursion?({:->, _meta, args}, function_name) do
    # head contains info related to 'when'
    [_head | tail] = args
    contains_recursion?(tail, function_name)
  end

  defp contains_recursion?({:__block__, _meta, args}, function_name) when is_list(args) do
    {_, result} =
      Enum.map_reduce(args, false, fn x, acc ->
        {contains_recursion?(x, function_name), acc || contains_recursion?(x, function_name)}
      end)

    result
  end

  defp contains_recursion?({function_name, _, _}, function_name) do
    # Recursion occurs here, since {function_name, _, _} calls the current function
    # todo: case when same function is called via module name e.g. Module.function_name
    true
  end

  defp contains_recursion?(_, _function_name) do
    false
  end

  ### Returns the label of the first send encountered: send(pid, {:label, data, ...})
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

  defp get_label_of_first_send([a]) do
    get_label_of_first_send(a)
  end

  defp get_label_of_first_send([a, b]) do
    x = get_label_of_first_send(a)

    if x == nil do
      get_label_of_first_send(b)
    else
      x
    end
  end

  defp get_label_of_first_send([a, b, c]) do
    # Returns the first non nil result
    x = get_label_of_first_send(a)

    if x == nil do
      y = get_label_of_first_send(b)

      if x == nil do
        get_label_of_first_send(c)
      else
        y
      end
    else
      x
    end
  end

  defp get_label_of_first_send({:->, _meta, args}) do
    # head contains info related to 'when'
    [_head | tail] = args
    get_label_of_first_send(tail)
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
    Enum.map(args, fn x -> get_label_of_first_send(x) end)
    |> first_non_nil()
    |> IO.inspect()

    # Returns the first non nil result

    # result
  end

  defp get_label_of_first_send(_) do
    nil
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

  # Returns the first element from a tuple in AST form
  # :atom                    # :atom
  # {:{}, [], []}            # {}
  # {:{}, [], [1]}           # {1}
  # {1, 2}                   # {1,2}
  # {:{}, [], [1, 2, 3]}     # {1,2,3}
  # {:{}, [], [1, 2, 3, 4]}  # {1,2,3,4}
  def first_elem_in_tuple_node(x) when is_atom(x) do
    x
  end

  def first_elem_in_tuple_node({x, _}) do
    x
  end

  def first_elem_in_tuple_node({:{}, [], [x]}) do
    x
  end

  def first_elem_in_tuple_node({:{}, [], [x | _]}) do
    x
  end

  def first_elem_in_tuple_node(_) do
    nil
  end

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
  def run() do
    fun = :ping

    body =
      quote do
        # send(self(), {:ping, self()})
        # send(self(), {:ping, self()})

        # a = true

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

          _ ->
            send(self(), {:abc, 12, :jhidf})

            send(self(), {:ok2, 12, 23, 4, 45, 535, 63_463_453, 8, :okkdsnjdf})
        end

        # send(self(), {:ping, self()})

        # case true do
        #   true -> :ok
        # end

        # receive do
        #   {:pong, 1, 2, 3} ->
        #     IO.puts("Received pong!")
        #     send(self(), {:ping, self()})
        #     send(self(), {:ping, self()})
        #     send(self(), {:ping, self()})

        #     receive do
        #       {:pong, 1, 2, 3} ->
        #         IO.puts("Received pong!")
        #         send(self(), {:ping, self()})
        #         send(self(), {:ping, self()})
        #         send(self(), {:ping, self()})
        #         send(self(), {:ping, self()})

        #       {:ponng} ->
        #         IO.puts("Received ponnng!")
        #     end

        #     send(self(), {:ping, self()})

        #   {:ponng} ->
        #     IO.puts("Received ponnng!")
        # end

        # send(self(), {:ping, self()})
        # ping()
      end

    session_type = [send: '{:ping, pid}', recv: '{:pong}']
    # a = Macro.prewalk(body, fn x -> Macro.expand(x, __ENV__) end)
    # IO.inspect(a)

    # IO.inspect Macro.expand(body, __ENV__)
    # IO.puts("_b = ")
    # IO.inspect(body)
    walk_ast(fun, body, session_type)

    # body
  end
end
