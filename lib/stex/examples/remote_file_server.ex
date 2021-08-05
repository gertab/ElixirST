# defmodule Examples.FileServer do
#   use ElixirSessions
#   @moduledoc false
#   # iex -S mix
#   # Modular session types for objects pg 37
#   # FileChannel = &{OPEN: ? String .⊕{OK: CanRead , ERROR: FileChannel } , QUIT : End }
#   # CanRead = &{READ: ⊕{EOF: FileChannel , DATA: ! String . CanRead } , CLOSE: FileChannel }
#   # Create the opposite side automatically
#   def run() do
#     server = spawn(__MODULE__, :fileChannel, [])

#     spawn(__MODULE__, :remoteFile, [
#       server,
#       "/mnt/c/Users/Gerard/Google Drive/Masters/Elixir/ElixirSessions/notes.txt",
#       0
#     ])
#   end

#   ### SERVER ###
#   @session "rec X.(?pid(pid).&{?open(string).+{!ok().rec Y.(&{?read().+{!eof().X, !data(string).Y}, ?close().X}), !error().X}, ?quit()})"
#   def fileChannel() do
#     client =
#       receive do
#         {:pid, value} ->
#           value
#       end

#     receive do
#       {:open, file} ->
#         case File.read(file) do
#           {:ok, contents} ->
#             send(client, {:ok})

#             splitFile = String.split(contents, "\n", trim: true)

#             canRead(client, splitFile)

#           {:error, _} ->
#             send(client, {:error})
#             fileChannel()
#         end

#         :ok

#       {:quit} ->
#         :ok
#     end
#   end

#   def canRead(pid, splitFile) do
#     receive do
#       {:read} ->
#         case splitFile do
#           [head | tail] ->
#             send(pid, {:data, head})
#             canRead(pid, tail)

#           [] ->
#             send(pid, {:eof})
#             fileChannel()
#         end

#       {:close} ->
#         fileChannel()
#     end
#   end

#   ### CLIENT ###
#   # dual of FileServer
#   @session "rec X.(!pid(pid).+{!open(string).&{?ok().rec Y.(+{!read().&{?eof().X, ?data(string).Y}, !close().X}), ?error().X}, !quit()})"
#   def remoteFile(server, fileToRead, tries) do
#     send(server, {:pid, self()})

#     case tries do
#       x when x < 5 ->
#         send(server, {:open, fileToRead})

#         receive do
#           {:ok} -> read(server, fileToRead)
#           {:error} -> remoteFile(server, fileToRead, tries + 1)
#         end

#       _ ->
#         send(server, {:quit})
#     end
#   end

#   def read(server, fileToRead) do
#     case is_binary(fileToRead) do
#       true ->
#         send(server, {:read})

#         receive do
#           {:eof} ->
#             remoteFile(server, fileToRead, :eof)

#           {:data, data} ->
#             IO.puts("Data received: #{inspect(data)}")
#             read(server, fileToRead)
#         end

#       false ->
#         send(server, {:close})
#         remoteFile(server, fileToRead, 0)
#     end
#   end
# end
