defmodule ElixirSessionsTest do
  use ExUnit.Case
  doctest ElixirSessions

  test "greets the world" do
    assert ElixirSessions.hello() == :world
  end
end
