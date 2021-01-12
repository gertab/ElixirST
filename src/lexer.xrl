Definitions.

INT        = [0-9]+
ATOM       = :[a-zA-Z_]+
WHITESPACE = [\s\t\n\r]
SEND = send
RECEIVE = receive
CHOICE = choice
BRANCH = branch
SEQUENCE = \.
TYPES = '([^']*)'
% TYPES = '([^\\\']|\\.)*'
REC = rec
% rec X.( +{!Guess(num: Int)[num > 0 && num < 10].&{ ?Correct(ans: Int)[ans==num], ?Incorrect().X }, !Quit()} )

Rules.

{SEND}         : {token, {send, TokenLine}}.
{RECEIVE}      : {token, {recv, TokenLine}}.
{CHOICE}       : {token, {choice, TokenLine}}.
{BRANCH}       : {token, {branch, TokenLine}}.
{SEQUENCE}     : {token, {sequence, TokenLine}}.
{REC}          : {token, {recurse, TokenLine}}.
{TYPES}        : {token, {types, TokenLine, lists:sublist(TokenChars, 2, TokenLen - 2)}}.
{INT}          : {token, {int,  TokenLine, list_to_integer(TokenChars)}}.
{ATOM}         : {token, {atom, TokenLine, to_atom(TokenChars)}}.
[a-zA-Z0-9_]+  : {token, {label,  TokenLine, list_to_atom(lists:sublist(TokenChars, 1, TokenLen))}}.
\[             : {token, {'[',  TokenLine}}.
\]             : {token, {']',  TokenLine}}.
\<             : {token, {'<',  TokenLine}}.
\>             : {token, {'>',  TokenLine}}.
\:             : {token, {':',  TokenLine}}.
,              : {token, {',',  TokenLine}}.
\(             : {token, {'(',  TokenLine}}.
\)             : {token, {')',  TokenLine}}.
{WHITESPACE}+  : skip_token.

Erlang code.

to_atom(Atom) ->
    'Elixir.Helpers':to_atom(Atom).
