Nonterminals
session choice_label_sessions branch_label_sessions types_list sequences sessions. 

Terminals
send recv choice branch sequence types label terminate recurse '{' '}' ':' ',' '(' ')'.

Rootsymbol session.

session -> terminate                                       : #terminate{}.
session -> send label '(' ')'                              : #send{label=unwrap('$2'), types=[], next=#terminate{}}.
session -> send label '(' types_list ')'                   : #send{label=unwrap('$2'), types='$4', next=#terminate{}}.
session -> send label '(' ')' sessions                     : #send{label=unwrap('$2'), types=[], next='$5'}.
session -> send label '(' types_list ')' sessions          : #send{label=unwrap('$2'), types='$4', next='$6'}.
session -> recv label '(' ')'                              : #recv{label=unwrap('$2'), types=[], next=#terminate{}}.
session -> recv label '(' types_list ')'                   : #recv{label=unwrap('$2'), types='$4', next=#terminate{}}.
session -> recv label '(' ')' sessions                     : #recv{label=unwrap('$2'), types=[], next='$5'}.
session -> recv label '(' types_list ')' sessions          : #recv{label=unwrap('$2'), types='$4', next='$6'}.
session -> choice '{' choice_label_sessions '}'            : #choice{choices='$3'}.
session -> branch '{' branch_label_sessions '}'            : #branch{branches='$3'}.
session -> recurse label sequences '(' session ')'         : #recurse{label=unwrap('$2'), body='$5'}.
session -> recurse label '(' session ')'                   : #recurse{label=unwrap('$2'), body='$4'}.
session -> label                                           : #call_recurse{label=unwrap('$1')}.

% todo allow only &{?} and not &{!}

sequences -> sequence                        : nil.
sequences -> sequences sequence              : nil.

sessions -> session                          : '$1'.
sessions -> sequences session                : '$2'.

choice_label_sessions -> session ',' choice_label_sessions : ['$1' | '$3' ].
choice_label_sessions -> session                           : ['$1'].

branch_label_sessions -> session ',' branch_label_sessions : ['$1' | '$3' ].
branch_label_sessions -> session                           : ['$1'].

types_list -> label ':' types                : [unwrap('$3')].
types_list -> types                          : [unwrap('$1')].
types_list -> label ':' types ',' types_list : [unwrap('$3') | '$5' ].
types_list -> types ',' types_list           : [unwrap('$1') | '$3' ].

Erlang code.

%todo give default
-record(send, {label, types, next}).
-record(recv, {label, types, next}).
-record(choice, {choices}).
-record(branch, {branches}).
-record(recurse, {label, body}).
-record(call_recurse, {label}).
-record(terminate, {}).

unwrap({_, _, V}) -> V.
% unwrap2({_, V}) -> V.
% put_tuple({Key, Value}) -> maps:put(Key,Value, #{}).
% put_tuple({Key, Value}, Other) -> maps:merge(maps:put(Key,Value, #{}), Other).
