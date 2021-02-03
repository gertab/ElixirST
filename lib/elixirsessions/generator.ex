defmodule ElixirSessions.Generator do
  @moduledoc """
  Given a session type, it generated the Elixir code/AST automatically.

  ## Examples

      iex>  session_type = [send: 'type', recv: 'type']
      ...> ElixirSessions.Generator.generate_to_string(session_type) |> IO.puts()
      #def func() do
        send(self(), {:data})
        receive do
          {_recv_data} ->
            :ok
        end
      #end

  Todo/To improve: Reduce number of conversions between strings and ASTs (Macro.to_string() and Code.string_to_quoted()).
    For recursion, replace func with the actual function name.
    Fix 'case': the first 'send' should also send the label
  """
  require Logger
  # recompile && ElixirSession.Generator.run
  def run() do
    session_type = [
      send: 'type',
      recv: 'type',
      branch: %{
        pong: [
          recv: 'type',
          send: 'type'
        ],
        ponng: [recv: 'type']
      }
    ]

    generate_to_string(session_type)
    # |> IO.puts()
  end

  @spec generate_to_string(session_type()) :: String.t()
  @doc """
  Given a session type, generates the corresponding Elixir code, formatted as a string.
  """
  def generate_to_string(session_type) do
    generate_quoted(session_type)
    |> Macro.to_string()
  end

  @type branch_type() :: %{atom => session_type}
  @type choice_type() :: %{atom => session_type}
  @type session_type() ::
          [
            {:recv, any}
            | {:send, any}
            | {:branch, branch_type}
            | {:call_recurse, any}
            | {:choice, choice_type}
            | {:recurse, any, session_type}
          ]
  @type ast() :: Macro.t()
  @spec generate_quoted(session_type) :: ast

  @doc """
  Given a session type, computes the equivalent (skeleton) code in Elixir. The output is in AST/quoted format.

  ## Examples
      iex> session_type = [send: 'type']
      ...> ElixirSessions.Generator.generate_quoted(session_type)
      {:def, [context: ElixirSessions.Generator, import: Kernel],
      [
        {:func, [context: ElixirSessions.Generator], []},
        [do: {:send, [line: 1], [{:self, [line: 1], []}, {:{}, [line: 1], [:data]}]}]
      ]}
  """
  def generate_quoted(session_type) do
    quote do
      def func() do
        unquote(generate(session_type))
      end
    end
  end

  defp generate(session_type)

  defp generate({:send, _type}) do
    quote do
      send(self(), {:data})
    end
  end

  defp generate({:recv, _type}) do
    quote do
      receive do
        {_recv_data} ->
          :ok
      end
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

  defp generate({:branch, args}) when is_map(args) do
    cases =
      Enum.map(args, fn {x, y} -> "{:#{x}} -> " <> (generate(y) |> Macro.to_string()) <> "\n" end)

    code = "receive do \n " <> List.to_string(cases) <> " \n end"

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

  defp generate({:choice, args}) when is_map(args) do
    # todo add label to first send - send(pid, {:label, data})
    cases =
      Enum.map(args, fn {x, y} -> "{:#{x}} -> " <> (generate(y) |> Macro.to_string()) <> "\n" end)

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
end
