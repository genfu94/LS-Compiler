#ifndef EXPRESSION_EVALUATION_H
#define EXPRESSION_EVALUATION_H

#include <ctype.h>
#include <stdio.h>
#include <string.h>
#include <stdlib.h>

//#define STACK_SIZE 1024

extern char** s;
extern int topElement;

int empty();
void push(char* elem);
char* pop();
char* top();
int priority(char elem);
int isOperator(char o);
int evaluate(char x,int op1,int op2);
char* getNextToken(char* s, int i, int *w);
char* infixToPostfix (char* infixString);
int postfixEvaluation (char* postfixExpr);
int evaluateString(char* stringExpr);
int isNumber(char* token);
char* variableExprToValueExpr (char* expr);

#endif
