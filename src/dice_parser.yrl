Nonterminals
expr
unary_operator
.

Terminals
var
int
float
basic_operator
complex_operator
exp_operator
','
roll
modifier
'('
')'
.

Rootsymbol expr.

Left  600 roll.
Left  550 modifier.
Unary 500 unary_operator.
Right 400 exp_operator.
Left  300 complex_operator.
Left  200 basic_operator.
Left  100 ','.

expr -> expr ',' expr               : {sep, '$1', '$3'}.
expr -> expr roll expr              : {roll, '$1', '$3'}.
expr -> expr modifier               : add_modifier('$1', '$2').
expr -> expr complex_operator expr  : {op('$2'), '$1', '$3'}.
expr -> expr basic_operator expr    : {op('$2'), '$1', '$3'}.
expr -> expr exp_operator expr      : {op('$2'), '$1', '$3'}.

expr -> '(' expr ')'          : '$2'.
expr -> int                   : to_integer('$1').
expr -> float                 : to_float('$1').
expr -> unary_operator        : '$1'.
expr -> var                   : val('$1').

unary_operator -> basic_operator expr : unary(last('$1'), '$2').


Erlang code.

val({T,_,V})  ->  {T, V}.

% the tokenizer only emits modifiers directly after a roll
add_modifier({roll, N, S}, {modifier, _, M}) -> {roll, N, S, [M]};
add_modifier({roll, N, S, Ms}, {modifier, _, M}) -> {roll, N, S, Ms ++ [M]};
add_modifier(_, {modifier, Line, _}) -> return_error(Line, "dice modifiers must follow a roll").
op({_, _, V}) ->  {operator, V}.
last({_, _, V}) -> V.

to_integer({_, _, V}) -> element(1, string:to_integer(V)).
to_float({_, _, V}) -> element(1, string:to_float(V)).

% A sign on a number is folded into it; on anything else, `-E` is `0 - E`,
% which also negates each value of a list.
unary("+", E) -> E;
unary("-", N) when is_number(N) -> -N;
unary("-", E) -> {{operator, "-"}, 0, E}.