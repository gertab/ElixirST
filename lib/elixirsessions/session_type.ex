defmodule ST do
  @moduledoc """
  Manipulate Session Type data

  Session type definitions:
      ! = send
      ? = receive
      & = branch (or external choice)
      + = (interal) choice

  Session types accept the following grammar:

      S =
          !label(types, ...).S
        | ?label(types, ...).S
        | &{?label(types, ...).S, ...}
        | +{!label(types, ...).S, ...}
        | rec X.(S)
        | X
        | end

  Note: The session type `end` is optional, therefore `!Hello()` and `!Hello().end` are equivalent.
  `X` refers to to a variable which can be called later in a recursion operation.
  `rec X.(S)` refers to recursion, or looping - when `X` is called, it is replaced with the whole session type
  `rec X.(S)`.

  Some session types examples:

      !Hello()                           # Sends {:Hello}

      ?Ping(number)                      # Receives {:Ping, value}, where values has to be a number

      &{?Option1().!Hello(), ?Option2()} # Receive either {:Option1} or {:Option2}. If it
                                         # receives the former, then it sends {:Hello}. If it
                                         # receives {:Option2}, then it terminates.

      rec X.(&{?Stop().end, ?Retry().X}) # The actor is able to receive multiple {:Retry},
                                         # and terminates when it receives {:Stop}.


  Internal representation of session types take the form of the following structs:
  - `%Send{label, types, next}`
  - `%Recv{label, types, next}`
  - `%Choice{choices}`
  - `%Branch{branches}`
  - `%Recurse{label, body}`
  - `%Call_Recurse{label}`
  - `%Terminate{}`

  The labels and types are of type `t:label/0` and `t:types/0` respectively. `next`, `choices`, `branches` and `body` have the type
  `t:session_type/0`.

  ### Parser

  Parses an input string to session types (as Elixir data).

  #### Simple example

      iex> s = "!Hello(Number)"
      ...> ST.string_to_st(s)
      %ST.Send{label: :Hello, next: %ST.Terminate{}, types: [:number]}

  #### Another example

      iex> s = "rec X.(&{?Ping().!Pong().X, ?Quit().end})"
      ...> ST.string_to_st(s)
      %ST.Recurse{
        label: :X,
        body: %ST.Branch{
          branches: %{
            Ping: %ST.Recv{
              label: :Ping,
              next: %ST.Send{label: :Pong, next: %ST.Call_Recurse{label: :X}, types: []},
              types: []
            },
            Quit: %ST.Recv{label: :Quit, next: %ST.Terminate{}, types: []}
          }
        }
      }

  """

  @typedoc """
  A session type list of session operations.
  """
  @type session_type() ::
          %ST.Send{label: label(), types: types(), next: session_type()}
          | %ST.Recv{label: label(), types: types(), next: session_type()}
          | %ST.Choice{choices: %{label() => session_type()}}
          | %ST.Branch{branches: %{label() => session_type()}}
          | %ST.Recurse{label: label(), body: session_type()}
          | %ST.Call_Recurse{label: label()}
          | %ST.Terminate{}

  @typedoc """
  Session types when stored as tuples. Useful for when converting from Erlang records.
  """
  @type session_type_tuple() ::
          {:send, atom, [atom], session_type_tuple()}
          | {:recv, atom, [atom], session_type_tuple()}
          | {:choice, [session_type_tuple]}
          | {:branch, [session_type_tuple]}
          | {:call, atom}
          | {:recurse, atom, session_type_tuple}
          | {:terminate}

  @typedoc """
  Label for sending/receiving statements. Should be of the form of an `atom`.
  """
  @type label() :: atom()

  @typedoc """
  Type for name and arity keys.
  """
  @type name_arity() :: {label(), non_neg_integer()}

  @typedoc """
  Native types accepted in the send/receive statements.
  E.g. !Ping(integer)
  """
  @type types() :: [
          :atom
          | :binary
          | :bitstring
          | :boolean
          | :exception
          | :float
          | :function
          | :integer
          | :list
          | :map
          | nil
          | :number
          | :pid
          | :port
          | :reference
          | :struct
          | :tuple
          | :string
        ]

  @typedoc """
  Abstract Syntax Tree (AST)
  """
  @type ast() :: Macro.t()

  defmodule Terminate do
    @moduledoc false
    defstruct []
    @type t :: %__MODULE__{}
  end

  defmodule Send do
    @moduledoc false
    @enforce_keys [:label]
    defstruct [:label, types: [], next: %ST.Terminate{}]

    @type session_type() :: ST.session_type()
    @type label() :: ST.label()
    @type types() :: ST.types()
    @type t :: %__MODULE__{label: label(), types: types(), next: session_type()}
  end

  defmodule Recv do
    @moduledoc false
    @enforce_keys [:label]
    defstruct [:label, types: [], next: %ST.Terminate{}]

    @type session_type() :: ST.session_type()
    @type label() :: ST.label()
    @type types() :: ST.types()
    @type t :: %__MODULE__{label: label(), types: types(), next: session_type()}
  end

  defmodule Choice do
    @moduledoc false
    @enforce_keys [:choices]
    defstruct [:choices]

    @type session_type() :: ST.session_type()
    @type label() :: ST.label()
    @type t :: %__MODULE__{choices: %{label() => session_type()}}
  end

  defmodule Branch do
    @moduledoc false
    @enforce_keys [:branches]
    defstruct [:branches]

    @type session_type() :: ST.session_type()
    @type label() :: ST.label()
    @type t :: %__MODULE__{branches: %{label() => session_type()}}
  end

  defmodule Recurse do
    @moduledoc false
    @enforce_keys [:label, :body]
    defstruct [:label, :body, outer_recurse: false]

    @type session_type() :: ST.session_type()
    @type label() :: ST.label()
    @type t :: %__MODULE__{label: label(), body: session_type(), outer_recurse: boolean()}
  end

  defmodule Call_Recurse do
    @moduledoc false
    @enforce_keys [:label]
    defstruct [:label]

    @type session_type() :: ST.session_type()
    @type label() :: ST.label()
    @type t :: %__MODULE__{label: label()}
  end

  defmodule Function do
    @moduledoc false

    @enforce_keys [:name]
    defstruct name: nil,
              arity: 0,
              def_p: :def,
              # List of bodies from different (pattern-matching) cases
              bodies: [],
              # Function meta
              meta: [],
              # Number of different patter-matching cases
              cases: 0,
              # List of function cases meta
              case_metas: [],
              # List (of list) of parameters
              parameters: [],
              # List (of list) of guards
              guards: [],
              types_known?: false,
              return_type: :any,
              param_types: []

    # Structure of functions in Beam debug_info
    # {{name, arity}, :def_or_p, meta, [{meta, parameters, guards, body}, case2, ...]}

    @type label() :: ST.label()
    @type t :: %__MODULE__{
            name: label(),
            arity: non_neg_integer(),
            def_p: :def | :defp,
            bodies: [any()],
            meta: [any()],
            case_metas: [any()],
            parameters: [any()],
            guards: [any()],
            types_known?: boolean(),
            return_type: any(),
            param_types: [any()]
          }
  end

  defmodule Module do
    @moduledoc false
    defstruct functions: [],
              function_st_context: %{},
              module_name: :"",
              file: "",
              relative_file: "",
              line: 1

    @type session_type() :: ST.session_type()
    @type label() :: ST.label()
    @type ast() :: ST.ast()
    @type func_name_arity() :: ST.name_arity()
    @type t :: %__MODULE__{
            functions: [ST.Function.t()],
            function_st_context: %{func_name_arity() => session_type()},
            module_name: atom(),
            file: String.t(),
            relative_file: String.t(),
            line: integer()
          }
  end

  @doc """
  Converts s session type to a string. To do the opposite, use `string_to_st/1`.

  ## Examples
      iex> s = "rec x.(&{?Hello(number), ?Retry().X})"
      ...> st = ST.string_to_st(s)
      ...> ST.st_to_string(st)
      "rec x.(&{?Hello(number), ?Retry().X})"
  """
  @spec st_to_string(session_type()) :: String.t()
  def st_to_string(%ST.Terminate{}), do: "end"

  def st_to_string(session_type) do
    st_to_string_internal(session_type)
  end

  defp st_to_string_internal(%ST.Send{label: label, types: types, next: next}) do
    types_string = Enum.map(types, &ElixirSessions.TypeOperations.string/1) |> Enum.join(", ")

    following_st = st_to_string_internal(next)

    if following_st != "" do
      "!#{label}(#{types_string}).#{following_st}"
    else
      "!#{label}(#{types_string})"
    end
  end

  defp st_to_string_internal(%ST.Recv{label: label, types: types, next: next}) do
    types_string = Enum.map(types, &ElixirSessions.TypeOperations.string/1) |> Enum.join(", ")

    following_st = st_to_string_internal(next)

    if following_st != "" do
      "?#{label}(#{types_string}).#{following_st}"
    else
      "?#{label}(#{types_string})"
    end
  end

  defp st_to_string_internal(%ST.Choice{choices: choices}) do
    v =
      Enum.map(choices, fn {_label, x} -> st_to_string_internal(x) end)
      |> Enum.join(", ")

    "+{#{v}}"
  end

  defp st_to_string_internal(%ST.Branch{branches: branches}) do
    v =
      Enum.map(branches, fn {_label, x} -> st_to_string_internal(x) end)
      |> Enum.join(", ")

    "&{#{v}}"
  end

  defp st_to_string_internal(%ST.Recurse{label: label, body: body, outer_recurse: outer_recurse}) do
    if outer_recurse do
      "#{label} = #{st_to_string_internal(body)}"
    else
      "rec #{label}.(#{st_to_string_internal(body)})"
    end
  end

  defp st_to_string_internal(%ST.Call_Recurse{label: label}) do
    "#{label}"
  end

  defp st_to_string_internal(%ST.Terminate{}) do
    ""
  end

  @doc """
  Converts the current session type to a string. E.g. ?Hello().!hi() would return ?Hello() only.

  ## Examples
      iex> s = "?Hello(number).?Retry()"
      ...> st = ST.string_to_st(s)
      ...> ST.st_to_string_current(st)
      "?Hello(number)"
  """
  @spec st_to_string_current(session_type()) :: String.t()
  def st_to_string_current(%ST.Terminate{}), do: "end"

  def st_to_string_current(session_type) do
    st_to_string_current_internal(session_type)
  end

  @spec st_to_string_current_internal(session_type()) :: String.t()
  defp st_to_string_current_internal(session_type)

  defp st_to_string_current_internal(%ST.Send{label: label, types: types}) do
    types_string = Enum.map(types, &ElixirSessions.TypeOperations.string/1) |> Enum.join(", ")

    "!#{label}(#{types_string})"
  end

  defp st_to_string_current_internal(%ST.Recv{label: label, types: types}) do
    types_string = Enum.map(types, &ElixirSessions.TypeOperations.string/1) |> Enum.join(", ")

    "?#{label}(#{types_string})"
  end

  defp st_to_string_current_internal(%ST.Choice{choices: choices}) do
    v =
      Enum.map(choices, fn {_, x} -> st_to_string_current_internal(x) end)
      |> Enum.map(fn x -> x <> "..." end)
      |> Enum.join(", ")

    "+{#{v}}"
  end

  defp st_to_string_current_internal(%ST.Branch{branches: branches}) do
    v =
      Enum.map(branches, fn {_, x} -> st_to_string_current_internal(x) end)
      |> Enum.map(fn x -> x <> "..." end)
      |> Enum.join(", ")

    "&{#{v}}"
  end

  defp st_to_string_current_internal(%ST.Recurse{label: label, body: body, outer_recurse: outer_recurse}) do
    if outer_recurse do
      "#{label} = #{st_to_string_current_internal(body)}"
    else
      "rec #{label}.(#{st_to_string_current_internal(body)})"
    end
  end

  defp st_to_string_current_internal(%ST.Call_Recurse{label: label}) do
    "#{label}"
  end

  defp st_to_string_current_internal(%ST.Terminate{}) do
    ""
  end

  @doc """
  Converts a string to a session type. To do the opposite, use `st_to_string/1`.

  ## Examples
      iex> s = "?Ping().!Pong()"
      ...> ST.string_to_st(s)
      %ST.Recv{
        label: :Ping,
        next: %ST.Send{label: :Pong, next: %ST.Terminate{}, types: []},
        types: []
      }
  """
  @spec string_to_st(String.t()) :: session_type()
  def string_to_st(st_string) do
    ElixirSessions.Parser.parse(st_string)
  end

  @doc """
  Spawns two actors, exchanges their pids and then calls the server/client functions

  `server_fn` and `client_fn` need to accept a `pid` as their first parameter.
  """
  @spec spawn(fun, maybe_improper_list, fun, maybe_improper_list) :: [{:client, pid} | {:server, pid}]
  def spawn(server_fn, server_args, client_fn, client_args)
      when is_function(server_fn) and is_list(server_args) and
             is_function(client_fn) and is_list(client_args) do
    server =
      spawn(fn ->
        receive do
          {:pid, pid} ->
            send(pid, {:pid, self()})
            apply(server_fn, [pid | server_args])
        end
      end)

    client =
      spawn(fn ->
        send(server, {:pid, self()})

        receive do
          {:pid, pid} ->
            client_fn.(pid)
            apply(client_fn, [pid | client_args])
        end
      end)

    [server: server, client: client]
  end

  @doc """
  Returns the dual of the fiven session type.

  ### Changes that are made:
  -  Receive <-> Send
  -  Branch  <-> Choice

  ## Examples
      iex> st_string = "!Ping(Number).?Pong(String)"
      ...> st = ElixirSessions.Parser.parse(st_string)
      ...> st_dual = ST.dual(st)
      ...> ST.st_to_string(st_dual)
      "?Ping(number).!Pong(string)"

  """
  @spec dual(session_type()) :: session_type()
  def dual(session_type)

  def dual(%ST.Send{label: label, types: types, next: next}) do
    %ST.Recv{label: label, types: types, next: dual(next)}
  end

  def dual(%ST.Recv{label: label, types: types, next: next}) do
    %ST.Send{label: label, types: types, next: dual(next)}
  end

  def dual(%ST.Choice{choices: choices}) do
    %ST.Branch{
      branches:
        Enum.map(choices, fn {label, choice} -> {label, dual(choice)} end)
        |> Enum.into(%{})
    }
  end

  def dual(%ST.Branch{branches: branches}) do
    %ST.Choice{
      choices:
        Enum.map(branches, fn {label, branches} -> {label, dual(branches)} end)
        |> Enum.into(%{})
    }
  end

  def dual(%ST.Recurse{label: label, body: body}) do
    %ST.Recurse{label: label, body: dual(body)}
  end

  def dual(%ST.Call_Recurse{} = st) do
    st
  end

  def dual(%ST.Terminate{} = st) do
    st
  end

  # Checks if the two given session types are dual of each other
  @spec dual?(session_type(), session_type()) :: boolean()
  def dual?(session_type1, session_type2)

  def dual?(
        %ST.Send{label: label, types: types, next: next1},
        %ST.Recv{label: label, types: types, next: next2}
      ) do
    dual?(next1, next2)
  end

  def dual?(%ST.Recv{} = a, %ST.Send{} = b) do
    dual?(b, a)
  end

  def dual?(%ST.Choice{choices: choices}, %ST.Branch{branches: branches}) do
    # %ST.Branch{branches: Enum.map(choices, fn choice -> dual?(choice) end)}
    labels_choices = Map.keys(choices) |> MapSet.new()
    labels_branches = Map.keys(branches) |> MapSet.new()

    # Check that all labels from the 'choice' are included in the 'branches'.
    check = MapSet.subset?(labels_choices, labels_branches)

    if check do
      Enum.map(labels_choices, fn label -> dual?(choices[label], branches[label]) end)
      # Finds in there are any 'false'
      |> Enum.find(true, fn x -> !x end)
    else
      false
    end
  end

  def dual?(%ST.Branch{} = a, %ST.Choice{} = b) do
    dual?(b, a)
  end

  def dual?(%ST.Choice{choices: choices}, %ST.Recv{} = recv) do
    if map_size(choices) > 1 do
      false
    else
      lhs = Map.values(choices)
      dual?(hd(lhs), recv)
    end
  end

  def dual?(%ST.Recv{} = a, %ST.Choice{} = b) do
    dual?(b, a)
  end

  def dual?(%ST.Branch{branches: branches}, %ST.Send{label: label} = send) do
    dual?(branches[label], send)
  end

  def dual?(%ST.Send{} = a, %ST.Branch{} = b) do
    dual?(b, a)
  end

  def dual?(%ST.Recurse{label: label, body: body1}, %ST.Recurse{label: label, body: body2}) do
    dual?(body1, body2)
  end

  def dual?(%ST.Call_Recurse{}, %ST.Call_Recurse{}) do
    true
  end

  def dual?(%ST.Terminate{}, %ST.Terminate{}) do
    true
  end

  def dual?(_, _) do
    false
  end

  # Equality, takes into consideration that recursions with a different variable name are equal
  # Pattern matching with ST.session_type()
  # ! = +{l} and & = &{l}
  @spec equal?(session_type(), session_type()) :: boolean()
  def equal?(session_type1, session_type2) do
    equal?(session_type1, session_type2, %{})
  end

  @spec equal?(session_type(), session_type(), %{}) :: boolean()
  defp equal?(session_type, session_type, recurse_var_mapping)

  defp equal?(
         %ST.Send{label: label, types: types, next: next1},
         %ST.Send{label: label, types: types, next: next2},
         recurse_var_mapping
       ) do
    equal?(next1, next2, recurse_var_mapping)
  end

  defp equal?(
         %ST.Recv{label: label, types: types, next: next1},
         %ST.Recv{label: label, types: types, next: next2},
         recurse_var_mapping
       ) do
    equal?(next1, next2, recurse_var_mapping)
  end

  defp equal?(%ST.Choice{choices: choices1}, %ST.Choice{choices: choices2}, recurse_var_mapping) do
    # Sorting is done (automatically) by the map

    Enum.zip(Map.values(choices1), Map.values(choices2))
    |> Enum.reduce(
      true,
      fn
        {choice1, choice2}, acc ->
          acc and equal?(choice1, choice2, recurse_var_mapping)
      end
    )
  end

  defp equal?(
         %ST.Branch{branches: branches1},
         %ST.Branch{branches: branches2},
         recurse_var_mapping
       ) do
    # Sorting is done (automatically) by the map

    Enum.zip(Map.values(branches1), Map.values(branches2))
    |> Enum.reduce(
      true,
      fn
        {branche1, branche2}, acc ->
          acc and equal?(branche1, branche2, recurse_var_mapping)
      end
    )
  end

  defp equal?(
         %ST.Recurse{label: label1, body: body1},
         %ST.Recurse{label: label2, body: body2},
         recurse_var_mapping
       ) do
    equal?(body1, body2, Map.put(recurse_var_mapping, label1, label2))
  end

  defp equal?(
         %ST.Call_Recurse{label: label1},
         %ST.Call_Recurse{label: label2},
         recurse_var_mapping
       ) do
    case Map.fetch(recurse_var_mapping, label1) do
      {:ok, ^label2} ->
        true

      _ ->
        # In case of free var
        label1 == label2
    end
  end

  defp equal?(%ST.Terminate{}, %ST.Terminate{}, _recurse_var_mapping) do
    true
  end

  defp equal?(_, _, _) do
    false
  end

  @doc """
  Takes a session type (starting with a recursion, e.g. rec X.(...)) and outputs a single unfold of X.


  ## Examples
          iex> st = "rec X.(!A().X)"
          ...> session_type = ST.string_to_st(st)
          ...> unfolded = ST.unfold(session_type)
          ...> ST.st_to_string(unfolded)
          "!A().rec X.(!A().X)"
  """
  @spec unfold(session_type()) :: session_type()
  def unfold(%ST.Recurse{label: label, body: body} = rec) do
    unfold(body, label, rec)
  end

  def unfold(x) do
    x
  end

  @spec unfold(session_type(), label(), ST.Recurse.t()) :: session_type()
  defp unfold(%ST.Send{label: label_send, types: types, next: next}, label, rec) do
    %ST.Send{label: label_send, types: types, next: unfold(next, label, rec)}
  end

  defp unfold(%ST.Recv{label: label_recv, types: types, next: next}, label, rec) do
    %ST.Recv{label: label_recv, types: types, next: unfold(next, label, rec)}
  end

  defp unfold(%ST.Choice{choices: choices}, label, rec) do
    %ST.Choice{
      choices:
        Enum.map(choices, fn {l, choice} -> {l, unfold(choice, label, rec)} end)
        |> Enum.into(%{})
    }
  end

  defp unfold(%ST.Branch{branches: branches}, label, rec) do
    %ST.Branch{
      branches:
        Enum.map(branches, fn {l, branch} -> {l, unfold(branch, label, rec)} end)
        |> Enum.into(%{})
    }
  end

  defp unfold(%ST.Recurse{label: diff_label, body: body}, label, rec) do
    %ST.Recurse{label: diff_label, body: unfold(body, label, rec)}
  end

  defp unfold(%ST.Call_Recurse{label: label}, label, rec) do
    rec
  end

  defp unfold(%ST.Call_Recurse{label: diff_label}, _label, _rec) do
    %ST.Call_Recurse{label: diff_label}
  end

  defp unfold(%ST.Terminate{} = st, _label, _rec) do
    st
  end
end
