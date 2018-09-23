Nonterminals
expr
subexpr
.

Terminals
digit
operator
roll
'('
')'
.

Rootsymbol expr.

expr -> digit roll digit : {roll, val('$1'), val('$3')}.
expr -> subexpr roll digit : {roll, '$1', val('$3')}.
expr -> subexpr roll subexpr : {roll, '$1', '$3'}.
expr -> digit roll subexpr : {roll, val('$1'), '$3'}.

expr -> digit operator digit : {val('$2'), val('$1'), val('$3')}.
expr -> digit operator expr : {val('$2'), val('$1'), '$3'}.
expr -> expr operator digit : {val('$2'), '$1', val('$3')}.
expr -> expr operator expr : {val('$2'), '$1', '$3'}.

expr -> digit operator subexpr : {val('$2'), val('$1'), '$3'}.
expr -> subexpr operator digit : {val('$2'), '$1', val('$3')}.
expr -> expr operator subexpr : {val('$2'), '$1', '$3'}.
expr -> subexpr operator expr : {val('$2'), '$1', '$3'}.
expr -> subexpr operator subexpr : {val('$2'), '$1', '$3'}.

subexpr -> '(' expr ')' : '$2'.

expr -> '$empty' : nil.

Erlang code.

val({T,_,V}) -> {T, V}.