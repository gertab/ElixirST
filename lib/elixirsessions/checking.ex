defmodule ElixirSessions.Checking do
  defmacro __using__(_) do
    quote do
      # import Kernel, except: [@: 1]
      import ElixirSessions.Checking

      Module.register_attribute(__MODULE__, :session, accumulate: true)

      # @before_compile ElixirSessions.Checking
      @on_definition ElixirSessions.Checking

      # @session %{}
      # @session nil
      # import ElixirSessions.Checking
    end
  end

  # defmacro __before_compile__(_env) do
    # definitions = Module.definitions_in(env.module)
    # contracts = Module.get_attribute(env.module, :session)

    # IO.inspect(definitions)
    # IO.inspect(contracts)

    # IO.inspect(__MODULE__.__info__)
  # end

  def __on_definition__(env, _kind, fun, _args, _guards, body) do

    if sessions = Module.get_attribute(env.module, :session) do
      # sessions = Module.get_attribute(env.module, :session)
      # sessions = Map.put(sessions, {kind, fun, length(args)}, session)
      # Module.put_attribute(env.module, :session, sessions)
      # Module.put_attribute(env.module, :session, nil)

      if length(sessions) > 0 do
        [session | _ ] = sessions
        IO.inspect(session)
        IO.inspect(fun)
      end
    end
    IO.inspect(body)
    :ok
  end

  # defmacro __before_compile__(env) do
  #   decorators = Module.get_attribute(env.module, :session)
  #   for {{kind, fun, arity}, decorator} <- decorators do
  #     args = generate_args(arity)
  #     body = decorator.decorate(kind, fun, args)
  #     quote do
  #       defoverridable [{unquote(fun), unquote(arity)}]

  #       Kernel.unquote(kind)(unquote(fun)(unquote_splicing(args))) do
  #         unquote(body)
  #       end
  #     end
  #   end
  # end
  # defp generate_args(0), do: []
  # defp generate_args(n), do: for(i <- 1..n, do: Macro.var(:"var#{i}", __MODULE__))


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
