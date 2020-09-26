/**
 * Provide aliases for arrays of certain declarations or statements.
 *
 * Copyright:   Copyright (C) 1999-2020 by The D Language Foundation, All Rights Reserved
 * Authors:     $(LINK2 http://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/src/dmd/arraytypes.d, _arraytypes.d)
 * Documentation:  https://dlang.org/phobos/dmd_arraytypes.html
 * Coverage:    https://codecov.io/gh/dlang/dmd/src/master/src/dmd/arraytypes.d
 */

module dmd.arraytypes;

import dmd.dclass : ClassDeclaration, BaseClass;
import dmd.declaration : AliasDeclaration, VarDeclaration;
import dmd.dmodule : Module;
import dmd.dsymbol : Dsymbol;
import dmd.dtemplate : TemplateParameter, TemplateInstance;
import dmd.expression;
import dmd.func : FuncDeclaration, DtorDeclaration, Ensure, StaticDtorDeclaration, SharedStaticDtorDeclaration;
import dmd.identifier : Identifier;
import dmd.init : Initializer;
import dmd.mtype : Parameter, Type;
import dmd.root.array : Array;
import dmd.root.rootobject : RootObject;
import dmd.statement : Statement, ReturnStatement, GotoStatement, ScopeStatement, GotoCaseStatement, CaseStatement, Catch;

alias Strings = Array!(const(char)*);
alias Identifiers = Array!(Identifier);
alias TemplateParameters = Array!(TemplateParameter);
alias Expressions = Array!(Expression);
alias Statements = Array!(Statement);
alias BaseClasses = Array!(BaseClass*);
alias ClassDeclarations = Array!(ClassDeclaration);
alias Dsymbols = Array!(Dsymbol);
alias Objects = Array!(RootObject);
alias DtorDeclarations = Array!(DtorDeclaration);
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
alias Ensures = Array!(Ensure);
