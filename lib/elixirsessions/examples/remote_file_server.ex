defmodule ElixirSessions.FileServer do
  use ElixirSessions.Checking
  @moduledoc false
  # iex -S mix
  # Modular session types for objects pg 37
  # FileChannel = &{OPEN: ? String .⊕{OK: CanRead , ERROR: FileChannel } , QUIT : End }
  # CanRead = &{READ: ⊕{EOF: FileChannel , DATA: ! String . CanRead } , CLOSE: FileChannel }
  # Create the opposite side automatically
  def run() do
    spawn(__MODULE__, :example1, [])
  end

  @session "fileChannel = rec X.(&{?open(string).+{!ok().canRead, !error().X}, ?quit()})"
  def fileChannel() do
    client = self()

    receive do
      {:open, file} ->
        case true do
          true ->
            send(client, {:ok})
            canRead(client)

          false ->
            send(client, {:error})
            fileChannel()
        end

        :ok

      {:quit} ->
        :ok
    end
  end

  @session "canRead = rec Y.(&{?read().+{!eof().fileChannel, !data(string).Y}, ?close().fileChannel})"
  def canRead(pid) do
    receive do
      {:read} ->
        case true do
          true ->
            send(pid, {:eof})
            fileChannel()

          false ->
            send(pid, {:data, "lines from file"})
            canRead(pid)
        end

      {:close} ->
        fileChannel()
    end
  end
end

defmodule ElixirSessions.RemoteFile do
  use ElixirSessions.Checking
  @moduledoc false

  # dual of FileServer
  def run() do
    spawn(__MODULE__, :fileChannel, [0])
  end

  @session "fileChannel = rec X.(+{!open(string).&{?ok().read, ?error().X}, !quit()})"
  def fileChannel(tries) do
    server = self()

    case tries do
      x when x < 5 ->
        send(server, {:open, "file.txt"})

        receive do
          {:ok} -> read(server)
          {:error} -> fileChannel(tries + 1)
        end

      _ ->
        send(server, {:quit})
    end
  end

  @session "read = rec Y.(+{!read().&{?eof().fileChannel, ?data(string).Y}, !close().fileChannel})"
  def read(pid) do
    case true do
      true ->
        send(pid, {:read})

        receive do
          {:eof} ->
            fileChannel(0)

          {:data, data} ->
            IO.puts("Data received: #{inspect data}")
            read(pid)
        end

      false ->
        send(pid, {:close})
        fileChannel(0)
    end
  end
end
