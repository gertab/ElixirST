defmodule ElixirSessions.Checking do
  require Logger

  @moduledoc false
  # @moduledoc """
  # This module is the starting point of ElixirSessions. It parses the `@session` attribute and starts the AST code comparison with the session type.
  # """

  defmacro __using__(_) do
    quote do
      import ElixirSessions.Checking

      Module.register_attribute(__MODULE__, :session_type_checking, persist: true)
      @session_type_checking true

      Module.register_attribute(__MODULE__, :session, accumulate: true, persist: true)
      Module.register_attribute(__MODULE__, :infer_session, accumulate: true, persist: true)
      Module.register_attribute(__MODULE__, :test, accumulate: true, persist: true)

      # @on_definition ElixirSessions.Checking
      # todo checkout @before_compile, @after_compile [Elixir fires the before compile hook after expansion but before compilation.]
      # __after_compile__/2 runs after elixir has compiled the AST into BEAM bytecode
      @after_compile ElixirSessions.Checking
      # @before_compile ElixirSessions.Checking

      IO.puts("ElixirSession started in #{IO.inspect(__MODULE__)}")
    end
  end

  # Definition of a function head, therefore do nothing
  # def __on_definition__(_env, _access, _name, _args, _guards, nil), do: nil
  # def __on_definition__(_env, _access, _name, _args, _guards, []), do: nil

  # def __on_definition__(env, _access, name, args, _guards, body) do
  #   if sessions = Module.get_attribute(env.module, :session) do
  #     if length(sessions) > 0 do
  #       session = hd(sessions)
  #       IO.inspect(sessions)
  #       # Module.get_attribute(env.module, :session)
  #       try do
  #         {_session_type_label, session_type} = ST.string_to_st_incl_label(session)

  #         ElixirSessions.SessionTypechecking.session_typecheck(
  #           name,
  #           length(args),
  #           body[:do],
  #           session_type
  #         )
  #       catch
  #         x ->
  #           throw(x)
  #           # _ = Logger.error("Leex/Yecc error #{inspect(x)}")
  #       end

  #       # case s do
  #       #   {:error, {line, _, message}} ->
  #       #     _ = Logger.error("Session type parsing error on line #{line}: #{inspect(message)}")
  #       #     :ok

  #       #   {:error, x} ->
  #       #     _ = Logger.error("Session type parsing error: #{inspect(x)}")
  #       #     :ok

  #       #   session_type when is_list(session_type) ->
  #       #     ElixirSessions.SessionTypechecking.session_typecheck(name, length(args), body[:do], session_type)
  #       #     :ok

  #       #   x ->
  #       #     _ = Logger.error("Leex/Yecc error #{inspect(x)}")
  #       #     :ok
  #       # end

  #       _inferred_session_type = ElixirSessions.Inference.infer_session_type(name, body[:do])
  #       IO.puts("\nSesssion type for #{name} type checks successfully.")
  #       # IO.puts("\nInferred sesssion type for: #{name}")
  #       # IO.inspect(inferred_session_type)
  #       :okkk
  #     end
  #   end

  #   if sessions = Module.get_attribute(env.module, :infer_session) do
  #     if length(sessions) > 0 do
  #       # session = hd(sessions)
  #       try do
  #         session_type = ElixirSessions.Inference.infer_session_type(name, body[:do])

  #         result = ST.st_to_string(session_type)
  #         throw(result)
  #       catch
  #         x ->
  #           throw(x)
  #       end

  #       inferred_session_type = ElixirSessions.Inference.infer_session_type(name, body[:do])
  #       IO.puts("\nInferred sesssion type for: #{name}")
  #       IO.inspect(inferred_session_type)
  #     end
  #   end

  #   :ok
  # end
  def __on_definition__(env, _access, name, args, _guards, body) do
    IO.puts("__on_definition__xz")
    IO.inspect(env)
    IO.inspect(__MODULE__)
    Module.put_attribute(env.module, :test, {name, length(args)})
  end

  def __before_compile__(_env) do
    IO.puts("BEFORE COMPILE")
  end

  def __after_compile__(_env, bytecode) do
    # IO.puts("AFTER COMPILE")
    # todo pattern matched functions?????

    # Gets debug_info chunk from BEAM file
    chunks =
      case :beam_lib.chunks(bytecode, [:debug_info]) do
        {:ok, {_mod, chunks}} -> chunks
        {:error, _, error} -> throw("Error: #{inspect(error)}")
      end

    # Gets the (extended) Elixir abstract syntax tree from debug_info chunk
    dbgi_map =
      case chunks[:debug_info] do
        {:debug_info_v1, :elixir_erl, metadata} ->
          case metadata do
            {:elixir_v1, map, _} ->
              # Erlang extended AST available
              map

            {version, _, _} ->
              throw("Found version #{version} but expected :elixir_v1.")
          end

        x ->
          throw("Error: #{inspect(x)}")
      end
      # |> IO.inspect()

    # {:ok,{_,[{:abstract_code,{_, ac}}]}} = :beam_lib.chunks(Beam,[abstract_code]).
    # erl_syntax:form_list(AC)

    # Gets the list of session types, which were stored as attributes in the module
    raw_session_types = Keyword.get_values(dbgi_map[:attributes], :session)

    dbgi_map[:attributes]
    # |> IO.inspect

    # # Parses session type from string to Elixir data
    # all_session_types =
    #   raw_session_types
    #   |> Enum.map(&ST.string_to_st_incl_label(&1))

    # # |> IO.inspect()

    # # Parses session type labels:
    # # e.g. ["ping/2": %ST.Terminate{}] becomes [{{:ping, 2}, %ST.Terminate{}}]
    # #      ["ping": %ST.Terminate{}]   becomes [{{:ping},    %ST.Terminate{}}]
    # session_types_name_arity =
    #   all_session_types
    #   |> Enum.map(fn {key, value} -> {split_name(key), value} end)

    # # |> IO.inspect()

    # # Ensures unique session type names
    # session_types_name_arity
    # # [{:a, :b}, {:c, :d}] -> [:a, :c]
    # |> Enum.map(&elem(&1, 0))
    # |> ensure_no_duplicates!()

    # all_functions =
    #   get_all_functions!(dbgi_map)
    #   # |> IO.inspect()

    # # dbgi_map
    # # |> IO.inspect()

    # matching_session_types_functions =
    #   Enum.map(
    #     session_types_name_arity,
    #     fn
    #       {{name, arity}, session_type} -> {{name, arity}, session_type}
    #       {{name}, session_type} -> {{name, get_arity!(all_functions, name)}, session_type}
    #     end
    #   )
    #   |> IO.inspect()

    # # @session can only be used with def not defp
    # _ = ensure_def_not_defp!(matching_session_types_functions, all_functions)

    # %ST.Module{
    #   functions: all_functions,
    #   function_session_type: to_map(matching_session_types_functions),
    #   file: dbgi_map[:file],
    #   relative_file: dbgi_map[:relative_file],
    #   line: dbgi_map[:line],
    #   module_name: dbgi_map[:module]
    # }
    # |> ElixirSessions.SessionTypechecking.session_typecheck_module()
  end

  # todo add call to session typecheck a module explicitly from beam (rather than rely on @after_compile)

  defp to_map(list) do
    list
    |> Enum.into(%{})
  end

  defp ensure_no_duplicates!(check) do
    if has_duplicates?(check) do
      throw("Cannot have session types with same name")
    end
  end

  # Checks if a list has duplicate elements. Returns true/false.
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

  # Given the debug info chunk from the Beam files,
  # return a list of all functions

  # Structure of [Elixir] functions in Beam
  # {{name, arity}, :def_or_p, meta, [{meta, parameters, guards, body}, case2, ...]}
  # E.g.
  # {{:function1, 1}, :def, [line: 36],
  #  [
  #    {[line: 36], [7777],                       [],       {:__block__, [], [...]}}, # Case 1
  #    {[line: 47], [{:server, [line: 47], nil}], [guards], {...}                  }, # Case 2
  #    ...
  #  ]
  # }

  defp get_all_functions!(dbgi_map) do
    dbgi_map[:definitions]
    |> Enum.map(fn
      {{name, arity}, def_p, meta, function_body} ->
        # Unzipping function_body
        {metas, parameters, guards, bodies} =
          Enum.reduce(function_body, {[], [], [], []}, fn {curr_m, curr_p, curr_g, curr_b},
                                                          {accu_m, accu_p, accu_g, accu_b} ->
            {[curr_m | accu_m], [curr_p | accu_p], [curr_g | accu_g], [curr_b | accu_b]}
          end)

        %ST.Function{
          name: name,
          arity: arity,
          def_p: def_p,
          meta: meta,
          cases: length(bodies),
          metas: metas,
          parameters: parameters,
          guards: guards,
          bodies: bodies
        }

      x ->
        throw("Unknown info for #{inspect(x)}")
    end)
  end

  # Given a function name, returns a matching (& unique) arity
  defp get_arity!(all_functions, name) do
    matches =
      Enum.map(
        all_functions,
        fn
          %ST.Function{name: ^name, arity: arity} -> arity
          _ -> nil
        end
      )
      |> Enum.filter(fn elem -> !is_nil(elem) end)

    case length(matches) do
      0 -> throw("Function #{name} was not found.")
      1 -> hd(matches)
      _ -> throw("Multiple function with the name #{name} were found with different arity.")
    end
  end

  # Given "name/arity" returns {name, arity} where name is an atom and arity is a number
  # Given "name" returns {:name}
  # E.g. :"ping/2" becomes {:ping, 2}
  #      :"ping"   becomes {:ping}
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

  defp ensure_def_not_defp!(session_types, all_functions) do
    Enum.map(session_types, fn {{name, arity}, _session_type} ->
      %ST.Function{def_p: def_p} = lookup_function!(all_functions, name, arity)

      case def_p do
        :def ->
          :ok

        :defp ->
          throw(
            "Session types can only be added to def function. " <>
              "#{name}/#{arity} is defined as defp."
          )
      end
    end)
  end

  defp lookup_function!(all_functions, name, arity) do
    matches =
      Enum.map(
        all_functions,
        fn
          %ST.Function{name: ^name, arity: ^arity} = function -> function
          _ -> nil
        end
      )
      |> Enum.filter(fn elem -> !is_nil(elem) end)

    case length(matches) do
      0 -> throw("Function #{name}/#{arity} was not found.")
      1 -> hd(matches)
      _ -> throw("Multiple function with the name #{name}/#{arity}.")
    end
  end

  # todo
  # defmacro left ::: right do
  # end
end
