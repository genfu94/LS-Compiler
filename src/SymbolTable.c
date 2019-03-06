#include "SymbolTable.h"
#include <string.h>
#include <stdlib.h>
#include "Vector.h"

char* baseTypes[] = {"integer", "floating", "boolean", "char", "string", "null"};
struct SymbolTable functionScope[1024];

char* buildString(char* str1, char* str2) {
	char* out = (char*) malloc(sizeof(char)*(strlen(str1) + strlen(str2))+1);
	out[0]='\0';
	out = strcat(out, str1);
	out = strcat(out, str2);
	out[strlen(str1)+strlen(str2)]='\0';
	return out;
}

int addType(struct TypeInfo* typeInfo) {
	struct TypeInfo* tp;
	for(tp = typeTable; tp < &typeTable[1024]; tp++) {
    	if(tp->typeName && !strcmp(tp->typeName, typeInfo->typeName)) {
        	return 1; //Found a type with the same name
    	}
    	if(!tp->typeName) {
        	*tp = *typeInfo;
        	return 0; //inserted
    	}
	}
}

struct TypeInfo* searchType(char* typeName) {
	struct TypeInfo* tp;
	for(tp = typeTable; tp < &typeTable[1024]; tp++) {
    	if(tp->typeName && !strcmp(tp->typeName, typeName)) {
			return tp;
    	}
   	 
    	if(!tp->typeName) {
        	return NULL;
    	}
	}
}

int isABaseType(char* typeName) {
	for(int i = 0; i < 6; i++) {
		if(!strcmp(baseTypes[i], typeName)) {
			return 1;
		}
	}
	return 0;
}

struct VarInfo* addVariable(struct SymbolTable *table, char* varName, char* varType) {
	struct SymbolTable* sp;
	for(sp = table; sp < &table[1024]; sp++) {
    	if(sp->name && !strcmp(sp->name, varName)) {
        	return NULL;
    	}
   	 
    	if(!sp->name) {
        	sp->name = strdup(varName);
        	sp->symbolType = VARIABLE;
        	sp->symbolContent.varInfo = (struct VarInfo*) malloc(sizeof(struct VarInfo));
        	sp->symbolContent.varInfo->varType = strdup(varType);
        	return sp->symbolContent.varInfo;
    	}
	}
}

struct VarInfo* searchVariable(char* varName) {
	struct SymbolTable* sp;
	if(functionScope != NULL) {
    	for(sp = functionScope; sp < &functionScope[1024]; sp++) {
   			if(sp->name && !strcmp(sp->name, varName) && sp->symbolType == VARIABLE) {
   				return sp->symbolContent.varInfo;
   			}
   			if(!sp->name) {
   				break;
   			}
   		}
	}


	for(sp = symTab; sp < &symTab[1024]; sp++) {
   		if(sp->name && !strcmp(sp->name, varName) && sp->symbolType == VARIABLE) {
   			return sp->symbolContent.varInfo;
   		}
   		if(!sp->name) {
   			return NULL;
   		}
    }
}

int addFunction(char* funcName, struct FuncInfo* funcInfo) {
	struct SymbolTable* sp;
	for(sp = symTab; sp < &symTab[1024]; sp++) {
    	if(sp->name && !strcmp(sp->name, funcName)) {
        	return 1; //found or tipo diverso
    	}
    	if(!sp->name) {
        	sp->name = strdup(funcName);
        	sp->symbolType = FUNCTION;
			sp->symbolContent.funcInfo = funcInfo;
        	return 0; //inserted
    	}
	}
}

struct FuncInfo* searchFunction(char* funcName) {
	struct SymbolTable* sp;
	for(sp = symTab; sp < &symTab[1024]; sp++) {
    	if(sp->name && !strcmp(sp->name, funcName)) {
        	if(sp->symbolType == FUNCTION) {
       		 return sp->symbolContent.funcInfo; //found
        	}
    	}
   	 
    	if(!sp->name) {
        	return NULL;
    	}
	}
}

int doesIdentifierExist(char* name) {
	struct SymbolTable* sp;
	for(sp = symTab; sp < &symTab[1024]; sp++) {
    	if(sp->name && !strcmp(sp->name, name)){
        	return 1;
    	}
    	if(!sp->name) {
        	return 0;
    	}
	}
}

char* getCTypeEquivalent(char* type) {
	if (strcmp(type, "integer") == 0) {
		return "int";
	}
	else if (strcmp(type, "floating") == 0) {
		return "float";
	}
	else if (strcmp(type, "boolean") == 0) {
		return "int";
	}
	else if (strcmp(type, "char") == 0) {
		return "char";
	}
	else if (strcmp(type, "string") == 0) {
		return "char*";
	}
	else if (strcmp(type, "null") == 0) {
		return "void";
	} else {
		return buildString("struct ", buildString(type, "*"));
	}
}

struct RecordField* isFieldOfRecord(char* fieldName, struct TypeInfo* typeInfo) {
	int i;
	struct RecordField *currField;
	if(typeInfo->typeConstructor != REC) {
		return 0;
	}
	
	Vector recordFields = typeInfo->typeValue.recordFields;
	for(i = 0; i < getSize(recordFields); i++) {
		currField = (struct RecordField*) get(recordFields, i);
		if(!strcmp(currField->fieldName, fieldName)) {
			return currField;
		}
	}
	
	return NULL;
}

void clearFuncScope() {
	struct SymbolTable* sp;
	for(sp = functionScope; sp < &functionScope[1024]; sp++) {
    	sp->name = NULL;
    }
}

void printFunctionArguments(FILE* f, struct FuncInfo* fi) {
	struct ArgumentValue* argValue;
	if(getSize(fi->argumentValues) > 0) {
		argValue = (struct ArgumentValue*) get(fi->argumentValues, 0);
		fprintf(f, "%s %s", getCTypeEquivalent(argValue->argType), argValue->argName);
		for(int i = 1; i < getSize(fi->argumentValues); i++) {
			argValue = (struct ArgumentValue*) get(fi->argumentValues, i);
			fprintf(f, ", %s %s", getCTypeEquivalent(argValue->argType), argValue->argName);
		}
	}
}

void printMainArgsInitialization(FILE* f, struct FuncInfo* fi) {
	struct ArgumentValue* argValue;
	for(int i = 0; i < getSize(fi->argumentValues); i++) {
		argValue = (struct ArgumentValue*) get(fi->argumentValues, i);
		fprintf(f, "%s %s", getCTypeEquivalent(argValue->argType), argValue->argName);
		
		if(!strcmp(argValue->argType, "integer")) { fprintf(f, " = atoi(args[%d]);\n", i+1); }
		else if(!strcmp(argValue->argType, "floating")) { fprintf(f, " = atof(args[%d]);\n", i+1); }
		else if(!strcmp(argValue->argType, "char")) { fprintf(f, " = args[%d][0];\n", i+1); }
		else if(!strcmp(argValue->argType, "string")) { fprintf(f, " = args[%d];\n", i+1); }
		else if(!strcmp(argValue->argType, "boolean")) { fprintf(f, " = (!strcmp(args[%d], \"true\") ? 1 : 0);\n", i+1); }
	}
}

void printInitializedVariables(FILE* f, struct SymbolTable* syt) {
	struct SymbolTable* sp;
	for(sp = syt; sp < &syt[1024]; sp++) {
		if(sp->name && sp->symbolType == VARIABLE && sp->symbolContent.varInfo->initialized == 1) {
			fprintf(f, "%s = %s;\n", sp->name, sp->symbolContent.varInfo->varInit);
		}
	}
}

void printCopyFunctionSig(FILE* f, struct TypeInfo* ti) {
	if(ti->typeConstructor != BASE) {
		fprintf(f, "%s _copy%s(%s arg)", getCTypeEquivalent(ti->typeName), ti->typeName, getCTypeEquivalent(ti->typeName));
	} else {
		if(!strcmp(ti->typeName, "string")) {
			fprintf(f, "%s _copy%s(%s arg)", getCTypeEquivalent(ti->typeName), ti->typeName, getCTypeEquivalent(ti->typeName));
		} else {
			fprintf(f, "%s* _copy%s(%s arg)", getCTypeEquivalent(ti->typeName), ti->typeName, getCTypeEquivalent(ti->typeName));
		}
	}
}

void printCopyFunctionsPrototype(FILE* f) {
	struct TypeInfo* ti;
	for(ti = typeTable; ti < &typeTable[1024]; ti++) {
		if(ti->typeName && strcmp(ti->typeName, "null")) {
			printCopyFunctionSig(f, ti);
			fprintf(f, ";\n");
		}
	}
}

int calcArraySize(struct ArrayValue av) {
	int tot = 1;
	for(int i = 0; i < av.totDimensions; i++) {
		tot *= av.dimensions[i].integerDim;
	}
	
	return tot;
}

void printCopyFunctionsDef(FILE* f) {
	struct TypeInfo* ti;
	struct RecordField* recField;
	for(ti = typeTable; ti < &typeTable[1024]; ti++) {
		if(ti->typeName && strcmp(ti->typeName, "null")) {
			printCopyFunctionSig(f, ti);
			fprintf(f, " {\n");
			switch(ti->typeConstructor) {
				case BASE:
					if(!strcmp(ti->typeName, "string")) {
						fprintf(f, "\t%s out = strdup(arg);\n", getCTypeEquivalent(ti->typeName));
					} else {
						fprintf(f, "\t%s* out = (%s*) malloc(sizeof(%s));\n", getCTypeEquivalent(ti->typeName), 
							getCTypeEquivalent(ti->typeName), getCTypeEquivalent(ti->typeName));
						fprintf(f, "\t*out = arg;\n");
					}
					break;
				case ARR:
					fprintf(f, "\t%s out = (%s) malloc(sizeof(struct %s));\n", getCTypeEquivalent(ti->typeName), 
						getCTypeEquivalent(ti->typeName), ti->typeName);
					fprintf(f, "\tmemcpy(out->array, arg->array, sizeof(int)*%d);\n", calcArraySize(ti->typeValue.arrayValue));
					break;
				case REC:
					fprintf(f, "\t%s out = (%s) malloc(sizeof(struct %s));\n", getCTypeEquivalent(ti->typeName), 
						getCTypeEquivalent(ti->typeName), ti->typeName);
					for(int i = 0; i < getSize(ti->typeValue.recordFields); i++) {
						recField = (struct RecordField*) get(ti->typeValue.recordFields, i);
						if(!isABaseType(recField->fieldType)) {
							fprintf(f, "\tif(arg->%s != NULL) {\n\t\tout->%s = _copy%s(arg->%s);\n\t}\n",
										recField->fieldName, recField->fieldName, recField->fieldType, recField->fieldName);
						} else {
							fprintf(f, "\tout->%s = arg->%s;\n", recField->fieldName, recField->fieldName);
						}
					}
					break;
			}
			fprintf(f, "\treturn out;\n}\n");
		}
	}
}

void appendFile(FILE* f1, FILE* f2) {
	char ch;
	fseek(f2, 0, SEEK_SET);
	fseek(f1, 0, SEEK_END);
	while ((ch = fgetc(f2)) != EOF) {
		fputc(ch, f1);
	}
}
