Nonterminals
expr
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
Left 400 complex_operator.
Left 300 basic_operator.

expr -> expr roll expr              : {roll, '$1', '$3'}.
expr -> expr complex_operator expr  : {op('$2'), '$1', '$3'}.
expr -> expr basic_operator expr    : {op('$2'), '$1', '$3'}.

expr -> '(' expr ')'  : '$2'.
expr -> digit         : val('$1').

Erlang code.

val({T,_,V})  ->  {T, V}.
op({_, _, V}) ->  {operator, V}.