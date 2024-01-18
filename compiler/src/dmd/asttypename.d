/**
 * Development utility for printing AST nodes by their internal name, instead of as D source code.
 *
 * Copyright:   Copyright (C) 1999-2024 by The D Language Foundation, All Rights Reserved
 * Authors:     Stefan Koch
 * License:     $(LINK2 https://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/src/dmd/asttypename.d, _asttypename.d)
 * Documentation:  https://dlang.org/phobos/dmd_asttypename.html
 * Coverage:    https://codecov.io/gh/dlang/dmd/src/master/src/dmd/asttypename.d
 */

module dmd.asttypename;

import dmd.ast_node;
import dmd.attrib;
import dmd.aliasthis;
import dmd.aggregate;
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
import dmd.identifier;
import dmd.init;
import dmd.root.complex;
import dmd.rootobject;
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
        case DYNCAST.object:
            return "RootObject";
        case DYNCAST.identifier:
            return "Identifier";
        case DYNCAST.tuple:
            return "Tuple";

        case DYNCAST.expression:
            return astTypeName(cast(Expression) node);
        case DYNCAST.dsymbol:
            return astTypeName(cast(Dsymbol) node);
        case DYNCAST.type:
            return astTypeName(cast(Type) node);
        case DYNCAST.parameter:
            return astTypeName(cast(Parameter) node);
        case DYNCAST.statement:
            return astTypeName(cast(Statement) node);
        case DYNCAST.condition:
            return astTypeName(cast(Condition) node);
        case DYNCAST.templateparameter:
            return astTypeName(cast(TemplateParameter) node);
        case DYNCAST.initializer:
            return astTypeName(cast(Initializer) node);
    }
}

extern(D) enum mixin_string =
({
    string astTypeNameFunctions;
    string visitOverloads;

    foreach (ov; __traits(getOverloads, Visitor, "visit"))
    {
        static if (is(typeof(ov) P == function))
        {
            static if (is(P[0] S == super) && is(S[0] == ASTNode))
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
private extern(C++) final class AstTypeNameVisitor : Visitor
{
    alias visit = Visitor.visit;
public :
    string typeName;
` ~ visitOverloads ~ "}";
}());

// pragma(msg, mixin_string);
mixin(mixin_string);
///
unittest
{
    import dmd.location;
    Expression e = new TypeidExp(Loc.initial, null);
    Tuple t = new Tuple();
    TemplateTypeParameter tp = new TemplateTypeParameter(Loc.initial, null, null, null);
    assert(e.astTypeName == "TypeidExp");
    assert(t.astTypeName == "Tuple");
    assert(tp.astTypeName == "TemplateTypeParameter");
}
