// Compiler implementation of the D programming language
// Copyright (c) 1999-2015 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// http://www.digitalmars.com
// Distributed under the Boost Software License, Version 1.0.
// http://www.boost.org/LICENSE_1_0.txt

module ddmd.arraytypes;

import ddmd.aggregate;
import ddmd.gluelayer;
import ddmd.dclass;
import ddmd.declaration;
import ddmd.dmodule;
import ddmd.dsymbol;
import ddmd.dtemplate;
import ddmd.expression;
import ddmd.func;
import ddmd.globals;
import ddmd.identifier;
import ddmd.init;
import ddmd.mtype;
import ddmd.root.array;
import ddmd.root.file;
import ddmd.root.rootobject;
import ddmd.statement;

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
