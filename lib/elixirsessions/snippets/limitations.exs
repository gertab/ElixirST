
case value do
  true -> send(pid, {:hello})
  false -> :not_ok # needs send with label
end

choice: %{
  hello: [send: 'type'],
  ??
}


receive do
  {:label, value} ->
    :ok
  {x} ->
    :not_ok # needs label [as atom]
end

branch: %{
  option1: [recv: 'type'],
  ??
}

def abc() do
  def() # assume call only, not session type
end


# certain macrcos are not currently included [todo: expand to case]
e.g. if clause, unless clause, ...
