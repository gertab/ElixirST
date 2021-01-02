defmodule ElixirSessions.Checking do
  defmacro __using__(_) do
    quote do
      # import Kernel, except: [@: 1]
      # import ElixirSessions.Checking

      Module.register_attribute(__MODULE__, :session, accumulate: true)

      @before_compile ElixirSessions.Checking
      import ElixirSessions.Checking
    end
  end

  defmacro __before_compile__(env) do
    definitions = Module.definitions_in(env.module)
    contracts = Module.get_attribute(env.module, :session)

    IO.inspect(definitions)
    IO.inspect(contracts)
  end

  # defmacro @{:session, _, expr} do
  #   # defcontract(expr, __CALLER__.line)
  #   IO.puts(expr)
  # end

  # defmacro @other do
  #   quote do
  #     Kernel.@(unquote(other))
  #   end
  # end
end
