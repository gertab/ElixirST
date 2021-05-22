defmodule ElixirSessions.Checking do
  require Logger

  @moduledoc false
  # @moduledoc """
  # This module is the starting point of ElixirSessions. It parses the `@session` attribute and starts the AST code comparison with the session type.
  # """

  defmacro __using__(_) do
    quote do
      import ElixirSessions.Checking

      Module.register_attribute(__MODULE__, :session_typing, accumulate: false, persist: true)
      Module.register_attribute(__MODULE__, :session, accumulate: false, persist: false)
      Module.register_attribute(__MODULE__, :dual, accumulate: false, persist: false)
      Module.register_attribute(__MODULE__, :session_marked, accumulate: true, persist: true)
      Module.register_attribute(__MODULE__, :type_specs, accumulate: true, persist: true)
      # todo change to option
      @session_typing true
      @compile :debug_info

      @on_definition ElixirSessions.Checking
      @after_compile ElixirSessions.Checking

      IO.puts("ElixirSession started in #{IO.inspect(__MODULE__)}")
    end
  end

  def __on_definition__(env, kind, _name, _args, _guards, _body) do
    session = Module.get_attribute(env.module, :session)
    dual = Module.get_attribute(env.module, :dual)
    spec = Module.get_attribute(env.module, :spec)
    {name, arity} = env.function

    # Parse temporary attributes into persistent attributes:
    #      @session, @dual -> @session_marked
    #      @spec           -> @type_specs
    session_attribute(session, name, arity, kind, env)
    dual_attribute(dual, name, arity, env)
    spec_attribute(spec, name, arity, env)
  end

  def __after_compile__(_env, bytecode) do
    ElixirSessions.Retriever.process(bytecode)
  end

  # todo throws -> Logger
  # Processes @session attribute - gets the function and session type details
  defp session_attribute(session, name, arity, kind, env) do
    if not is_nil(session) do
      # @session_marked contains a list of functions with session types
      # E.g. [{{:pong, 0}, "?ping()"}, ...]
      # Ensure that only one session type is set for each function (in case of multiple cases)
      duplicate_session_types =
        Module.get_attribute(env.module, :session_marked)
        |> Enum.find(nil, fn
          {{^name, ^arity}, _} -> true
          _ -> false
        end)

      if not is_nil(duplicate_session_types) do
        throw("Cannot set multiple session types for the same function #{name}/#{arity}.")
      end

      if kind != :def do
        throw(
          "Session types can only be added to def function. " <>
            "#{name}/#{arity} is defined as defp."
        )
      end

      # Ensure that the session type is valid
      :ok = ST.validate!(session)

      Module.put_attribute(env.module, :session_marked, {{name, arity}, session})
      Module.delete_attribute(env.module, :session)
    end
  end

  # Processes @dual attribute, which takes a function reference, e.g. @dual &function/1.
  defp dual_attribute(dual, name, arity, env) do
    if not is_nil(dual) do
      if not is_function(dual) do
        throw("Expected function name but found #{inspect(dual)}.")
      end

      function = Function.info(dual)

      # dual_module = function[:module] # todo should be the same as current module
      dual_name = function[:name]
      dual_arity = function[:arity]
      # dual_type = function[:type] # should be :external (not :local = anon)

      dual_session =
        Module.get_attribute(env.module, :session_marked)
        |> Enum.find(nil, fn
          {{^dual_name, ^dual_arity}, _} -> true
          _ -> false
        end)

      if is_nil(dual_session) do
        throw("No dual match found for #{inspect(dual)}.")
      end

      {_name_arity, dual_session} = dual_session

      expected_dual_session =
        ST.string_to_st(dual_session)
        |> ST.dual()
        |> ST.st_to_string()

      Module.put_attribute(env.module, :session_marked, {{name, arity}, expected_dual_session})
      Module.delete_attribute(env.module, :dual)
    end
  end

  # Processes @spec details for public and private functions
  defp spec_attribute(spec, name, arity, env) do
    # Get function return and argument types from @spec directive
    if not is_nil(spec) and length(spec) > 0 do
      {:spec, {:"::", _, [{spec_name, _, args_types}, return_type]}, _module} = hd(spec)

      args_types = args_types || []

      args_types_converted = ElixirSessions.TypeOperations.get_type(args_types)
      return_type_converted = ElixirSessions.TypeOperations.get_type(return_type)

      if args_types_converted == :error or return_type_converted == :error do
        throw(
          "Problem with @spec for #{spec_name}/#{length(args_types)} " <>
            inspect(args_types) <> " " <> inspect(return_type)
        )
      end

      # IO.warn(
      #   "Checking: Found @spec: name " <>
      #     inspect(spec_name) <>
      #     ", args_types " <>
      #     # inspect(args_types) <>
      #     # " => " <>
      #     inspect(args_types_converted) <>
      #     ", return_type " <>
      #     # inspect(return_type) <>
      #     # " => " <>
      #     inspect(return_type_converted)
      # )

      types = {spec_name, length(args_types)}

      case types do
        {^name, ^arity} ->
          # Spec describes the current function
          Module.put_attribute(
            env.module,
            :type_specs,
            {{name, arity}, {args_types_converted, return_type_converted}}
          )

        _ ->
          # No spec match
          :ok
      end
    end
  end
end
