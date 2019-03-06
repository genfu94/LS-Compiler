#include "Stack.h"
#include <stdio.h>

int stackEmpty(Stack s) {
	if((*s)->top == -1) {
		return 1;
	} else {
		return 0;
	}
}

void stackPush(Stack s, void* element) {
	(*s)->elements[++((*s)->top)] = element;
}

void* stackPop(Stack s) {
	if(stackEmpty(s)) { return NULL; }
	else { return (*s)->elements[((*s)->top)--]; }
}

void* stackTop(Stack s) {
	if(stackEmpty(s)) { return NULL; }
	else { return (*s)->elements[(*s)->top]; }
}

void stackInit(Stack s) {
	(*s) = (struct StackAux*) malloc(sizeof(struct StackAux*));
	(*s)->elements = (void**) malloc(sizeof(void*) * STACK_SIZE);
	(*s)->top = -1;
}
