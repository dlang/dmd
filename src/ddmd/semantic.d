/**
 * Compiler implementation of the
 * $(LINK2 http://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (c) 1999-2017 by Digital Mars, All Rights Reserved
 * Authors:     $(LINK2 http://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/src/ddmd/semantic.d, _semantic.d)
 */

module ddmd.semantic;

// Online documentation: https://dlang.org/phobos/ddmd_semantic.html

import ddmd.arraytypes;
import ddmd.dsymbol;
import ddmd.dscope;
import ddmd.dtemplate;
import ddmd.expression;
import ddmd.globals;
import ddmd.init;
import ddmd.mtype;
import ddmd.statement;

import ddmd.initsem;
import ddmd.dsymbolsem;
import ddmd.expressionsem;
import ddmd.statementsem;
import ddmd.templateparamsem;
import ddmd.typesem;

/*************************************
 * Does semantic analysis on the public face of declarations.
 */
extern(C++) void semantic(Dsymbol dsym, Scope* sc)
{
    scope v = new DsymbolSemanticVisitor(sc);
    dsym.accept(v);
}

// entrypoint for semantic ExpressionSemanticVisitor
extern(C++) Expression semantic(Expression e, Scope* sc)
{
    scope v = new ExpressionSemanticVisitor(sc);
    e.accept(v);
    return v.result;
}

/******************************************
 * Perform semantic analysis on init.
 * Params:
 *      init = Initializer AST node
 *      sc = context
 *      t = type that the initializer needs to become
 *      needInterpret = if CTFE needs to be run on this,
 *                      such as if it is the initializer for a const declaration
 * Returns:
 *      `Initializer` with completed semantic analysis, `ErrorInitializer` if errors
 *      were encountered
 */
extern(C++) Initializer semantic(Initializer init, Scope* sc, Type t, NeedInterpret needInterpret)
{
    scope v = new InitializerSemanticVisitor(sc, t, needInterpret);
    init.accept(v);
    return v.result;
}

// Performs semantic analisys in Statement AST nodes
extern(C++) Statement semantic(Statement s, Scope* sc)
{
    scope v = new StatementSemanticVisitor(sc);
    s.accept(v);
    return v.result;
}

/******************************************
 * Perform semantic analysis on a type.
 * Params:
 *      t = Type AST node
 *      loc = the location of the type
 *      sc = context
 * Returns:
 *      `Type` with completed semantic analysis, `Terror` if errors
 *      were encountered
 */
extern(C++) Type semantic(Type t, Loc loc, Scope* sc)
{
    scope v = new TypeSemanticVisitor(loc, sc);
    t.accept(v);
    return  v.result;
}


void semantic(Catch c, Scope* sc)
{
    semanticWrapper(c, sc);
}

/*************************************
 * Does semantic analysis on initializers and members of aggregates.
 */
extern(C++) void semantic2(Dsymbol dsym, Scope* sc)
{
    scope v = new Semantic2Visitor(sc);
    dsym.accept(v);
}

/*************************************
 * Does semantic analysis on function bodies.
 */
extern(C++) void semantic3(Dsymbol dsym, Scope* sc)
{
    scope v = new Semantic3Visitor(sc);
    dsym.accept(v);
}
