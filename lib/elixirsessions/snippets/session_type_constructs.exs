
# Send type
send = "send 'any'"
send_session_type = [send: 'any']

# Receive type
recv = "receive 'any'"
receive_session_type = {:ok, [recv: 'any']}

# Sequence type
sequence = "send 'any' . receive 'any'"
sequence_session_type = [send: 'any', recv: 'any']

# Branch type
branch = "branch<neg: send 'any', neg2: send 'any'>"
branch_session_type = [branch: %{neg: [send: 'any'], neg2: [send: 'any']}]

# Choice type
choice = "choice<neg: send 'any'>"
choice_session_type = [choice: %{neg: [send: 'any']}]

# Recursice types
recursive = "rec X . (send 'any' . X)"
recursice_session_type = [{:recurse, :X, [send: 'any', call_recurse: :X]}]
