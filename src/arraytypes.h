
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

typedef Array<class TemplateParameter> TemplateParameters;

typedef Array<class Expression> Expressions;

typedef Array<class Statement> Statements;

typedef Array<class BaseClass> BaseClasses;

typedef Array<class ClassDeclaration> ClassDeclarations;

typedef Array<class Dsymbol> Dsymbols;

typedef Array<class RootObject> Objects;

typedef Array<class FuncDeclaration> FuncDeclarations;

typedef Array<class Parameter> Parameters;

typedef Array<class Identifier> Identifiers;

typedef Array<class Initializer> Initializers;

typedef Array<class VarDeclaration> VarDeclarations;

typedef Array<class Type> Types;

typedef Array<class ScopeDsymbol> ScopeDsymbols;

typedef Array<class Catch> Catches;

typedef Array<class StaticDtorDeclaration> StaticDtorDeclarations;

typedef Array<class SharedStaticDtorDeclaration> SharedStaticDtorDeclarations;

typedef Array<class AliasDeclaration> AliasDeclarations;

typedef Array<class Module> Modules;

typedef Array<struct File> Files;

typedef Array<class CaseStatement> CaseStatements;

typedef Array<class ScopeStatement> ScopeStatements;

typedef Array<class GotoCaseStatement> GotoCaseStatements;

typedef Array<class GotoStatement> GotoStatements;

typedef Array<class ReturnStatement> ReturnStatements;

typedef Array<class TemplateInstance> TemplateInstances;

//typedef Array<char> Strings;

typedef Array<void> Voids;

typedef Array<struct block> Blocks;

typedef Array<struct Symbol> Symbols;

typedef Array<struct dt_t> Dts;
#endif
