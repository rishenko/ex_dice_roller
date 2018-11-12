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
'('
')'
.

Rootsymbol expr.

Left  600 roll.
Left  500 unary_operator.
Right 400 exp_operator.
Left  300 complex_operator.
Left  200 basic_operator.
Left  100 ','.

expr -> expr ',' expr               : {sep, '$1', '$3'}.
expr -> expr roll expr              : {roll, '$1', '$3'}.
expr -> expr complex_operator expr  : {op('$2'), '$1', '$3'}.
expr -> expr basic_operator expr    : {op('$2'), '$1', '$3'}.
expr -> expr exp_operator expr    : {op('$2'), '$1', '$3'}.

expr -> '(' expr ')'          : '$2'.
expr -> int                   : to_integer('$1').
expr -> float                 : to_float('$1').
expr -> unary_operator        : '$1'.
expr -> var                   : val('$1').

unary_operator -> basic_operator int : val_to_integer(last('$1') ++ last('$2')).
unary_operator -> basic_operator float : val_to_float(last('$1') ++ last('$2')).


Erlang code.

val({T,_,V})  ->  {T, V}.
op({_, _, V}) ->  {operator, V}.
last({_, _, V}) -> V.

to_integer({_, _, V}) -> element(1, string:to_integer(V)).
val_to_integer(V) -> element(1, string:to_integer(V)).
to_float({_, _, V}) -> element(1, string:to_float(V)).
val_to_float(V) -> element(1, string:to_float(V)).