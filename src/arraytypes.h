
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

typedef Array<struct TemplateParameter> TemplateParameters;

typedef Array<struct Expression> Expressions;

typedef Array<struct Statement> Statements;

typedef Array<struct BaseClass> BaseClasses;

typedef Array<struct ClassDeclaration> ClassDeclarations;

typedef Array<struct Dsymbol> Dsymbols;

typedef Array<struct Object> Objects;

typedef Array<struct FuncDeclaration> FuncDeclarations;

typedef Array<struct Parameter> Parameters;

typedef Array<struct Identifier> Identifiers;

typedef Array<struct Initializer> Initializers;

typedef Array<struct VarDeclaration> VarDeclarations;

typedef Array<struct Type> Types;

typedef Array<struct ScopeDsymbol> ScopeDsymbols;

typedef Array<struct Catch> Catches;

typedef Array<struct StaticDtorDeclaration> StaticDtorDeclarations;

typedef Array<struct SharedStaticDtorDeclaration> SharedStaticDtorDeclarations;

typedef Array<struct AliasDeclaration> AliasDeclarations;

typedef Array<struct Module> Modules;

typedef Array<struct File> Files;

typedef Array<struct CaseStatement> CaseStatements;

typedef Array<struct CompoundStatement> CompoundStatements;

typedef Array<struct GotoCaseStatement> GotoCaseStatements;

typedef Array<struct TemplateInstance> TemplateInstances;

typedef Array<char> Strings;

typedef Array<void> Voids;

typedef Array<struct block> Blocks;

typedef Array<struct Symbol> Symbols;

#endif
