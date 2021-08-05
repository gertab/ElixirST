# Session Types in Elixir

[![Elixir CI](https://github.com/gertab/STEx/actions/workflows/elixir.yml/badge.svg)](https://github.com/gertab/STEx/actions/workflows/elixir.yml)

STEx (**S**ession **T**ypes in **E**li**x**ir) applies *Session Types* to a part of the Elixir language. It statically checks that the programs use the correct communication structures (e.g. `send`/`receive`) when dealing with message passing between processes. It also ensures that the correct types are being used. For example, the session type `?Add(number, number).!Result(number).end` expects that two numbers are received (i.e. `?`), then a number is sent (i.e. `!`) and finally the session terminates.

## Example

To session typecheck modules in Elixir, add `use STEx` and include any assertions using the annotations `@session` and `@dual` preceding any public function (`def`). The following is a [`simple example`](/lib/stex/examples/small_example.ex):
<!-- The `@spec` directives are needed to ensure type correctness for the parameters. -->

```elixir
defmodule Example do
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

ElixirSessions runs automatically at compile time (`mix compile`) or as a mix task (`mix sessions (module)`):
```text
$ mix sessions SmallExample
[info]  Session typechecking for client/1 terminated successfully
[info]  Session typechecking for server/0 terminated successfully
```

If the client sends a different label (e.g. :Hi) instead of the one specified in the session type (i.e. `@session "!Hello()"`), ElixirSessions will complain:

```text
$ mix sessions Examples.SmallExample
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
  | atom
  | pid
  | {types, types, ...}             (tuple)
  | [types]                         (list)
```

----------

## Using STEx


### Installation

The package can be installed by adding `stex_elixir` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:stex_elixir, "~> 0.4.2"}
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

Documentation can be found at [https://hexdocs.pm/stex_elixir](https://hexdocs.pm/stex_elixir/docs.html).

### Use in Elixir modules

To session typecheck a module, insert this line at the top:
```elixir
use STEx
```

Insert any checks using the `@session` attribute followed by a function that should be session type checked, such as:
```elixir
@session "pinger = !Ping().?Pong()"
def function(), do: ...
```

The `@dual` attribute checks the dual of the specified session type.
```elixir
@dual "pinger"
# Equivalent to: @session "?Ping().!Pong()"
```

<!-- In the case of multiple function definitions with the name name and arity (e.g. for pattern matching), define only one session type for all functions. -->

Other examples can be found in the [`examples`](/lib/stex/examples) folder.
<!-- 
### Features

ElixirSessions implements several features that allow for _session type_ manipulation.
Some of these are shown below, which include: 
 - session type parsing ([`lib/elixirsessions/parser/parser.ex`](/lib/elixirsessions/parser/parser.ex)),
 - session type comparison (e.g. equality) and manipulation (e.g. duality). -->

### Acknowledgements

Some code related to Elixir expression typing was adapted from [typelixir](https://github.com/Typelixir/typelixir) by Cassola (MIT [licence](ACK)).

This project is licenced under the GPL-3.0 licence.