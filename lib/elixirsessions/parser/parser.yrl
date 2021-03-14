Nonterminals
session_type session choice_label_sessions branch_label_sessions types_list sequences sessions. 

Terminals
send recv choice branch sequence label terminate recurse '{' '}' ':' ',' '(' ')' '='.

Rootsymbol session_type.

session_type -> label '='                                  : {nolabel, #terminate{}}.
session_type -> session                                    : {nolabel, '$1'}.
session_type -> label '=' session                          : {unwrap('$1'), '$3'}.

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
session -> label                                           : #call{label=unwrap('$1')}.

sequences -> sequence                                      : nil.
sequences -> sequences sequence                            : nil.

sessions -> session                                        : '$1'.
sessions -> sequences session                              : '$2'.

choice_label_sessions -> session ',' choice_label_sessions : ['$1' | '$3' ].
choice_label_sessions -> session                           : ['$1'].

branch_label_sessions -> session ',' branch_label_sessions : ['$1' | '$3' ].
branch_label_sessions -> session                           : ['$1'].

types_list -> label ':' label                              : [lowercase_atom(unwrap('$3'))].
types_list -> label                                        : [lowercase_atom(unwrap('$1'))].
types_list -> label ':' label ',' types_list               : [lowercase_atom(unwrap('$3')) | '$5' ].
types_list -> label ',' types_list                         : [lowercase_atom(unwrap('$1')) | '$3' ].

Erlang code.

%todo give default
-record(send, {label, types, next}).
-record(recv, {label, types, next}).
-record(choice, {choices}).
-record(branch, {branches}).
-record(recurse, {label, body}).
-record(call, {label}).
-record(terminate, {}).

lowercase_atom(V) -> list_to_atom(string:lowercase(atom_to_list(V))).

unwrap({_, _, V}) -> V.