defmodule ElixirSessions.Checking do
  require Logger

  @moduledoc false
  # @moduledoc """
  # This module is the starting point of ElixirSessions. It parses the `@session` attribute and starts the AST code comparison with the session type.
  # """

  defmacro __using__(_) do
    quote do
      import ElixirSessions.Checking

      Module.register_attribute(__MODULE__, :session_type_checking,
        accumulate: true,
        persist: true
      )

      Module.register_attribute(__MODULE__, :session, accumulate: true, persist: true)
      Module.register_attribute(__MODULE__, :infer_session, accumulate: true, persist: true)

      @on_definition ElixirSessions.Checking
      # todo checkout @before_compile, @after_compile [Elixir fires the before compile hook after expansion but before compilation.]
      # __after_compile__/2 runs after elixir has compiled the AST into BEAM bytecode
      @after_compile ElixirSessions.Checking

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
          {_session_type_label, session_type} = ST.string_to_st_incl_label(session)

          ElixirSessions.SessionTypechecking.session_typecheck(
            name,
            length(args),
            body[:do],
            session_type
          )
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

  def __after_compile__(_env, bytecode) do
    IO.puts("AFTER COMPILE")

    chunks =
      case :beam_lib.chunks(bytecode, [:debug_info]) do
        {:ok, {_mod, chunks}} -> chunks
        {:error, _, error} -> throw("Error: #{inspect(error)}")
      end

    dbgi_map =
      case chunks[:debug_info] do
        {:debug_info_v1, :elixir_erl, metadata} ->
          case metadata do
            {:elixir_v1, map, _} ->
              # Erlang extened AST available
              map

            {version, _, _} ->
              throw("Found version #{version} but expected :elixir_v1.")
          end

        x ->
          throw("Error: #{inspect(x)}")
      end

    # {:ok,{_,[{:abstract_code,{_, ac}}]}} = :beam_lib.chunks(Beam,[abstract_code]).
    # erl_syntax:form_list(AC)

    raw_session_types = Keyword.get_values(dbgi_map[:attributes], :session)

    all_session_types =
      raw_session_types
      |> Enum.map(&ST.string_to_st_incl_label(&1))
      |> Enum.map(fn {func_name_arity, body} -> {split_name(func_name_arity), body} end)
      |> IO.inspect()

    # all_session_types
    # |> IO.inspect()

    all_functions = get_all_functions(dbgi_map)
    |> IO.inspect()
  end

  defp get_all_functions(dbgi_map) do
    dbgi_map[:definitions]
    |> Enum.map(fn
      {func_name_arity, _def_p, _meta, body} -> {func_name_arity, func_body(hd(body))}
      x -> throw("Unknown parameters for #{inspect(x)}")
    end)
  end

  defp func_body({_, _, _, body}), do: body

  defp func_body(_) do
    throw("Expected a tuple of size 4")
  end

  # Given "name/arity" returns {name, arity} where name is an atom and arity is a number
  # Given "name" returns {:name, :no_arity}
  defp split_name(name_arity) do
    split = String.split(Atom.to_string(name_arity), "/", parts: 2)

    name = String.to_atom(Enum.at(split, 0))

    arity =
      case Enum.at(split, 1, :no_arity) do
        :no_arity ->
          :no_arity

        x ->
          Integer.parse(x)
          |> elem(0)
      end

    {name, arity}
  end

  # defmacro left ::: right do
  # end
end
