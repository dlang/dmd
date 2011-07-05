
// Compiler implementation of the D programming language
// Copyright (c) 2006-2007 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// http://www.digitalmars.com
// License for redistribution is by either the Artistic License
// in artistic.txt, or the GNU General Public License in gnu.txt.
// See the included readme.txt for details.

#ifndef DMD_ARRAYTYPES_H
#define DMD_ARRAYTYPES_H

#ifdef __DMC__
#pragma once
#endif /* __DMC__ */


#include "root.h"

struct Expression;
struct Statement;
struct BaseClass;
struct TemplateParameter;
struct FuncDeclaration;
struct Identifier;
struct Initializer;

struct Dsymbol;
struct ClassDeclaration;
struct Parameter;

struct VarDeclaration;
struct Type;
struct ScopeDsymbol;
struct Catch;
struct StaticDtorDeclaration;
struct SharedStaticDtorDeclaration;
struct AliasDeclaration;
struct Module;
struct File;
struct CaseStatement;
struct CompoundStatement;
struct GotoCaseStatement;
struct TemplateInstance;
struct TemplateParameter;

struct block;
struct Symbol;

#define ArrayOf(TYPE) struct ArrayOf_##TYPE : ArrayBase \
{ \
    TYPE **tdata() { return (TYPE **)data; } \
    void insert(unsigned index, TYPE *v) { ArrayBase::insert(index, (void *)v); } \
    void insert(unsigned index, ArrayOf_##TYPE *a) { ArrayBase::insert(index, (ArrayBase *)a); } \
    void append(ArrayOf_##TYPE *a) { ArrayBase::append((ArrayBase *)a); } \
    void push(TYPE *a) { ArrayBase::push((void *)a); } \
    ArrayOf_##TYPE *copy() { return (ArrayOf_##TYPE *)ArrayBase::copy(); } \
}

typedef ArrayOf(TemplateParameter) TemplateParameters;

typedef ArrayOf(Expression) Expressions;

typedef ArrayOf(Statement) Statements;

typedef ArrayOf(BaseClass) BaseClasses;

typedef ArrayOf(ClassDeclaration) ClassDeclarations;

typedef ArrayOf(Dsymbol) Dsymbols;

typedef ArrayOf(Object) Objects;

typedef ArrayOf(FuncDeclaration) FuncDeclarations;

typedef ArrayOf(Parameter) Parameters;

typedef ArrayOf(Identifier) Identifiers;

typedef ArrayOf(Initializer) Initializers;

typedef ArrayOf(VarDeclaration) VarDeclarations;

typedef ArrayOf(Type) Types;

typedef ArrayOf(ScopeDsymbol) ScopeDsymbols;

typedef ArrayOf(Catch) Catches;

typedef ArrayOf(StaticDtorDeclaration) StaticDtorDeclarations;

typedef ArrayOf(SharedStaticDtorDeclaration) SharedStaticDtorDeclarations;

typedef ArrayOf(AliasDeclaration) AliasDeclarations;

typedef ArrayOf(Module) Modules;

typedef ArrayOf(File) Files;

typedef ArrayOf(CaseStatement) CaseStatements;

typedef ArrayOf(CompoundStatement) CompoundStatements;

typedef ArrayOf(GotoCaseStatement) GotoCaseStatements;

typedef ArrayOf(TemplateInstance) TemplateInstances;

typedef ArrayOf(char) Strings;

typedef ArrayOf(void) Voids;

typedef ArrayOf(block) Blocks;

typedef ArrayOf(Symbol) Symbols;

#endif
