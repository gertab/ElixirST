
# B.ex
defmodule B do
  defmacro __using__(_) do
    quote do
      import B
      Module.register_attribute(__MODULE__, :description, accumulate: true, persist: true)
      Module.register_attribute(__MODULE__, :test, accumulate: true, persist: true)
      @after_compile B
    end
  end

  def __on_definition__(env, _access, name, args, _guards, _body) do
    IO.puts("Reached on_definition")
    desc = Module.get_attribute(env.module, :description) |> hd()
    Module.delete_attribute(env.module, :description)
    Module.put_attribute(env.module, :test, {name, length(args), desc})
  end

  def __after_compile__(_env, bytecode) do
    IO.puts("Reached after_compile")
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
          end
        x ->
          throw("Error: #{inspect(x)}")
      end
    dbgi_map[:attributes]
    |> IO.inspect
  end
end

# A.ex
defmodule A do
  use B

  @description "function1/0 returns :ok"
  def function1() do
    :ok
  end

  @description &A.function1/0
  def function2() do
    :ok
  end
end

[
  test: {:function1, 0, "function1/0 returns :ok"},
  test: {:function2, 0, "function2/0 returns :not_ok"}
]
