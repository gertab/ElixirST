defmodule ST do
  @moduledoc """
  ST = SessionType

  This module allows the following operations: [parser](#module-parser), [generator](#module-generator) and [duality](#module-duality).

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

      iex> s = "!Hello(Integer)"
      ...> ST.string_to_st(s)
      %ST.Send{label: :Hello, next: %ST.Terminate{}, types: [:integer]}

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

  # ### Generator
  # Given a session type, `generate_quoted/1` generates the quoted Elixir code (or AST) automatically.

  # For example, setting the session type to `!hello(number).?hello_ret(number)`, `generate_to_string/1` automatically synthesizes the
  # equivalent Elixir code, as shown below.

  # #### Synthesizer usage
  # s = "!hello(number).?hello_ret(number)"
  # st = ST.string_to_st(s)
  # ST.generate_to_string(st)

  # #### Synthesizer output
  # def func() do
  #   send(self(), {:hello})
  #   receive do
  #     {:hello_ret, var1} when is_number(var1) ->
  #       :ok
  #   end
  # end

  ### Duality

  Given a session type, `dual/1` returns its dual session type.
  For example, the dual of `!Hello()` becomes `?Hello()`. The dual of `&{?Option1(), ?Option2()}` becomes `+{!Option1(), !Option2()}`.

  #### Usage example
      iex> st_string = "!Ping(Integer).?Pong(String)"
      ...> st = ST.string_to_st(st_string)
      ...> st_dual = ST.dual(st)
      %ST.Recv{
        label: :Ping,
        next: %ST.Send{label: :Pong, next: %ST.Terminate{}, types: [:string]},
        types: [:integer]
      }
      ...> ST.st_to_string(st_dual)
      "?Ping(integer).!Pong(string)"

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
    defstruct [:label, :body]

    @type session_type() :: ST.session_type()
    @type label() :: ST.label()
    @type t :: %__MODULE__{label: label(), body: session_type()}
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
    @type func_name_arity() :: {label(), non_neg_integer()}
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
  Convert session types from Erlang records to Elixir Structs.
  Throws error in case of branches/choices with same labels, or
  if the types are not valid.

  ## Example
      iex> st_erlang = {:recv, :Ping, [], {:send, :Pong, [], {:terminate}}}
      ...> ST.convert_to_structs(st_erlang)
      %ST.Recv{
        label: :Ping,
        next: %ST.Send{label: :Pong, next: %ST.Terminate{}, types: []},
        types: []
      }
  """
  @spec convert_to_structs(session_type_tuple()) :: session_type()
  def convert_to_structs(session_type_tuple) do
    ElixirSessions.Operations.convert_to_structs(session_type_tuple, [])
  end

  @doc """
  Converts s session type to a string. To do the opposite, use `string_to_st/1`.

  ## Examples
      iex> s = "rec x.(&{?Hello(number), ?Retry().X})"
      ...> st = ST.string_to_st(s)
      ...> ST.st_to_string(st)
      "rec x.(&{?Hello(number), ?Retry().X})"
  """
  # todo should you include '.end'?
  @spec st_to_string(session_type()) :: String.t()
  def st_to_string(session_type) do
    ElixirSessions.Operations.st_to_string(session_type)
  end

  @doc """
  Converts the current session type to a string.

  ## Examples
      iex> s = "?Hello(number).?Retry()"
      ...> st = ST.string_to_st(s)
      ...> ST.st_to_string_current(st)
      "?Hello(number)"
  """
  @spec st_to_string_current(session_type()) :: String.t()
  def st_to_string_current(session_type) do
    ElixirSessions.Operations.st_to_string_current(session_type)
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

  @spec string_to_st_no_validations(String.t()) :: session_type()
  def string_to_st_no_validations(st_string) do
    ElixirSessions.Parser.parse_no_validations(st_string)
  end

  @doc """
  Performs validations on the session type.
  Throws an error if the structure of the session type is incorrect or there are any illegal operations.

  Ensures the following:
    1) All branches have a `receive` statement as the first statement.
    2) All choices have a `send` statement as the first statement.
    3) todo: check if similar checks are needed for `rec`
  """
  # todo examples
  # todo (confirm before implement) branches need more than one branch
  # todo confirm if sorted
  # todo maybe defp (no external use?)
  @spec validate!(String.t()) :: :ok
  def validate!(session_type_string) do
    _ = ST.string_to_st(session_type_string)
    :ok
  end

  @spec validate(String.t()) :: :ok | {:error, any()}
  def validate(session_type_string) do
    try do
      validate!(session_type_string)
    catch
      x -> {:error, x}
    end
  end

  @doc """
  Returns the dual of the fiven session type.

  ### Changes that are made:
  -  Receive <-> Send
  -  Branch  <-> Choice

  ## Examples
      iex> st_string = "!Ping(Integer).?Pong(String)"
      ...> st = ElixirSessions.Parser.parse(st_string)
      ...> st_dual = ST.dual(st)
      %ST.Recv{
        label: :Ping,
        next: %ST.Send{label: :Pong, next: %ST.Terminate{}, types: [:string]},
        types: [:integer]
      }
      ...> ST.st_to_string(st_dual)
      "?Ping(integer).!Pong(string)"

  """
  @spec dual(session_type()) :: session_type()
  def dual(session_type) do
    ElixirSessions.Operations.dual(session_type)
  end

  @spec dual?(session_type(), session_type()) :: boolean()
  def dual?(session_type1, session_type2) do
    ElixirSessions.Operations.dual?(session_type1, session_type2)
  end

  # Equality, takes into consideration that recursions with a different variable name are equal
  @spec equal?(session_type(), session_type()) :: boolean()
  def equal?(session_type1, session_type2) do
    ElixirSessions.Operations.equal?(session_type1, session_type2, %{})
  end

  # Subtype
  @spec subtype?(session_type(), session_type()) :: boolean()
  def subtype?(session_type1, session_type2) do
    ElixirSessions.Operations.subtype?(session_type1, session_type2)
  end

  @doc """
  Takes a session type (starting with a recursion, e.g. rec X.(...)) and outputs a single unfold of X.


  ## Examples
          iex> st = "rec X.(!A().X)"
          ...> session_type = ST.string_to_st(st)
          ...> unfolded = ST.unfold_current(session_type)
          ...> ST.st_to_string(unfolded)
          "!A().rec X.(!A().X)"
  """
  @spec unfold_current(session_type()) :: session_type()
  def unfold_current(%ST.Recurse{label: label, body: body} = rec) do
    ElixirSessions.Operations.unfold_current_inside(body, label, rec)
  end

  def unfold_current(x) do
    x
  end

  @doc """
  Given !A().X, it will unfold the (unbound) recursive variable X. The value of X should be found in `recurse_var_map`.
  Will not unfold any bound recursive variables.

  ## Examples
          iex> st = "!A().X"
          ...> session_type = ST.string_to_st(st)
          ...> recurse_var_map = %{:X => ST.string_to_st("rec X.(!B().X)")}
          ...> unfolded_session_type = ST.unfold_unknown(session_type, recurse_var_map)
          ...> ST.st_to_string(unfolded_session_type)
          "!A().rec X.(!B().X)"
  """
  @spec unfold_unknown(session_type(), %{}) :: session_type()
  def unfold_unknown(session_type, recurse_var_map) do
    modified = ElixirSessions.Operations.unfold_unknown_inside(session_type, recurse_var_map, [])

    if ST.equal?(session_type, modified) do
      session_type
    else
      # Unfolds for unfolded variable may be needed
      # E.g. !A().X becomes !A().!B().Y which needs to end up as !A().!B().!C()
      ElixirSessions.Operations.unfold_unknown_inside(modified, recurse_var_map, [])
    end
  end

  # @doc """
  #   Given a session type, generates the corresponding Elixir code, formatted as a string.

  #   E.g.
  #         st = ElixirSessions.Parser.parse("!Ping(Integer).?Pong(String)")
  #         ElixirSessions.Generator.generate_to_string(st)
  #         def func() do
  #           send(self(), {:Ping})
  #           receive do
  #             {:Pong, var1} when is_binary(var1) ->
  #               :ok
  #             end
  #           end
  #         end
  # """
  # # @spec generate_to_string(session_type()) :: String.t()
  # def generate_to_string(session_type) do
  #   ElixirSessions.Generator.generate_to_string(session_type)
  # end

  # @doc """
  # Given a session type, computes the equivalent (skeleton) code in Elixir. The output is in AST/quoted format.

  # ## Examples
  #     iex> session_type = %ST.Send{label: :hello, types: [], next: %ST.Terminate{}}
  #     ...> ST.generate_quoted(session_type)
  #     {:def, [context: ElixirSessions.Generator, import: Kernel],
  #     [
  #       {:func, [context: ElixirSessions.Generator], []},
  #       [
  #         do:
  #           {:send, [context: ElixirSessions.Generator, import: Kernel],
  #             [{:self, [context: ElixirSessions.Generator, import: Kernel], []}, {:{}, [], [:hello]}]}
  #       ]
  #     ]}
  # """
  # @spec generate_quoted(session_type()) :: ast()
  # def generate_quoted(session_type) do
  #   ElixirSessions.Generator.generate_quoted(session_type)
  # end

  @spec session_subtraction!(session_type(), session_type()) :: session_type()
  def session_subtraction!(session_type, session_type_internal_function) do
    ElixirSessions.Operations.session_subtraction!(
      session_type,
      %{},
      session_type_internal_function,
      %{}
    )
  end

  @spec session_subtraction(session_type(), session_type()) ::
          {:ok, session_type()} | {:error, any()}
  def session_subtraction(session_type, session_type_internal_function) do
    ElixirSessions.Operations.session_subtraction(session_type, session_type_internal_function)
  end

  @spec session_tail_subtraction(session_type(), session_type()) ::
          {:ok, session_type()} | {:error, any()}
  def session_tail_subtraction(session_type, session_type_internal_function) do
    ElixirSessions.Operations.session_tail_subtraction(
      session_type,
      session_type_internal_function
    )
  end
end
