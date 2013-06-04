
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

typedef ArrayBase<class TemplateParameter> TemplateParameters;

typedef ArrayBase<class Expression> Expressions;

typedef ArrayBase<class Statement> Statements;

typedef ArrayBase<class BaseClass> BaseClasses;

typedef ArrayBase<class ClassDeclaration> ClassDeclarations;

typedef ArrayBase<class Dsymbol> Dsymbols;

typedef ArrayBase<class Object> Objects;

typedef ArrayBase<class FuncDeclaration> FuncDeclarations;

typedef ArrayBase<class Parameter> Parameters;

typedef ArrayBase<class Identifier> Identifiers;

typedef ArrayBase<class Initializer> Initializers;

typedef ArrayBase<class VarDeclaration> VarDeclarations;

typedef ArrayBase<class Type> Types;

typedef ArrayBase<class ScopeDsymbol> ScopeDsymbols;

typedef ArrayBase<class Catch> Catches;

typedef ArrayBase<class StaticDtorDeclaration> StaticDtorDeclarations;

typedef ArrayBase<class SharedStaticDtorDeclaration> SharedStaticDtorDeclarations;

typedef ArrayBase<class AliasDeclaration> AliasDeclarations;

typedef ArrayBase<class Module> Modules;

typedef ArrayBase<class File> Files;

typedef ArrayBase<class CaseStatement> CaseStatements;

typedef ArrayBase<class CompoundStatement> CompoundStatements;

typedef ArrayBase<class GotoCaseStatement> GotoCaseStatements;

typedef ArrayBase<class ReturnStatement> ReturnStatements;

typedef ArrayBase<class TemplateInstance> TemplateInstances;

//typedef ArrayBase<char> Strings;

typedef ArrayBase<void> Voids;

typedef ArrayBase<struct block> Blocks;

typedef ArrayBase<struct Symbol> Symbols;

typedef ArrayBase<struct dt_t> Dts;
#endif
