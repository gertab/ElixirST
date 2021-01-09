Definitions.

INT        = [0-9]+
ATOM       = :[a-z_]+
WHITESPACE = [\s\t\n\r]

Rules.

{INT}         : {token, {int,  TokenLine, list_to_integer(TokenChars)}}.
{ATOM}        : {token, {atom, TokenLine, to_atom(TokenChars)}}.
[a-z_]+:      : {token, {key,  TokenLine, list_to_atom(lists:sublist(TokenChars, 1, TokenLen - 1))}}.
\[            : {token, {'[',  TokenLine}}.
\]            : {token, {']',  TokenLine}}.
,             : {token, {',',  TokenLine}}.
{WHITESPACE}+ : skip_token.

Erlang code.

to_atom(Atom) ->
    'Elixir.Helpers':to_atom(Atom).
