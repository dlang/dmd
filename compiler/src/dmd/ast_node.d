/**
 * Defines the base class for all nodes which are part of the AST.
 *
 * Copyright:   Copyright (C) 1999-2023 by The D Language Foundation, All Rights Reserved
 * Authors:     $(LINK2 https://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 https://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/src/dmd/ast_node.d, _ast_node.d)
 * Documentation:  https://dlang.org/phobos/dmd_ast_node.html
 * Coverage:    https://codecov.io/gh/dlang/dmd/src/master/src/dmd/ast_node.d
 */
module dmd.ast_node;

import dmd.visitor : Visitor;

/***********************************************************
 */

enum DYNCAST : int
{
    object,
    expression,
    dsymbol,
    type,
    identifier,
    tuple,
    parameter,
    statement,
    condition,
    templateparameter,
    initializer,
}

/***********************************************************
 */

extern (C++) class RootObject
{
    this() nothrow pure @nogc @safe scope
    {
    }

    bool equals(const RootObject o) const
    {
        return o is this;
    }

    const(char)* toChars() const
    {
        assert(0);
    }

    ///
    extern(D) const(char)[] toString() const
    {
        import core.stdc.string : strlen;
        auto p = this.toChars();
        return p[0 .. strlen(p)];
    }

    DYNCAST dyncast() const nothrow pure @nogc @safe
    {
        return DYNCAST.object;
    }
}


/// The base class of all AST nodes.
extern (C++) abstract class ASTNode : RootObject
{
    /**
     * Visits this AST node using the given visitor.
     *
     * Params:
     *  v = the visitor to use when visiting this node
     */
    abstract void accept(Visitor v);
}
