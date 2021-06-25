# defmodule Examples.OneLiners, do: def abc(), do: :ok
defmodule Examples.OneLiners2 do use ElixirSessions; @session "!hello()"; @spec abc() :: {atom}; def abc() do send(self(), {:hello}) end; end
# defmodule Examples.OneLiners3 do def a(a) do case a do false -> :ok; true -> :notok end end; def b() do end end
