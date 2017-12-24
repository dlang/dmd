//===-- ldcbindings.d -----------------------------------------------------===//
//
//                         LDC – the LLVM D compiler
//
// This file is distributed under the BSD-style LDC license. See the LICENSE
// file for details.
//
//===----------------------------------------------------------------------===//

module ddmd.ldcbindings;

import ddmd.expression;
import ddmd.globals;
import ddmd.identifier;
import ddmd.mtype;
import ddmd.declaration;
import ddmd.dsymbol;
import ddmd.tokens;
import std.traits;
import std.stdio;
import std.string;
import std.conv;

/+ This mixin defines "createClassName" functions for all constructors of T, returning T*.
 + createClassName(...) must be used in C++ code instead of "new ClassName(...)".
 + For structs it returns a T (non-ptr).
 + Many thanks to Chris Wright for authoring the initial version.
 +/
private string factory(T)() {
    string s;
    int count = __traits(getOverloads, T, "__ctor").length;
    if (count == 0) {
        s = `ClassName createClassName() { return new ClassName(); }`;
    } else {
        for (int i = 0; i < count; i++) {
            s ~= `ClassName createClassName(Parameters!(__traits(getOverloads, ClassName, "__ctor")[OVERLOAD]) params) {
                return new ClassName(params);
            }
            `.replace("OVERLOAD", i.to!string);
        }
    }
    static if (is(T == struct)) {
        s = s.replace("new", "");
    }
    return s.replace("ClassName", T.stringof.split('.')[$-1]);
}
// helper functions to create D objects
extern(C++):
mixin(factory!IntegerExp);
mixin(factory!LogicalExp);
mixin(factory!EqualExp);
mixin(factory!CmpExp);
mixin(factory!ShlExp);
mixin(factory!ShrExp);
mixin(factory!UshrExp);
mixin(factory!NotExp);
mixin(factory!ComExp);
mixin(factory!OrExp);
mixin(factory!AndExp);
mixin(factory!XorExp);
mixin(factory!ModExp);
mixin(factory!MulExp);
mixin(factory!DivExp);
mixin(factory!AddExp);
mixin(factory!MinExp);
mixin(factory!NegExp);
mixin(factory!AddrExp);
mixin(factory!RealExp);
mixin(factory!DsymbolExp);
mixin(factory!Expression);
mixin(factory!TypeDelegate);
mixin(factory!TypeIdentifier);
