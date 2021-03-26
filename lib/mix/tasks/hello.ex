defmodule Mix.Tasks.Hello do
  @dialyzer {:nowarn_function}
  use Mix.Task

  @moduledoc false
  # @shortdoc "Simply calls the ElixirSessions.Inference.run/0 function."
  def run(_) do
    ElixirSessions.Inference.run()
  end
end
