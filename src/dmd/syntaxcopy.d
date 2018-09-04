/**
 * Compiler implementation of the
 * $(LINK2 http://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (C) 1999-2018 by The D Language Foundation, All Rights Reserved
 * Authors:     $(LINK2 http://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/src/dmd/syntaxcopy.d, _syntaxcopy.d)
 * Documentation:  https://dlang.org/phobos/dmd_syntaxcopy.html
 * Coverage:    https://codecov.io/gh/dlang/dmd/src/master/src/dmd/syntaxcopy.d
 */

module dmd.syntaxcopy;

import dmd.cond;
import dmd.visitor;

package:

/**
 * Make a deep copy of a front end AST node.
 * Params:
 *      from = AST node to make a new copy of
 * Returns:
 *      the resulting copy
 */
Condition syntaxCopy(Condition from)
{
    scope SyntaxCopyVisitor scv = new SyntaxCopyVisitor();
    from.accept(scv);
    return scv.condition;
}

private:

extern (C++) final class SyntaxCopyVisitor : Visitor
{
    alias visit = Visitor.visit;

    Condition condition;

    extern(D) this()
    {
    }

    override void visit(DVCondition from)
    {
        condition = from; // don't need to copy
    }

    override void visit(StaticIfCondition from)
    {
        condition = new StaticIfCondition(from.loc, from.exp.syntaxCopy());
    }
}
