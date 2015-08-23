// Compiler implementation of the D programming language
// Copyright (c) 1999-2015 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// http://www.digitalmars.com
// Distributed under the Boost Software License, Version 1.0.
// http://www.boost.org/LICENSE_1_0.txt

module ddmd.arraytypes;

import ddmd.aggregate, ddmd.backend, ddmd.dclass, ddmd.declaration, ddmd.dmodule, ddmd.dsymbol, ddmd.dtemplate, ddmd.expression, ddmd.func, ddmd.globals, ddmd.identifier, ddmd.init, ddmd.mtype, ddmd.root.array, ddmd.root.file, ddmd.root.rootobject, ddmd.statement;

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
