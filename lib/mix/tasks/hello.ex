defmodule Mix.Tasks.Hello do
  use Mix.Task

  @shortdoc "Simply calls the ElixirSessions.Code.run/0 function."
  def run(_) do
    ElixirSessions.Code.run()
  end
end
