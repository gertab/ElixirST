defmodule A do
  use B

  @description "function1/0 returns :ok"
  def function1() do
    :ok
  end

  @description "function1/0 returns :not_ok"
  def function2() do
    :not_ok
  end
end
