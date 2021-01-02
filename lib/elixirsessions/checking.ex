defmodule ElixirSessions.Checking do
  defmacro __using__(_) do
    quote do
      import ElixirSessions.Checking

      Module.register_attribute(__MODULE__, :sessions, accumulate: true)

      @before_compile ElixirSessions.Checking
      # import ElixirSessions.Checking
    end
  end

  defmacro __before_compile__(env) do
    definitions = Module.definitions_in(env.module)
    contracts = Module.get_attribute(env.module, :sessions)

    IO.inspect(definitions)
    IO.inspect(contracts)
  end
end
