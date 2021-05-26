# Future Improvements

### ElixirSessions.Checking Module
- [ ] Replace ElixirSessions.Checking by ElixirSessions
- [ ] Add custom options  (e.g. use ElixirSessions.Checking)
- [ ] Replace throws by Logger
- [ ] allow `@dual &fun/1` instead of having to include the module (e.g. `@dual &Module.Submodule.fun/1`)

### ElixirSessions.Retriever Module
- [ ] Ensure that process/2 is only called once (in mix task and in @after_compile)
- [x] Execute session typecheck from BEAM (rather than rely on @after_compile), a la ExUnit - can be done using `mix session_check Module`

### ElixirSessions.SessionType Module
- [ ] Improve examples, docs and doctests
- [ ] Add spawn(server_fn, server_args, client_fn, client_args) that spawns two actors, exchanges their pids and calls the server/client functions
- [ ] Unfold multiple e.g. rec X.rec Y.(!A().X)

### ElixirSessions.SessionTypechecking Module
- [ ] Improve error messages
- [ ] Logger should accept different levels (:debug, :info, :warn & :error)
- [ ] Ignore variable type starting with _, e.g. _var = 7
- [ ] Include aliases
- [ ] Prettify Erlang output since some custom operators (e.g. :"=:=" is equivalent to the Elixir operator :===)
- [ ] Typecheck pin operator: ^x
- [ ] Pattern matching in receive: match labels with receive, thus allowing multiple pattern matching cases with the same label

### Parser Module
- [ ] Invalidate unused and infinite (or empty) recursion: e.g. rec Y.rec X.Y
- [ ] Improve error messages (e.g. replace {:illegal, '#'})
- [ ] Maybe convert branches with one option to receive statements (resp. Choice for send operations)
