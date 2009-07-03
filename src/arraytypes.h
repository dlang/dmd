
// Compiler implementation of the D programming language
// Copyright (c) 2006-2007 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// www.digitalmars.com
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

struct TemplateParameters : Array { };

struct Expressions : Array { };

struct Statements : Array { };

struct BaseClasses : Array { };

struct ClassDeclarations : Array { };

struct Dsymbols : Array { };

struct Objects : Array { };

struct FuncDeclarations : Array { };

struct Arguments : Array { };

#endif
