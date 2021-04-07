defmodule ElixirSessions.OneLiners, do: def abc(), do: :ok
defmodule ElixirSessions.Other do use ElixirSessions.Checking; @session "!hello()"; def abc() do send(self(), {:hello}) end; def abc2(b) do a = 2; a + b end; end
