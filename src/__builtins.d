/* This D file is implicitly imported by all ImportC source files.
 * It provides definitions for C compiler builtin functions and declarations.
 * The purpose is to make it unnecessary to hardwire them into the compiler.
 * As the leading double underscore suggests, this is for internal use only.
 *
 * Copyright: Copyright Digital Mars 2022
 * License:   $(HTTP www.boost.org/LICENSE_1_0.txt, Boost License 1.0).
 * Authors:   Walter Bright
 * Source: $(DRUNTIMESRC __builtins.d)
 */


module __builtins;

import core.stdc.stdarg;

@nogc nothrow:
extern (C):

alias va_list = core.stdc.stdarg.va_list;

void __builtin_va_start(va_list, ...);
void __builtin_va_end(va_list);
