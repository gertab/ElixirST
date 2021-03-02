Nonterminals
session label_sessions types_list sequences sessions. 

Terminals
send recv choice branch sequence types label terminate recurse '{' '}' ':' ',' '(' ')'.

Rootsymbol session.

session -> terminate : nil.
session -> send label '(' ')'                              : {send, unwrap('$2'), [], nil}.
session -> send label '(' types_list ')'                   : {send, unwrap('$2'), '$4', nil}.
session -> send label '(' ')' sessions                     : {send, unwrap('$2'), [], '$5'}.
session -> send label '(' types_list ')' sessions          : {send, unwrap('$2'), '$4', '$6'}.
session -> recv label '(' ')'                              : {recv, unwrap('$2'), [], nil}.
session -> recv label '(' types_list ')'                   : {recv, unwrap('$2'), '$4', nil}.
session -> recv label '(' ')' sessions                     : {recv, unwrap('$2'), [], '$5'}.
session -> recv label '(' types_list ')' sessions          : {recv, unwrap('$2'), '$4', '$6'}.
session -> choice '{' label_sessions '}'                   : {choice, '$3'}.
session -> branch '{' label_sessions '}'                   : {branch, '$3'}.
session -> recurse label sequences '(' session ')'         : {recurse, unwrap('$2'), '$5'}.
session -> recurse label '(' session ')'                   : {recurse, unwrap('$2'), '$4'}.
session -> label                                           : {call_recurse, unwrap('$1')}.

sequences -> sequence                        : nil.
sequences -> sequences sequence              : nil.

sessions -> session                          : '$1'.
sessions -> sequences session                : '$2'.

label_sessions -> session ',' label_sessions : ['$1' | '$3' ].
label_sessions -> session                    : ['$1'].

types_list -> label ':' types                : [unwrap('$3')].
types_list -> types                          : [unwrap('$1')].
types_list -> label ':' types ',' types_list : [unwrap('$3') | '$5' ].
types_list -> types ',' types_list           : [unwrap('$1') | '$3' ].

Erlang code.
unwrap({_, _, V}) -> V.
% unwrap2({_, V}) -> V.
% put_tuple({Key, Value}) -> maps:put(Key,Value, #{}).
% put_tuple({Key, Value}, Other) -> maps:merge(maps:put(Key,Value, #{}), Other).