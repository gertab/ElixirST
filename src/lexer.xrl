Definitions.

WHITESPACE  = [\s\t\n\r]
SEND        = send|\!
RECEIVE     = receive|\?
CHOICE      = choice|select|\+
% todo replace choice w/ select
BRANCH      = branch|\&
SEQUENCE    = \.
TYPES       = (any|atom|binary|bitstring|boolean|exception|float|function|integer|list|map|nil|number|pid|port|reference|struct|tuple|string)
TYPES_UPPER = (Any|Atom|Binary|Bitstring|Boolean|Exception|Float|Function|Integer|List|Map|Nil|Number|Pid|Port|Reference|Struct|Tuple|String) 
% note: String does not have is_string
REC         = rec
LABEL       = [a-zA-Z0-9_]+
END         = end|End

Rules.

{SEND}         : {token, {send, TokenLine}}.
{RECEIVE}      : {token, {recv, TokenLine}}.
{CHOICE}       : {token, {choice, TokenLine}}.
{BRANCH}       : {token, {branch, TokenLine}}.
{SEQUENCE}     : {token, {sequence, TokenLine}}.
{REC}          : {token, {recurse, TokenLine}}.
{END}          : {token, {terminate, TokenLine}}.
{TYPES}        : {token, {types, TokenLine, list_to_atom(lists:sublist(TokenChars, 1, TokenLen))}}.
{TYPES_UPPER}  : {token, {types, TokenLine, list_to_atom(string:lowercase(lists:sublist(TokenChars, 1, TokenLen)))}}.
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

