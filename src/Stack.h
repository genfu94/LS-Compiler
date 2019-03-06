#ifndef STACK_H
#define STACK_H

#include <stdlib.h>

#define STACK_SIZE 1024
#define createStack(s) s = (struct StackAux**)malloc(sizeof(struct StackAux*))

struct StackAux {
	void** elements;
	int top;
};

typedef struct StackAux** Stack; 

void stackInit(Stack s);
int stackEmpty(Stack s);
void stackPush(Stack s, void* element);
void* stackPop(Stack s);
void* stackTop(Stack s);

#endif
