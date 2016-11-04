/**
 * Compiler implementation of the
 * $(LINK2 http://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (c) 1999-2016 by Digital Mars, All Rights Reserved
 * Authors:     $(LINK2 http://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(DMDSRC _doc.d)
 */

module ddmd.doc;

import core.stdc.ctype;
import core.stdc.stdlib;
import core.stdc.stdio;
import core.stdc.string;
import core.stdc.time;
import ddmd.aggregate;
import ddmd.arraytypes;
import ddmd.attrib;
import ddmd.dclass;
import ddmd.declaration;
import ddmd.denum;
import ddmd.dmacro;
import ddmd.dmodule;
import ddmd.dscope;
import ddmd.dstruct;
import ddmd.dsymbol;
import ddmd.dtemplate;
import ddmd.errors;
import ddmd.func;
import ddmd.globals;
import ddmd.hdrgen;
import ddmd.id;
import ddmd.identifier;
import ddmd.lexer;
import ddmd.mtype;
import ddmd.root.array;
import ddmd.root.file;
import ddmd.root.filename;
import ddmd.root.outbuffer;
import ddmd.root.port;
import ddmd.root.rmem;
import ddmd.tokens;
import ddmd.utf;
import ddmd.utils;
import ddmd.visitor;

struct Escape
{
    const(char)*[256] strings;

    /***************************************
     * Find character string to replace c with.
     */
    extern (C++) const(char)* escapeChar(uint c)
    {
        version (all)
        {
            assert(c < 256);
            //printf("escapeChar('%c') => %p, %p\n", c, strings, strings[c]);
            return strings[c];
        }
        else
        {
            const(char)* s;
            switch (c)
            {
            case '<':
                s = "&lt;";
                break;
            case '>':
                s = "&gt;";
                break;
            case '&':
                s = "&amp;";
                break;
            default:
                s = null;
                break;
            }
            return s;
        }
    }
}

/***********************************************************
 */
extern (C++) class Section
{
    const(char)* name;
    size_t namelen;
    const(char)* _body;
    size_t bodylen;
    int nooutput;

    void write(Loc loc, DocComment* dc, Scope* sc, Dsymbols* a, OutBuffer* buf)
    {
        assert(a.dim);
        if (namelen)
        {
            static __gshared const(char)** table =
            [
                "AUTHORS",
                "BUGS",
                "COPYRIGHT",
                "DATE",
                "DEPRECATED",
                "EXAMPLES",
                "HISTORY",
                "LICENSE",
                "RETURNS",
                "SEE_ALSO",
                "STANDARDS",
                "THROWS",
                "VERSION",
                null
            ];
            for (size_t i = 0; table[i]; i++)
            {
                if (icmp(table[i], name, namelen) == 0)
                {
                    buf.printf("$(DDOC_%s ", table[i]);
                    goto L1;
                }
            }
            buf.writestring("$(DDOC_SECTION ");
            // Replace _ characters with spaces
            buf.writestring("$(DDOC_SECTION_H ");
            size_t o = buf.offset;
            for (size_t u = 0; u < namelen; u++)
            {
                char c = name[u];
                buf.writeByte((c == '_') ? ' ' : c);
            }
            escapeStrayParenthesis(loc, buf, o);
            buf.writestring(":)\n");
        }
        else
        {
            buf.writestring("$(DDOC_DESCRIPTION ");
        }
    L1:
        size_t o = buf.offset;
        buf.write(_body, bodylen);
        escapeStrayParenthesis(loc, buf, o);
        highlightText(sc, a, buf, o);
        buf.writestring(")\n");
    }
}

/***********************************************************
 */
extern (C++) final class ParamSection : Section
{
    override void write(Loc loc, DocComment* dc, Scope* sc, Dsymbols* a, OutBuffer* buf)
    {
        assert(a.dim);
        Dsymbol s = (*a)[0]; // test
        const(char)* p = _body;
        size_t len = bodylen;
        const(char)* pend = p + len;
        const(char)* tempstart = null;
        size_t templen = 0;
        const(char)* namestart = null;
        size_t namelen = 0; // !=0 if line continuation
        const(char)* textstart = null;
        size_t textlen = 0;
        size_t paramcount = 0;
        buf.writestring("$(DDOC_PARAMS ");
        while (p < pend)
        {
            // Skip to start of macro
            while (1)
            {
                switch (*p)
                {
                case ' ':
                case '\t':
                    p++;
                    continue;
                case '\n':
                    p++;
                    goto Lcont;
                default:
                    if (isIdStart(p) || isCVariadicArg(p, pend - p))
                        break;
                    if (namelen)
                        goto Ltext;
                    // continuation of prev macro
                    goto Lskipline;
                }
                break;
            }
            tempstart = p;
            while (isIdTail(p))
                p += utfStride(p);
            if (isCVariadicArg(p, pend - p))
                p += 3;
            templen = p - tempstart;
            while (*p == ' ' || *p == '\t')
                p++;
            if (*p != '=')
            {
                if (namelen)
                    goto Ltext;
                // continuation of prev macro
                goto Lskipline;
            }
            p++;
            if (namelen)
            {
                // Output existing param
            L1:
                //printf("param '%.*s' = '%.*s'\n", namelen, namestart, textlen, textstart);
                ++paramcount;
                HdrGenState hgs;
                buf.writestring("$(DDOC_PARAM_ROW ");
                {
                    buf.writestring("$(DDOC_PARAM_ID ");
                    {
                        size_t o = buf.offset;
                        Parameter fparam = isFunctionParameter(a, namestart, namelen);
                        if (!fparam)
                        {
                            // Comments on a template might refer to function parameters within.
                            // Search the parameters of nested eponymous functions (with the same name.)
                            fparam = isEponymousFunctionParameter(a, namestart, namelen);
                        }
                        bool isCVariadic = isCVariadicParameter(a, namestart, namelen);
                        if (isCVariadic)
                        {
                            buf.writestring("...");
                        }
                        else if (fparam && fparam.type && fparam.ident)
                        {
                            .toCBuffer(fparam.type, buf, fparam.ident, &hgs);
                        }
                        else
                        {
                            if (isTemplateParameter(a, namestart, namelen))
                            {
                                // 10236: Don't count template parameters for params check
                                --paramcount;
                            }
                            else if (!fparam)
                            {
                                warning(s.loc, "Ddoc: function declaration has no parameter '%.*s'", namelen, namestart);
                            }
                            buf.write(namestart, namelen);
                        }
                        escapeStrayParenthesis(loc, buf, o);
                        highlightCode(sc, a, buf, o);
                    }
                    buf.writestring(")\n");
                    buf.writestring("$(DDOC_PARAM_DESC ");
                    {
                        size_t o = buf.offset;
                        buf.write(textstart, textlen);
                        escapeStrayParenthesis(loc, buf, o);
                        highlightText(sc, a, buf, o);
                    }
                    buf.writestring(")");
                }
                buf.writestring(")\n");
                namelen = 0;
                if (p >= pend)
                    break;
            }
            namestart = tempstart;
            namelen = templen;
            while (*p == ' ' || *p == '\t')
                p++;
            textstart = p;
        Ltext:
            while (*p != '\n')
                p++;
            textlen = p - textstart;
            p++;
        Lcont:
            continue;
        Lskipline:
            // Ignore this line
            while (*p++ != '\n')
            {
            }
        }
        if (namelen)
            goto L1;
        // write out last one
        buf.writestring(")\n");
        TypeFunction tf = a.dim == 1 ? isTypeFunction(s) : null;
        if (tf)
        {
            size_t pcount = (tf.parameters ? tf.parameters.dim : 0) + cast(int)(tf.varargs == 1);
            if (pcount != paramcount)
            {
                warning(s.loc, "Ddoc: parameter count mismatch");
            }
        }
    }
}

/***********************************************************
 */
extern (C++) final class MacroSection : Section
{
    override void write(Loc loc, DocComment* dc, Scope* sc, Dsymbols* a, OutBuffer* buf)
    {
        //printf("MacroSection::write()\n");
        DocComment.parseMacros(dc.pescapetable, dc.pmacrotable, _body, bodylen);
    }
}

alias Sections = Array!(Section);

// Workaround for missing Parameter instance for variadic params. (it's unnecessary to instantiate one).
extern (C++) bool isCVariadicParameter(Dsymbols* a, const(char)* p, size_t len)
{
    for (size_t i = 0; i < a.dim; i++)
    {
        TypeFunction tf = isTypeFunction((*a)[i]);
        if (tf && tf.varargs == 1 && cmp("...", p, len) == 0)
            return true;
    }
    return false;
}

extern (C++) static Dsymbol getEponymousMember(TemplateDeclaration td)
{
    if (!td.onemember)
        return null;
    if (AggregateDeclaration ad = td.onemember.isAggregateDeclaration())
        return ad;
    if (FuncDeclaration fd = td.onemember.isFuncDeclaration())
        return fd;
    if (auto em = td.onemember.isEnumMember())
        return null;    // Keep backward compatibility. See compilable/ddoc9.d
    if (VarDeclaration vd = td.onemember.isVarDeclaration())
        return td.constraint ? null : vd;
    return null;
}

extern (C++) static TemplateDeclaration getEponymousParent(Dsymbol s)
{
    if (!s.parent)
        return null;
    TemplateDeclaration td = s.parent.isTemplateDeclaration();
    return (td && getEponymousMember(td)) ? td : null;
}

extern (C++) __gshared const(char)* ddoc_default = import("default_ddoc_theme.ddoc");
extern (C++) __gshared const(char)* ddoc_decl_s = "$(DDOC_DECL ";
extern (C++) __gshared const(char)* ddoc_decl_e = ")\n";
extern (C++) __gshared const(char)* ddoc_decl_dd_s = "$(DDOC_DECL_DD ";
extern (C++) __gshared const(char)* ddoc_decl_dd_e = ")\n";

/****************************************************
 */
extern (C++) void gendocfile(Module m)
{
    static __gshared OutBuffer mbuf;
    static __gshared int mbuf_done;
    OutBuffer buf;
    //printf("Module::gendocfile()\n");
    if (!mbuf_done) // if not already read the ddoc files
    {
        mbuf_done = 1;
        // Use our internal default
        mbuf.write(ddoc_default, strlen(ddoc_default));
        // Override with DDOCFILE specified in the sc.ini file
        char* p = getenv("DDOCFILE");
        if (p)
            global.params.ddocfiles.shift(p);
        // Override with the ddoc macro files from the command line
        for (size_t i = 0; i < global.params.ddocfiles.dim; i++)
        {
            auto f = FileName((*global.params.ddocfiles)[i]);
            auto file = File(&f);
            readFile(m.loc, &file);
            // BUG: convert file contents to UTF-8 before use
            //printf("file: '%.*s'\n", file.len, file.buffer);
            mbuf.write(file.buffer, file.len);
        }
    }
    DocComment.parseMacros(&m.escapetable, &m.macrotable, mbuf.peekSlice().ptr, mbuf.peekSlice().length);
    Scope* sc = Scope.createGlobal(m); // create root scope
    DocComment* dc = DocComment.parse(sc, m, m.comment);
    dc.pmacrotable = &m.macrotable;
    dc.pescapetable = &m.escapetable;
    sc.lastdc = dc;
    // Generate predefined macros
    // Set the title to be the name of the module
    {
        const(char)* p = m.toPrettyChars();
        Macro.define(&m.macrotable, "TITLE", p[0 .. strlen(p)]);
    }
    // Set time macros
    {
        time_t t;
        time(&t);
        char* p = ctime(&t);
        p = mem.xstrdup(p);
        Macro.define(&m.macrotable, "DATETIME", p[0 .. strlen(p)]);
        Macro.define(&m.macrotable, "YEAR", p[20 .. 20 + 4]);
    }
    const srcfilename = m.srcfile.toChars();
    Macro.define(&m.macrotable, "SRCFILENAME", srcfilename[0 .. strlen(srcfilename)]);
    const docfilename = m.docfile.toChars();
    Macro.define(&m.macrotable, "DOCFILENAME", docfilename[0 .. strlen(docfilename)]);
    if (dc.copyright)
    {
        dc.copyright.nooutput = 1;
        Macro.define(&m.macrotable, "COPYRIGHT", dc.copyright._body[0 .. dc.copyright.bodylen]);
    }
    if (m.isDocFile)
    {
        Loc loc = m.md ? m.md.loc : m.loc;
        size_t commentlen = strlen(cast(char*)m.comment);
        Dsymbols a;
        // Bugzilla 9764: Don't push m in a, to prevent emphasize ddoc file name.
        if (dc.macros)
        {
            commentlen = dc.macros.name - m.comment;
            dc.macros.write(loc, dc, sc, &a, &buf);
        }
        buf.write(m.comment, commentlen);
        highlightText(sc, &a, &buf, 0);
    }
    else
    {
        Dsymbols a;
        a.push(m);
        dc.writeSections(sc, &a, &buf);
        emitMemberComments(m, &buf, sc);
    }
    //printf("BODY= '%.*s'\n", buf.offset, buf.data);
    Macro.define(&m.macrotable, "BODY", buf.peekSlice());
    OutBuffer buf2;
    buf2.writestring("$(DDOC)\n");
    size_t end = buf2.offset;
    m.macrotable.expand(&buf2, 0, &end, null, 0);
    version (all)
    {
        /* Remove all the escape sequences from buf2,
         * and make CR-LF the newline.
         */
        {
            const slice = buf2.peekSlice();
            buf.setsize(0);
            buf.reserve(slice.length);
            auto p = slice.ptr;
            for (size_t j = 0; j < slice.length; j++)
            {
                char c = p[j];
                if (c == 0xFF && j + 1 < slice.length)
                {
                    j++;
                    continue;
                }
                if (c == '\n')
                    buf.writeByte('\r');
                else if (c == '\r')
                {
                    buf.writestring("\r\n");
                    if (j + 1 < slice.length && p[j + 1] == '\n')
                    {
                        j++;
                    }
                    continue;
                }
                buf.writeByte(c);
            }
        }
        // Transfer image to file
        assert(m.docfile);
        m.docfile.setbuffer(cast(void*)buf.peekSlice().ptr, buf.peekSlice().length);
        m.docfile._ref = 1;
        ensurePathToNameExists(Loc(), m.docfile.toChars());
        writeFile(m.loc, m.docfile);
    }
    else
    {
        /* Remove all the escape sequences from buf2
         */
        {
            size_t i = 0;
            char* p = buf2.data;
            for (size_t j = 0; j < buf2.offset; j++)
            {
                if (p[j] == 0xFF && j + 1 < buf2.offset)
                {
                    j++;
                    continue;
                }
                p[i] = p[j];
                i++;
            }
            buf2.setsize(i);
        }
        // Transfer image to file
        m.docfile.setbuffer(buf2.data, buf2.offset);
        m.docfile._ref = 1;
        ensurePathToNameExists(Loc(), m.docfile.toChars());
        writeFile(m.loc, m.docfile);
    }
}

/****************************************************
 * Having unmatched parentheses can hose the output of Ddoc,
 * as the macros depend on properly nested parentheses.
 * This function replaces all ( with $(LPAREN) and ) with $(RPAREN)
 * to preserve text literally. This also means macros in the
 * text won't be expanded.
 */
extern (C++) void escapeDdocString(OutBuffer* buf, size_t start)
{
    for (size_t u = start; u < buf.offset; u++)
    {
        char c = buf.data[u];
        switch (c)
        {
        case '$':
            buf.remove(u, 1);
            buf.insert(u, "$(DOLLAR)");
            u += 8;
            break;
        case '(':
            buf.remove(u, 1); //remove the (
            buf.insert(u, "$(LPAREN)"); //insert this instead
            u += 8; //skip over newly inserted macro
            break;
        case ')':
            buf.remove(u, 1); //remove the )
            buf.insert(u, "$(RPAREN)"); //insert this instead
            u += 8; //skip over newly inserted macro
            break;
        default:
            break;
        }
    }
}

/****************************************************
 * Having unmatched parentheses can hose the output of Ddoc,
 * as the macros depend on properly nested parentheses.
 *
 * Fix by replacing unmatched ( with $(LPAREN) and unmatched ) with $(RPAREN).
 */
extern (C++) void escapeStrayParenthesis(Loc loc, OutBuffer* buf, size_t start)
{
    uint par_open = 0;
    bool inCode = 0;
    for (size_t u = start; u < buf.offset; u++)
    {
        char c = buf.data[u];
        switch (c)
        {
        case '(':
            if (!inCode)
                par_open++;
            break;
        case ')':
            if (!inCode)
            {
                if (par_open == 0)
                {
                    //stray ')'
                    warning(loc, "Ddoc: Stray ')'. This may cause incorrect Ddoc output. Use $(RPAREN) instead for unpaired right parentheses.");
                    buf.remove(u, 1); //remove the )
                    buf.insert(u, "$(RPAREN)"); //insert this instead
                    u += 8; //skip over newly inserted macro
                }
                else
                    par_open--;
            }
            break;
            version (none)
            {
                // For this to work, loc must be set to the beginning of the passed
                // text which is currently not possible
                // (loc is set to the Loc of the Dsymbol)
            case '\n':
                loc.linnum++;
                break;
            }
        case '-':
            // Issue 15465: don't try to escape unbalanced parens inside code
            // blocks.
            int numdash = 0;
            while (u < buf.offset && buf.data[u] == '-')
            {
                numdash++;
                u++;
            }
            if (numdash >= 3)
                inCode = !inCode;
            break;
        default:
            break;
        }
    }
    if (par_open) // if any unmatched lparens
    {
        par_open = 0;
        for (size_t u = buf.offset; u > start;)
        {
            u--;
            char c = buf.data[u];
            switch (c)
            {
            case ')':
                par_open++;
                break;
            case '(':
                if (par_open == 0)
                {
                    //stray '('
                    warning(loc, "Ddoc: Stray '('. This may cause incorrect Ddoc output. Use $(LPAREN) instead for unpaired left parentheses.");
                    buf.remove(u, 1); //remove the (
                    buf.insert(u, "$(LPAREN)"); //insert this instead
                }
                else
                    par_open--;
                break;
            default:
                break;
            }
        }
    }
}

// Basically, this is to skip over things like private{} blocks in a struct or
// class definition that don't add any components to the qualified name.
extern (C++) static Scope* skipNonQualScopes(Scope* sc)
{
    while (sc && !sc.scopesym)
        sc = sc.enclosing;
    return sc;
}

extern (C++) static bool emitAnchorName(OutBuffer* buf, Dsymbol s, Scope* sc, bool includeParent)
{
    if (!s || s.isPackage() || s.isModule())
        return false;
    // Add parent names first
    bool dot = false;
    auto eponymousParent = getEponymousParent(s);
    if (includeParent && s.parent || eponymousParent)
        dot = emitAnchorName(buf, s.parent, sc, includeParent);
    else if (includeParent && sc)
        dot = emitAnchorName(buf, sc.scopesym, skipNonQualScopes(sc.enclosing), includeParent);
    // Eponymous template members can share the parent anchor name
    if (eponymousParent)
        return dot;
    if (dot)
        buf.writeByte('.');
    // Use "this" not "__ctor"
    TemplateDeclaration td;
    if (s.isCtorDeclaration() || ((td = s.isTemplateDeclaration()) !is null && td.onemember && td.onemember.isCtorDeclaration()))
    {
        buf.writestring("this");
    }
    else
    {
        /* We just want the identifier, not overloads like TemplateDeclaration::toChars.
         * We don't want the template parameter list and constraints. */
        buf.writestring(s.Dsymbol.toChars());
    }
    return true;
}

extern (C++) static void emitAnchor(OutBuffer* buf, Dsymbol s, Scope* sc, bool forHeader = false)
{
    Identifier ident;
    {
        OutBuffer anc;
        emitAnchorName(&anc, s, skipNonQualScopes(sc), true);
        ident = Identifier.idPool(anc.peekSlice());
    }

    auto pcount = cast(void*)ident in sc.anchorCounts;
    typeof(*pcount) count;
    if (!forHeader)
    {
        if (pcount)
        {
            // Existing anchor,
            // don't write an anchor for matching consecutive ditto symbols
            TemplateDeclaration td = getEponymousParent(s);
            if (sc.prevAnchor == ident && sc.lastdc && (isDitto(s.comment) || (td && isDitto(td.comment))))
                return;

            count = ++*pcount;
        }
        else
        {
            sc.anchorCounts[cast(void*)ident] = 1;
            count = 1;
        }
    }

    // cache anchor name
    sc.prevAnchor = ident;
    auto macroName = forHeader ? "DDOC_HEADER_ANCHOR" : "DDOC_ANCHOR";
    auto symbolName = ident.toString();
    buf.printf("$(%.*s %.*s", cast(int) macroName.length, macroName.ptr,
        cast(int) symbolName.length, symbolName.ptr);
    // only append count once there's a duplicate
    if (count > 1)
        buf.printf(".%u", count);

    if (forHeader)
    {
        Identifier shortIdent;
        {
            OutBuffer anc;
            emitAnchorName(&anc, s, skipNonQualScopes(sc), false);
            shortIdent = Identifier.idPool(anc.peekSlice());
        }

        auto shortName = shortIdent.toString();
        buf.printf(", %.*s", cast(int) shortName.length, shortName.ptr);
    }

    buf.writeByte(')');
}

/******************************* emitComment **********************************/

/** Get leading indentation from 'src' which represents lines of code. */
extern (C++) static size_t getCodeIndent(const(char)* src)
{
    while (src && (*src == '\r' || *src == '\n'))
        ++src; // skip until we find the first non-empty line
    size_t codeIndent = 0;
    while (src && (*src == ' ' || *src == '\t'))
    {
        codeIndent++;
        src++;
    }
    return codeIndent;
}

/** Recursively expand template mixin member docs into the scope. */
extern (C++) static void expandTemplateMixinComments(TemplateMixin tm, OutBuffer* buf, Scope* sc)
{
    if (!tm.semanticRun)
        tm.semantic(sc);
    TemplateDeclaration td = (tm && tm.tempdecl) ? tm.tempdecl.isTemplateDeclaration() : null;
    if (td && td.members)
    {
        for (size_t i = 0; i < td.members.dim; i++)
        {
            Dsymbol sm = (*td.members)[i];
            TemplateMixin tmc = sm.isTemplateMixin();
            if (tmc && tmc.comment)
                expandTemplateMixinComments(tmc, buf, sc);
            else
                emitComment(sm, buf, sc);
        }
    }
}

extern (C++) void emitMemberComments(ScopeDsymbol sds, OutBuffer* buf, Scope* sc)
{
    if (!sds.members)
        return;
    //printf("ScopeDsymbol::emitMemberComments() %s\n", toChars());
    const(char)* m = "$(DDOC_MEMBERS ";
    if (sds.isTemplateDeclaration())
        m = "$(DDOC_TEMPLATE_MEMBERS ";
    else if (sds.isClassDeclaration())
        m = "$(DDOC_CLASS_MEMBERS ";
    else if (sds.isStructDeclaration())
        m = "$(DDOC_STRUCT_MEMBERS ";
    else if (sds.isEnumDeclaration())
        m = "$(DDOC_ENUM_MEMBERS ";
    else if (sds.isModule())
        m = "$(DDOC_MODULE_MEMBERS ";
    size_t offset1 = buf.offset; // save starting offset
    buf.writestring(m);
    size_t offset2 = buf.offset; // to see if we write anything
    sc = sc.push(sds);
    for (size_t i = 0; i < sds.members.dim; i++)
    {
        Dsymbol s = (*sds.members)[i];
        //printf("\ts = '%s'\n", s->toChars());
        // only expand if parent is a non-template (semantic won't work)
        if (s.comment && s.isTemplateMixin() && s.parent && !s.parent.isTemplateDeclaration())
            expandTemplateMixinComments(cast(TemplateMixin)s, buf, sc);
        emitComment(s, buf, sc);
    }
    emitComment(null, buf, sc);
    sc.pop();
    if (buf.offset == offset2)
    {
        /* Didn't write out any members, so back out last write
         */
        buf.offset = offset1;
    }
    else
        buf.writestring(")\n");
}

extern (C++) void emitProtection(OutBuffer* buf, Prot prot)
{
    if (prot.kind != PROTundefined && prot.kind != PROTpublic)
    {
        protectionToBuffer(buf, prot);
        buf.writeByte(' ');
    }
}

extern (C++) void emitComment(Dsymbol s, OutBuffer* buf, Scope* sc)
{
    extern (C++) final class EmitComment : Visitor
    {
        alias visit = super.visit;
    public:
        OutBuffer* buf;
        Scope* sc;

        extern (D) this(OutBuffer* buf, Scope* sc)
        {
            this.buf = buf;
            this.sc = sc;
        }

        override void visit(Dsymbol)
        {
        }

        override void visit(InvariantDeclaration)
        {
        }

        override void visit(UnitTestDeclaration)
        {
        }

        override void visit(PostBlitDeclaration)
        {
        }

        override void visit(DtorDeclaration)
        {
        }

        override void visit(StaticCtorDeclaration)
        {
        }

        override void visit(StaticDtorDeclaration)
        {
        }

        override void visit(TypeInfoDeclaration)
        {
        }

        void emit(Scope* sc, Dsymbol s, const(char)* com)
        {
            if (s && sc.lastdc && isDitto(com))
            {
                sc.lastdc.a.push(s);
                return;
            }
            // Put previous doc comment if exists
            if (DocComment* dc = sc.lastdc)
            {
                assert(dc.a.dim > 0, "Expects at least one declaration for a" ~
                    "documentation comment");

                auto symbol = dc.a[0];
                auto symbolName = symbol.ident.toString;

                buf.writestring("$(DDOC_MEMBER");
                buf.writestring("$(DDOC_MEMBER_HEADER");
                emitAnchor(buf, symbol, sc, true);
                buf.writeByte(')');

                // Put the declaration signatures as the document 'title'
                buf.writestring(ddoc_decl_s);
                for (size_t i = 0; i < dc.a.dim; i++)
                {
                    Dsymbol sx = dc.a[i];
                    // the added linebreaks in here make looking at multiple
                    // signatures more appealing
                    if (i == 0)
                    {
                        size_t o = buf.offset;
                        toDocBuffer(sx, buf, sc);
                        highlightCode(sc, sx, buf, o);
                        buf.writestring("$(DDOC_OVERLOAD_SEPARATOR)");
                        continue;
                    }
                    buf.writestring("$(DDOC_DITTO ");
                    {
                        size_t o = buf.offset;
                        toDocBuffer(sx, buf, sc);
                        highlightCode(sc, sx, buf, o);
                    }
                    buf.writestring("$(DDOC_OVERLOAD_SEPARATOR)");
                    buf.writeByte(')');
                }
                buf.writestring(ddoc_decl_e);
                // Put the ddoc comment as the document 'description'
                buf.writestring(ddoc_decl_dd_s);
                {
                    dc.writeSections(sc, &dc.a, buf);
                    if (ScopeDsymbol sds = dc.a[0].isScopeDsymbol())
                        emitMemberComments(sds, buf, sc);
                }
                buf.writestring(ddoc_decl_dd_e);
                buf.writeByte(')');
                //printf("buf.2 = [[%.*s]]\n", buf->offset - o0, buf->data + o0);
            }
            if (s)
            {
                DocComment* dc = DocComment.parse(sc, s, com);
                dc.pmacrotable = &sc._module.macrotable;
                sc.lastdc = dc;
            }
        }

        override void visit(Declaration d)
        {
            //printf("Declaration::emitComment(%p '%s'), comment = '%s'\n", d, d.toChars(), d.comment);
            //printf("type = %p\n", d.type);
            const(char)* com = d.comment;
            if (TemplateDeclaration td = getEponymousParent(d))
            {
                if (isDitto(td.comment))
                    com = td.comment;
                else
                    com = Lexer.combineComments(td.comment, com);
            }
            else
            {
                if (!d.ident)
                    return;
                if (!d.type)
                {
                    if (!d.isCtorDeclaration() &&
                        !d.isAliasDeclaration() &&
                        !d.isVarDeclaration())
                    {
                        return;
                    }
                }
                if (d.protection.kind == PROTprivate || sc.protection.kind == PROTprivate)
                    return;
            }
            if (!com)
                return;
            emit(sc, d, com);
        }

        override void visit(AggregateDeclaration ad)
        {
            //printf("AggregateDeclaration::emitComment() '%s'\n", ad->toChars());
            const(char)* com = ad.comment;
            if (TemplateDeclaration td = getEponymousParent(ad))
            {
                if (isDitto(td.comment))
                    com = td.comment;
                else
                    com = Lexer.combineComments(td.comment, com);
            }
            else
            {
                if (ad.prot().kind == PROTprivate || sc.protection.kind == PROTprivate)
                    return;
                if (!ad.comment)
                    return;
            }
            if (!com)
                return;
            emit(sc, ad, com);
        }

        override void visit(TemplateDeclaration td)
        {
            //printf("TemplateDeclaration::emitComment() '%s', kind = %s\n", td->toChars(), td->kind());
            if (td.prot().kind == PROTprivate || sc.protection.kind == PROTprivate)
                return;
            if (!td.comment)
                return;
            if (Dsymbol ss = getEponymousMember(td))
            {
                ss.accept(this);
                return;
            }
            emit(sc, td, td.comment);
        }

        override void visit(EnumDeclaration ed)
        {
            if (ed.prot().kind == PROTprivate || sc.protection.kind == PROTprivate)
                return;
            if (ed.isAnonymous() && ed.members)
            {
                for (size_t i = 0; i < ed.members.dim; i++)
                {
                    Dsymbol s = (*ed.members)[i];
                    emitComment(s, buf, sc);
                }
                return;
            }
            if (!ed.comment)
                return;
            if (ed.isAnonymous())
                return;
            emit(sc, ed, ed.comment);
        }

        override void visit(EnumMember em)
        {
            //printf("EnumMember::emitComment(%p '%s'), comment = '%s'\n", em, em->toChars(), em->comment);
            if (em.prot().kind == PROTprivate || sc.protection.kind == PROTprivate)
                return;
            if (!em.comment)
                return;
            emit(sc, em, em.comment);
        }

        override void visit(AttribDeclaration ad)
        {
            //printf("AttribDeclaration::emitComment(sc = %p)\n", sc);
            /* A general problem with this, illustrated by BUGZILLA 2516,
             * is that attributes are not transmitted through to the underlying
             * member declarations for template bodies, because semantic analysis
             * is not done for template declaration bodies
             * (only template instantiations).
             * Hence, Ddoc omits attributes from template members.
             */
            Dsymbols* d = ad.include(null, null);
            if (d)
            {
                for (size_t i = 0; i < d.dim; i++)
                {
                    Dsymbol s = (*d)[i];
                    //printf("AttribDeclaration::emitComment %s\n", s->toChars());
                    emitComment(s, buf, sc);
                }
            }
        }

        override void visit(ProtDeclaration pd)
        {
            if (pd.decl)
            {
                Scope* scx = sc;
                sc = sc.copy();
                sc.protection = pd.protection;
                visit(cast(AttribDeclaration)pd);
                scx.lastdc = sc.lastdc;
                sc = sc.pop();
            }
        }

        override void visit(ConditionalDeclaration cd)
        {
            //printf("ConditionalDeclaration::emitComment(sc = %p)\n", sc);
            if (cd.condition.inc)
            {
                visit(cast(AttribDeclaration)cd);
                return;
            }
            /* If generating doc comment, be careful because if we're inside
             * a template, then include(NULL, NULL) will fail.
             */
            Dsymbols* d = cd.decl ? cd.decl : cd.elsedecl;
            for (size_t i = 0; i < d.dim; i++)
            {
                Dsymbol s = (*d)[i];
                emitComment(s, buf, sc);
            }
        }
    }

    scope EmitComment v = new EmitComment(buf, sc);
    if (!s)
        v.emit(sc, null, null);
    else
        s.accept(v);
}

extern (C++) void toDocBuffer(Dsymbol s, OutBuffer* buf, Scope* sc)
{
    extern (C++) final class ToDocBuffer : Visitor
    {
        alias visit = super.visit;
    public:
        OutBuffer* buf;
        Scope* sc;

        extern (D) this(OutBuffer* buf, Scope* sc)
        {
            this.buf = buf;
            this.sc = sc;
        }

        override void visit(Dsymbol s)
        {
            //printf("Dsymbol::toDocbuffer() %s\n", s->toChars());
            HdrGenState hgs;
            hgs.ddoc = true;
            .toCBuffer(s, buf, &hgs);
        }

        void prefix(Dsymbol s)
        {
            if (s.isDeprecated())
                buf.writestring("deprecated ");
            if (Declaration d = s.isDeclaration())
            {
                emitProtection(buf, d.protection);
                if (d.isStatic())
                    buf.writestring("static ");
                else if (d.isFinal())
                    buf.writestring("final ");
                else if (d.isAbstract())
                    buf.writestring("abstract ");

                if (d.isFuncDeclaration())      // functionToBufferFull handles this
                    return;

                if (d.isImmutable())
                    buf.writestring("immutable ");
                if (d.storage_class & STCshared)
                    buf.writestring("shared ");
                if (d.isWild())
                    buf.writestring("inout ");
                if (d.isConst())
                    buf.writestring("const ");

                if (d.isSynchronized())
                    buf.writestring("synchronized ");

                if (d.storage_class & STCmanifest)
                    buf.writestring("enum ");

                // Add "auto" for the untyped variable in template members
                if (!d.type && d.isVarDeclaration() &&
                    !d.isImmutable() && !(d.storage_class & STCshared) && !d.isWild() && !d.isConst() &&
                    !d.isSynchronized())
                {
                    buf.writestring("auto ");
                }
            }
        }

        override void visit(Declaration d)
        {
            if (!d.ident)
                return;
            TemplateDeclaration td = getEponymousParent(d);
            //printf("Declaration::toDocbuffer() %s, originalType = %s, td = %s\n", d->toChars(), d->originalType ? d->originalType->toChars() : "--", td ? td->toChars() : "--");
            HdrGenState hgs;
            hgs.ddoc = true;
            if (d.isDeprecated())
                buf.writestring("$(DEPRECATED ");
            prefix(d);
            if (d.type)
            {
                Type origType = d.originalType ? d.originalType : d.type;
                if (origType.ty == Tfunction)
                {
                    functionToBufferFull(cast(TypeFunction)origType, buf, d.ident, &hgs, td);
                }
                else
                    .toCBuffer(origType, buf, d.ident, &hgs);
            }
            else
                buf.writestring(d.ident.toChars());
            if (d.isVarDeclaration() && td)
            {
                buf.writeByte('(');
                if (td.origParameters && td.origParameters.dim)
                {
                    for (size_t i = 0; i < td.origParameters.dim; i++)
                    {
                        if (i)
                            buf.writestring(", ");
                        toCBuffer((*td.origParameters)[i], buf, &hgs);
                    }
                }
                buf.writeByte(')');
            }
            // emit constraints if declaration is a templated declaration
            if (td && td.constraint)
            {
                bool noFuncDecl = td.isFuncDeclaration() is null;
                if (noFuncDecl)
                {
                    buf.writestring("$(DDOC_CONSTRAINT ");
                }

                .toCBuffer(td.constraint, buf, &hgs);

                if (noFuncDecl)
                {
                    buf.writestring(")");
                }
            }
            if (d.isDeprecated())
                buf.writestring(")");
            buf.writestring(";\n");
        }

        override void visit(AliasDeclaration ad)
        {
            //printf("AliasDeclaration::toDocbuffer() %s\n", ad->toChars());
            if (!ad.ident)
                return;
            if (ad.isDeprecated())
                buf.writestring("deprecated ");
            emitProtection(buf, ad.protection);
            buf.printf("alias %s = ", ad.toChars());
            if (Dsymbol s = ad.aliassym) // ident alias
            {
                prettyPrintDsymbol(s, ad.parent);
            }
            else if (Type type = ad.getType()) // type alias
            {
                if (type.ty == Tclass || type.ty == Tstruct || type.ty == Tenum)
                {
                    if (Dsymbol s = type.toDsymbol(null)) // elaborate type
                        prettyPrintDsymbol(s, ad.parent);
                    else
                        buf.writestring(type.toChars());
                }
                else
                {
                    // simple type
                    buf.writestring(type.toChars());
                }
            }
            buf.writestring(";\n");
        }

        void parentToBuffer(Dsymbol s)
        {
            if (s && !s.isPackage() && !s.isModule())
            {
                parentToBuffer(s.parent);
                buf.writestring(s.toChars());
                buf.writestring(".");
            }
        }

        static bool inSameModule(Dsymbol s, Dsymbol p)
        {
            for (; s; s = s.parent)
            {
                if (s.isModule())
                    break;
            }
            for (; p; p = p.parent)
            {
                if (p.isModule())
                    break;
            }
            return s == p;
        }

        void prettyPrintDsymbol(Dsymbol s, Dsymbol parent)
        {
            if (s.parent && (s.parent == parent)) // in current scope -> naked name
            {
                buf.writestring(s.toChars());
            }
            else if (!inSameModule(s, parent)) // in another module -> full name
            {
                buf.writestring(s.toPrettyChars());
            }
            else // nested in a type in this module -> full name w/o module name
            {
                // if alias is nested in a user-type use module-scope lookup
                if (!parent.isModule() && !parent.isPackage())
                    buf.writestring(".");
                parentToBuffer(s.parent);
                buf.writestring(s.toChars());
            }
        }

        override void visit(AggregateDeclaration ad)
        {
            if (!ad.ident)
                return;
            version (none)
            {
                emitProtection(buf, ad.protection);
            }
            buf.printf("%s %s", ad.kind(), ad.toChars());
            buf.writestring(";\n");
        }

        override void visit(StructDeclaration sd)
        {
            //printf("StructDeclaration::toDocbuffer() %s\n", sd->toChars());
            if (!sd.ident)
                return;
            version (none)
            {
                emitProtection(buf, sd.protection);
            }
            if (TemplateDeclaration td = getEponymousParent(sd))
            {
                toDocBuffer(td, buf, sc);
            }
            else
            {
                buf.printf("%s %s", sd.kind(), sd.toChars());
            }
            buf.writestring(";\n");
        }

        override void visit(ClassDeclaration cd)
        {
            //printf("ClassDeclaration::toDocbuffer() %s\n", cd->toChars());
            if (!cd.ident)
                return;
            version (none)
            {
                emitProtection(buf, cd.protection);
            }
            if (TemplateDeclaration td = getEponymousParent(cd))
            {
                toDocBuffer(td, buf, sc);
            }
            else
            {
                if (!cd.isInterfaceDeclaration() && cd.isAbstract())
                    buf.writestring("abstract ");
                buf.printf("%s %s", cd.kind(), cd.toChars());
            }
            int any = 0;
            for (size_t i = 0; i < cd.baseclasses.dim; i++)
            {
                BaseClass* bc = (*cd.baseclasses)[i];
                if (bc.sym && bc.sym.ident == Id.Object)
                    continue;
                if (any)
                    buf.writestring(", ");
                else
                {
                    buf.writestring(": ");
                    any = 1;
                }
                emitProtection(buf, Prot(PROTpublic));
                if (bc.sym)
                {
                    buf.printf("$(DDOC_PSUPER_SYMBOL %s)", bc.sym.toPrettyChars());
                }
                else
                {
                    HdrGenState hgs;
                    .toCBuffer(bc.type, buf, null, &hgs);
                }
            }
            buf.writestring(";\n");
        }

        override void visit(EnumDeclaration ed)
        {
            if (!ed.ident)
                return;
            buf.printf("%s %s", ed.kind(), ed.toChars());
            if (ed.memtype)
            {
                buf.writestring(": $(DDOC_ENUM_BASETYPE ");
                HdrGenState hgs;
                .toCBuffer(ed.memtype, buf, null, &hgs);
                buf.writestring(")");
            }
            buf.writestring(";\n");
        }

        override void visit(EnumMember em)
        {
            if (!em.ident)
                return;
            buf.writestring(em.toChars());
        }
    }

    scope ToDocBuffer v = new ToDocBuffer(buf, sc);
    s.accept(v);
}

/***********************************************************
 */
struct DocComment
{
    Sections sections;      // Section*[]
    Section summary;
    Section copyright;
    Section macros;
    Macro** pmacrotable;
    Escape** pescapetable;
    Dsymbols a;

    extern (C++) static DocComment* parse(Scope* sc, Dsymbol s, const(char)* comment)
    {
        //printf("parse(%s): '%s'\n", s->toChars(), comment);
        auto dc = new DocComment();
        dc.a.push(s);
        if (!comment)
            return dc;
        dc.parseSections(comment);
        for (size_t i = 0; i < dc.sections.dim; i++)
        {
            Section sec = dc.sections[i];
            if (icmp("copyright", sec.name, sec.namelen) == 0)
            {
                dc.copyright = sec;
            }
            if (icmp("macros", sec.name, sec.namelen) == 0)
            {
                dc.macros = sec;
            }
        }
        return dc;
    }

    /************************************************
     * Parse macros out of Macros: section.
     * Macros are of the form:
     *      name1 = value1
     *
     *      name2 = value2
     */
    extern (C++) static void parseMacros(Escape** pescapetable, Macro** pmacrotable, const(char)* m, size_t mlen)
    {
        const(char)* p = m;
        size_t len = mlen;
        const(char)* pend = p + len;
        const(char)* tempstart = null;
        size_t templen = 0;
        const(char)* namestart = null;
        size_t namelen = 0; // !=0 if line continuation
        const(char)* textstart = null;
        size_t textlen = 0;
        while (p < pend)
        {
            // Skip to start of macro
            while (1)
            {
                if (p >= pend)
                    goto Ldone;
                switch (*p)
                {
                case ' ':
                case '\t':
                    p++;
                    continue;
                case '\r':
                case '\n':
                    p++;
                    goto Lcont;
                default:
                    if (isIdStart(p))
                        break;
                    if (namelen)
                        goto Ltext; // continuation of prev macro
                    goto Lskipline;
                }
                break;
            }
            tempstart = p;
            while (1)
            {
                if (p >= pend)
                    goto Ldone;
                if (!isIdTail(p))
                    break;
                p += utfStride(p);
            }
            templen = p - tempstart;
            while (1)
            {
                if (p >= pend)
                    goto Ldone;
                if (!(*p == ' ' || *p == '\t'))
                    break;
                p++;
            }
            if (*p != '=')
            {
                if (namelen)
                    goto Ltext; // continuation of prev macro
                goto Lskipline;
            }
            p++;
            if (p >= pend)
                goto Ldone;
            if (namelen)
            {
                // Output existing macro
            L1:
                //printf("macro '%.*s' = '%.*s'\n", namelen, namestart, textlen, textstart);
                if (icmp("ESCAPES", namestart, namelen) == 0)
                    parseEscapes(pescapetable, textstart, textlen);
                else
                    Macro.define(pmacrotable, namestart[0 ..namelen], textstart[0 .. textlen]);
                namelen = 0;
                if (p >= pend)
                    break;
            }
            namestart = tempstart;
            namelen = templen;
            while (p < pend && (*p == ' ' || *p == '\t'))
                p++;
            textstart = p;
        Ltext:
            while (p < pend && *p != '\r' && *p != '\n')
                p++;
            textlen = p - textstart;
            p++;
            //printf("p = %p, pend = %p\n", p, pend);
        Lcont:
            continue;
        Lskipline:
            // Ignore this line
            while (p < pend && *p != '\r' && *p != '\n')
                p++;
        }
    Ldone:
        if (namelen)
            goto L1; // write out last one
    }

    /**************************************
     * Parse escapes of the form:
     *      /c/string/
     * where c is a single character.
     * Multiple escapes can be separated
     * by whitespace and/or commas.
     */
    extern (C++) static void parseEscapes(Escape** pescapetable, const(char)* textstart, size_t textlen)
    {
        Escape* escapetable = *pescapetable;
        if (!escapetable)
        {
            escapetable = new Escape();
            memset(escapetable, 0, Escape.sizeof);
            *pescapetable = escapetable;
        }
        //printf("parseEscapes('%.*s') pescapetable = %p\n", textlen, textstart, pescapetable);
        const(char)* p = textstart;
        const(char)* pend = p + textlen;
        while (1)
        {
            while (1)
            {
                if (p + 4 >= pend)
                    return;
                if (!(*p == ' ' || *p == '\t' || *p == '\r' || *p == '\n' || *p == ','))
                    break;
                p++;
            }
            if (p[0] != '/' || p[2] != '/')
                return;
            char c = p[1];
            p += 3;
            const(char)* start = p;
            while (1)
            {
                if (p >= pend)
                    return;
                if (*p == '/')
                    break;
                p++;
            }
            size_t len = p - start;
            char* s = cast(char*)memcpy(mem.xmalloc(len + 1), start, len);
            s[len] = 0;
            escapetable.strings[c] = s;
            //printf("\t%c = '%s'\n", c, s);
            p++;
        }
    }

    /*****************************************
     * Parse next paragraph out of *pcomment.
     * Update *pcomment to point past paragraph.
     * Returns NULL if no more paragraphs.
     * If paragraph ends in 'identifier:',
     * then (*pcomment)[0 .. idlen] is the identifier.
     */
    extern (C++) void parseSections(const(char)* comment)
    {
        const(char)* p;
        const(char)* pstart;
        const(char)* pend;
        const(char)* idstart = null; // dead-store to prevent spurious warning
        size_t idlen;
        const(char)* name = null;
        size_t namelen = 0;
        //printf("parseSections('%s')\n", comment);
        p = comment;
        while (*p)
        {
            const(char)* pstart0 = p;
            p = skipwhitespace(p);
            pstart = p;
            pend = p;
            /* Find end of section, which is ended by one of:
             *      'identifier:' (but not inside a code section)
             *      '\0'
             */
            idlen = 0;
            int inCode = 0;
            while (1)
            {
                // Check for start/end of a code section
                if (*p == '-')
                {
                    if (!inCode)
                    {
                        // restore leading indentation
                        while (pstart0 < pstart && isIndentWS(pstart - 1))
                            --pstart;
                    }
                    int numdash = 0;
                    while (*p == '-')
                    {
                        ++numdash;
                        p++;
                    }
                    // BUG: handle UTF PS and LS too
                    if ((!*p || *p == '\r' || *p == '\n') && numdash >= 3)
                        inCode ^= 1;
                    pend = p;
                }
                if (!inCode && isIdStart(p))
                {
                    const(char)* q = p + utfStride(p);
                    while (isIdTail(q))
                        q += utfStride(q);
                    if (*q == ':') // identifier: ends it
                    {
                        idlen = q - p;
                        idstart = p;
                        for (pend = p; pend > pstart; pend--)
                        {
                            if (pend[-1] == '\n')
                                break;
                        }
                        p = q + 1;
                        break;
                    }
                }
                while (1)
                {
                    if (!*p)
                        goto L1;
                    if (*p == '\n')
                    {
                        p++;
                        if (*p == '\n' && !summary && !namelen && !inCode)
                        {
                            pend = p;
                            p++;
                            goto L1;
                        }
                        break;
                    }
                    p++;
                    pend = p;
                }
                p = skipwhitespace(p);
            }
        L1:
            if (namelen || pstart < pend)
            {
                Section s;
                if (icmp("Params", name, namelen) == 0)
                    s = new ParamSection();
                else if (icmp("Macros", name, namelen) == 0)
                    s = new MacroSection();
                else
                    s = new Section();
                s.name = name;
                s.namelen = namelen;
                s._body = pstart;
                s.bodylen = pend - pstart;
                s.nooutput = 0;
                //printf("Section: '%.*s' = '%.*s'\n", s->namelen, s->name, s->bodylen, s->body);
                sections.push(s);
                if (!summary && !namelen)
                    summary = s;
            }
            if (idlen)
            {
                name = idstart;
                namelen = idlen;
            }
            else
            {
                name = null;
                namelen = 0;
                if (!*p)
                    break;
            }
        }
    }

    extern (C++) void writeSections(Scope* sc, Dsymbols* a, OutBuffer* buf)
    {
        assert(a.dim);
        //printf("DocComment::writeSections()\n");
        Loc loc = (*a)[0].loc;
        if (Module m = (*a)[0].isModule())
        {
            if (m.md)
                loc = m.md.loc;
        }
        size_t offset1 = buf.offset;
        buf.writestring("$(DDOC_SECTIONS ");
        size_t offset2 = buf.offset;
        for (size_t i = 0; i < sections.dim; i++)
        {
            Section sec = sections[i];
            if (sec.nooutput)
                continue;
            //printf("Section: '%.*s' = '%.*s'\n", sec->namelen, sec->name, sec->bodylen, sec->body);
            if (!sec.namelen && i == 0)
            {
                buf.writestring("$(DDOC_SUMMARY ");
                size_t o = buf.offset;
                buf.write(sec._body, sec.bodylen);
                escapeStrayParenthesis(loc, buf, o);
                highlightText(sc, a, buf, o);
                buf.writestring(")\n");
            }
            else
                sec.write(loc, &this, sc, a, buf);
        }
        for (size_t i = 0; i < a.dim; i++)
        {
            Dsymbol s = (*a)[i];
            if (Dsymbol td = getEponymousParent(s))
                s = td;
            for (UnitTestDeclaration utd = s.ddocUnittest; utd; utd = utd.ddocUnittest)
            {
                if (utd.protection.kind == PROTprivate || !utd.comment || !utd.fbody)
                    continue;
                // Strip whitespaces to avoid showing empty summary
                const(char)* c = utd.comment;
                while (*c == ' ' || *c == '\t' || *c == '\n' || *c == '\r')
                    ++c;
                buf.writestring("$(DDOC_EXAMPLES ");
                size_t o = buf.offset;
                buf.writestring(cast(char*)c);
                if (utd.codedoc)
                {
                    auto codedoc = utd.codedoc.stripLeadingNewlines;
                    size_t n = getCodeIndent(codedoc);
                    while (n--)
                        buf.writeByte(' ');
                    buf.writestring("----\n");
                    buf.writestring(codedoc);
                    buf.writestring("----\n");
                    highlightText(sc, a, buf, o);
                }
                buf.writestring(")");
            }
        }
        if (buf.offset == offset2)
        {
            /* Didn't write out any sections, so back out last write
             */
            buf.offset = offset1;
            buf.writestring("$(DDOC_BLANKLINE)\n");
        }
        else
            buf.writestring(")\n");
    }
}

/******************************************
 * Compare 0-terminated string with length terminated string.
 * Return < 0, ==0, > 0
 */
extern (C++) int cmp(const(char)* stringz, const(void)* s, size_t slen)
{
    size_t len1 = strlen(stringz);
    if (len1 != slen)
        return cast(int)(len1 - slen);
    return memcmp(stringz, s, slen);
}

extern (C++) int icmp(const(char)* stringz, const(void)* s, size_t slen)
{
    size_t len1 = strlen(stringz);
    if (len1 != slen)
        return cast(int)(len1 - slen);
    return Port.memicmp(stringz, cast(char*)s, slen);
}

/*****************************************
 * Return true if comment consists entirely of "ditto".
 */
extern (C++) bool isDitto(const(char)* comment)
{
    if (comment)
    {
        const(char)* p = skipwhitespace(comment);
        if (Port.memicmp(p, "ditto", 5) == 0 && *skipwhitespace(p + 5) == 0)
            return true;
    }
    return false;
}

/**********************************************
 * Skip white space.
 */
extern (C++) const(char)* skipwhitespace(const(char)* p)
{
    for (; 1; p++)
    {
        switch (*p)
        {
        case ' ':
        case '\t':
        case '\n':
            continue;
        default:
            break;
        }
        break;
    }
    return p;
}

/************************************************
 * Scan forward to one of:
 *      start of identifier
 *      beginning of next line
 *      end of buf
 */
extern (C++) size_t skiptoident(OutBuffer* buf, size_t i)
{
    const slice = buf.peekSlice();
    while (i < slice.length)
    {
        dchar c;
        size_t oi = i;
        if (utf_decodeChar(slice.ptr, slice.length, i, c))
        {
            /* Ignore UTF errors, but still consume input
             */
            break;
        }
        if (c >= 0x80)
        {
            if (!isUniAlpha(c))
                continue;
        }
        else if (!(isalpha(c) || c == '_' || c == '\n'))
            continue;
        i = oi;
        break;
    }
    return i;
}

/************************************************
 * Scan forward past end of identifier.
 */
extern (C++) size_t skippastident(OutBuffer* buf, size_t i)
{
    const slice = buf.peekSlice();
    while (i < slice.length)
    {
        dchar c;
        size_t oi = i;
        if (utf_decodeChar(slice.ptr, slice.length, i, c))
        {
            /* Ignore UTF errors, but still consume input
             */
            break;
        }
        if (c >= 0x80)
        {
            if (isUniAlpha(c))
                continue;
        }
        else if (isalnum(c) || c == '_')
            continue;
        i = oi;
        break;
    }
    return i;
}

/************************************************
 * Scan forward past URL starting at i.
 * We don't want to highlight parts of a URL.
 * Returns:
 *      i if not a URL
 *      index just past it if it is a URL
 */
extern (C++) size_t skippastURL(OutBuffer* buf, size_t i)
{
    const slice = buf.peekSlice()[i .. $];
    size_t j;
    bool sawdot = false;
    if (slice.length > 7 && Port.memicmp(slice.ptr, "http://", 7) == 0)
    {
        j = 7;
    }
    else if (slice.length > 8 && Port.memicmp(slice.ptr, "https://", 8) == 0)
    {
        j = 8;
    }
    else
        goto Lno;
    for (; j < slice.length; j++)
    {
        const c = slice[j];
        if (isalnum(c))
            continue;
        if (c == '-' || c == '_' || c == '?' || c == '=' || c == '%' ||
            c == '&' || c == '/' || c == '+' || c == '#' || c == '~')
            continue;
        if (c == '.')
        {
            sawdot = true;
            continue;
        }
        break;
    }
    if (sawdot)
        return i + j;
Lno:
    return i;
}

/****************************************************
 */
extern (C++) bool isIdentifier(Dsymbols* a, const(char)* p, size_t len)
{
    for (size_t i = 0; i < a.dim; i++)
    {
        const(char)* s = (*a)[i].ident.toChars();
        if (cmp(s, p, len) == 0)
            return true;
    }
    return false;
}

/****************************************************
 */
extern (C++) bool isKeyword(const(char)* p, size_t len)
{
    immutable string[3] table = ["true", "false", "null"];
    foreach (s; table)
    {
        if (cmp(s.ptr, p, len) == 0)
            return true;
    }
    return false;
}

/****************************************************
 */
extern (C++) TypeFunction isTypeFunction(Dsymbol s)
{
    FuncDeclaration f = s.isFuncDeclaration();
    /* f->type may be NULL for template members.
     */
    if (f && f.type)
    {
        Type t = f.originalType ? f.originalType : f.type;
        if (t.ty == Tfunction)
            return cast(TypeFunction)t;
    }
    return null;
}

/****************************************************
 */
private Parameter isFunctionParameter(Dsymbol s, const(char)* p, size_t len)
{
    TypeFunction tf = isTypeFunction(s);
    if (tf && tf.parameters)
    {
        for (size_t k = 0; k < tf.parameters.dim; k++)
        {
            Parameter fparam = (*tf.parameters)[k];
            if (fparam.ident && cmp(fparam.ident.toChars(), p, len) == 0)
            {
                return fparam;
            }
        }
    }
    return null;
}

/****************************************************
 */
extern (C++) Parameter isFunctionParameter(Dsymbols* a, const(char)* p, size_t len)
{
    for (size_t i = 0; i < a.dim; i++)
    {
        Parameter fparam = isFunctionParameter((*a)[i], p, len);
        if (fparam)
        {
            return fparam;
        }
    }
    return null;
}

/****************************************************
 */
private Parameter isEponymousFunctionParameter(Dsymbols *a, const(char) *p, size_t len)
{
    for (size_t i = 0; i < a.dim; i++)
    {
        TemplateDeclaration td = (*a)[i].isTemplateDeclaration();
        if (td && td.onemember)
        {
            /* Case 1: we refer to a template declaration inside the template

               /// ...ddoc...
               template case1(T) {
                 void case1(R)() {}
               }
             */
            td = td.onemember.isTemplateDeclaration();
        }
        if (!td)
        {
            /* Case 2: we're an alias to a template declaration

               /// ...ddoc...
               alias case2 = case1!int;
             */
            AliasDeclaration ad = (*a)[i].isAliasDeclaration();
            if (ad && ad.aliassym)
            {
                td = ad.aliassym.isTemplateDeclaration();
            }
        }
        while (td)
        {
            Dsymbol sym = getEponymousMember(td);
            if (sym)
            {
                Parameter fparam = isFunctionParameter(sym, p, len);
                if (fparam)
                {
                    return fparam;
                }
            }
            td = td.overnext;
        }
    }
    return null;
}

/****************************************************
 */
extern (C++) TemplateParameter isTemplateParameter(Dsymbols* a, const(char)* p, size_t len)
{
    for (size_t i = 0; i < a.dim; i++)
    {
        TemplateDeclaration td = (*a)[i].isTemplateDeclaration();
        // Check for the parent, if the current symbol is not a template declaration.
        if (!td)
            td = getEponymousParent((*a)[i]);
        if (td && td.origParameters)
        {
            for (size_t k = 0; k < td.origParameters.dim; k++)
            {
                TemplateParameter tp = (*td.origParameters)[k];
                if (tp.ident && cmp(tp.ident.toChars(), p, len) == 0)
                {
                    return tp;
                }
            }
        }
    }
    return null;
}

/****************************************************
 * Return true if str is a reserved symbol name
 * that starts with a double underscore.
 */
extern (C++) bool isReservedName(const(char)* str, size_t len)
{
    immutable string[] table =
    [
        "__ctor",
        "__dtor",
        "__postblit",
        "__invariant",
        "__unitTest",
        "__require",
        "__ensure",
        "__dollar",
        "__ctfe",
        "__withSym",
        "__result",
        "__returnLabel",
        "__vptr",
        "__monitor",
        "__gate",
        "__xopEquals",
        "__xopCmp",
        "__LINE__",
        "__FILE__",
        "__MODULE__",
        "__FUNCTION__",
        "__PRETTY_FUNCTION__",
        "__DATE__",
        "__TIME__",
        "__TIMESTAMP__",
        "__VENDOR__",
        "__VERSION__",
        "__EOF__",
        "__LOCAL_SIZE",
        "___tls_get_addr",
        "__entrypoint",
    ];
    foreach (s; table)
    {
        if (cmp(s.ptr, str, len) == 0)
            return true;
    }
    return false;
}

/**************************************************
 * Highlight text section.
 */
extern (C++) void highlightText(Scope* sc, Dsymbols* a, OutBuffer* buf, size_t offset)
{
    Dsymbol s = a.dim ? (*a)[0] : null; // test
    //printf("highlightText()\n");
    int leadingBlank = 1;
    int inCode = 0;
    int inBacktick = 0;
    //int inComment = 0;                  // in <!-- ... --> comment
    size_t iCodeStart = 0; // start of code section
    size_t codeIndent = 0;
    size_t iLineStart = offset;
    for (size_t i = offset; i < buf.offset; i++)
    {
        char c = buf.data[i];
    Lcont:
        switch (c)
        {
        case ' ':
        case '\t':
            break;
        case '\n':
            if (inBacktick)
            {
                // `inline code` is only valid if contained on a single line
                // otherwise, the backticks should be output literally.
                //
                // This lets things like `output from the linker' display
                // unmolested while keeping the feature consistent with GitHub.
                inBacktick = false;
                inCode = false; // the backtick also assumes we're in code
                // Nothing else is necessary since the DDOC_BACKQUOTED macro is
                // inserted lazily at the close quote, meaning the rest of the
                // text is already OK.
            }
            if (!sc._module.isDocFile && !inCode && i == iLineStart && i + 1 < buf.offset) // if "\n\n"
            {
                immutable blankline = "$(DDOC_BLANKLINE)\n";
                i = buf.insert(i, blankline);
            }
            leadingBlank = 1;
            iLineStart = i + 1;
            break;
        case '<':
            {
                leadingBlank = 0;
                if (inCode)
                    break;
                const slice = buf.peekSlice();
                auto p = &slice[i];
                const se = sc._module.escapetable.escapeChar('<');
                if (se && strcmp(se, "&lt;") == 0)
                {
                    // Generating HTML
                    // Skip over comments
                    if (p[1] == '!' && p[2] == '-' && p[3] == '-')
                    {
                        size_t j = i + 4;
                        p += 4;
                        while (1)
                        {
                            if (j == slice.length)
                                goto L1;
                            if (p[0] == '-' && p[1] == '-' && p[2] == '>')
                            {
                                i = j + 2; // place on closing '>'
                                break;
                            }
                            j++;
                            p++;
                        }
                        break;
                    }
                    // Skip over HTML tag
                    if (isalpha(p[1]) || (p[1] == '/' && isalpha(p[2])))
                    {
                        size_t j = i + 2;
                        p += 2;
                        while (1)
                        {
                            if (j == slice.length)
                                break;
                            if (p[0] == '>')
                            {
                                i = j; // place on closing '>'
                                break;
                            }
                            j++;
                            p++;
                        }
                        break;
                    }
                }
            L1:
                // Replace '<' with '&lt;' character entity
                if (se)
                {
                    const len = strlen(se);
                    buf.remove(i, 1);
                    i = buf.insert(i, se, len);
                    i--; // point to ';'
                }
                break;
            }
        case '>':
            {
                leadingBlank = 0;
                if (inCode)
                    break;
                // Replace '>' with '&gt;' character entity
                const(char)* se = sc._module.escapetable.escapeChar('>');
                if (se)
                {
                    size_t len = strlen(se);
                    buf.remove(i, 1);
                    i = buf.insert(i, se, len);
                    i--; // point to ';'
                }
                break;
            }
        case '&':
            {
                leadingBlank = 0;
                if (inCode)
                    break;
                char* p = cast(char*)&buf.data[i];
                if (p[1] == '#' || isalpha(p[1]))
                    break;
                // already a character entity
                // Replace '&' with '&amp;' character entity
                const(char)* se = sc._module.escapetable.escapeChar('&');
                if (se)
                {
                    size_t len = strlen(se);
                    buf.remove(i, 1);
                    i = buf.insert(i, se, len);
                    i--; // point to ';'
                }
                break;
            }
        case '`':
            {
                if (inBacktick)
                {
                    inBacktick = 0;
                    inCode = 0;
                    OutBuffer codebuf;
                    codebuf.write(buf.peekSlice().ptr + iCodeStart + 1, i - (iCodeStart + 1));
                    // escape the contents, but do not perform highlighting except for DDOC_PSYMBOL
                    highlightCode(sc, a, &codebuf, 0);
                    buf.remove(iCodeStart, i - iCodeStart + 1); // also trimming off the current `
                    immutable pre = "$(DDOC_BACKQUOTED ";
                    i = buf.insert(iCodeStart, pre);
                    i = buf.insert(i, codebuf.peekSlice());
                    i = buf.insert(i, ")");
                    i--; // point to the ending ) so when the for loop does i++, it will see the next character
                    break;
                }
                if (inCode)
                    break;
                inCode = 1;
                inBacktick = 1;
                codeIndent = 0; // inline code is not indented
                // All we do here is set the code flags and record
                // the location. The macro will be inserted lazily
                // so we can easily cancel the inBacktick if we come
                // across a newline character.
                iCodeStart = i;
                break;
            }
        case '-':
            /* A line beginning with --- delimits a code section.
             * inCode tells us if it is start or end of a code section.
             */
            if (leadingBlank)
            {
                size_t istart = i;
                size_t eollen = 0;
                leadingBlank = 0;
                while (1)
                {
                    ++i;
                    if (i >= buf.offset)
                        break;
                    c = buf.data[i];
                    if (c == '\n')
                    {
                        eollen = 1;
                        break;
                    }
                    if (c == '\r')
                    {
                        eollen = 1;
                        if (i + 1 >= buf.offset)
                            break;
                        if (buf.data[i + 1] == '\n')
                        {
                            eollen = 2;
                            break;
                        }
                    }
                    // BUG: handle UTF PS and LS too
                    if (c != '-')
                        goto Lcont;
                }
                if (i - istart < 3)
                    goto Lcont;
                // We have the start/end of a code section
                // Remove the entire --- line, including blanks and \n
                buf.remove(iLineStart, i - iLineStart + eollen);
                i = iLineStart;
                if (inCode && (i <= iCodeStart))
                {
                    // Empty code section, just remove it completely.
                    inCode = 0;
                    break;
                }
                if (inCode)
                {
                    inCode = 0;
                    // The code section is from iCodeStart to i
                    OutBuffer codebuf;
                    codebuf.write(buf.data + iCodeStart, i - iCodeStart);
                    codebuf.writeByte(0);
                    // Remove leading indentations from all lines
                    bool lineStart = true;
                    char* endp = cast(char*)codebuf.data + codebuf.offset;
                    for (char* p = cast(char*)codebuf.data; p < endp;)
                    {
                        if (lineStart)
                        {
                            size_t j = codeIndent;
                            char* q = p;
                            while (j-- > 0 && q < endp && isIndentWS(q))
                                ++q;
                            codebuf.remove(p - cast(char*)codebuf.data, q - p);
                            assert(cast(char*)codebuf.data <= p);
                            assert(p < cast(char*)codebuf.data + codebuf.offset);
                            lineStart = false;
                            endp = cast(char*)codebuf.data + codebuf.offset; // update
                            continue;
                        }
                        if (*p == '\n')
                            lineStart = true;
                        ++p;
                    }
                    highlightCode2(sc, a, &codebuf, 0);
                    buf.remove(iCodeStart, i - iCodeStart);
                    i = buf.insert(iCodeStart, codebuf.peekSlice());
                    i = buf.insert(i, ")\n");
                    i -= 2; // in next loop, c should be '\n'
                }
                else
                {
                    static __gshared const(char)* d_code = "$(D_CODE ";
                    inCode = 1;
                    codeIndent = istart - iLineStart; // save indent count
                    i = buf.insert(i, d_code, strlen(d_code));
                    iCodeStart = i;
                    i--; // place i on >
                    leadingBlank = true;
                }
            }
            break;
        default:
            leadingBlank = 0;
            if (sc._module.isDocFile || inCode)
                break;
            const start = cast(char*)buf.data + i;
            if (isIdStart(start))
            {
                size_t j = skippastident(buf, i);
                if (i < j)
                {
                    size_t k = skippastURL(buf, i);
                    if (i < k)
                    {
                        i = k - 1;
                        break;
                    }
                }
                else
                    break;
                size_t len = j - i;
                // leading '_' means no highlight unless it's a reserved symbol name
                if (c == '_' && (i == 0 || !isdigit(*(start - 1))) && (i == buf.offset - 1 || !isReservedName(start, len)))
                {
                    buf.remove(i, 1);
                    i = j - 1;
                    break;
                }
                if (isIdentifier(a, start, len))
                {
                    i = buf.bracket(i, "$(DDOC_PSYMBOL ", j, ")") - 1;
                    break;
                }
                if (isKeyword(start, len))
                {
                    i = buf.bracket(i, "$(DDOC_KEYWORD ", j, ")") - 1;
                    break;
                }
                if (isFunctionParameter(a, start, len))
                {
                    //printf("highlighting arg '%s', i = %d, j = %d\n", arg->ident->toChars(), i, j);
                    i = buf.bracket(i, "$(DDOC_PARAM ", j, ")") - 1;
                    break;
                }
                i = j - 1;
            }
            break;
        }
    }
    if (inCode)
        error(s ? s.loc : Loc(), "unmatched --- in DDoc comment");
}

/**************************************************
 * Highlight code for DDOC section.
 */
extern (C++) void highlightCode(Scope* sc, Dsymbol s, OutBuffer* buf, size_t offset)
{
    //printf("highlightCode(s = %s '%s')\n", s->kind(), s->toChars());
    OutBuffer ancbuf;
    emitAnchor(&ancbuf, s, sc);
    buf.insert(offset, ancbuf.peekSlice());
    offset += ancbuf.offset;
    Dsymbols a;
    a.push(s);
    highlightCode(sc, &a, buf, offset);
}

/****************************************************
 */
extern (C++) void highlightCode(Scope* sc, Dsymbols* a, OutBuffer* buf, size_t offset)
{
    //printf("highlightCode(a = '%s')\n", a->toChars());
    bool resolvedTemplateParameters = false;

    for (size_t i = offset; i < buf.offset; i++)
    {
        char c = buf.data[i];
        const(char)* se = sc._module.escapetable.escapeChar(c);
        if (se)
        {
            size_t len = strlen(se);
            buf.remove(i, 1);
            i = buf.insert(i, se, len);
            i--; // point to ';'
            continue;
        }
        char* start = cast(char*)buf.data + i;
        if (isIdStart(start))
        {
            size_t j = skippastident(buf, i);
            if (i < j)
            {
                size_t len = j - i;
                if (isIdentifier(a, start, len))
                {
                    i = buf.bracket(i, "$(DDOC_PSYMBOL ", j, ")") - 1;
                    continue;
                }
                if (isFunctionParameter(a, start, len))
                {
                    //printf("highlighting arg '%s', i = %d, j = %d\n", arg->ident->toChars(), i, j);
                    i = buf.bracket(i, "$(DDOC_PARAM ", j, ")") - 1;
                    continue;
                }
                i = j - 1;
            }
        }
        else if (!resolvedTemplateParameters)
        {
            size_t previ = i;

            // hunt for template declarations:
            foreach (symi; 0 .. a.dim)
            {
                FuncDeclaration fd = (*a)[symi].isFuncDeclaration();

                if (!fd || !fd.parent || !fd.parent.isTemplateDeclaration())
                {
                    continue;
                }

                TemplateDeclaration td = fd.parent.isTemplateDeclaration();

                // build the template parameters
                Array!(size_t) paramLens;
                paramLens.reserve(td.parameters.dim);

                OutBuffer parametersBuf;
                HdrGenState hgs;

                parametersBuf.writeByte('(');

                foreach (parami; 0 .. td.parameters.dim)
                {
                    TemplateParameter tp = (*td.parameters)[parami];

                    if (parami)
                        parametersBuf.writestring(", ");

                    size_t lastOffset = parametersBuf.offset;

                    .toCBuffer(tp, &parametersBuf, &hgs);

                    paramLens[parami] = parametersBuf.offset - lastOffset;
                }
                parametersBuf.writeByte(')');

                const templateParams = parametersBuf.peekString();
                const templateParamsLen = parametersBuf.peekSlice().length;

                //printf("templateDecl: %s\ntemplateParams: %s\nstart: %s\n", td.toChars(), templateParams, start);

                if (cmp(templateParams, start, templateParamsLen) == 0)
                {
                    immutable templateParamListMacro = "$(DDOC_TEMPLATE_PARAM_LIST ";
                    buf.bracket(i, templateParamListMacro.ptr, i + templateParamsLen, ")");

                    // We have the parameter list. While we're here we might
                    // as well wrap the parameters themselves as well

                    // + 1 here to take into account the opening paren of the
                    // template param list
                    i += templateParamListMacro.length + 1;

                    foreach (const len; paramLens)
                    {
                        i = buf.bracket(i, "$(DDOC_TEMPLATE_PARAM ", i + len, ")");
                        // increment two here for space + comma
                        i += 2;
                    }

                    resolvedTemplateParameters = true;
                    // reset i to be positioned back before we found the template
                    // param list this assures that anything within the template
                    // param list that needs to be escaped or otherwise altered
                    // has an opportunity for that to happen outside of this context
                    i = previ;

                    continue;
                }
            }
        }
    }
}

/****************************************
 */
extern (C++) void highlightCode3(Scope* sc, OutBuffer* buf, const(char)* p, const(char)* pend)
{
    for (; p < pend; p++)
    {
        const(char)* s = sc._module.escapetable.escapeChar(*p);
        if (s)
            buf.writestring(s);
        else
            buf.writeByte(*p);
    }
}

/**************************************************
 * Highlight code for CODE section.
 */
extern (C++) void highlightCode2(Scope* sc, Dsymbols* a, OutBuffer* buf, size_t offset)
{
    uint errorsave = global.errors;
    scope Lexer lex = new Lexer(null, cast(char*)buf.data, 0, buf.offset - 1, 0, 1);
    OutBuffer res;
    const(char)* lastp = cast(char*)buf.data;
    //printf("highlightCode2('%.*s')\n", buf->offset - 1, buf->data);
    res.reserve(buf.offset);
    while (1)
    {
        Token tok;
        lex.scan(&tok);
        highlightCode3(sc, &res, lastp, tok.ptr);
        const(char)* highlight = null;
        switch (tok.value)
        {
        case TOKidentifier:
            {
                if (!sc)
                    break;
                size_t len = lex.p - tok.ptr;
                if (isIdentifier(a, tok.ptr, len))
                {
                    highlight = "$(D_PSYMBOL ";
                    break;
                }
                if (isFunctionParameter(a, tok.ptr, len))
                {
                    //printf("highlighting arg '%s', i = %d, j = %d\n", arg->ident->toChars(), i, j);
                    highlight = "$(D_PARAM ";
                    break;
                }
                break;
            }
        case TOKcomment:
            highlight = "$(D_COMMENT ";
            break;
        case TOKstring:
            highlight = "$(D_STRING ";
            break;
        default:
            if (tok.isKeyword())
                highlight = "$(D_KEYWORD ";
            break;
        }
        if (highlight)
        {
            res.writestring(highlight);
            size_t o = res.offset;
            highlightCode3(sc, &res, tok.ptr, lex.p);
            if (tok.value == TOKcomment || tok.value == TOKstring)
                escapeDdocString(&res, o); // Bugzilla 7656, 7715, and 10519
            res.writeByte(')');
        }
        else
            highlightCode3(sc, &res, tok.ptr, lex.p);
        if (tok.value == TOKeof)
            break;
        lastp = lex.p;
    }
    buf.setsize(offset);
    buf.write(&res);
    global.errors = errorsave;
}

/****************************************
 * Determine if p points to the start of a "..." parameter identifier.
 */
extern (C++) bool isCVariadicArg(const(char)* p, size_t len)
{
    return len >= 3 && cmp("...", p, 3) == 0;
}

/****************************************
 * Determine if p points to the start of an identifier.
 */
extern (C++) bool isIdStart(const(char)* p)
{
    dchar c = *p;
    if (isalpha(c) || c == '_')
        return true;
    if (c >= 0x80)
    {
        size_t i = 0;
        if (utf_decodeChar(p, 4, i, c))
            return false; // ignore errors
        if (isUniAlpha(c))
            return true;
    }
    return false;
}

/****************************************
 * Determine if p points to the rest of an identifier.
 */
extern (C++) bool isIdTail(const(char)* p)
{
    dchar c = *p;
    if (isalnum(c) || c == '_')
        return true;
    if (c >= 0x80)
    {
        size_t i = 0;
        if (utf_decodeChar(p, 4, i, c))
            return false; // ignore errors
        if (isUniAlpha(c))
            return true;
    }
    return false;
}

/****************************************
 * Determine if p points to the indentation space.
 */
extern (C++) bool isIndentWS(const(char)* p)
{
    return (*p == ' ') || (*p == '\t');
}

/*****************************************
 * Return number of bytes in UTF character.
 */
extern (C++) int utfStride(const(char)* p)
{
    dchar c = *p;
    if (c < 0x80)
        return 1;
    size_t i = 0;
    utf_decodeChar(p, 4, i, c); // ignore errors, but still consume input
    return cast(int)i;
}

inout(char)* stripLeadingNewlines(inout(char)* s)
{
    while (s && *s == '\n' || *s == '\r')
        s++;

    return s;
}
