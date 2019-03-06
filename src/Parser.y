%{
	#include <stdio.h>
	#include <stdlib.h>
	#include <string.h>
	#include "SymbolTable.h"
	#include "Vector.h"
	#include "Stack.h"
	#include "ExpressionEvaluation.h"
	
	extern FILE *yyin;
	FILE* firstParse;
	FILE* funcsHeader;
	FILE* funcsDef;
	FILE* lazyFuncs;
	FILE* cSourceOut;
	FILE* cSourceOutApp;
	FILE* types;
	
	//Riferimento alla tabella dei simboli attualmente in uso (può puntare o a symTab o a functionScope)
	struct SymbolTable* currSymTab;
	
	//Struttura usata per il calcolo di espressioni
	struct ExpressionValue {
		char* exprType;
		char* exprString;
		int containsArrays;
		int containsRecords;
		int containsUninitializedVariables;
		int containsFuncCalls;
	};
	
	//Struttura usata per tenere traccia delle chiamate a funzioni
	struct FuncCallStruct {
		struct FuncInfo* fi;
		int funcCallArgIndex;
	};
	
	//Necessario durante la dichiarazione di variabili
	int typeArrayDimensionIndex;
	
	//Mi tiene traccia di tipi non specificati in un dato momento, che dovranno essere verificati poi alla fine 
	//della dichiarazione dei tipi
	Vector typesToDeclare;
	
	//Usati durante la dichiarazione di tipi e variabili
	struct TypeInfo* tp;
	struct VarInfo* vp;
	
	//Necessarie al parsing delle espressioni
	//struct TypeInfo* tpExpr;
	Stack exprStack;
	struct VarInfo* vpExpr;
	
	//Needed for functions implementation
	char* funcName;
	struct FuncInfo* funcImplInfo;
	struct FuncInfo* lazyFuncImplInfo;
	//Contiene il tipo di ritorno della funzione, usata duranta la seconda parsata del sorgente ls
	char* funcImplRetType = NULL;
	//Contiene il numero di return statement presenti nella funzione
	int funcImplRetNum = 0;
	
	//Stack per le chiamate di funzione
	Stack funcCallInfo;
	
	//Se vale uno allora esegue le inizializzazione delle variabili globali.
	int initialized = 0;
	
	//Se vale uno allora esegue i controlli semantici sugli statement altrimenti li salta.
	int eval = 0;
	
	//Usato per inserire "->array" quando si fa accesso all'elemento di un array
	int arrowForArrayAccess = 1;
	
	//Se vale uno allora durante il parsing di newvars aggiunge le variabili parsate alla tabella dei 
	//simboli corrente
	int addVariables = 1;
	
	//Se vale uno allora stampa dentro "funcsHeader" e "funcsDef" rispettivamente i prototipi e le definizioni
	//delle funzioni di copia dei tipi
	int printCopyFunc = 1;
	
	//Utilizzato per dare il nome alle funzioni che tengono memorizzate le espressioni che sono parte destra
	//di un assegnamento lazy
	int lazyFuncID = 0;
	
	//Utilizzato per dare il nome agli argomenti delle funzioni su citate
	int lazyArgID = 0;
	
	//In un dato istante contiene il nome della funzione lazy che si sta attualmente creando
	char* lazyFuncLexprName;
	
	//Utilizzato per la stampa delle variabili durante la loro dichiarazione: se firstVar=1 allora non inserisce
	//'*' dopo il printing del tipo (nel caso in cui quest'ultimo sia un puntatore), altrimenti lo inserisce
	int firstVar = 0;
	
	char* varName;
	
	char* varDeclName;
%}

%token NEWTYPE NEWVARS FUNC ARRAY RECORD BEG END START NEW FREE LOOP IF ELSE THEN RETURN PRINTF SCANF FLOATING_CAST LAZY_ASS
%token <stringa> IDENTIFIER
%token <stringa> INTEGER_NUM FLOATING_NUM  STRING_CONST TRUE_CONST FALSE_CONST CHAR_CONST LOGIC_AND LOGIC_OR BITWISE_NOT RELOP
%type <stringa> array_dim_expr array_dim_mul_expr array_dim_primary
%type <stringa> var_decl var_declaration_section var_decl_type var_decl_stmt var_decl_stmt_var var_decl_stmt_list var_decl_stmt_assign var_decl_stmt_comma
%type <exprValue> expr_first expr_second expr_third expr_fourth expr_fifth expr_sixth
%type <exprValue> var_location_first var_location_second record_access var_location_type array_location
%type <exprValue> func_call func_call_start func_call_arg_list func_call_other_args func_call_arg_param
%type <exprValue> lexpr_first lexpr_second lexpr_array_loc lexpr_record lexpr_type
%type <stringa> loop_start if_start printf_start printf_arg printf_arg_list printf_end scanf_start scanf_arg scanf_arg_list

%union {
	char* stringa;
	struct ExpressionValue* exprValue;
}

%%
entry_point:	compiler_initialization type_declaration_section var_declaration_section function_decl_list { }
				;

compiler_initialization:	{
								//Alla prima parsata del file sorgente inizializziamo tutto quello che ci serve
								if(!initialized) {
									currSymTab = symTab;
									
									firstParse = fopen("FirstParse.txt", "w");
									funcsHeader = fopen("FuncsHeader.txt", "w+");
									funcsDef = fopen("FuncsDef.txt", "w+");
									lazyFuncs = fopen("LazyFuncs.txt", "w+");
									types = fopen("Types.txt", "w+");
									cSourceOutApp = fopen("cSourceOutApp.txt", "w+");
									
									//TODO:Ancora co sto coso!?!? Usare la libreria stack invece...
									s = (char**) malloc(sizeof(char*) * STACK_SIZE);
									
									createStack(funcCallInfo);
									stackInit(funcCallInfo);
									
									createStack(exprStack);
									stackInit(exprStack);
									
									//Così qui poi non ci entro più
									initialized = 1;
								}
							}
							;
							
/******Questa produzione la parso alla fine della sezione di dichiarazione dei tipi********/
type_declaration_section:	{ /*Do nothing*/ }
						|	type_decl type_declaration_section { /*Do nothing*/ }
							;

type_decl:	type_decl_tok type_array_decl ';'{ /*Do nothing*/ }
		|	type_decl_tok type_record_decl ';' { /*Do nothing*/ }
			;

type_decl_tok:	NEWTYPE	{ if(!eval) { fprintf(firstParse, "newtype "); } }
				;

type_array_decl:	type_array_name type_array_dimension_list ')'
					{
						if(!eval) {
							//Quando arrivo qua allora le dimensioni dell'array sono state tutte specificate;
							//memorizzo dunque nell'apposito campo della struttura il numero di dimensioni che sono
							//state indicate (nella variabile typeArrayDimensionIndex che di volta in volta viene incrementata)
							tp->typeValue.arrayValue.totDimensions = typeArrayDimensionIndex;
						
							addType(tp);
						
							//VARIABILE GLOBALE: la resetto a zero nel caso in cui qualcuno poi ci va a lavorare sopra ignaro che
							//questa produzione va a metterci mano sopra
							typeArrayDimensionIndex = 0;
							
							fprintf(firstParse, ");\n");
						} else {
							fprintf(types, ";\n};\n");
						}
					}
					;
					
/*******Questa produzione mi parsa tutta la prima parte della dichiarazione di un nuovo tipo con array come costruttore******/
type_array_name:	IDENTIFIER ARRAY '(' IDENTIFIER
					{
						if(!eval) {
							//Preparo un oggetto della classe TypeInfo che andrò a riempire durante il parsing del "newtype"
							tp = (struct TypeInfo*) malloc(sizeof(struct TypeInfo));
						
							tp->typeName = strdup($1);
						
							//Mi preparo a parsare le dimensioni dell'array...ad ogni dimensione parsata incremento di uno questa var
							typeArrayDimensionIndex = 0;
						
							if(searchType($1)) { yyerror(buildString("Type ", buildString($1, " already defined"))); }
						
							tp->typeConstructor = ARR;
							tp->typeValue.arrayValue.arrayType = strdup($4);
							
							fprintf(firstParse, "%s array(%s", $1, $4);
						} else {
							if(!searchType($4)) { yyerror(buildString("Type ", buildString($4, " not defined"))); }
							fprintf(types, "struct %s {\n\t%s array", $1, getCTypeEquivalent($4));
						}
					}
                    ;

/********Questa produzione mi parsa tutte le dimensione specificate nella costruzione di un tipo array******/
type_array_dimension_list:	{ /*Do nothing*/ }
							| array_dimension_decl type_array_dimension_list { /*Do nothing*/ }
							;

/*******Questa produzione mi parsa una singola dimensione di un tipo array durante la sua specifica*********/
array_dimension_decl:	',' array_dim_expr
						{
							if(!eval) {							
								typeArrayDimensionIndex++;
								
								fprintf(firstParse, ", %s", $2);
							} else {
								char* numericalExpr = variableExprToValueExpr($2);
								if(numericalExpr == NULL) { yyerror("Error during array dimension parsing"); }
								tp->typeValue.arrayValue.dimensions[typeArrayDimensionIndex].integerDim = evaluateString(numericalExpr);
								fprintf(types, "[%d]", tp->typeValue.arrayValue.dimensions[typeArrayDimensionIndex].integerDim);
							}
						}
						;

/*************************************************************************************************************
*****************Grammatica per le espressioni che possono comparire come dimensione di array*****************
*************************************************************************************************************/
array_dim_expr:	array_dim_expr '+' array_dim_mul_expr {	$$ = buildString($1, buildString("+", $3));	}
			|	array_dim_expr '-' array_dim_mul_expr { $$ = buildString($1, buildString("-", $3));	}
			|	array_dim_mul_expr { $$ = strdup($1); }
			;

array_dim_mul_expr:	array_dim_mul_expr '*' array_dim_primary { $$ = buildString($1, buildString("*", $3)); }
				|	array_dim_mul_expr '/' array_dim_primary { $$ = buildString($1, buildString("/", $3)); }
				|	array_dim_primary
				;

array_dim_primary:	IDENTIFIER { $$ = strdup($1); }
				|	INTEGER_NUM { $$ = strdup($1); }
				|	'(' array_dim_expr ')' { $$ = strdup($2); }
				;
/*************************************************************************************************************
**************************************************************************************************************
*************************************************************************************************************/

/*************************************************************************************************************
************************************Grammatica per le dichiarazioni di tipo***********************************
*************************************************************************************************************/
type_record_decl:	type_record_name type_record_field_decl type_record_field_list ')'
					{
						if(!eval) {
							addType(tp);
							fprintf(firstParse, ");\n");
						} else {
							fprintf(types, "};\n");
						}
					}
					;

type_record_name:	IDENTIFIER RECORD '('
					{
						if(!eval) {
							//Alloco l'oggetto di tipo TypeInfo che andrò a riempire man mano durante il parsing del "newtype"
							tp = (struct TypeInfo*) malloc(sizeof(struct TypeInfo));
						
							//Alloco il vettore per mantenere la lista dei campi del record
							createVector(tp->typeValue.recordFields);
							initVector(tp->typeValue.recordFields);
						
							if(searchType($1)) { yyerror(buildString("Type ", buildString($1, " already defined"))); }
							tp->typeName = strdup($1);
							tp->typeConstructor = REC;
							
							fprintf(firstParse, "%s record(", $1);
						} else {
							fprintf(types, "struct %s {\n", $1);
						}
					}
					;

type_record_field_list:	{ /*Do nothing*/ }
						| type_record_field_comma type_record_field_decl type_record_field_list { /*Do nothing*/ }
						;

type_record_field_comma:	',' { if(!eval) { fprintf(firstParse, ", "); } }
							;

type_record_field_decl:	IDENTIFIER IDENTIFIER
						{
							if(!eval) {						
								//Mi preparo ad inserire il nuovo campo nella struttura del record...
								struct RecordField* newField = (struct RecordField*) malloc(sizeof(struct RecordField));
								newField->fieldType = strdup($1);
								newField->fieldName = strdup($2);
						
								int i;
								struct RecordField* fieldIt;
								//....prima però controllo che non ci sia un altro campo definito con lo stesso nome
								for(i = 0; i < getSize(tp->typeValue.recordFields); i++) {
									fieldIt = (struct RecordField*) get(tp->typeValue.recordFields, i);
							
									if(!strcmp(fieldIt->fieldName, newField->fieldName)) {
										yyerror(buildString("Type ", buildString(tp->typeName, buildString(" contains multiple definition of field ", $2))));
									}
								}
						
								add(tp->typeValue.recordFields, newField);
							
								fprintf(firstParse, "%s %s", $1, $2);
							} else {
								if(!searchType($1)) {
									yyerror(buildString("Type ", buildString($1, " not defined")));
								}
								fprintf(types, "\t%s %s;\n", getCTypeEquivalent($1), $2);
							}
						}
						;
						
var_declaration_section:	{
								//Stampiamo i prototipi e le definizioni delle funzioni di copia dei tipi
								//solo se ci troviamo nella seconda parsata ed una sola volta
								//(con l'escamotage della variabile printCopyFunc)
								if(eval && printCopyFunc) {
									printCopyFunctionsPrototype(funcsHeader);
									printCopyFunctionsDef(funcsDef);
									printCopyFunc = 0;
								}
							}
						|	var_decl var_declaration_section { /*Do nothing*/ }
							;
/*************************************************************************************************************
**************************************************************************************************************
*************************************************************************************************************/

/*************************************************************************************************************
********************************Grammatica per le dichiarazioni di variabili**********************************
*************************************************************************************************************/
var_decl: 	NEWVARS var_decl_type var_decl_stmt var_decl_stmt_list ';'
			{
				if(!eval) {
					fprintf(firstParse, "%s %s %s;\n", $2, $3, $4);
				} else {
					fprintf(cSourceOutApp, "%s %s %s;\n", getCTypeEquivalent($2), $3, $4);
				}
			}
			;

var_decl_type:	IDENTIFIER
				{
					if(!eval) {
						$$ = buildString("newvars ", $1);
						tp = searchType($1);
						if(!tp) { yyerror(buildString("Type ", buildString($1, " has not been defined"))); }
					} else {
						tp = searchType($1);
						$$ = strdup($1);
						firstVar = 1;
					}
				}
				;

var_decl_stmt:	var_decl_stmt_var var_decl_stmt_assign { $$ = buildString($1, $2); };

var_decl_stmt_var:	IDENTIFIER 
					{
						if(addVariables) {
							vp = addVariable(currSymTab, $1, tp->typeName);
							if(vp == NULL) {
								yyerror(buildString("A variable with name ", buildString($1, " already exists")));
							}
							vp->initialized = 0;
						}
						
						if(eval) {
							vp = searchVariable($1);
							varDeclName = strdup($1);
							//Se è la prima variabile del blocco di dichiarazione allora stampa solamente
							//il suo nome
							if(firstVar) {
								$$ = buildString(" ", $1);
								firstVar = 0;
							} else {
								//Altrimenti se il tipo del blocco di dichiarazione non è un puntatore
								//(ossia è un tipo base tranne il tipo string (in quanto questo è rappresentato come char*))
								if(isABaseType(tp->typeName) && strcmp(tp->typeName, "string")) {
									$$ = buildString(" ", $1);
								} else {
									//Altrimenti stampa il suo nome preceduto da un *, ossia la variabile dichiarata
									//è un puntatore al tipo
									$$ = buildString(" *", $1);
								}
							}
						} else { $$ = strdup($1); }
					}
					;

/************Una assegnamento inline può essere o vuoto (nel caso di dichirazione secca) o con un'espressione a destra**********/			
var_decl_stmt_assign:	{ $$ = ""; }
					|	'=' expr_first
						{
							if($2->containsArrays || $2->containsRecords || $2->containsFuncCalls) {
								yyerror("Inline assignment cannot contains arrays, records and function calls");
							}
							
							if(eval) {
								if(strcmp($2->exprType, tp->typeName)) { yyerror("Assignment type error"); }
							}
							
							if(addVariables) {
								if(!$2->containsUninitializedVariables) { vp->initialized = 1; }
								vp->varInit = strdup($2->exprString);
							}
							
							if(!eval) {
								$$ = buildString(" = ", $2->exprString);
							} else {
								$$ = "";
								//Stampiamo l'assegnamento solo se ci troviamo in una funzione, in quanto l'assegnamento
								//globale del C funziona un pochettino male...
								if(funcImplInfo != NULL) {
									$$ = buildString(" = ", $2->exprString);
								}
								vp->varInit = strdup($2->exprString);
							}
						}
						;

var_decl_stmt_comma:	','
						{ $$ = ","; }
						;

var_decl_stmt_list:	{ $$ = ""; }
				|	var_decl_stmt_comma var_decl_stmt var_decl_stmt_list { $$ = buildString($1, buildString($2, $3)); }
					;
/*************************************************************************************************************
**************************************************************************************************************
*************************************************************************************************************/

/*************************************************************************************************************
****************************************Grammatica per le espressioni destre**********************************
*************************************************************************************************************/
expr_first:	expr_first LOGIC_AND expr_second
			{
				$$=(struct ExpressionValue*)malloc(sizeof(struct ExpressionValue));
				if(eval) {
					if(strcmp($1->exprType, $3->exprType)) { yyerror("Expression type error"); }
					if(strcmp($1->exprType, "boolean")) { yyerror("Expression type error"); }
					$$->exprType = "boolean";
				}
				$$->containsArrays = $1->containsArrays || $3->containsArrays;
				$$->containsRecords = $1->containsRecords || $3->containsRecords;
				$$->containsFuncCalls = $1->containsFuncCalls || $3->containsFuncCalls;
				$$->containsUninitializedVariables = $1->containsUninitializedVariables || $3->containsUninitializedVariables;
				$$->exprString = buildString($1->exprString, buildString($2, $3->exprString));
			}
		|	expr_second { $$ = $1; }
			;

expr_second:	expr_second LOGIC_OR expr_third
				{
					$$=(struct ExpressionValue*)malloc(sizeof(struct ExpressionValue));
					if(eval) {
						if(strcmp($1->exprType, $3->exprType)) { yyerror("Expression type error"); }
						if(strcmp($1->exprType, "boolean")) { yyerror("Expression type error"); }
						$$->exprType = "boolean";
					}
					$$->containsArrays = $1->containsArrays || $3->containsArrays;
					$$->containsRecords = $1->containsRecords || $3->containsRecords;
					$$->containsFuncCalls = $1->containsFuncCalls || $3->containsFuncCalls;
					$$->containsUninitializedVariables = $1->containsUninitializedVariables || $3->containsUninitializedVariables;
					$$->exprString = buildString($1->exprString, buildString($2, $3->exprString));
				}
			|	expr_third { $$ = $1; }
				;

expr_third:	expr_third RELOP expr_fourth
			{
				$$=(struct ExpressionValue*)malloc(sizeof(struct ExpressionValue));
				if(eval) {
					if(strcmp($1->exprType, $3->exprType)) { yyerror("Expression type error"); }
					$$->exprType = "boolean";
				}
				$$->containsArrays = $1->containsArrays || $3->containsArrays;
				$$->containsRecords = $1->containsRecords || $3->containsRecords;
				$$->containsFuncCalls = $1->containsFuncCalls || $3->containsFuncCalls;
				$$->containsUninitializedVariables = $1->containsUninitializedVariables || $3->containsUninitializedVariables;
				$$->exprString = buildString($1->exprString, buildString($2, $3->exprString));
			}
		|	expr_fourth { $$ = $1; }
			;

expr_fourth:	expr_fourth '+' expr_fifth
				{
					$$=(struct ExpressionValue*)malloc(sizeof(struct ExpressionValue));
					if(eval) {
						if(strcmp($1->exprType, $3->exprType)) { yyerror("Expression type error"); }
						$$->exprType = strdup($1->exprType);
					}
					$$->containsArrays = $1->containsArrays || $3->containsArrays;
					$$->containsRecords = $1->containsRecords || $3->containsRecords;
					$$->containsFuncCalls = $1->containsFuncCalls || $3->containsFuncCalls;
					$$->containsUninitializedVariables = $1->containsUninitializedVariables || $3->containsUninitializedVariables;
					$$->exprString = buildString($1->exprString, buildString("+", $3->exprString));
				}
			|	expr_fourth '-' expr_fifth
				{
					$$=(struct ExpressionValue*)malloc(sizeof(struct ExpressionValue));
					if(eval) {
						if(strcmp($1->exprType, $3->exprType)) { yyerror("Expression type error"); }
						$$->exprType = strdup($1->exprType);
					}
					$$->containsArrays = $1->containsArrays || $3->containsArrays;
					$$->containsRecords = $1->containsRecords || $3->containsRecords;
					$$->containsFuncCalls = $1->containsFuncCalls || $3->containsFuncCalls;
					$$->containsUninitializedVariables = $1->containsUninitializedVariables || $3->containsUninitializedVariables;
					$$->exprString = buildString($1->exprString, buildString("-", $3->exprString));
				}
			|	expr_fifth { $$ = $1; }
				;

expr_fifth:	expr_fifth '*' expr_sixth
			{
				$$=(struct ExpressionValue*)malloc(sizeof(struct ExpressionValue));
				if(eval) {
					if(strcmp($1->exprType, $3->exprType)) { yyerror("Expression type error"); }
					$$->exprType = strdup($1->exprType);
				}
				$$->containsArrays = $1->containsArrays || $3->containsArrays;
				$$->containsRecords = $1->containsRecords || $3->containsRecords;
				$$->containsFuncCalls = $1->containsFuncCalls || $3->containsFuncCalls;
				$$->containsUninitializedVariables = $1->containsUninitializedVariables || $3->containsUninitializedVariables;
				$$->exprString = buildString($1->exprString, buildString("*", $3->exprString));
			}
		|	expr_fifth '/' expr_sixth
			{
				$$=(struct ExpressionValue*)malloc(sizeof(struct ExpressionValue));
				if(eval) {
					if(strcmp($1->exprType, $3->exprType)) { yyerror("Expression type error"); }
					$$->exprType = strdup($1->exprType);
				}
				$$->containsArrays = $1->containsArrays || $3->containsArrays;
				$$->containsRecords = $1->containsRecords || $3->containsRecords;
				$$->containsFuncCalls = $1->containsFuncCalls || $3->containsFuncCalls;
				$$->containsUninitializedVariables = $1->containsUninitializedVariables || $3->containsUninitializedVariables;
				$$->exprString = buildString($1->exprString, buildString("/", $3->exprString));
			}
		|	expr_sixth { $$ = $1; }
			;

expr_sixth:	NEW '(' IDENTIFIER ')'
			{
				$$=(struct ExpressionValue*)malloc(sizeof(struct ExpressionValue));
				if(eval) {
					struct TypeInfo* ti = searchType($3);
					if(ti == NULL) { yyerror("Type not defined"); }
					$$->exprType = ti->typeName;
					$$->exprString = (char*) malloc(sizeof(char)*(2*(strlen(ti->typeName)+10)+30));
					sprintf($$->exprString, "(%s) malloc(sizeof(struct %s))", getCTypeEquivalent(ti->typeName), ti->typeName);
				} else {
					$$->exprString = buildString("new(", buildString($3, ")"));
				}
			}
		|	var_location_first
			{
				$$=(struct ExpressionValue*)malloc(sizeof(struct ExpressionValue));
				if(eval) {
					$$->exprType = strdup($1->exprType);
				}
				$$->exprString = strdup($1->exprString);
			}
		|	TRUE_CONST {
				$$=(struct ExpressionValue*)malloc(sizeof(struct ExpressionValue));
				$$->exprType = "boolean";
				if(eval) {
					$$->exprString = "1";
				} else {
					$$->exprString = "true";
				}
			}
		|	FALSE_CONST { 
				$$=(struct ExpressionValue*)malloc(sizeof(struct ExpressionValue));
				$$->exprType = "boolean";
				if(eval) {
					$$->exprString = "0";
				} else {
					$$->exprString = "false";
				}
			}
		|	INTEGER_NUM {
				$$=(struct ExpressionValue*)malloc(sizeof(struct ExpressionValue));
				$$->exprType = "integer";
				$$->exprString = strdup($1);
			}
		|	FLOATING_NUM {
				$$=(struct ExpressionValue*)malloc(sizeof(struct ExpressionValue));
				$$->exprType = "floating";
				$$->exprString = strdup($1);
			}
		|	STRING_CONST {
				$$=(struct ExpressionValue*)malloc(sizeof(struct ExpressionValue));
				$$->exprType = "string";
				$$->exprString = strdup($1);
			}
		|	CHAR_CONST {
				$$=(struct ExpressionValue*)malloc(sizeof(struct ExpressionValue));
				$$->exprType = "char";
				$$->exprString = strdup($1);
			}
		|	'-' expr_sixth {
				$$=(struct ExpressionValue*)malloc(sizeof(struct ExpressionValue));
				if(eval) {
					$$->exprType = strdup($2->exprType);
					if(strcmp($2->exprType, "integer") && !strcmp($2->exprType, "floating")) { yyerror("Expression type error"); }
				}
				$$->containsArrays = $2->containsArrays;
				$$->containsRecords = $2->containsRecords;
				$$->containsFuncCalls = $2->containsFuncCalls;
				$$->containsUninitializedVariables = $2->containsUninitializedVariables;
				$$->exprString = buildString("-", $2->exprString);
			}
		|	'!'	expr_sixth {
				$$=(struct ExpressionValue*)malloc(sizeof(struct ExpressionValue));
				if(eval) {
					$$->exprType = strdup($2->exprType);
					if(strcmp($2->exprType, "boolean")) { yyerror("Expression type error"); }
				}
				$$->containsArrays = $2->containsArrays;
				$$->containsRecords = $2->containsRecords;
				$$->containsFuncCalls = $2->containsFuncCalls;
				$$->containsUninitializedVariables = $2->containsUninitializedVariables;
				$$->exprString = buildString("!", $2->exprString);
			}
		|	'(' expr_first ')' {
				$$=(struct ExpressionValue*)malloc(sizeof(struct ExpressionValue));
				if(eval) {
					$$->exprType = strdup($2->exprType);
				}
				$$->containsArrays = $2->containsArrays;
				$$->containsRecords = $2->containsRecords;
				$$->containsFuncCalls = $2->containsFuncCalls;
				$$->containsUninitializedVariables = $2->containsUninitializedVariables;
				$$->exprString = buildString("(", buildString($2->exprString, ")"));
			}
			;
				
var_location_first:	var_location_type var_location_second
					{
						$$ = (struct ExpressionValue*) malloc(sizeof(struct ExpressionValue));
						$$->containsArrays = $1->containsArrays || $2->containsArrays;
						$$->containsRecords = $1->containsRecords || $2->containsRecords;
						$$->containsFuncCalls = $1->containsFuncCalls || $2->containsFuncCalls;
						$$->containsUninitializedVariables = $1->containsUninitializedVariables || $2->containsUninitializedVariables;
						
						if(eval) {
							if(strcmp($2->exprString, "")) {
								$$->exprType = $2->exprType;
							} else {
								$$->exprType = $1->exprType;
							}
							
							char* expr = buildString($1->exprString, $2->exprString);
							
							if(!$$->containsFuncCalls && strcmp($1->exprType, "null")) {
								//Prima di usare una variabile, ne calcoliamo il valore se era lazy
								//(avviene attraverso codice C iniettato prima della stampa dell'espressione
								//in cui compare tale varaibile)
								fprintf(cSourceOutApp, "lavl = _isLazy(\"%s\");\n", expr);
								if(isABaseType($$->exprType) && strcmp($$->exprType, "string")) {
									fprintf(cSourceOutApp, "if(lavl != NULL) { %s = *((%s*) (lavl->func(lavl->args)));\n}\n",
										expr, getCTypeEquivalent($$->exprType));
								} else {
									fprintf(cSourceOutApp, "if(lavl != NULL) { %s = ((%s) (lavl->func(lavl->args)));\n}\n",
											expr, getCTypeEquivalent($$->exprType));
								}
							
								if(lazyFuncImplInfo != NULL) {
									struct ArgumentValue* argValue = (struct ArgumentValue*) malloc(sizeof(struct ArgumentValue));
									argValue->argType = strdup($$->exprType);
									char app[15];
									sprintf(app, "%d", lazyArgID);
									argValue->argName = buildString("arg", app);
									add(lazyFuncImplInfo->argumentValues, argValue);
									fprintf(cSourceOutApp, "_add(_args, _copy%s(%s));\n", argValue->argType, expr);
									if(isABaseType($$->exprType) && strcmp($$->exprType, "string")) {
										$$->exprString = buildString("*", buildString("arg",app));
									} else {
										$$->exprString = buildString("arg",app);
									}
									lazyArgID++;
								} else {
									$$->exprString = strdup(expr);
								}
							} else {
								$$->exprString = strdup(expr);
							}
							stackPop(exprStack);
						} else {
							$$->exprString = buildString($1->exprString, $2->exprString);
						}
					}
					;

var_location_type:	IDENTIFIER
					{
						$$ = (struct ExpressionValue*) malloc(sizeof(struct ExpressionValue));
						if(eval) {
							if(!strcmp($1, "null")) { $$->exprType = "null"; }
							else {
								vpExpr = searchVariable($1);
								if(vpExpr == NULL) { yyerror(buildString("No variable named ", $1)); }
								struct TypeInfo* ti = searchType(vpExpr->varType);
								stackPush(exprStack, searchType(vpExpr->varType));
								if(!vpExpr->initialized) { $$->containsUninitializedVariables = 1; }
								
								$$->exprType = strdup(((struct TypeInfo*) stackTop(exprStack))->typeName);
								typeArrayDimensionIndex = 0;
							
								arrowForArrayAccess = 1;
							}
						}
						$$->exprString = strdup($1);
					}
				|	func_call
					{
						$$ = (struct ExpressionValue*) malloc(sizeof(struct ExpressionValue));
						if(eval) {
							$$->exprType = strdup($1->exprType);
							stackPush(exprStack, searchType($1->exprType));
							typeArrayDimensionIndex = 0;
							arrowForArrayAccess = 1;
						}
						
						$$->containsFuncCalls = 1;
						$$->exprString = strdup($1->exprString);
					}
					;

var_location_second:	{
							$$ = (struct ExpressionValue*) malloc(sizeof(struct ExpressionValue));
							if(eval) {
								struct TypeInfo* ti =  (struct TypeInfo*) stackTop(exprStack);
								if(ti == NULL) { $$->exprType = "null"; }
								else { $$->exprType = strdup(ti->typeName); }
							}
							$$->exprString = "";
						}
					|	record_access var_location_second
						{
							$$ = (struct ExpressionValue*) malloc(sizeof(struct ExpressionValue));
							if(eval) {
								$$->exprType = strdup(((struct TypeInfo*) stackTop(exprStack))->typeName);
							}
							$$->exprString = buildString($1->exprString, $2->exprString);
						}
					|	array_location var_location_second
						{
							$$ = (struct ExpressionValue*) malloc(sizeof(struct ExpressionValue));
							if(eval) {
								$$->exprType = strdup(((struct TypeInfo*) stackTop(exprStack))->typeName);
							}
							$$->exprString = buildString($1->exprString, $2->exprString);
						}
						;

array_location: '[' expr_first ']'
				{
					$$ = (struct ExpressionValue*) malloc(sizeof(struct ExpressionValue));
					$$->exprString="";
					if(eval) {
						struct TypeInfo* tpExpr = (struct TypeInfo*) stackTop(exprStack);
						if(tpExpr->typeConstructor != ARR) { yyerror("Variable not an array2"); }
						if(eval && arrowForArrayAccess) { $$->exprString = "->array"; arrowForArrayAccess = 0; }
						if(typeArrayDimensionIndex + 1 > tpExpr->typeValue.arrayValue.totDimensions) {
							yyerror("Array out of bound");
						}
				
						char* newExprType = strdup(tpExpr->typeValue.arrayValue.arrayType);
						stackPop(exprStack);
						stackPush(exprStack, searchType(newExprType));
						$$->exprType = newExprType;	
			
						typeArrayDimensionIndex++;
					}
					$$->exprString = buildString($$->exprString, buildString("[", buildString($2->exprString, "]")));
					$$->containsArrays = 1;
				}
				;

record_access: '.' IDENTIFIER
				{
					$$ = (struct ExpressionValue*) malloc(sizeof(struct ExpressionValue));
					
					if(eval) {
						struct TypeInfo* tpExpr = (struct TypeInfo*) stackTop(exprStack);
						$$->exprString = buildString("->", $2);
						if(tpExpr->typeConstructor == ARR) {
							tpExpr = searchType(tpExpr->typeValue.arrayValue.arrayType);
						}
			
						if(tpExpr->typeConstructor != REC) { yyerror("Variable not a record"); }
						struct RecordField* field = isFieldOfRecord($2, tpExpr);
						if(field == NULL) { yyerror("Not a field of record"); }
			
						char* newExprType = strdup(field->fieldType);
						stackPop(exprStack);
						stackPush(exprStack, searchType(newExprType));
						
						$$->exprType = strdup(newExprType);
					} else {
						$$->exprString = buildString(".", $2);
					}
					$$->containsRecords = 1;
				}
				;

func_call:	func_call_start func_call_arg_list ')'
			{
				$$ = (struct ExpressionValue*) malloc(sizeof(struct ExpressionValue));
				if(eval) {
					if(getSize(((struct FuncCallStruct*) stackTop(funcCallInfo))->fi->argumentValues) >
					   ((struct FuncCallStruct*) stackTop(funcCallInfo))->funcCallArgIndex) {
						yyerror("Numero di argomenti insufficiente");
					}
				
					$$->exprType = $1->exprType;
					stackPop(funcCallInfo);
				}
				
				$$->exprString = buildString($1->exprString, buildString($2->exprString, ")"));
			}
			;

func_call_start:	IDENTIFIER '('
					{
						$$ = (struct ExpressionValue*) malloc(sizeof(struct ExpressionValue));
						if(eval) {
							struct FuncInfo* fi = searchFunction($1);
						
							if(fi == NULL) {
								yyerror("Funzione non definita");
							}
							
							struct FuncCallStruct* fcs = (struct FuncCallStruct*) malloc(sizeof(struct FuncCallStruct));
							fcs->fi = fi;
							fcs->funcCallArgIndex = 0;
							
							stackPush(funcCallInfo, fcs);
							
							$$->exprType = strdup(((struct FuncCallStruct*) stackTop(funcCallInfo))->fi->returnType);
						}
						$$->exprString = buildString($1, "(");
					}
					;

func_call_arg_list: {
						$$ = (struct ExpressionValue*) malloc(sizeof(struct ExpressionValue));
						$$->exprString = "";
					}
			|	func_call_arg_param func_call_other_args
				{
					$$ = (struct ExpressionValue*) malloc(sizeof(struct ExpressionValue));
					$$->exprString = buildString($1->exprString, $2->exprString);
				}
			;

func_call_other_args:	{
							$$ = (struct ExpressionValue*) malloc(sizeof(struct ExpressionValue));
							$$->exprString = "";
						}
						|	func_call_comma func_call_arg_param func_call_other_args
							{
								$$ = (struct ExpressionValue*) malloc(sizeof(struct ExpressionValue));
								$$->exprString = buildString(",", buildString($2->exprString, $3->exprString));
							}
							;

func_call_comma:	',' { };

func_call_arg_param: 	expr_first
						{
							$$ = (struct ExpressionValue*) malloc(sizeof(struct ExpressionValue));
							if(eval) {
								
								//se la funzione non prevede argomenti o siamo a troppi argomenti dà errore
								if(getSize(((struct FuncCallStruct*) stackTop(funcCallInfo))->fi->argumentValues) == 0 ||
								   getSize(((struct FuncCallStruct*) stackTop(funcCallInfo))->fi->argumentValues)
								   		<= ((struct FuncCallStruct*) stackTop(funcCallInfo))->funcCallArgIndex) {
									yyerror("Numero di argomenti errato");
								}
							
								struct ArgumentValue* av = (struct ArgumentValue*)
									get(((struct FuncCallStruct*) stackTop(funcCallInfo))->fi->argumentValues,
									    ((struct FuncCallStruct*) stackTop(funcCallInfo))->funcCallArgIndex);
								if(strcmp(av->argType, $1->exprType) != 0) {
									yyerror("Tipo non corrispondente");
								}
							
								((struct FuncCallStruct*) stackTop(funcCallInfo))->funcCallArgIndex++;
							}
							
							$$->exprString = strdup($1->exprString);
						}
						;
/*************************************************************************************************************
**************************************************************************************************************
*************************************************************************************************************/

/*************************************************************************************************************
**************************************Grammatica per le espressioni sinistre**********************************
*************************************************************************************************************/

lexpr_first:	lexpr_type lexpr_second
				{
					$$ = (struct ExpressionValue*) malloc(sizeof(struct ExpressionValue));
					
					if(eval) {
						if(strcmp($2->exprString, "")) {
							$$->exprType = $2->exprType;
						} else {
							$$->exprType = $1->exprType;
						}
						
						stackPop(exprStack);
					}
					
					$$->exprString = buildString($1->exprString, $2->exprString);
				}
				;

lexpr_type:	IDENTIFIER
			{
				$$ = (struct ExpressionValue*) malloc(sizeof(struct ExpressionValue));
				if(eval) {
					vpExpr = searchVariable($1);
					if(vpExpr == NULL) { yyerror(buildString("No variable named ", $1)); }
					struct TypeInfo* ti = searchType(vpExpr->varType);
					stackPush(exprStack, ti);
					stackTop(exprStack);
				
					if(!vpExpr->initialized) { $$->containsUninitializedVariables = 1; }
					
					$$->exprType = strdup(((struct TypeInfo*) stackTop(exprStack))->typeName);
					typeArrayDimensionIndex = 0;
					
					arrowForArrayAccess = 1;
				}
				$$->exprString = strdup($1);
			}
			;

lexpr_second:	{
					$$ = (struct ExpressionValue*) malloc(sizeof(struct ExpressionValue));
					if(eval) {
						struct TypeInfo* ti =  (struct TypeInfo*) stackTop(exprStack);
						if(ti == NULL) { $$->exprType = "null"; }
						else { $$->exprType = strdup(ti->typeName); }
					}
					$$->exprString = "";
				}
			|	lexpr_array_loc var_location_second
				{
					$$ = (struct ExpressionValue*) malloc(sizeof(struct ExpressionValue));
					if(eval) {
						$$->exprType = strdup(((struct TypeInfo*) stackTop(exprStack))->typeName);
					}
					$$->exprString = buildString($1->exprString, $2->exprString);
				}
			|	lexpr_record var_location_second
				{
					$$ = (struct ExpressionValue*) malloc(sizeof(struct ExpressionValue));
					if(eval) {
						$$->exprType = strdup(((struct TypeInfo*) stackTop(exprStack))->typeName);
					}
					$$->exprString = buildString($1->exprString, $2->exprString);
				}
				;

lexpr_array_loc:	'[' expr_first ']'
					{
						$$ = (struct ExpressionValue*) malloc(sizeof(struct ExpressionValue));
						$$->exprString="";
						if(eval) {
							struct TypeInfo* tpExpr = (struct TypeInfo*) stackTop(exprStack);
							if(tpExpr->typeConstructor != ARR) { yyerror("Variable not an array"); }
							if(eval && arrowForArrayAccess) { $$->exprString = "->array"; arrowForArrayAccess = 0; }
							if(typeArrayDimensionIndex + 1 > tpExpr->typeValue.arrayValue.totDimensions) {
								yyerror("Array out of bound");
							}
							
							char* newExprType = strdup(tpExpr->typeValue.arrayValue.arrayType);
							stackPop(exprStack);
							stackPush(exprStack, searchType(newExprType));
							$$->exprType = newExprType;	
			
							typeArrayDimensionIndex++;
						}
						$$->exprString = buildString($$->exprString, buildString("[", buildString($2->exprString, "]")));
						$$->containsArrays = 1;
					}
					;

lexpr_record:	'.' IDENTIFIER
				{
					$$ = (struct ExpressionValue*) malloc(sizeof(struct ExpressionValue));
					
					if(eval) {
						struct TypeInfo* tpExpr = (struct TypeInfo*) stackTop(exprStack);
						$$->exprString = buildString("->", $2);
						if(tpExpr->typeConstructor == ARR) {
							tpExpr = searchType(tpExpr->typeValue.arrayValue.arrayType);
						}
			
						if(tpExpr->typeConstructor != REC) { yyerror("Variable not a record"); }
						struct RecordField* field = isFieldOfRecord($2, tpExpr);
						if(field == NULL) { yyerror("Not a field of record"); }
			
						char* newExprType = strdup(field->fieldType);
						stackPop(exprStack);
						stackPush(exprStack, searchType(newExprType));
						
						$$->exprType = strdup(newExprType);
					} else {
						$$->exprString = buildString(".", $2);
					}
					$$->containsRecords = 1;
				}
				;

/*************************************************************************************************************
**************************************************************************************************************
*************************************************************************************************************/

/*************************************************************************************************************
*******************************************Implementazione di funzioni****************************************
*************************************************************************************************************/

function_decl_list:	{
						if(!searchFunction("start")) {
							yyerror("start function not found");
						}
					}
				|	func_impl function_decl_list { /*Do nothing*/ }
        		;        		

func_impl:	FUNC func_impl_start func_impl_arg_list func_impl_end BEG var_declaration_section stmt_list  END 
			{
				if(!eval) {
					fprintf(firstParse,"end\n");
					addFunction(funcName, funcImplInfo);
				} else {
					if(strcmp(funcImplInfo->returnType, "null") && (funcImplRetNum == 0)) {
						yyerror("Return type not null but no return statement found");
					}
					clearFuncScope();
					fprintf(cSourceOutApp, "_stackPop(_lazyAssignedValues);\n");
					fprintf(cSourceOutApp, "free(_lazyEnv);\n");
					fprintf(cSourceOutApp, "}\n");
				}
				funcImplInfo = NULL;
			}
			;


func_impl_start:	IDENTIFIER '('
					{
						if(!eval) {
							fprintf(firstParse, "func %s(", $1);
						
							funcName = strdup($1);
							funcImplInfo = (struct FuncInfo*) malloc(sizeof(struct FuncInfo));
							createVector(funcImplInfo->argumentValues);
							initVector(funcImplInfo->argumentValues);
							
							addVariables = 0;
						} else {
							currSymTab = functionScope;
							funcName = strdup($1);
							funcImplInfo = searchFunction($1);
							funcImplRetNum = 0;
							addVariables = 1;
							varName = strdup($1);
						}
	                }
	                ;


func_impl_arg_list:	{ /*Do nothing*/ }
            	|	func_impl_arg_decl func_impl_arg_list { /*Do nothing*/ }
					;

func_impl_arg_decl_comma:	',' { if(!eval) { fprintf(firstParse, ", "); } }
							;

func_impl_arg_decl:	func_impl_arg_param { /*Do nothing*/ }
            	|	func_impl_arg_decl_comma func_impl_arg_param { /*Do nothing*/ }
            		;


func_impl_arg_param:	IDENTIFIER IDENTIFIER
						{
							if(!eval) {
								if(!strcmp(funcName, "start") && !isABaseType($1)) {
									yyerror("Function start can contains only base types as parameters");
								}
								
								if(strcmp(funcName, "start") && !searchType($1)) {
									yyerror(buildString("Type ", buildString($1, " has not been defined")));
								}
								
								struct ArgumentValue* newArgVal = (struct ArgumentValue*) malloc(sizeof(struct ArgumentValue));
			                    newArgVal->argType = strdup($1);
			                    newArgVal->argName = strdup($2);
			                    add(funcImplInfo->argumentValues, newArgVal);
			                    
			                    fprintf(firstParse, "%s %s", $1, $2);
							} else {
								if(!addVariable(functionScope, $2, $1)) {
									yyerror(buildString("Variable ", buildString($2, " already exists")));
								}
							}
	                    }
	                    ;


func_impl_end:	')' ':' IDENTIFIER
				{
					if(!eval) {
						if(!strcmp(funcName, "integer") && strcmp($3, "integer") && strcmp($3, "null")) {
							yyerror("Return value for function start must be either integer or null");
						}
						
						if(strcmp(funcName, "start") && !searchType($3)) {
							yyerror(buildString("Type ", buildString($3, " has not been defined")));
						}
						
						//setto il tipo di ritorno
						funcImplInfo->returnType = strdup($3);
						
						fprintf(firstParse, "):%s\nbegin\n", $3);
						
						if(strcmp(funcName, "start")) {
							fprintf(funcsHeader, "%s %s(", getCTypeEquivalent(funcImplInfo->returnType), funcName);
							printFunctionArguments(funcsHeader, funcImplInfo);
							fprintf(funcsHeader, ");\n");
						}
					} else {
						if(!strcmp(funcName, "start")) {
							fprintf(cSourceOutApp, "%s main(int argc, char* args[]) {\n", getCTypeEquivalent(funcImplInfo->returnType));
							printInitializedVariables(cSourceOutApp, symTab);
							printMainArgsInitialization(cSourceOutApp, funcImplInfo);
							fprintf(cSourceOutApp, "_createStack(_lazyAssignedValues);\n_stackInit(_lazyAssignedValues);\n");
						} else {
							fprintf(cSourceOutApp, "%s %s(", getCTypeEquivalent(funcImplInfo->returnType), funcName);
							printFunctionArguments(cSourceOutApp, funcImplInfo);
							fprintf(cSourceOutApp, ") {\n");
						}
						fprintf(cSourceOutApp, "struct _LazyAssignmentValue* _lazyEnv = (struct _LazyAssignmentValue*) malloc(sizeof(struct _LazyAssignmentValue)*1024);\n");
						fprintf(cSourceOutApp, "_stackPush(_lazyAssignedValues, _lazyEnv);\n");
					}
				}
				;

//**********************************-----------------------------------*******************************************************
//**********************************-----------------------------------*******************************************************
//**********************************-----------------------------------*******************************************************

stmt_assign:	lexpr_first '=' expr_first
				{					
					if(eval) {
						if(strcmp($1->exprType, $3->exprType)) { yyerror("Type assignment error"); }
						fprintf(cSourceOutApp, "_deleteLazyValue(\"%s\");\n", $1->exprString);
						fprintf(cSourceOutApp, "%s = %s", $1->exprString, $3->exprString);
					} else {
						fprintf(firstParse, "%s = %s", $1->exprString, $3->exprString);
					}
				}
				;

printf_arg_list:	{ $$ = ""; }
				|	printf_arg printf_arg_list { $$ = buildString($1, $2); }
					;

printf_arg:	',' expr_first
			{
				$$ = buildString(", ", $2->exprString);
			}
			;

scanf_arg_list:	{ $$ = ""; }
			|	scanf_arg scanf_arg_list { $$ = buildString($1, $2); }
				;

scanf_arg: ',' var_location_first
			{
				if(eval) {
					if(!isABaseType($2->exprType)) { yyerror("Cannot scanf a custom type"); }
					$$ = buildString(", &", $2->exprString);
				} else {
					$$ = buildString(", ", $2->exprString);
				}
			}
			;

loop:	loop_start
		{
			if(eval) {
				fprintf(cSourceOutApp, "%s", $1);
			} else {
				fprintf(firstParse, "%s", $1);
			}
		}
		;

loop_start:	LOOP '(' expr_first ')'
			{
				if(eval) {
					if(strcmp($3->exprType, "boolean")) { yyerror("Expected boolean"); }
					$$ = buildString("while(", buildString($3->exprString, ")"));
				} else {
					$$ = buildString("loop(", buildString($3->exprString, ")"));
				}
			}
			;

block_begin:	BEG {
					if(eval) { fprintf(cSourceOutApp, "{\n"); }
					else { fprintf(firstParse, "\nbegin\n"); }
				}
				;

block_end:	END {
				if(eval) { fprintf(cSourceOutApp, "\n}\n"); }
				else { fprintf(firstParse, "\nend\n"); }
			}
			;

if: if_start
	{
		if(eval) {
			fprintf(cSourceOutApp, "%s", $1);
		} else {
			fprintf(firstParse, "%s", $1);
		}
	}
	;

if_start:	IF '(' expr_first ')' THEN
			{
				if(eval) {
					if(strcmp($3->exprType, "boolean")) { yyerror("Expected boolean"); }
					$$ = buildString("if(", buildString($3->exprString, ")"));
				} else {
					$$ = buildString("if(", buildString($3->exprString, ") then"));
				}
			}
			;

else:	ELSE
		{
			if(eval) {
				fprintf(cSourceOutApp, "else");
			} else {
				fprintf(firstParse, "else");
			}
		}
		;
		
printf: printf_start printf_arg_list printf_end
		{
			if(eval) {
				fprintf(cSourceOutApp, "%s%s%s", $1, $2, $3);
			} else {
				fprintf(firstParse, "%s%s%s", $1, $2, $3);
			}
		}
		;

printf_start:	PRINTF '(' expr_first
				{
					if(strcmp($3->exprType, "string")) { yyerror("printf first argument have to be a string"); }
					$$ = buildString("printf(", $3->exprString);
				}
				;

printf_end:	')' ';'
			{
				$$ = ");\n";
			}
			;

scanf:	scanf_start scanf_arg_list printf_end
		{
			if(eval) {
				fprintf(cSourceOutApp, "%s%s%s", $1, $2, $3);
			} else {
				fprintf(firstParse, "%s%s%s", $1, $2, $3);
			}
		}
		;

scanf_start:	SCANF '(' expr_first
				{
					if(strcmp($3->exprType, "string")) { yyerror("printf first argument have to be a string"); }
					$$ = buildString("scanf(", $3->exprString);
				}
				;

lazy_stmt_assign:	lazy_lexpr LAZY_ASS expr_first
					{
						if(eval) {
							if(strcmp(lazyFuncImplInfo->returnType, $3->exprType)) { yyerror("Type assignment error"); }
							struct ArgumentValue* argValue = (struct ArgumentValue*) malloc(sizeof(struct ArgumentValue));
							if(isABaseType($3->exprType) && strcmp($3->exprType, "string")) {
								fprintf(lazyFuncs, "%s* %s(", getCTypeEquivalent(lazyFuncImplInfo->returnType), funcName);
							} else {
								fprintf(lazyFuncs, "%s %s(", getCTypeEquivalent(lazyFuncImplInfo->returnType), funcName);
							}
							if(getSize(lazyFuncImplInfo->argumentValues) > 0) {
								argValue = (struct ArgumentValue*) get(lazyFuncImplInfo->argumentValues, 0);
								if(isABaseType(argValue->argType) && strcmp(argValue->argType, "string")) {
									fprintf(lazyFuncs, "%s* %s", getCTypeEquivalent(argValue->argType), argValue->argName);
								} else {
									fprintf(lazyFuncs, "%s %s", getCTypeEquivalent(argValue->argType), argValue->argName);
								}
								for(int i = 1; i < getSize(lazyFuncImplInfo->argumentValues); i++) {
									argValue = (struct ArgumentValue*) get(lazyFuncImplInfo->argumentValues, i);
									if(isABaseType(argValue->argType) && strcmp(argValue->argType, "string")) {
										fprintf(lazyFuncs, ", %s* %s", getCTypeEquivalent(argValue->argType), argValue->argName);
									} else {
										fprintf(lazyFuncs, ", %s %s", getCTypeEquivalent(argValue->argType), argValue->argName);
									}
								}
							}
							fprintf(lazyFuncs, ") {\n");
							if(isABaseType($3->exprType) && strcmp($3->exprType, "string")) {
								fprintf(lazyFuncs, "\t%s* out = (%s*) malloc(sizeof(%s));\n", getCTypeEquivalent(lazyFuncImplInfo->returnType),
									getCTypeEquivalent(lazyFuncImplInfo->returnType), getCTypeEquivalent(lazyFuncImplInfo->returnType));
								fprintf(lazyFuncs, "\t*out = %s;\n", $3->exprString);
								fprintf(lazyFuncs, "\treturn out;\n}\n");
							} else {
								if(!strcmp($3->exprType, "string")) {
									fprintf(lazyFuncs, "\t%s out = strdup(%s);\n", getCTypeEquivalent(lazyFuncImplInfo->returnType),
										$3->exprString);
								} else {
									fprintf(lazyFuncs, "\t%s out = _copy%s(%s);\n", getCTypeEquivalent(lazyFuncImplInfo->returnType),
										lazyFuncImplInfo->returnType, $3->exprString);
								}
								fprintf(lazyFuncs, "return out;\n}\n");
							}
							fprintf(lazyFuncs, "void* %s(_Vector v) {\n\treturn %s(", buildString(funcName, "Call"), funcName);
							if(getSize(lazyFuncImplInfo->argumentValues) > 0) {
								argValue = (struct ArgumentValue*) get(lazyFuncImplInfo->argumentValues, 0);
								if(isABaseType(argValue->argType) && strcmp(argValue->argType, "string")) {
									fprintf(lazyFuncs, "(%s*) _get(v, 0)", getCTypeEquivalent(argValue->argType));
								} else {
									fprintf(lazyFuncs, "(%s) _get(v, 0)", getCTypeEquivalent(argValue->argType));
								}
								for(int i = 1; i < getSize(lazyFuncImplInfo->argumentValues); i++) {
									argValue = (struct ArgumentValue*) get(lazyFuncImplInfo->argumentValues, i);
									if(isABaseType(argValue->argType) && strcmp(argValue->argType, "string")) {
										fprintf(lazyFuncs, ", (%s*) _get(v, %d)", getCTypeEquivalent(argValue->argType), i);
									} else {
										fprintf(lazyFuncs, ", (%s) _get(v, %d)", getCTypeEquivalent(argValue->argType), i);
									}
								}
							}
							fprintf(lazyFuncs, ");\n}\n");
							fprintf(cSourceOutApp, "_addLazyAssignedValue(\"%s\", %s, _args);\n}\n", lazyFuncLexprName, buildString(funcName, "Call"));
							lazyFuncImplInfo = NULL;
							lazyArgID = 0;
						} else {
							fprintf(firstParse, " ?= %s;\n", $3->exprString);
						}
					}
					;

lazy_lexpr:	lexpr_first
			{
				if(eval) {
					if($1->containsFuncCalls) { yyerror("Left expression contains bad location"); }
					lazyFuncImplInfo = (struct FuncInfo*) malloc(sizeof(struct FuncInfo));
					char app[15];
					sprintf(app, "%d", lazyFuncID++);
					funcName = buildString("_lazyFunc", app);
					lazyFuncImplInfo->returnType = $1->exprType;
					lazyFuncLexprName = strdup($1->exprString);
					createVector(lazyFuncImplInfo->argumentValues);
					initVector(lazyFuncImplInfo->argumentValues);
					fprintf(cSourceOutApp, "{\n_Vector _args;\n");
					fprintf(cSourceOutApp, "\t_createVector(_args);\n");
					fprintf(cSourceOutApp, "\t_initVector(_args);\n");
				} else {
					fprintf(firstParse, "%s", $1->exprString);
				}
			}
			;
		
stmt:	func_call ';'
		{
			if(eval) {
				fprintf(cSourceOutApp, "%s;", $1->exprString);
			} else {
				fprintf(firstParse, "%s;", $1->exprString);
			}
		}
    |	loop block_begin stmt_list block_end { /*Do nothing*/ }
	|	if block_begin stmt_list block_end { /*Do nothing*/ }
	|	if block_begin stmt_list block_end else block_begin stmt_list block_end { /*Do nothing*/ }
	|	stmt_assign ';' {
			if(eval) {
				fprintf(cSourceOutApp, ";\n");
			} else {
				fprintf(firstParse, ";\n");
			}
		}
	|	lazy_stmt_assign ';' { /*Do nothing*/ }
		;
	|	RETURN expr_first ';' {
			if(eval) {
				if(funcImplInfo == NULL) { yyerror("Return statement outside of function body"); }
				if(strcmp(funcImplInfo->returnType, $2->exprType)) { yyerror("Returned value does not match that of function"); }
				funcImplRetNum++;
				fprintf(cSourceOutApp, "_stackPop(_lazyAssignedValues);\n");
				fprintf(cSourceOutApp, "free(_lazyEnv);\n");
				if(!strcmp($2->exprType, "null")) { fprintf(cSourceOutApp, "return;\n", $2->exprString); }
				else { fprintf(cSourceOutApp, "return %s;\n", $2->exprString); }
			} else {
				fprintf(firstParse, "return %s;\n", $2->exprString);
			}
		}
	|	FREE '(' lexpr_first ')' ';'
		{
			if(eval) {
				fprintf(cSourceOutApp, "free(%s);\n%s = NULL;\n", $3->exprString, $3->exprString);
			} else {
				fprintf(firstParse, "free(%s);\n", $3->exprString);
			}
		}
	|	printf { /*Do nothing*/ }
	|	scanf { /*Do nothing*/ }
		;
        
stmt_list:	{ /*Do nothing*/ }
		|	stmt stmt_list { /*Do nothing*/ }
			;

%%

yyerror(char* errorString) {
	printf("%s", errorString);
	exit(1);
}

main(int argc, char* args[]) {
	//Aggiungiamo i tipi base
	struct TypeInfo ti;
	ti.typeConstructor = BASE;
	
	for(int i = 0; i < 6; i++) {
		ti.typeName = strdup(baseTypes[i]);
		addType(&ti);
	}
	
	//Aggiungiamo la funzione "floating" per il casting da floating a intero
	funcImplInfo = (struct FuncInfo*) malloc(sizeof(struct FuncInfo));
	funcImplInfo->returnType = "floating";
	createVector(funcImplInfo->argumentValues);
	initVector(funcImplInfo->argumentValues);
	struct ArgumentValue* arg = (struct ArgumentValue*) malloc(sizeof(struct ArgumentValue));
	arg->argType = "integer";
	arg->argName = "arg";
	add(funcImplInfo->argumentValues, arg);
	addFunction("floating", funcImplInfo);
	funcImplInfo = NULL;
	
	yyin = fopen(args[1], "r");
	if(yyin==NULL) {
		 printf("Error!\n");
	}
	else {
		yyparse();
		fclose(firstParse);
		eval = 1;
		yyin = fopen("FirstParse.txt", "r");
		yyparse();
		cSourceOut = fopen("ls.out.c", "w");
		fprintf(cSourceOut, "#include <stdio.h>\n#include <stdlib.h>\n#include <string.h>\n");
		fprintf(cSourceOut, "#define _INITIAL_VECTOR_SIZE 20\n");
		fprintf(cSourceOut, "#define _STACK_SIZE 1024\n");
		fprintf(cSourceOut, "#define _createVector(v) v = (_VectorAux**)malloc(sizeof(_VectorAux*))\n");
		fprintf(cSourceOut, "#define _createStack(s) s = (struct _StackAux**)malloc(sizeof(struct _StackAux*))\n");
		fprintf(cSourceOut, "\n");
		fprintf(cSourceOut, "typedef struct _VectorAux {\n");
		fprintf(cSourceOut, "	int size;\n");
		fprintf(cSourceOut, "	int maxSize;\n");
		fprintf(cSourceOut, "	void** elements;\n");
		fprintf(cSourceOut, "} _VectorAux;\n");
		fprintf(cSourceOut, "typedef _VectorAux** _Vector;\n");
		fprintf(cSourceOut, "void _initVector(_Vector v) {\n");
		fprintf(cSourceOut, "	(*v) = (_VectorAux*) malloc(sizeof(_VectorAux*));\n");
		fprintf(cSourceOut, "	(*v)->elements = (void**) malloc(sizeof(void*) * _INITIAL_VECTOR_SIZE);\n");
		fprintf(cSourceOut, "	(*v)->size = 0;\n");
		fprintf(cSourceOut, "	(*v)->maxSize = _INITIAL_VECTOR_SIZE;\n");
		fprintf(cSourceOut, "}\n");
		fprintf(cSourceOut, "void _add(_Vector v, void* el) {\n");
		fprintf(cSourceOut, "	if((*v)->size + 1 > (*v)->maxSize) {\n");
		fprintf(cSourceOut, "		int newSize = (*v)->maxSize * 2;\n");
		fprintf(cSourceOut, "		(*v)->elements = (void*) realloc((*v)->elements, sizeof(void*) * newSize);\n");
		fprintf(cSourceOut, "		(*v)->maxSize = newSize;\n");
		fprintf(cSourceOut, "	}\n");
		fprintf(cSourceOut, "	(*v)->elements[(*v)->size++] = el;\n");
		fprintf(cSourceOut, "}\n");
		fprintf(cSourceOut, "void* _get(_Vector v, int i) {\n");
		fprintf(cSourceOut, "	if(i >= (*v)->maxSize) {\n");
		fprintf(cSourceOut, "		return NULL;\n");
		fprintf(cSourceOut, "	}\n");
		fprintf(cSourceOut, "	return (*v)->elements[i];\n");
		fprintf(cSourceOut, "}\n");
		fprintf(cSourceOut, "int _getSize(_Vector v) {\n");
		fprintf(cSourceOut, "	return (*v)->size;\n");
		fprintf(cSourceOut, "}\n");
		fprintf(cSourceOut, "struct _StackAux {\n");
		fprintf(cSourceOut, "	void** elements;\n");
		fprintf(cSourceOut, "	int top;\n");
		fprintf(cSourceOut, "};\n");
		fprintf(cSourceOut, "typedef struct _StackAux** _Stack;\n");
		fprintf(cSourceOut, "int _stackEmpty(_Stack s) {\n");
		fprintf(cSourceOut, "	if((*s)->top == -1) {\n");
		fprintf(cSourceOut, "		return 1;\n");
		fprintf(cSourceOut, "	} else {\n");
		fprintf(cSourceOut, "		return 0;\n");
		fprintf(cSourceOut, "	}\n");
		fprintf(cSourceOut, "}\n");
		fprintf(cSourceOut, "void _stackPush(_Stack s, void* element) {\n");
		fprintf(cSourceOut, "	(*s)->elements[++((*s)->top)] = element;\n");
		fprintf(cSourceOut, "}\n");

		fprintf(cSourceOut, "void* _stackPop(_Stack s) {\n");
		fprintf(cSourceOut, "	return (*s)->elements[((*s)->top)--];\n");
		fprintf(cSourceOut, "}\n");

		fprintf(cSourceOut, "void* _stackTop(_Stack s) {\n");
		fprintf(cSourceOut, "	return (*s)->elements[(*s)->top];\n");
		fprintf(cSourceOut, "}\n");

		fprintf(cSourceOut, "void _stackInit(_Stack s) {\n");
		fprintf(cSourceOut, "	(*s) = (struct _StackAux*) malloc(sizeof(struct _StackAux*));\n");
		fprintf(cSourceOut, "	(*s)->elements = (void**) malloc(sizeof(void*) * _STACK_SIZE);\n");
		fprintf(cSourceOut, "	(*s)->top = -1;\n");
		fprintf(cSourceOut, "}\n");
		fprintf(cSourceOut, "struct _LazyAssignmentValue {\n");
		fprintf(cSourceOut, "    char* lexpr;\n");
		fprintf(cSourceOut, "    void*(*func)(_Vector);\n");
		fprintf(cSourceOut, "    _Vector args;\n");
		fprintf(cSourceOut, "};\n");
		fprintf(cSourceOut, "_Stack _lazyAssignedValues;\n");
		fprintf(cSourceOut, "struct _LazyAssignmentValue* lavl;\n");
		fprintf(cSourceOut, "struct _LazyAssignmentValue* _isLazy(char* lexpr) {\n");
		fprintf(cSourceOut, "    struct _LazyAssignmentValue* lav = (struct _LazyAssignmentValue*) _stackTop(_lazyAssignedValues);\n");
		fprintf(cSourceOut, "    struct _LazyAssignmentValue* lavp;\n");
		fprintf(cSourceOut, "    for(lavp = lav; lavp < &lav[1024]; lavp++) {\n");
		fprintf(cSourceOut, "            if(lavp->lexpr && !strcmp(lavp->lexpr, lexpr)) {\n");
		fprintf(cSourceOut, "                return lavp;\n");
		fprintf(cSourceOut, "            }\n");
		fprintf(cSourceOut, "    }\n");
		fprintf(cSourceOut, "    return NULL;\n");
		fprintf(cSourceOut, "}\n");
		fprintf(cSourceOut, "void _deleteLazyValue(char* lexpr) {\n");
		fprintf(cSourceOut, "    struct _LazyAssignmentValue* lav = (struct _LazyAssignmentValue*) _stackTop(_lazyAssignedValues);\n");
		fprintf(cSourceOut, "    struct _LazyAssignmentValue* lavp;\n");
		fprintf(cSourceOut, "    for(lavp = lav; lavp < &lav[1024]; lavp++) {\n");
		fprintf(cSourceOut, "            if(lavp->lexpr && !strcmp(lavp->lexpr, lexpr)) {\n");
		fprintf(cSourceOut, "                lavp->lexpr = NULL;\n");
		fprintf(cSourceOut, "                return;\n");
		fprintf(cSourceOut, "            }\n");
		fprintf(cSourceOut, "    }\n");
		fprintf(cSourceOut, "}\n");
		fprintf(cSourceOut, "void _addLazyAssignedValue(char* lexpr, void*(*func)(_Vector), _Vector args) {\n");
		fprintf(cSourceOut, "    struct _LazyAssignmentValue* lav = (struct _LazyAssignmentValue*) _stackTop(_lazyAssignedValues);\n");
		fprintf(cSourceOut, "    struct _LazyAssignmentValue* lavp;\n");
		fprintf(cSourceOut, "    if(_isLazy(lexpr)) { _deleteLazyValue(lexpr); }");
		fprintf(cSourceOut, "    for(lavp = lav; lavp < &lav[1024]; lavp++) {\n");
		fprintf(cSourceOut, "        if(!lavp->lexpr) {\n");
		fprintf(cSourceOut, "            lavp->lexpr = strdup(lexpr);\n");
		fprintf(cSourceOut, "            lavp->func = func;\n");
		fprintf(cSourceOut, "            lavp->args = args;\n");
		fprintf(cSourceOut, "            return;\n");
		fprintf(cSourceOut, "        }\n");
		fprintf(cSourceOut, "    }\n");
		fprintf(cSourceOut, "}\n");
		appendFile(cSourceOut, types);
		appendFile(cSourceOut, funcsHeader);
		appendFile(cSourceOut, funcsDef);
		appendFile(cSourceOut, lazyFuncs);
		appendFile(cSourceOut, cSourceOutApp);
		fclose(cSourceOutApp);
		fclose(lazyFuncs);
		fclose(cSourceOut);	
		fclose(funcsDef);
		fclose(funcsHeader);
		fclose(firstParse);
		fclose(types);	
	}
}
