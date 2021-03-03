defmodule ElixirSessions.Generator do
  @moduledoc """
  Given a session type, it generates the quoted Elixir code (or AST) automatically.

      session_type = [{:send, :hello, [:number]}, {:recv, :hello_ret, [:number]}]

      ElixirSessions.Generator.generate_to_string(session_type) |> IO.puts()

      def func() do
        send(self(), {:hello})
        receive do
          {:hello_ret, var1} when is_number(var1) ->
            :ok
        end
      end

  Another example:

      session_type = [
        {:recv, :Hello, []},
        {:choice,
        [
          [{:send, :Neg, [:number, :pid]}, {:recv, :Hello, [:number]}],
          [{:send, :Neg, [:number, :pid]}, {:recv, :Hello, [:number]}]
        ]}
      ]

      ElixirSessions.Generator.generate_to_string(session_type) |> IO.puts

      def func() do
        receive do
          {:Hello} ->
            :ok
        end
        case true do
          {:option0} ->
            send(self(), {:Neg})
            receive do
              {:Hello, var1} when is_number(var1) ->
                :ok
            end
          {:option1} ->
            send(self(), {:Neg})
            receive do
              {:Hello, var1} when is_number(var1) ->
                :ok
            end
        end
      end

  Todo/To improve: Reduce number of conversions between strings and ASTs (Macro.to_string() and Code.string_to_quoted()).
    For recursion, replace func with the actual function name.
    todo: multiple recursion levels
  """
  require Logger
  require ST

  @typedoc false
  @type ast :: ElixirSessions.Common.ast()
  @typedoc false
  @type info :: ElixirSessions.Common.info()
  @typedoc false
  @type session_type :: ElixirSessions.Common.session_type()

  @doc """
        Given a session type, generates the corresponding Elixir code, formatted as a string.

        E.g.
              st = ElixirSessions.Parser.parse("!Ping(Integer).?Pong(String)")
              ElixirSessions.Generator.generate_to_string(st)
              def func() do
                send(self(), {:Ping})
                receive do
                  {:Pong, var1} when is_binary(var1) ->
                    :ok
                  end
                end
              end
      """
  @spec generate_to_string(session_type()) :: String.t()
  def generate_to_string(session_type) do
    generate_quoted(session_type)
    |> Macro.to_string()
  end

  @doc """
    Given a session type (as a string), generates the corresponding Elixir code.
    E.g.
        ElixirSessions.Generator.generate_from_session_type("!Ping(Integer).?Pong(String)")
        def func() do
          send(self(), {:Ping})
          receive do
            {:Pong, var1} when is_binary(var1) ->
              :ok
          end
        end
  """
  @spec generate_from_session_type(String.t()) :: String.t()
  def generate_from_session_type(session_type_string) when is_binary(session_type_string) do
    session_type = ElixirSessions.Parser.parse(session_type_string)
    ElixirSessions.Generator.generate_to_string(session_type)
  end

  @doc """
  Given a session type, computes the equivalent (skeleton) code in Elixir. The output is in AST/quoted format.

  ## Examples
      iex> session_type = [{:send, :value, []}]
      ...> ElixirSessions.Generator.generate_quoted(session_type)
      {:def, [context: ElixirSessions.Generator, import: Kernel],
        [
          {:func, [context: ElixirSessions.Generator], []},
          [
            do: {:send, [line: 1],
              [{:self, [line: 1], []}, {:{}, [line: 1], [:value]}]}
          ]
        ]
      }
  """
  @spec generate_quoted(session_type) :: ast
  def generate_quoted(session_type) do
    quote do
      def func() do
        unquote(generate(session_type))
      end
    end
  end

  defp generate(session_type)

  defp generate({:send, label, _types}) do
    quote do
      send(self(), {unquote(label)})
    end
  end

  defp generate({:recv, label, types}) do
    guards =
      if type_guards(types) != "" do
        "when #{type_guards(types)}"
      end

    conditions = "{:#{label}#{variable_guards(types)}} #{guards} -> :ok\n"

    case Code.string_to_quoted("receive do \n " <> conditions <> " \n end") do
      {:ok, result} ->
        result

      {:error, {line, err1, err2}} ->
        _ =
          Logger.error(
            "Error while generating receive AST on line #{line}: #{IO.inspect(err1)} #{
              IO.inspect(err2)
            }"
          )

        []
    end
  end

  defp generate({:recurse, _recurse_var, args}) when is_list(args) do
    generate(args)
  end

  defp generate({:call_recurse, _recurse_var}) do
    quote do
      func()
    end
  end

  defp generate({:branch, args}) when is_list(args) do
    cases =
      Enum.map(
        args,
        fn
          [{:recv, label, types}] ->
            guards =
              if type_guards(types) != "" do
                "when #{type_guards(types)}"
              end

            "{:#{label}#{variable_guards(types)}} #{guards} -> :ok\n"

          [{:recv, label, types} | b] ->
            guards =
              if type_guards(types) != "" do
                "when #{type_guards(types)}"
              end

            "{:#{label}#{variable_guards(types)}} #{guards} -> " <>
              (generate(b) |> Macro.to_string()) <> "\n"

          _ ->
            throw(
              "Error while generating branch: all branches need to start with a receive statement"
            )
        end
      )

    code = "receive do \n " <> List.to_string(cases) <> " \n end"

    case Code.string_to_quoted(code) do
      {:ok, result} ->
        result

      {:error, {line, err1, err2}} ->
        _ =
          Logger.error(
            "Error while generating receive AST on line #{line}: #{IO.inspect(err1)} #{
              IO.inspect(err2)
            }"
          )

        []
    end
  end

  defp generate({:choice, args}) when is_list(args) do
    # todo add label to first send - send(pid, {:label, data})
    cases =
      Enum.with_index(args)
      |> Enum.map(fn
        {[{:send, label, types}], index} ->
          "{:option#{index}} -> #{generate({:send, label, types}) |> Macro.to_string()}\n"

        {[{:send, label, types} | b], index} ->
          "{:option#{index}} -> #{generate({:send, label, types}) |> Macro.to_string()}\n" <>
            (generate(b) |> Macro.to_string()) <> "\n"

        _ ->
          throw(
            "Error while generating branch: all branches need to start with a receive statement"
          )
      end)

    code = "case true do \n " <> List.to_string(cases) <> " \n end"

    case Code.string_to_quoted(code) do
      {:ok, result} ->
        result

      {:error, {line, err1, err2}} ->
        Logger.error(
          "Error while generating receive AST on line #{line}: #{IO.inspect(err1)} #{
            IO.inspect(err2)
          }"
        )
    end
  end

  defp generate(session_type) when is_list(session_type) do
    code =
      Enum.map(session_type, fn x ->
        generate(x)
        |> Macro.to_string()
      end)
      # ["code", "code2"] -> ["code \n", "code2 \n"]
      |> Enum.map(fn x -> x <> " \n" end)
      # ["code \n", "code2 \n"] -> "code \ncode2 \n"
      |> List.to_string()

    # Convert to quoted/AST
    case Code.string_to_quoted(code) do
      {:ok, result} ->
        result

      {:error, {line, err1, err2}} ->
        Logger.error(
          "Error while generating block AST on line #{line}: #{IO.inspect(err1)} #{
            IO.inspect(err2)
          }"
        )
    end
  end

  defp type_equivalent(type) when is_atom(type) do
    types = %{
      "atom" => "is_atom",
      "binary" => "is_binary",
      "bitstring" => "is_bitstring",
      "boolean" => "is_boolean",
      "exception" => "is_exception",
      "float" => "is_float",
      "function" => "is_function",
      "integer" => "is_integer",
      "list" => "is_list",
      "map" => "is_map",
      "nil" => "is_nil",
      "number" => "is_number",
      "pid" => "is_pid",
      "port" => "is_port",
      "reference" => "is_reference",
      "struct" => "is_struct",
      "tuple" => "is_tuple",
      "string" => "is_binary"
    }

    lower_type = String.downcase(Atom.to_string(type))

    if Map.has_key?(types, lower_type) do
      {:ok, res} = Map.fetch(types, lower_type)
      res
    else
      throw("Invalid type given: #{type}")
    end
  end

  defp type_guards(types) when is_list(types) do
    Enum.with_index(types, 1)
    |> Enum.map(fn
      {:any, _index} -> nil
      {type, index} -> "#{type_equivalent(type)}(var#{index})"
    end)
    |> Enum.filter(fn elem -> !is_nil(elem) end)
    |> Enum.join(" and ")
  end

  defp variable_guards(types) when is_list(types) do
    0..length(types)
    |> Enum.to_list()
    |> Enum.slice(1..-1)
    |> Enum.map(fn x -> "var#{x}" end)
    |> List.insert_at(0, nil)
    |> Enum.join(", ")
  end

  # recompile && (IO.puts(ElixirSessions.Generator.run))
  def run() do
    session_type_string =
      "!Hello().!Hello2(Number).!Hello2(String).&{?Option1(Atom), ?Option2(Atom, any, Number).?Option2(list, Atom, Number).!SDFLDF(), ?Option3()}.+{!Option1(List), !Option2().!SDFLDF(), !Option3()}"

    generate_from_session_type(session_type_string)
  end
end
