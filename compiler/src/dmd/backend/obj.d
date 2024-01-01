/**
 * Compiler implementation of the
 * $(LINK2 https://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (C) 1994-1998 by Symantec
 *              Copyright (C) 2000-2024 by The D Language Foundation, All Rights Reserved
 * Authors:     $(LINK2 https://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 https://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/src/dmd/backend/obj.d, backend/obj.d)
 */

module dmd.backend.obj;

// Online documentation: https://dlang.org/phobos/dmd_backend_obj.html

/* Interface to object file format
 */

import dmd.backend.cdef;
import dmd.backend.cc;
import dmd.backend.code;
import dmd.backend.el;

import dmd.common.outbuffer;

nothrow:

version (Windows)
{
}
else version (Posix)
{
}
else
    static assert(0, "unsupported version");

/******************************************************************/

import dmd.backend.cgobj;
import dmd.backend.mscoffobj;
import dmd.backend.elfobj;
import dmd.backend.machobj;

/******************************************************************/

version (STUB)
{
    public import stubobj;
}
else
{
    /*******************************************
     * Generic interface to the four object module file formats supported.
     * Instead of using virtual functions (i.e. virtual dispatch) it uses
     * static dispatch. Since config.objfmt never changes after initialization
     * of the compiler, static branch prediction should make it faster than
     * virtual dispatch.
     *
     * Making static dispatch work requires tediously repetitive boilerplate,
     * which we accomplish via string mixins.
     */
    class Obj
    {
      static
      {
        nothrow:

        Obj initialize(OutBuffer* objbuf, const(char)* filename, const(char)* csegname)
        {
            mixin(genRetVal("init(objbuf, filename, csegname)"));
        }

        void initfile(const(char)* filename, const(char)* csegname, const(char)* modname)
        {
            mixin(genRetVal("initfile(filename, csegname, modname)"));
        }

        void termfile()
        {
            mixin(genRetVal("termfile()"));
        }

        void term(const(char)* objfilename)
        {
            mixin(genRetVal("term(objfilename)"));
        }

        size_t mangle(Symbol *s,char *dest)
        {
            assert(config.objfmt == OBJ_OMF);
            return OmfObj_mangle(s, dest);
        }

        void _import(elem *e)
        {
            assert(config.objfmt == OBJ_OMF);
            return OmfObj_import(e);
        }

        void linnum(Srcpos srcpos, int seg, targ_size_t offset)
        {
            mixin(genRetVal("linnum(srcpos, seg, offset)"));
        }

        int codeseg(const char *name,int suffix)
        {
            mixin(genRetVal("codeseg(name, suffix)"));
        }

        void dosseg()
        {
            assert(config.objfmt == OBJ_OMF);
            return OmfObj_dosseg();
        }

        void startaddress(Symbol *s)
        {
            mixin(genRetVal("startaddress(s)"));
        }

        bool includelib(scope const(char)[] name)
        {
            mixin(genRetVal("includelib(name)"));
        }

        bool linkerdirective(scope const(char)* p)
        {
            mixin(genRetVal("linkerdirective(p)"));
        }

        bool allowZeroSize()
        {
            mixin(genRetVal("allowZeroSize()"));
        }

        void exestr(const(char)* p)
        {
            mixin(genRetVal("exestr(p)"));
        }

        void user(const(char)* p)
        {
            mixin(genRetVal("user(p)"));
        }

        void compiler(const(char)* p)
        {
            mixin(genRetVal("compiler(p)"));
        }

        void wkext(Symbol* s1, Symbol* s2)
        {
            mixin(genRetVal("wkext(s1, s2)"));
        }

        void lzext(Symbol* s1, Symbol* s2)
        {
            assert(config.objfmt == OBJ_OMF);
            OmfObj_lzext(s1, s2);
        }

        void _alias(const(char)* n1,const(char)* n2)
        {
            mixin(genRetVal("alias(n1, n2)"));
        }

        void theadr(const(char)* modname)
        {
            assert(config.objfmt == OBJ_OMF);
            OmfObj_theadr(modname);
        }

        void segment_group(targ_size_t codesize, targ_size_t datasize, targ_size_t cdatasize, targ_size_t udatasize)
        {
            assert(config.objfmt == OBJ_OMF);
            OmfObj_segment_group(codesize, datasize, cdatasize, udatasize);
        }

        void staticctor(Symbol *s,int dtor,int seg)
        {
            mixin(genRetVal("staticctor(s, dtor, seg)"));
        }

        void staticdtor(Symbol *s)
        {
            mixin(genRetVal("staticdtor(s)"));
        }

        void setModuleCtorDtor(Symbol *s, bool isCtor)
        {
            mixin(genRetVal("setModuleCtorDtor(s, isCtor)"));
        }

        void ehtables(Symbol *sfunc,uint size,Symbol *ehsym)
        {
            mixin(genRetVal("ehtables(sfunc, size, ehsym)"));
        }

        void ehsections()
        {
            mixin(genRetVal("ehsections()"));
        }

        void moduleinfo(Symbol *scc)
        {
            mixin(genRetVal("moduleinfo(scc)"));
        }

        int comdat(Symbol *s)
        {
            mixin(genRetVal("comdat(s)"));
        }

        int comdatsize(Symbol *s, targ_size_t symsize)
        {
            mixin(genRetVal("comdatsize(s, symsize)"));
        }

        int readonly_comdat(Symbol *s)
        {
            mixin(genRetVal("comdat(s)"));
        }

        void setcodeseg(int seg)
        {
            mixin(genRetVal("setcodeseg(seg)"));
        }

        seg_data *tlsseg()
        {
            mixin(genRetVal("tlsseg()"));
        }

        seg_data *tlsseg_bss()
        {
            mixin(genRetVal("tlsseg_bss()"));
        }

        seg_data *tlsseg_data()
        {
            mixin(genRetVal("tlsseg_data()"));
        }

        int  fardata(char *name, targ_size_t size, targ_size_t *poffset)
        {
            assert(config.objfmt == OBJ_OMF);
            return OmfObj_fardata(name, size, poffset);
        }

        void export_symbol(Symbol *s, uint argsize)
        {
            mixin(genRetVal("export_symbol(s, argsize)"));
        }

        void pubdef(int seg, Symbol *s, targ_size_t offset)
        {
            mixin(genRetVal("pubdef(seg, s, offset)"));
        }

        void pubdefsize(int seg, Symbol *s, targ_size_t offset, targ_size_t symsize)
        {
            mixin(genRetVal("pubdefsize(seg, s, offset, symsize)"));
        }

        int external_def(const(char)* name)
        {
            mixin(genRetVal("external_def(name)"));
        }

        int data_start(Symbol *sdata, targ_size_t datasize, int seg)
        {
            mixin(genRetVal("data_start(sdata, datasize, seg)"));
        }

        int external(Symbol *s)
        {
            mixin(genRetVal("external(s)"));
        }

        int common_block(Symbol *s, targ_size_t size, targ_size_t count)
        {
            mixin(genRetVal("common_block(s, size, count)"));
        }

        int common_block(Symbol *s, int flag, targ_size_t size, targ_size_t count)
        {
            mixin(genRetVal("common_block(s, flag, size, count)"));
        }

        void lidata(int seg, targ_size_t offset, targ_size_t count)
        {
            mixin(genRetVal("lidata(seg, offset, count)"));
        }

        void write_zeros(seg_data *pseg, targ_size_t count)
        {
            mixin(genRetVal("write_zeros(pseg, count)"));
        }

        void write_byte(seg_data *pseg, uint _byte)
        {
            mixin(genRetVal("write_byte(pseg, _byte)"));
        }

        void write_bytes(seg_data *pseg, const(void[]) a)
        {
            mixin(genRetVal("write_bytes(pseg, a)"));
        }

        void _byte(int seg, targ_size_t offset, uint _byte)
        {
            mixin(genRetVal("byte(seg, offset, _byte)"));
        }

        size_t bytes(int seg, targ_size_t offset, size_t nbytes, const(void)* p)
        {
            mixin(genRetVal("bytes(seg, offset, nbytes, p)"));
        }

        void ledata(int seg, targ_size_t offset, targ_size_t data, uint lcfd, uint idx1, uint idx2)
        {
            assert(config.objfmt == OBJ_OMF);
            OmfObj_ledata(seg, offset, data, lcfd, idx1, idx2);
        }

        void reftodatseg(int seg, targ_size_t offset, targ_size_t val, uint targetdatum, int flags)
        {
            mixin(genRetVal("reftodatseg(seg, offset, val, targetdatum, flags)"));
        }

        void reftofarseg(int seg, targ_size_t offset, targ_size_t val, int farseg, int flags)
        {
            assert(config.objfmt == OBJ_OMF);
            OmfObj_reftofarseg(seg, offset, val, farseg, flags);
        }

        void reftocodeseg(int seg, targ_size_t offset, targ_size_t val)
        {
            mixin(genRetVal("reftocodeseg(seg, offset, val)"));
        }

        int reftoident(int seg, targ_size_t offset, Symbol *s, targ_size_t val, int flags)
        {
            mixin(genRetVal("reftoident(seg, offset, s, val, flags)"));
        }

        void far16thunk(Symbol *s)
        {
            mixin(genRetVal("far16thunk(s)"));
        }

        void fltused()
        {
            mixin(genRetVal("fltused()"));
        }

        int data_readonly(char *p, int len, int *pseg)
        {
            mixin(genRetVal("data_readonly(p, len, pseg)"));
        }

        int data_readonly(char *p, int len)
        {
            mixin(genRetVal("data_readonly(p, len)"));
        }

        int string_literal_segment(uint sz)
        {
            mixin(genRetVal("string_literal_segment(sz)"));
        }

        Symbol *sym_cdata(tym_t ty, char *p, int len)
        {
            mixin(genRetVal("sym_cdata(ty, p, len)"));
        }

        void func_start(Symbol *sfunc)
        {
            mixin(genRetVal("func_start(sfunc)"));
        }

        void func_term(Symbol *sfunc)
        {
            mixin(genRetVal("func_term(sfunc)"));
        }

        void write_pointerRef(Symbol* s, uint off)
        {
            mixin(genRetVal("write_pointerRef(s, off)"));
        }

        int jmpTableSegment(Symbol* s)
        {
            mixin(genRetVal("jmpTableSegment(s)"));
        }

        Symbol *tlv_bootstrap()
        {
            mixin(genRetVal("tlv_bootstrap()"));
        }

        void gotref(Symbol *s)
        {
            switch (config.objfmt)
            {
                case OBJ_ELF:     ElfObj_gotref(s); break;
                case OBJ_MACH:   MachObj_gotref(s); break;
                default:         assert(0);
            }
        }

        Symbol *getGOTsym()
        {
            switch (config.objfmt)
            {
                case OBJ_ELF:    return  ElfObj_getGOTsym();
                case OBJ_MACH:   return MachObj_getGOTsym();
                default:         assert(0);
            }
        }

        void refGOTsym()
        {
            switch (config.objfmt)
            {
                case OBJ_ELF:     ElfObj_refGOTsym(); break;
                case OBJ_MACH:   MachObj_refGOTsym(); break;
                default:         assert(0);
            }
        }

        int seg_debugT()           // where the symbolic debug type data goes
        {
            switch (config.objfmt)
            {
                case OBJ_MSCOFF: return MsCoffObj_seg_debugT();
                case OBJ_OMF:    return    OmfObj_seg_debugT();
                default:         assert(0);
            }
        }

        void write_long(int seg, targ_size_t offset, uint data, uint lcfd, uint idx1, uint idx2)
        {
            assert(config.objfmt == OBJ_OMF);
            return OmfObj_write_long(seg, offset, data, lcfd, idx1, idx2);
        }

        uint addstr(OutBuffer *strtab, const(char)* p)
        {
            switch (config.objfmt)
            {
                case OBJ_ELF:    return    ElfObj_addstr(strtab, p);
                case OBJ_MACH:   return   MachObj_addstr(strtab, p);
                default:         assert(0);
            }
        }

        int getsegment(const(char)* sectname, const(char)* segname, int align_, int flags)
        {
            assert(config.objfmt == OBJ_MACH);
            return MachObj_getsegment(sectname, segname, align_, flags);
        }

        int getsegment(const(char)* name, const(char)* suffix, int type, int flags, int  align_)
        {
            assert(config.objfmt == OBJ_ELF);
            return ElfObj_getsegment(name, suffix, type, flags, align_);
        }

        int getsegment(const(char)* sectname, uint flags)
        {
            assert(config.objfmt == OBJ_MSCOFF);
            return MsCoffObj_getsegment(sectname, flags);
        }

        void addrel(int seg, targ_size_t offset, Symbol *targsym, uint targseg, int rtype, int val = 0)
        {
            switch (config.objfmt)
            {
                case OBJ_MSCOFF: return MsCoffObj_addrel(seg, offset, targsym, targseg, rtype, val);
                case OBJ_MACH:   return   MachObj_addrel(seg, offset, targsym, targseg, rtype, val);
                default:         assert(0);
            }
        }

        void addrel(int seg, targ_size_t offset, uint type, uint symidx, targ_size_t val)
        {
            assert(config.objfmt == OBJ_ELF);
            return ElfObj_addrel(seg, offset, type, symidx, val);
        }

        size_t writerel(int targseg, size_t offset, uint type, uint symidx, targ_size_t val)
        {
            assert(config.objfmt == OBJ_ELF);
            return ElfObj_writerel(targseg, offset, type, symidx, val);
        }

        int  getsegment2(uint shtidx)
        {
            assert(config.objfmt == OBJ_MSCOFF);
            return MsCoffObj_getsegment2(shtidx);
        }

        uint addScnhdr(const(char)* scnhdr_name, uint flags)
        {
            assert(config.objfmt == OBJ_MSCOFF);
            return MsCoffObj_addScnhdr(scnhdr_name, flags);
        }

        int  seg_drectve()
        {
            assert(config.objfmt == OBJ_MSCOFF);
            return MsCoffObj_seg_drectve();
        }

        int  seg_pdata()
        {
            assert(config.objfmt == OBJ_MSCOFF);
            return MsCoffObj_seg_pdata();
        }

        int  seg_xdata()
        {
            assert(config.objfmt == OBJ_MSCOFF);
            return MsCoffObj_seg_xdata();
        }

        int  seg_pdata_comdat(Symbol *sfunc)
        {
            assert(config.objfmt == OBJ_MSCOFF);
            return MsCoffObj_seg_pdata_comdat(sfunc);
        }

        int  seg_xdata_comdat(Symbol *sfunc)
        {
            assert(config.objfmt == OBJ_MSCOFF);
            return MsCoffObj_seg_xdata_comdat(sfunc);
        }

        int  seg_debugS()
        {
            assert(config.objfmt == OBJ_MSCOFF);
            return MsCoffObj_seg_debugS();
        }

        int  seg_debugS_comdat(Symbol *sfunc)
        {
            assert(config.objfmt == OBJ_MSCOFF);
            return MsCoffObj_seg_debugS_comdat(sfunc);
        }
      }
    }
}

public import dmd.backend.var : objmod;

/*****************************************
 * Use to generate 4 function declarations, one for
 * each object file format supported.
 * Params:
 *      pattern = function declaration
 * Returns:
 *      declarations as a string suitable for mixin
 */
private extern (D)
string ObjMemDecl(string pattern)
{
    string r =
        gen(pattern,    "Omf") ~ ";\n" ~
        gen(pattern, "MsCoff") ~ ";\n" ~
        gen(pattern,    "Elf") ~ ";\n" ~
        gen(pattern,   "Mach") ~ ";\n";
    return r;
}

/****************************************
 * Generate boilerplate for static dispatch that
 * returns a value. Don't care about type of the value.
 * Params:
 *      arg = function name to be dispatched based on `objfmt`
 * Returns:
 *      mixin string with static dispatch
 */
private extern (D)
string genRetVal(string arg)
{
    return
    "
        switch (config.objfmt)
        {
            case OBJ_ELF:    return    ElfObj_"~arg~";
            case OBJ_MSCOFF: return MsCoffObj_"~arg~";
            case OBJ_OMF:    return    OmfObj_"~arg~";
            case OBJ_MACH:   return   MachObj_"~arg~";
            default:     assert(0);
        }
    ";
}

/****************************************
 * Generate boilerplate that replaces the single '$' in `pattern` with `arg`
 * Params:
 *      pattern = pattern to scan for '$'
 *      arg = string to insert where '$' is found
 * Returns:
 *      boilerplate string
 */
private extern (D)
string gen(string pattern, string arg)
{
    foreach (i; 0 .. pattern.length)
        if (pattern[i] == '$')
            return pattern[0 .. i] ~ arg ~ pattern[i + 1 .. $];
    assert(0);
}
