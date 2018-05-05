/**
 * Compiler implementation of the
 * $(LINK2 http://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (C) 1999-2018 by The D Language Foundation, All Rights Reserved
 * Authors:     $(LINK2 http://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/src/dmd/compiler.d, _compiler.d)
 * Documentation:  https://dlang.org/phobos/dmd_compiler.html
 * Coverage:    https://codecov.io/gh/dlang/dmd/src/master/src/dmd/compiler.d
 */

module dmd.compiler;

///
struct Compiler
{
    /// Compiler backend name
    const(char)* vendor;
}

/**
 * Initializes the dmd lexer and all required components in order
 *
 * It is templated (so D only) to prevent
 *  errors on local imports to things that may not exist.
 *
 * See_Also:
 *     lexerDeinit
 */
void lexerInit()()
{
    import dmd.globals : global;
    import dmd.id : Id;
    import dmd.tokens : Token;
    import dmd.identifier : Identifier;

    global._init();
    Identifier.initTable();

    // Id MUST be initialized after Token
    Token.initialize();
    Id.initialize();
}

/**
 * Deinitializers the dmd lexer and all required components in order
 *
 * It is templated (so D only) to prevent
 *  errors on local imports to things that may not exist.
 *
 * See_Also:
 *     lexerInit
 */
void lexerDeinit()()
{
    import dmd.globals : global, Global;
    import dmd.id : Id;
    import dmd.tokens : Token;
    import dmd.identifier : Identifier;

    Id.deinitialize();
    Token.deinitialize();
    Identifier.deinitTable();

    // we reset this manually, just to prevent any chance of pinning memory
    // but this approach does currently leak when !version(GC)
    // which is quite a problem... but out of scope for now
    global = Global.init;
}
