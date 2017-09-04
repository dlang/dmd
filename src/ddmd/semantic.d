module ddmd.semantic;

import ddmd.dsymbol;
import ddmd.dsymbolsem;
import ddmd.dscope;
import ddmd.expression;
import ddmd.expressionsem;
import ddmd.init;
import ddmd.initsem;
import ddmd.mtype;
import ddmd.statement;
import ddmd.statementsem;

/*************************************
 * Does semantic analysis on the public face of declarations.
 */
extern(C++) void semantic(Dsymbol dsym, Scope* sc)
{
    scope v = new DsymbolSemanticVisitor(sc);
    dsym.accept(v);
}

// entrypoint for semantic ExpressionSemanticVisitor
extern (C++) Expression semantic(Expression e, Scope* sc)
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
extern (C++) Initializer semantic(Initializer init, Scope* sc, Type t, NeedInterpret needInterpret)
{
    scope v = new InitializerSemanticVisitor(sc, t, needInterpret);
    init.accept(v);
    return v.result;
}

// Performs semantic analisys in Statement AST nodes
extern (C++) Statement semantic(Statement s, Scope* sc)
{
    scope v = new StatementSemanticVisitor(sc);
    s.accept(v);
    return v.result;
}

void semantic(Catch c, Scope* sc)
{
    semanticWrapper(c, sc);
}

/*************************************
 * Does semantic analysis on function bodies.
 */
extern(C++) void semantic3(Dsymbol dsym, Scope* sc)
{
    scope v = new Semantic3Visitor(sc);
    dsym.accept(v);
}
