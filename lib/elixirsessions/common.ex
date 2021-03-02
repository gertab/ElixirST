defmodule ST do
  @moduledoc """
  ST = SessionType

  Session type can tke the form of the following:

  ```%Recv{label, types, next}```

  ```%Send{label, types, next}```

  ```%Choice{choices}```

  ```%Branch{branches}```

  ```%Recurse{label, body}```

  ```%Call_Recurse{label}```

  ```%Terminate{}```
  """

  defmodule Send do
    @moduledoc false
    defstruct [:label, :types, :next]
    # todo add specs
  end

  defmodule Recv do
    @moduledoc false
    defstruct [:label, :types, :next]
    # todo add specs
  end

  defmodule Choice do
    @moduledoc false
    defstruct [:choices]
    # todo add specs
  end

  defmodule Branch do
    @moduledoc false
    defstruct [:branches]
    # todo add specs
  end

  defmodule Recurse do
    @moduledoc false
    defstruct [:label, :body]
    # todo add specs
  end

  defmodule Call_Recurse do
    @moduledoc false
    defstruct [:label]
    # todo add specs
  end

  defmodule Terminate do
    @moduledoc false
    defstruct []
  end

  def convert_to_structs(nil) do
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
    %ST.Recurse{label: label}
  end
end

defmodule ElixirSessions.Common do
  require ST

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

  # todo change to defstruct

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
end
