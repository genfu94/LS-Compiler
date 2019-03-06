#ifndef SYMBOL_TABLE_H
#define SYMBOL_TABLE_H

#include "Vector.h"

extern char* baseTypes[];

struct ArrayDimension {
	int integerDim;
	char* stringDim;
};

struct ArrayValue {
	char* arrayType;
	struct ArrayDimension dimensions[10];
	int totDimensions;
};

struct RecordField {
	char* fieldType;
	char* fieldName;
};

struct ArgumentValue {
	char* argType;
	char* argName;
};

struct TypeInfo {
	char* typeName;
	enum TypeConstructor {BASE, ARR, REC} typeConstructor;
	union TypeValue {
		struct ArrayValue arrayValue;
		Vector recordFields;
	} typeValue;
} typeTable[1024];

struct FuncInfo {
	char* funcBody;
	char* returnType;
	Vector argumentValues;
};

struct VarInfo {
	int initialized;
	char* varType;
	char* varInit;
	int integerVal;
};

struct SymbolTable {
	char* name;
	enum SymbolType {VARIABLE, FUNCTION} symbolType;
	union SymbolContent {
		struct VarInfo* varInfo;
		struct FuncInfo* funcInfo;
	} symbolContent;
} symTab[1024];

extern struct SymbolTable functionScope[1024];

int addType(struct TypeInfo* typeInfo);
struct TypeInfo* searchType(char* typeName);
int isABaseType(char* typeName);
struct VarInfo* addVariable(struct SymbolTable *table, char* varName, char* varType);
struct VarInfo* searchVariable(char* varName);
int addFunction(char* funcName, struct FuncInfo* funcInfo);
struct FuncInfo* searchFunction(char* funcName);
int doesIdentifierExist(char* name);
char* getCTypeEquivalent(char* type);
char* buildString(char* str1, char* str2);
struct RecordField* isFieldOfRecord(char* fieldName, struct TypeInfo* typeInfo);
void clearFuncScope();
void printFunctionArguments(FILE* f, struct FuncInfo* fi);
void printMainArgsInitialization(FILE* f, struct FuncInfo* fi);
void printInitializedVariables(FILE* f, struct SymbolTable* syt);
void printCopyFunctionSig(FILE* f, struct TypeInfo* ti);
void printCopyFunctionsPrototype(FILE* f);
int calcArraySize(struct ArrayValue av);
void printCopyFunctionsDef(FILE* f);
void appendFile(FILE* f1, FILE* f2);

#endif
