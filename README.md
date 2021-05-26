# ElixirSessions

[![Elixir CI](https://github.com/gertab/ElixirSessions/actions/workflows/elixir.yml/badge.svg)](https://github.com/gertab/ElixirSessions/actions/workflows/elixir.yml)

ElixirSessions uses *Session Types* to check statically that the Elixir modules use the expected communication structure (e.g. `send`/`receive`) when dealing with message passing between actors. It also ensures that the correct types are being used. For example, the session type `?Add(number, number).!Result(number).end` expects that two numbers are received (i.e. `?`), then a number is sent (i.e. `!`) and finally the session terminates.

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
    {:dep_from_git, git: "https://github.com/gertab/ElixirSessions.git"}
  ]
end
```

{:dep_from_git, git: "https://github.com/gertab/ElixirSessions.git", tag: "0.1.0"}
-->

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/elixirsessions](https://hexdocs.pm/elixirsessions).


## Example

To session typecheck filex in Elixir, add `use ElixirSessions` and include any assertions using `@session` (or `@dual`) attributes preceeding any `def` functions. The following is a simple example ([`small_example.ex`](/lib/elixirsessions/examples/small_example.ex)):
<!-- The `@spec` directives are needed to ensure type correctness for the parameters. -->

```elixir
defmodule SmallExample do
  use ElixirSessions

  @session "!Hello()"
  @spec client(pid) :: {atom()}
  def client(pid) do
    send(pid, {:Hello})
  end

  @dual &SmallExample.client/1
  @spec server() :: atom()
  def server() do
    receive do
      {:Hello} ->
        :ok
    end
  end
end
```

ElixirSessions runs automatically at compile time (`mix compile`) or as a mix task (`mix session_check (module)`):
```
$ mix session_check SmallExample
[info]  Session typechecking for client/1 terminated successfully
[info]  Session typechecking for server/0 terminated successfully
```

If the client were to send a different label (e.g. :Hi) instead of the one specified in the session type (i.e. @session "!Hello()"), ElixirSessions would complain with an error messages:

```
$ mix session_check SmallExample
[error] Session typechecking for client/1 found an error. 
[error] [Line 7] Expected send with label :Hello but found :Hi.
```

## Session Types in Elixir

Session types are used to ensure correct communication between concurrent programs. 
Some session type definitions: `!` refers to a send action, `?` refers to a receive action, `&` refers to a branch (external choice), and `+` refers to an (internal) choice.

Session types accept the following grammar and types:

```
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
  | string
  | binary
  | {types, types, ...}             (tuple)
  | [types]                         (list)
```

The following are some session type examples along with the equivalent Elixir code. 

<table>
<tr>
<td> Session Type </td> <td> Elixir </td> <td> Description </td>
</tr>
<tr>
<td> 

`!Hello()` 
</td>
<td>

```elixir
send(pid, {:Hello})
```
</td>
<td>
Send one label <code>:Hello</code>.
</td>
</tr>
<tr>
<td> 

`?Ping(number)` 
</td>
<td>

```elixir
receive do
  {:Ping, value} -> value
end
```
</td>
<td>
Receive a label <code>:Ping</code> with a value of type <code>number</code>.
</td>
</tr>
<tr>
<td> 

```
&{ 
  ?Option1().!Hello(number), 
  ?Option2()
 }
```

</td>
<td>

```elixir
receive do
  {:Option1} -> send(pid, {:Hello, 55})
                # ...
  {:Option2} -> # ...
end
```
</td>
<td>
The process can receive either <code>{:Option1}</code> or <code>{:Option2}</code>. 
If the process receives the former, then it has to send <code>{:Hello}</code>. 
If it receives <code>{:Option2}</code>, then it terminates.
</td>
</tr>
<tr>
<td> 

```rec X.(&{?Stop(), ?Retry().X})```

</td>
<td>

```elixir
receive do
  {:Stop}  -> # ...
  {:Retry} -> recurse()
end
```
</td>
<td>
If the process receives <code>{:Stop}</code>, then it terminates. 
If it receives <code>{:Retry}</code> it recurses back to the beginning.
</td>
</tr>
</table>

----------

## Using ElixirSessions

To session type check a module, insert this line at the top:
```elixir
use ElixirSessions
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

In the following example, the module `LargerExample` contains two functions that will be typechecked. The first function is typechecked with `@session "!Hello().end"` - it expects a single send action containing `{:Hello}`. The second function is typechecked with `@session "rec X.(&{...})"` which expects a branching using the receive and a recursive call. The `@spec` directives are needed to ensure type correctness for the parameters. This example is found in [`larger_example.ex`](/lib/elixirsessions/examples/larger_example.ex):

```elixir
defmodule LargeExample do
  use ElixirSessions

  @session "!Hello().end"
  @spec do_something(pid) :: :ok
  def do_something(pid) do
    send(pid, {:Hello})
    :ok
  end

  @session """
              rec X.(&{
                        ?Option1(string),
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

In the next example, session type checking fails because the session type `!Hello()` expected to find a send action with `{:Hello}` but found `{:Yo}`:

```elixir
defmodule Module2 do
  use ElixirSessions

  @session "!Hello()"
  @spec do_something(pid) :: {:Yo}
  def do_something(pid) do
    send(pid, {:Yo})
  end
end
```

Output:
```
$ mix compile
== Compilation error in file example.ex ==
** (throw) "[Line 6] Expected send with label :Hello but found :Yo."
```

Other examples can be found in the [`examples`](/lib/elixirsessions/examples) folder.
<!-- 
### Features

ElixirSessions implements several features that allow for _session type_ manipulation.
Some of these are shown below, which include: 
 - session type parsing ([`lib/elixirsessions/parser/parser.ex`](/lib/elixirsessions/parser/parser.ex)),
 - session type comparison (e.g. equality) and manipulation (e.g. duality). -->

### Acknowledgements

Some code related to Elixir expression typing was adapted from [typelixir](https://github.com/Typelixir/typelixir) by Cassola (MIT [licence](ACK)).
