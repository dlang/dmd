/**
 * Part of the Compiler implementation of the D programming language
 * Copyright:   Copyright (c) 1999-2017 by The D Language Foundation, All Rights Reserved
 * Authors:     Stefan Koch
 * License:     $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(DMDSRC _asttypename.d)
 */

module ddmd.asttypename;

import ddmd.attrib;
import ddmd.aliasthis;
import ddmd.aggregate;
import ddmd.complex;
import ddmd.cond;
import ddmd.ctfeexpr;
import ddmd.dclass;
import ddmd.declaration;
import ddmd.denum;
import ddmd.dimport;
import ddmd.declaration;
import ddmd.dstruct;
import ddmd.dsymbol;
import ddmd.dtemplate;
import ddmd.dversion;
import ddmd.expression;
import ddmd.func;
import ddmd.denum;
import ddmd.dimport;
import ddmd.dmodule;
import ddmd.mtype;
import ddmd.typinf;
import ddmd.identifier;
import ddmd.init;
import ddmd.doc;
import ddmd.root.rootobject;
import ddmd.statement;
import ddmd.staticassert;
import ddmd.nspace;
import ddmd.visitor;

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
    import ddmd.globals : Loc;
    Expression e = new TypeidExp(Loc.init, null);
    assert(e.astTypeName == "TypeidExp");
}
