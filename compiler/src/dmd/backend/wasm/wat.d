/**
 * WebAssembly text (WAT) disassembly of generated function bodies, for `-vasm`.
 *
 * Copyright:   Copyright (C) 1999-2026 by The D Language Foundation, All Rights Reserved
 * License:     $(LINK2 https://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/compiler/src/dmd/backend/wasm/wat.d, _wat.d)
 */

module dmd.backend.wasm.wat;

import dmd.backend.cc;
import dmd.backend.symbol;
import dmd.backend.wasm.codgen : localWasmType;
import dmd.backend.wasm.enums;
import dmd.backend.wasm.obj;
import dmd.backend.wasm.util : readsLEB128, readuLEB128;
import dmd.common.outbuffer;

nothrow:

private immutable string[] namespaces =
[
    "i32", "i64", "f32", "f64", "v128", "local", "global", "memory",
    "i8x16", "i16x8", "i32x4", "i64x2", "f32x4", "f64x2",
];

// Convert enum name like I32_CONST to i32.const (kindy hacky, separate table would probably be better)
private string enumToWat(string m)
{
    string s;
    foreach (c; m)
        s ~= (c >= 'A' && c <= 'Z') ? cast(char)(c + ('a' - 'A')) : c;

    size_t u = 0;
    while (u < s.length && s[u] != '_')
        ++u;
    if (u < s.length)
        foreach (ns; namespaces)
            if (s[0 .. u] == ns)
                return s[0 .. u] ~ "." ~ s[u + 1 .. $];
    return s;
}

private string[256] buildSubNames(E)()
{
    string[256] names;
    static foreach (m; __traits(allMembers, E))
    {{
        enum uint v = __traits(getMember, E, m);
        static if (v < 256)
            names[v] = enumToWat(m);
    }}
    return names;
}

private immutable opNames = () {
    string[256] names = buildSubNames!OP();
    names[OP.FC_PREFIX] = null;
    names[OP.FD_PREFIX] = null;
    return names;
} ();

private immutable simdNames = buildSubNames!WASM_SIMD();
private immutable fcNames = buildSubNames!WASM_FC();

private const(char)* typeName(ubyte b)
{
    switch (b)
    {
        case WASM_TYPE.I32:    return "i32";
        case WASM_TYPE.I64:    return "i64";
        case WASM_TYPE.F32:    return "f32";
        case WASM_TYPE.F64:    return "f64";
        case WASM_TYPE.V128:   return "v128";
        case WASM_TYPE.EXNREF: return "exnref";
        default:               return "?";
    }
}

private struct Reader
{
    const(ubyte)[] code;
    const(WasmReloc)[] relocs;
    size_t pos;

nothrow:

    bool empty() const => pos >= code.length;

    ubyte pop()
    {
        return pos < code.length ? code[pos++] : 0;
    }

    ulong uleb() => readuLEB128(code, pos);

    long sleb() => readsLEB128(code, pos);

    const(WasmReloc)* relocHere()
    {
        foreach (ref const r; relocs)
            if (r.offset == pos)
                return &r;
        return null;
    }
}

private void printIndex(ref Reader r, ref OutBuffer buf)
{
    if (auto rel = r.relocHere())
    {
        r.pos += 5;
        if (rel.sym)
            buf.printf(" $%.*s", cast(int) rel.sym.identifier.length, rel.sym.identifier.ptr);
        else
            buf.printf(" %u", rel.symIdx);
        if (rel.addend)
            buf.printf("+%u", rel.addend);
        return;
    }
    buf.printf(" %llu", cast(ulong) r.uleb());
}

private void printBlockType(ref Reader r, ref OutBuffer buf)
{
    const ubyte b = r.pop();
    if (b == WASM_VOID_BLOCK)
        return;
    if (b >= 0x69)
        buf.printf(" (result %s)", typeName(b));
    else
    {
        --r.pos;
        buf.printf(" (type %lld)", r.sleb());
    }
}

private void printMemArg(ref Reader r, ref OutBuffer buf, uint natural)
{
    const ulong a = r.uleb();
    const ulong off = r.uleb();
    if (off)
        buf.printf(" offset=%llu", off);
    if (a != natural)
        buf.printf(" align=%llu", cast(ulong)(1UL << a));
}

private void printCatches(ref Reader r, ref OutBuffer buf)
{
    const ulong n = r.uleb();
    foreach (i; 0 .. n)
    {
        const ubyte kind = r.pop();
        switch (kind)
        {
            case WASM_CATCH.CATCH:         buf.writestring(" catch");         break;
            case WASM_CATCH.CATCH_REF:     buf.writestring(" catch_ref");     break;
            case WASM_CATCH.CATCH_ALL:     buf.writestring(" catch_all");     break;
            case WASM_CATCH.CATCH_ALL_REF: buf.writestring(" catch_all_ref"); break;
            default:                       buf.writestring(" catch?");        break;
        }
        if (kind == WASM_CATCH.CATCH || kind == WASM_CATCH.CATCH_REF)
            printIndex(r, buf);
        buf.printf(" %llu", r.uleb());
    }
}

private void printSimd(ref Reader r, ref OutBuffer buf)
{
    const ulong sub = r.uleb();
    const string name = sub < 256 ? simdNames[cast(size_t) sub] : null;
    if (name.length)
        buf.writestring(name);
    else
        buf.printf("v128.op:%llu", sub);

    switch (sub)
    {
        case WASM_SIMD.V128_LOAD, WASM_SIMD.V128_STORE:
            printMemArg(r, buf, 4);
            break;
        case WASM_SIMD.V128_CONST:
            buf.writestring(" i8x16");
            foreach (i; 0 .. 16)
                buf.printf(" 0x%02x", r.pop());
            break;
        default:
            break;
    }
}

private void printPrefixedFC(ref Reader r, ref OutBuffer buf)
{
    const ulong sub = r.uleb();
    const string name = sub < 256 ? fcNames[cast(size_t) sub] : null;
    if (name.length)
        buf.writestring(name);
    else
        buf.printf("fc.op:%llu", sub);

    if (sub == WASM_FC.MEMORY_COPY)
    {
        r.uleb();
        r.uleb();
    }
    else if (sub == WASM_FC.MEMORY_FILL)
        r.uleb();
}

/**
 * Append `fb`'s code as WebAssembly text, one instruction per line prefixed with
 * its offset in the code body.
 *
 * At this point the relocated immediates (call targets, data addresses, tag and
 * type indices) still hold placeholder bytes, so operands covered by a
 * relocation are printed from the relocation instead of from the byte stream.
 *
 * Params:
 *      fb = generated function body
 *      buf = buffer to append the text to
 */
void wasmDisassemble(ref WasmFuncBody fb, ref OutBuffer buf)
{
    Symbol* sym = cast(Symbol*) fb.sym;
    buf.printf("(func $%.*s", cast(int) sym.identifier.length, sym.identifier.ptr);

    const ft = wmod_funcTypeForSym(sym);
    if (ft.params.length)
    {
        buf.writestring(" (param");
        foreach (p; ft.params)
            buf.printf(" %s", typeName(p));
        buf.writestring(")");
    }
    if (ft.results.length)
    {
        buf.writestring(" (result");
        foreach (t; ft.results)
            buf.printf(" %s", typeName(t));
        buf.writestring(")");
    }
    buf.writestring("\n");

    foreach (Symbol* l; fb.locals[fb.numParams .. $])
        buf.printf("  (local %s)\n", typeName(localWasmType(l)));

    wasmDisassembleCode(fb.code.peekSlice(), fb.relocs, buf);
}

/**
 * Append `code` as WebAssembly text, one instruction per line prefixed with its
 * offset, followed by the closing paren of the enclosing `(func`.
 *
 * Params:
 *      code = instruction bytes
 *      relocs = relocations into `code`, printed in place of the placeholder bytes
 *      buf = buffer to append the text to
 */
void wasmDisassembleCode(const(ubyte)[] code, const(WasmReloc)[] relocs, ref OutBuffer buf)
{
    auto r = Reader(code, relocs, 0);
    int depth = 1;

    while (!r.empty)
    {
        const uint off = cast(uint) r.pos;
        const ubyte op = r.pop();

        if (op == OP.END || op == OP.ELSE)
            --depth;

        buf.printf("%04x:", off);
        const int nest = depth < 0 ? 0 : depth;
        foreach (i; 0 .. nest)
            buf.writestring("  ");

        switch (op)
        {
            case OP.FD_PREFIX:
                printSimd(r, buf);
                break;

            case OP.FC_PREFIX:
                printPrefixedFC(r, buf);
                break;

            default:
            {
                const string name = opNames[op];
                if (name.length)
                    buf.writestring(name);
                else
                    buf.printf("op:0x%02x", op);

                switch (op)
                {
                    case OP.BLOCK, OP.LOOP, OP.IF:
                        printBlockType(r, buf);
                        break;

                    case OP.TRY_TABLE:
                        printBlockType(r, buf);
                        printCatches(r, buf);
                        break;

                    case OP.BR, OP.BR_IF, OP.LOCAL_GET, OP.LOCAL_SET, OP.LOCAL_TEE,
                         OP.GLOBAL_GET, OP.GLOBAL_SET, OP.MEMORY_SIZE, OP.MEMORY_GROW,
                         OP.RETURN_CALL:
                        buf.printf(" %llu", r.uleb());
                        break;

                    case OP.CALL, OP.THROW:
                        printIndex(r, buf);
                        break;

                    case OP.CALL_INDIRECT, OP.RETURN_CALL_INDIRECT:
                        buf.writestring(" (type");
                        printIndex(r, buf);
                        buf.writestring(")");
                        printIndex(r, buf);
                        break;

                    case OP.BR_TABLE:
                    {
                        const ulong n = r.uleb();
                        foreach (i; 0 .. n + 1)
                            buf.printf(" %llu", r.uleb());
                        break;
                    }

                    case OP.I32_CONST:
                        if (r.relocHere())
                            printIndex(r, buf);
                        else
                            buf.printf(" %lld", r.sleb());
                        break;

                    case OP.I64_CONST:
                        buf.printf(" %lld", r.sleb());
                        break;

                    case OP.F32_CONST:
                    {
                        float f;
                        foreach (i; 0 .. 4)
                            (cast(ubyte*) &f)[i] = r.pop();
                        buf.printf(" %g", cast(double) f);
                        break;
                    }

                    case OP.F64_CONST:
                    {
                        double d;
                        foreach (i; 0 .. 8)
                            (cast(ubyte*) &d)[i] = r.pop();
                        buf.printf(" %g", d);
                        break;
                    }

                    default:
                        if (op >= OP.I32_LOAD && op <= OP.I64_STORE32)
                            printMemArg(r, buf, naturalAlign(cast(OP) op));
                        break;
                }
                break;
            }
        }
        buf.writestring("\n");

        if (op == OP.BLOCK || op == OP.LOOP || op == OP.IF || op == OP.ELSE || op == OP.TRY_TABLE)
            ++depth;
    }
    buf.writestring(")\n");
}

unittest
{
    static string disasm(const(ubyte)[] code)
    {
        OutBuffer buf;
        wasmDisassembleCode(code, null, buf);
        return buf[].idup;
    }

    assert(disasm([OP.LOCAL_GET, 2, OP.I32_CONST, 0x7f, OP.I32_ADD, OP.RETURN, OP.END]) ==
"0000:  local.get 2
0002:  i32.const -1
0004:  i32.add
0005:  return
0006:end
)
");

    assert(disasm([OP.BLOCK, WASM_VOID_BLOCK, OP.LOOP, WASM_VOID_BLOCK,
                   OP.BR_TABLE, 2, 0, 1, 3, OP.END, OP.END]) ==
"0000:  block
0002:    loop
0004:      br_table 0 1 3
0009:    end
000a:  end
)
");

    assert(disasm([OP.I32_LOAD, 2, 8, OP.I64_STORE, 3, 0,
                   OP.F64_CONST, 0, 0, 0, 0, 0, 0, 0xf0, 0x3f]) ==
"0000:  i32.load offset=8
0003:  i64.store
0006:  f64.const 1
)
");

    // opcodes past 0x7f are LEB128 encoded
    assert(disasm([OP.FD_PREFIX, 0xAE, 0x01]) == "0000:  i32x4.add\n)\n");
    assert(disasm([OP.FC_PREFIX, WASM_FC.I32_TRUNC_SAT_F64_S]) == "0000:  i32.trunc_sat_f64_s\n)\n");

    assert(disasm([OP.FD_PREFIX, WASM_SIMD.V128_LOAD, 3, 16,
                   OP.FD_PREFIX, WASM_SIMD.V128_STORE, 4, 0]) ==
"0000:  v128.load offset=16 align=8
0004:  v128.store
)
");

    assert(disasm([OP.FD_PREFIX, WASM_SIMD.V128_CONST,
                   1, 0, 0, 0, 2, 0, 0, 0, 3, 0, 0, 0, 4, 0, 0, 0]) ==
"0000:  v128.const i8x16 0x01 0x00 0x00 0x00 0x02 0x00 0x00 0x00 0x03 0x00 0x00 0x00 0x04 0x00 0x00 0x00
)
");

    assert(disasm([OP.FC_PREFIX, WASM_FC.MEMORY_COPY, 0, 0,
                   OP.FC_PREFIX, WASM_FC.MEMORY_FILL, 0]) ==
"0000:  memory.copy
0004:  memory.fill
)
");

    assert(disasm([OP.BLOCK, WASM_TYPE.I32, OP.GLOBAL_GET, 3, OP.ELSE, OP.END]) ==
"0000:  block (result i32)
0002:    global.get 3
0004:  else
0005:  end
)
");

    assert(disasm([OP.TRY_TABLE, WASM_VOID_BLOCK, 2,
                   WASM_CATCH.CATCH, 3, 1, WASM_CATCH.CATCH_ALL, 0, OP.END]) ==
"0000:  try_table catch 3 1 catch_all 0
0008:  end
)
");

    assert(disasm([OP.CALL_INDIRECT, 7, 0, OP.F32_CONST, 0, 0, 0x80, 0x3f, OP.DROP]) ==
"0000:  call_indirect (type 7) 0
0003:  f32.const 1
0008:  drop
)
");

    // an unnatural alignment is printed, a natural one is implied
    assert(disasm([OP.I32_LOAD8_U, 0, 4, OP.I64_LOAD16_S, 2, 0]) ==
"0000:  i32.load8_u offset=4
0003:  i64.load16_s align=4
)
");

    // unknown opcodes are printed as their encoding instead of being skipped
    assert(disasm([0x06]) == "0000:  op:0x06\n)\n");
    assert(disasm([OP.FD_PREFIX, 0xAC, 0x02]) == "0000:  v128.op:300\n)\n");
    assert(disasm([OP.FC_PREFIX, 20]) == "0000:  fc.op:20\n)\n");
}
