#include "Vector.h"

void initVector(Vector v) {
	(*v) = (VectorAux*) malloc(sizeof(VectorAux*));
	(*v)->elements = (void**) malloc(sizeof(void*) * INITIAL_VECTOR_SIZE);
	(*v)->size = 0;
	(*v)->maxSize = INITIAL_VECTOR_SIZE;
}

void add(Vector v, void* el) {
	if((*v)->size + 1 > (*v)->maxSize) {
		int newSize = (*v)->maxSize * 2;
		(*v)->elements = (void*) realloc((*v)->elements, sizeof(void*) * newSize);
		(*v)->maxSize = newSize;
	}
	(*v)->elements[(*v)->size++] = el;
}

void* get(Vector v, int i) {
	if(i >= (*v)->maxSize) {
		return NULL;
	}
	
	return (*v)->elements[i];
}

int getSize(Vector v) {
	return (*v)->size;
}