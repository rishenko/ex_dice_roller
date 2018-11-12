Definitions.

Number          = [0-9]+
BasicOperator   = [\+\-]
ComplexOperator = [\*\/%]
ExponOperator   = \^
Roll            = d
Space           = [\s\t\n\r]+
LeftParen       = \(
RightParen      = \)
Variable        = [a-zA-Z]
Separator       = ,

Rules.

{Space}             : skip_token.
{ExponOperator}               : {token, {exp_operator, TokenLine, TokenChars}}.
{BasicOperator}     : {token, {basic_operator, TokenLine, TokenChars}}.
{ComplexOperator}   : {token, {complex_operator, TokenLine, TokenChars}}.
{Roll}              : {token, {roll, TokenLine, TokenChars}}.
{LeftParen}         : {token, {'(', TokenLine, TokenChars}}.
{RightParen}        : {token, {')', TokenLine, TokenChars}}.
{Number}            : {token, {int, TokenLine, TokenChars}}.
{Number}\.{Number}  : {token, {float, TokenLine, TokenChars}}.
{Variable}          : {token, {var, TokenLine, TokenChars}}.
{Separator}         : {token, {',', TokenLine, TokenChars}}.

Erlang code.
