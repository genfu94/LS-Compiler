#include "SymbolTable.h"
#include "ExpressionEvaluation.h"


char** s;
int topElement = -1;

int empty()
{
	if(topElement == -1) {
		return(1);
	} else {
		return(0);
	}
}

void push(char* elem)
{                       /* Function for PUSH operation */
	s[++topElement]=elem;
}

char* pop()
{                      /* Function for POP operation */
    return s[topElement--];
}

char* top()
{
   return s[topElement];
}

int priority(char elem)
{                 /* Function for precedence */
    switch(elem)
    {
    case '#': return 0;
    case '(': return 1;
    case '+':
    case '-': return 2;
    case '*':
    case '/': return 3;
    }
}

int isOperator(char o) {
    switch(o) {
        case '(':
        case ')':
        case '+':
        case '-':
        case '*':
        case '/': return 1;
        default: return 0;
    }
}

int evaluate(char x,int op1,int op2)
{
    if(x=='+')
        return(op1+op2);
    if(x=='-')
        return(op1-op2);
    if(x=='*')
        return(op1*op2);
    if(x=='/')
        return(op1/op2);
    if(x=='%')
        return(op1%op2);
}

char* getNextToken(char* s, int i, int *w) {
	int k = 0;
	while(s[i] == ' ') {
		i++;
		k++;
	}
	
	if(s[i] == '\0') {
		return NULL;
	}
	
    if(isOperator(s[i]) == 1) {
    	char* out = (char*) malloc(sizeof(char));
    	out[0] = s[i];
    	*w = 1+k;
    	out[1+k] = '\0';
    	return out;
    } else {
        int j;
        char* out = (char*) malloc(strlen(s) - i);
        for(j = 0; s[i] != '\0' && !isOperator(s[i]) && s[i] != ' '; i++, j++) {
            out[j] = s[i];
        }
        *w = j+k;
        out[j+k] = '\0';
        return out;
    }
}

char* infixToPostfix (char* infixString) {
    int i=0;
    int *w = (int*) malloc(sizeof(int));
	char* pofx = (char*) malloc(sizeof(char)*strlen(infixString)*2);
	pofx[0] = '\0';
	char* currToken;
	char* x;
	
	while(currToken = getNextToken(infixString, i, w)) {
		if(isOperator(currToken[0])) {
			if(currToken[0] == '(') {
				push("(");
			}
			else
			{
				if(currToken[0] == ')') {
					x = pop();
					while(strcmp(x, "(")) {
						strcat(pofx, x);
						x = pop();
					}
				} else {
					while(!empty() && priority(currToken[0]) <= priority(top()[0]))
             		{
						x=pop();
						strcat(pofx, x);
					}
					push(currToken);
				}
			}
		} else {
			strcat(pofx, currToken);
			strcat(pofx, " ");
		}
		i = i + *w;
    }

    while(!empty())
    {
    	x=pop();
    	strcat(pofx, x);
    }

	return pofx;
}

int postfixEvaluation (char* postfixExpr) {
    char* currToken;
    int i = 0;
    int *w = (int*) malloc(sizeof(int));
    char stringResult[15];
	while(currToken = getNextToken(postfixExpr, i, w)) {
		if(isOperator(currToken[0])) {
		    int num2 = atoi(pop());
		    int num1 = atoi(pop());
		    int result = evaluate(currToken[0], num1, num2);
		    sprintf(stringResult, "%d", result);
		    push(strdup(stringResult));
		} else {
		    push(currToken);
		}
		i = i + *w;
	}
	return atoi(pop());
}

int isNumber (char* token) {
	for (int i = 0; i<strlen(token); i++) {
		if (!isdigit(token[i]))
			return 0;
	}
	return 1;
}

char* variableExprToValueExpr (char* expr) {
	char* out = (char*)malloc(sizeof(char)*(strlen(expr)*14));
	char* currToken;
    int i = 0;
    int *w = (int*) malloc(sizeof(int));
	struct VarInfo* vi;
	
	out[0] = '\0';
	while (currToken = getNextToken(expr, i, w)) {
		if(isNumber(currToken) || isOperator(currToken[0])) {
			out = strcat(out, currToken);
		} else {
			vi = searchVariable(currToken);
			if(vi == NULL || vi->initialized==0 || strcmp(vi->varType, "integer")) { return NULL; }
			else {
				char* subExpr = variableExprToValueExpr(vi->varInit);
				if(subExpr == NULL) { return NULL; }
				out = strcat(out, subExpr);
			}
		}
		i = i+*w;
	}

	return out;
}

int evaluateString(char* stringExpr) {
	char* pofx = infixToPostfix(stringExpr);
	return postfixEvaluation(pofx);
}
