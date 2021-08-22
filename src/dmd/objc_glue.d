/**
 * Glue code for Objective-C interop.
 *
 * Copyright:   Copyright (C) 2015-2021 by The D Language Foundation, All Rights Reserved
 * Authors:     $(LINK2 http://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/src/dmd/objc_glue.d, _objc_glue.d)
 * Documentation:  https://dlang.org/phobos/dmd_objc_glue.html
 * Coverage:    https://codecov.io/gh/dlang/dmd/src/master/src/dmd/objc_glue.d
 */

module dmd.objc_glue;

import core.stdc.stdio;
import core.stdc.stdlib;
import core.stdc.string;

import dmd.aggregate;
import dmd.arraytypes;
import dmd.astenums;
import dmd.dclass;
import dmd.declaration;
import dmd.dmodule;
import dmd.dsymbol;
import dmd.expression;
import dmd.func;
import dmd.glue;
import dmd.identifier;
import dmd.mtype;
import dmd.objc;
import dmd.target;

import dmd.root.stringtable;
import dmd.root.array;

import dmd.backend.dt;
import dmd.backend.cc;
import dmd.backend.cdef;
import dmd.backend.el;
import dmd.backend.global;
import dmd.backend.oper;
import dmd.backend.outbuf;
import dmd.backend.ty;
import dmd.backend.type;
import dmd.backend.mach;
import dmd.backend.obj;

private __gshared ObjcGlue _objc;

ObjcGlue objc()
{
    return _objc;
}

// Should be an interface
extern(C++) abstract class ObjcGlue
{
    static struct ElemResult
    {
        elem* ec;
        elem* ethis;
    }

    static void initialize()
    {
        if (target.objc.supported)
            _objc = new Supported;
        else
            _objc = new Unsupported;
    }

    /// Resets the Objective-C glue layer.
    abstract void reset();

    abstract void setupMethodSelector(FuncDeclaration fd, elem** esel);

    abstract ElemResult setupMethodCall(FuncDeclaration fd, TypeFunction tf,
        bool directcall, elem* ec, elem* ehidden, elem* ethis);

    abstract void setupEp(elem* esel, elem** ep, int leftToRight);
    abstract void generateModuleInfo(Module module_);

    /// Returns: the given expression converted to an `elem` structure
    abstract elem* toElem(ObjcClassReferenceExp e) const;

    /// Outputs the given Objective-C class to the object file.
    abstract void toObjFile(ClassDeclaration classDeclaration) const;

    /**
     * Adds the selector parameter to the given list of parameters.
     *
     * For Objective-C methods the selector parameter is added. For
     * non-Objective-C methods `parameters` is unchanged.
     *
     * Params:
     *  functionDeclaration = the function declaration to add the selector
     *      parameter from
     *  parameters = the list of parameters to add the selector parameter to
     *  parameterCount = the number of parameters
     *
     * Returns: the new number of parameters
     */
    abstract size_t addSelectorParameterSymbol(
        FuncDeclaration functionDeclaration,
        Symbol** parameters, size_t parameterCount) const;

    /**
     * Returns the offset of the given variable declaration `var`.
     *
     * This is used in a `DotVarExp` to get the offset of the variable the
     * expression is accessing.
     *
     * Instance variables in Objective-C are non-fragile. That means that the
     * base class can change (add or remove instance variables) without the
     * subclasses needing to recompile or relink. This is implemented instance
     * variables having a dynamic offset. This is achieved by going through an
     * indirection in the form of a symbol generated in the binary. The compiler
     * outputs the static offset in the generated symbol. Then, at load time,
     * the symbol is updated with the correct offset, if necessary.
     *
     * Params:
     *  var = the variable declaration to return the offset of
     *  type = the type of the `DotVarExp`
     *  offset = the existing offset
     *
     * Returns: a symbol containing the offset of the variable declaration
     */
    abstract elem* getOffset(VarDeclaration var, Type type, elem* offset) const;
}

private:

extern(C++) final class Unsupported : ObjcGlue
{
    override void reset()
    {
        // noop
    }

    override void setupMethodSelector(FuncDeclaration fd, elem** esel)
    {
        // noop
    }

    override ElemResult setupMethodCall(FuncDeclaration, TypeFunction, bool,
        elem*, elem*, elem*)
    {
        assert(0, "Should never be called when Objective-C is not supported");
    }

    override void setupEp(elem* esel, elem** ep, int reverse)
    {
        // noop
    }

    override void generateModuleInfo(Module)
    {
        // noop
    }

    override elem* toElem(ObjcClassReferenceExp e) const
    {
        assert(0, "Should never be called when Objective-C is not supported");
    }

    override void toObjFile(ClassDeclaration classDeclaration) const
    {
        assert(0, "Should never be called when Objective-C is not supported");
    }

    override size_t addSelectorParameterSymbol(FuncDeclaration, Symbol**,
        size_t count) const
    {
        return count;
    }

    override elem* getOffset(VarDeclaration var, Type type, elem* offset) const
    {
        return offset;
    }
}

extern(C++) final class Supported : ObjcGlue
{
    extern (D) this()
    {
        Segments.initialize();
        Symbols.initialize();
    }

    override void reset()
    {
        Segments.reset();
        Symbols.reset();
    }

    override void setupMethodSelector(FuncDeclaration fd, elem** esel)
    {
        if (fd && fd.objc.selector && !*esel)
        {
            *esel = el_var(Symbols.getMethVarRef(fd.objc.selector.toString()));
        }
    }

    override ElemResult setupMethodCall(FuncDeclaration fd, TypeFunction tf,
        bool directcall, elem* ec, elem* ehidden, elem* ethis)
    {
        import dmd.e2ir : addressElem;

        if (directcall) // super call
        {
            ElemResult result;
            // call through Objective-C runtime dispatch
            result.ec = el_var(Symbols.getMsgSendSuper(ehidden !is null));

            // need to change this pointer to a pointer to an two-word
            // objc_super struct of the form { this ptr, class ptr }.
            auto cd = fd.isThis.isClassDeclaration;
            assert(cd, "call to objc_msgSendSuper with no class declaration");

            // faking objc_super type as delegate
            auto classRef = el_var(Symbols.getClassReference(cd));
            auto super_ = el_pair(TYdelegate, ethis, classRef);

            result.ethis = addressElem(super_, tf);

            return result;
        }

        else
        {
            // make objc-style "virtual" call using dispatch function
            assert(ethis);
            Type tret = tf.next;

            ElemResult result = {
                ec: el_var(Symbols.getMsgSend(tret, ehidden !is null)),
                ethis: ethis
            };

            return result;
        }
    }

    override void setupEp(elem* esel, elem** ep, int leftToRight)
    {
        if (esel)
        {
            // using objc-style "virtual" call
            // add hidden argument (second to 'this') for selector used by dispatch function
            if (leftToRight)
                *ep = el_param(esel, *ep);
            else
                *ep = el_param(*ep, esel);
        }
    }

    override void generateModuleInfo(Module module_)
    {
        ClassDeclarations classes;
        ClassDeclarations categories;

        module_.members.foreachDsymbol(m => m.addObjcSymbols(&classes, &categories));

        if (classes.length || categories.length || Symbols.hasSymbols)
            Symbols.getModuleInfo(classes, categories);
    }

    override elem* toElem(ObjcClassReferenceExp e) const
    {
        return el_var(Symbols.getClassReference(e.classDeclaration));
    }

    override void toObjFile(ClassDeclaration classDeclaration) const
    in
    {
        assert(classDeclaration !is null);
        assert(classDeclaration.classKind == ClassKind.objc);
    }
    do
    {
        if (!classDeclaration.objc.isMeta)
            ObjcClassDeclaration(classDeclaration, false).toObjFile();
    }

    override size_t addSelectorParameterSymbol(FuncDeclaration fd,
        Symbol** params, size_t count) const
    in
    {
        assert(fd);
    }
    do
    {
        if (!fd.objc.selector)
            return count;

        assert(fd.objc.selectorParameter);
        auto selectorSymbol = fd.objc.selectorParameter.toSymbol();
        memmove(params + 1, params, count * params[0].sizeof);
        params[0] = selectorSymbol;

        return count + 1;
    }

    override elem* getOffset(VarDeclaration var, Type type, elem* offset) const
    {
        auto typeClass = type.isTypeClass;

        if (!typeClass || typeClass.sym.classKind != ClassKind.objc)
            return offset;

        return el_var(ObjcClassDeclaration(typeClass.sym, false).getIVarOffset(var));
    }
}

struct Segments
{
    enum Id
    {
        classlist,
        classname,
        classrefs,
        const_,
        objcData,
        imageinfo,
        ivar,
        methname,
        methtype,
        selrefs,
        protolist,
        data
    }

    private
    {
        __gshared int[Id] segments;
        __gshared Segments[Id] segmentData;

        immutable(char*) sectionName;
        immutable(char*) segmentName;
        immutable int flags;
        immutable int alignment;

        this(typeof(this.tupleof) tuple)
        {
            this.tupleof = tuple;
        }

        static void initialize()
        {
            segmentData = [
                Id.classlist: Segments("__objc_classlist", "__DATA", S_REGULAR | S_ATTR_NO_DEAD_STRIP, 3),
                Id.classname: Segments("__objc_classname", "__TEXT", S_CSTRING_LITERALS, 0),
                Id.classrefs: Segments("__objc_classrefs", "__DATA", S_REGULAR | S_ATTR_NO_DEAD_STRIP, 3),
                Id.const_: Segments("__objc_const", "__DATA", S_REGULAR, 3),
                Id.objcData: Segments("__objc_data", "__DATA", S_REGULAR, 3),
                Id.imageinfo: Segments("__objc_imageinfo", "__DATA", S_REGULAR | S_ATTR_NO_DEAD_STRIP, 0),
                Id.ivar: Segments("__objc_ivar", "__DATA", S_REGULAR, 3),
                Id.methname: Segments("__objc_methname", "__TEXT", S_CSTRING_LITERALS, 0),
                Id.methtype: Segments("__objc_methtype", "__TEXT", S_CSTRING_LITERALS, 0),
                Id.selrefs: Segments("__objc_selrefs", "__DATA", S_LITERAL_POINTERS | S_ATTR_NO_DEAD_STRIP, 3),
                Id.protolist: Segments("__objc_protolist", "__DATA", S_COALESCED | S_ATTR_NO_DEAD_STRIP, 3),
                Id.data: Segments("__data", "__DATA", S_REGULAR, 3),
            ];
        }
    }

    /// Resets the segments.
    static void reset()
    {
        clearCache();
    }

    // Clears any caches.
    private static void clearCache()
    {
        segments.clear;
    }

    static int opIndex(Id id)
    {
        if (auto segment = id in segments)
            return *segment;

        const seg = segmentData[id];

        version (OSX)
        {
            return segments[id] = Obj.getsegment(
                seg.sectionName,
                seg.segmentName,
                seg.alignment,
                seg.flags
            );
        }

        else
        {
            // This should never happen. If the platform is not OSX an error
            // should have occurred sooner which should have prevented the
            // code from getting here.
            assert(0);
        }
    }
}

struct Symbols
{
static:

    private __gshared
    {
        alias SymbolCache = StringTable!(Symbol*)*;

        bool hasSymbols_ = false;

        Symbol* objc_msgSend = null;
        Symbol* objc_msgSend_stret = null;
        Symbol* objc_msgSend_fpret = null;
        Symbol* objc_msgSend_fp2ret = null;

        Symbol* objc_msgSendSuper = null;
        Symbol* objc_msgSendSuper_stret = null;

        Symbol* imageInfo = null;
        Symbol* moduleInfo = null;

        Symbol* emptyCache = null;
        Symbol* emptyVTable = null;

        // Cache for `_OBJC_METACLASS_$_`/`_OBJC_CLASS_$_` symbols.
        SymbolCache classNameTable = null;

        // Cache for `L_OBJC_CLASSLIST_REFERENCES_` symbols.
        SymbolCache classReferenceTable = null;

        // Cache for `__OBJC_PROTOCOL_$_` symbols.
        SymbolCache protocolTable = null;

        SymbolCache methVarNameTable = null;
        SymbolCache methVarRefTable = null;
        SymbolCache methVarTypeTable = null;

        // Cache for instance variable offsets
        SymbolCache ivarOffsetTable = null;
    }

    void initialize()
    {
        initializeStringTables();
    }

    private void initializeStringTables()
    {
        alias This = typeof(this);

        foreach (m ; __traits(allMembers, This))
        {
            static if (is(typeof(__traits(getMember, This, m)) == SymbolCache))
            {
                __traits(getMember, This, m) = new StringTable!(Symbol*)();
                __traits(getMember, This, m)._init();
            }
        }
    }

    /// Resets the symbols.
    void reset()
    {
        clearCache();
        resetSymbolCache();
    }

    // Clears any caches.
    private void clearCache()
    {
        alias This = typeof(this);

        foreach (m ; __traits(allMembers, This))
        {
            static if (is(typeof(__traits(getMember, This, m)) == Symbol*))
                __traits(getMember, This, m) = null;
        }
    }

    // Resets the symbol caches.
    private void resetSymbolCache()
    {
        alias This = typeof(this);

        foreach (m ; __traits(allMembers, This))
        {
            static if (is(typeof(__traits(getMember, This, m)) == SymbolCache))
                __traits(getMember, This, m).reset();
        }
    }

    bool hasSymbols()
    {
        if (hasSymbols_)
            return true;

        alias This = typeof(this);

        foreach (m ; __traits(allMembers, This))
        {
            static if (is(typeof(__traits(getMember, This, m)) == Symbol*))
            {
                if (__traits(getMember, This, m) !is null)
                    return true;
            }
        }

        return false;
    }

    /**
     * Convenience wrapper around `dmd.backend.global.symbol_name`.
     *
     * Allows to pass the name of the symbol as a D string.
     */
    Symbol* symbolName(const(char)[] name, int sclass, type* t)
    {
        return symbol_name(name.ptr, cast(uint) name.length, sclass, t);
    }

    /**
     * Gets a global symbol.
     *
     * Params:
     *  name = the name of the symbol
     *  t = the type of the symbol
     *
     * Returns: the symbol
     */
    Symbol* getGlobal(const(char)[] name, type* t = type_fake(TYnptr))
    {
        return symbolName(name, SCglobal, t);
    }

    /**
     * Gets a static symbol.
     *
     * Params:
     *  name = the name of the symbol
     *  t = the type of the symbol
     *
     * Returns: the symbol
     */
    Symbol* getStatic(const(char)[] name, type* t = type_fake(TYnptr))
    {
        return symbolName(name, SCstatic, t);
    }

    Symbol* getCString(const(char)[] str, const(char)[] symbolName, Segments.Id segment)
    {
        hasSymbols_ = true;

        // create data
        auto dtb = DtBuilder(0);
        dtb.nbytes(cast(uint) (str.length + 1), str.toStringz());

        // find segment
        auto seg = Segments[segment];

        // create symbol
        auto s = getStatic(symbolName, type_allocn(TYarray, tstypes[TYchar]));
        s.Sdt = dtb.finish();
        s.Sseg = seg;
        return s;
    }

    Symbol* getMethVarName(const(char)[] name)
    {
        return cache(name, methVarNameTable, {
            __gshared size_t classNameCount = 0;
            char[42] buffer;
            const symbolName = format(buffer, "L_OBJC_METH_VAR_NAME_%lu", classNameCount++);

            return getCString(name, symbolName, Segments.Id.methname);
        });
    }

    Symbol* getMethVarName(Identifier ident)
    {
        return getMethVarName(ident.toString());
    }

    Symbol* getMsgSend(Type returnType, bool hasHiddenArgument)
    {
        if (hasHiddenArgument)
            return setMsgSendSymbol!("_objc_msgSend_stret")(TYhfunc);
        // not sure if DMD can handle this
        else if (returnType.ty == Tcomplex80)
            return setMsgSendSymbol!("_objc_msgSend_fp2ret");
        else if (returnType.ty == Tfloat80)
            return setMsgSendSymbol!("_objc_msgSend_fpret");
        else
            return setMsgSendSymbol!("_objc_msgSend");

        assert(0);
    }

    Symbol* getMsgSendSuper(bool hasHiddenArgument)
    {
        if (hasHiddenArgument)
            return setMsgSendSymbol!("_objc_msgSendSuper_stret")(TYhfunc);
        else
            return setMsgSendSymbol!("_objc_msgSendSuper")(TYnfunc);
    }

    Symbol* getImageInfo()
    {
        if (imageInfo)
            return imageInfo;

        auto dtb = DtBuilder(0);
        dtb.dword(0); // version
        dtb.dword(64); // flags

        imageInfo = symbol_name("L_OBJC_IMAGE_INFO", SCstatic, type_allocn(TYarray, tstypes[TYchar]));
        imageInfo.Sdt = dtb.finish();
        imageInfo.Sseg = Segments[Segments.Id.imageinfo];
        outdata(imageInfo);

        return imageInfo;
    }

    Symbol* getModuleInfo(/*const*/ ref ClassDeclarations classes,
        /*const*/ ref ClassDeclarations categories)
    {
        assert(!moduleInfo); // only allow once per object file

        auto dtb = DtBuilder(0);

        foreach (c; classes)
            dtb.xoff(getClassName(c), 0);

        foreach (c; categories)
            dtb.xoff(getClassName(c), 0);

        Symbol* symbol = symbol_name("L_OBJC_LABEL_CLASS_$", SCstatic, type_allocn(TYarray, tstypes[TYchar]));
        symbol.Sdt = dtb.finish();
        symbol.Sseg = Segments[Segments.Id.classlist];
        outdata(symbol);

        getImageInfo(); // make sure we also generate image info

        return moduleInfo;
    }

    /**
     * Returns: the `_OBJC_METACLASS_$_`/`_OBJC_CLASS_$_` symbol for the given
     *  class declaration.
     */
    Symbol* getClassName(ObjcClassDeclaration objcClass)
    {
        hasSymbols_ = true;

        const prefix = objcClass.isMeta ? "_OBJC_METACLASS_$_" : "_OBJC_CLASS_$_";
        auto name = prefix ~ objcClass.classDeclaration.objc.identifier.toString();

        return cache(name, classNameTable, () => getGlobal(name));
    }

    /// ditto
    Symbol* getClassName(ClassDeclaration classDeclaration, bool isMeta = false)
    in
    {
        assert(classDeclaration !is null);
    }
    do
    {
        return getClassName(ObjcClassDeclaration(classDeclaration, isMeta));
    }

    /*
     * Returns: the `L_OBJC_CLASSLIST_REFERENCES_$_` symbol for the given class
     *  declaration.
     */
    Symbol* getClassReference(ClassDeclaration classDeclaration)
    {
        hasSymbols_ = true;

        auto name = classDeclaration.objc.identifier.toString();

        return cache(name, classReferenceTable, {
            auto dtb = DtBuilder(0);
            auto className = getClassName(classDeclaration);
            dtb.xoff(className, 0, TYnptr);

            auto segment = Segments[Segments.Id.classrefs];

            __gshared size_t classReferenceCount = 0;

            char[42] nameString;
            auto result = format(nameString, "L_OBJC_CLASSLIST_REFERENCES_$_%lu", classReferenceCount++);
            auto symbol = getStatic(result);
            symbol.Sdt = dtb.finish();
            symbol.Sseg = segment;
            outdata(symbol);

            return symbol;
        });
    }

    Symbol* getMethVarRef(const(char)[] name)
    {
        return cache(name, methVarRefTable, {
            // create data
            auto dtb = DtBuilder(0);
            auto selector = getMethVarName(name);
            dtb.xoff(selector, 0, TYnptr);

            // find segment
            auto seg = Segments[Segments.Id.selrefs];

            // create symbol
            __gshared size_t selectorCount = 0;
            char[42] nameString;
            sprintf(nameString.ptr, "L_OBJC_SELECTOR_REFERENCES_%llu", cast(ulong) selectorCount);
            auto symbol = symbol_name(nameString.ptr, SCstatic, type_fake(TYnptr));

            symbol.Sdt = dtb.finish();
            symbol.Sseg = seg;
            outdata(symbol);

            ++selectorCount;

            return symbol;
        });
    }

    Symbol* getMethVarRef(const Identifier ident)
    {
        return getMethVarRef(ident.toString());
    }

    /**
     * Returns the Objective-C type encoding for the given type.
     *
     * The available type encodings are documented by Apple, available at
     * $(LINK2 https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/ObjCRuntimeGuide/Articles/ocrtTypeEncodings.html#//apple_ref/doc/uid/TP40008048-CH100, Type Encoding).
     * The type encodings can also be obtained by running an Objective-C
     * compiler and using the `@encode()` compiler directive.
     *
     * Params:
     *  type = the type to return the type encoding for
     *
     * Returns: a string containing the type encoding
     */
    string getTypeEncoding(Type type)
    in
    {
        assert(type !is null);
    }
    do
    {
        enum assertMessage = "imaginary types are not supported by Objective-C";

        with (TY) switch (type.ty)
        {
            case Tvoid: return "v";
            case Tbool: return "B";
            case Tint8: return "c";
            case Tuns8: return "C";
            case Tchar: return "C";
            case Tint16: return "s";
            case Tuns16: return "S";
            case Twchar: return "S";
            case Tint32: return "i";
            case Tuns32: return "I";
            case Tdchar: return "I";
            case Tint64: return "q";
            case Tuns64: return "Q";
            case Tfloat32: return "f";
            case Tcomplex32: return "jf";
            case Tfloat64: return "d";
            case Tcomplex64: return "jd";
            case Tfloat80: return "D";
            case Tcomplex80: return "jD";
            case Timaginary32: assert(false, assertMessage);
            case Timaginary64: assert(false, assertMessage);
            case Timaginary80: assert(false, assertMessage);
            default: return "?"; // unknown
            // TODO: add "*" char*, "#" Class, "@" id, ":" SEL
            // TODO: add "^"<type> indirection and "^^" double indirection
        }
    }

    /**
     * Returns: the `L_OBJC_METH_VAR_TYPE_` symbol containing the given
     * type encoding.
     */
    Symbol* getMethVarType(const(char)[] typeEncoding)
    {
        return cache(typeEncoding, methVarTypeTable, {
            __gshared size_t count = 0;
            char[42] nameString;
            const symbolName = format(nameString, "L_OBJC_METH_VAR_TYPE_%lu", count++);
            auto symbol = getCString(typeEncoding, symbolName, Segments.Id.methtype);

            outdata(symbol);

            return symbol;
        });
    }

    /// ditto
    Symbol* getMethVarType(Type[] types ...)
    {
        string typeCode;
        typeCode.reserve(types.length);

        foreach (type; types)
            typeCode ~= getTypeEncoding(type);

        return getMethVarType(typeCode);
    }

    /// ditto
    Symbol* getMethVarType(FuncDeclaration func)
    {
        Type[] types = [func.type.nextOf]; // return type first

        if (func.parameters)
        {
            types.reserve(func.parameters.length);

            foreach (e; *func.parameters)
                types ~= e.type;
        }

        return getMethVarType(types);
    }

    /// Returns: the externally defined `__objc_empty_cache` symbol
    Symbol* getEmptyCache()
    {
        return emptyCache = emptyCache ? emptyCache : getGlobal("__objc_empty_cache");
    }

    /// Returns: the externally defined `__objc_empty_vtable` symbol
    Symbol* getEmptyVTable()
    {
        return emptyVTable = emptyVTable ? emptyVTable : getGlobal("__objc_empty_vtable");
    }

    /// Returns: the `L_OBJC_CLASS_NAME_` symbol for a class with the given name
    Symbol* getClassNameRo(const(char)[] name)
    {
        return cache(name, classNameTable, {
            __gshared size_t count = 0;
            char[42] nameString;
            const symbolName = format(nameString, "L_OBJC_CLASS_NAME_%lu", count++);

            return getCString(name, symbolName, Segments.Id.classname);
        });
    }

    /// ditto
    Symbol* getClassNameRo(const Identifier ident)
    {
        return getClassNameRo(ident.toString());
    }

    Symbol* getIVarOffset(ClassDeclaration cd, VarDeclaration var, bool outputSymbol)
    {
        hasSymbols_ = true;

        const className = cd.objc.identifier.toString;
        const varName = var.ident.toString;
        const name = "_OBJC_IVAR_$_" ~ className ~ '.' ~ varName;

        auto stringValue = ivarOffsetTable.update(name);
        auto symbol = stringValue.value;

        if (!symbol)
        {
            symbol = getGlobal(name);
            symbol.Sfl |= FLextern;
            stringValue.value = symbol;
        }

        if (!outputSymbol)
            return symbol;

        auto dtb = DtBuilder(0);
        dtb.size(var.offset);

        symbol.Sdt = dtb.finish();
        symbol.Sseg = Segments[Segments.Id.ivar];
        symbol.Sfl &= ~FLextern;

        outdata(symbol);

        return symbol;
    }

    Symbol* getProtocolSymbol(InterfaceDeclaration id)
    in
    {
        assert(!id.objc.isMeta);
    }
    do
    {
        const name = id.objc.identifier.toString();
        return cache(name, protocolTable, () => ProtocolDeclaration(id).toObjFile());
    }

    private Symbol* setMsgSendSymbol(string name)(tym_t ty = TYnfunc)
    {
        alias This = typeof(this);
        enum fieldName = name[1 .. $];

        if (!__traits(getMember, This, fieldName))
            __traits(getMember, This, fieldName) = getGlobal(name, type_fake(ty));

        return __traits(getMember, This, fieldName);
    }

    /**
     * Caches the symbol returned by `block` using the given name.
     *
     * If the symbol is already in the cache, the symbol will be returned
     * immediately and `block` will not be called.
     *
     * Params:
     *  name = the name to cache the symbol under
     *  symbolCache = the cache storage to use for this symbol
     *  block = invoked when the symbol is not in the cache. The return value
     *      will be put into the cache
     *
     * Returns: the cached symbol
     */
    private Symbol* cache(const(char)[] name, SymbolCache symbolCache,
        scope Symbol* delegate() block)
    {
        hasSymbols_ = true;

        auto stringValue = symbolCache.update(name);

        if (stringValue.value)
            return stringValue.value;

        return stringValue.value = block();
    }
}

private:

/**
 * Functionality for outputting symbols for a specific Objective-C class
 * declaration.
 */
struct ObjcClassDeclaration
{
    /// Indicates what kind of class this is.
    private enum Flags
    {
        /// Regular class.
        regular = 0x00000,

        /// Meta class.
        meta = 0x00001,

        /// Root class. A class without any base class.
        root = 0x00002
    }

    /// The class declaration
    ClassDeclaration classDeclaration;

    /// `true` if this class is a metaclass.
    bool isMeta;

    this(ClassDeclaration classDeclaration, bool isMeta)
    in
    {
        assert(classDeclaration !is null);
    }
    do
    {
        this.classDeclaration = classDeclaration;
        this.isMeta = isMeta;
    }

    /**
     * Outputs the class declaration to the object file.
     *
     * Returns: the exported symbol, that is, `_OBJC_METACLASS_$_` or
     * `_OBJC_CLASS_$_`
     */
    Symbol* toObjFile()
    {
        if (classDeclaration.objc.isExtern)
            return null; // only a declaration for an externally-defined class

        auto dtb = DtBuilder(0);
        toDt(dtb);

        auto symbol = Symbols.getClassName(this);
        symbol.Sdt = dtb.finish();
        symbol.Sseg = Segments[Segments.Id.objcData];
        outdata(symbol);

        return symbol;
    }

private:

    /**
     * Outputs the class declaration to the object file.
     *
     * Params:
     *  dtb = the `DtBuilder` to output the class declaration to
     */
    void toDt(ref DtBuilder dtb)
    {
        auto baseClassSymbol = classDeclaration.baseClass ?
            Symbols.getClassName(classDeclaration.baseClass, isMeta) : null;

        dtb.xoff(getMetaclass(), 0); // pointer to metaclass
        dtb.xoffOrNull(baseClassSymbol); // pointer to base class
        dtb.xoff(Symbols.getEmptyCache(), 0);
        dtb.xoff(Symbols.getEmptyVTable(), 0);
        dtb.xoff(getClassRo(), 0);
    }

    /// Returns: the name of the metaclass of this class declaration
    Symbol* getMetaclass()
    {
        if (isMeta)
        {
            // metaclass: return root class's name
            // (will be replaced with metaclass reference at load)

            auto metaclassDeclaration = classDeclaration;

            while (metaclassDeclaration.baseClass)
                metaclassDeclaration = metaclassDeclaration.baseClass;

            return Symbols.getClassName(metaclassDeclaration, true);
        }

        else
        {
            // regular class: return metaclass with the same name
            return ObjcClassDeclaration(classDeclaration, true).toObjFile();
        }
    }

    /**
     * Returns: the `l_OBJC_CLASS_RO_$_`/`l_OBJC_METACLASS_RO_$_` symbol for
     * this class declaration
     */
    Symbol* getClassRo()
    {
        auto dtb = DtBuilder(0);

        dtb.dword(flags);
        dtb.dword(instanceStart);
        dtb.dword(instanceSize);
        dtb.dword(0); // reserved

        dtb.size(0); // ivar layout
        dtb.xoff(Symbols.getClassNameRo(classDeclaration.ident), 0); // name of the class

        dtb.xoffOrNull(getMethodList()); // instance method list
        dtb.xoffOrNull(getProtocolList()); // protocol list

        if (isMeta)
        {
            dtb.size(0); // instance variable list
            dtb.size(0); // weak ivar layout
            dtb.size(0); // properties
        }

        else
        {
            dtb.xoffOrNull(getIVarList()); // instance variable list
            dtb.size(0); // weak ivar layout
            dtb.xoffOrNull(getPropertyList()); // properties
        }

        const prefix = isMeta ? "l_OBJC_METACLASS_RO_$_" : "l_OBJC_CLASS_RO_$_";
        const symbolName = prefix ~ classDeclaration.objc.identifier.toString();
        auto symbol = Symbols.getStatic(symbolName);

        symbol.Sdt = dtb.finish();
        symbol.Sseg = Segments[Segments.Id.const_];
        outdata(symbol);

        return symbol;
    }

    /**
     * Returns method list for this class declaration.
     *
     * This is a list of all methods defined in this class declaration, i.e.
     * methods with a body.
     *
     * Returns: the symbol for the method list, `l_OBJC_$_CLASS_METHODS_` or
     * `l_OBJC_$_INSTANCE_METHODS_`
     */
    Symbol* getMethodList()
    {
        auto methods = isMeta ? classDeclaration.objc.metaclass.objc.methodList :
            classDeclaration.objc.methodList;

        auto methodsWithBody = methods.filter!(m => m.fbody);
        const methodCount = methodsWithBody.walkLength;

        if (methodCount == 0)
            return null;

        auto dtb = DtBuilder(0);

        dtb.dword(24); // _objc_method.sizeof
        dtb.dword(cast(int) methodCount); // method count

        foreach (func; methodsWithBody)
        {
            assert(func.objc.selector);

            dtb.xoff(func.objc.selector.toNameSymbol(), 0); // method name
            dtb.xoff(Symbols.getMethVarType(func), 0); // method type string
            dtb.xoff(func.toSymbol(), 0); // function implementation
        }

        const prefix = isMeta ? "l_OBJC_$_CLASS_METHODS_" : "l_OBJC_$_INSTANCE_METHODS_";
        const symbolName = prefix ~ classDeclaration.objc.identifier.toString();
        auto symbol = Symbols.getStatic(symbolName);

        symbol.Sdt = dtb.finish();
        symbol.Sseg = Segments[Segments.Id.const_];

        return symbol;
    }

    Symbol* getProtocolList()
    {
        if (classDeclaration.interfaces.length == 0)
            return null;

        auto dtb = DtBuilder(0);
        dtb.size(classDeclaration.interfaces.length); // count

        auto protocolSymbols = classDeclaration
            .interfaces
            .map!(base => cast(InterfaceDeclaration) base.sym)
            .map!(Symbols.getProtocolSymbol);

        foreach (symbol; protocolSymbols)
            dtb.xoff(symbol, 0); // pointer to protocol declaration

        dtb.size(0); // null-terminate the list

        enum prefix = "__OBJC_CLASS_PROTOCOLS_$_";
        const symbolName = prefix ~ classDeclaration.objc.identifier.toString();
        auto symbol = Symbols.getStatic(symbolName);
        symbol.Sseg = Segments[Segments.Id.const_];
        symbol.Salignment = 3;
        symbol.Sdt = dtb.finish();

        return symbol;
    }

    Symbol* getIVarList()
    {
        if (isMeta || classDeclaration.fields.length == 0)
            return null;

        auto dtb = DtBuilder(0);

        dtb.dword(32); // entsize, _ivar_t.sizeof
        dtb.dword(cast(int) classDeclaration.fields.length); // ivar count

        foreach (field; classDeclaration.fields)
        {
            auto var = field.isVarDeclaration;
            assert(var);
            assert((var.storage_class & STC.static_) == 0);

            dtb.xoff(Symbols.getIVarOffset(classDeclaration, var, true), 0); // pointer to ivar offset
            dtb.xoff(Symbols.getMethVarName(var.ident), 0); // name
            dtb.xoff(Symbols.getMethVarType(var.type), 0); // type string
            dtb.dword(var.alignment);
            dtb.dword(cast(int) var.size(var.loc));
        }

        enum prefix = "l_OBJC_$_INSTANCE_VARIABLES_";
        const symbolName = prefix ~ classDeclaration.objc.identifier.toString();
        auto symbol = Symbols.getStatic(symbolName);

        symbol.Sdt = dtb.finish();
        symbol.Sseg = Segments[Segments.Id.const_];

        return symbol;
    }

    Symbol* getPropertyList()
    {
        // properties are not supported yet
        return null;
    }

    Symbol* getIVarOffset(VarDeclaration var)
    {
        if (var.toParent() is classDeclaration)
            return Symbols.getIVarOffset(classDeclaration, var, false);

        else if (classDeclaration.baseClass)
            return ObjcClassDeclaration(classDeclaration.baseClass, false)
                .getIVarOffset(var);

        else
            assert(false, "Trying to get the base class of a root class");
    }

    /**
     * Returns the flags for this class declaration.
     *
     * That is, if this is a regular class, a metaclass and/or a root class.
     *
     * Returns: the flags
     */
    uint flags() const
    {
        uint flags = isMeta ? Flags.meta : Flags.regular;

        if (classDeclaration.objc.isRootClass)
            flags |= Flags.root;

        return flags;
    }

    /**
     * Returns the offset of where an instance of this class starts.
     *
     * For a metaclass this is always `40`. For a class with no instance
     * variables this is the size of the class declaration. For a class with
     * instance variables it's the offset of the first instance variable.
     *
     * Returns: the instance start
     */
    int instanceStart()
    {
        if (isMeta)
            return 40;

        const start = cast(uint) classDeclaration.size(classDeclaration.loc);

        if (!classDeclaration.members || classDeclaration.members.length == 0)
            return start;

        foreach (member; *classDeclaration.members)
        {
            auto var = member.isVarDeclaration;

            if (var && var.isField)
                return var.offset;
        }

        return start;
    }

    /// Returns: the size of an instance of this class
    int instanceSize()
    {
        return isMeta ? 40 : cast(int) classDeclaration.size(classDeclaration.loc);
    }
}

/**
 * Functionality for outputting symbols for a specific Objective-C protocol
 * declaration.
 */
struct ProtocolDeclaration
{
    /// The interface declaration
    private InterfaceDeclaration interfaceDeclaration;

    this(InterfaceDeclaration interfaceDeclaration)
    in
    {
        assert(interfaceDeclaration !is null);
    }
    do
    {
        this.interfaceDeclaration = interfaceDeclaration;
    }

    /**
     * Outputs the protocol declaration to the object file.
     *
     * Returns: the exported symbol, that is, `__OBJC_PROTOCOL_$_`
     */
    Symbol* toObjFile()
    {
        const name = interfaceDeclaration.objc.identifier.toString();

        auto type = type_fake(TYnptr);
        type_setty(&type, type.Tty | mTYweakLinkage);

        void createLabel(Symbol* protocol)
        {
            enum prefix = "__OBJC_LABEL_PROTOCOL_$_";
            auto symbolName = prefix ~ name;

            auto symbol = Symbols.getGlobal(symbolName, type);
            symbol.Sseg = Segments[Segments.Id.protolist];
            symbol.Sclass = SCcomdat;
            symbol.Sflags |= SFLhidden;
            symbol.Salignment = 3;

            auto dtb = DtBuilder(0);
            dtb.xoff(protocol, 0);
            symbol.Sdt = dtb.finish();
            outdata(symbol);
        }

        enum prefix = "__OBJC_PROTOCOL_$_";
        auto symbolName = prefix ~ name;

        auto symbol = Symbols.getGlobal(symbolName, type);
        symbol.Sseg = Segments[Segments.Id.data];
        symbol.Sclass = SCcomdat;
        symbol.Sflags |= SFLhidden;
        symbol.Salignment = 3;

        auto dtb = DtBuilder(0);
        toDt(dtb);
        symbol.Sdt = dtb.finish();
        outdata(symbol);

        createLabel(symbol);

        return symbol;
    }

private:

    /**
     * Outputs the protocols declaration to the object file.
     *
     * Params:
     *  dtb = the `DtBuilder` to output the protocol declaration to
     */
    void toDt(ref DtBuilder dtb)
    {
        dtb.size(0); // isa, always null
        dtb.xoff(Symbols.getClassNameRo(interfaceDeclaration.ident), 0); // name
        dtb.xoffOrNull(protocolList); // protocols

        dtb.xoffOrNull(instanceMethodList); // instance methods
        dtb.xoffOrNull(classMethodList); // class methods
        dtb.xoffOrNull(optionalInstanceMethodList); // optional instance methods
        dtb.xoffOrNull(optionalClassMethodList); // optional class methods

        dtb.size(0); // instance properties
        dtb.dword(96); // the size of _protocol_t, always 96
        dtb.dword(0); // flags, seems to always be 0

        dtb.xoffOrNull(getMethodTypes); // extended method types

        dtb.size(0); // demangled name. Used by Swift, unused by Objective-C
        dtb.size(0); // class properties
    }

    /**
     * Returns instance method list for this protocol declaration.
     *
     * This is a list of all instance methods declared in this protocol
     * declaration.
     *
     * Returns: the symbol for the method list, `__OBJC_$_PROTOCOL_INSTANCE_METHODS_`
     */
    Symbol* instanceMethodList()
    {
        enum symbolNamePrefix = "__OBJC_$_PROTOCOL_INSTANCE_METHODS_";
        auto methods = interfaceDeclaration
            .objc
            .methodList
            .filter!(m => !m.objc.isOptional);

        return methodList(symbolNamePrefix, methods);
    }

    /**
     * Returns class method list for this protocol declaration.
     *
     * This is a list of all class methods declared in this protocol
     * declaration.
     *
     * Returns: the symbol for the method list, `__OBJC_$_PROTOCOL_CLASS_METHODS_`
     */
    Symbol* classMethodList()
    {
        enum symbolNamePrefix = "__OBJC_$_PROTOCOL_CLASS_METHODS_";
        auto methods = interfaceDeclaration
            .objc
            .metaclass
            .objc
            .methodList
            .filter!(m => !m.objc.isOptional);

        return methodList(symbolNamePrefix, methods);
    }

    /**
     * Returns optional instance method list for this protocol declaration.
     *
     * This is a list of all optional instance methods declared in this protocol
     * declaration.
     *
     * Returns: the symbol for the method list, `l_OBJC_$_PROTOCOL_INSTANCE_METHODS_`
     */
    Symbol* optionalInstanceMethodList()
    {
        enum symbolNamePrefix = "l_OBJC_$_PROTOCOL_INSTANCE_METHODS_OPT_";

        auto methods = interfaceDeclaration
            .objc
            .methodList
            .filter!(m => m.objc.isOptional);

        return methodList(symbolNamePrefix, methods);
    }

    /**
     * Returns optional class method list for this protocol declaration.
     *
     * This is a list of all optional class methods declared in this protocol
     * declaration.
     *
     * Returns: the symbol for the method list, `l_OBJC_$_PROTOCOL_INSTANCE_METHODS_`
     */
    Symbol* optionalClassMethodList()
    {
        enum symbolNamePrefix = "l_OBJC_$_PROTOCOL_CLASS_METHODS_OPT_";
        auto methods = interfaceDeclaration
            .objc
            .metaclass
            .objc
            .methodList
            .filter!(m => m.objc.isOptional);

        return methodList(symbolNamePrefix, methods);
    }

    /**
     * Returns a method list for this protocol declaration.
     *
     * Returns: the symbol for the method list
     */
    Symbol* methodList(Range)(string symbolNamePrefix, Range methods)
    if (isInputRange!Range && is(ElementType!Range == FuncDeclaration))
    {
        const methodCount = methods.walkLength;

        if (methodCount == 0)
            return null;

        auto dtb = DtBuilder(0);

        dtb.dword(24); // _objc_method.sizeof
        dtb.dword(cast(int) methodCount); // method count

        foreach (func; methods)
        {
            dtb.xoff(func.objc.selector.toNameSymbol(), 0); // method name
            dtb.xoff(Symbols.getMethVarType(func), 0); // method type string
            dtb.size(0); // NULL, protocol methods have no implementation
        }

        const symbolName = symbolNamePrefix ~ interfaceDeclaration.objc.identifier.toString();
        auto symbol = Symbols.getStatic(symbolName);

        symbol.Sdt = dtb.finish();
        symbol.Sseg = Segments[Segments.Id.const_];
        symbol.Salignment = 3;

        return symbol;
    }

    /**
     * Returns a list of type encodings for this protocol declaration.
     *
     * This is a list of all the type encodings for all methods declared in this
     * protocol declaration.
     *
     * Returns: the symbol for the type encodings, `__OBJC_$_PROTOCOL_METHOD_TYPES_`
     */
    Symbol* getMethodTypes()
    {
        if (interfaceDeclaration.objc.methodList.length == 0)
            return null;

        auto dtb = DtBuilder(0);

        auto varTypeSymbols = interfaceDeclaration
            .objc
            .methodList
            .map!(Symbols.getMethVarType);

        foreach (symbol; varTypeSymbols)
            dtb.xoff(symbol, 0); // method type string

        enum prefix = "__OBJC_$_PROTOCOL_METHOD_TYPES_";
        const symbolName = prefix ~ interfaceDeclaration.objc.identifier.toString();
        auto symbol = Symbols.getStatic(symbolName);

        symbol.Sdt = dtb.finish();
        symbol.Sseg = Segments[Segments.Id.const_];
        symbol.Salignment = 3;

        outdata(symbol);

        return symbol;
    }

    /// Returns: the symbol for the protocol references,  `__OBJC_$_PROTOCOL_REFS_`
    Symbol* protocolList()
    {
        auto interfaces = interfaceDeclaration.interfaces;

        if (interfaces.length == 0)
            return null;

        auto dtb = DtBuilder(0);

        dtb.size(interfaces.length); // number of protocols in the list

        auto symbols = interfaces
            .map!(i => cast(InterfaceDeclaration) i.sym)
            .map!(Symbols.getProtocolSymbol);

        foreach (s; symbols)
            dtb.xoff(s, 0); // pointer to protocol declaration

        dtb.size(0); // null-terminate the list

        const prefix = "__OBJC_$_PROTOCOL_REFS_";
        const symbolName = prefix ~ interfaceDeclaration.objc.identifier.toString();
        auto symbol = Symbols.getStatic(symbolName);

        symbol.Sdt = dtb.finish();
        symbol.Sseg = Segments[Segments.Id.const_];
        symbol.Salignment = 3;

        outdata(symbol);

        return symbol;
    }
}

private:

/*
 * Formats the given arguments into the given buffer.
 *
 * Convenience wrapper around `snprintf`.
 *
 * Params:
 *  bufLength = length of the buffer
 *  buffer = the buffer where to store the result
 *  format = the format string
 *  args = the arguments to format
 *
 * Returns: the formatted result, a slice of the given buffer
 */
char[] format(size_t bufLength, Args...)(return ref char[bufLength] buffer,
    const(char)* format, const Args args)
{
    auto length = snprintf(buffer.ptr, buffer.length, format, args);

    assert(length >= 0, "An output error occurred");
    assert(length < buffer.length, "Output was truncated");

    return buffer[0 .. length];
}

/// Returns: the symbol of the given selector
Symbol* toNameSymbol(const ObjcSelector* selector)
{
    return Symbols.getMethVarName(selector.toString());
}

/**
 * Adds a reference to the given `symbol` or null if the symbol is null.
 *
 * Params:
 *  dtb = the dt builder to add the symbol to
 *  symbol = the symbol to add
 */
void xoffOrNull(ref DtBuilder dtb, Symbol* symbol)
{
    if (symbol)
        dtb.xoff(symbol, 0);
    else
        dtb.size(0);
}

/**
 * Converts the given D string to a null terminated C string.
 *
 * Asserts if `str` is longer than `maxLength`, with assertions enabled. With
 * assertions disabled it will truncate the result to `maxLength`.
 *
 * Params:
 *  maxLength = the max length of `str`
 *  str = the string to convert
 *  buf = the buffer where to allocate the result. By default this will be
 *      allocated in the caller scope using `alloca`. If the buffer is created
 *      by the callee it needs to be able to fit at least `str.length + 1` bytes
 *
 * Returns: the given string converted to a C string, a slice of `str` or the
 *  given buffer `buffer`
 */
const(char)* toStringz(size_t maxLength = 4095)(in const(char)[] str,
    scope return void[] buffer = alloca(maxLength + 1)[0 .. maxLength + 1]) pure
in
{
    assert(maxLength >= str.length);
}
out(result)
{
    assert(str.length == result.strlen);
}
do
{
    if (str.length == 0)
        return "".ptr;

    const maxLength = buffer.length - 1;
    const len = str.length > maxLength ? maxLength : str.length;
    auto buf = cast(char[]) buffer[0 .. len + 1];
    buf[0 .. len] = str[0 .. len];
    buf[len] = '\0';

    return cast(const(char)*) buf.ptr;
}
