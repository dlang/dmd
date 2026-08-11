/**
 * A library in the GNU/SVR4 ar archive format for WebAssembly.
 *
 * The ar format is shared with the ELF library (same header structure and
 * symbol-table layout); see dmd.lib.ArHeader and arFillHeader() in package.d.
 *
 * Copyright:   Copyright (C) 1999-2026 by The D Language Foundation, All Rights Reserved
 * License:     $(LINK2 https://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/compiler/src/dmd/lib/wasm.d, _libwasm.d)
 */

module dmd.lib.wasm;

import core.stdc.stdlib : strtoul;
import core.stdc.string : memcmp;
import core.stdc.time : time;

import dmd.errors : fatal;
import dmd.lib;
import dmd.lib.scanwasm;
import dmd.location;
import dmd.root.array;
import dmd.root.filename;
import dmd.root.rmem;
import dmd.root.string;
import dmd.root.stringtable;
import dmd.common.outbuffer;
import dmd.utils : readFile;

package(dmd.lib) extern (C++) Library LibWasm_factory()
{
    return new LibWasm();
}

private:
nothrow:

alias WasmObjSymbol = ArObjSymbol;
alias WasmObjModule = ArObjModule;

alias WasmObjModules = Array!(WasmObjModule*);
alias WasmObjSymbols = Array!(WasmObjSymbol*);

final class LibWasm : Library
{
    WasmObjModules objmodules;
    WasmObjSymbols objsymbols;
    StringTable!(WasmObjSymbol*) tab;

    extern (D) this()
    {
        tab._init(14_000);
    }

    /***************************************
     * Add object module or library to the library.
     * If buffer is empty, load from module_name.
     */
    override void addObject(const(char)[] module_name, const(ubyte)[] buffer)
    {
        if (!buffer.length)
        {
            assert(module_name.length);
            OutBuffer b;
            if (readFile(Loc.initial, module_name, b))
                fatal();
            buffer = cast(ubyte[])b.extractSlice();
        }

        if (buffer.length >= 8 && memcmp(buffer.ptr, "!<arch>\n".ptr, 8) == 0)
        {
            extractArchive(buffer);
            return;
        }

        if (buffer.length < 4 || buffer[0] != 0 || buffer[1] != 0x61 ||
            buffer[2] != 0x73 || buffer[3] != 0x6d)
        {
            eSink.error(Loc.initial, "not a WASM object: %.*s",
                cast(int)module_name.length, module_name.ptr);
            return;
        }

        auto om = new WasmObjModule();
        om.name = toCString(FileName.name(module_name));
        om.base = cast(ubyte*)buffer.ptr;
        om.length = cast(uint)buffer.length;
        om.scan = 1;

        time(&om.file_time);
        om.user_id = 0;
        om.group_id = 0;
        om.file_mode = (1 << 15) | (6 << 6) | (4 << 3) | (4 << 0); // 0100644
        objmodules.push(om);
    }

    /***************************************
     * Write library as a GNU/SVR4 ar archive with a symbol table.
     * Compatible with wasm-ld and llvm-ar.
     */
    protected override void writeLibToBuffer(ref OutBuffer libbuf)
    {
        scanAndWriteArLib!scanWasmObjModule(libbuf, objmodules, objsymbols, tab, eSink, filename);
    }

private:

    /***************************************
     * Add every object member of a GNU/SVR4 `ar` archive to this library.
     *
     * Members are added individually so that a library built from other
     * libraries (e.g. `-lib` with an archive input) contains their objects
     * rather than a nested archive. The symbol table members (`/`, `__.SYMDEF`)
     * are skipped, the long name table (`//`) is used to resolve `/offset`
     * member names.
     *
     * Params:
     *      buf = archive file contents, starting with the `!<arch>\n` magic
     */
    void extractArchive(const(ubyte)[] buf)
    {
        uint offset = 8;
        const(char)[] nametab;

        while (offset + ArHeader.sizeof <= buf.length)
        {
            auto h = cast(const(ArHeader)*)(buf.ptr + offset);
            offset += ArHeader.sizeof;

            char* endptr;
            uint size = cast(uint)strtoul(cast(char*)h.file_size.ptr, &endptr, 10);
            if (offset + size > buf.length)
                break;

            const(char)[] memberName = h.object_name[];

            if (memberName.length >= 2 && memberName[0] == '/' && memberName[1] == '/')
            {
                nametab = cast(const(char)[])(buf.ptr + offset)[0 .. size];
            }
            else if (memberName[0] != '/')
            {
                const(char)[] name = memberName;
                size_t end = name.length;
                while (end > 0 && (name[end-1] == ' ' || name[end-1] == '/'))
                    end--;
                if (end)
                    addObject(name[0 .. end], cast(const(ubyte)[])(buf.ptr + offset)[0 .. size]);
            }
            else if (memberName[0] == '/' && memberName[1] != '/' && memberName[1] != ' ')
            {
                uint noff = cast(uint)strtoul(cast(char*)memberName.ptr + 1, null, 10);
                if (noff < nametab.length)
                {
                    const(char)[] rest = nametab[noff .. $];
                    size_t end = 0;
                    while (end < rest.length && rest[end] != '/' && rest[end] != '\n')
                        end++;
                    if (end)
                        addObject(rest[0 .. end], cast(const(ubyte)[])(buf.ptr + offset)[0 .. size]);
                }
            }

            offset += size;
            if (offset & 1)
                offset++;
        }
    }
}
