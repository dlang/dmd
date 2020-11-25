
// This file is part of Visual D
//
// Visual D integrates the D programming language into Visual Studio
// Copyright (c) 2010-2011 by Rainer Schuetze, All Rights Reserved
//
// Distributed under the Boost Software License, Version 1.0.
// See accompanying file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt

module vdc.util;

import vdc.lexer;

import std.conv;
import std.string;
import std.array;

////////////////////////////////////////////////////////////////
// use instead of assert() to be nicely breakable and avoid the bad
// semantics of assert(false)
void _assert(bool cond)
{
    if(!cond)
        assert(false);
}

////////////////////////////////////////////////////////////////
alias int TokenId;
enum NumTokens = TOK_end_Operators;

struct TextPos
{
    int index;
    int line;

    int opCmp(ref const(TextPos) tp) const
    {
        if(line != tp.line)
            return line - tp.line;
        return index - tp.index;
    }
}

struct TextSpan
{
    TextPos start;
    TextPos end;
}

// returns < 0 if adr1 < adr2
int compareTextSpanAddress(int line1, int index1, int line2, int index2)
{
    int difflines = line1 - line2;
    if(difflines != 0)
        return difflines;
    return index1 - index2;
}

bool textSpanContains(ref const(TextSpan) span, int line, int index)
{
    return compareTextSpanAddress(span.start.line, span.start.index, line, index) <= 0
        && compareTextSpanAddress(span.end.line,   span.end.index,   line, index) > 0;
}


class Token
{
    TokenId id; // terminals and non-terminals
    string txt;
    TextSpan span;

    void copy(const(Token) tok)
    {
        id = tok.id;
        txt = tok.txt;
        span = tok.span;
    }
}

////////////////////////////////////////////////////////////////
string genFlagsEnum(string name, string prefix, string[] allMembers)
{
    string s = "enum " ~ name ~ " { ";
    foreach(i, c; allMembers)
        s ~= prefix ~ c ~ " = 1 << " ~ to!string(i) ~ ", ";
    s ~= "}";
    return s;
}

// Attribute also used for storage class
enum AttrBits
{
    Extern,
    Synchronized,
    Static,
    Final,
    Abstract,
    Const,
    Auto,
    Scope,
    Ref,
    Volatile,
    Gshared,
    Thread,
    Shared,
    Immutable,
    Pure,
    Nothrow,
    Inout,
    ExternC,
    ExternCPP,
    ExternD,
    ExternWindows,
    ExternSystem,
    Export,
    Align,
    Align1,
    Align2,
    Align4,
    Align8,
    Align16,
}

mixin(genFlagsEnum("", "Attr_", [__traits(allMembers,AttrBits)]));

enum Attr_AlignMask  = Attr_Align | Attr_Align1 | Attr_Align2 | Attr_Align4 | Attr_Align8 | Attr_Align16;
enum Attr_CallMask   = Attr_ExternC | Attr_ExternCPP | Attr_ExternD | Attr_ExternWindows | Attr_ExternSystem;
enum Attr_ShareMask  = Attr_Shared | Attr_Gshared | Attr_Thread;

alias uint Attribute;

Attribute tokenToAttribute(TokenId tok)
{
    switch(tok)
    {
        case TOK_extern:       return Attr_Extern;
        case TOK_synchronized: return Attr_Synchronized;
        case TOK_static:       return Attr_Static;
        case TOK_final:        return Attr_Final;
        case TOK_abstract:     return Attr_Abstract;
        case TOK_const:        return Attr_Const;
        case TOK_auto:         return Attr_Auto;
        case TOK_scope:        return Attr_Scope;
        case TOK_ref:          return Attr_Ref;
        case TOK_volatile:     return Attr_Volatile;
        case TOK___gshared:    return Attr_Gshared;
        case TOK___thread:     return Attr_Thread;
        case TOK_shared:       return Attr_Shared;
        case TOK_immutable:    return Attr_Immutable;
        case TOK_pure:         return Attr_Pure;
        case TOK_nothrow:      return Attr_Nothrow;
        case TOK_inout:        return Attr_Inout;
        case TOK_export:       return Attr_Export;
        case TOK_align:        return Attr_Align;
        default: return 0;
    }
}

TokenId attributeToToken(Attribute attr)
{
    switch(attr)
    {
        case Attr_Extern:       return TOK_extern;
        case Attr_Synchronized: return TOK_synchronized;
        case Attr_Static:       return TOK_static;
        case Attr_Final:        return TOK_final;
        case Attr_Abstract:     return TOK_abstract;
        case Attr_Const:        return TOK_const;
        case Attr_Auto:         return TOK_auto;
        case Attr_Scope:        return TOK_scope;
        case Attr_Ref:          return TOK_ref;
        case Attr_Volatile:     return TOK_volatile;
        case Attr_Gshared:      return TOK___gshared;
        case Attr_Thread:       return TOK___thread;
        case Attr_Shared:       return TOK_shared;
        case Attr_Immutable:    return TOK_immutable;
        case Attr_Pure:         return TOK_pure;
        case Attr_Nothrow:      return TOK_nothrow;
        case Attr_Inout:        return TOK_inout;
        case Attr_Export:       return TOK_export;
        case Attr_Align:        return TOK_align;
        default: return -1;
    }
}

Attribute combineAttributes(Attribute attr, Attribute newAttr)
{
    if(newAttr & Attr_AlignMask)
        attr &= ~Attr_AlignMask;
    if(newAttr & Attr_CallMask)
        attr &= ~Attr_CallMask;
    if(newAttr & Attr_ShareMask)
        attr &= ~Attr_ShareMask;
    return attr | newAttr;
}

string attrToString(Attribute attr)
{
    switch(attr)
    {
        case Attr_Extern:        return "extern";
        case Attr_Synchronized:  return "synchronized";
        case Attr_Static:        return "static";
        case Attr_Final:         return "final";
        case Attr_Abstract:      return "abstract";
        case Attr_Const:         return "const";
        case Attr_Auto:          return "auto";
        case Attr_Scope:         return "scope";
        case Attr_Ref:           return "ref";
        case Attr_Volatile:      return "volatile";
        case Attr_Gshared:       return "__gshared";
        case Attr_Thread:        return "__thread";
        case Attr_Shared:        return "shared";
        case Attr_Immutable:     return "immutable";
        case Attr_Pure:          return "pure";
        case Attr_Nothrow:       return "nothrow";
        case Attr_Inout:         return "inout";
        case Attr_ExternC:       return "extern(C)";
        case Attr_ExternCPP:     return "extern(C++)";
        case Attr_ExternD:       return "extern(D)";
        case Attr_ExternWindows: return "extern(Windows)";
        case Attr_ExternSystem:  return "extern(System)";
        case Attr_Export:        return "export";
        case Attr_Align:         return "align";
        case Attr_Align1:        return "align(1)";
        case Attr_Align2:        return "align(2)";
        case Attr_Align4:        return "align(4)";
        case Attr_Align8:        return "align(8)";
        case Attr_Align16:       return "align(16)";
        default: assert(false);
    }
}

string attrToStringC(Attribute attr)
{
    // Compiler-Specific
    switch(attr)
    {
        case Attr_Extern:        return "extern";
        case Attr_Synchronized:  return "";
        case Attr_Static:        return "static";
        case Attr_Final:         return "";
        case Attr_Abstract:      return "";
        case Attr_Const:         return "const";
        case Attr_Auto:          return "auto";
        case Attr_Scope:         return "scope";
        case Attr_Ref:           return "ref";
        case Attr_Volatile:      return "volatile";
        case Attr_Gshared:       return "";
        case Attr_Thread:        return "__declspec(thread)";
        case Attr_Shared:        return "shared";
        case Attr_Immutable:     return "const";
        case Attr_Pure:          return "";
        case Attr_Nothrow:       return "";
        case Attr_Inout:         return "";
        case Attr_ExternC:       return "extern \"C\"";
        case Attr_ExternCPP:     return "";
        case Attr_ExternD:       return "";
        case Attr_ExternWindows: return "__stdcall";
        case Attr_ExternSystem:  return "__stdcall";
        case Attr_Export:        return "__declspec(dllexport)";
        case Attr_Align:         return "__declspec(align(4))";
        case Attr_Align1:        return "__declspec(align(1))";
        case Attr_Align2:        return "__declspec(align(2))";
        case Attr_Align4:        return "__declspec(align(4))";
        case Attr_Align8:        return "__declspec(align(8))";
        case Attr_Align16:       return "__declspec(align(16))";
        default: assert(false);
    }
}

////////////////////////////////////////////////////////////////
enum AnnotationBits
{
    Deprecated,
    Override,
    Private,
    Package,
    Protected,
    Nogc,
    Public,
    Export,
    Disable,
    Property,
    Safe,
    System,
    Trusted,
}

mixin(genFlagsEnum("", "Annotation_", [__traits(allMembers,AnnotationBits)]));

alias uint Annotation;

enum Annotation_ProtectionMask = Annotation_Private | Annotation_Protected | Annotation_Public | Annotation_Package;
enum Annotation_SafeMask       = Annotation_Safe | Annotation_System | Annotation_Trusted;

Annotation tokenToAnnotation(TokenId tok)
{
    switch(tok)
    {
        case TOK_deprecated: return Annotation_Deprecated;
        case TOK_override:   return Annotation_Override;
        case TOK_disable:    return Annotation_Disable;
        case TOK_property:   return Annotation_Property;
        case TOK_nogc:       return Annotation_Nogc;
        case TOK_safe:       return Annotation_Safe;
        case TOK_system:     return Annotation_System;
        case TOK_trusted:    return Annotation_Trusted;
        default:             return 0;
    }
}

Annotation tokenToProtection(TokenId tok)
{
    switch(tok)
    {
        case TOK_private:   return Annotation_Private;
        case TOK_package:   return Annotation_Package;
        case TOK_protected: return Annotation_Protected;
        case TOK_public:    return Annotation_Public;
        case TOK_export:    return Annotation_Export;
        default:            return 0;
    }
}

Annotation combineAnnotations(Annotation annot, Annotation newAnnot)
{
    if(newAnnot & Annotation_ProtectionMask)
        annot &= ~Annotation_ProtectionMask;
    if(newAnnot & Annotation_SafeMask)
        annot &= ~Annotation_SafeMask;
    return annot | newAnnot;
}

string annotationToString(Annotation annot)
{
    switch(annot)
    {
        case Annotation_Deprecated:return "deprecated";
        case Annotation_Override:  return "override";
        case Annotation_Disable:   return "@disable";
        case Annotation_Property:  return "@property";
        case Annotation_Nogc:      return "@nogc";
        case Annotation_Safe:      return "@safe";
        case Annotation_System:    return "@system";
        case Annotation_Trusted:   return "@trusted";
        case Annotation_Private:   return "private";
        case Annotation_Package:   return "package";
        case Annotation_Protected: return "protected";
        case Annotation_Public:    return "public";
        case Annotation_Export:    return "export";
        default: assert(false);
    }
}

////////////////////////////////////////////////////////////////
string _mixinGetClasses(allMembers...)()
{
    string s;
    foreach(c; allMembers)
        s ~= "if(is(" ~ c ~ " == class)) classes ~= `" ~ c ~ "`;";
    return s;
}

string[] getClasses(allMembers...)()
{
    string[] classes;
    mixin(_mixinGetClasses!(allMembers));
    return classes;
}

string genClassEnum(allMembers...)(string name, string prefix, int off)
{
    string[] classes = getClasses!allMembers();

    string s = "enum " ~ name ~ " { ";
    bool first = true;
    foreach(c; classes)
    {
        if(first)
            s ~= prefix ~ c ~ " = " ~ to!string(off) ~ ", ";
        else
            s ~= prefix ~ c ~ ", ";
        first = false;
    }
    if(prefix.length > 0)
        s ~= prefix ~ "end";
    s ~= " }";
    return s;
}

version(none)
mixin(genClassEnum!(__traits(allMembers,vdc.parser.expr),
                    __traits(allMembers,vdc.parser.decl),
                    __traits(allMembers,vdc.parser.stmt),
                    __traits(allMembers,vdc.parser.mod),
                    __traits(allMembers,vdc.parser.aggr),
                    __traits(allMembers,vdc.parser.misc))("", "NT_", TOK_end_Operators));
