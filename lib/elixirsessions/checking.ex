defmodule ElixirSessions.Checking do
  require Logger

  @moduledoc false
  # @moduledoc """
  # This module is the starting point of ElixirSessions. It parses the `@session` attribute and starts the AST code comparison with the session type.
  # """

  defmacro __using__(_) do
    quote do
      import ElixirSessions.Checking

      Module.register_attribute(__MODULE__, :session, accumulate: true)
      Module.register_attribute(__MODULE__, :infer_session, accumulate: true)
      # todo add @infer_session true

      @on_definition ElixirSessions.Checking
      # todo checkout @before_compile, @after_compile [Elixir fires the before compile hook after expansion but before compilation.]
      # __after_compile__/2 runs after elixir has compiled the AST into BEAM bytecode

      IO.puts("ElixirSession started in #{IO.inspect(__MODULE__)}")
    end
  end

  # Definition of a function head, therefore do nothing
  def __on_definition__(_env, _access, _name, _args, _guards, nil), do: nil
  def __on_definition__(_env, _access, _name, _args, _guards, []), do: nil

  def __on_definition__(env, _access, name, args, _guards, body) do
    if sessions = Module.get_attribute(env.module, :session) do
      if length(sessions) > 0 do
        session = hd(sessions)
        IO.inspect(sessions)
        # Module.get_attribute(env.module, :session)
        try do
          session_type = ST.string_to_st(session)

            ElixirSessions.SessionTypechecking.session_typecheck(name, length(args), body[:do], session_type)

        catch
          x ->
            throw(x)
            # _ = Logger.error("Leex/Yecc error #{inspect(x)}")
        end



        # case s do
        #   {:error, {line, _, message}} ->
        #     _ = Logger.error("Session type parsing error on line #{line}: #{inspect(message)}")
        #     :ok

        #   {:error, x} ->
        #     _ = Logger.error("Session type parsing error: #{inspect(x)}")
        #     :ok

        #   session_type when is_list(session_type) ->
        #     ElixirSessions.SessionTypechecking.session_typecheck(name, length(args), body[:do], session_type)
        #     :ok

        #   x ->
        #     _ = Logger.error("Leex/Yecc error #{inspect(x)}")
        #     :ok
        # end

        _inferred_session_type = ElixirSessions.Inference.infer_session_type(name, body[:do])
        IO.puts("\nSesssion type for #{name} type checks successfully.")
        # IO.puts("\nInferred sesssion type for: #{name}")
        # IO.inspect(inferred_session_type)
        :okkk
      end
    end


    if sessions = Module.get_attribute(env.module, :infer_session) do
      if length(sessions) > 0 do
        # session = hd(sessions)
        try do
          session_type = ElixirSessions.Inference.infer_session_type(name, body[:do])

          result = ST.st_to_string(session_type)
          throw(result)
        catch
          x ->
            throw(x)
        end

        inferred_session_type = ElixirSessions.Inference.infer_session_type(name, body[:do])
        IO.puts("\nInferred sesssion type for: #{name}")
        IO.inspect(inferred_session_type)
      end
    end
    :ok
  end
end
