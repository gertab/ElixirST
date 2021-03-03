defmodule ST do
  @moduledoc """
  ST = SessionType

  Session type can tke the form of the following structs:

  ```%Send{label, types, next}```

  ```%Recv{label, types, next}```

  ```%Choice{choices}```

  ```%Branch{branches}```

  ```%Recurse{label, body}```

  ```%Call_Recurse{label}```

  ```%Terminate{}```
  """

  @typedoc """
  A session type list of session operations.
  """
  @type session_type() ::
          %ST.Send{label: label(), types: types(), next: session_type()}
          | %ST.Recv{label: label(), types: types(), next: session_type()}
          | %ST.Choice{choices: [session_type()]}
          | %ST.Branch{branches: [session_type()]}
          | %ST.Recurse{label: label(), body: session_type()}
          | %ST.Call_Recurse{label: label()}
          | %ST.Terminate{}

  @typedoc """
  Label for sending/receiving statements. Should be of the form of an `atom`.
  """
  @type label() :: atom()

  @typedoc """
  Native types accepted in the send/receive statements.
  E.g. !Ping(integer)
  """
  @type types() :: [:atom|:binary|:bitstring|:boolean|:exception|:float|:function|:integer|:list|:map|:nil|:number|:pid|:port|:reference|:struct|:tuple|:string]

  @typedoc """
  Abstract Syntax Tree (AST)
  """
  @type ast() :: Macro.t()

  @typedoc """
  Information related to a function body.
  """
  @type info() :: %{
          # recursion: boolean(),
          call_recursion: atom,
          function_name: atom,
          arity: arity
          # session_type: any
          # todo maybe add __module__
        }

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
    @type t :: %__MODULE__{choices: [session_type()]}
  end

  defmodule Branch do
    @moduledoc false
    @enforce_keys [:branches]
    defstruct [:branches]

    @type session_type() :: ST.session_type()
    @type t :: %__MODULE__{branches: [session_type()]}
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

  @typep session_type_tuple() ::
           {:send, atom, [atom], session_type_tuple()}
           | {:recv, atom, [atom], session_type_tuple()}
           | {:choice, [session_type_tuple]}
           | {:branch, [session_type_tuple]}
           | {:call_recurse, atom}
           | {:recurse, atom, session_type_tuple}
           | {:terminate}

  @doc """
  Convert session types from Erlang records to Elixir Structs.

  ## Example
      iex> st_erlang = {:recv, :Ping, [], {:send, :Pong, [], {:terminate}}}
      ...> ST.convert_to_structs(st_erlang)
      %ST.Recv{
        label: :Ping,
        next: %ST.Send{label: :Pong, next: %ST.Terminate{}, types: []},
        types: []
      }
  """
  @spec convert_to_structs(session_type_tuple) :: session_type()
  def convert_to_structs({:terminate}) do
    %ST.Terminate{}
  end

  def convert_to_structs({:send, label, types, next}) do
    %ST.Send{label: label, types: types, next: convert_to_structs(next)}
  end

  def convert_to_structs({:recv, label, types, next}) do
    %ST.Recv{label: label, types: types, next: convert_to_structs(next)}
  end

  def convert_to_structs({:choice, choices}) do
    %ST.Choice{choices: Enum.map(choices, fn x -> convert_to_structs(x) end)}
  end

  def convert_to_structs({:branch, branches}) do
    %ST.Branch{branches: Enum.map(branches, fn x -> convert_to_structs(x) end)}
  end

  def convert_to_structs({:recurse, label, body}) do
    %ST.Recurse{label: label, body: convert_to_structs(body)}
  end

  def convert_to_structs({:call_recurse, label}) do
    %ST.Call_Recurse{label: label}
  end

  @doc """
  Converts session type to a string.

  ## Examples
      iex> s = "rec x.(&{?Hello(number), ?Retry().X})"
      ...> st = ElixirSessions.Parser.parse(s)
      ...> ST.st_to_string(st)
      "rec x.(&{?Hello(number), ?Retry().X})"
  """
  # todo should you include '.end'?
  @spec st_to_string(session_type()) :: String.t()
  def st_to_string(session_type)

  def st_to_string(%ST.Send{label: label, types: types, next: next}) do
    types_string = types |> Enum.join(", ")

    following_st = st_to_string(next)

    if following_st != "" do
      "!#{label}(#{types_string}).#{following_st}"
    else
      "!#{label}(#{types_string})"
    end
  end

  def st_to_string(%ST.Recv{label: label, types: types, next: next}) do
    types_string = types |> Enum.join(", ")

    following_st = st_to_string(next)

    if following_st != "" do
      "?#{label}(#{types_string}).#{following_st}"
    else
      "?#{label}(#{types_string})"
    end
  end

  def st_to_string(%ST.Choice{choices: choices}) do
    v =
      Enum.map(choices, fn x -> st_to_string(x) end)
      |> Enum.join(", ")

    "+{#{v}}"
  end

  def st_to_string(%ST.Branch{branches: branches}) do
    v =
      Enum.map(branches, fn x -> st_to_string(x) end)
      |> Enum.join(", ")

    "&{#{v}}"
  end

  def st_to_string(%ST.Recurse{label: label, body: body}) do
    "rec #{label}.(#{st_to_string(body)})"
  end

  def st_to_string(%ST.Call_Recurse{label: label}) do
    "#{label}"
  end

  def st_to_string(%ST.Terminate{}) do
    ""
  end

  # def st_to_string(_) do
  #   throw("Parsing to string problem. Unknown input")
  #   ""
  # end

  @doc """
  Performs validations on the session type.

  Ensure the following:
    1) All branches have a `receive` statement as the first statement.
    2) All choices have a `send` statement as the first statement.
    3) todo: check if similar checks are needed for `rec`
  """
  # todo examples
  # todo (confirm before implement) branches need more than one branch
  @spec validate!(session_type()) :: boolean()
  def validate!(session_type)

  def validate!(%ST.Send{next: next}) do
    validate!(next)
  end

  def validate!(%ST.Recv{next: next}) do
    validate!(next)
  end

  def validate!(%ST.Choice{choices: choices}) do
    res =
      Enum.map(
        choices,
        fn
          %ST.Send{next: next} ->
            validate!(next)

          other ->
            throw(
              "Session type parsing validation error: Each branch needs a send as the first statement: #{
                ST.st_to_string(other)
              }."
            )

            false
        end
      )

    # AND operation
    if false in res do
      false
    else
      true
    end
  end

  def validate!(%ST.Branch{branches: branches}) do
    res =
      Enum.map(
        branches,
        fn
          %ST.Recv{next: next} ->
            validate!(next)

          other ->
            throw(
              "Session type parsing validation error: Each branch needs a receive as the first statement: #{
                ST.st_to_string(other)
              }."
            )

            false
        end
      )

    if false in res do
      false
    else
      true
    end
  end

  def validate!(%ST.Recurse{body: body}) do
    validate!(body)
  end

  def validate!(%ST.Call_Recurse{}) do
    true
  end

  def validate!(%ST.Terminate{}) do
    true
  end

  # def validate!(_) do
  #   throw("Validation problem. Unknown input")
  #   false
  # end
end

# Pattern matching with ST.session_type()
# def xyz(session_type)

# def xyz(%ST.Send{label: label, types: types, next: next}) do
# end

# def xyz(%ST.Recv{label: label, types: types, next: next}) do
# end

# def xyz(%ST.Choice{choices: choices}) do
# end

# def xyz(%ST.Branch{branches: branches}) do
# end

# def xyz(%ST.Recurse{label: label, body: body}) do
# end

# def xyz(%ST.Call_Recurse{label: label}) do
# end

# def xyz(%ST.Terminate{}) do
# end
