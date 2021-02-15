defmodule Mix.Tasks.Hello do
  use Mix.Task

  @shortdoc "Simply calls the ElixirSessions.Inference.run/0 function."
  def run(_) do
    ElixirSessions.Inference.run()
  end
end
