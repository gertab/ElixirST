% Compiled - set in mix.exs: erlc_paths: ["lib/stex/parser"]

Definitions.

WHITESPACE  = [\s\t\n\r]
SEND        = send|\!
RECEIVE     = receive|\?
CHOICE      = choice|select|\+
BRANCH      = branch|\&
SEQUENCE    = \.
REC         = rec
LABEL       = [a-zA-Z0-9_/]+
END         = end|End

Rules.

{SEND}         : {token, {send, TokenLine}}.
{RECEIVE}      : {token, {recv, TokenLine}}.
{CHOICE}       : {token, {choice, TokenLine}}.
{BRANCH}       : {token, {branch, TokenLine}}.
{SEQUENCE}     : {token, {sequence, TokenLine}}.
{REC}          : {token, {recurse, TokenLine}}.
{END}          : {token, {terminate, TokenLine}}.
{LABEL}        : {token, {label,  TokenLine, list_to_atom(lists:sublist(TokenChars, 1, TokenLen))}}.
\=             : {token, {'=',  TokenLine}}.
\[             : {token, {'[',  TokenLine}}.
\]             : {token, {']',  TokenLine}}.
\{             : {token, {'{',  TokenLine}}.
\}             : {token, {'}',  TokenLine}}.
\:             : {token, {':',  TokenLine}}.
,              : {token, {',',  TokenLine}}.
\(             : {token, {'(',  TokenLine}}.
\)             : {token, {')',  TokenLine}}.
{WHITESPACE}+  : skip_token.

Erlang code.
