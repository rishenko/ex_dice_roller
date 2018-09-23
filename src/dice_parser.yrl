Nonterminals
expr
.

Terminals
digit
operator
roll
'('
')'
.

Rootsymbol expr.

Left 500 roll.

expr -> expr roll expr : {roll, '$1', '$3'}.
expr -> expr operator expr : {val('$2'), '$1', '$3'}.

expr -> '(' expr ')' : '$2'.
expr -> digit : val('$1').
expr -> '$empty' : nil.

Erlang code.

val({T,_,V}) -> {T, V}.