Definitions.

Number          = [0-9]+
BasicOperator   = [\+\-]
ComplexOperator = [\*\/]
Roll            = d
Space           = [\s]+
LeftParen       = \(
RightParen      = \)

Rules.

{Space}             : skip_token.
{Newline}           : skip_token.
{BasicOperator}     : {token, {basic_operator, TokenLine, TokenChars}}.
{ComplexOperator}   : {token, {complex_operator, TokenLine, TokenChars}}.
{Roll}              : {token, {roll, TokenLine, TokenChars}}.
{LeftParen}         : {token, {'(', TokenLine, TokenChars}}.
{RightParen}        : {token, {')', TokenLine, TokenChars}}.
{Number}            : {token, {digit, TokenLine, TokenChars}}.

Erlang code.
