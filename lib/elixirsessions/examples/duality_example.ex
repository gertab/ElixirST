defmodule Ss do
  use ElixirSessions.Checking

  @session "!hello().!hello().!hello2()"
  def aaa(pid) do
    send(pid, {:hello})
    send(pid, {:hello})
    send(pid, {:hello2})
  end

  @dual &ElixirSessions.PingPong.aaa/1
  def bbb(_pid) do
    receive do
      {:hello} -> :ok
    end
    receive do
      {:hello} -> :ok
    end
    receive do
      {:hello2} -> :ok
    end
  end
end
