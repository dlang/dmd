// This file is part of Visual D
//
// Visual D integrates the D programming language into Visual Studio
// Copyright (c) 2010-2011 by Rainer Schuetze, All Rights Reserved
//
// Distributed under the Boost Software License, Version 1.0.
// See accompanying file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt

module vdc.ast.writer;

import vdc.lexer;
import vdc.util;
import vdc.parser.expr;
import vdc.parser.decl;
import vdc.parser.stmt;
import vdc.parser.aggr;
import vdc.parser.misc;
import vdc.parser.mod;
import ast = vdc.ast.all;

import std.stdio;
import std.array;

////////////////////////////////////////////////////////////////
void delegate(string s) getStringSink(ref string s)
{
    void stringSink(string txt)
    {
        s ~= txt;
    }
    return &stringSink;
}

void delegate(string s) getConsoleSink()
{
    void consoleSink(string txt)
    {
        write(txt);
    }
    return &consoleSink;
}

class CodeWriter
{
    alias void delegate(string s) Sink;

    Sink sink;

    bool writeDeclarations    = true;
    bool writeImplementations = true;
    bool writeClassImplementations = true;
    bool writeReferencedOnly  = false;
    bool newline;
    bool lastLineEmpty;

    string indentation;

    this(Sink snk)
    {
        sink = snk;
    }

    abstract void writeNode(ast.Node node);

    void write(T...)(T args)
    {
        if(newline)
        {
            sink(indentation);
            newline = false;
        }
        foreach(t; args)
            static if(is(typeof(t) : ast.Node))
                writeNode(t);
            else static if(is(typeof(t) : int))
                writeKeyword(t);
            else
                sink(t);
    }

    void opCall(T...)(T args)
    {
        write(args);
    }

    void indent(int n)
    {
        if(n > 0)
            indentation ~= replicate("  ", n);
        else
            indentation = indentation[0..$+n*2];
    }

    void writeArray(T)(T[] members, string sep = ", ", bool beforeFirst = false, bool afterLast = false)
    {
        bool writeSep = beforeFirst;
        foreach(m; members)
        {
            if(writeSep)
                write(sep);
            writeSep = true;
            write(m);
        }
        if(afterLast)
            write(sep);
    }

    @property void nl(bool force = true)
    {
        if(!lastLineEmpty)
            force = true;

        if(force)
        {
            sink("\n");
            lastLineEmpty = newline;
            newline = true;
        }
    }

    void writeKeyword(int id)
    {
        write(tokenString(id));
    }

    void writeIdentifier(string ident)
    {
        write(ident);
    }

    bool writeAttributes(Attribute attr, bool spaceBefore = false)
    {
        if(!attr)
            return false;
        while(attr)
        {
            Attribute a = attr & -attr;
            if(spaceBefore)
                write(" ");
            write(attrToString(a));
            if(!spaceBefore)
                write(" ");
            attr -= a;
        }
        return true;
    }

    bool writeAnnotations(Annotation annot, bool spaceBefore = false)
    {
        if(!annot)
            return false;
        while(annot)
        {
            Annotation a = annot & -annot;
            if(spaceBefore)
                write(" ");
            write(annotationToString(a));
            if(!spaceBefore)
                write(" ");
            annot -= a;
        }
        return true;
    }

    void writeAttributesAndAnnotations(Attribute attr, Annotation annot, bool spaceBefore = false)
    {
        writeAttributes(attr, spaceBefore);
        writeAnnotations(annot, spaceBefore);
    }
}

class DCodeWriter : CodeWriter
{
    this(Sink snk)
    {
        super(snk);
    }

    override void writeNode(ast.Node node)
    {
        node.toD(this);
    }
}

class CCodeWriter : CodeWriter
{
    this(Sink snk)
    {
        super(snk);
    }

    override void writeNode(ast.Node node)
    {
        node.toC(this);
    }

    override void writeKeyword(int id)
    {
        // Compiler-specific
        switch(id)
        {
            case TOK_long:  write("__int64"); break;
            case TOK_alias: write("typedef"); break;
            case TOK_in:    write("const"); break;
            default:
                write(tokenString(id));
        }
    }

    override void writeIdentifier(string ident)
    {
        // check whether it conflicts with a C++ keyword
        // Compiler-specific
        switch(ident)
        {
            case "__int64":
            case "__int32":
            case "__int16":
            case "__int8":
            case "unsigned":
            case "signed":
                write(ident, "__D");
                break;
            default:
                write(ident);
                break;
        }
    }

    override bool writeAttributes(Annotation attr, bool spaceBefore = false)
    {
        if(!attr)
            return false;
        while(attr)
        {
            Attribute a = attr & -attr;
            string cs = attrToStringC(a);
            if(cs.length > 0)
            {
                if(spaceBefore)
                    write(" ");
                write(cs);
                if(!spaceBefore)
                    write(" ");
            }
            attr -= a;
        }
        return true;
    }

    override bool writeAnnotations(Annotation annot, bool spaceBefore = false)
    {
        return true;
    }
}

struct CodeIndenter
{
    CodeWriter writer;
    int indent;

    this(CodeWriter _writer, int n = 1)
    {
        writer = _writer;
        indent = n;

        writer.indent(n);
    }
    ~this()
    {
        writer.indent(-indent);
    }
}

string writeD(ast.Node n)
{
    string txt;
    DCodeWriter writer = new DCodeWriter(getStringSink(txt));
    writer.writeImplementations = false;
    writer.writeClassImplementations = false;
    writer(n);
    return txt;
}

////////////////////////////////////////////////////////////////

version(all) {
    import vdc.parser.engine;

    void verifyParseWrite(string filename = __FILE__, int lno = __LINE__)(string txt)
    {
        Parser p = new Parser;
        p.filename = filename;
        ast.Node n = p.parseModule(txt);

        string ntxt;
        DCodeWriter writer = new DCodeWriter(getStringSink(ntxt));
        writer(n);

        ast.Node m = p.parseModule(ntxt);
        bool eq = n.compare(m);
        assert(eq);
    }

    ////////////////////////////////////////////////////////////////
}
