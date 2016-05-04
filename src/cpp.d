// Compiler implementation of the D programming language
// Copyright (c) 1999-2015 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// http://www.digitalmars.com
// Distributed under the Boost Software License, Version 1.0.
// http://www.boost.org/LICENSE_1_0.txt

module ddmd.cpp;

import core.stdc.ctype;
import core.stdc.stdio;

import ddmd.root.outbuffer;

import ddmd.aggregate;
import ddmd.arraytypes;
import ddmd.attrib;
import ddmd.dclass;
import ddmd.declaration;
import ddmd.denum;
import ddmd.dmodule;
import ddmd.dimport;
import ddmd.dstruct;
import ddmd.dsymbol;
import ddmd.dtemplate;
import ddmd.expression;
import ddmd.func;
import ddmd.globals;
import ddmd.identifier;
import ddmd.init;
import ddmd.mars;
import ddmd.mtype;
import ddmd.visitor;

/****************************************************
 */
void genCppFiles(OutBuffer* buf, Modules* ms)
{
    extern(C++) final class ToCppBuffer : Visitor
    {
        alias visit = super.visit;
    public:
        bool[void*] visited;
        bool[void*] forwarded;
        OutBuffer *fwdbuf;
        OutBuffer *donebuf;
        OutBuffer *buf;
        AggregateDeclaration ad;
        Identifier ident;

        this(OutBuffer* fwdbuf, OutBuffer* donebuf, OutBuffer* buf)
        {
            this.fwdbuf = fwdbuf;
            this.donebuf = donebuf;
            this.buf = buf;
        }

        override void visit(Dsymbol s)
        {
            buf.printf("// ignored %s %s\n\n", s.kind(), s.toPrettyChars());
        }

        override void visit(Import)
        {
        }

        override void visit(AttribDeclaration pd)
        {
            foreach (s; *pd.decl)
            {
                if (!ad && s.prot().kind < PROTpublic)
                    continue;
                s.accept(this);
            }
        }

        override void visit(Module m)
        {
            // printf("Module::ToCppBuffer() %s\n", m.toChars());

            foreach (s; *m.members)
            {
                if (s.prot().kind < PROTpublic)
                    continue;
                s.accept(this);
            }
        }

        override void visit(FuncDeclaration fd)
        {
            if (cast(void*)fd in visited)
                return;
            // printf("FuncDeclaration %s %s\n", fd.toPrettyChars(), fd.type.toChars());
            visited[cast(void*)fd] = true;

            auto tf = cast(TypeFunction)fd.type;
            assert(tf);
            if (tf.linkage != LINKc && tf.linkage != LINKcpp)
            {
                buf.printf("// ignoring function %s because of linkage\n", fd.toPrettyChars());
                visit(cast(Dsymbol)fd);
                return;
            }
            if (!tf.deco)
            {
                buf.printf("// ignoring function %s because semantic hasn't been run\n", fd.toPrettyChars());
                visit(cast(Dsymbol)fd);
                return;
            }
            if (!ad && !fd.fbody)
            {
                buf.printf("// ignoring function %s because it's extern\n", fd.toPrettyChars());
                visit(cast(Dsymbol)fd);
                return;
            }

            if (ad)
                buf.writestring("    ");
            if (tf.linkage == LINKc)
                buf.writestring("extern \"C\" ");
            if (!ad)
                buf.writestring("extern ");
            if (ad && fd.storage_class & STCstatic)
                buf.writestring("static ");
            if (ad && fd.vtblIndex != -1)
                buf.writestring("virtual ");
            funcToBuffer(tf, fd.ident);
            if (ad && tf.isConst())
                buf.writestring(" const");
            if (ad && fd.storage_class & STCabstract)
                buf.writestring(" = 0");
            buf.printf(";\n\n");
        }

        override void visit(VarDeclaration vd)
        {
            if (cast(void*)vd in visited)
                return;
            visited[cast(void*)vd] = true;
            if (vd.storage_class & STCmanifest &&
                vd.type.isintegral() &&
                vd._init && vd._init.isExpInitializer())
            {
                if (ad)
                    buf.writestring("    ");
                buf.writestring("#define ");
                // typeToBuffer(vd.type, vd.ident);
                buf.writestring(vd.ident.toChars());
                buf.writestring(" ");
                auto e = vd._init.toExpression();
                if (e.type.ty == Tbool)
                    buf.printf("%d", e.toInteger());
                else
                    vd._init.toExpression().accept(this);
                buf.writestring("\n\n");
                return;
            }

            if ((vd.linkage == LINKc || vd.linkage == LINKcpp) &&
                vd.storage_class & STCgshared)
            {
                if (ad)
                    buf.writestring("    ");
                if (vd.linkage == LINKc)
                    buf.writestring("extern \"C\" ");
                buf.writestring("extern ");
                if (ad && vd.isDataseg())
                    buf.writestring("static ");
                typeToBuffer(vd.type, vd.ident);
                buf.writestring(";\n\n");
                return;
            }

            if (ad && vd.type && vd.type.deco)
            {
                buf.writestring("    ");
                typeToBuffer(vd.type, vd.ident);
                buf.writestring(";\n");
                if (vd.type.ty == Tstruct)
                {
                    auto t = cast(TypeStruct)vd.type;
                    includeSymbol(t.sym);
                }
                return;
            }

            visit(cast(Dsymbol)vd);
        }

        override void visit(TypeInfoDeclaration)
        {
        }

        override void visit(AliasDeclaration ad)
        {
            if (auto t = ad.type)
            {
                if (t.ty == Tdelegate)
                {
                    visit(cast(Dsymbol)ad);
                    return;
                }
                buf.writestring("typedef ");
                typeToBuffer(t, ad.ident);
                buf.writestring(";\n\n");
                return;
            }
            if (!ad.aliassym)
            {
                printf("wtf\n");
                ad.print();
            }
            if (auto ti = ad.aliassym.isTemplateInstance())
            {
                visitTi(ti);
                return;
            }
            if (auto sd = ad.aliassym.isStructDeclaration())
            {
                buf.writestring("typedef ");
                sd.type.accept(this);
                buf.writestring(" ");
                buf.writestring(ad.ident.toChars());
                buf.writestring(";\n\n");
                return;
            }
            buf.printf("//Ignored %s %s\n", ad.aliassym.kind(), ad.aliassym.toPrettyChars());
            visit(cast(Dsymbol)ad);
        }

        override void visit(AnonDeclaration ad)
        {
            buf.writestring(ad.isunion ? "union" : "struct");
            buf.writestring("\n{\n");
            foreach (s; *ad.decl)
            {
                s.accept(this);
            }
            buf.writestring("};\n");
        }

        override void visit(StructDeclaration sd)
        {
            if (sd.isInstantiated())
                return;
            if (cast(void*)sd in visited)
                return;
            if (sd.getModule() && sd.getModule().isDRootModule())
                return;
            if (!sd.type || !sd.type.deco)
                return;
            visited[cast(void*)sd] = true;
            buf.writestring("struct ");
            buf.writestring(sd.ident.toChars());
            if (sd.members)
            {
                buf.writestring("\n{\n");
                auto save = ad;
                ad = sd;
                foreach (m; *sd.members)
                {
                    m.accept(this);
                }
                ad = save;
                // Generate default ctor
                buf.printf("    %s(", sd.ident.toChars());
                buf.printf(") {");
                size_t varCount;
                foreach (m; *sd.members)
                {
                    if (auto vd = m.isVarDeclaration())
                    {
                        if (!vd.type || !vd.type.deco || !vd.ident)
                            continue;
                        if (vd.type.ty == Tfunction)
                            continue;
                        if (vd.type.ty == Tsarray)
                            continue;
                        varCount++;
                        if (!vd._init && !vd.type.isTypeBasic())
                            continue;
                        buf.printf(" this->%s = ", vd.ident.toChars());
                        if (vd._init)
                            vd._init.toExpression().accept(this);
                        else if (vd.type.isTypeBasic())
                            vd.type.defaultInitLiteral(Loc()).accept(this);
                        buf.printf(";");
                    }
                }
                buf.printf("}\n");

                if (varCount)
                {
                    buf.printf("    %s(", sd.ident.toChars());
                    bool first = true;
                    foreach (m; *sd.members)
                    {
                        if (auto vd = m.isVarDeclaration())
                        {
                            if (vd.type.ty == Tsarray)
                                continue;
                            if (first)
                                first = false;
                            else
                                buf.writestring(", ");
                            assert(vd.type);
                            assert(vd.ident);
                            typeToBuffer(vd.type, vd.ident);
                        }
                    }
                    buf.printf(") {");
                    foreach (m; *sd.members)
                    {
                        if (auto vd = m.isVarDeclaration())
                        {
                            if (!vd.type || !vd.type.deco || !vd.ident)
                                continue;
                            if (vd.type.ty == Tfunction)
                                continue;
                            if (vd.type.ty == Tsarray)
                                continue;
                            buf.printf(" this->%s = %s;", vd.ident.toChars(), vd.ident.toChars());
                        }
                    }
                    buf.printf("}\n");
                }

                buf.writestring("};\n\n");
            }
            else
                buf.writestring(";\n\n");
        }

        void includeSymbol(Dsymbol ds)
        {
            // static int level;
            // printf("Forward declaring %s %d\n", ds.toChars(), level);
            if (cast(void*)ds !in visited)
            {
                // level++;
                // scope(exit) level--;
                // printf("Actually\n");

                OutBuffer decl;
                auto save = buf;
                buf = &decl;
                ds.accept(this);
                buf = save;
                donebuf.writestring(decl.peekString());
                // printf("FWD: %s\n", decl.peekString());
            }
            // else
                // printf("Already done\n");
        }

        override void visit(ClassDeclaration cd)
        {
            if (cast(void*)cd in visited)
                return;
            if (cd.getModule() && cd.getModule().isDRootModule())
                return;
            visited[cast(void*)cd] = true;
            if (!cd.isCPPclass())
            {
                buf.printf("// ignoring non-cpp class %s\n", cd.toChars());
                visit(cast(Dsymbol)cd);
                return;
            }

            buf.writestring("class ");
            buf.writestring(cd.ident.toChars());
            if (cd.baseClass)
            {
                buf.writestring(" : public ");
                buf.writestring(cd.baseClass.ident.toChars());

                includeSymbol(cd.baseClass);
            }
            if (cd.members)
            {
                buf.writestring("\n{\npublic:\n");
                auto save = ad;
                ad = cd;
                foreach (m; *cd.members)
                {
                    m.accept(this);
                }
                ad = save;
                buf.writestring("};\n\n");
            }
            else
                buf.writestring(";\n\n");
        }

        override void visit(EnumDeclaration ed)
        {
            if (cast(void*)ed in visited)
                return;
            visited[cast(void*)ed] = true;
            buf.writestring("enum");
            if (ed.ident)
            {
                buf.writeByte(' ');
                buf.writestring(ed.ident.toChars());
            }
            if (ed.members)
            {
                buf.writestring("\n{\n");
                foreach (i, m; *ed.members)
                {
                    if (i)
                        buf.writestring(",\n");
                    buf.writestring("    ");
                    m.accept(this);
                }
                buf.writestring("\n};\n\n");
            }
            else
                buf.writestring(";\n\n");
        }

        override void visit(EnumMember em)
        {
            buf.writestring(em.ident.toChars());
            buf.writestring(" = ");
            em.value.accept(this);
        }

        void typeToBuffer(Type t, Identifier ident)
        {
            this.ident = ident;
            t.accept(this);
            if (this.ident)
            {
                buf.writeByte(' ');
                buf.writestring(ident.toChars());
            }
            this.ident = null;
            if (t.ty == Tsarray)
            {
                auto tsa = cast(TypeSArray)t;
                buf.writeByte('[');
                tsa.dim.accept(this);
                buf.writeByte(']');
            }
        }

        override void visit(Type t)
        {
            printf("Invalid type: %s\n", t.toPrettyChars());
            assert(0);
        }

        override void visit(TypeBasic t)
        {
            if (t.mod & MODconst)
                buf.writestring("const ");
            switch (t.ty)
            {
            case Tbool, Tvoid:
            case Tchar, Twchar, Tdchar:
            case Tint8, Tuns8:
            case Tint16, Tuns16:
            case Tint32, Tuns32:
            case Tint64, Tuns64:
            case Tfloat32, Tfloat64, Tfloat80:
                buf.writestring("_d_");
                buf.writestring(t.dstring);
                break;
            default:
                t.print();
                assert(0);
            }
        }

        override void visit(TypePointer t)
        {
            t.next.accept(this);
            if (t.next.ty != Tfunction)
                buf.writeByte('*');
        }

        override void visit(TypeSArray t)
        {
            t.next.accept(this);
        }

        override void visit(TypeAArray t)
        {
            Type.tvoidptr.accept(this);
        }

        override void visit(TypeFunction tf)
        {
            tf.next.accept(this);
            buf.writeByte('(');
            buf.writeByte('*');
            if (ident)
                buf.writestring(ident.toChars());
            ident = null;
            buf.writeByte(')');
            buf.writeByte('(');
            foreach (i; 0 .. Parameter.dim(tf.parameters))
            {
                if (i)
                    buf.writestring(", ");
                auto fparam = Parameter.getNth(tf.parameters, i);
                fparam.accept(this);
            }
            if (tf.varargs)
            {
                if (tf.parameters.dim && tf.varargs == 1)
                    buf.writestring(", ");
                buf.writestring("...");
            }
            buf.writeByte(')');
        }

        override void visit(TypeEnum t)
        {
            if (cast(void*)t.sym !in forwarded)
            {
                forwarded[cast(void*)t.sym] = true;
                fwdbuf.writestring("enum ");
                fwdbuf.writestring(t.sym.toChars());
                fwdbuf.writestring(";\n");
            }

            buf.writestring(t.sym.toChars());
        }

        override void visit(TypeStruct t)
        {
            if (cast(void*)t.sym !in forwarded &&
                !t.sym.parent.isTemplateInstance())
            {
                forwarded[cast(void*)t.sym] = true;
                fwdbuf.writestring("struct ");
                fwdbuf.writestring(t.sym.toChars());
                fwdbuf.writestring(";\n");
            }

            if (auto ti = t.sym.parent.isTemplateInstance())
            {
                visitTi(ti);
                return;
            }
            buf.writestring(t.sym.toChars());
        }

        override void visit(TypeDArray t)
        {
            buf.writestring("DArray<");
            t.next.accept(this);
            buf.writestring(">");
        }

        void visitTi(TemplateInstance ti)
        {
            buf.writestring(ti.tempdecl.ident.toChars());
            buf.writeByte('<');
            foreach (i, o; *ti.tiargs)
            {
                if (i)
                    buf.writestring(", ");
                if (auto tt = isType(o))
                {
                    tt.accept(this);
                }
                else
                {
                    ti.print();
                    o.print();
                    assert(0);
                }
            }
            buf.writeByte('>');
        }

        override void visit(TypeClass t)
        {
            if (cast(void*)t.sym !in forwarded)
            {
                forwarded[cast(void*)t.sym] = true;
                fwdbuf.writestring("class ");
                fwdbuf.writestring(t.sym.toChars());
                fwdbuf.writestring(";\n");
            }

            buf.writestring(t.sym.toChars());
            buf.writeByte('*');
        }

        void funcToBuffer(TypeFunction tf, Identifier ident)
        {
            assert(tf.next);
            tf.next.accept(this);
            if (tf.isref)
                buf.writeByte('&');
            buf.writeByte(' ');
            buf.writestring(ident.toChars());

            buf.writeByte('(');
            foreach (i; 0 .. Parameter.dim(tf.parameters))
            {
                if (i)
                    buf.writestring(", ");
                auto fparam = Parameter.getNth(tf.parameters, i);
                fparam.accept(this);
            }
            if (tf.varargs)
            {
                if (tf.parameters.dim && tf.varargs == 1)
                    buf.writestring(", ");
                buf.writestring("...");
            }
            buf.writeByte(')');
        }

        override void visit(Parameter p)
        {
            ident = p.ident;
            if (p.type.mod & MODconst)
                buf.writestring("const ");
            p.type.accept(this);
            assert(!(p.storageClass & ~(STCref)));
            if (p.storageClass & STCref)
                buf.writeByte('&');
            buf.writeByte(' ');
            if (ident)
                buf.writestring(ident.toChars());
            ident = null;
            if (p.defaultArg)
            {
                // buf.writestring("/*");
                buf.writestring(" = ");
                p.defaultArg.accept(this);
                // buf.writestring("*/");
            }
        }

        override void visit(Expression e)
        {
            e.print();
            assert(0);
        }

        override void visit(NullExp e)
        {
            buf.writestring("_d_null");
        }

        override void visit(ArrayLiteralExp e)
        {
            buf.writestring("arrayliteral");
        }

        override void visit(StringExp e)
        {
            assert(e.sz == 1 || e.sz == 2);
            if (e.sz == 2)
                buf.writeByte('L');
            buf.writeByte('"');
            size_t o = buf.offset;
            for (size_t i = 0; i < e.len; i++)
            {
                uint c = e.charAt(i);
                switch (c)
                {
                case '"':
                case '\\':
                    buf.writeByte('\\');
                    goto default;
                default:
                    if (c <= 0xFF)
                    {
                        if (c <= 0x7F && isprint(c))
                            buf.writeByte(c);
                        else
                            buf.printf("\\x%02x", c);
                    }
                    else if (c <= 0xFFFF)
                        buf.printf("\\x%02x\\x%02x", c & 0xFF, c >> 8);
                    else
                        buf.printf("\\x%02x\\x%02x\\x%02x\\x%02x", c & 0xFF, (c >> 8) & 0xFF, (c >> 16) & 0xFF, c >> 24);
                    break;
                }
            }
            buf.writeByte('"');
        }

        override void visit(RealExp e)
        {
            buf.writestring("0");
        }

        override void visit(IntegerExp e)
        {
            visitInteger(e.toInteger, e.type);
        }

        void visitInteger(dinteger_t v, Type t)
        {
            switch (t.ty)
            {
            case Tenum:
                auto te = cast(TypeEnum)t;
                buf.printf("(%s)", te.sym.toChars());
                visitInteger(v, te.sym.memtype);
                break;
            case Tbool:
                buf.writestring(v ? "true" : "false");
                break;
            case Tint8:
                buf.printf("%d", cast(byte)v);
                break;
            case Tuns8:
            case Tchar:
                buf.printf("%uu", cast(ubyte)v);
                break;
            case Tint16:
                buf.printf("%d", cast(short)v);
                break;
            case Tuns16:
                buf.printf("%uu", cast(ushort)v);
                break;
            case Tint32:
                buf.printf("%d", cast(int)v);
                break;
            case Tuns32:
                buf.printf("%uu", cast(uint)v);
                break;
            case Tint64:
                buf.printf("%lldLL", v);
                break;
            case Tuns64:
                buf.printf("%lluLLU", v);
                break;
            default:
                t.print();
                assert(0);
            }
        }

        override void visit(StructLiteralExp sle)
        {
            buf.writestring(sle.sd.ident.toChars());
            buf.writeByte('(');
            foreach(i, e; *sle.elements)
            {
                if (i)
                    buf.writestring(", ");
                e.accept(this);
            }
            buf.writeByte(')');
        }
    }

    buf.writeByte('\n');
    buf.printf("// Automatically generated by DMD -C\n");
    buf.writeByte('\n');
    buf.writestring("#define _d_void void\n");
    buf.writestring("#define _d_bool bool\n");
    buf.writestring("#define _d_byte signed char\n");
    buf.writestring("#define _d_ubyte unsigned char\n");
    buf.writestring("#define _d_short short\n");
    buf.writestring("#define _d_ushort unsigned short\n");
    buf.writestring("#define _d_int int\n");
    buf.writestring("#define _d_uint unsigned\n");
    buf.writestring("#define _d_long long long\n");
    buf.writestring("#define _d_ulong unsigned long long\n");
    buf.writestring("#define _d_float float\n");
    buf.writestring("#define _d_double double\n");
    buf.writestring("#define _d_real long double\n");
    buf.writestring("#define _d_char char\n");
    buf.writestring("#define _d_wchar wchar_t\n");
    buf.writestring("#define _d_dchar unsigned\n");
    buf.writestring("\n");
    buf.writestring("#define _d_null NULL\n");
    buf.writestring("\n");
    buf.writestring("template<typename T>\n");
    buf.writestring("struct DArray\n");
    buf.writestring("{\n");
    buf.writestring("    size_t length;\n");
    buf.writestring("    T *ptr;\n");
    buf.writestring("};\n");
    buf.writestring("\n");

    OutBuffer done;
    OutBuffer decl;
    scope v = new ToCppBuffer(buf, &done, &decl);
    foreach (m; *ms)
        m.accept(v);
    buf.write(&done);
    buf.write(&decl);
}
