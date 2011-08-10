
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

typedef ArrayBase<struct TemplateParameter> TemplateParameters;

typedef ArrayBase<struct Expression> Expressions;

typedef ArrayBase<struct Statement> Statements;

typedef ArrayBase<struct BaseClass> BaseClasses;

typedef ArrayBase<struct ClassDeclaration> ClassDeclarations;

typedef ArrayBase<struct Dsymbol> Dsymbols;

typedef ArrayBase<struct Object> Objects;

typedef ArrayBase<struct FuncDeclaration> FuncDeclarations;

typedef ArrayBase<struct Parameter> Parameters;

typedef ArrayBase<struct Identifier> Identifiers;

typedef ArrayBase<struct Initializer> Initializers;

typedef ArrayBase<struct VarDeclaration> VarDeclarations;

typedef ArrayBase<struct Type> Types;

typedef ArrayBase<struct ScopeDsymbol> ScopeDsymbols;
typedef ArrayBase<struct Module> Modules;
typedef ArrayBase<struct CaseStatement> CaseStatements;
typedef ArrayBase<struct TemplateInstance> TemplateInstances;

typedef ArrayBase<struct Symbol> Symbols;

#endif
