# ElixirSessions

![Elixir CI](https://github.com/gertab/ElixirSessions/workflows/Elixir%20CI/badge.svg)

**TODO: Add description**

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `elixirsessions` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:elixirsessions, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/elixirsessions](https://hexdocs.pm/elixirsessions).

## Session Types in Elixir

Session types are used to ensure correct communication between concurrent programs. 
Some session type definitions: `!` refers to a send action, `?` refers to a receive action, `&` refers to a branch (external choice), and `+` refers to an (internal) choice.

Session types accept the following grammar:

```
S =
    !label(types, ...).S
  | ?label(types, ...).S
  | &{?label(types, ...).S, ...}
  | +{!label(types, ...).S, ...}
  | rec X.(S)
  | X
  | end
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
  {:Ping, value} -> # ...
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

To session type check a module, insert this line:
```elixir
use ElixirSessions.Checking
```

Insert any checks using the `@session` attribute followed by a function that should be session type checked, such as:
```elixir
@session "!Ping().?Pong()"
def function(), do: ...
```

In the case of multiple function definitions with the name name and arity (for pattern matching), define only one session type for all functions.

## Example

In the following example, `Module1` contains two functions that will be type checked. The first function is type checked with `@session "!Hello().end"` - it expects a single send action containing `{:Hello}`. The second function is type checked with `@session "rec X.(&{...})"` which expects a branching using the receive and a recursive call.

```elixir
defmodule Module1 do
  use ElixirSessions.Checking

  @session "!Hello().end"
  def do_something(pid) do
    send(pid, {:Hello})
  end

  @session """
              rec X.(&{
                        ?Option1(string),
                        ?Option2().X,
                        ?Option3()
                      })
           """
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
end
```

In the next example, session type checking fails because the session type `!Hello()` expected to find a send action with `{:Hello}` but found `{:Yo}`:
```elixir
defmodule Module2 do
  use ElixirSessions.Checking

  @session "!Hello()"
  def do_something(pid) do
    send(pid, {:Yo})
  end
end
```

Output:
```
$ mix compile
...
== Compilation error in file example.ex ==
** (throw) "[Line 6] Expected send with label :Hello but found :Yo."
    ...
```

Other examples can be found in the [`lib/elixirsessions/examples`](/lib/elixirsessions/examples) folder.

### Features

ElixirSessions implements several features that allow for _session type_ manipulation.
Some of these are shown below, which include: 
 - string parsing ([`lib/elixirsessions/parser.ex`](/lib/elixirsessions/parser.ex)),
 <!-- - ~~code synthesizer from session types ([`lib/elixirsessions/generator.ex`](/lib/elixirsessions/generator.ex)),~~
 - ~~session type inference from code ([`lib/elixirsessions/inference.ex`](/lib/elixirsessions/inference.ex)),~~ -->
 - session type comparison (e.g. equality) and manipulation (e.g. duality).

#### Parsing

To parse an input string to session types (as Elixir data), use the function `string_to_st/1` from module [`ST`](/lib/elixirsessions/session_type.ex) (stands for _Session Types_).
      
```elixir
iex> s  = "!Hello(Integer)"
...> st = ST.string_to_st(s)
# Stored internally as a tree of Structs
...> st
%ST.Send{label: :Hello, next: %ST.Terminate{}, types: [:integer]}
```

<!-- #### Generator (not updated)

To synthesize (or generate) Elixir code from a session type use the functions `generate_quoted/1` or `generate_to_string/1`. 
These automatically generate the quoted (i.e. AST) or stringified Elixir code respectively. 

Example:

```elixir
iex> s         = "!hello(number).?hello_ret(number)"
...> st        = ST.string_to_st(s)
...> st_string = ST.generate_to_string(st)
``` -->

Generates the following automatically:

```elixir
iex> st_string
def func() do
  send(pid, {:hello})
  receive do
    {:hello_ret, var1} when is_number(var1) ->
      :ok
  end
end
```
#### Duality

Given a session type, `dual/1` returns its dual session type. 
For example, the dual of a send is a receive (e.g. `!Hello()` becomes `?Hello()`), and vice versa. The dual of a branch is a choice (e.g. `&{?Option1(), ?Option2()}` becomes `+{!Option1(), !Option2()}`). 
Recursive operations remain unaffected.

Example:

```elixir
iex> st_string = "!Ping(Integer).?Pong(String)"
...> st = ST.string_to_st(st_string)
...> st_dual = ST.dual(st)
...> ST.st_to_string(st_dual)
"?Ping(integer).!Pong(string)"
```

<!-- #### Inference (Depreciated)

Given quoted Elixir code, _ElixirSessions_ can infer the equivalent session type. To do so, use the function `ElixirSessions.Inference.infer_session_type/2`.

The following shown an example which contains send/receive statements and branch/choice options:

```elixir
iex> ast = quote do
...>   def ping(pid) do
...>     send(pid, {:label})
...>     receive do
...>       {:do_something} -> :ok
...>       {:do_something_else, value} -> send(pid, {:label2, value})
...>     end
...>     a = true
...>     case a do
...>       true -> send(pid, {:first_branch})
...>       false -> send(pid, {:other_branch})
...>     end
...>   end
...> end
...> st = ElixirSessions.Inference.infer_session_type(:ping, ast)
...> ST.st_to_string(st)
"!label().
  &{ 
     ?do_something().+{!first_branch(), !other_branch()}, 
     ?do_something_else(any).!label2(any).
       +{ 
          !first_branch(), 
          !other_branch()
        }
   }"
``` -->

#### Session type-checking

...