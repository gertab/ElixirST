# Input session type
@session "receive '{label}' . branch<add: receive '{number, number, pid}' . send '{number}', neg: receive '{number, pid}' . send '{number}'>"

# Processed session types [automated]
session_type = [
  recv: '{label}',
  branch: %{
    add: [recv: '{number, number, pid}', send: '{number}'],
    neg: [recv: '{number, pid}', send: '{number}']
  }
]

# Dual of session_type [automated]
dual_session_type = [
   send: '{label}',
   choice: %{
     add: [send: '{number, number, pid}', recv: '{number}'],
     neg: [send: '{number, pid}', recv: '{number}']
   }
 ]
