/**
 * Development utility for printing AST nodes by their internal name, instead of as D source code.
 *
 * Copyright:   Copyright (C) 1999-2026 by The D Language Foundation, All Rights Reserved
 * Authors:     Stefan Koch
 * License:     $(LINK2 https://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/compiler/src/dmd/ast/typename.d, _typename.d)
 * Documentation:  https://dlang.org/phobos/dmd_ast_typename.html
 * Coverage:    https://codecov.io/gh/dlang/dmd/src/master/compiler/src/dmd/ast/typename.d
 */

module dmd.ast.asttypename;

import dmd.ast.node;
import dmd.ast.attrib;
import dmd.ast.aliasthis;
import dmd.ast.aggregate;
import dmd.ast.cond;
import dmd.ast.dclass;
import dmd.ast.declaration;
import dmd.ast.denum;
import dmd.ast.dimport;
import dmd.ast.init;
import dmd.ast.dmodule;
import dmd.ast.dstruct;
import dmd.ast.dsymbol;
import dmd.ast.dtemplate;
import dmd.ast.dversion;
import dmd.ast.expression;
import dmd.ast.func;
import dmd.ast.mtype;
import dmd.ast.nspace;
import dmd.ast.statement;
import dmd.ast.staticassert;

import dmd.identifier;
import dmd.root.complex;
import dmd.rootobject;


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
