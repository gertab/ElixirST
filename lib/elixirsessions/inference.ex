defmodule ElixirSessions.Inference do
  require Logger
  require ST

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
      ...>     a = true
      ...>     case a do
      ...>       true -> send(pid, {:first_branch})
      ...>       false -> send(pid, {:other_branch})
      ...>     end
      ...>   end
      ...> end
      ...> st = ElixirSessions.Inference.infer_session_type(:ping, ast)
      ...> ElixirSessions.Parser.st_to_string(st)
      "!label().&{?do_something().+{!first_branch(), !other_branch()}, ?do_something_else(any).!label2(any).+{!first_branch(), !other_branch()}}"

  todo: AST comparison (not just inference) with the expected session types.
  todo: add more detail in errors (e.g. lines)
  todo: fix structure?
  Add runtime check for types: e.g. is_integer, is_atom, ...
  """
  @typedoc false
  @type ast :: ST.ast()
  @typedoc false
  @type info :: ST.info()

  @typedoc """
  A session type list of session operations.

  A session type may: `receive` (or dually `send` data), `branch` (or make a `choice`) or `recurse`.
  """
  @type session_type() ::
          [
            {:recv, atom, any}
            | {:send, atom, any}
            | {:branch, [session_type]}
            | {:choice, [session_type]}
            | {:call_recurse, atom}
            | {:recurse, atom, session_type}
          ]

  @doc """
  Given a function (and its body), it is compared to a session type. `fun` is the function name and `body` is the function body as AST.

  ## Examples
          iex> ast = quote do
          ...>   def ping() do
          ...>     send(self(), {:hello})
          ...>   end
          ...> end
          ...> ElixirSessions.Inference.infer_session_type(:ping, ast)
          [{:send, :hello, []}]
  """
  @spec infer_session_type(atom(), ast()) :: session_type()
  def infer_session_type(fun, body) do
    # IO.inspect(fun)
    # IO.inspect(body)

    res = infer_session_type_incl_recursion(fun, body)

    # IO.puts("Inferred session type for &#{fun}:\n#{ElixirSessions.Parser.st_to_string(res)}\n")

    res_structured = ElixirSessions.Parser.fix_structure_branch_choice(res)
    ElixirSessions.Parser.validate(res_structured)

    IO.puts("Inferred session type for &#{fun}:\n#{ElixirSessions.Parser.st_to_string(res_structured)}\n")

    res_structured
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
          ...> st = ElixirSessions.Inference.infer_session_type(:ping, ast)
          [
            {:recurse, :X, [{:send, :label, []}, {:call_recurse, :X}]}
          ]
          ...> ElixirSessions.Parser.st_to_string(st)
          "rec X.(!label().X)"
  """
  @spec infer_session_type_incl_recursion(atom(), ast()) :: session_type()
  def infer_session_type_incl_recursion(fun, body) do
    info = %{
      call_recursion: :X,
      function_name: fun,
      # todo fix with proper arity
      arity: 0
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
            {:send, :label, []},
            {:branch,
            [
              [{:recv, :do_something, []}],
              [{:recv, :do_something_else, [:any]}, {:send, :label2, [:any]}]
            ]}
          ]
  """
  def infer_session_type_ast(node, info)
  @spec infer_session_type_ast(ast, info) :: session_type()
  #### Checking for AST literals
  # :atoms, 123, 3.12 (numbers), [1,2,3] (list), "string", {:ok, 1} (short tuples)
  def infer_session_type_ast(x, _info) when is_atom(x) or is_number(x) or is_binary(x) do
    # Atom, number, or string
    []
  end

  def infer_session_type_ast({_a, _b}, _info) do
    # Tuple

    # todo check if ok, maybe check each element
    []
  end

  def infer_session_type_ast(args, info) when is_list(args) do
    # List

    Enum.reduce(args, [], fn x, acc -> acc ++ infer_session_type_ast(x, info) end)
    |> remove_nils()
  end

  #### AST checking for non literals
  def infer_session_type_ast({:__block__, _meta, args}, info) do
    # Block

    infer_session_type_ast(args, info)
  end

  def infer_session_type_ast({:case, _meta, [_what_you_are_checking, body]}, info)
      when is_list(body) do
    # Case

    cases = body[:do]

    case length(cases) do
      0 ->
        []

      1 ->
        # todo check if ok with just 1 options
        infer_session_type_ast(cases, info)

      _ ->
        # Greater than 1

        choice_session_type =
          Enum.map(cases, fn x -> infer_session_type_ast(x, info) end)
          # Remove any :nils
          |> Enum.map(fn x -> remove_nils(x) end)

        # Ensure that all cases start with a 'send'
        case ensure_send(choice_session_type) do
          :ok ->
            choice_session_type
            # {:choice, map}
            |> to_choice
            # [{:choice, map}]
            |> to_list

          :error ->
            # todo fix
            # nope because it breaks if there is a 'case' without send/receive statements
            # throw("Error while inferring: When making a choice (in case statement), you need to have a 'send' as the first item")

            []
        end
    end
  end

  def infer_session_type_ast({:=, _meta, [_left, right]}, info) do
    # Pattern matchin

    infer_session_type_ast(right, info)
  end

  def infer_session_type_ast({:send, _meta, [_lhr, rhs]}, _info) do
    # Send

    {label, types} = parse_options(rhs)

    [{:send, label, types}]
  end

  def infer_session_type_ast({:receive, _meta, [body]}, info) do
    # body contains [do: [ {:->, _, [ [ when/condition ], work ]}, other_cases... ] ]
    # Receive

    cases = body[:do]

    case length(cases) do
      0 ->
        []

      1 ->
        {:->, _, [[lhs] | _]} = hd(cases)
        {label, types} = parse_options(lhs)

        [{:recv, label, types}] ++ infer_session_type_ast(cases, info)

      _ ->
        Enum.map(cases, fn x ->
          {:->, _, [[lhs] | _]} = x
          {label, types} = parse_options(lhs)

          [{:recv, label, types}] ++ infer_session_type_ast(x, info)
        end)
        # Remove any :nils
        |> Enum.map(fn x -> remove_nils(x) end)
        # {:branch, map}
        |> to_branch
        # [{:branch, map}]
        |> to_list
    end
  end

  def infer_session_type_ast({:->, _meta, [_head | body]}, info) do
    # ->
    infer_session_type_ast(body, info)
  end

  def infer_session_type_ast({function_name, _meta, _}, %{
        function_name: function_name,
        call_recursion: recurse
      }) do
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

  # Check if a given  contains {call_recurse, :X}
  @spec contains_recursion?(session_type()) :: boolean()
  defp contains_recursion?(session_type)

  defp contains_recursion?(x) when is_list(x) do
    Enum.reduce(x, false, fn elem, acc -> acc || contains_recursion?(elem) end)
  end

  defp contains_recursion?({x, _, _}) when x in [:send, :recv] do
    false
  end

  defp contains_recursion?({x, args}) when x in [:branch, :choice] and is_list(args) do
    # args =[[do_stuff, ...], [...], ...}]
    args
    # todo check if it works
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

  @doc false
  # Takes case of :-> and returns the label and number of values as ':any' type.
  # e.g. {:label, value1, value2} -> do_something()
  # returns {:label, [:any, :any]}
  def parse_options(x) do
    x =
      case x do
        {:when, _, data} ->
          # throw("Problem while inferring: 'when' not implemented yet")
          hd(data)

        x ->
          x
      end

    {label, size} =
      case x do
        # Size 0, e.g. {:do_something}
        {:{}, _, [label]} ->
          {label, 0}

        # Size 1, e.g. {:value, 545}
        {label, _} ->
          {label, 1}

        # Size > 2, e.g. {:add, 3, 5}
        {:{}, _, x} when is_list(x) and length(x) > 2 ->
          {hd(x), length(x)}

        _ ->
          throw(
            "Needs to be a tuple contain at least a label. E.g. {:do_something} oe {:value, 54}"
          )
      end

    case is_atom(label) do
      true ->
        :ok

      false ->
        throw("First item in tuple needs to be a label/atom. (#{inspect(label)})")
    end

    # Default type is set to any
    types = List.duplicate(:any, size)

    {label, types}
  end

    @doc """
  Fixes structure of sessionn types. E.g. `&{!A()}.!B()` becomes `&{!A().!B()}`.

  ## Examples
      iex> s = "&{?Hello()}.!Wrong()"
      ...> st = ElixirSessions.Parser.parse(s) # Calls fix_structure_branch_choice
      ...> ElixirSessions.Parser.st_to_string(st)
      "&{?Hello().!Wrong()}"

  ## Examples
      iex> st =
      ...> [
      ...>   {:choice, [[{:send, :neg, [:number, :pid]}, {:recv, :Num, [:number]}]]},
      ...>   {:send, :Hello, [:integer]}
      ...> ]
      iex> ElixirSessions.Parser.fix_structure_branch_choice(st)
      [
        choice: [
          [
            {:send, :neg, [:number, :pid]},
            {:recv, :Num, [:number]},
            {:send, :Hello, [:integer]}
          ]
        ]
      ]
  """
  @spec fix_structure_branch_choice(session_type()) :: session_type()
  def fix_structure_branch_choice([{:send, label, types} | remaining]) do
    [{:send, label, types} | fix_structure_branch_choice(remaining)]
  end

  def fix_structure_branch_choice([{:recv, label, types} | remaining]) do
    [{:recv, label, types} | fix_structure_branch_choice(remaining)]
  end

  def fix_structure_branch_choice([{:branch, branches}]) do
    [{:branch, Enum.map(branches, fn branch -> fix_structure_branch_choice(branch) end)}]
  end

  def fix_structure_branch_choice([{:branch, branches} | remaining]) do
    final = [
      {:branch,
       Enum.map(branches, fn branch ->
         fix_structure_branch_choice(branch ++ fix_structure_branch_choice(remaining))
       end)}
    ]

    # _ = Logger.warn("Fixing structure of session type: \n#{st_to_string(initial)} was changed to\n#{st_to_string(final)}")
    final
  end

  def fix_structure_branch_choice([{:choice, choices}]) do
    [{:choice, Enum.map(choices, fn choice -> fix_structure_branch_choice(choice) end)}]
  end

  def fix_structure_branch_choice([{:choice, choices} | remaining]) do
    final = [
      {:choice,
       Enum.map(choices, fn choice ->
         fix_structure_branch_choice(choice ++ fix_structure_branch_choice(remaining))
       end)}
    ]

    # _ = Logger.warn("Fixing structure of session type: \n#{st_to_string(initial)} was changed to\n#{st_to_string(final)}")
    final
  end

  def fix_structure_branch_choice([{:call_recurse, label} | remaining]) do
    [{:call_recurse, label} | fix_structure_branch_choice(remaining)]
  end

  def fix_structure_branch_choice([{:recurse, label, body} | remaining]) do
    [
      {:recurse, label, fix_structure_branch_choice(body)}
      | fix_structure_branch_choice(remaining)
    ]
  end

  def fix_structure_branch_choice([]) do
    []
  end

  def fix_structure_branch_choice(x) do
    throw("fix_structure_branch_choice unknown #{inspect(x)}")
    []
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
        send(pid, {:hello, value})

        receive do
          {:label1} ->
            receive do
              {:option1, v} -> send(pid, {:in_label1})
              {:option2} -> :ok
            end

          {:label2} ->
            :ok

          {:label3} ->
            :ok
        end

        send(pid, {:end})

        # send(self(), {:ping})
        # send(self(), {:ping2, 43})
        # send(self(), {:ping3, 2343, 23_424_234})

        # a = true

        # receive do
        #   {:labelll, 34, v} ->
        #     :okkk
        # end

        # case a do
        #   true ->
        #     :okkkk
        #     a = 1 + 3

        #     send(self(), {:ok1})

        #     receive do
        #       {:message_type, value} ->
        #         :jksdfsdn
        #     end

        #     send(self(), {:ok2ddd})

        #   # false -> :kdnfkjs
        #   _ ->
        #     send(self(), {:abc, 12, :jhidf})

        #     send(self(), {:ok2, 12, 23, 4, 45, 535, 63_463_453, 8, :okkdsnjdf})
        # end

        # send(self(), {:ping, self()})

        # case true do
        #   true -> :ok
        #   false -> :not_okkkk
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

    infer_session_type(fun, body)
    # body
  end
end
