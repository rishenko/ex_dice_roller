Nonterminals
expr
unary_operator
.

Terminals
digit
basic_operator
complex_operator
roll
'('
')'
.

Rootsymbol expr.

Left 500 roll.
Left 400 unary_operator.
Left 300 complex_operator.
Left 200 basic_operator.

expr -> expr roll expr              : {roll, '$1', '$3'}.
expr -> expr complex_operator expr  : {op('$2'), '$1', '$3'}.
expr -> expr basic_operator expr    : {op('$2'), '$1', '$3'}.

expr -> '(' expr ')'          : '$2'.
expr -> digit                 : val('$1').
expr -> unary_operator        : '$1'.

unary_operator -> basic_operator digit : {digit, last('$1') ++ last('$2')}.


Erlang code.

val({T,_,V})  ->  {T, V}.
op({_, _, V}) ->  {operator, V}.
last({_, _, V}) -> V.