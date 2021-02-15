# iex -S mix
# c("lib/elixirsessions/snippets/actors.exs") && Actors.start

defmodule Actors do
  def start() do
    IO.puts("Main programm in pid #{inspect(self())}")

    i = actor_spawn(&add/0)

    actor_send(i, {:pid, self()})
    actor_send(i, {:numbers, {4, 5}})
    actor_receive({:result, fn msg -> IO.puts("Result = #{msg}") end})
  end

  # i[rcv{pid -> rcv{numbers -> h!(x+y)}}]
  # h[i!pid.i!numbers.rcv{result -> print(result)}]
  def add() do
    IO.puts("[add] Actor in pid #{inspect(self())}")

    actor_receive(
      {:pid,
       fn
         pid ->
           IO.puts("Received #{inspect(pid)}")

           actor_receive(
             {:numbers,
              fn
                {value1, value2} ->
                  IO.puts("Received {#{value1}, #{value2}}")
                  actor_send(pid, {:result, value1 + value2})
              end}
           )
       end}
    )

    # Equivalent to:
    # receive do
    #   {:pid, pid} ->
    #     receive do
    #       {:num, {value1, value2}} ->
    #         actor_send(pid, {:result, value1 + value2})
    #     end
    # end
  end

  # Spawn, send and receive functions abstrated in actor_spawn, actor_send and actor_receive.

  def actor_spawn(fun) when is_function(fun) do
    # pid = spawn(fn -> receive do actor -> fun(actor) end )

    IO.puts("[actor_spawn] Spawning function")
    pid = spawn(fn -> fun.() end)
    IO.puts("[actor_spawn] Spawned actor with pid #{inspect(pid)}")
    pid
  end

  def actor_send(actor, msg) when is_pid(actor) do
    IO.puts("[actor_send] Sending #{inspect(msg)} from #{inspect(self())} to #{inspect(actor)}")
    send(actor, msg)
  end

  def actor_receive({label, cont_func}) when is_atom(label) and is_function(cont_func) do
    IO.puts(
      "[actor_receive] Waiting to receive #{label} at #{inspect(self())} and then continue with func..."
    )

    receive do
      {label, msg} ->
        IO.puts("[actor_receive] Received label #{label}, with func")
        cont_func.(msg)
    end
  end
end
