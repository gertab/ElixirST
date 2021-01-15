Nonterminals
session sessions label_sessions.

Terminals
send recv choice branch sequence types int atom label recurse '<' '>' ':' ',' '(' ')'.

Rootsymbol sessions.

session -> recv types : {recv, unwrap('$2')}.
session -> send types : {send, unwrap('$2')}.
session -> label : {call_recurse, unwrap('$1')}.
session -> choice '<' label_sessions '>' : {choice, '$3'}.
session -> branch '<' label_sessions '>' : {branch, '$3'}.
session -> recurse label sequence '(' sessions ')' : {recurse, unwrap('$2'), '$5'}.
session -> recurse label '(' sessions ')' : {recurse, unwrap('$2'), '$4'}.

sessions -> session : ['$1'].
sessions -> session sessions : ['$1' | '$2' ].
sessions -> session sequence sessions : ['$1' | '$3' ].

label_sessions -> label ':' sessions ',' label_sessions : '$5'#{unwrap('$1') => '$3'}.
label_sessions -> label ':' sessions : #{unwrap('$1') => '$3'}.

Erlang code.
unwrap({_, _, V}) -> V.
% unwrap2({_, V}) -> V.
% put_tuple({Key, Value}) -> maps:put(Key,Value, #{}).
% put_tuple({Key, Value}, Other) -> maps:merge(maps:put(Key,Value, #{}), Other).