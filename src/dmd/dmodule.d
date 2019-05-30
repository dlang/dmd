/**
 * Compiler implementation of the
 * $(LINK2 http://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (C) 1999-2019 by The D Language Foundation, All Rights Reserved
 * Authors:     $(LINK2 http://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/src/dmd/dmodule.d, _dmodule.d)
 * Documentation:  https://dlang.org/phobos/dmd_dmodule.html
 * Coverage:    https://codecov.io/gh/dlang/dmd/src/master/src/dmd/dmodule.d
 */

module dmd.dmodule;

import core.stdc.stdio;
import core.stdc.stdlib;
import core.stdc.string;
import dmd.aggregate;
import dmd.arraytypes;
import dmd.astcodegen;
import dmd.compiler;
import dmd.gluelayer;
import dmd.dimport;
import dmd.dmacro;
import dmd.doc;
import dmd.dscope;
import dmd.dsymbol;
import dmd.dsymbolsem;
import dmd.errors;
import dmd.expression;
import dmd.expressionsem;
import dmd.globals;
import dmd.id;
import dmd.identifier;
import dmd.parse;
import dmd.root.file;
import dmd.root.filename;
import dmd.root.outbuffer;
import dmd.root.port;
import dmd.root.rmem;
import dmd.semantic2;
import dmd.semantic3;
import dmd.utils;
import dmd.visitor;

version(Windows) {
    extern (C) char* getcwd(char* buffer, size_t maxlen);
} else {
    import core.sys.posix.unistd : getcwd;
}

/* ===========================  ===================== */
/********************************************
 * Look for the source file if it's different from filename.
 * Look for .di, .d, directory, and along global.path.
 * Does not open the file.
 * Input:
 *      filename        as supplied by the user
 *      global.path
 * Returns:
 *      NULL if it's not different from filename.
 */
private const(char)[] lookForSourceFile(const(char)[] filename)
{
    /* Search along global.path for .di file, then .d file.
     */
    const sdi = FileName.forceExt(filename, global.hdr_ext.toDString());
    if (FileName.exists(sdi) == 1)
        return sdi;
    scope(exit) FileName.free(sdi.ptr);
    const sd = FileName.forceExt(filename, global.mars_ext.toDString());
    if (FileName.exists(sd) == 1)
        return sd;
    scope(exit) FileName.free(sd.ptr);
    if (FileName.exists(filename) == 2)
    {
        /* The filename exists and it's a directory.
         * Therefore, the result should be: filename/package.d
         * iff filename/package.d is a file
         */
        const ni = FileName.combine(filename, "package.di");
        if (FileName.exists(ni) == 1)
            return ni;
        FileName.free(ni.ptr);
        const n = FileName.combine(filename, "package.d");
        if (FileName.exists(n) == 1)
            return n;
        FileName.free(n.ptr);
    }
    if (FileName.absolute(filename))
        return null;
    if (!global.path)
        return null;
    for (size_t i = 0; i < global.path.dim; i++)
    {
        const p = (*global.path)[i].toDString();
        const(char)[] n = FileName.combine(p, sdi);
        if (FileName.exists(n) == 1) {
            return n;
        }
        FileName.free(n.ptr);
        n = FileName.combine(p, sd);
        if (FileName.exists(n) == 1) {
            return n;
        }
        FileName.free(n.ptr);
        const b = FileName.removeExt(filename);
        n = FileName.combine(p, b);
        FileName.free(b.ptr);
        if (FileName.exists(n) == 2)
        {
            const n2i = FileName.combine(n, "package.di");
            if (FileName.exists(n2i) == 1)
                return n2i;
            FileName.free(n2i.ptr);
            const n2 = FileName.combine(n, "package.d");
            if (FileName.exists(n2) == 1) {
                return n2;
            }
            FileName.free(n2.ptr);
        }
        FileName.free(n.ptr);
    }
    return null;
}

// function used to call semantic3 on a module's dependencies
void semantic3OnDependencies(Module m)
{
    if (!m)
        return;

    if (m.semanticRun > PASS.semantic3)
        return;

    m.semantic3(null);

    foreach (i; 1 .. m.aimports.dim)
        semantic3OnDependencies(m.aimports[i]);
}

enum PKG : int
{
    unknown,     // not yet determined whether it's a package.d or not
    module_,      // already determined that's an actual package.d
    package_,     // already determined that's an actual package
}

/***********************************************************
 */
extern (C++) class Package : ScopeDsymbol
{
    PKG isPkgMod = PKG.unknown;
    uint tag;        // auto incremented tag, used to mask package tree in scopes
    Module mod;     // !=null if isPkgMod == PKG.module_

    final extern (D) this(const ref Loc loc, Identifier ident)
    {
        super(loc, ident);
        __gshared uint packageTag;
        this.tag = packageTag++;
    }

    override const(char)* kind() const
    {
        return "package";
    }

    /****************************************************
     * Input:
     *      packages[]      the pkg1.pkg2 of pkg1.pkg2.mod
     * Returns:
     *      the symbol table that mod should be inserted into
     * Output:
     *      *pparent        the rightmost package, i.e. pkg2, or NULL if no packages
     *      *ppkg           the leftmost package, i.e. pkg1, or NULL if no packages
     */
    extern (D) static DsymbolTable resolve(Identifiers* packages, Dsymbol* pparent, Package* ppkg)
    {
        DsymbolTable dst = Module.modules;
        Dsymbol parent = null;
        //printf("Package::resolve()\n");
        if (ppkg)
            *ppkg = null;
        if (packages)
        {
            for (size_t i = 0; i < packages.dim; i++)
            {
                Identifier pid = (*packages)[i];
                Package pkg;
                Dsymbol p = dst.lookup(pid);
                if (!p)
                {
                    pkg = new Package(Loc.initial, pid);
                    dst.insert(pkg);
                    pkg.parent = parent;
                    pkg.symtab = new DsymbolTable();
                }
                else
                {
                    pkg = p.isPackage();
                    assert(pkg);
                    // It might already be a module, not a package, but that needs
                    // to be checked at a higher level, where a nice error message
                    // can be generated.
                    // dot net needs modules and packages with same name
                    // But we still need a symbol table for it
                    if (!pkg.symtab)
                        pkg.symtab = new DsymbolTable();
                }
                parent = pkg;
                dst = pkg.symtab;
                if (ppkg && !*ppkg)
                    *ppkg = pkg;
                if (pkg.isModule())
                {
                    // Return the module so that a nice error message can be generated
                    if (ppkg)
                        *ppkg = cast(Package)p;
                    break;
                }
            }
        }
        if (pparent)
            *pparent = parent;
        return dst;
    }

    override final inout(Package) isPackage() inout
    {
        return this;
    }

    /**
     * Checks if pkg is a sub-package of this
     *
     * For example, if this qualifies to 'a1.a2' and pkg - to 'a1.a2.a3',
     * this function returns 'true'. If it is other way around or qualified
     * package paths conflict function returns 'false'.
     *
     * Params:
     *  pkg = possible subpackage
     *
     * Returns:
     *  see description
     */
    final bool isAncestorPackageOf(const Package pkg) const
    {
        if (this == pkg)
            return true;
        if (!pkg || !pkg.parent)
            return false;
        return isAncestorPackageOf(pkg.parent.isPackage());
    }

    override Dsymbol search(const ref Loc loc, Identifier ident, int flags = SearchLocalsOnly)
    {
        //printf("%s Package.search('%s', flags = x%x)\n", toChars(), ident.toChars(), flags);
        flags &= ~SearchLocalsOnly;  // searching an import is always transitive
        if (!isModule() && mod)
        {
            // Prefer full package name.
            Dsymbol s = symtab ? symtab.lookup(ident) : null;
            if (s)
                return s;
            //printf("[%s] through pkdmod: %s\n", loc.toChars(), toChars());
            return mod.search(loc, ident, flags);
        }
        return ScopeDsymbol.search(loc, ident, flags);
    }

    override void accept(Visitor v)
    {
        v.visit(this);
    }

    final Module isPackageMod()
    {
        if (isPkgMod == PKG.module_)
        {
            return mod;
        }
        return null;
    }
}

/***********************************************************
 */
extern (C++) final class Module : Package
{
    extern (C++) __gshared Module rootModule;
    extern (C++) __gshared DsymbolTable modules; // symbol table of all modules
    extern (C++) __gshared Modules amodules;     // array of all modules
    extern (C++) __gshared Dsymbols deferred;    // deferred Dsymbol's needing semantic() run on them
    extern (C++) __gshared Dsymbols deferred2;   // deferred Dsymbol's needing semantic2() run on them
    extern (C++) __gshared Dsymbols deferred3;   // deferred Dsymbol's needing semantic3() run on them
    extern (C++) __gshared uint dprogress;       // progress resolving the deferred list

    static void _init()
    {
        modules = new DsymbolTable();
    }

    /**
     * Deinitializes the global state of the compiler.
     *
     * This can be used to restore the state set by `_init` to its original
     * state.
     */
    static void deinitialize()
    {
        modules = modules.init;
    }

    extern (C++) __gshared AggregateDeclaration moduleinfo;

    const(char)* arg;           // original argument name
    ModuleDeclaration* md;      // if !=null, the contents of the ModuleDeclaration declaration
    File* srcfile;              // input source file
    File* objfile;              // output .obj file
    File* hdrfile;              // 'header' file
    File* docfile;              // output documentation file
    uint errors;                // if any errors in file
    uint numlines;              // number of lines in source file
    bool isHdrFile;             // if it is a header (.di) file
    bool isDocFile;             // if it is a documentation input file, not D source
    bool isPackageFile;         // if it is a package.d
    Strings contentImportedFiles; // array of files whose content was imported
    int needmoduleinfo;
    int selfimports;            // 0: don't know, 1: does not, 2: does

    /*************************************
     * Return true if module imports itself.
     */
    bool selfImports()
    {
        //printf("Module::selfImports() %s\n", toChars());
        if (selfimports == 0)
        {
            for (size_t i = 0; i < amodules.dim; i++)
                amodules[i].insearch = 0;
            selfimports = imports(this) + 1;
            for (size_t i = 0; i < amodules.dim; i++)
                amodules[i].insearch = 0;
        }
        return selfimports == 2;
    }

    int rootimports;            // 0: don't know, 1: does not, 2: does

    /*************************************
     * Return true if module imports root module.
     */
    bool rootImports()
    {
        //printf("Module::rootImports() %s\n", toChars());
        if (rootimports == 0)
        {
            for (size_t i = 0; i < amodules.dim; i++)
                amodules[i].insearch = 0;
            rootimports = 1;
            for (size_t i = 0; i < amodules.dim; ++i)
            {
                Module m = amodules[i];
                if (m.isRoot() && imports(m))
                {
                    rootimports = 2;
                    break;
                }
            }
            for (size_t i = 0; i < amodules.dim; i++)
                amodules[i].insearch = 0;
        }
        return rootimports == 2;
    }

    int insearch;
    Identifier searchCacheIdent;
    Dsymbol searchCacheSymbol;  // cached value of search
    int searchCacheFlags;       // cached flags

    /**
     * A root module is one that will be compiled all the way to
     * object code.  This field holds the root module that caused
     * this module to be loaded.  If this module is a root module,
     * then it will be set to `this`.  This is used to determine
     * ownership of template instantiation.
     */
    Module importedFrom;

    Dsymbols* decldefs;         // top level declarations for this Module

    Modules aimports;           // all imported modules

    uint debuglevel;            // debug level
    Identifiers* debugids;      // debug identifiers
    Identifiers* debugidsNot;   // forward referenced debug identifiers

    uint versionlevel;          // version level
    Identifiers* versionids;    // version identifiers
    Identifiers* versionidsNot; // forward referenced version identifiers

    Macro* macrotable;          // document comment macros
    Escape* escapetable;        // document comment escapes

    size_t nameoffset;          // offset of module name from start of ModuleInfo
    size_t namelen;             // length of module name in characters

    extern (D) this(const ref Loc loc, const(char)* filename, Identifier ident, int doDocComment, int doHdrGen)
    {
        super(loc, ident);
        const(char)* srcfilename;
        //printf("Module::Module(filename = '%s', ident = '%s')\n", filename, ident.toChars());
        this.arg = filename;
        srcfilename = FileName.defaultExt(filename, global.mars_ext);
        if (global.run_noext && global.params.run && !FileName.ext(filename) && FileName.exists(srcfilename) == 0 && FileName.exists(filename) == 1)
        {
            FileName.free(srcfilename);
            srcfilename = FileName.removeExt(filename); // just does a mem.strdup(filename)
        }
        else if (!FileName.equalsExt(srcfilename, global.mars_ext) && !FileName.equalsExt(srcfilename, global.hdr_ext) && !FileName.equalsExt(srcfilename, "dd"))
        {
            error("source file name '%s' must have .%s extension", srcfilename, global.mars_ext);
            fatal();
        }
        srcfile = new File(srcfilename);
        objfile = setOutfile(global.params.objname, global.params.objdir, filename, global.obj_ext);
        if (doDocComment)
            setDocfile();
        if (doHdrGen)
            hdrfile = setOutfile(global.params.hdrname, global.params.hdrdir, arg, global.hdr_ext);
        //objfile = new File(objfilename);
        escapetable = new Escape();
    }

    extern (D) this(const(char)* filename, Identifier ident, int doDocComment, int doHdrGen)
    {
        this(Loc.initial, filename, ident, doDocComment, doHdrGen);
    }

    static Module create(const(char)* filename, Identifier ident, int doDocComment, int doHdrGen)
    {
        return new Module(Loc.initial, filename, ident, doDocComment, doHdrGen);
    }

    static Module load(Loc loc, Identifiers* packages, Identifier ident)
    {
        //printf("Module::load(ident = '%s')\n", ident.toChars());
        // Build module filename by turning:
        //  foo.bar.baz
        // into:
        //  foo\bar\baz
        const(char)[] filename = ident.toString();
        if (packages && packages.dim)
        {
            OutBuffer buf;
            OutBuffer dotmods;
            auto ms = global.params.modFileAliasStrings;
            const msdim = ms ? ms.dim : 0;

            void checkModFileAlias(const(char)[] p)
            {
                /* Check and replace the contents of buf[] with
                 * an alias string from global.params.modFileAliasStrings[]
                 */
                dotmods.writestring(p);
            Lmain:
                for (size_t j = msdim; j--;)
                {
                    const m = (*ms)[j];
                    const q = strchr(m, '=');
                    assert(q);
                    if (dotmods.offset == q - m && memcmp(dotmods.peekString(), m, q - m) == 0)
                    {
                        buf.reset();
                        auto qlen = strlen(q + 1);
                        if (qlen && (q[qlen] == '/' || q[qlen] == '\\'))
                            --qlen;             // remove trailing separator
                        buf.writestring(q[1 .. qlen + 1]);
                        break Lmain;            // last matching entry in ms[] wins
                    }
                }
                dotmods.writeByte('.');
            }

            foreach (pid; *packages)
            {
                const p = pid.toString();
                buf.writestring(p);
                if (msdim)
                    checkModFileAlias(p);
                version (Windows)
                {
                    buf.writeByte('\\');
                }
                else
                {
                    buf.writeByte('/');
                }
            }
            buf.writestring(filename);
            if (msdim)
                checkModFileAlias(filename);
            buf.writeByte(0);
            filename = buf.extractData().toDString();
        }
        auto m = new Module(loc, filename.ptr, ident, 0, 0);

        /* Look for the source file
         */
        if (const result = lookForSourceFile(filename))
        {
            m.srcfile = new File(result);
            FileName.free(result.ptr);
        }

        if (!m.read(loc))
            return null;
        if (global.params.verbose)
        {
            OutBuffer buf;
            if (packages)
            {
                foreach (pid; *packages)
                {
                    buf.writestring(pid.toString());
                    buf.writeByte('.');
                }
            }
            buf.printf("%s\t(%s)", ident.toChars(), m.srcfile.toChars());
            message("import    %s", buf.peekString());
        }
        m = m.parse();

        // Call onImport here because if the module is going to be compiled then we
        // need to determine it early because it affects semantic analysis. This is
        // being done after parsing the module so the full module name can be taken
        // from whatever was declared in the file.
        if (!m.isRoot() && Compiler.onImport(m))
        {
            m.importedFrom = m;
            assert(m.isRoot());
        }

        Compiler.loadModule(m);
        return m;
    }

    override const(char)* kind() const
    {
        return "module";
    }

    /*********************************************
     * Combines things into output file name for .html and .di files.
     * Input:
     *      name    Command line name given for the file, NULL if none
     *      dir     Command line directory given for the file, NULL if none
     *      arg     Name of the source file
     *      ext     File name extension to use if 'name' is NULL
     *      global.params.preservePaths     get output path from arg
     *      srcfile Input file - output file name must not match input file
     */
    File* setOutfile(const(char)* name, const(char)* dir, const(char)* arg, const(char)* ext)
    {
        return setOutfile(name.toDString(), dir.toDString(), arg.toDString(), ext.toDString());
    }

    /// Ditto
    extern(D) File* setOutfile(const(char)[] name, const(char)[] dir, const(char)[] arg, const(char)[] ext)
    {
        const(char)[] docfilename;
        if (name)
        {
            docfilename = name;
        }
        else
        {
            const(char)[] argdoc;
            OutBuffer buf;
            if (arg == "__stdin.d")
            {
                version (Posix)
                    import core.sys.posix.unistd : getpid;
                else version (Windows)
                    import core.sys.windows.winbase : getpid = GetCurrentProcessId;
                buf.printf("__stdin_%d.d", getpid());
                arg = buf.peekSlice();
            }
            if (global.params.preservePaths)
                argdoc = arg;
            else
                argdoc = FileName.name(arg);
            // If argdoc doesn't have an absolute path, make it relative to dir
            if (!FileName.absolute(argdoc))
            {
                //FileName::ensurePathExists(dir);
                argdoc = FileName.combine(dir, argdoc);
            }
            docfilename = FileName.forceExt(argdoc, ext);
        }
        if (FileName.equals(docfilename, srcfile.name.toString()))
        {
            error("source file and output file have same name '%s'", srcfile.name.toChars());
            fatal();
        }
        return new File(docfilename);
    }

    void setDocfile()
    {
        docfile = setOutfile(global.params.docname, global.params.docdir, arg, global.doc_ext);
    }

    // read file, returns 'true' if succeed, 'false' otherwise.
    bool read(Loc loc)
    {
        //printf("Module::read('%s') file '%s'\n", toChars(), srcfile.toChars());
        if (!srcfile.read())
            return true;

        if (FileName.equals(srcfile.toString(), "object.d"))
        {
            .error(loc, "cannot find source code for runtime library file 'object.d'");
            errorSupplemental(loc, "dmd might not be correctly installed. Run 'dmd -man' for installation instructions.");
            const dmdConfFile = global.inifilename ? FileName.canonicalName(global.inifilename) : null;
            errorSupplemental(loc, "config file: %s", dmdConfFile ? dmdConfFile : "not found".ptr);
        }
        else
        {
            // if module is not named 'package' but we're trying to read 'package.d', we're looking for a package module
            bool isPackageMod = (strcmp(toChars(), "package") != 0) && (strcmp(srcfile.name.name(), "package.d") == 0 || (strcmp(srcfile.name.name(), "package.di") == 0));
            if (isPackageMod)
                .error(loc, "importing package '%s' requires a 'package.d' file which cannot be found in '%s'", toChars(), srcfile.toChars());
            else
                error(loc, "is in file '%s' which cannot be read", srcfile.toChars());
        }
        if (!global.gag)
        {
            /* Print path
             */
            if (global.path)
            {
                foreach (i, p; *global.path)
                    fprintf(stderr, "import path[%llu] = %s\n", cast(ulong)i, p);
            }
            else
                fprintf(stderr, "Specify path to file '%s' with -I switch\n", srcfile.toChars());
            fatal();
        }
        return false;
    }

    // syntactic parse
    Module parse()
    {
        //printf("Module::parse(srcfile='%s') this=%p\n", srcfile.name.toChars(), this);
        const(char)* srcname = srcfile.name.toChars();
        //printf("Module::parse(srcname = '%s')\n", srcname);
        isPackageFile = (strcmp(srcfile.name.name(), "package.d") == 0 ||
                         strcmp(srcfile.name.name(), "package.di") == 0);
        char* buf = cast(char*)srcfile.buffer;
        size_t buflen = srcfile.len;
        if (buflen >= 2)
        {
            /* Convert all non-UTF-8 formats to UTF-8.
             * BOM : http://www.unicode.org/faq/utf_bom.html
             * 00 00 FE FF  UTF-32BE, big-endian
             * FF FE 00 00  UTF-32LE, little-endian
             * FE FF        UTF-16BE, big-endian
             * FF FE        UTF-16LE, little-endian
             * EF BB BF     UTF-8
             */
            uint le;
            uint bom = 1; // assume there's a BOM
            if (buf[0] == 0xFF && buf[1] == 0xFE)
            {
                if (buflen >= 4 && buf[2] == 0 && buf[3] == 0)
                {
                    // UTF-32LE
                    le = 1;
                Lutf32:
                    OutBuffer dbuf;
                    uint* pu = cast(uint*)buf;
                    uint* pumax = &pu[buflen / 4];
                    if (buflen & 3)
                    {
                        error("odd length of UTF-32 char source %u", buflen);
                        fatal();
                    }
                    dbuf.reserve(buflen / 4);
                    for (pu += bom; pu < pumax; pu++)
                    {
                        uint u;
                        u = le ? Port.readlongLE(pu) : Port.readlongBE(pu);
                        if (u & ~0x7F)
                        {
                            if (u > 0x10FFFF)
                            {
                                error("UTF-32 value %08x greater than 0x10FFFF", u);
                                fatal();
                            }
                            dbuf.writeUTF8(u);
                        }
                        else
                            dbuf.writeByte(u);
                    }
                    dbuf.writeByte(0); // add 0 as sentinel for scanner
                    buflen = dbuf.offset - 1; // don't include sentinel in count
                    buf = dbuf.extractData();
                }
                else
                {
                    // UTF-16LE (X86)
                    // Convert it to UTF-8
                    le = 1;
                Lutf16:
                    OutBuffer dbuf;
                    ushort* pu = cast(ushort*)buf;
                    ushort* pumax = &pu[buflen / 2];
                    if (buflen & 1)
                    {
                        error("odd length of UTF-16 char source %u", buflen);
                        fatal();
                    }
                    dbuf.reserve(buflen / 2);
                    for (pu += bom; pu < pumax; pu++)
                    {
                        uint u;
                        u = le ? Port.readwordLE(pu) : Port.readwordBE(pu);
                        if (u & ~0x7F)
                        {
                            if (u >= 0xD800 && u <= 0xDBFF)
                            {
                                uint u2;
                                if (++pu > pumax)
                                {
                                    error("surrogate UTF-16 high value %04x at end of file", u);
                                    fatal();
                                }
                                u2 = le ? Port.readwordLE(pu) : Port.readwordBE(pu);
                                if (u2 < 0xDC00 || u2 > 0xDFFF)
                                {
                                    error("surrogate UTF-16 low value %04x out of range", u2);
                                    fatal();
                                }
                                u = (u - 0xD7C0) << 10;
                                u |= (u2 - 0xDC00);
                            }
                            else if (u >= 0xDC00 && u <= 0xDFFF)
                            {
                                error("unpaired surrogate UTF-16 value %04x", u);
                                fatal();
                            }
                            else if (u == 0xFFFE || u == 0xFFFF)
                            {
                                error("illegal UTF-16 value %04x", u);
                                fatal();
                            }
                            dbuf.writeUTF8(u);
                        }
                        else
                            dbuf.writeByte(u);
                    }
                    dbuf.writeByte(0); // add 0 as sentinel for scanner
                    buflen = dbuf.offset - 1; // don't include sentinel in count
                    buf = dbuf.extractData();
                }
            }
            else if (buf[0] == 0xFE && buf[1] == 0xFF)
            {
                // UTF-16BE
                le = 0;
                goto Lutf16;
            }
            else if (buflen >= 4 && buf[0] == 0 && buf[1] == 0 && buf[2] == 0xFE && buf[3] == 0xFF)
            {
                // UTF-32BE
                le = 0;
                goto Lutf32;
            }
            else if (buflen >= 3 && buf[0] == 0xEF && buf[1] == 0xBB && buf[2] == 0xBF)
            {
                // UTF-8
                buf += 3;
                buflen -= 3;
            }
            else
            {
                /* There is no BOM. Make use of Arcane Jill's insight that
                 * the first char of D source must be ASCII to
                 * figure out the encoding.
                 */
                bom = 0;
                if (buflen >= 4)
                {
                    if (buf[1] == 0 && buf[2] == 0 && buf[3] == 0)
                    {
                        // UTF-32LE
                        le = 1;
                        goto Lutf32;
                    }
                    else if (buf[0] == 0 && buf[1] == 0 && buf[2] == 0)
                    {
                        // UTF-32BE
                        le = 0;
                        goto Lutf32;
                    }
                }
                if (buflen >= 2)
                {
                    if (buf[1] == 0)
                    {
                        // UTF-16LE
                        le = 1;
                        goto Lutf16;
                    }
                    else if (buf[0] == 0)
                    {
                        // UTF-16BE
                        le = 0;
                        goto Lutf16;
                    }
                }
                // It's UTF-8
                if (buf[0] >= 0x80)
                {
                    error("source file must start with BOM or ASCII character, not \\x%02X", buf[0]);
                    fatal();
                }
            }
        }
        /* If it starts with the string "Ddoc", then it's a documentation
         * source file.
         */
        if (buflen >= 4 && memcmp(buf, cast(char*)"Ddoc", 4) == 0)
        {
            comment = buf + 4;
            isDocFile = true;
            if (!docfile)
                setDocfile();
            return this;
        }
        /* If it has the extension ".dd", it is also a documentation
         * source file. Documentation source files may begin with "Ddoc"
         * but do not have to if they have the .dd extension.
         * https://issues.dlang.org/show_bug.cgi?id=15465
         */
        if (FileName.equalsExt(arg, "dd"))
        {
            comment = buf; // the optional Ddoc, if present, is handled above.
            isDocFile = true;
            if (!docfile)
                setDocfile();
            return this;
        }
        /* If it has the extension ".di", it is a "header" file.
         */
        if (FileName.equalsExt(arg, "di"))
        {
            isHdrFile = true;
        }
        {
            scope diagnosticReporter = new StderrDiagnosticReporter(global.params.useDeprecated);
            scope p = new Parser!ASTCodegen(this, buf[0 .. buflen], docfile !is null, diagnosticReporter);
            p.nextToken();
            members = p.parseModule();
            md = p.md;
            numlines = p.scanloc.linnum;
            if (p.errors)
                ++global.errors;
        }
        if (srcfile._ref == 0)
            mem.xfree(srcfile.buffer);
        srcfile.buffer = null;
        srcfile.len = 0;
        /* The symbol table into which the module is to be inserted.
         */
        DsymbolTable dst;
        if (md)
        {
            /* A ModuleDeclaration, md, was provided.
             * The ModuleDeclaration sets the packages this module appears in, and
             * the name of this module.
             */
            this.ident = md.id;
            Package ppack = null;
            dst = Package.resolve(md.packages, &this.parent, &ppack);
            assert(dst);
            Module m = ppack ? ppack.isModule() : null;
            if (m && (strcmp(m.srcfile.name.name(), "package.d") != 0 &&
                      strcmp(m.srcfile.name.name(), "package.di") != 0))
            {
                .error(md.loc, "package name '%s' conflicts with usage as a module name in file %s", ppack.toPrettyChars(), m.srcfile.toChars());
            }
        }
        else
        {
            /* The name of the module is set to the source file name.
             * There are no packages.
             */
            dst = modules; // and so this module goes into global module symbol table
            /* Check to see if module name is a valid identifier
             */
            if (!Identifier.isValidIdentifier(this.ident.toChars()))
                error("has non-identifier characters in filename, use module declaration instead");
        }
        // Insert module into the symbol table
        Dsymbol s = this;
        if (isPackageFile)
        {
            /* If the source tree is as follows:
             *     pkg/
             *     +- package.d
             *     +- common.d
             * the 'pkg' will be incorporated to the internal package tree in two ways:
             *     import pkg;
             * and:
             *     import pkg.common;
             *
             * If both are used in one compilation, 'pkg' as a module (== pkg/package.d)
             * and a package name 'pkg' will conflict each other.
             *
             * To avoid the conflict:
             * 1. If preceding package name insertion had occurred by Package::resolve,
             *    later package.d loading will change Package::isPkgMod to PKG.module_ and set Package::mod.
             * 2. Otherwise, 'package.d' wrapped by 'Package' is inserted to the internal tree in here.
             */
            auto p = new Package(Loc.initial, ident);
            p.parent = this.parent;
            p.isPkgMod = PKG.module_;
            p.mod = this;
            p.tag = this.tag; // reuse the same package tag
            p.symtab = new DsymbolTable();
            s = p;
        }
        if (!dst.insert(s))
        {
            /* It conflicts with a name that is already in the symbol table.
             * Figure out what went wrong, and issue error message.
             */
            Dsymbol prev = dst.lookup(ident);
            assert(prev);
            if (Module mprev = prev.isModule())
            {
                if (!FileName.equals(srcname, mprev.srcfile.toChars()))
                    error(loc, "from file %s conflicts with another module %s from file %s", srcname, mprev.toChars(), mprev.srcfile.toChars());
                else if (isRoot() && mprev.isRoot())
                    error(loc, "from file %s is specified twice on the command line", srcname);
                else
                    error(loc, "from file %s must be imported with 'import %s;'", srcname, toPrettyChars());
                // https://issues.dlang.org/show_bug.cgi?id=14446
                // Return previously parsed module to avoid AST duplication ICE.
                return mprev;
            }
            else if (Package pkg = prev.isPackage())
            {
                if (pkg.isPkgMod == PKG.unknown && isPackageFile)
                {
                    /* If the previous inserted Package is not yet determined as package.d,
                     * link it to the actual module.
                     */
                    pkg.isPkgMod = PKG.module_;
                    pkg.mod = this;
                    pkg.tag = this.tag; // reuse the same package tag
                    amodules.push(this); // Add to global array of all modules
                }
                else
                    error(md ? md.loc : loc, "from file %s conflicts with package name %s", srcname, pkg.toChars());
            }
            else
                assert(global.errors);
        }
        else
        {
            // Add to global array of all modules
            amodules.push(this);
        }
        return this;
    }

    override void importAll(Scope* prevsc)
    {
        //printf("+Module::importAll(this = %p, '%s'): parent = %p\n", this, toChars(), parent);
        if (_scope)
            return; // already done
        if (isDocFile)
        {
            error("is a Ddoc file, cannot import it");
            return;
        }

        /* Note that modules get their own scope, from scratch.
         * This is so regardless of where in the syntax a module
         * gets imported, it is unaffected by context.
         * Ignore prevsc.
         */
        Scope* sc = Scope.createGlobal(this); // create root scope

        if (md && md.msg)
            md.msg = semanticString(sc, md.msg, "deprecation message");

        // Add import of "object", even for the "object" module.
        // If it isn't there, some compiler rewrites, like
        //    classinst == classinst -> .object.opEquals(classinst, classinst)
        // would fail inside object.d.
        if (members.dim == 0 || (*members)[0].ident != Id.object ||
            (*members)[0].isImport() is null)
        {
            auto im = new Import(Loc.initial, null, Id.object, null, 0);
            members.shift(im);
        }
        if (!symtab)
        {
            // Add all symbols into module's symbol table
            symtab = new DsymbolTable();
            for (size_t i = 0; i < members.dim; i++)
            {
                Dsymbol s = (*members)[i];
                s.addMember(sc, sc.scopesym);
            }
        }
        // anything else should be run after addMember, so version/debug symbols are defined
        /* Set scope for the symbols so that if we forward reference
         * a symbol, it can possibly be resolved on the spot.
         * If this works out well, it can be extended to all modules
         * before any semantic() on any of them.
         */
        setScope(sc); // remember module scope for semantic
        for (size_t i = 0; i < members.dim; i++)
        {
            Dsymbol s = (*members)[i];
            s.setScope(sc);
        }
        for (size_t i = 0; i < members.dim; i++)
        {
            Dsymbol s = (*members)[i];
            s.importAll(sc);
        }
        sc = sc.pop();
        sc.pop(); // 2 pops because Scope::createGlobal() created 2
    }

    /**********************************
     * Determine if we need to generate an instance of ModuleInfo
     * for this Module.
     */
    int needModuleInfo()
    {
        //printf("needModuleInfo() %s, %d, %d\n", toChars(), needmoduleinfo, global.params.cov);
        return needmoduleinfo || global.params.cov;
    }

    override Dsymbol search(const ref Loc loc, Identifier ident, int flags = SearchLocalsOnly)
    {
        /* Since modules can be circularly referenced,
         * need to stop infinite recursive searches.
         * This is done with the cache.
         */
        //printf("%s Module.search('%s', flags = x%x) insearch = %d\n", toChars(), ident.toChars(), flags, insearch);
        if (insearch)
            return null;

        /* Qualified module searches always search their imports,
         * even if SearchLocalsOnly
         */
        if (!(flags & SearchUnqualifiedModule))
            flags &= ~(SearchUnqualifiedModule | SearchLocalsOnly);

        if (searchCacheIdent == ident && searchCacheFlags == flags)
        {
            //printf("%s Module::search('%s', flags = %d) insearch = %d searchCacheSymbol = %s\n",
            //        toChars(), ident.toChars(), flags, insearch, searchCacheSymbol ? searchCacheSymbol.toChars() : "null");
            return searchCacheSymbol;
        }

        uint errors = global.errors;

        insearch = 1;
        Dsymbol s = ScopeDsymbol.search(loc, ident, flags);
        insearch = 0;

        if (errors == global.errors)
        {
            // https://issues.dlang.org/show_bug.cgi?id=10752
            // Can cache the result only when it does not cause
            // access error so the side-effect should be reproduced in later search.
            searchCacheIdent = ident;
            searchCacheSymbol = s;
            searchCacheFlags = flags;
        }
        return s;
    }

    override bool isPackageAccessible(Package p, Prot protection, int flags = 0)
    {
        if (insearch) // don't follow import cycles
            return false;
        insearch = true;
        scope (exit)
            insearch = false;
        if (flags & IgnorePrivateImports)
            protection = Prot(Prot.Kind.public_); // only consider public imports
        return super.isPackageAccessible(p, protection);
    }

    override Dsymbol symtabInsert(Dsymbol s)
    {
        searchCacheIdent = null; // symbol is inserted, so invalidate cache
        return Package.symtabInsert(s);
    }

    void deleteObjFile()
    {
        if (global.params.obj)
            objfile.remove();
        if (docfile)
            docfile.remove();
    }

    /*******************************************
     * Can't run semantic on s now, try again later.
     */
    static void addDeferredSemantic(Dsymbol s)
    {
        //printf("Module::addDeferredSemantic('%s')\n", s.toChars());
        deferred.push(s);
    }

    static void addDeferredSemantic2(Dsymbol s)
    {
        //printf("Module::addDeferredSemantic2('%s')\n", s.toChars());
        deferred2.push(s);
    }

    static void addDeferredSemantic3(Dsymbol s)
    {
        //printf("Module::addDeferredSemantic3('%s')\n", s.toChars());
        deferred3.push(s);
    }

    /******************************************
     * Run semantic() on deferred symbols.
     */
    static void runDeferredSemantic()
    {
        if (dprogress == 0)
            return;

        __gshared int nested;
        if (nested)
            return;
        //if (deferred.dim) printf("+Module::runDeferredSemantic(), len = %d\n", deferred.dim);
        nested++;

        size_t len;
        do
        {
            dprogress = 0;
            len = deferred.dim;
            if (!len)
                break;

            Dsymbol* todo;
            Dsymbol* todoalloc = null;
            Dsymbol tmp;
            if (len == 1)
            {
                todo = &tmp;
            }
            else
            {
                todo = cast(Dsymbol*)malloc(len * Dsymbol.sizeof);
                assert(todo);
                todoalloc = todo;
            }
            memcpy(todo, deferred.tdata(), len * Dsymbol.sizeof);
            deferred.setDim(0);

            for (size_t i = 0; i < len; i++)
            {
                Dsymbol s = todo[i];
                s.dsymbolSemantic(null);
                //printf("deferred: %s, parent = %s\n", s.toChars(), s.parent.toChars());
            }
            //printf("\tdeferred.dim = %d, len = %d, dprogress = %d\n", deferred.dim, len, dprogress);
            if (todoalloc)
                free(todoalloc);
        }
        while (deferred.dim < len || dprogress); // while making progress
        nested--;
        //printf("-Module::runDeferredSemantic(), len = %d\n", deferred.dim);
    }

    static void runDeferredSemantic2()
    {
        Module.runDeferredSemantic();

        Dsymbols* a = &Module.deferred2;
        for (size_t i = 0; i < a.dim; i++)
        {
            Dsymbol s = (*a)[i];
            //printf("[%d] %s semantic2a\n", i, s.toPrettyChars());
            s.semantic2(null);

            if (global.errors)
                break;
        }
        a.setDim(0);
    }

    static void runDeferredSemantic3()
    {
        Module.runDeferredSemantic2();

        Dsymbols* a = &Module.deferred3;
        for (size_t i = 0; i < a.dim; i++)
        {
            Dsymbol s = (*a)[i];
            //printf("[%d] %s semantic3a\n", i, s.toPrettyChars());
            s.semantic3(null);

            if (global.errors)
                break;
        }
        a.setDim(0);
    }

    static void clearCache()
    {
        for (size_t i = 0; i < amodules.dim; i++)
        {
            Module m = amodules[i];
            m.searchCacheIdent = null;
        }
    }

    /************************************
     * Recursively look at every module this module imports,
     * return true if it imports m.
     * Can be used to detect circular imports.
     */
    int imports(Module m)
    {
        //printf("%s Module::imports(%s)\n", toChars(), m.toChars());
        version (none)
        {
            for (size_t i = 0; i < aimports.dim; i++)
            {
                Module mi = cast(Module)aimports.data[i];
                printf("\t[%d] %s\n", i, mi.toChars());
            }
        }
        for (size_t i = 0; i < aimports.dim; i++)
        {
            Module mi = aimports[i];
            if (mi == m)
                return true;
            if (!mi.insearch)
            {
                mi.insearch = 1;
                int r = mi.imports(m);
                if (r)
                    return r;
            }
        }
        return false;
    }

    bool isRoot()
    {
        return this.importedFrom == this;
    }

    // true if the module source file is directly
    // listed in command line.
    bool isCoreModule(Identifier ident)
    {
        return this.ident == ident && parent && parent.ident == Id.core && !parent.parent;
    }

    // Back end
    int doppelganger; // sub-module
    Symbol* cov; // private uint[] __coverage;
    uint* covb; // bit array of valid code line numbers
    Symbol* sictor; // module order independent constructor
    Symbol* sctor; // module constructor
    Symbol* sdtor; // module destructor
    Symbol* ssharedctor; // module shared constructor
    Symbol* sshareddtor; // module shared destructor
    Symbol* stest; // module unit test
    Symbol* sfilename; // symbol for filename

    override inout(Module) isModule() inout
    {
        return this;
    }

    override void accept(Visitor v)
    {
        v.visit(this);
    }

    /***********************************************
     * Writes this module's fully-qualified name to buf
     * Params:
     *    buf = The buffer to write to
     */
    void fullyQualifiedName(ref OutBuffer buf)
    {
        buf.writestring(ident.toString());

        for (auto package_ = parent; package_ !is null; package_ = package_.parent)
        {
            buf.prependstring(".");
            buf.prependstring(package_.ident.toChars());
        }
    }
}

/***********************************************************
 */
struct ModuleDeclaration
{
    Loc loc;
    Identifier id;
    Identifiers* packages;  // array of Identifier's representing packages
    bool isdeprecated;      // if it is a deprecated module
    Expression msg;

    extern (D) this(const ref Loc loc, Identifiers* packages, Identifier id, Expression msg, bool isdeprecated)
    {
        this.loc = loc;
        this.packages = packages;
        this.id = id;
        this.msg = msg;
        this.isdeprecated = isdeprecated;
    }

    extern (C++) const(char)* toChars() const
    {
        OutBuffer buf;
        if (packages && packages.dim)
        {
            foreach (pid; *packages)
            {
                buf.writestring(pid.toString());
                buf.writeByte('.');
            }
        }
        buf.writestring(id.toString());
        return buf.extractString();
    }

    /// Provide a human readable representation
    extern (D) const(char)[] toString() const
    {
        return this.toChars().toDString;
    }
}
