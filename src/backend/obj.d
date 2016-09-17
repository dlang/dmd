/**
 * Compiler implementation of the
 * $(LINK2 http://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (C) 1994-1998 by Symantec
 *              Copyright (c) 2000-2016 by Digital Mars, All Rights Reserved
 * Authors:     $(LINK2 http://www.digitalmars.com, Walter Bright)
 * License:     backendlicense.txt
 * Source:      $(DMDSRC backend/_obj.d)
 */

module ddmd.backend.obj;

/* Interface to object file format
 */

import ddmd.backend.cdef;
import ddmd.backend.cc;
import ddmd.backend.el;
import ddmd.backend.outbuf;

extern (C++):

struct seg_data;

version (Windows)
{
class Obj
{
  public:
    static Obj init(Outbuffer *, const(char)* filename, const(char)* csegname);
    void initfile(const(char)* filename, const(char)* csegname, const(char)* modname);
    void termfile();
    void term(const(char)* objfilename);

    size_t mangle(Symbol *s,char *dest);
    void _import(elem *e);
    void linnum(Srcpos srcpos, targ_size_t offset);
    int codeseg(char *name,int suffix);
    void dosseg();
    void startaddress(Symbol *);
    bool includelib(const(char)* );
    bool allowZeroSize();
    void exestr(const(char)* p);
    void user(const(char)* p);
    void compiler();
    void wkext(Symbol *,Symbol *);
    void lzext(Symbol *,Symbol *);
    void _alias(const(char)* n1,const(char)* n2);
    void theadr(const(char)* modname);
    void segment_group(targ_size_t codesize, targ_size_t datasize, targ_size_t cdatasize, targ_size_t udatasize);
    void staticctor(Symbol *s,int dtor,int seg);
    void staticdtor(Symbol *s);
    void funcptr(Symbol *s);
    void ehtables(Symbol *sfunc,targ_size_t size,Symbol *ehsym);
    void ehsections();
    void moduleinfo(Symbol *scc);
    int comdat(Symbol *);
    int comdatsize(Symbol *, targ_size_t symsize);
    void setcodeseg(int seg);
    seg_data *tlsseg();
    seg_data *tlsseg_bss();
    seg_data *tlsseg_data();
    static int  fardata(char *name, targ_size_t size, targ_size_t *poffset);
    void export_symbol(Symbol *s, uint argsize);
    void pubdef(int seg, Symbol *s, targ_size_t offset);
    void pubdefsize(int seg, Symbol *s, targ_size_t offset, targ_size_t symsize);
    int external_def(const(char)* );
    int data_start(Symbol *sdata, targ_size_t datasize, int seg);
    int external(Symbol *);
    int common_block(Symbol *s, targ_size_t size, targ_size_t count);
    int common_block(Symbol *s, int flag, targ_size_t size, targ_size_t count);
    void lidata(int seg, targ_size_t offset, targ_size_t count);
    void write_zeros(seg_data *pseg, targ_size_t count);
    void write_byte(seg_data *pseg, uint _byte);
    void write_bytes(seg_data *pseg, uint nbytes, void *p);
    void _byte(int seg, targ_size_t offset, uint _byte);
    uint bytes(int seg, targ_size_t offset, uint nbytes, void *p);
    void ledata(int seg, targ_size_t offset, targ_size_t data, uint lcfd, uint idx1, uint idx2);
    void write_long(int seg, targ_size_t offset, uint data, uint lcfd, uint idx1, uint idx2);
    void reftodatseg(int seg, targ_size_t offset, targ_size_t val, uint targetdatum, int flags);
    void reftofarseg(int seg, targ_size_t offset, targ_size_t val, int farseg, int flags);
    void reftocodeseg(int seg, targ_size_t offset, targ_size_t val);
    int reftoident(int seg, targ_size_t offset, Symbol *s, targ_size_t val, int flags);
    void far16thunk(Symbol *s);
    void fltused();
    int data_readonly(char *p, int len, int *pseg);
    int data_readonly(char *p, int len);
    Symbol *sym_cdata(tym_t, char *, int);
    void func_start(Symbol *sfunc);
    void func_term(Symbol *sfunc);

    Symbol *tlv_bootstrap();

    static void gotref(Symbol *s);

    int seg_debugT();           // where the symbolic debug type data goes
}


class MsCoffObj : Obj
{
  public:
    static MsCoffObj init(Outbuffer *, const(char)* filename, const(char)* csegname);
    override void initfile(const(char)* filename, const(char)* csegname, const(char)* modname);
    override void termfile();
    override void term(const(char)* objfilename);

//    size_t mangle(Symbol *s,char *dest);
//    void _import(elem *e);
    override void linnum(Srcpos srcpos, targ_size_t offset);
    override int codeseg(char *name,int suffix);
//    void dosseg();
    override void startaddress(Symbol *);
    override bool includelib(const(char)* );
    override bool allowZeroSize();
    override void exestr(const(char)* p);
    override void user(const(char)* p);
    override void compiler();
    override void wkext(Symbol *,Symbol *);
//    void lzext(Symbol *,Symbol *);
    override void _alias(const(char)* n1,const(char)* n2);
//    void theadr(const(char)* modname);
//    void segment_group(targ_size_t codesize, targ_size_t datasize, targ_size_t cdatasize, targ_size_t udatasize);
    override void staticctor(Symbol *s,int dtor,int seg);
    override void staticdtor(Symbol *s);
    override void funcptr(Symbol *s);
    override void ehtables(Symbol *sfunc,targ_size_t size,Symbol *ehsym);
    override void ehsections();
    override void moduleinfo(Symbol *scc);
    override int comdat(Symbol *);
    override int comdatsize(Symbol *, targ_size_t symsize);
    override void setcodeseg(int seg);
    override seg_data *tlsseg();
    override seg_data *tlsseg_bss();
    override seg_data *tlsseg_data();
    override void export_symbol(Symbol *s, uint argsize);
    override void pubdef(int seg, Symbol *s, targ_size_t offset);
    override void pubdefsize(int seg, Symbol *s, targ_size_t offset, targ_size_t symsize);
//    int external(const(char)* );
    override int external_def(const(char)* );
    override int data_start(Symbol *sdata, targ_size_t datasize, int seg);
    override int external(Symbol *);
    override int common_block(Symbol *s, targ_size_t size, targ_size_t count);
    override int common_block(Symbol *s, int flag, targ_size_t size, targ_size_t count);
    override void lidata(int seg, targ_size_t offset, targ_size_t count);
    override void write_zeros(seg_data *pseg, targ_size_t count);
    override void write_byte(seg_data *pseg, uint _byte);
    override void write_bytes(seg_data *pseg, uint nbytes, void *p);
    override void _byte(int seg, targ_size_t offset, uint _byte);
    override uint bytes(int seg, targ_size_t offset, uint nbytes, void *p);
//    void ledata(int seg, targ_size_t offset, targ_size_t data, uint lcfd, uint idx1, uint idx2);
//    void write_long(int seg, targ_size_t offset, uint data, uint lcfd, uint idx1, uint idx2);
    override void reftodatseg(int seg, targ_size_t offset, targ_size_t val, uint targetdatum, int flags);
//    void reftofarseg(int seg, targ_size_t offset, targ_size_t val, int farseg, int flags);
    override void reftocodeseg(int seg, targ_size_t offset, targ_size_t val);
    override int reftoident(int seg, targ_size_t offset, Symbol *s, targ_size_t val, int flags);
    override void far16thunk(Symbol *s);
    override void fltused();
    override int data_readonly(char *p, int len, int *pseg);
    override int data_readonly(char *p, int len);
    override Symbol *sym_cdata(tym_t, char *, int);
    static  uint addstr(Outbuffer *strtab, const(char)* );
    override void func_start(Symbol *sfunc);
    override void func_term(Symbol *sfunc);

    static int getsegment(const(char)* sectname, uint flags);
    static int getsegment2( uint shtidx);
    static  uint addScnhdr(const(char)* scnhdr_name, uint flags);

    static void addrel(int seg, targ_size_t offset, Symbol *targsym,
         uint targseg, int rtype, int val);
//    static void addrel(int seg, targ_size_t offset, uint type,
//                                         uint symidx, targ_size_t val);

    static int seg_pdata();
    static int seg_xdata();
    static int seg_pdata_comdat(Symbol *sfunc);
    static int seg_xdata_comdat(Symbol *sfunc);

    static int seg_debugS();
    override int seg_debugT();
    static int seg_debugS_comdat(Symbol *sfunc);

    override Symbol *tlv_bootstrap();
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

    static size_t mangle(Symbol *s,char *dest);
    static void _import(elem *e);
    static void linnum(Srcpos srcpos, targ_size_t offset);
    static int codeseg(char *name,int suffix);
    static void dosseg();
    static void startaddress(Symbol *);
    static bool includelib(const(char)* );
    static bool allowZeroSize();
    static void exestr(const(char)* p);
    static void user(const(char)* p);
    static void compiler();
    static void wkext(Symbol *,Symbol *);
    static void lzext(Symbol *,Symbol *);
    static void _alias(const(char)* n1,const(char)* n2);
    static void theadr(const(char)* modname);
    static void segment_group(targ_size_t codesize, targ_size_t datasize, targ_size_t cdatasize, targ_size_t udatasize);
    static void staticctor(Symbol *s,int dtor,int seg);
    static void staticdtor(Symbol *s);
    static void funcptr(Symbol *s);
    static void ehtables(Symbol *sfunc,targ_size_t size,Symbol *ehsym);
    static void ehsections();
    static void moduleinfo(Symbol *scc);
    int comdat(Symbol *);
    static int comdatsize(Symbol *, targ_size_t symsize);
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
    static Symbol *sym_cdata(tym_t, char *, int);
    static void func_start(Symbol *sfunc);
    static void func_term(Symbol *sfunc);

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
else
    static assert(0, "unsupported version");


extern __gshared Obj objmod;

