// This file is part of Visual D
//
// Visual D integrates the D programming language into Visual Studio
// Copyright (c) 2010-2011 by Rainer Schuetze, All Rights Reserved
//
// Distributed under the Boost Software License, Version 1.0.
// See accompanying file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt

module vdc.semantic;

import vdc.util;
import vdc.ast.mod;
import vdc.ast.node;
import vdc.ast.type;
import vdc.ast.aggr;
import vdc.ast.decl;
import vdc.ast.expr;
import vdc.ast.tmpl;
import vdc.ast.writer;
import vdc.parser.engine;
import vdc.logger;
import vdc.interpret;
import vdc.versions;

import stdext.util;
import stdext.array;
import stdext.path;

import std.exception;
import std.stdio;
import std.string;
import std.array;
import std.conv;
import std.datetime;

int semanticErrors;

alias object.AssociativeArray!(Node, const(bool)) _wa1; // fully instantiate type info for bool[Node]
alias object.AssociativeArray!(string, const(VersionInfo)) _wa2; // fully instantiate type info for VersionInfo[string]
alias object.AssociativeArray!(string, const(bool)) _wa3; // fully instantiate type info for bool[string]

class SemanticException : Exception
{
    this(string msg)
    {
        super(msg);
    }
}

class InterpretException : Exception
{
    this()
    {
        super("cannot interpret");
    }
}

enum MessageType
{
    Warning,
    Error,
    Message
}

void delegate(MessageType,string) fnSemanticWriteError = null;

string semanticErrorWriteLoc(string filename, ref const(TextPos) pos)
{
    string txt = filename;
    if(pos.line > 0)
        txt ~= text("(", pos.line, ")");
    txt ~= ": ";
    semanticErrors++;
    return txt;
}

void semanticErrorLoc(T...)(string filename, ref const(TextPos) pos, T args)
{
    foreach(a; args)
        if(typeid(a) == typeid(ErrorType) || typeid(a) == typeid(ErrorValue))
            return;

    string msg = semanticErrorWriteLoc(filename, pos);
    msg ~= text(args);
    if(fnSemanticWriteError)
        fnSemanticWriteError(MessageType.Error, msg);
    logInfo("%s", msg); // avoid interpreting % in message
}

void semanticErrorPos(T...)(ref const(TextPos) pos, T args)
{
    string filename;
    if(Scope.current && Scope.current.mod)
        filename = Scope.current.mod.filename;
    else
        filename = "at global scope";
    semanticErrorLoc(filename, pos, args);
}

void semanticError(T...)(T args)
{
    TextPos pos;
    semanticErrorPos(pos, args);
}

void semanticErrorFile(T...)(string fname, T args)
{
    TextPos pos;
    semanticErrorLoc(fname, pos, args);
}

void semanticMessage(string msg)
{
    if(fnSemanticWriteError)
        fnSemanticWriteError(MessageType.Message, msg);
}

ErrorValue semanticErrorValue(T...)(T args)
{
    TextPos pos;
    semanticErrorPos(pos, args);
    //throw new InterpretException;
    return Singleton!(ErrorValue).get();
}

ErrorType semanticErrorType(T...)(T args)
{
    semanticErrorPos(TextPos(), args);
    return Singleton!(ErrorType).get();
}

alias Node Symbol;

class Context
{
    Scope scop;
    Value[Node] vars;
    Context parent;

    this(Context p)
    {
        parent = p;
    }

    Value getThis()
    {
        if(parent)
            return parent.getThis();
        return null;
    }

    void setThis(Value v)
    {
        setValue(null, v);
    }

    Value getValue(Node n)
    {
        if(auto pn = n in vars)
            return *pn;
        if(parent)
            return parent.getValue(n);
        return null;
    }

    void setValue(Node n, Value v)
    {
        vars[n] = v;
    }
}

class AggrContext : Context
{
    Value instance;
    bool virtualCall;

    this(Context p, Value inst)
    {
        super(p);
        instance = inst;
        virtualCall = true;
    }

    override Value getThis()
    {
        if(auto t = cast(Class)instance.getType())
            return new ClassValue(t, static_cast!ClassInstanceValue (instance));
        return instance;
    }

    override Value getValue(Node n)
    {
        if(auto pn = n in vars)
            return *pn;
        if(auto decl = cast(Declarator) n)
            //if(Value v = instance._interpretProperty(this, decl.ident))
            if(Value v = instance.getType().getProperty(instance, decl, virtualCall))
                return v;
        if(parent)
            return parent.getValue(n);
        return null;
    }
}

class AssertContext : Context
{
    Value[Node] identVal;

    this(Context p)
    {
        super(p);
    }
}

Context nullContext;
AggrContext noThisContext;

Context globalContext;
Context threadContext;
Context errorContext;

class Scope
{
    Scope parent;

    Annotation annotations;
    Attribute attributes;
    Module mod;
    Node node;
    Set!Symbol[string] symbols;
    Import[] imports;

//    Context ctx; // compile time only

    static Scope current;

    this()
    {
        logInfo("Scope(%s) created, current=%s", cast(void*)this, cast(void*)current);
    }
    enum
    {
        SearchParentScope = 1,
        SearchPrivateImport = 2,
    }

    Scope pushClone()
    {
        Scope sc = new Scope;
        sc.annotations = annotations;
        sc.attributes = attributes;
        sc.mod = mod;
        sc.parent = this;
        return current = sc;
    }
    Scope push(Scope sc)
    {
        if(!sc)
            return pushClone();

        assert(this !is sc);
        sc.parent = this;
        return current = sc;
    }

    Scope pop()
    {
        return current = parent;
    }

    Type getThisType()
    {
        if(!parent)
            return null;
        return parent.getThisType();
    }

    void addSymbol(string ident, Symbol s)
    {
        logInfo("Scope(%s).addSymbol(%s, sym %s=%s)", cast(void*)this, ident, s, cast(void*)s);

        if(auto sym = ident in symbols)
            addunique(*sym, s);
        else
            symbols[ident] = Set!Symbol([s : true]);
    }

    void addImport(Import imp)
    {
        imports ~= imp;
    }

    struct SearchData { string ident; Scope sc; }
    static Stack!SearchData searchStack;

    alias Set!Symbol SearchSet;

    void searchCollect(string ident, ref SearchSet syms)
    {
        string iden = ident[0..$-1];
        foreach(id, sym; symbols)
            if(id.startsWith(iden))
                addunique(syms, sym);
    }

    void searchParents(string ident, bool inParents, bool privateImports, bool publicImports, ref SearchSet syms)
    {
        if(inParents && parent)
        {
            if(syms.length == 0)
                syms = parent.search(ident, true, privateImports, publicImports);
            else if(collectSymbols(ident))
                addunique(syms, parent.search(ident, true, privateImports, publicImports));
        }
    }

    static bool collectSymbols(string ident)
    {
        return ident.endsWith("*");
    }

    SearchSet search(string ident, bool inParents, bool privateImports, bool publicImports)
    {
        // check recursive search
        SearchData sd = SearchData(ident, this);
        for(int d = 0; d < searchStack.depth; d++)
            if(searchStack.stack[d] == sd) // memcmp
                return Scope.SearchSet();

        SearchSet syms;
        if(collectSymbols(ident))
            searchCollect(ident, syms);
        else if(auto pn = ident in symbols)
            return *pn;

        searchStack.push(sd);
        if(publicImports)
            foreach(imp; imports)
            {
                if(privateImports || (imp.getProtection() & Annotation_Public))
                    addunique(syms, imp.search(this, ident));
            }
        searchParents(ident, inParents, privateImports, publicImports, syms);
        searchStack.pop();
        return syms;
    }

    Scope.SearchSet matchFunctionArguments(Node id, Scope.SearchSet n)
    {
        Scope.SearchSet matches;
        ArgumentList fnargs = id.getFunctionArguments();
        int cntFunc = 0;
        foreach(s, b; n)
            if(s.getParameterList())
                cntFunc++;
        if(cntFunc != n.length)
            return matches;

        Node[] args;
        if(fnargs)
            args = fnargs.members;
        foreach(s, b; n)
        {
            auto pl = s.getParameterList();
            if(args.length > pl.members.length)
                continue;

            if(args.length < pl.members.length)
                // parameterlist must have default
                if(auto param = pl.getParameter(args.length))
                    if(!param.getInitializer())
                        continue;

            int a;
            for(a = 0; a < args.length; a++)
            {
                auto atype = args[a].calcType();
                auto ptype = pl.members[a].calcType();
                if(!ptype.convertableFrom(atype, Type.ConversionFlags.kImpliciteConversion))
                    break;
            }
            if(a < args.length)
                continue;
            matches[s] = true;
        }
        return matches;
    }

    Node resolveOverload(string ident, Node id, Scope.SearchSet n)
    {
        if(n.length == 0)
        {
            id.semanticError("unknown identifier " ~ ident);
            return null;
        }
        foreach(s, b; n)
            s.semanticSearches++;

        if(n.length > 1)
        {
            auto matches = matchFunctionArguments(id, n);
            if(matches.length == 1)
                return matches.first();
            else if(matches.length > 0)
                n = matches; // report only matching funcs

            id.semanticError("ambiguous identifier " ~ ident);
            foreach(s, b; n)
                s.semanticError("possible candidate");

            if(!collectSymbols(ident))
                return null;
        }
        return n.first();
    }

    Node resolve(string ident, Node id, bool inParents = true)
    {
        auto n = search(ident, inParents, true, true);
        logInfo("Scope(%s).search(%s) found %s %s", cast(void*)this, ident, n.keys(), n.length > 0 ? cast(void*)n.first() : null);

        return resolveOverload(ident, id, n);
    }

    Node resolveWithTemplate(string ident, Scope sc, Node id, bool inParents = true)
    {
        auto n = search(ident, inParents, true, true);
        logInfo("Scope(%s).search(%s) found %s %s", cast(void*)this, ident, n.keys(), n.length > 0 ? cast(void*)n.first() : null);

        auto resolved = resolveOverload(ident, id, n);
        if(resolved && resolved.isTemplate())
        {
            TemplateArgumentList args;
            if(auto tmplid = cast(TemplateInstance)id)
            {
                args = tmplid.getTemplateArgumentList();
            }
            else
            {
                args = new TemplateArgumentList; // no args
            }
            resolved = resolved.expandTemplate(sc, args);
        }
        return resolved;
    }

    Project getProject() { return mod ? mod.getProject() : null; }
}

struct ArgMatch
{
    Value value;
    string name;

    string toString() { return "{" ~ value.toStr() ~ "," ~ name ~ "}"; }
}

class SourceModule
{
    // filename already in Module
    SysTime lastModified;
    Options options;

    string txt;
    Module parsed;
    Module analyzed;

    Parser parser;
    ParseError[] parseErrors;

    bool parsing() { return parser !is null; }
}

version = no_syntaxcopy;
version = no_disconnect;
//version = free_ast;

class Project : Node
{
    Options options;
    int countErrors;
    bool saveErrors;

    Module mObjectModule; // object.d
    SourceModule[string] mSourcesByModName;
    SourceModule[string] mSourcesByFileName;

    this()
    {
        TextSpan initspan;
        super(initspan);
        options = new Options;

        version(none)
        {
        options.importDirs ~= r"c:\l\dmd-2.055\src\druntime\import\";
        options.importDirs ~= r"c:\l\dmd-2.055\src\phobos\";

        options.importDirs ~= r"c:\tmp\d\runnable\";
        options.importDirs ~= r"c:\tmp\d\runnable\imports\";

        options.importDirs ~= r"m:\s\d\rainers\dmd\test\";
        options.importDirs ~= r"m:\s\d\rainers\dmd\test\imports\";
        }

        globalContext = new Context(null);
        threadContext = new Context(null);
        errorContext = new Context(null);
    }

    Module addSource(string fname, Module mod, ParseError[] errors, Node importFrom = null)
    {
        mod.filename = fname;
        mod.imported = importFrom !is null;

        SourceModule src;
        string modname = mod.getModuleName();
        if(auto pm = modname in mSourcesByModName)
        {
            if(pm.parsed && pm.parsed.filename != fname)
            {
                semanticErrorFile(fname, "module name " ~ modname ~ " already used by " ~ pm.parsed.filename);
                countErrors++;
                //return null;
            }
            src = *pm;
        }
        else if(auto pm = fname in mSourcesByFileName)
            src = *pm;
        else
            src = new SourceModule;

        if(src.parsed)
        {
            version(no_disconnect) {} else
                src.parsed.disconnect();
            version(free_ast)
                src.parsed.free();
        }
        src.parsed = mod;
        src.parseErrors = errors;

        import std.file : exists, timeLastModified;

        if(exists(fname)) // could be pseudo name
            src.lastModified = timeLastModified(fname);

        if(src.analyzed)
        {
            removeMember(src.analyzed);
            version(disconnect) {} else
                src.analyzed.disconnect();
            version(free_ast)
                src.analyzed.free();
        }
        version(no_syntaxcopy) {} else
        {
            src.analyzed = mod.clone();
            addMember(src.analyzed);
        }
        src.options = options;
        if(importFrom)
            if(auto m = importFrom.getModule())
                src.options = m.getOptions();

        mSourcesByModName[modname] = src;
        mSourcesByFileName[fname] = src;
        version(no_syntaxcopy)
            return src.parsed;
        else
            return src.analyzed;
    }

    ////////////////////////////////////////////////////////////
    Module addText(string fname, string txt, Node importFrom = null)
    {
        SourceModule src;
        if(auto pm = fname in mSourcesByFileName)
            src = *pm;
        else
            src = new SourceModule;

        logInfo("parsing " ~ fname);

        Parser p = new Parser;
        p.saveErrors = saveErrors;
        src.parser = p;
        scope(exit) src.parser = null;

        p.filename = fname;
        Node n;
        try
        {
            semanticMessage(fname ~ ": parsing...");
            n = p.parseModule(txt);
        }
        catch(Exception e)
        {
            if(fnSemanticWriteError)
                fnSemanticWriteError(MessageType.Error, e.msg);
            countErrors += p.countErrors + 1;
            return null;
        }
        countErrors += p.countErrors;
        if(!n)
            return null;

        auto mod = static_cast!(Module)(n);
        return addSource(fname, mod, p.errors, importFrom);
    }

    Module addAndParseFile(string fname, Node importFrom = null)
    {
        //debug writeln(fname, ":");
        string txt = readUtf8(fname);
        return addText(fname, txt, importFrom);
    }

    bool addFile(string fname)
    {
        import std.file : exists, timeLastModified;
        auto src = new SourceModule;
        if(exists(fname)) // could be pseudo name
            src.lastModified = timeLastModified(fname);

        src.txt = readUtf8(fname);
        mSourcesByFileName[fname] = src;
        return true;
    }

    Module getModule(string modname)
    {
        if(auto pm = modname in mSourcesByModName)
            return pm.analyzed;
        return null;
    }

    SourceModule getModuleByFilename(string filename)
    {
        if(auto pm = filename in mSourcesByFileName)
            return *pm;
        return null;
    }

    Module importModule(string modname, Node importFrom)
    {
        if(auto mod = getModule(modname))
            return mod;

        string dfile = replace(modname, ".", "/") ~ ".di";
        string srcfile = searchImportFile(dfile, importFrom);
        if(srcfile.length == 0)
        {
            dfile = replace(modname, ".", "/") ~ ".d";
            srcfile = searchImportFile(dfile, importFrom);
        }
        if(srcfile.length == 0)
        {
            if (importFrom)
                importFrom.semanticError("cannot find imported module " ~ modname);
            else
                .semanticError("cannot find imported module " ~ modname);
            return null;
        }
        srcfile = normalizePath(srcfile);
        return addAndParseFile(srcfile, importFrom);
    }

    string searchImportFile(string dfile, Node importFrom)
    {
        import std.file : exists;
        if(exists(dfile))
            return dfile;

        Options opt = options;
        if(importFrom)
            if(auto mod = importFrom.getModule())
                opt = mod.getOptions();

        foreach(dir; opt.importDirs)
            if(exists(dir ~ dfile))
                return dir ~ dfile;
        return null;
    }

    void initScope()
    {
        getObjectModule(null);
        scop = new Scope;
    }

    Module getObjectModule(Module importFrom)
    {
        if(!mObjectModule)
            mObjectModule = importModule("object", importFrom);
        return mObjectModule;
    }

    // for error messages
    override string getModuleFilename()
    {
        return "<global scope>";
    }

    void semantic()
    {
        try
        {
            size_t cnt = members.length; // do not fully analyze imported modules
            initScope();

            for(size_t m = 0; m < cnt; m++)
                members[m].semantic(scop);
        }
        catch(InterpretException)
        {
            semanticError("unhandled interpret exception, semantic analysis aborted");
        }
    }
    ////////////////////////////////////////////////////////////
    void update()
    {
    }

    void disconnectAll()
    {
        foreach(s; mSourcesByFileName)
        {
            if(s.parsed)
                s.parsed.disconnect();
            if(s.analyzed)
                s.analyzed.disconnect();
        }
    }

    ////////////////////////////////////////////////////////////
    void writeCpp(string fname)
    {
        string src;
        CCodeWriter writer = new CCodeWriter(getStringSink(src));
        writer.writeDeclarations    = true;
        writer.writeImplementations = false;

        for(int m = 0; m < members.length; m++)
        {
            writer.writeReferencedOnly = getMember!Module(m).imported;
            writer(members[m]);
            writer.nl;
        }

        writer.writeDeclarations    = false;
        writer.writeImplementations = true;
        for(int m = 0; m < members.length; m++)
        {
            writer.writeReferencedOnly = getMember!Module(m).imported;
            writer(members[m]);
            writer.nl;
        }

        Node mainNode;
        for(int m = 0; m < members.length; m++)
            if(members[m].scop)
            {
                if(auto pn = "main" in members[m].scop.symbols)
                {
                    if(pn.length > 1 || mainNode)
                        semanticError("multiple candidates for main function");
                    else
                        mainNode = (*pn).first();
                }
            }
        if(mainNode)
        {
            writer("int main(int argc, char**argv)");
            writer.nl;
            writer("{");
            writer.nl;
            {
                CodeIndenter indent = CodeIndenter(writer);
                Module mod = mainNode.getModule();
                mod.writeNamespace(writer);
                writer("main();");
                writer.nl;
                writer("return 0;");
                writer.nl;
            }
            writer("}");
            writer.nl;
        }

        import std.file : write;
        write(fname, src);
    }

    override void toD(CodeWriter writer)
    {
        throw new SemanticException("Project.toD not implemeted");
    }

    int run()
    {
        Scope.SearchSet funcs;
        foreach(m; mSourcesByModName)
            addunique(funcs, m.analyzed.search("main"));
        if(funcs.length == 0)
        {
            semanticError("no function main");
            return -1;
        }
        if(funcs.length > 1)
        {
            semanticError("multiple functions main");
            return -2;
        }
        TupleValue args = new TupleValue;
        if(auto cn = cast(CallableNode)funcs.first())
            if(auto pl = cn.getParameterList())
                if(pl.members.length > 0)
                {
                    auto tda = new TypeDynamicArray;
                    tda.setNextType(getTypeString!char());
                    auto dav = new DynArrayValue(tda);
                    args.addValue(dav);
                }

        try
        {
            Value v = funcs.first().interpret(nullContext).opCall(nullContext, args);
            if(v is theVoidValue)
                return 0;
            return v.toInt();
        }
        catch(InterpretException)
        {
            semanticError("cannot run main, interpretation aborted");
            return -1;
        }
    }
}

struct VersionInfo
{
    TextPos defined;     // line -1 if not defined yet
    TextPos firstUsage;  // line int.max if not used yet
}

struct VersionDebug
{
    int level;
    VersionInfo[string] identifiers;

    bool reset(int lev, string[] ids)
    {
        if(lev == level && ids.length == identifiers.length)
        {
            bool different = false;
            foreach(id; ids)
                if(id !in identifiers)
                    different = true;
            if(!different)
                return false;
        }

        level = lev;
        identifiers = identifiers.init;
        foreach(id; ids)
            identifiers[id] = VersionInfo();

        return true;
    }

    bool preDefined(string ident) const
    {
        if(auto vi = ident in identifiers)
            return vi.defined.line >= 0;
        return false;
    }

    bool defined(string ident, TextPos pos)
    {
        if(auto vi = ident in identifiers)
        {
            if(pos < vi.defined)
                semanticErrorPos(pos, "identifier " ~ ident ~ " used before defined");

            if(pos < vi.firstUsage)
                vi.firstUsage = pos;

            return vi.defined.line >= 0;
        }
        VersionInfo vi;
        vi.defined.line = -1;
        vi.firstUsage = pos;
        identifiers[ident] = vi;
        return false;
    }

    void define(string ident, TextPos pos)
    {
        if(auto vi = ident in identifiers)
        {
            if(pos > vi.firstUsage)
                semanticErrorPos(pos, "identifier " ~ ident ~ " defined after usage");
            if(pos < vi.defined)
                vi.defined = pos;
        }

        VersionInfo vi;
        vi.firstUsage.line = int.max;
        vi.defined = pos;
        identifiers[ident] = vi;
    }
}

class Options
{
    string[] importDirs;
    string[] stringImportDirs;

    public /* debug & version handling */ {
    bool unittestOn;
    bool x64;
    bool debugOn;
    bool coverage;
    bool doDoc;
    bool noBoundsCheck;
    bool gdcCompiler;
    bool noDeprecated;
    bool mixinAnalysis;
    bool UFCSExpansions;
    VersionDebug debugIds;
    VersionDebug versionIds;

    int changeCount;

    bool setImportDirs(string[] dirs)
    {
        if(dirs == importDirs)
            return false;

        importDirs = dirs.dup;
        changeCount++;
        return true;
    }
    bool setStringImportDirs(string[] dirs)
    {
        if(dirs == stringImportDirs)
            return false;

        stringImportDirs = dirs.dup;
        changeCount++;
        return true;
    }
    bool setVersionIds(int level, string[] versionids)
    {
        if(!versionIds.reset(level, versionids))
            return false;
        changeCount++;
        return true;
    }
    bool setDebugIds(int level, string[] debugids)
    {
        if(!debugIds.reset(level, debugids))
            return false;
        changeCount++;
        return true;
    }

    bool versionEnabled(string ident)
    {
        int pre = versionPredefined(ident);
        if(pre == 0)
            return versionIds.defined(ident, TextPos());

        return pre > 0;
    }

    bool versionEnabled(int level)
    {
        return level <= versionIds.level;
    }

    bool debugEnabled(string ident)
    {
        return debugIds.defined(ident, TextPos());
    }

    bool debugEnabled(int level)
    {
        return level <= debugIds.level;
    }

    int versionPredefined(string ident)
    {
        int* p = ident in sPredefinedVersions;
        if(!p)
            return 0;
        if(*p)
            return *p;

        switch(ident)
        {
            case "unittest":
                return unittestOn ? 1 : -1;
            case "assert":
                return unittestOn || debugOn ? 1 : -1;
            case "D_Coverage":
                return coverage ? 1 : -1;
            case "D_Ddoc":
                return doDoc ? 1 : -1;
            case "D_NoBoundsChecks":
                return noBoundsCheck ? 1 : -1;
            case "CRuntime_DigitalMars":
            case "Win32":
            case "X86":
            case "D_InlineAsm_X86":
                return x64 ? -1 : 1;
            case "CRuntime_Microsoft":
            case "Win64":
            case "X86_64":
            case "D_InlineAsm_X86_64":
            case "D_LP64":
                return x64 ? 1 : -1;
            case "GNU":
                return gdcCompiler ? 1 : -1;
            case "DigitalMars":
                return gdcCompiler ? -1 : 1;
            default:
                assert(false, "inconsistent predefined versions");
        }
    }

    }
}
