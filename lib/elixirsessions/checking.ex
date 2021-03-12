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
      |> IO.inspect()

    session_types_name_arity =
      all_session_types
      |> Keyword.keys()
      |> Enum.map(fn x -> {split_name(x), x} end)

    session_types_name_arity
      |> Enum.map(&elem(&1, 1))
      |> ensure_no_duplicates()

    all_functions = get_all_functions(dbgi_map)

    matching_session_types_functions =
    session_types_name_arity
    |> Enum.map(fn {split_name_arity, name_arity} ->
      case all_functions_filter(all_functions, split_name_arity) do
        [] ->
          nil

        [value] ->
          {value, name_arity}

        [{name, arity} | _] = values ->
          throw(
            "Session type #{inspect(elem(split_name_arity, 0))} matched with multiple functions: " <>
              "#{inspect(values)}. Specify the arity, e.g. #{name}/#{arity}."
          )
      end
    end)
    |> Enum.filter(fn elem -> !is_nil(elem) end)
    |> Enum.into(%{})
    |> IO.inspect()
  end

  defp all_functions_filter(all_functions, {expected_name}) do
    all_functions
    |> Enum.filter(fn {{name, _arity}, _func_body} -> name == expected_name end)
    |> Enum.map(&elem(&1, 0))
  end

  defp all_functions_filter(all_functions, {expected_name, expected_arity}) do
    all_functions
    |> Enum.filter(fn {{name, arity}, _func_body} ->
      name == expected_name and arity == expected_arity
    end)
    |> Enum.map(&elem(&1, 0))
  end

  defp ensure_no_duplicates(check) do
    if has_duplicates?(check) do
      throw("Cannot have session types with same name")
    end
  end

  defp has_duplicates?(list) do
    list
    |> Enum.reduce_while([], fn x, acc ->
      if x in acc do
        {:halt, false}
      else
        {:cont, [x | acc]}
      end
    end)
    |> is_boolean()
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

    case Enum.at(split, 1, :no_arity) do
      :no_arity ->
        {name}

      x ->
        arity =
          Integer.parse(x)
          |> elem(0)

        {name, arity}
    end
  end

  # defmacro left ::: right do
  # end
end
