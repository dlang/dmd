/**
 * Part of the Compiler implementation of the D programming language
 * Copyright:   Copyright (c) 1999-2017 by The D Language Foundation, All Rights Reserved
 * Authors:     Stefan Koch
 * License:     $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(DMDSRC _asttypename.d)
 */

module dmd.asttypename;

import dmd.attrib;
import dmd.aliasthis;
import dmd.aggregate;
import dmd.complex;
import dmd.cond;
import dmd.ctfeexpr;
import dmd.dclass;
import dmd.declaration;
import dmd.denum;
import dmd.dimport;
import dmd.declaration;
import dmd.dstruct;
import dmd.dsymbol;
import dmd.dtemplate;
import dmd.dversion;
import dmd.expression;
import dmd.func;
import dmd.denum;
import dmd.dimport;
import dmd.dmodule;
import dmd.mtype;
import dmd.typinf;
import dmd.identifier;
import dmd.init;
import dmd.doc;
import dmd.root.rootobject;
import dmd.statement;
import dmd.staticassert;
import dmd.nspace;
import dmd.visitor;

/// Returns: the typename of the dynamic ast-node-type
/// (this is a development tool, do not use in actual code)
string astTypeName(RootObject node)
{
    final switch (node.dyncast())
    {
        case DYNCAST_OBJECT:
            return "RootObject";
        case DYNCAST_IDENTIFIER:
            return "Identifier";

        case DYNCAST_EXPRESSION:
            return astTypeName(cast(Expression) node);
        case DYNCAST_DSYMBOL:
            return astTypeName(cast(Dsymbol) node);
        case DYNCAST_TYPE:
            return astTypeName(cast(Type) node);
        case DYNCAST_TUPLE:
            return astTypeName(cast(Tuple) node);
        case DYNCAST_PARAMETER:
            return astTypeName(cast(Parameter) node);
        case DYNCAST_STATEMENT:
            return astTypeName(cast(Statement) node);
    }
}

mixin
({
    string astTypeNameFunctions;
    string visitOverloads;

    foreach (ov; __traits(getOverloads, Visitor, "visit"))
    {
        static if (is(typeof(ov) P == function))
        {
            static if (is(P[0] S == super) && is(S[0] == RootObject))
            {
                astTypeNameFunctions ~= `
string astTypeName(` ~ P[0].stringof ~ ` node)
{
    scope tsv = new AstTypeNameVisitor;
    node.accept(tsv);
    return tsv.typeName;
}
`;
            }

            visitOverloads ~= `
    override void visit (` ~ P[0].stringof ~ ` _)
    {
        typeName = "` ~ P[0].stringof ~ `";
    }
`;
        }
    }

    return astTypeNameFunctions ~ `
extern(C++) final class AstTypeNameVisitor : Visitor
{
    alias visit = super.visit;
public :
    string typeName;
` ~ visitOverloads ~ "}";
}());

///
unittest
{
    import dmd.globals : Loc;
    Expression e = new TypeidExp(Loc.init, null);
    assert(e.astTypeName == "TypeidExp");
}
