/**
 * Compiler implementation of the
 * $(LINK2 http://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (C) 1994-1998 by Symantec
 *              Copyright (C) 2000-2020 by The D Language Foundation, All Rights Reserved
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

nothrow:

version (SPP)
    version = STUB;
else version (HTOD)
    version = STUB;
else version (Windows)
    version = OMFandMSCOFF;
else version (Posix)
    version = ELFandMACH;
else
    static assert(0, "unsupported version");


version (Windows)
{
    Obj  OmfObj_init(Outbuffer *, const(char)* filename, const(char)* csegname);
    void OmfObj_initfile(const(char)* filename, const(char)* csegname, const(char)* modname);
    void OmfObj_termfile();
    void OmfObj_term(const(char)* objfilename);
    size_t OmfObj_mangle(Symbol *s,char *dest);
    void OmfObj_import(elem *e);
    void OmfObj_linnum(Srcpos srcpos, int seg, targ_size_t offset);
    int  OmfObj_codeseg(const char *name,int suffix);
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
    int  MsCoffObj_codeseg(const char *name,int suffix);
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

version (Posix)
{
    Obj Obj_init(Outbuffer *, const(char)* filename, const(char)* csegname);
    void Obj_initfile(const(char)* filename, const(char)* csegname, const(char)* modname);
    void Obj_termfile();
    void Obj_term(const(char)* objfilename);
    void Obj_compiler();
    void Obj_exestr(const(char)* p);
    void Obj_dosseg();
    void Obj_startaddress(Symbol *);
    bool Obj_includelib(const(char)* );
    bool Obj_linkerdirective(const(char)* p);
    size_t Obj_mangle(Symbol *s,char *dest);
    void Obj_alias(const(char)* n1,const(char)* n2);
    void Obj_user(const(char)* p);

    void Obj_import(elem *e);
    void Obj_linnum(Srcpos srcpos, int seg, targ_size_t offset);
    int Obj_codeseg(const char *name,int suffix);
    bool Obj_allowZeroSize();
    void Obj_wkext(Symbol *,Symbol *);
    void Obj_lzext(Symbol *,Symbol *);
    void Obj_theadr(const(char)* modname);
    void Obj_segment_group(targ_size_t codesize, targ_size_t datasize, targ_size_t cdatasize, targ_size_t udatasize);
    void Obj_staticctor(Symbol *s,int dtor,int seg);
    void Obj_staticdtor(Symbol *s);
    void Obj_setModuleCtorDtor(Symbol *s, bool isCtor);
    void Obj_ehtables(Symbol *sfunc,uint size,Symbol *ehsym);
    void Obj_ehsections();
    void Obj_moduleinfo(Symbol *scc);
    int Obj_comdat(Symbol *);
    int Obj_comdatsize(Symbol *, targ_size_t symsize);
    int Obj_readonly_comdat(Symbol *s);
    void Obj_setcodeseg(int seg);
    seg_data* Obj_tlsseg();
    seg_data* Obj_tlsseg_bss();
    seg_data* Obj_tlsseg_data();
    int Obj_fardata(char *name, targ_size_t size, targ_size_t *poffset);
    void Obj_export_symbol(Symbol *s, uint argsize);
    void Obj_pubdef(int seg, Symbol *s, targ_size_t offset);
    void Obj_pubdefsize(int seg, Symbol *s, targ_size_t offset, targ_size_t symsize);
    int Obj_external_def(const(char)* );
    int Obj_data_start(Symbol *sdata, targ_size_t datasize, int seg);
    int Obj_external(Symbol *);
    int Obj_common_block(Symbol *s, targ_size_t size, targ_size_t count);
    int Obj_common_block(Symbol *s, int flag, targ_size_t size, targ_size_t count);
    void Obj_lidata(int seg, targ_size_t offset, targ_size_t count);
    void Obj_write_zeros(seg_data *pseg, targ_size_t count);
    void Obj_write_byte(seg_data *pseg, uint _byte);
    void Obj_write_bytes(seg_data *pseg, uint nbytes, void *p);
    void Obj_byte(int seg, targ_size_t offset, uint _byte);
    uint Obj_bytes(int seg, targ_size_t offset, uint nbytes, void *p);
    void Obj_ledata(int seg, targ_size_t offset, targ_size_t data, uint lcfd, uint idx1, uint idx2);
    void Obj_write_long(int seg, targ_size_t offset, uint data, uint lcfd, uint idx1, uint idx2);
    void Obj_reftodatseg(int seg, targ_size_t offset, targ_size_t val, uint targetdatum, int flags);
    void Obj_reftofarseg(int seg, targ_size_t offset, targ_size_t val, int farseg, int flags);
    void Obj_reftocodeseg(int seg, targ_size_t offset, targ_size_t val);
    int Obj_reftoident(int seg, targ_size_t offset, Symbol *s, targ_size_t val, int flags);
    void Obj_far16thunk(Symbol *s);
    void Obj_fltused();
    int Obj_data_readonly(char *p, int len, int *pseg);
    int Obj_data_readonly(char *p, int len);
    int Obj_string_literal_segment(uint sz);
    Symbol* Obj_sym_cdata(tym_t, char *, int);
    void Obj_func_start(Symbol *sfunc);
    void Obj_func_term(Symbol *sfunc);
    void Obj_write_pointerRef(Symbol* s, uint off);
    int Obj_jmpTableSegment(Symbol* s);

    Symbol* Obj_tlv_bootstrap();

    void Obj_gotref(Symbol *s);

    uint Obj_addstr(Outbuffer *strtab, const(char)* );
    Symbol* Obj_getGOTsym();
    void Obj_refGOTsym();

    version (OSX)
    {
        int Obj_getsegment(const(char)* sectname, const(char)* segname,
                              int  _align, int flags);
        void Obj_addrel(int seg, targ_size_t offset, Symbol *targsym,
                           uint targseg, int rtype, int val = 0);
    }
    else
    {
        int Obj_getsegment(const(char)* name, const(char)* suffix,
                              int type, int flags, int  _align);
        void Obj_addrel(int seg, targ_size_t offset, uint type,
                           uint symidx, targ_size_t val);
        size_t Obj_writerel(int targseg, size_t offset, uint type,
                               uint symidx, targ_size_t val);
    }
}

version (OMFandMSCOFF)
{
    class Obj
    {
      static
      {
        nothrow:

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

        int codeseg(const char *name,int suffix)
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

        Symbol *getGOTsym()
        {
            assert(0);
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
else version (ELFandMACH)
{
    class Obj
    {
      static:
      nothrow:
        Obj init(Outbuffer* objbuf, const(char)* filename, const(char)* csegname)
        {
            return Obj_init(objbuf, filename, csegname);
        }

        void initfile(const(char)* filename, const(char)* csegname, const(char)* modname)
        {
            return Obj_initfile(filename, csegname, modname);
        }

        void termfile()
        {
            return Obj_termfile();
        }

        void term(const(char)* objfilename)
        {
            return Obj_term(objfilename);
        }

        /+size_t mangle(Symbol *s,char *dest)
        {
            return Obj_mangle(s, dest);
        }+/

        /+void _import(elem *e)
        {
            return Obj_import(e);
        }+/

        void linnum(Srcpos srcpos, int seg, targ_size_t offset)
        {
            return Obj_linnum(srcpos, seg, offset);
        }

        int codeseg(const char *name,int suffix)
        {
            return Obj_codeseg(name, suffix);
        }

        /+void dosseg()
        {
            return Obj_dosseg();
        }+/

        void startaddress(Symbol *s)
        {
            return Obj_startaddress(s);
        }

        bool includelib(const(char)* name)
        {
            return Obj_includelib(name);
        }

        bool linkerdirective(const(char)* p)
        {
            return Obj_linkerdirective(p);
        }

        bool allowZeroSize()
        {
            return Obj_allowZeroSize();
        }

        void exestr(const(char)* p)
        {
            return Obj_exestr(p);
        }

        void user(const(char)* p)
        {
            return Obj_user(p);
        }

        void compiler()
        {
            return Obj_compiler();
        }

        void wkext(Symbol* s1, Symbol* s2)
        {
            return Obj_wkext(s1, s2);
        }

        /+void lzext(Symbol* s1, Symbol* s2)
        {
            return Obj_lzext(s1, s2);
        }+/

        void _alias(const(char)* n1,const(char)* n2)
        {
            return Obj_alias(n1, n2);
        }

        /+void theadr(const(char)* modname)
        {
            return Obj_theadr(modname);
        }+/

        /+void segment_group(targ_size_t codesize, targ_size_t datasize, targ_size_t cdatasize, targ_size_t udatasize)
        {
            return Obj_segment_group(codesize, datasize, cdatasize, udatasize);
        }+/

        void staticctor(Symbol *s,int dtor,int seg)
        {
            return Obj_staticctor(s, dtor, seg);
        }

        void staticdtor(Symbol *s)
        {
            return Obj_staticdtor(s);
        }

        void setModuleCtorDtor(Symbol *s, bool isCtor)
        {
            return Obj_setModuleCtorDtor(s, isCtor);
        }

        void ehtables(Symbol *sfunc,uint size,Symbol *ehsym)
        {
            return Obj_ehtables(sfunc, size, ehsym);
        }

        void ehsections()
        {
            return Obj_ehsections();
        }

        void moduleinfo(Symbol *scc)
        {
            return Obj_moduleinfo(scc);
        }

        int comdat(Symbol *s)
        {
            return Obj_comdat(s);
        }

        int comdatsize(Symbol *s, targ_size_t symsize)
        {
            return Obj_comdatsize(s, symsize);
        }

        int readonly_comdat(Symbol *s)
        {
            return Obj_comdat(s);
        }

        void setcodeseg(int seg)
        {
            return Obj_setcodeseg(seg);
        }

        seg_data *tlsseg()
        {
            return Obj_tlsseg();
        }

        seg_data *tlsseg_bss()
        {
            return Obj_tlsseg_bss();
        }

        seg_data *tlsseg_data()
        {
            return Obj_tlsseg_data();
        }

        /+int fardata(char *name, targ_size_t size, targ_size_t *poffset)
        {
            return Obj_fardata(name, size, poffset);
        }+/

        void export_symbol(Symbol *s, uint argsize)
        {
            return Obj_export_symbol(s, argsize);
        }

        void pubdef(int seg, Symbol *s, targ_size_t offset)
        {
            return Obj_pubdef(seg, s, offset);
        }

        void pubdefsize(int seg, Symbol *s, targ_size_t offset, targ_size_t symsize)
        {
            return Obj_pubdefsize(seg, s, offset, symsize);
        }

        int external_def(const(char)* name)
        {
            return Obj_external_def(name);
        }

        int data_start(Symbol *sdata, targ_size_t datasize, int seg)
        {
            return Obj_data_start(sdata, datasize, seg);
        }

        int external(Symbol *s)
        {
            return Obj_external(s);
        }

        int common_block(Symbol *s, targ_size_t size, targ_size_t count)
        {
            return Obj_common_block(s, size, count);
        }

        int common_block(Symbol *s, int flag, targ_size_t size, targ_size_t count)
        {
            return Obj_common_block(s, flag, size, count);
        }

        void lidata(int seg, targ_size_t offset, targ_size_t count)
        {
            return Obj_lidata(seg, offset, count);
        }

        void write_zeros(seg_data *pseg, targ_size_t count)
        {
            return Obj_write_zeros(pseg, count);
        }

        void write_byte(seg_data *pseg, uint _byte)
        {
            return Obj_write_byte(pseg, _byte);
        }

        void write_bytes(seg_data *pseg, uint nbytes, void *p)
        {
            return Obj_write_bytes(pseg, nbytes, p);
        }

        void _byte(int seg, targ_size_t offset, uint _byte)
        {
            return Obj_byte(seg, offset, _byte);
        }

        uint bytes(int seg, targ_size_t offset, uint nbytes, void *p)
        {
            return Obj_bytes(seg, offset, nbytes, p);
        }

        /+void ledata(int seg, targ_size_t offset, targ_size_t data, uint lcfd, uint idx1, uint idx2)
        {
            return Obj_ledata(seg, offset, data, lcfd, idx1, idx2);
        }+/

        /+void write_long(int seg, targ_size_t offset, uint data, uint lcfd, uint idx1, uint idx2)
        {
            return Obj_write_long(seg, offset, data, lcfd, idx1, idx2);
        }+/

        void reftodatseg(int seg, targ_size_t offset, targ_size_t val, uint targetdatum, int flags)
        {
            return Obj_reftodatseg(seg, offset, val, targetdatum, flags);
        }

        void reftofarseg(int seg, targ_size_t offset, targ_size_t val, int farseg, int flags)
        {
        }

        void reftocodeseg(int seg, targ_size_t offset, targ_size_t val)
        {
            return Obj_reftocodeseg(seg, offset, val);
        }

        int reftoident(int seg, targ_size_t offset, Symbol *s, targ_size_t val, int flags)
        {
            return Obj_reftoident(seg, offset, s, val, flags);
        }

        void far16thunk(Symbol *s)
        {
            return Obj_far16thunk(s);
        }

        void fltused()
        {
            return Obj_fltused();
        }

        int data_readonly(char *p, int len, int *pseg)
        {
            return Obj_data_readonly(p, len, pseg);
        }

        int data_readonly(char *p, int len)
        {
            return Obj_data_readonly(p, len);
        }

        int string_literal_segment(uint sz)
        {
            return Obj_string_literal_segment(sz);
        }

        Symbol *sym_cdata(tym_t ty, char *p, int len)
        {
            return Obj_sym_cdata(ty, p, len);
        }

        void func_start(Symbol *sfunc)
        {
            return Obj_func_start(sfunc);
        }

        void func_term(Symbol *sfunc)
        {
            return Obj_func_term(sfunc);
        }

        void write_pointerRef(Symbol* s, uint off)
        {
            return Obj_write_pointerRef(s, off);
        }

        int jmpTableSegment(Symbol* s)
        {
            return Obj_jmpTableSegment(s);
        }

        Symbol *tlv_bootstrap()
        {
            return Obj_tlv_bootstrap();
        }

        void gotref(Symbol *s)
        {
            return Obj_gotref(s);
        }

        uint addstr(Outbuffer *strtab, const(char)* p)
        {
            return Obj_addstr(strtab, p);
        }

        Symbol *getGOTsym()
        {
            return Obj_getGOTsym();
        }

        void refGOTsym()
        {
            return Obj_refGOTsym();
        }


        version (OSX)
        {
            int getsegment(const(char)* sectname, const(char)* segname,
                                  int align_, int flags)
            {
                return Obj_getsegment(sectname, segname, align_, flags);
            }

            void addrel(int seg, targ_size_t offset, Symbol *targsym,
                               uint targseg, int rtype, int val = 0)
            {
                return Obj_addrel(seg, offset, targsym, targseg, rtype, val);
            }

        }
        else
        {
            int getsegment(const(char)* name, const(char)* suffix,
                                  int type, int flags, int  align_)
            {
                return Obj_getsegment(name, suffix, type, flags, align_);
            }

            void addrel(int seg, targ_size_t offset, uint type,
                               uint symidx, targ_size_t val)
            {
                return Obj_addrel(seg, offset, type, symidx, val);
            }

            size_t writerel(int targseg, size_t offset, uint type,
                                   uint symidx, targ_size_t val)
            {
                return Obj_writerel(targseg, offset, type, symidx, val);
            }

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

