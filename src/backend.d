// Compiler implementation of the D programming language
// Copyright (c) 1999-2015 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// http://www.digitalmars.com
// Distributed under the Boost Software License, Version 1.0.
// http://www.boost.org/LICENSE_1_0.txt

module ddmd.backend;

import ddmd.aggregate;
import ddmd.dmodule;
import ddmd.dscope;
import ddmd.expression;
import ddmd.lib;
import ddmd.mtype;
import ddmd.root.file;

struct Symbol;
struct TYPE;
alias type = TYPE;
struct code;
struct block;

extern extern (C++) void backend_init();
extern extern (C++) void backend_term();
extern extern (C++) void obj_start(char* srcfile);
extern extern (C++) void obj_end(Library library, File* objfile);
extern extern (C++) void obj_write_deferred(Library library);

extern extern (C++) Type getTypeInfoType(Type t, Scope* sc);
extern extern (C++) Expression getInternalTypeInfo(Type t, Scope* sc);
extern extern (C++) void genObjFile(Module m, bool multiobj);

extern extern (C++) Symbol* toInitializer(AggregateDeclaration sd);
extern extern (C++) Symbol* toModuleArray(Module m);
extern extern (C++) Symbol* toModuleAssert(Module m);
extern extern (C++) Symbol* toModuleUnittest(Module m);
