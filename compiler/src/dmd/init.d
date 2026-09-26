/**
 * Defines the auxiliary types for initializers of variables, e.g. the array literal in `int[3] x = [0, 1, 2]`.
 *
 * Copyright:   Copyright (C) 1999-2026 by The D Language Foundation, All Rights Reserved
 * Authors:     $(LINK2 https://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 https://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/compiler/src/dmd/init.d, _init.d)
 * Documentation:  https://dlang.org/phobos/dmd_init.html
 * Coverage:    https://codecov.io/gh/dlang/dmd/src/master/compiler/src/dmd/init.d
 */

module dmd.init;

import dmd.arraytypes;
import dmd.expression;
import dmd.identifier;
import dmd.location;

enum NeedInterpret : int
{
    INITnointerpret,
    INITinterpret,
}

alias INITnointerpret = NeedInterpret.INITnointerpret;
alias INITinterpret = NeedInterpret.INITinterpret;

alias Initializer = Expression;

/***********************************************************
 * Holds the `designator` for C initializers
 */
struct Designator
{
    Expression exp;     /// [ constant-expression ]
    Identifier ident;   /// . identifier

    this(Expression exp) @safe { this.exp = exp; }
    this(Identifier ident) @safe  { this.ident = ident; }
}

/*********************************************
 * Holds the `designation (opt) initializer` for C initializers
 */
struct DesigInit
{
    Designators* designatorList; /// designation (opt)
    Initializer initializer;     /// initializer
}

/*********************************************
 * int[3] a = [1: 2, 3];
 */
struct ArrayBuilder(AST)
{
    AST.Expressions* keys;
    AST.Expressions* values;

    void addInit(AST.Expression index, AST.Expression value)
    {
        if (!values)
            values = new AST.Expressions();
        if (index && !keys)
        {
            keys = new AST.Expressions(values.length);
            keys.zero();
        }
        if (keys)
            keys.push(index);
        values.push(value);
    }

    void addValue(AST.Expression value)
    {
        addInit(null, value);
    }

    AST.Expression finish(Loc loc)
    {
        if (!values)
            values = new AST.Expressions();
        if (keys)
            return new AST.AssocArrayLiteralExp(loc, keys, values);
        return new AST.ArrayLiteralExp(loc, null, values);
    }
}
