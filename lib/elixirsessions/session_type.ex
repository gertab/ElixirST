defmodule ST do
  @moduledoc """
  ST = SessionType

  Session type can tke the form of the following structs:

  ```%Recv{label, types, next}```

  ```%Send{label, types, next}```

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
          %ST.Send{}
          | %ST.Recv{}
          | %ST.Choice{}
          | %ST.Branch{}
          | %ST.Recurse{}
          | %ST.Call_Recurse{}
          | %ST.Terminate{}

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
    @type t :: %__MODULE__{label: atom, types: [atom()], next: session_type()}
  end

  defmodule Recv do
    @moduledoc false
    @enforce_keys [:label]
    defstruct [:label, types: [], next: %ST.Terminate{}]

    @type session_type() :: ST.session_type()
    @type t :: %__MODULE__{label: atom, types: [atom()], next: session_type()}
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
    @type t :: %__MODULE__{label: atom(), body: session_type()}
  end

  defmodule Call_Recurse do
    @moduledoc false
    @enforce_keys [:label]
    defstruct [:label]

    @type session_type() :: ST.session_type()
    @type t :: %__MODULE__{label: atom()}
  end

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
end
