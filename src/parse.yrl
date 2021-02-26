Nonterminals
session sessions label_sessions types_list.

Terminals
send recv choice branch sequence types label recurse '{' '}' ':' ',' '(' ')'.

Rootsymbol sessions.

session -> recv label '(' ')' : {recv, unwrap('$2'), []}.
session -> send label '(' ')' : {send, unwrap('$2'), []}.
session -> recv label '(' types_list ')' : {recv, unwrap('$2'), '$4'}.
session -> send label '(' types_list ')' : {send, unwrap('$2'), '$4'}.
session -> choice '{' label_sessions '}' : {choice, '$3'}.
session -> branch '{' label_sessions '}' : {branch, '$3'}.
session -> recurse label sequence '(' sessions ')' : {recurse, unwrap('$2'), '$5'}.
session -> recurse label '(' sessions ')' : {recurse, unwrap('$2'), '$4'}.
session -> label : {call_recurse, unwrap('$1')}.

sessions -> session : ['$1'].
sessions -> session sessions : ['$1' | '$2' ].
sessions -> session sequence sessions : ['$1' | '$3' ].

label_sessions -> sessions ',' label_sessions : ['$1' | '$3' ].
label_sessions -> sessions : ['$1'].

types_list -> label ':' types : [unwrap('$3')].
types_list -> types : [unwrap('$1')].
types_list -> label ':' types ',' types_list : [unwrap('$3') | '$5' ].
types_list -> types ',' types_list : [unwrap('$1') | '$3' ].

Erlang code.
unwrap({_, _, V}) -> V.
% unwrap2({_, V}) -> V.
% put_tuple({Key, Value}) -> maps:put(Key,Value, #{}).
% put_tuple({Key, Value}, Other) -> maps:merge(maps:put(Key,Value, #{}), Other).