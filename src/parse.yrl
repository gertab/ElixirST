Nonterminals
session sessions label_session label_sessions.

Terminals
send recv choice branch sequence types int atom label '[' ']' '<' '>' ':' ','.

Rootsymbol sessions.

session -> '<' : '$1'.
session -> recv types : {recv, unwrap('$2')}.
session -> send types : {send, unwrap('$2')}.
session -> choice '<' label_session '>' : {choice, '$3'}.
session -> branch '<' label_sessions '>' : {branch, '$3'}.
sessions -> session : ['$1'].
sessions -> session sessions : ['$1' | '$2' ].
sessions -> session sequence sessions : ['$1' | '$3' ].

label_session -> label sessions : {unwrap('$1'), '$2'}.
label_sessions -> label_session ',' label_sessions : ['$1' | '$3'].
label_sessions -> label_session : ['$1'].
% value -> object : '$1'.
% value -> array : '$1'.
% value -> int : unwrap('$1').
% value -> float : unwrap('$1').
% value -> string : unwrap('$1').
% value -> bool : unwrap('$1').
% value -> null : unwrap('$1').

% object -> open_curly pairs close_curly : '$2'.
% object -> open_curly close_curly : #{}.

% pairs -> pair comma pairs : put_tuple('$1', '$3').
% pairs -> pair : put_tuple('$1').
% pair -> string colon value : {unwrap('$1'), '$3'}.

% array -> open_array list close_array : '$2'.
% array -> open_array close_array : [].

% list -> value comma list : ['$1' | '$3'].
% list -> value : ['$1'].

Erlang code.
unwrap({_, _, V}) -> V.
unwrap2({_, V}) -> V.
put_tuple({Key, Value}) -> maps:put(Key,Value, #{}).
put_tuple({Key, Value}, Other) -> maps:merge(maps:put(Key,Value, #{}), Other).