/**
 * Compiler implementation of the
 * $(LINK2 http://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (C) 1994-1998 by Symantec
 *              Copyright (C) 2000-2018 by The D Language Foundation, All Rights Reserved
 * Authors:     $(LINK2 http://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
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
import dmd.backend.outbuf;

extern (C++):

version (Windows)
{
    version (SCPP)
    {
        version = OMF;
    }
    version (SPP)
    {
        version = OMF;
    }
    version (HTOD)
    {
        version = STUB;
    }
    version (MARS)
    {
        version = OMFandMSCOFF;
    }
}

version (Windows)
{
    Obj  OmfObj_init(Outbuffer *, const(char)* filename, const(char)* csegname);
    void OmfObj_initfile(const(char)* filename, const(char)* csegname, const(char)* modname);
    void OmfObj_termfile();
    void OmfObj_term(const(char)* objfilename);
    size_t OmfObj_mangle(Symbol *s,char *dest);
    void OmfObj_import(elem *e);
    void OmfObj_linnum(Srcpos srcpos, int seg, targ_size_t offset);
    int  OmfObj_codeseg(char *name,int suffix);
    void OmfObj_dosseg();
    void OmfObj_startaddress(Symbol *);
    bool OmfObj_includelib(const(char)* );
    bool OmfObj_linkerdirective(const(char)* );
    bool OmfObj_allowZeroSize();
    void OmfObj_exestr(const(char)* p);
    void OmfObj_user(const(char)* p);
    void OmfObj_compiler();
    void OmfObj_wkext(Symbol *,Symbol *);
    void OmfObj_lzext(Symbol *,Symbol *);
    void OmfObj_alias(const(char)* n1,const(char)* n2);
    void OmfObj_theadr(const(char)* modname);
    void OmfObj_segment_group(targ_size_t codesize, targ_size_t datasize, targ_size_t cdatasize, targ_size_t udatasize);
    void OmfObj_staticctor(Symbol *s,int dtor,int seg);
    void OmfObj_staticdtor(Symbol *s);
    void OmfObj_setModuleCtorDtor(Symbol *s, bool isCtor);
    void OmfObj_ehtables(Symbol *sfunc,uint size,Symbol *ehsym);
    void OmfObj_ehsections();
    void OmfObj_moduleinfo(Symbol *scc);
    int  OmfObj_comdat(Symbol *);
    int  OmfObj_comdatsize(Symbol *, targ_size_t symsize);
    int  OmfObj_readonly_comdat(Symbol *s);
    void OmfObj_setcodeseg(int seg);
    seg_data* OmfObj_tlsseg();
    seg_data* OmfObj_tlsseg_bss();
    seg_data* OmfObj_tlsseg_data();
    int  OmfObj_fardata(char *name, targ_size_t size, targ_size_t *poffset);
    void OmfObj_export_symbol(Symbol *s, uint argsize);
    void OmfObj_pubdef(int seg, Symbol *s, targ_size_t offset);
    void OmfObj_pubdefsize(int seg, Symbol *s, targ_size_t offset, targ_size_t symsize);
    int  OmfObj_external_def(const(char)* );
    int  OmfObj_data_start(Symbol *sdata, targ_size_t datasize, int seg);
    int  OmfObj_external(Symbol *);
    int  OmfObj_common_block(Symbol *s, targ_size_t size, targ_size_t count);
    int  OmfObj_common_block(Symbol *s, int flag, targ_size_t size, targ_size_t count);
    void OmfObj_lidata(int seg, targ_size_t offset, targ_size_t count);
    void OmfObj_write_zeros(seg_data *pseg, targ_size_t count);
    void OmfObj_write_byte(seg_data *pseg, uint _byte);
    void OmfObj_write_bytes(seg_data *pseg, uint nbytes, void *p);
    void OmfObj_byte(int seg, targ_size_t offset, uint _byte);
    uint OmfObj_bytes(int seg, targ_size_t offset, uint nbytes, void *p);
    void OmfObj_ledata(int seg, targ_size_t offset, targ_size_t data, uint lcfd, uint idx1, uint idx2);
    void OmfObj_write_long(int seg, targ_size_t offset, uint data, uint lcfd, uint idx1, uint idx2);
    void OmfObj_reftodatseg(int seg, targ_size_t offset, targ_size_t val, uint targetdatum, int flags);
    void OmfObj_reftofarseg(int seg, targ_size_t offset, targ_size_t val, int farseg, int flags);
    void OmfObj_reftocodeseg(int seg, targ_size_t offset, targ_size_t val);
    int  OmfObj_reftoident(int seg, targ_size_t offset, Symbol *s, targ_size_t val, int flags);
    void OmfObj_far16thunk(Symbol *s);
    void OmfObj_fltused();
    int  OmfObj_data_readonly(char *p, int len, int *pseg);
    int  OmfObj_data_readonly(char *p, int len);
    int  OmfObj_string_literal_segment(uint sz);
    Symbol* OmfObj_sym_cdata(tym_t, char *, int);
    void OmfObj_func_start(Symbol *sfunc);
    void OmfObj_func_term(Symbol *sfunc);
    void OmfObj_write_pointerRef(Symbol* s, uint off);
    int  OmfObj_jmpTableSegment(Symbol* s);
    Symbol* OmfObj_tlv_bootstrap();
    void OmfObj_gotref(Symbol *s);
    int  OmfObj_seg_debugT();           // where the symbolic debug type data goes

    Obj  MsCoffObj_init(Outbuffer *, const(char)* filename, const(char)* csegname);
    void MsCoffObj_initfile(const(char)* filename, const(char)* csegname, const(char)* modname);
    void MsCoffObj_termfile();
    void MsCoffObj_term(const(char)* objfilename);
//    size_t MsCoffObj_mangle(Symbol *s,char *dest);
//    void MsCoffObj_import(elem *e);
    void MsCoffObj_linnum(Srcpos srcpos, int seg, targ_size_t offset);
    int  MsCoffObj_codeseg(char *name,int suffix);
//    void MsCoffObj_dosseg();
    void MsCoffObj_startaddress(Symbol *);
    bool MsCoffObj_includelib(const(char)* );
    bool MsCoffObj_linkerdirective(const(char)* );
    bool MsCoffObj_allowZeroSize();
    void MsCoffObj_exestr(const(char)* p);
    void MsCoffObj_user(const(char)* p);
    void MsCoffObj_compiler();
    void MsCoffObj_wkext(Symbol *,Symbol *);
//    void MsCoffObj_lzext(Symbol *,Symbol *);
    void MsCoffObj_alias(const(char)* n1,const(char)* n2);
//    void MsCoffObj_theadr(const(char)* modname);
//    void MsCoffObj_segment_group(targ_size_t codesize, targ_size_t datasize, targ_size_t cdatasize, targ_size_t udatasize);
    void MsCoffObj_staticctor(Symbol *s,int dtor,int seg);
    void MsCoffObj_staticdtor(Symbol *s);
    void MsCoffObj_setModuleCtorDtor(Symbol *s, bool isCtor);
    void MsCoffObj_ehtables(Symbol *sfunc,uint size,Symbol *ehsym);
    void MsCoffObj_ehsections();
    void MsCoffObj_moduleinfo(Symbol *scc);
    int  MsCoffObj_comdat(Symbol *);
    int  MsCoffObj_comdatsize(Symbol *, targ_size_t symsize);
    int  MsCoffObj_readonly_comdat(Symbol *s);
    void MsCoffObj_setcodeseg(int seg);
    seg_data* MsCoffObj_tlsseg();
    seg_data* MsCoffObj_tlsseg_bss();
    seg_data* MsCoffObj_tlsseg_data();
//    int  MsCoffObj_fardata(char *name, targ_size_t size, targ_size_t *poffset);
    void MsCoffObj_export_symbol(Symbol *s, uint argsize);
    void MsCoffObj_pubdef(int seg, Symbol *s, targ_size_t offset);
    void MsCoffObj_pubdefsize(int seg, Symbol *s, targ_size_t offset, targ_size_t symsize);
    int  MsCoffObj_external_def(const(char)* );
    int  MsCoffObj_data_start(Symbol *sdata, targ_size_t datasize, int seg);
    int  MsCoffObj_external(Symbol *);
    int  MsCoffObj_common_block(Symbol *s, targ_size_t size, targ_size_t count);
    int  MsCoffObj_common_block(Symbol *s, int flag, targ_size_t size, targ_size_t count);
    void MsCoffObj_lidata(int seg, targ_size_t offset, targ_size_t count);
    void MsCoffObj_write_zeros(seg_data *pseg, targ_size_t count);
    void MsCoffObj_write_byte(seg_data *pseg, uint _byte);
    void MsCoffObj_write_bytes(seg_data *pseg, uint nbytes, void *p);
    void MsCoffObj_byte(int seg, targ_size_t offset, uint _byte);
    uint MsCoffObj_bytes(int seg, targ_size_t offset, uint nbytes, void *p);
//    void MsCoffObj_ledata(int seg, targ_size_t offset, targ_size_t data, uint lcfd, uint idx1, uint idx2);
//    void MsCoffObj_write_long(int seg, targ_size_t offset, uint data, uint lcfd, uint idx1, uint idx2);
    void MsCoffObj_reftodatseg(int seg, targ_size_t offset, targ_size_t val, uint targetdatum, int flags);
//    void MsCoffObj_reftofarseg(int seg, targ_size_t offset, targ_size_t val, int farseg, int flags);
    void MsCoffObj_reftocodeseg(int seg, targ_size_t offset, targ_size_t val);
    int  MsCoffObj_reftoident(int seg, targ_size_t offset, Symbol *s, targ_size_t val, int flags);
    void MsCoffObj_far16thunk(Symbol *s);
    void MsCoffObj_fltused();
    int  MsCoffObj_data_readonly(char *p, int len, int *pseg);
    int  MsCoffObj_data_readonly(char *p, int len);
    int  MsCoffObj_string_literal_segment(uint sz);
    Symbol* MsCoffObj_sym_cdata(tym_t, char *, int);
    void MsCoffObj_func_start(Symbol *sfunc);
    void MsCoffObj_func_term(Symbol *sfunc);
    void MsCoffObj_write_pointerRef(Symbol* s, uint off);
    int  MsCoffObj_jmpTableSegment(Symbol* s);
    Symbol* MsCoffObj_tlv_bootstrap();
//    void MsCoffObj_gotref(Symbol *s);
    int  MsCoffObj_seg_debugT();           // where the symbolic debug type data goes

    int  MsCoffObj_getsegment(const(char)* sectname, uint flags);
    int  MsCoffObj_getsegment2( uint shtidx);
    uint MsCoffObj_addScnhdr(const(char)* scnhdr_name, uint flags);
    void MsCoffObj_addrel(int seg, targ_size_t offset, Symbol *targsym,
                          uint targseg, int rtype, int val);
    int  MsCoffObj_seg_drectve();
    int  MsCoffObj_seg_pdata();
    int  MsCoffObj_seg_xdata();
    int  MsCoffObj_seg_pdata_comdat(Symbol *sfunc);
    int  MsCoffObj_seg_xdata_comdat(Symbol *sfunc);
    int  MsCoffObj_seg_debugS();
    int  MsCoffObj_seg_debugS_comdat(Symbol *sfunc);
}

version (OMF)
{
    class Obj
    {
      static
      {
        Obj init(Outbuffer* objbuf, const(char)* filename, const(char)* csegname)
        {
            return OmfObj_init(objbuf, filename, csegname);
        }

        void initfile(const(char)* filename, const(char)* csegname, const(char)* modname)
        {
            return OmfObj_initfile(filename, csegname, modname);
        }

        void termfile()
        {
            return OmfObj_termfile();
        }

        void term(const(char)* objfilename)
        {
            return OmfObj_term(objfilename);
        }

        size_t mangle(Symbol *s,char *dest)
        {
            return OmfObj_mangle(s, dest);
        }

        void _import(elem *e)
        {
            return OmfObj_import(e);
        }

        void linnum(Srcpos srcpos, int seg, targ_size_t offset)
        {
            return OmfObj_linnum(srcpos, seg, offset);
        }

        int codeseg(char *name,int suffix)
        {
            return OmfObj_codeseg(name, suffix);
        }

        void dosseg()
        {
            return OmfObj_dosseg();
        }

        void startaddress(Symbol *s)
        {
            return OmfObj_startaddress(s);
        }

        bool includelib(const(char)* name)
        {
            return OmfObj_includelib(name);
        }

        bool linkerdirective(const(char)* p)
        {
            return OmfObj_linkerdirective(p);
        }

        bool allowZeroSize()
        {
            return OmfObj_allowZeroSize();
        }

        void exestr(const(char)* p)
        {
            return OmfObj_exestr(p);
        }

        void user(const(char)* p)
        {
            return OmfObj_user(p);
        }

        void compiler()
        {
            return OmfObj_compiler();
        }

        void wkext(Symbol* s1, Symbol* s2)
        {
            return OmfObj_wkext(s1, s2);
        }

        void lzext(Symbol* s1, Symbol* s2)
        {
            return OmfObj_lzext(s1, s2);
        }

        void _alias(const(char)* n1,const(char)* n2)
        {
            return OmfObj_alias(n1, n2);
        }

        void theadr(const(char)* modname)
        {
            return OmfObj_theadr(modname);
        }

        void segment_group(targ_size_t codesize, targ_size_t datasize, targ_size_t cdatasize, targ_size_t udatasize)
        {
            return OmfObj_segment_group(codesize, datasize, cdatasize, udatasize);
        }

        void staticctor(Symbol *s,int dtor,int seg)
        {
            return OmfObj_staticctor(s, dtor, seg);
        }

        void staticdtor(Symbol *s)
        {
            return OmfObj_staticdtor(s);
        }

        void setModuleCtorDtor(Symbol *s, bool isCtor)
        {
            return OmfObj_setModuleCtorDtor(s, isCtor);
        }

        void ehtables(Symbol *sfunc,uint size,Symbol *ehsym)
        {
            return OmfObj_ehtables(sfunc, size, ehsym);
        }

        void ehsections()
        {
            return OmfObj_ehsections();
        }

        void moduleinfo(Symbol *scc)
        {
            return OmfObj_moduleinfo(scc);
        }

        int comdat(Symbol *s)
        {
            return OmfObj_comdat(s);
        }

        int comdatsize(Symbol *s, targ_size_t symsize)
        {
            return OmfObj_comdatsize(s, symsize);
        }

        int readonly_comdat(Symbol *s)
        {
            return OmfObj_comdat(s);
        }

        void setcodeseg(int seg)
        {
            return OmfObj_setcodeseg(seg);
        }

        seg_data *tlsseg()
        {
            return OmfObj_tlsseg();
        }

        seg_data *tlsseg_bss()
        {
            return OmfObj_tlsseg_bss();
        }

        seg_data *tlsseg_data()
        {
            return OmfObj_tlsseg_data();
        }

        int  fardata(char *name, targ_size_t size, targ_size_t *poffset)
        {
            return OmfObj_fardata(name, size, poffset);
        }

        void export_symbol(Symbol *s, uint argsize)
        {
            return OmfObj_export_symbol(s, argsize);
        }

        void pubdef(int seg, Symbol *s, targ_size_t offset)
        {
            return OmfObj_pubdef(seg, s, offset);
        }

        void pubdefsize(int seg, Symbol *s, targ_size_t offset, targ_size_t symsize)
        {
            return OmfObj_pubdefsize(seg, s, offset, symsize);
        }

        int external_def(const(char)* name)
        {
            return OmfObj_external_def(name);
        }

        int data_start(Symbol *sdata, targ_size_t datasize, int seg)
        {
            return OmfObj_data_start(sdata, datasize, seg);
        }

        int external(Symbol *s)
        {
            return OmfObj_external(s);
        }

        int common_block(Symbol *s, targ_size_t size, targ_size_t count)
        {
            return OmfObj_common_block(s, size, count);
        }

        int common_block(Symbol *s, int flag, targ_size_t size, targ_size_t count)
        {
            return OmfObj_common_block(s, flag, size, count);
        }

        void lidata(int seg, targ_size_t offset, targ_size_t count)
        {
            return OmfObj_lidata(seg, offset, count);
        }

        void write_zeros(seg_data *pseg, targ_size_t count)
        {
            return OmfObj_write_zeros(pseg, count);
        }

        void write_byte(seg_data *pseg, uint _byte)
        {
            return OmfObj_write_byte(pseg, _byte);
        }

        void write_bytes(seg_data *pseg, uint nbytes, void *p)
        {
            return OmfObj_write_bytes(pseg, nbytes, p);
        }

        void _byte(int seg, targ_size_t offset, uint _byte)
        {
            return OmfObj_byte(seg, offset, _byte);
        }

        uint bytes(int seg, targ_size_t offset, uint nbytes, void *p)
        {
            return OmfObj_bytes(seg, offset, nbytes, p);
        }

        void ledata(int seg, targ_size_t offset, targ_size_t data, uint lcfd, uint idx1, uint idx2)
        {
            return OmfObj_ledata(seg, offset, data, lcfd, idx1, idx2);
        }

        void write_long(int seg, targ_size_t offset, uint data, uint lcfd, uint idx1, uint idx2)
        {
            return OmfObj_write_long(seg, offset, data, lcfd, idx1, idx2);
        }

        void reftodatseg(int seg, targ_size_t offset, targ_size_t val, uint targetdatum, int flags)
        {
            return OmfObj_reftodatseg(seg, offset, val, targetdatum, flags);
        }

        void reftofarseg(int seg, targ_size_t offset, targ_size_t val, int farseg, int flags)
        {
            return OmfObj_reftofarseg(seg, offset, val, farseg, flags);
        }

        void reftocodeseg(int seg, targ_size_t offset, targ_size_t val)
        {
            return OmfObj_reftocodeseg(seg, offset, val);
        }

        int reftoident(int seg, targ_size_t offset, Symbol *s, targ_size_t val, int flags)
        {
            return OmfObj_reftoident(seg, offset, s, val, flags);
        }

        void far16thunk(Symbol *s)
        {
            return OmfObj_far16thunk(s);
        }

        void fltused()
        {
            return OmfObj_fltused();
        }

        int data_readonly(char *p, int len, int *pseg)
        {
            return OmfObj_data_readonly(p, len, pseg);
        }

        int data_readonly(char *p, int len)
        {
            return OmfObj_data_readonly(p, len);
        }

        int string_literal_segment(uint sz)
        {
            return OmfObj_string_literal_segment(sz);
        }

        Symbol *sym_cdata(tym_t ty, char *p, int len)
        {
            return OmfObj_sym_cdata(ty, p, len);
        }

        void func_start(Symbol *sfunc)
        {
            return OmfObj_func_start(sfunc);
        }

        void func_term(Symbol *sfunc)
        {
            return OmfObj_func_term(sfunc);
        }

        void write_pointerRef(Symbol* s, uint off)
        {
            return OmfObj_write_pointerRef(s, off);
        }

        int jmpTableSegment(Symbol* s)
        {
            return OmfObj_jmpTableSegment(s);
        }

        Symbol *tlv_bootstrap()
        {
            return OmfObj_tlv_bootstrap();
        }

        void gotref(Symbol *s)
        {
            return OmfObj_gotref(s);
        }

        int seg_debugT()           // where the symbolic debug type data goes
        {
            return OmfObj_seg_debugT();
        }

      }
    }
}
else version (OMFandMSCOFF)
{
    class Obj
    {
      static
      {
        Obj init(Outbuffer* objbuf, const(char)* filename, const(char)* csegname)
        {
            return config.objfmt == OBJ_MSCOFF
                ? MsCoffObj_init(objbuf, filename, csegname)
                :    OmfObj_init(objbuf, filename, csegname);
        }

        void initfile(const(char)* filename, const(char)* csegname, const(char)* modname)
        {
            return config.objfmt == OBJ_MSCOFF
                ? MsCoffObj_initfile(filename, csegname, modname)
                :    OmfObj_initfile(filename, csegname, modname);
        }

        void termfile()
        {
            return config.objfmt == OBJ_MSCOFF
                ? MsCoffObj_termfile()
                :    OmfObj_termfile();
        }

        void term(const(char)* objfilename)
        {
            return config.objfmt == OBJ_MSCOFF
                ? MsCoffObj_term(objfilename)
                :    OmfObj_term(objfilename);
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
            return config.objfmt == OBJ_MSCOFF
                ? MsCoffObj_linnum(srcpos, seg, offset)
                :    OmfObj_linnum(srcpos, seg, offset);
        }

        int codeseg(char *name,int suffix)
        {
            return config.objfmt == OBJ_MSCOFF
                ? MsCoffObj_codeseg(name, suffix)
                :    OmfObj_codeseg(name, suffix);
        }

        void dosseg()
        {
            assert(config.objfmt == OBJ_OMF);
            return OmfObj_dosseg();
        }

        void startaddress(Symbol *s)
        {
            return config.objfmt == OBJ_MSCOFF
                ? MsCoffObj_startaddress(s)
                :    OmfObj_startaddress(s);
        }

        bool includelib(const(char)* name)
        {
            return config.objfmt == OBJ_MSCOFF
                ? MsCoffObj_includelib(name)
                :    OmfObj_includelib(name);
        }

        bool linkerdirective(const(char)* p)
        {
            return config.objfmt == OBJ_MSCOFF
                ? MsCoffObj_linkerdirective(p)
                :    OmfObj_linkerdirective(p);
        }

        bool allowZeroSize()
        {
            return config.objfmt == OBJ_MSCOFF
                ? MsCoffObj_allowZeroSize()
                :    OmfObj_allowZeroSize();
        }

        void exestr(const(char)* p)
        {
            return config.objfmt == OBJ_MSCOFF
                ? MsCoffObj_exestr(p)
                :    OmfObj_exestr(p);
        }

        void user(const(char)* p)
        {
            return config.objfmt == OBJ_MSCOFF
                ? MsCoffObj_user(p)
                :    OmfObj_user(p);
        }

        void compiler()
        {
            return config.objfmt == OBJ_MSCOFF
                ? MsCoffObj_compiler()
                :    OmfObj_compiler();
        }

        void wkext(Symbol* s1, Symbol* s2)
        {
            return config.objfmt == OBJ_MSCOFF
                ? MsCoffObj_wkext(s1, s2)
                :    OmfObj_wkext(s1, s2);
        }

        void lzext(Symbol* s1, Symbol* s2)
        {
            return config.objfmt == OBJ_MSCOFF
                ? assert(0)
                : OmfObj_lzext(s1, s2);
        }

        void _alias(const(char)* n1,const(char)* n2)
        {
            return config.objfmt == OBJ_MSCOFF
                ? MsCoffObj_alias(n1, n2)
                :    OmfObj_alias(n1, n2);
        }

        void theadr(const(char)* modname)
        {
            return config.objfmt == OBJ_MSCOFF
                ? assert(0)
                : OmfObj_theadr(modname);
        }

        void segment_group(targ_size_t codesize, targ_size_t datasize, targ_size_t cdatasize, targ_size_t udatasize)
        {
            return config.objfmt == OBJ_MSCOFF
                ? assert(0)
                : OmfObj_segment_group(codesize, datasize, cdatasize, udatasize);
        }

        void staticctor(Symbol *s,int dtor,int seg)
        {
            return config.objfmt == OBJ_MSCOFF
                ? MsCoffObj_staticctor(s, dtor, seg)
                :    OmfObj_staticctor(s, dtor, seg);
        }

        void staticdtor(Symbol *s)
        {
            return config.objfmt == OBJ_MSCOFF
                ? MsCoffObj_staticdtor(s)
                :    OmfObj_staticdtor(s);
        }

        void setModuleCtorDtor(Symbol *s, bool isCtor)
        {
            return config.objfmt == OBJ_MSCOFF
                ? MsCoffObj_setModuleCtorDtor(s, isCtor)
                :    OmfObj_setModuleCtorDtor(s, isCtor);
        }

        void ehtables(Symbol *sfunc,uint size,Symbol *ehsym)
        {
            return config.objfmt == OBJ_MSCOFF
                ? MsCoffObj_ehtables(sfunc, size, ehsym)
                :    OmfObj_ehtables(sfunc, size, ehsym);
        }

        void ehsections()
        {
            return config.objfmt == OBJ_MSCOFF
                ? MsCoffObj_ehsections()
                :    OmfObj_ehsections();
        }

        void moduleinfo(Symbol *scc)
        {
            return config.objfmt == OBJ_MSCOFF
                ? MsCoffObj_moduleinfo(scc)
                :    OmfObj_moduleinfo(scc);
        }

        int comdat(Symbol *s)
        {
            return config.objfmt == OBJ_MSCOFF
                ? MsCoffObj_comdat(s)
                :    OmfObj_comdat(s);
        }

        int comdatsize(Symbol *s, targ_size_t symsize)
        {
            return config.objfmt == OBJ_MSCOFF
                ? MsCoffObj_comdatsize(s, symsize)
                :    OmfObj_comdatsize(s, symsize);
        }

        int readonly_comdat(Symbol *s)
        {
            return config.objfmt == OBJ_MSCOFF
                ? MsCoffObj_comdat(s)
                :    OmfObj_comdat(s);
        }

        void setcodeseg(int seg)
        {
            return config.objfmt == OBJ_MSCOFF
                ? MsCoffObj_setcodeseg(seg)
                :    OmfObj_setcodeseg(seg);
        }

        seg_data *tlsseg()
        {
            return config.objfmt == OBJ_MSCOFF
                ? MsCoffObj_tlsseg()
                :    OmfObj_tlsseg();
        }

        seg_data *tlsseg_bss()
        {
            return config.objfmt == OBJ_MSCOFF
                ? MsCoffObj_tlsseg_bss()
                :    OmfObj_tlsseg_bss();
        }

        seg_data *tlsseg_data()
        {
            return config.objfmt == OBJ_MSCOFF
                ? MsCoffObj_tlsseg_data()
                :    OmfObj_tlsseg_data();
        }

        int  fardata(char *name, targ_size_t size, targ_size_t *poffset)
        {
            assert(config.objfmt == OBJ_OMF);
            return OmfObj_fardata(name, size, poffset);
        }

        void export_symbol(Symbol *s, uint argsize)
        {
            return config.objfmt == OBJ_MSCOFF
                ? MsCoffObj_export_symbol(s, argsize)
                :    OmfObj_export_symbol(s, argsize);
        }

        void pubdef(int seg, Symbol *s, targ_size_t offset)
        {
            return config.objfmt == OBJ_MSCOFF
                ? MsCoffObj_pubdef(seg, s, offset)
                :    OmfObj_pubdef(seg, s, offset);
        }

        void pubdefsize(int seg, Symbol *s, targ_size_t offset, targ_size_t symsize)
        {
            return config.objfmt == OBJ_MSCOFF
                ? MsCoffObj_pubdefsize(seg, s, offset, symsize)
                :    OmfObj_pubdefsize(seg, s, offset, symsize);
        }

        int external_def(const(char)* name)
        {
            return config.objfmt == OBJ_MSCOFF
                ? MsCoffObj_external_def(name)
                :    OmfObj_external_def(name);
        }

        int data_start(Symbol *sdata, targ_size_t datasize, int seg)
        {
            return config.objfmt == OBJ_MSCOFF
                ? MsCoffObj_data_start(sdata, datasize, seg)
                :    OmfObj_data_start(sdata, datasize, seg);
        }

        int external(Symbol *s)
        {
            return config.objfmt == OBJ_MSCOFF
                ? MsCoffObj_external(s)
                :    OmfObj_external(s);
        }

        int common_block(Symbol *s, targ_size_t size, targ_size_t count)
        {
            return config.objfmt == OBJ_MSCOFF
                ? MsCoffObj_common_block(s, size, count)
                :    OmfObj_common_block(s, size, count);
        }

        int common_block(Symbol *s, int flag, targ_size_t size, targ_size_t count)
        {
            return config.objfmt == OBJ_MSCOFF
                ? MsCoffObj_common_block(s, flag, size, count)
                :    OmfObj_common_block(s, flag, size, count);
        }

        void lidata(int seg, targ_size_t offset, targ_size_t count)
        {
            return config.objfmt == OBJ_MSCOFF
                ? MsCoffObj_lidata(seg, offset, count)
                :    OmfObj_lidata(seg, offset, count);
        }

        void write_zeros(seg_data *pseg, targ_size_t count)
        {
            return config.objfmt == OBJ_MSCOFF
                ? MsCoffObj_write_zeros(pseg, count)
                :    OmfObj_write_zeros(pseg, count);
        }

        void write_byte(seg_data *pseg, uint _byte)
        {
            return config.objfmt == OBJ_MSCOFF
                ? MsCoffObj_write_byte(pseg, _byte)
                :    OmfObj_write_byte(pseg, _byte);
        }

        void write_bytes(seg_data *pseg, uint nbytes, void *p)
        {
            return config.objfmt == OBJ_MSCOFF
                ? MsCoffObj_write_bytes(pseg, nbytes, p)
                :    OmfObj_write_bytes(pseg, nbytes, p);
        }

        void _byte(int seg, targ_size_t offset, uint _byte)
        {
            return config.objfmt == OBJ_MSCOFF
                ? MsCoffObj_byte(seg, offset, _byte)
                :    OmfObj_byte(seg, offset, _byte);
        }

        uint bytes(int seg, targ_size_t offset, uint nbytes, void *p)
        {
            return config.objfmt == OBJ_MSCOFF
                ? MsCoffObj_bytes(seg, offset, nbytes, p)
                :    OmfObj_bytes(seg, offset, nbytes, p);
        }

        void ledata(int seg, targ_size_t offset, targ_size_t data, uint lcfd, uint idx1, uint idx2)
        {
            return config.objfmt == OBJ_MSCOFF
                ? assert(0)
                : OmfObj_ledata(seg, offset, data, lcfd, idx1, idx2);
        }

        void write_long(int seg, targ_size_t offset, uint data, uint lcfd, uint idx1, uint idx2)
        {
            return config.objfmt == OBJ_MSCOFF
                ? assert(0)
                : OmfObj_write_long(seg, offset, data, lcfd, idx1, idx2);
        }

        void reftodatseg(int seg, targ_size_t offset, targ_size_t val, uint targetdatum, int flags)
        {
            return config.objfmt == OBJ_MSCOFF
                ? MsCoffObj_reftodatseg(seg, offset, val, targetdatum, flags)
                :    OmfObj_reftodatseg(seg, offset, val, targetdatum, flags);
        }

        void reftofarseg(int seg, targ_size_t offset, targ_size_t val, int farseg, int flags)
        {
            return config.objfmt == OBJ_MSCOFF
                ? assert(0)
                : OmfObj_reftofarseg(seg, offset, val, farseg, flags);
        }

        void reftocodeseg(int seg, targ_size_t offset, targ_size_t val)
        {
            return config.objfmt == OBJ_MSCOFF
                ? MsCoffObj_reftocodeseg(seg, offset, val)
                :    OmfObj_reftocodeseg(seg, offset, val);
        }

        int reftoident(int seg, targ_size_t offset, Symbol *s, targ_size_t val, int flags)
        {
            return config.objfmt == OBJ_MSCOFF
                ? MsCoffObj_reftoident(seg, offset, s, val, flags)
                :    OmfObj_reftoident(seg, offset, s, val, flags);
        }

        void far16thunk(Symbol *s)
        {
            return config.objfmt == OBJ_MSCOFF
                ? MsCoffObj_far16thunk(s)
                :    OmfObj_far16thunk(s);
        }

        void fltused()
        {
            return config.objfmt == OBJ_MSCOFF
                ? MsCoffObj_fltused()
                :    OmfObj_fltused();
        }

        int data_readonly(char *p, int len, int *pseg)
        {
            return config.objfmt == OBJ_MSCOFF
                ? MsCoffObj_data_readonly(p, len, pseg)
                :    OmfObj_data_readonly(p, len, pseg);
        }

        int data_readonly(char *p, int len)
        {
            return config.objfmt == OBJ_MSCOFF
                ? MsCoffObj_data_readonly(p, len)
                :    OmfObj_data_readonly(p, len);
        }

        int string_literal_segment(uint sz)
        {
            return config.objfmt == OBJ_MSCOFF
                ? MsCoffObj_string_literal_segment(sz)
                :    OmfObj_string_literal_segment(sz);
        }

        Symbol *sym_cdata(tym_t ty, char *p, int len)
        {
            return config.objfmt == OBJ_MSCOFF
                ? MsCoffObj_sym_cdata(ty, p, len)
                :    OmfObj_sym_cdata(ty, p, len);
        }

        void func_start(Symbol *sfunc)
        {
            return config.objfmt == OBJ_MSCOFF
                ? MsCoffObj_func_start(sfunc)
                :    OmfObj_func_start(sfunc);
        }

        void func_term(Symbol *sfunc)
        {
            return config.objfmt == OBJ_MSCOFF
                ? MsCoffObj_func_term(sfunc)
                :    OmfObj_func_term(sfunc);
        }

        void write_pointerRef(Symbol* s, uint off)
        {
            return config.objfmt == OBJ_MSCOFF
                ? MsCoffObj_write_pointerRef(s, off)
                :    OmfObj_write_pointerRef(s, off);
        }

        int jmpTableSegment(Symbol* s)
        {
            return config.objfmt == OBJ_MSCOFF
                ? MsCoffObj_jmpTableSegment(s)
                :    OmfObj_jmpTableSegment(s);
        }

        Symbol *tlv_bootstrap()
        {
            return config.objfmt == OBJ_MSCOFF
                ? MsCoffObj_tlv_bootstrap()
                :    OmfObj_tlv_bootstrap();
        }

        void gotref(Symbol *s)
        {
        }

        int seg_debugT()           // where the symbolic debug type data goes
        {
            return config.objfmt == OBJ_MSCOFF
                ? MsCoffObj_seg_debugT()
                :    OmfObj_seg_debugT();
        }

        /*******************************************/

        int  getsegment(const(char)* sectname, uint flags)
        {
            assert(config.objfmt == OBJ_MSCOFF);
            return MsCoffObj_getsegment(sectname, flags);
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

        void addrel(int seg, targ_size_t offset, Symbol *targsym,
                              uint targseg, int rtype, int val)
        {
            assert(config.objfmt == OBJ_MSCOFF);
            return MsCoffObj_addrel(seg, offset, targsym, targseg, rtype, val);
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
else version (Posix)
{
    class Obj
    {
      public:
        static Obj init(Outbuffer *, const(char)* filename, const(char)* csegname);
        static void initfile(const(char)* filename, const(char)* csegname, const(char)* modname);
        static void termfile();
        static void term(const(char)* objfilename);
        static void compiler();
        static void exestr(const(char)* p);
        static void dosseg();
        static void startaddress(Symbol *);
        static bool includelib(const(char)* );
        static bool linkerdirective(const(char)* p);
        static size_t mangle(Symbol *s,char *dest);
        static void _alias(const(char)* n1,const(char)* n2);
        static void user(const(char)* p);

        static void _import(elem *e);
        static void linnum(Srcpos srcpos, int seg, targ_size_t offset);
        static int codeseg(char *name,int suffix);
        static bool allowZeroSize();
        static void wkext(Symbol *,Symbol *);
        static void lzext(Symbol *,Symbol *);
        static void theadr(const(char)* modname);
        static void segment_group(targ_size_t codesize, targ_size_t datasize, targ_size_t cdatasize, targ_size_t udatasize);
        static void staticctor(Symbol *s,int dtor,int seg);
        static void staticdtor(Symbol *s);
        static void setModuleCtorDtor(Symbol *s, bool isCtor);
        static void ehtables(Symbol *sfunc,uint size,Symbol *ehsym);
        static void ehsections();
        static void moduleinfo(Symbol *scc);
        static int comdat(Symbol *);
        static int comdatsize(Symbol *, targ_size_t symsize);
        int readonly_comdat(Symbol *s);
        static void setcodeseg(int seg);
        seg_data *tlsseg();
        seg_data *tlsseg_bss();
        static seg_data *tlsseg_data();
        static int  fardata(char *name, targ_size_t size, targ_size_t *poffset);
        static void export_symbol(Symbol *s, uint argsize);
        static void pubdef(int seg, Symbol *s, targ_size_t offset);
        static void pubdefsize(int seg, Symbol *s, targ_size_t offset, targ_size_t symsize);
        static int external_def(const(char)* );
        static int data_start(Symbol *sdata, targ_size_t datasize, int seg);
        static int external(Symbol *);
        static int common_block(Symbol *s, targ_size_t size, targ_size_t count);
        static int common_block(Symbol *s, int flag, targ_size_t size, targ_size_t count);
        static void lidata(int seg, targ_size_t offset, targ_size_t count);
        static void write_zeros(seg_data *pseg, targ_size_t count);
        static void write_byte(seg_data *pseg, uint _byte);
        static void write_bytes(seg_data *pseg, uint nbytes, void *p);
        static void _byte(int seg, targ_size_t offset, uint _byte);
        static uint bytes(int seg, targ_size_t offset, uint nbytes, void *p);
        static void ledata(int seg, targ_size_t offset, targ_size_t data, uint lcfd, uint idx1, uint idx2);
        static void write_long(int seg, targ_size_t offset, uint data, uint lcfd, uint idx1, uint idx2);
        static void reftodatseg(int seg, targ_size_t offset, targ_size_t val, uint targetdatum, int flags);
        static void reftofarseg(int seg, targ_size_t offset, targ_size_t val, int farseg, int flags);
        static void reftocodeseg(int seg, targ_size_t offset, targ_size_t val);
        static int reftoident(int seg, targ_size_t offset, Symbol *s, targ_size_t val, int flags);
        static void far16thunk(Symbol *s);
        static void fltused();
        static int data_readonly(char *p, int len, int *pseg);
        static int data_readonly(char *p, int len);
        static int string_literal_segment(uint sz);
        static Symbol *sym_cdata(tym_t, char *, int);
        static void func_start(Symbol *sfunc);
        static void func_term(Symbol *sfunc);
        static void write_pointerRef(Symbol* s, uint off);
        static int jmpTableSegment(Symbol* s);

        static Symbol *tlv_bootstrap();

        static void gotref(Symbol *s);

        static  uint addstr(Outbuffer *strtab, const(char)* );
        static Symbol *getGOTsym();
        static void refGOTsym();
    }

    version (OSX)
    {
        class MachObj : Obj
        {
          public:
            static int getsegment(const(char)* sectname, const(char)* segname,
                int  _align, int flags);
            static void addrel(int seg, targ_size_t offset, Symbol *targsym,
                 uint targseg, int rtype, int val = 0);
        }

        class MachObj64 : MachObj
        {
          public:
            override seg_data *tlsseg();
            override seg_data *tlsseg_bss();
        }
    }
    else
    {
        class ElfObj : Obj
        {
          public:
            static int getsegment(const(char)* name, const(char)* suffix,
                int type, int flags, int  _align);
            static void addrel(int seg, targ_size_t offset, uint type,
                                uint symidx, targ_size_t val);
            static size_t writerel(int targseg, size_t offset, uint type,
                                    uint symidx, targ_size_t val);
        }
    }
}
else version (STUB)
{
    public import stubobj;
}
else
    static assert(0, "unsupported version");


extern __gshared Obj objmod;

