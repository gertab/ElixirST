# defmodule ElixirSessions.OneLiners, do: def abc(), do: :ok
# defmodule ElixirSessions.OneLiners2 do use ElixirSessions.Checking; @session "!hello()"; def abc() do send(self(), {:hello}) end; def abc2(b) do a = 2; a + b end; end
# defmodule ElixirSessions.OneLiners3 do def a(a) do case a do false -> :ok; true -> :notok end end; def b() do end end
