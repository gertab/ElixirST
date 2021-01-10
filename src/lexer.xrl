Definitions.

INT        = [0-9]+
ATOM       = :[a-z_]+
WHITESPACE = [\s\t\n\r]
SEND = send
RECEIVE = receive
SEND_CHOICE = send_choice
OFFER_OPTION = offer_option
SEQUENCE = .
TYPES = '([^\\\"]|\\.)*'

Rules.

{SEND}         : {token, {send, TokenLine}}.
{RECEIVE}      : {token, {recv, TokenLine}}.
{SEND_CHOICE}  : {token, {send_choice, TokenLine}}.
{OFFER_OPTION} : {token, {offer_option, TokenLine}}.
{SEQUENCE}     : {token, {sequence, TokenLine}}.
{TYPES}        : {token, {types, TokenLine, lists:sublist(TokenChars, 2, TokenLen - 2)}}.
{INT}          : {token, {int,  TokenLine, list_to_integer(TokenChars)}}.
{ATOM}         : {token, {atom, TokenLine, to_atom(TokenChars)}}.
[a-z_]+:       : {token, {key,  TokenLine, list_to_atom(lists:sublist(TokenChars, 1, TokenLen - 1))}}.
\[             : {token, {'[',  TokenLine}}.
\]             : {token, {']',  TokenLine}}.
\<             : {token, {'<',  TokenLine}}.
\>             : {token, {'>',  TokenLine}}.
\:             : {token, {':',  TokenLine}}.
,              : {token, {',',  TokenLine}}.
{WHITESPACE}+  : skip_token.

Erlang code.

to_atom(Atom) ->
    'Elixir.Helpers':to_atom(Atom).
