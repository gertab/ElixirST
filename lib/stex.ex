defmodule ElixirSessions do
  require Logger

  @moduledoc false
  # @moduledoc """
  # This module is the starting point of STEx. It parses the `@session` attribute and starts the AST code comparison with the session type.
  # """

  defmacro __using__(_) do
    quote do
      import ElixirSessions

      Module.register_attribute(__MODULE__, :session, accumulate: false, persist: false)
      Module.register_attribute(__MODULE__, :dual, accumulate: false, persist: false)
      Module.register_attribute(__MODULE__, :session_type_collection, accumulate: true, persist: true)
      Module.register_attribute(__MODULE__, :dual_unprocessed_collection, accumulate: true, persist: true)
      Module.register_attribute(__MODULE__, :type_specs, accumulate: true, persist: true)
      @compile :debug_info

      @on_definition ElixirSessions
      @after_compile ElixirSessions

      IO.puts("ElixirSession started in #{IO.inspect(__MODULE__)}")
    end
  end

  def __on_definition__(env, kind, _name, _args, _guards, _body) do
    session = Module.get_attribute(env.module, :session)
    dual = Module.get_attribute(env.module, :dual)
    spec = Module.get_attribute(env.module, :spec)
    {name, arity} = env.function

    # Parse temporary attributes into persistent attributes:
    #      @session        -> @session_type_collection
    #      @dual           -> @dual_unprocessed_collection
    #      @spec           -> @type_specs
    session_attribute(session, name, arity, kind, env)
    dual_attribute(dual, name, arity, env)
    spec_attribute(spec, name, arity, env)
  end

  def __after_compile__(_env, bytecode) do
    ElixirSessions.Retriever.process(bytecode)
  end

  # Processes @session attribute - gets the function and session type details
  defp session_attribute(session, name, arity, kind, env) do
    unless is_nil(session) do
      # @session_type_collection contains a list of functions with session types
      # E.g. [{{:pong, 0}, "?ping()"}, ...]
      # Ensures that only one session type is set for each function (in case of multiple cases)
      all_session_types = Module.get_attribute(env.module, :session_type_collection)

      duplicate_session_types =
        all_session_types
        |> Enum.find(nil, fn
          {{^name, ^arity}, _} -> true
          _ -> false
        end)

      unless is_nil(duplicate_session_types) do
        throw("Cannot set multiple session types for the same function #{name}/#{arity}.")
      end

      if kind != :def do
        throw(
          "Session types can only be added to def function. " <>
            "#{name}/#{arity} is defined as defp."
        )
      end

      # Ensures that the session type is valid
      parsed_session_type = ST.string_to_st(session)

      case parsed_session_type do
        %ST.Recurse{outer_recurse: true, label: label} ->
          if Keyword.has_key?(all_session_types, label) do
            raise "Cannot have multiple session types with the same label: '#{label}'"
          end

          Module.put_attribute(env.module, :session_type_collection, {label, {{name, arity}, session}})

        _ ->
          Module.put_attribute(env.module, :session_type_collection, {nil, {{name, arity}, session}})
      end

      Module.delete_attribute(env.module, :session)
    end
  end

  # Processes @dual attribute, which takes a function reference, e.g. @dual "session_name".
  defp dual_attribute(dual_label, name, arity, env) do
    unless is_nil(dual_label) do
      unless is_binary(dual_label) do
        throw("Expected session type name but found #{inspect(dual_label)}.")
      end

      Module.put_attribute(env.module, :dual_unprocessed_collection, {{name, arity}, String.to_atom(dual_label)})
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
            inspect(args_types) <>
            " :: " <>
            inspect(return_type) <>
            " ## " <>
            inspect(args_types_converted) <> " :: " <> inspect(return_type_converted)
        )
      end

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
