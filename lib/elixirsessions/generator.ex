defmodule ElixirSession.Generator do
  require Logger
  # recompile && ElixirSession.Generator.run
  def run() do
    # session_type = [
    #   {:recurse, X,
    #    [
    #      choice: %{
    #        abc: [send: 'type', send: 'type'],
    #        ok1: [send: 'type', recv: 'type', send: 'type']
    #      },
    #      send: 'type',
    #      branch: %{
    #        pong: [
    #          recv: 'type',
    #          send: 'type',
    #          send: 'type',
    #          send: 'type',
    #          branch: %{
    #            pong: [
    #              recv: 'type',
    #              send: 'type',
    #              send: 'type',
    #              send: 'type',
    #              send: 'type'
    #            ],
    #            ponng: [recv: 'type']
    #          },
    #          send: 'type'
    #        ],
    #        ponng: [recv: 'type']
    #      },
    #      send: 'type',
    #      call_recurse: :X
    #    ]}
    # ]

    session_type = [
      recv: 'type',
      send: 'type',
      send: 'type',
      send: 'type',
      branch: %{
        pong: [
          # recv: 'type',
          send: 'type',
          send: 'type',
          send: 'type',
          send: 'type'
        ],
        ponng: [recv: 'type']
      },
      send: 'type'
    ]

    generate(session_type)
    |> Macro.to_string()
    |> IO.puts
  end

  def generate(session_type)

  def generate({:send, _type}) do
    quote do
      send(nil, {:data})
    end
  end

  def generate({:recv, _type}) do
    quote do
      receive do
        {_recv_data} ->
          :ok
      end
    end
  end

  def generate({:branch, args}) when is_map(args) do
    cases =
      Enum.map(args, fn {x, y} -> "#{x} -> " <> (generate(y) |> Macro.to_string()) <> "\n" end)

    code = ("receive do \n " <> List.to_string(cases) <> " \n end")

    case Code.string_to_quoted(code) do
      {:ok, result} ->
        result

      {:error, {line, err1, err2}} ->
        Logger.error(
          "Error while generating receive AST on line #{line}: #{IO.inspect(err1)} #{IO.inspect(err2)}"
        )
    end
  end


  def generate({:choice, args}) when is_map(args) do
    cases =
      Enum.map(args, fn {x, y} -> "#{x} -> " <> (generate(y) |> Macro.to_string()) <> "\n" end)

    code = ("case do \n " <> List.to_string(cases) <> " \n end")

    case Code.string_to_quoted(code) do
      {:ok, result} ->
        result

      {:error, {line, err1, err2}} ->
        Logger.error(
          "Error while generating receive AST on line #{line}: #{IO.inspect(err1)} #{IO.inspect(err2)}"
        )
    end
  end

  def generate(session_type) when is_list(session_type) do
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
          "Error while generating block AST on line #{line}: #{IO.inspect(err1)} #{IO.inspect(err2)}"
        )
    end
  end
end
