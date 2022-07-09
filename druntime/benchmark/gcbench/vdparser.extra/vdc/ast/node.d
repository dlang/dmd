// This file is part of Visual D
//
// Visual D integrates the D programming language into Visual Studio
// Copyright (c) 2010-2011 by Rainer Schuetze, All Rights Reserved
//
// Distributed under the Boost Software License, Version 1.0.
// See accompanying file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt

module vdc.ast.node;

import vdc.util;
import vdc.semantic;
import vdc.lexer;
import vdc.ast.expr;
import vdc.ast.type;
import vdc.ast.mod;
import vdc.ast.tmpl;
import vdc.ast.decl;
import vdc.ast.misc;
import vdc.ast.writer;
import vdc.logger;
import vdc.interpret;

import std.exception;
import std.stdio;
import std.string;
import std.conv;
import std.algorithm;

import stdext.util;

//version = COUNT;
//version = NODE_ALLOC;

version(COUNT) import visuald.windows;

version(NODE_ALLOC)
class NodeAllocData
{
    enum kSize = 0x4000;
    byte* pos;

    private byte** data;
    private int    numdata;

    byte* base() { return data[numdata-1]; }

    void moreData()
    {
        byte* arr = cast(byte*) gc_calloc(kSize, 0);
        // when appending to the array, ensure that no old reference is dangling
        byte** ndata = cast(byte**) gc_malloc((numdata + 1) * data[0].sizeof, 0);
        ndata[0..numdata] = data[0..numdata];
        data[0..numdata] = null;
        ndata[numdata] = arr;
        gc_free(data);
        data = ndata;
        numdata++;
        pos = arr;
    }

    ~this()
    {
        destroy(false); // must not call back into GC
    }

    void destroy(bool free)
    {
        while(numdata > 0)
        {
            size_t sz;
            byte* beg = data[--numdata];
            byte* end = beg + kSize;
            for(byte* p = beg; p < end && *cast(size_t*)p != 0; p += sz)
            {
                Node n = cast(Node) p;
                sz = typeid(n).initializer.length;
                sz = (sz + 15) & ~15;
                assert(sz > 0);
                clear(n); // calls rt_finalize
            }
            if(free)
                gc_free(beg);
            data[numdata] = null;
        }
        if(data && free)
            gc_free(data);
        data = null;
        pos = null;
    }

    static NodeAllocData current;

    static NodeAllocData detachCurrent()
    {
        auto cur = current;
        current = null;
        return cur;
    }

    static void checkAlloc(size_t sz)
    {
        if(!current)
            current = new NodeAllocData;
        if(!current.pos)
            current.moreData();
        if(current.pos + sz > current.base() + kSize)
            current.moreData();
    }

    static void* alloc(size_t sz)
    {
        sz = (sz + 15) & ~15;
        checkAlloc(sz);
        void* p = current.pos;
        current.pos += sz;
        //if(current.pos < current.base() + kSize)
        //    *cast(size_t*)current.pos = 0;
        return p;
    }
}

// moved out of Node due to regression http://d.puremagic.com/issues/show_bug.cgi?id=9101
mixin template ForwardCtor()
{
    this()
    {
        // default constructor needed for clone()
    }
    this(ref const(TextSpan) _span)
    {
        super(_span);
    }
    this(Token tok)
    {
        super(tok);
    }
    this(TokenId _id, ref const(TextSpan) _span)
    {
        super(_id, _span);
    }
}

mixin template ForwardCtorTok()
{
    this() {} // default constructor needed for clone()

    this(Token tok)
    {
        super(tok);
    }
}

mixin template ForwardCtorNoId()
{
    this() {} // default constructor needed for clone()

    this(ref const(TextSpan) _span)
    {
        super(_span);
    }
    this(Token tok)
    {
        super(tok.span);
    }
}

class Node
{
    TokenId id;
    Attribute attr;
    Annotation annotation;
    TextSpan span; // file extracted from parent module
    TextSpan fulspan;

    Node parent;
    Node[] members;

    // semantic data
    int semanticSearches;
    Scope scop;

    version(COUNT) static __gshared int countNodes;

    this()
    {
        version(COUNT) InterlockedIncrement(&countNodes);
        // default constructor needed for clone()
    }

    this(ref const(TextSpan) _span)
    {
        version(COUNT) InterlockedIncrement(&countNodes);
        fulspan = span = _span;
    }
    this(Token tok)
    {
        version(COUNT) InterlockedIncrement(&countNodes);
        id = tok.id;
        span = tok.span;
        fulspan = tok.span;
    }
    this(TokenId _id, ref const(TextSpan) _span)
    {
        version(COUNT) InterlockedIncrement(&countNodes);
        id = _id;
        fulspan = span = _span;
    }

    version(COUNT) ~this()
    {
        version(COUNT) InterlockedDecrement(&countNodes);
    }

    void reinit()
    {
        id = 0;
        attr = 0;
        annotation = 0;
        members.length = 0;
        clearSpan();
    }

    final Node _cloneShallow()
    {
        Node    n = static_cast!Node(typeid(this).create());

        n.id = id;
        n.attr = attr;
        n.annotation = annotation;
        n.span = span;
        n.fulspan = fulspan;

        return n;
    }

    Node clone()
    {
        Node n = _cloneShallow();
        foreach(m; members)
            n.addMember(m.clone());
        return n;
    }

    bool compare(const(Node) n) const
    {
        if (typeid(this) !is typeid(n))
            return false;

        if(n.id != id || n.attr != attr || n.annotation != annotation)
            return false;
        // ignore span

        if(members.length != n.members.length)
            return false;

        for(int m = 0; m < members.length; m++)
            if(!members[m].compare(n.members[m]))
                return false;

        return true;
    }

    ////////////////////////////////////////////////////////////
    Node visit(DG)(DG dg)
    {
        if(!dg(this))
            return this;
        for(int m = 0; m < members.length; m++)
            if(auto n = members[m].visit(dg))
                return n;
        return null;
    }

    bool detachFromModule(Module mod)
    {
        return true;
    }

    void disconnect()
    {
        for(int m = 0; m < members.length; m++)
            members[m].disconnect();

        for(int m = 0; m < members.length; m++)
            members[m].parent = null;
        members = members.init;
    }

    void free()
    {
        for(int m = 0; m < members.length; m++)
            members[m].free();

        for(int m = 0; m < members.length; m++)
            members[m].parent = null;

        import core.memory;

        for(int m = 0; m < members.length; m++)
            GC.free(cast(void*) (members[m]));

        GC.free(cast(void*) (members.ptr));
        members = members.init;
    }

    ////////////////////////////////////////////////////////////
    abstract void toD(CodeWriter writer)
    {
        writer(typeid(this).name);
        writer.nl();

        auto indent = CodeIndenter(writer);
        foreach(c; members)
            writer(c);
    }

    void toC(CodeWriter writer)
    {
        toD(writer);
    }

    ////////////////////////////////////////////////////////////
    static string genCheckState(string state)
    {
        return "
            if(" ~ state ~ "!= 0)
                return;
            " ~ state ~ " = 1;
            scope(exit) " ~ state ~ " = 2;
        ";
    }

    enum SemanticState
    {
        None,
        ExpandingNonScopeMembers,
        ExpandedNonScopeMembers,
        AddingSymbols,
        AddedSymbols,
        ResolvingSymbols,
        ResolvedSymbols,
        SemanticDone,
    }
    int semanticState;

    void expandNonScopeSimple(Scope sc, size_t i, size_t j)
    {
        Node[1] narray;
        for(size_t m = i; m < j; )
        {
            Node n = members[m];
            narray[0] = n;
            size_t mlen = members.length;
            Node[] nm = n.expandNonScopeBlock(sc, narray);
            assert(members.length == mlen);
            if(nm.length == 1 && nm[0] == n)
            {
                n.addSymbols(sc);
                assert(members.length == mlen);
                m++;
            }
            else
            {
                replaceMember(m, nm);
                assert(members.length == mlen + nm.length - 1);
                j += nm.length - 1;
            }
        }
    }

    void expandNonScopeBlocks(Scope sc)
    {
        if(semanticState >= SemanticState.ExpandingNonScopeMembers)
            return;

        // simple expansions
        semanticState = SemanticState.ExpandingNonScopeMembers;
        expandNonScopeSimple(sc, 0, members.length);

        // expansions with interpretation
        Node[1] narray;
        for(int m = 0; m < members.length; )
        {
            Node n = members[m];
            narray[0] = n;
            Node[] nm = n.expandNonScopeInterpret(sc, narray);
            if(nm.length == 1 && nm[0] == n)
                m++;
            else
            {
                replaceMember(m, nm);
                expandNonScopeSimple(sc, m, m + nm.length);
            }
        }
        semanticState = SemanticState.ExpandedNonScopeMembers;
    }

    Node[] expandNonScopeBlock(Scope sc, Node[] athis)
    {
        return athis;
    }

    Node[] expandNonScopeInterpret(Scope sc, Node[] athis)
    {
        return athis;
    }

    void addMemberSymbols(Scope sc)
    {
        if(semanticState >= SemanticState.AddingSymbols)
            return;

        scop = sc;
        expandNonScopeBlocks(scop);

        semanticState = SemanticState.AddedSymbols;
    }

    void addSymbols(Scope sc)
    {
    }

    bool createsScope() const { return false; }

    Scope enterScope(ref Scope nscope, Scope sc)
    {
        if(!nscope)
        {
            nscope = sc.pushClone();
            nscope.node = this;
            addMemberSymbols(nscope);
            return nscope;
        }
        return sc.push(nscope);
    }
    Scope enterScope(Scope sc)
    {
        return enterScope(scop, sc);
    }

    final void semantic(Scope sc)
    {
        assert(sc);

        if(semanticState < SemanticState.SemanticDone)
        {
            logInfo("Scope(%s):semantic(%s=%s)", cast(void*)sc, this, cast(void*)this);
            LogIndent indent = LogIndent(1);

            _semantic(sc);
            semanticState = SemanticState.SemanticDone;
        }
    }

    void _semantic(Scope sc)
    {
//        throw new SemanticException(text(this, ".semantic not implemented"));
        foreach(m; members)
            m.semantic(sc);
    }

    Scope getScope()
    {
        if(scop)
            return scop;
        if(parent)
        {
            Scope sc = parent.getScope();
            assert(sc);
            if(sc && createsScope())
                sc = enterScope(sc);
            return sc;
        }
        return null;
    }

    Node resolve()
    {
        return null;
    }

    Type calcType()
    {
        return semanticErrorType(this, ".calcType not implemented");
    }

    Value interpret(Context sc)
    {
        return semanticErrorValue(this, ".interpret not implemented");
    }

    Value interpretCatch(Context sc)
    {
        try
        {
            return interpret(sc);
        }
        catch(InterpretException)
        {
        }
        return semanticErrorValue(this, ": interpretation stopped");
    }

    ParameterList getParameterList()
    {
        return null;
    }
    ArgumentList getFunctionArguments()
    {
        return null;
    }

    bool isTemplate()
    {
        return false;
    }
    Node expandTemplate(Scope sc, TemplateArgumentList args)
    {
        return this;
    }

    ////////////////////////////////////////////////////////////
    version(COUNT) {} else // invariant does not work with destructor
    invariant()
    {
        if(!__ctfe)
        foreach(m; members)
            assert(m.parent is this);
    }

    void addMember(Node m)
    {
        assert(m.parent is null);
        members ~= m;
        m.parent = this;
        extendSpan(m.fulspan);
    }

    Node removeMember(Node m)
    {
        auto n = std.algorithm.countUntil(members, m);
        assert(n >= 0);
        return removeMember(n);
    }

    Node removeMember(size_t m)
    {
        Node n = members[m];
        removeMember(m, 1);
        return n;
    }

    void removeMember(size_t m, size_t cnt)
    {
        assert(m >= 0 && m + cnt <= members.length);
        for (size_t i = 0; i < cnt; i++)
            members[m + i].parent = null;

        for (size_t n = m + cnt; n < members.length; n++)
            members[n - cnt] = members[n];
        members.length = members.length - cnt;
    }

    Node[] removeAll()
    {
        for (size_t m = 0; m < members.length; m++)
            members[m].parent = null;
        Node[] nm = members;
        members = members.init;
        return nm;
    }

    void replaceMember(Node m, Node[] nm)
    {
        auto n = std.algorithm.countUntil(members, m);
        assert(n >= 0);
        replaceMember(n, nm);
    }

    void replaceMember(size_t m, Node[] nm)
    {
        if(m < members.length)
            members[m].parent = null;
        if(nm.length == 1 && m < members.length)
            members[m] = nm[0];
        else
            members = members[0..m] ~ nm ~ members[m+1..$];
        foreach(n; nm)
            n.parent = this;
    }

    T getMember(T = Node)(size_t idx)
    {
        if (idx < 0 || idx >= members.length)
            return null;
        return static_cast!T(members[idx]);
    }

    Module getModule()
    {
        Node n = this;
        while(n)
        {
            if(n.scop)
                return n.scop.mod;
            n = n.parent;
        }
        return null;
    }
    string getModuleFilename()
    {
        Module mod = getModule();
        if(!mod)
            return null;
        return mod.filename;
    }

    void semanticError(T...)(T args)
    {
        semanticErrorLoc(getModuleFilename(), span.start, args);
    }

    ErrorValue semanticErrorValue(T...)(T args)
    {
        semanticErrorLoc(getModuleFilename(), span.start, args);
        return Singleton!(ErrorValue).get();
    }

    ErrorType semanticErrorType(T...)(T args)
    {
        semanticErrorLoc(getModuleFilename(), span.start, args);
        return Singleton!(ErrorType).get();
    }

    ////////////////////////////////////////////////////////////
    void extendSpan(ref const(TextSpan) _span)
    {
        if(_span.start < fulspan.start)
            fulspan.start = _span.start;
        if(_span.end > fulspan.end)
            fulspan.end = _span.end;
    }
    void limitSpan(ref const(TextSpan) _span)
    {
        if(_span.start > fulspan.start)
            fulspan.start = _span.start;
        if(_span.end < fulspan.end)
            fulspan.end = _span.end;
    }
    void clearSpan()
    {
        span.end.line = span.start.line;
        span.end.index = span.start.index;
        fulspan = span;
    }
}

class ParseRecoverNode : Node
{
    mixin ForwardCtor!();

    override void toD(CodeWriter writer)
    {
        string start = to!string(fulspan.start.line) ~ "," ~ to!string(fulspan.start.index);
        string end   = to!string(fulspan.end.line) ~ "," ~ to!string(fulspan.end.index);
        writer("/+ syntax error: span = ", start, " - ", end, " +/");
        writer.nl();
    }

    override void _semantic(Scope sc)
    {
    }
}

interface CallableNode
{
    Value interpretCall(Context sc);

    ParameterList getParameterList();
    FunctionBody getFunctionBody();
}

TextPos minimumTextPos(Node node)
{
    version(all)
        return node.fulspan.start;
    else
    {
        TextPos start = node.span.start;
        while(node.members.length > 0)
        {
            if(compareTextSpanAddress(node.members[0].span.start.line, node.members[0].span.start.index,
                                      start.line, start.index) < 0)
                start = node.members[0].span.start;
            node = node.members[0];
        }
        return start;
    }
}

TextPos maximumTextPos(Node node)
{
    version(all)
        return node.fulspan.end;
    else
    {
        TextPos end = node.span.end;
        while(node.members.length > 0)
        {
            if(compareTextSpanAddress(node.members[$-1].span.end.line, node.members[$-1].span.start.index,
                                      end.line, end.index) > 0)
                end = node.members[$-1].span.end;
            node = node.members[$-1];
        }
        return end;
    }
}

// prefer start
bool nodeContains(Node node, in TextPos pos)
{
    TextPos start = minimumTextPos(node);
    if(start > pos)
        return false;
    TextPos end = maximumTextPos(node);
    if(end <= pos)
        return false;
    return true;
}

bool nodeContains(Node node, in TextSpan* span)
{
    TextPos start = minimumTextPos(node);
    if(start > span.start)
        return false;
    TextPos end = maximumTextPos(node);
    if(end < span.end)
        return false;
    return true;
}

// prefer end
bool nodeContainsEnd(Node node, in TextPos* pos)
{
    TextPos start = minimumTextPos(node);
    if(start >= *pos)
        return false;
    TextPos end = maximumTextPos(node);
    if(end < *pos)
        return false;
    return true;
}

// figure out whether the given range is between the children of a binary expression
bool isBinaryOperator(Node root, int startLine, int startIndex, int endLine, int endIndex)
{
    TextPos pos = TextPos(startIndex, startLine);
    if(!nodeContains(root, pos))
        return false;

L_loop:
    if(root.members.length == 2)
    {
        if(cast(BinaryExpression) root)
            if(maximumTextPos(root.members[0]) <= pos && minimumTextPos(root.members[1]) > pos)
                return true;
    }

    foreach(m; root.members)
        if(nodeContains(m, pos))
        {
            root = m;
            goto L_loop;
        }

    return false;
}

Node getTextPosNode(Node root, in TextSpan* span, bool *inDotExpr)
{
    if(!nodeContains(root, span))
        return null;

L_loop:
    foreach(m; root.members)
        if(nodeContains(m, span))
        {
            root = m;
            goto L_loop;
        }

    if(inDotExpr)
        *inDotExpr = false;

    if(auto dotexpr = cast(DotExpression)root)
    {
        if(inDotExpr)
        {
            root = dotexpr.getExpression();
            *inDotExpr = true;
        }
    }
    else if(auto id = cast(Identifier)root)
    {
        if(auto dotexpr = cast(DotExpression)id.parent)
        {
            if(dotexpr.getIdentifier() == id)
            {
                if(inDotExpr)
                {
                    root = dotexpr.getExpression();
                    *inDotExpr = true;
                }
                else
                    root = dotexpr;
            }
        }
    }
    return root;
}
