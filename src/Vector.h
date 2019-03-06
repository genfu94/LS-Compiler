#ifndef VECTOR_H
#define VECTOR_H

#include <stdio.h>
#include <stdlib.h>

#define INITIAL_VECTOR_SIZE 20
#define createVector(v) v = (VectorAux**)malloc(sizeof(VectorAux*))  

typedef struct VectorAux {
	int size;
	int maxSize;
	void** elements;
} VectorAux;

typedef VectorAux** Vector;

void initVector(Vector v);
void add(Vector v, void* el);
void* get(Vector v, int i);
int getSize(Vector v);

#endif