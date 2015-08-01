
/* Compiler implementation of the D programming language
 * Copyright (c) 2006-2014 by Digital Mars
 * All Rights Reserved
 * written by Walter Bright
 * http://www.digitalmars.com
 * Distributed under the Boost Software License, Version 1.0.
 * http://www.boost.org/LICENSE_1_0.txt
 * https://github.com/D-Programming-Language/dmd/blob/master/src/arraytypes.h
 */

#ifndef DMD_ARRAYTYPES_H
#define DMD_ARRAYTYPES_H

#ifdef __DMC__
#pragma once
#endif /* __DMC__ */


#include "root.h"

typedef Array<class TemplateParameter *> TemplateParameters;

typedef Array<class Expression *> Expressions;

typedef Array<class Statement *> Statements;

typedef Array<struct BaseClass *> BaseClasses;

typedef Array<class ClassDeclaration *> ClassDeclarations;

typedef Array<class Dsymbol *> Dsymbols;

typedef Array<class RootObject *> Objects;

typedef Array<class FuncDeclaration *> FuncDeclarations;

typedef Array<class Parameter *> Parameters;

typedef Array<class Identifier *> Identifiers;

typedef Array<class Initializer *> Initializers;

typedef Array<class VarDeclaration *> VarDeclarations;

typedef Array<class Type *> Types;
typedef Array<class Catch *> Catches;

typedef Array<class StaticDtorDeclaration *> StaticDtorDeclarations;

typedef Array<class SharedStaticDtorDeclaration *> SharedStaticDtorDeclarations;

typedef Array<class AliasDeclaration *> AliasDeclarations;

typedef Array<class Module *> Modules;

typedef Array<struct File *> Files;

typedef Array<class CaseStatement *> CaseStatements;

typedef Array<class ScopeStatement *> ScopeStatements;

typedef Array<class GotoCaseStatement *> GotoCaseStatements;

typedef Array<class ReturnStatement *> ReturnStatements;

typedef Array<class GotoStatement *> GotoStatements;

typedef Array<class TemplateInstance *> TemplateInstances;

#endif
