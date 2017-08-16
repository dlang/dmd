/**
 * Compiler implementation of the
 * $(LINK2 http://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (c) 1999-2017 by Digital Mars, All Rights Reserved
 * Authors:     $(LINK2 http://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(DMDSRC _mtype.d)
 */

module ddmd.typesem;

import ddmd.arraytypes;
import ddmd.dsymbol;
import ddmd.expression;
import ddmd.globals;
import ddmd.identifier;
import ddmd.init;
import ddmd.visitor;
import ddmd.mtype;
import ddmd.root.rootobject;
import ddmd.tokens;

private extern (C++) final class TypeToExpressionVisitor : Visitor
{
    alias visit = super.visit;

    Expression result;
    Type itype;

    this() {}

    this(Type itype)
    {
        this.itype = itype;
    }

    override void visit(Type t)
    {
        result = null;
    }

    override void visit(TypeSArray t)
    {
        Expression e = t.next.typeToExpression();
        if (e)
            e = new ArrayExp(t.dim.loc, e, t.dim);
        result = e;
    }

    override void visit(TypeAArray t)
    {
        Expression e = t.next.typeToExpression();
        if (e)
        {
            Expression ei = t.index.typeToExpression();
            if (ei)
            {
                result = new ArrayExp(t.loc, e, ei);
                return;
            }
        }
        result = null;
    }

    override void visit(TypeIdentifier t)
    {
        result = typeToExpressionHelper(t, new IdentifierExp(t.loc, t.ident));
    }

    override void visit(TypeInstance t)
    {
        result = typeToExpressionHelper(t, new ScopeExp(t.loc, t.tempinst));
    }
}

/* We've mistakenly parsed this as a type.
 * Redo it as an Expression.
 * NULL if cannot.
 */
extern (C++) Expression typeToExpression(Type t)
{
    scope v = new TypeToExpressionVisitor();
    t.accept(v);
    return v.result;
}

/* Helper function for `typeToExpression`. Contains common code
 * for TypeQualified derived classes.
 */
extern (C++) Expression typeToExpressionHelper(TypeQualified t, Expression e, size_t i = 0)
{
    //printf("toExpressionHelper(e = %s %s)\n", Token.toChars(e.op), e.toChars());
    for (; i < t.idents.dim; i++)
    {
        RootObject id = t.idents[i];
        //printf("\t[%d] e: '%s', id: '%s'\n", i, e.toChars(), id.toChars());

        switch (id.dyncast())
        {
            // ... '. ident'
            case DYNCAST.identifier:
                e = new DotIdExp(e.loc, e, cast(Identifier)id);
                break;

            // ... '. name!(tiargs)'
            case DYNCAST.dsymbol:
                auto ti = (cast(Dsymbol)id).isTemplateInstance();
                assert(ti);
                e = new DotTemplateInstanceExp(e.loc, e, ti.name, ti.tiargs);
                break;

            // ... '[type]'
            case DYNCAST.type:          // https://issues.dlang.org/show_bug.cgi?id=1215
                e = new ArrayExp(t.loc, e, new TypeExp(t.loc, cast(Type)id));
                break;

            // ... '[expr]'
            case DYNCAST.expression:    // https://issues.dlang.org/show_bug.cgi?id=1215
                e = new ArrayExp(t.loc, e, cast(Expression)id);
                break;

            default:
                assert(0);
        }
    }
    return e;
}
