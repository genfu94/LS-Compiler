%{
    #include "y.tab.h"
    #include <string.h>
%}

integer_num        		[0]|[1-9][0-9]*
floating_num			{integer_num}\.[0-9]*[1-9]
string_const			\"(\ |\\.|[^"])*\"
char_const		   		\'[^']\'

%%
[ \t\n\r]+				{ /*Ignore spaces*/ }
printf					{ return PRINTF; }
scanf					{ return SCANF; }
return					{ return RETURN; }
if						{ return IF; }
else					{ return ELSE; }
then					{ return THEN; }
loop					{ return LOOP; }
new						{ return NEW; }
free					{ return FREE; }
newtype					{ return NEWTYPE; }
newvars					{ return NEWVARS; }
array					{ return ARRAY; }
record					{ return RECORD; }
func					{ return FUNC; }
begin 					{ return BEG; }
end 					{ return END; }
true					{ yylval.stringa = strdup(yytext); return TRUE_CONST; }
false					{ yylval.stringa = strdup(yytext); return FALSE_CONST; }
&&						{ yylval.stringa = strdup(yytext); return LOGIC_AND; }
\|\| 					{ yylval.stringa = strdup(yytext); return LOGIC_OR; }
! 						{ yylval.stringa = strdup(yytext); return BITWISE_NOT; }
(\<\=) 					{ yylval.stringa = strdup(yytext); return RELOP; }
(\>\=) 					{ yylval.stringa = strdup(yytext); return RELOP; }
(\<) 					{ yylval.stringa = strdup(yytext); return RELOP; }
(\>) 					{ yylval.stringa = strdup(yytext); return RELOP; }
(\=\=) 					{ yylval.stringa = strdup(yytext); return RELOP; }
(\!\=)					{ yylval.stringa = strdup(yytext); return RELOP; }
\?\=					{ yylval.stringa = strdup(yytext); return LAZY_ASS; }
{integer_num} 			{ yylval.stringa = strdup(yytext); return INTEGER_NUM; }
{floating_num} 			{ yylval.stringa = strdup(yytext); return FLOATING_NUM; }
[a-zA-Z][_0-9a-zA-Z]*	{ yylval.stringa = strdup(yytext); return IDENTIFIER; }
{char_const}			{ yylval.stringa = strdup(yytext); return CHAR_CONST; }
{string_const} 			{ yylval.stringa = strdup(yytext); return STRING_CONST; }
.						{ return yytext[0]; }
%%

