#!/usr/bin/env python3
"""
Generates compiler/src/generated/cpp_layout_asserts.d from compiler/include/dmd/*.h.

Test whether the sizes, offsets, vtable layouts, and enum offsets match between:
compiler/include/*.h and compiler/src/*.d

Usage: gen_cpp_layout_test.py <include_dir> <output_file>

Parsed with libclang. Output is a D source file of static asserts that verify
enum values, field offsets/sizes, class instance sizes, vtable indices, and
C++ mangled names match between the C++ headers and the D extern(C++) declarations.
"""

import clang.cindex as cx
import ctypes
import os
import subprocess
import sys
from collections import Counter
from pathlib import Path

# Skip these headers because they are C++ compatibility shims
_SKIP_HEADERS = frozenset({
    "root/dcompat.h",
    "root/dsystem.h",
})

# Free functions in namespace dmd that are not wrapped in dmd.cxxfrontend on Linux
# (e.g. Windows/MSVC-only functions).
_SKIP_FREE_FUNCS = frozenset({
    "toCppMangleMSVC",
    "cppTypeInfoMangleMSVC",
})

# Skip these C++ class/struct names because they are D templates (TODO: instantiate these and check?)
_SKIP_TYPES = frozenset({
    "ParseTimeVisitor",   # D: class ParseTimeVisitor(AST) - template, visitor.h
    "Visitor",            # D: class Visitor : ParseTimeVisitor!ASTCodegen - template
    "StoppableVisitor",   # D: class StoppableVisitor : Visitor - template chain
})

# C++ enum member names mapped to a different D name (or None to skip).
# Default behaviour (no entry): use the C++ name unchanged.
# The trailing '_' that C++ adds to avoid C++ keyword conflicts usually survives
# unchanged into D, because most such names are also D keywords.  The exceptions
# below are names that are C++ keywords but NOT D keywords, so D spells them
# without the underscore.
_D_KEYWORD_RENAME: dict[tuple[str, str], str | None] = {
    ("Baseok", "in"): None,              # D renames to 'start' (unrelated name)
    # C extension tokens: C++ uses trailing _ or no prefix; D uses __ prefix
    ("TOK", "pragma"): "__pragma",       # second pragma (C ext); D: __pragma
    ("TOK", "cdecl_"): "__cdecl",        # Windows calling conv; D: __cdecl
    ("TOK", "declspec"): "__declspec",   # Windows extension; D: __declspec
    ("TOK", "stdcall"): "__stdcall",     # Windows calling conv; D: __stdcall
    ("TOK", "thread"): "__thread",       # GCC thread-local; D: __thread
    ("TOK", "int128_"): "__int128",      # GCC extension; D: __int128
    ("TOK", "attribute__"): "__attribute__",  # GCC extension; D: __attribute__
    # Sentinel / count values not present in D enums
    ("TOK", "MAX"): None,
    ("EXP", "MAX"): None,
    ("TY", "TMAX"): None,
    # C++ alternative operator tokens: not D keywords, so D drops the trailing _
    ("TOK", "and_"): "and",
    ("TOK", "or_"):  "or",
    ("TOK", "xor_"): "xor",
    ("TOK", "not_"): "not",
    ("EXP", "and_"):     "and",
    ("EXP", "or_"):      "or",
    ("EXP", "xor_"):     "xor",
    ("EXP", "not_"):     "not",
    ("EXP", "_Generic_"):"_Generic",
    # C99 keywords that are not D keywords
    ("TOK", "inline_"):   "inline",
    ("TOK", "register_"): "register",
    ("TOK", "restrict_"): "restrict",
    ("TOK", "signed_"):   "signed",
    ("TOK", "unsigned_"): "unsigned",
    ("TOK", "volatile_"): "volatile",
    # C11 _Xxx keywords: trailing _ stripped (leading _ already present)
    ("TOK", "_Alignas_"):      "_Alignas",
    ("TOK", "_Alignof_"):      "_Alignof",
    ("TOK", "_Atomic_"):       "_Atomic",
    ("TOK", "_Bool_"):         "_Bool",
    ("TOK", "_Complex_"):      "_Complex",
    ("TOK", "_Generic_"):      "_Generic",
    ("TOK", "_Imaginary_"):    "_Imaginary",
    ("TOK", "_Noreturn_"):     "_Noreturn",
    ("TOK", "_Static_assert_"):"_Static_assert",
    ("TOK", "_Thread_local_"): "_Thread_local",
}

# All D imports needed to check all definitions from include/*.h
D_IMPORTS = """\
import dmd.aggregate, dmd.aliasthis, dmd.arraytypes, dmd.ast_node,
       dmd.attrib, dmd.compiler, dmd.cond, dmd.ctfeexpr, dmd.cxxfrontend, dmd.declaration,
       dmd.denum, dmd.dimport, dmd.dmodule, dmd.dscope, dmd.dstruct,
       dmd.dsymbol, dmd.dtemplate, dmd.dversion, dmd.errors,
       dmd.astenums, dmd.ctorflow, dmd.dclass, dmd.dmacro, dmd.dsymbolsem, dmd.errorsink, dmd.expression, dmd.func,
       dmd.globals, dmd.hdrgen, dmd.lexer,
       dmd.id, dmd.identifier, dmd.init, dmd.json, dmd.location,
       dmd.mangle, dmd.mtype, dmd.nspace, dmd.objc, dmd.rootobject,
       dmd.statement, dmd.staticassert, dmd.target, dmd.tokens, dmd.typinf,
       dmd.visitor, dmd.vsoptions,
       dmd.root.array, dmd.root.bitarray, dmd.root.complex,
       dmd.root.ctfloat, dmd.root.filename, dmd.root.longdouble,
       dmd.root.optional, dmd.root.port, dmd.root.rmem,
       dmd.common.charactertables, dmd.common.outbuffer;"""

# Helper emitted once
D_HELPER_CODE = r"""private enum hasMangled(alias T, string method, string mangled) = () {
    static foreach (alias f; __traits(getOverloads, T, method))
        static if (f.mangleof == mangled) return true;
    return false;
}();

private enum genericMsg =
    "Changes to dmd's extern(C++) types/functions must be reflected in compiler/include/*.h\n";

// Eponymous template: dLocString!sym => "file:line" string
template dLocString(alias sym)
{
    private enum _loc = __traits(getLocation, sym);
    enum dLocString = _loc[0] ~ ":" ~ _loc[1].stringof;
}

// Value-to-decimal helper for enum messages
private enum string itoa(int x) = x.stringof;

private void checkField(alias T, string field, int expectedOffset, int expectedSize, string cppLoc)()
{
    static if (__traits(hasMember, T, field))
    {
        alias _fieldSym = __traits(getMember, T, field);
        enum int actualOffset = _fieldSym.offsetof;
        enum int actualSize = _fieldSym.sizeof;
        enum dLoc = dLocString!_fieldSym;
        static assert(actualOffset == expectedOffset,
            "\n\nOffset mismatch for `" ~ T.stringof ~ "." ~ field ~ "`:\n" ~
            "  D field at offset " ~ actualOffset.stringof ~ " at " ~ dLoc ~ "\n" ~
            "  C++ field at offset " ~ expectedOffset.stringof ~ " at " ~ cppLoc ~ "\n" ~
            genericMsg);
        static assert(actualSize == expectedSize,
            "\n\nSize mismatch for `" ~ T.stringof ~ "." ~ field ~ "`:\n" ~
            "  D field has size " ~ actualSize.stringof ~ " at " ~ dLoc ~ "\n" ~
            "  C++ field has size " ~ expectedSize.stringof ~ " at " ~ cppLoc ~ "\n" ~
            genericMsg);
    }
}

private void checkVtable(alias T, string method, size_t expected, string cppLoc)()
{
    alias _methodSym = __traits(getOverloads, T, method)[0];
    enum dLoc = dLocString!_methodSym;
    enum actual = __traits(getVirtualIndex, __traits(getMember, T, method));
    static assert(actual == expected,
        "\n\nVtable index mismatch for `" ~ T.stringof ~ "." ~ method ~ "`:\n" ~
        "  D method at index " ~ actual.stringof ~ " at " ~ dLoc ~ "\n" ~
        "  C++ method at index " ~ expected.stringof ~ " at " ~ cppLoc ~ "\n" ~
        genericMsg);
}

private void checkSize(alias T, size_t expected, string cppLoc)()
{
    enum dLoc = dLocString!T;

    // D classInstanceSize may omit trailing alignment padding; round up to alignof.
    static if (is(T == class))
        enum actual = ((__traits(classInstanceSize, T) + T.alignof - 1) / T.alignof) * T.alignof;
    else
        enum actual = T.sizeof;

    static assert(actual == expected,
        "\n\nSize mismatch for `" ~ T.stringof ~ "`:\n" ~
        "  D type has size " ~ actual.stringof ~ " at " ~ dLoc ~ "\n" ~
        "  C++ type has size " ~ expected.stringof ~ " at " ~ cppLoc ~ "\n" ~
        genericMsg);
}

"""


lib = cx.conf.lib

# clang_getOverriddenCursors / clang_disposeOverriddenCursors are not exposed by
# the Python bindings, so we wire them up manually via ctypes.
lib.clang_getOverriddenCursors.restype = None
lib.clang_getOverriddenCursors.argtypes = [
    cx.Cursor,
    ctypes.POINTER(ctypes.POINTER(cx.Cursor)),
    ctypes.POINTER(ctypes.c_uint),
]
lib.clang_disposeOverriddenCursors.restype = None
lib.clang_disposeOverriddenCursors.argtypes = [ctypes.POINTER(cx.Cursor)]


def get_overridden_manglings(cursor: cx.Cursor) -> list[str]:
    """Return mangled names of methods that *cursor* overrides."""
    ptr = ctypes.POINTER(cx.Cursor)()
    n = ctypes.c_uint(0)
    lib.clang_getOverriddenCursors(cursor, ctypes.byref(ptr), ctypes.byref(n))
    result = []
    for i in range(n.value):
        result.append(ptr[i].mangled_name)
    if n.value:
        lib.clang_disposeOverriddenCursors(ptr)
    return result


CK = cx.CursorKind

def gen(include_dir: Path, out_path: Path) -> None:
    include_str = str(include_dir.resolve())

    resource_dir = subprocess.run(
        ["clang", "-print-resource-dir"], capture_output=True, text=True
    ).stdout.strip()

    # Build umbrella header.
    headers: list[str] = []
    for root, _, files in os.walk(include_dir):
        for f in sorted(files):
            if f.endswith(".h"):
                headers.append(os.path.relpath(os.path.join(root, f), include_dir))

    umbrella_path = out_path.parent / "_umbrella.h"
    umbrella_path.parent.mkdir(parents=True, exist_ok=True)
    umbrella_path.write_text("\n".join(f'#include "{h}"' for h in sorted(headers)))

    idx = cx.Index.create()
    tu = idx.parse(
        str(umbrella_path),
        args=[
            "-x", "c++", "-std=c++17",
            f"-I{include_str}",
            f"-I{resource_dir}/include",
        ],
    )

    errors = [d for d in tu.diagnostics if d.severity >= cx.Diagnostic.Error]
    if errors:
        for e in errors:
            print(f"clang error: {e.spelling}", file=sys.stderr)
        sys.exit(1)

    vtable_cache: dict[int, list[tuple[str, str]]] = {}

    def compute_vtable(cls: cx.Cursor) -> list[tuple[str, str]]:
        key = cls.hash
        if key in vtable_cache:
            return vtable_cache[key]
        # sentinel to break cycles
        vtable_cache[key] = []

        base_vtable: list[tuple[str, str]] = []
        for child in cls.get_children():
            if child.kind == CK.CXX_BASE_SPECIFIER:
                base = child.referenced
                if not base.is_definition():
                    base = base.get_definition()
                if base and base.is_definition():
                    base_vtable = compute_vtable(base)
                break

        vtable = list(base_vtable)
        for child in cls.get_children():
            if child.kind != CK.CXX_METHOD or not child.is_virtual_method():
                continue
            mangled = child.mangled_name
            overridden = get_overridden_manglings(child)
            placed = False
            if overridden:
                for i, (slot_m, _) in enumerate(vtable):
                    if slot_m in overridden:
                        vtable[i] = (mangled, child.spelling)
                        placed = True
                        break
            if not placed:
                vtable.append((mangled, child.spelling))

        vtable_cache[key] = vtable
        return vtable

    def get_vtable_index(method: cx.Cursor, cls: cx.Cursor) -> int:
        for i, (slot_m, _) in enumerate(compute_vtable(cls)):
            if slot_m == method.mangled_name:
                return i
        return -1

    lines: list[str] = [
        "// AUTO-GENERATED - do not edit. Regenerated by: ./build.d cpp-layout-test",
        D_IMPORTS,
        "",
        D_HELPER_CODE,
    ]

    def in_dir(cursor: cx.Cursor) -> bool:
        loc = cursor.location
        if not loc.file or not loc.file.name.startswith(include_str):
            return False
        rel = os.path.relpath(loc.file.name, include_str)
        return rel not in _SKIP_HEADERS

    def emit_enum(cursor: cx.Cursor) -> None:
        # Only check scoped enums (enum class / enum struct): member names match D.
        # C-style enums rename members (e.g. DYNCAST_OBJECT → object).
        if not cursor.is_scoped_enum():
            return
        name = cursor.spelling
        if not name or name.startswith("("):
            return  # anonymous

        members = [
            (c.spelling, c.enum_value,
             f"{os.path.relpath(c.location.file.name, include_str)}:{c.location.line}")
            for c in cursor.get_children()
            if c.kind == CK.ENUM_CONSTANT_DECL
        ]
        if not members:
            return

        lines.append("")
        lines.append(f"// enum class {name}")
        for mname, mval, cloc in members:
            key = (name, mname)
            d_mname = _D_KEYWORD_RENAME.get(key, mname)
            if key in _D_KEYWORD_RENAME and d_mname is None:
                lines.append(f"// skip {name}.{mname} == {mval}")
                continue
            d_expr = f"{name}.{d_mname}"
            msg = (f'"\\n\\nEnum value mismatch for `{d_expr}`:\\n'
                   f'  D value:   " ~ itoa!({d_expr}) ~ " at " ~ dLocString!({d_expr}) ~ "\\n'
                   f'  C++ value: {mval} at {cloc}\\n" ~ genericMsg')
            lines.append(f'static assert({d_expr} == {mval}, {msg});')

    def uses_dstring(cursor: cx.Cursor) -> bool:
        """Return True if a method/function uses DString (extern(D) mangling)."""
        if "DString" in cursor.result_type.spelling:
            return True
        return any("DString" in a.type.spelling for a in cursor.get_arguments())

    def emit_record(cursor: cx.Cursor) -> None:
        name = cursor.spelling
        if not name or name in _SKIP_TYPES:
            return

        is_class = cursor.kind == CK.CLASS_DECL
        size = cursor.type.get_size()
        if size <= 0:
            return

        # Skip empty structs (sizeof==1, no data fields): C++ uses them as namespaces for enums,
        # which D represents as plain enums rather than structs.
        public_fields = [c for c in cursor.get_children()
                         if c.kind == CK.FIELD_DECL and
                         c.access_specifier in (cx.AccessSpecifier.PUBLIC, cx.AccessSpecifier.INVALID)]
        if not is_class and size == 1 and not public_fields:
            return

        lines.append("")
        kind_str = "class" if is_class else "struct"
        lines.append(f"// {kind_str} {name}")

        cloc = cursor.location
        record_cpp_loc = f"{os.path.relpath(cloc.file.name, include_str)}:{cloc.line}"

        # Size + field offsets/sizes + vtable indices: all collected into a unittest block.
        unit_lines: list[str] = []
        for child in cursor.get_children():
            if child.kind != CK.FIELD_DECL:
                continue
            if child.access_specifier not in (cx.AccessSpecifier.PUBLIC,
                                               cx.AccessSpecifier.INVALID):
                continue  # skip explicitly private/protected C++ fields
            fname = child.spelling
            if not fname:
                continue
            offset_bytes = child.get_field_offsetof() // 8
            fsize = child.type.get_size()
            if fsize <= 0:
                continue
            floc = child.location
            field_cpp_loc = f"{os.path.relpath(floc.file.name, include_str)}:{floc.line}"
            unit_lines.append(f'    checkField!({name}, "{fname}", {offset_bytes}, {fsize}, "{field_cpp_loc}");')

        if is_class:
            # Only check class size when C++ exposes data fields; otherwise it's an API-only
            # view and D may add internal fields that legitimately increase the size.
            if public_fields:
                unit_lines.append(f'    checkSize!({name}, {size}, "{record_cpp_loc}");')
        else:
            unit_lines.append(f'    checkSize!({name}, {size}, "{record_cpp_loc}");')

        if not is_class:
            if unit_lines:
                lines.append("unittest {")
                lines.extend(unit_lines)
                lines.append("}")
            return  # structs have no vtable

        # Virtual methods: vtable index (unittest) + mangled name (static assert).
        virt_methods = [
            c for c in cursor.get_children()
            if c.kind == CK.CXX_METHOD and c.is_virtual_method()
        ]
        if not virt_methods:
            if unit_lines:
                lines.append("unittest {")
                lines.extend(unit_lines)
                lines.append("}")
            return

        name_count = Counter(m.spelling for m in virt_methods)

        mangled_lines: list[str] = []
        for method in virt_methods:
            mname = method.spelling
            mangled = method.mangled_name
            overloaded = name_count[mname] > 1
            d_method = uses_dstring(method)
            mloc = method.location
            method_cpp_loc = f"{os.path.relpath(mloc.file.name, include_str)}:{mloc.line}"

            idx = get_vtable_index(method, cursor)
            if not overloaded and idx >= 0:
                unit_lines.append(f'    checkVtable!({name}, "{mname}", {idx}, "{method_cpp_loc}");')

            if d_method:
                mangled_lines.append(f"// skip {name}.{mname}.mangleof: extern(D) method, mangling differs")
            elif overloaded:
                msg = (f'"\\n\\nNo overload of `{name}.{mname}` has C++ mangling:\\n'
                       f'  expected: {mangled} at {method_cpp_loc}\\n" ~ genericMsg')
                mangled_lines.append(f'static assert(hasMangled!({name}, "{mname}", "{mangled}"), {msg});')
            else:
                msg = (f'"\\n\\nMangled name mismatch for `{name}.{mname}`:\\n'
                       f'  D:   " ~ {name}.{mname}.mangleof ~ " at " ~ dLocString!({name}.{mname}) ~ "\\n'
                       f'  C++: {mangled} at {method_cpp_loc}\\n" ~ genericMsg')
                mangled_lines.append(f'static assert({name}.{mname}.mangleof == "{mangled}", {msg});')

        if unit_lines:
            lines.append("unittest {")
            lines.extend(unit_lines)
            lines.append("}")
        lines.extend(mangled_lines)

    # Collected across all namespace dmd {} blocks (may span multiple headers).
    dmd_free_funcs: list[cx.Cursor] = []

    def collect_dmd_namespace(ns_cursor: cx.Cursor) -> None:
        """Collect free functions in namespace dmd {} for later emission."""
        for child in ns_cursor.get_children():
            if child.kind == CK.FUNCTION_DECL and in_dir(child):
                dmd_free_funcs.append(child)

    seen: set[int] = set()

    def walk(cursor: cx.Cursor) -> None:
        for child in cursor.get_children():
            h = child.hash
            if h in seen:
                continue
            seen.add(h)

            if not in_dir(child):
                # Recurse into namespaces even from other files (dmd ns spans headers).
                if child.kind == CK.NAMESPACE:
                    walk(child)
                continue

            if child.kind == CK.ENUM_DECL and child.is_definition():
                emit_enum(child)
            elif child.kind in (CK.CLASS_DECL, CK.STRUCT_DECL) and child.is_definition():
                emit_record(child)
            elif child.kind == CK.NAMESPACE:
                if child.spelling == "dmd":
                    collect_dmd_namespace(child)
                walk(child)

    walk(tu.cursor)

    # Emit mangled name checks for free functions in namespace dmd.
    # All such functions are re-exported via dmd.cxxfrontend as extern(C++, "dmd").
    if dmd_free_funcs:
        name_count = Counter(f.spelling for f in dmd_free_funcs)
        lines.append("")
        lines.append("// free functions in namespace dmd (via dmd.cxxfrontend)")
        for func in dmd_free_funcs:
            fname = func.spelling
            mangled = func.mangled_name
            floc = func.location
            func_cpp_loc = f"{os.path.relpath(floc.file.name, include_str)}:{floc.line}"
            if fname in _SKIP_FREE_FUNCS:
                lines.append(f"// skip dmd::{fname}: not in dmd.cxxfrontend on this platform")
            elif uses_dstring(func):
                lines.append(f"// skip dmd::{fname}: uses DString")
            elif name_count[fname] > 1:
                msg = (f'"\\n\\nNo overload of `dmd.cxxfrontend.{fname}` has C++ mangling:\\n'
                       f'  expected: {mangled} at {func_cpp_loc}\\n" ~ genericMsg')
                lines.append(f'static assert(hasMangled!(dmd.cxxfrontend, "{fname}", "{mangled}"), {msg});')
            else:
                msg = (f'"\\n\\nMangled name mismatch for `dmd.cxxfrontend.{fname}`:\\n'
                       f'  D:   " ~ dmd.cxxfrontend.{fname}.mangleof ~ " at " ~ dLocString!(dmd.cxxfrontend.{fname}) ~ "\\n'
                       f'  C++: {mangled} at {func_cpp_loc}\\n" ~ genericMsg')
                lines.append(f'static assert(dmd.cxxfrontend.{fname}.mangleof == "{mangled}", {msg});')

    out_path.write_text("\n".join(lines) + "\n")
    print(f"Generated {out_path} ({len(lines)} lines)")


if __name__ == "__main__":
    if len(sys.argv) != 3:
        print(f"Usage: {sys.argv[0]} <include_dir> <output_file>", file=sys.stderr)
        sys.exit(1)

    gen(Path(sys.argv[1]), Path(sys.argv[2]))
