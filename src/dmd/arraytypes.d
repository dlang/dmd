/**
 * Compiler implementation of the
 * $(LINK2 http://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (c) 1999-2017 by Digital Mars, All Rights Reserved
 * Authors:     $(LINK2 http://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(DMDSRC _arraytypes.d)
 */

module dmd.arraytypes;

import dmd.dclass;
import dmd.declaration;
import dmd.dmodule;
import dmd.dsymbol;
import dmd.dtemplate;
import dmd.expression;
import dmd.func;
import dmd.identifier;
import dmd.init;
import dmd.mtype;
import dmd.root.array;
import dmd.root.rootobject;
import dmd.statement;

alias Strings = Array!(const(char)*);
alias Identifiers = Array!(Identifier);
alias TemplateParameters = Array!(TemplateParameter);
alias Expressions = Array!(Expression);
alias Statements = Array!(Statement);
alias BaseClasses = Array!(BaseClass*);
alias ClassDeclarations = Array!(ClassDeclaration);
alias Dsymbols = Array!(Dsymbol);
alias Objects = Array!(RootObject);
alias FuncDeclarations = Array!(FuncDeclaration);
alias Parameters = Array!(Parameter);
alias Initializers = Array!(Initializer);
alias VarDeclarations = Array!(VarDeclaration);
alias Types = Array!(Type);
alias Catches = Array!(Catch);
alias StaticDtorDeclarations = Array!(StaticDtorDeclaration);
alias SharedStaticDtorDeclarations = Array!(SharedStaticDtorDeclaration);
alias AliasDeclarations = Array!(AliasDeclaration);
alias Modules = Array!(Module);
alias CaseStatements = Array!(CaseStatement);
alias ScopeStatements = Array!(ScopeStatement);
alias GotoCaseStatements = Array!(GotoCaseStatement);
alias ReturnStatements = Array!(ReturnStatement);
alias GotoStatements = Array!(GotoStatement);
alias TemplateInstances = Array!(TemplateInstance);
