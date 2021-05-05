defmodule ElixirSessions.TypeOperations do

  @spec types :: [
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
  def types do
    [
      :any,
      :atom,
      :binary,
      :bitstring,
      :boolean,
      :exception,
      :float,
      :function,
      :integer,
      :list,
      :map,
      nil,
      :number,
      :pid,
      :port,
      :reference,
      :struct,
      :tuple,
      :string
    ]
  end

  def get_type do
nil
  end
end
