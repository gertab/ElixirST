# ElixirSessions

ElixirSessions applies *Session Types* to the Elixir language. It statically checks that the programs use the correct communication structures (e.g. `send`/`receive`) when dealing with message passing between actors. It also ensures that the correct types are being used. For example, the session type `?Add(number, number).!Result(number).end` expects that two numbers are received (i.e. `?`), then a number is sent (i.e. `!`) and finally the session terminates.

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `elixirsessions` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:elixirsessions, "~> 0.2.0"}
  ]
end
```
<!-- 
```elixir
def deps do
  [
    {:dep_from_git, git: "https://github.com/gertab/STEx.git"}
  ]
end
```

{:dep_from_git, git: "https://github.com/gertab/STEx.git", tag: "0.1.0"}
-->

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/elixirsessions](https://hexdocs.pm/elixirsessions).


## Example

To session typecheck files in Elixir, add `use STEx` and include any assertions using `@session` (or `@dual`) attributes preceding any `def` functions. The following is a [`simple example`](/lib/elixirsessions/examples/small_example.ex):
<!-- The `@spec` directives are needed to ensure type correctness for the parameters. -->

```elixir
defmodule Examples.SmallExample do
  use STEx

  @session "server = ?Hello()"
  @spec server(pid) :: atom()
  def server(_pid) do
    receive do
      {:Hello} -> :ok
    end
  end

  @dual "server"
  @spec client(pid) :: {atom()}
  def client(pid) do
    send(pid, {:Hello})
  end
end
```

ElixirSessions runs automatically at compile time (`mix compile`) or as a mix task (`mix session_check`):
```text
$ mix session_check Examples.SmallExample
[info]  Session typechecking for client/1 terminated successfully
[info]  Session typechecking for server/0 terminated successfully
```

If the client sends a different label (e.g. :Hi) instead of the one specified in the session type (i.e. `@session "!Hello()"`), ElixirSessions will complain:

```text
$ mix session_check Examples.SmallExample
[error] Session typechecking for client/1 found an error. 
[error] [Line 7] Expected send with label :Hello but found :Hi.
```

## Session Types in Elixir

Session types are used to ensure correct communication between concurrent programs. 
Some session type definitions: `!` refers to a send action, `?` refers to a receive action, `&` refers to a branch (external choice), and `+` refers to an (internal) choice.

Session types accept the following grammar and types:

```text
S =
    !label(types, ...).S            (send)
  | ?label(types, ...).S            (receive)
  | &{?label(types, ...).S, ...}    (branch)
  | +{!label(types, ...).S, ...}    (choice)
  | rec X.(S)                       (recurse)
  | X                               (recursion var)
  | end                             (terminate)

types =
  atom
  | boolean
  | number
  | pid
  | nil
  | binary
  | {types, types, ...}             (tuple)
  | [types]                         (list)
```

The following are some session type examples along with the equivalent Elixir code. 


<!-- Session Type  Elixir  Description -->
-   **Send**  
    `!Hello()` - Sends label `:Hello`
    
    Equivalent Elixir code:
    ```elixir
    send(pid, {:Hello})
    ```

-   **Receive**

    `?Ping(number)` - Receives a label `:Ping` with a value of type `number`.  

    Equivalent Elixir code:
    ```elixir
    receive do
      {:Ping, value} -> value
    end
    ```

-   **Branch**

    ```text
    &{ 
      ?Option1().!Hello(number), 
      ?Option2()
    }
    ```
    The process can receive either `{:Option1}` or `{:Option2}`. 
    If the process receives the former, then it has to send `{:Hello}`. 
    If it receives `{:Option2}`, then it terminates.  

    Equivalent Elixir code:
    ```elixir
    receive do
      {:Option1} -> send(pid, {:Hello, 55})
                    # ...
      {:Option2} -> # ...
    end
    ```

-   **Choice**

    ```text
    +{ 
      !Option1().!Hello(number), 
      !Option2()
    }
    ```
    The process can choose either `{:Option1}` or `{:Option2}`. 
    If the process chooses the former, then it has to send `{:Hello}`. 
    If it chooses `{:Option2}`, then it terminates.  

    Equivalent Elixir code:
    ```elixir
    send(pid, {:Option1})
    send(pid, {:Hello, 55})
    # or
    send(pid, {:Option2})
    ```

-   **Recurse**

    ```X = &{?Stop(), ?Retry().X}``` - 
    If the process receives `{:Stop}`, it terminates. 
    If it receives `{:Retry}` it recurses back to the beginning.  
    
    Equivalent Elixir code:
    ```elixir
    def rec() do
      receive do
        {:Stop}  -> # ...
        {:Retry} -> rec()
      end 
    end
    ```


<!-- !Hello().end = Hello() -->

----------

## Using ElixirSessions

To session typecheck a module, insert this line at the top:
```elixir
use STEx
```

Insert any checks using the `@session` attribute followed by a function that should be session type checked, such as:
```elixir
@session "!Ping().?Pong()"
def function(), do: ...
```

The `@dual` attribute checks the dual of the specified session type.
```elixir
@dual &function/0
# Equivalent to: @session "?Ping().!Pong()"
```

In the case of multiple function definitions with the name name and arity (e.g. for pattern matching), define only one session type for all functions.

## Another Example

In the following example, the module `LargerExample` contains two functions that will be typechecked. The first function is typechecked with the session type `!Hello().end` - it expects a single send action containing `{:Hello}`. The second function is typechecked with respect to `rec X.(&{...})` which expects a branch using the receive construct and a recursive call. The `@spec` directives are required to ensure type correctness for the parameters. This example is found in [`larger_example.ex`](/lib/elixirsessions/examples/larger_example.ex):

```elixir
defmodule LargeExample do
  use STEx

  @session "!Hello().end"
  @spec do_something(pid) :: :ok
  def do_something(pid) do
    send(pid, {:Hello})
    :ok
  end

  @session """
              rec X.(&{
                        ?Option1(boolean),
                        ?Option2().X,
                        ?Option3()
                      })
           """
  @spec do_something_else :: :ok
  def do_something_else() do
    receive do
      {:Option1, value} ->
        IO.puts(value)

      {:Option2} ->
        do_something_else()

      {:Option3} ->
        :ok
    end
  end
```

In the next example, session typechecking fails because the session type `!Hello()` was expecting to find a send action with `{:Hello}` but found `{:Yo}`:

```elixir
defmodule Module2 do
  use STEx

  @session "!Hello()"
  @spec do_something(pid) :: {:Yo}
  def do_something(pid) do
    send(pid, {:Yo})
  end
end
```

Output:
```
mix compile
== Compilation error in file example.ex ==
** (throw) "[Line 6] Expected send with label :Hello but found :Yo."
```

Other examples can be found in the [`examples`](https://github.com/gertab/ElixirSessions/tree/master/lib/elixirsessions/examples) folder.
<!-- 
### Features

ElixirSessions implements several features that allow for _session type_ manipulation.
Some of these are shown below, which include: 
 - session type parsing ([`lib/elixirsessions/parser/parser.ex`](/lib/elixirsessions/parser/parser.ex)),
 - session type comparison (e.g. equality) and manipulation (e.g. duality). -->

### Acknowledgements

Some code related to Elixir expression typing was adapted from [typelixir](https://github.com/Typelixir/typelixir) by Cassola (MIT [licence](https://github.com/gertab/ElixirSessions/blob/master/ACK.md)).
