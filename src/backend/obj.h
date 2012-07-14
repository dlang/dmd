// Copyright (C) 2012 by Digital Mars
// All Rights Reserved
// http://www.digitalmars.com
// Written by Walter Bright
/*
 * This source file is made available for personal use
 * only. The license is in /dmd/src/dmd/backendlicense.txt
 * or /dm/src/dmd/backendlicense.txt
 * For any other uses, please contact Digital Mars.
 */

/* Interface to object file format
 */

//#pragma once
#ifndef OBJ_H
#define OBJ_H        1

struct seg_data;


struct Obj
{
    static Obj *init(Outbuffer *, const char *filename, const char *csegname);
    static void initfile(const char *filename, const char *csegname, const char *modname);
    static void termfile();
    static void term();

    static size_t mangle(Symbol *s,char *dest);
    static void import(elem *e);
    static void linnum(Srcpos srcpos, targ_size_t offset);
    static int codeseg(char *name,int suffix);
    static void dosseg(void);
    static void startaddress(Symbol *);
    static bool includelib(const char *);
    static bool allowZeroSize();
    static void exestr(const char *p);
    static void user(const char *p);
    static void compiler();
    static void wkext(Symbol *,Symbol *);
    static void lzext(Symbol *,Symbol *);
    static void alias(const char *n1,const char *n2);
    static void theadr(const char *modname);
    static void segment_group(targ_size_t codesize, targ_size_t datasize, targ_size_t cdatasize, targ_size_t udatasize);
    static void staticctor(Symbol *s,int dtor,int seg);
    static void staticdtor(Symbol *s);
    static void funcptr(Symbol *s);
    static void ehtables(Symbol *sfunc,targ_size_t size,Symbol *ehsym);
    static void ehsections();
    static void moduleinfo(Symbol *scc);
    static int  comdat(Symbol *);
    static int  comdatsize(Symbol *, targ_size_t symsize);
    static void setcodeseg(int seg);
    static seg_data *tlsseg();
    static seg_data *tlsseg_bss();
    static int  fardata(char *name, targ_size_t size, targ_size_t *poffset);
    static void browse(char *, unsigned);
    static void end(void);
    static void export_symbol(Symbol *s, unsigned argsize);
    static void pubdef(int seg, Symbol *s, targ_size_t offset);
    static void pubdefsize(int seg, Symbol *s, targ_size_t offset, targ_size_t symsize);
    static int external(const char *);
    static int external_def(const char *);
    static int data_start(Symbol *sdata, targ_size_t datasize, int seg);
    static int external(Symbol *);
    static int common_block(Symbol *s, targ_size_t size, targ_size_t count);
    static int common_block(Symbol *s, int flag, targ_size_t size, targ_size_t count);
    static void lidata(int seg, targ_size_t offset, targ_size_t count);
    static void write_zeros(seg_data *pseg, targ_size_t count);
    static void write_byte(seg_data *pseg, unsigned byte);
    static void write_bytes(seg_data *pseg, unsigned nbytes, void *p);
    static void byte(int seg, targ_size_t offset, unsigned byte);
    static unsigned bytes(int seg, targ_size_t offset, unsigned nbytes, void *p);
    static void ledata(int seg, targ_size_t offset, targ_size_t data, unsigned lcfd, unsigned idx1, unsigned idx2);
    static void write_long(int seg, targ_size_t offset, unsigned long data, unsigned lcfd, unsigned idx1, unsigned idx2);
    static void reftodatseg(int seg, targ_size_t offset, targ_size_t val, unsigned targetdatum, int flags);
    static void reftofarseg(int seg, targ_size_t offset, targ_size_t val, int farseg, int flags);
    static void reftocodeseg(int seg, targ_size_t offset, targ_size_t val);
    static int reftoident(int seg, targ_size_t offset, Symbol *s, targ_size_t val, int flags);
    static void far16thunk(Symbol *s);
    static void fltused();
    static int data_readonly(char *p, int len, int *pseg);
    static int data_readonly(char *p, int len);
    static symbol *sym_cdata(tym_t, char *, int);
    static unsigned addstr(Outbuffer *strtab, const char *);
    static void func_start(Symbol *sfunc);
    static void func_term(Symbol *sfunc);

#if TARGET_LINUX || TARGET_OSX || TARGET_FREEBSD || TARGET_OPENBSD || TARGET_SOLARIS
    static void gotref(symbol *s);
    static symbol *getGOTsym();
    static void refGOTsym();
#endif

};

struct ElfObj : Obj
{
    static int getsegment(const char *name, const char *suffix,
        int type, int flags, int align);
    static void addrel(int seg, targ_size_t offset, unsigned type,
                        unsigned symidx, targ_size_t val);
};

struct MachObj : Obj
{
    static int getsegment(const char *sectname, const char *segname,
        int align, int flags, int flags2 = 0);
    static void addrel(int seg, targ_size_t offset, symbol *targsym,
        unsigned targseg, int rtype, int val = 0);
};

struct MsCoffObj : Obj
{
    static MsCoffObj *init(Outbuffer *, const char *filename, const char *csegname);
    static void initfile(const char *filename, const char *csegname, const char *modname);
    static void termfile();
    static void term();

    static size_t mangle(Symbol *s,char *dest);
    static void import(elem *e);
    static void linnum(Srcpos srcpos, targ_size_t offset);
    static int codeseg(char *name,int suffix);
    static void dosseg(void);
    static void startaddress(Symbol *);
    static bool includelib(const char *);
    static bool allowZeroSize();
    static void exestr(const char *p);
    static void user(const char *p);
    static void compiler();
    static void wkext(Symbol *,Symbol *);
    static void lzext(Symbol *,Symbol *);
    static void alias(const char *n1,const char *n2);
    static void theadr(const char *modname);
    static void segment_group(targ_size_t codesize, targ_size_t datasize, targ_size_t cdatasize, targ_size_t udatasize);
    static void staticctor(Symbol *s,int dtor,int seg);
    static void staticdtor(Symbol *s);
    static void funcptr(Symbol *s);
    static void ehtables(Symbol *sfunc,targ_size_t size,Symbol *ehsym);
    static void ehsections();
    static void moduleinfo(Symbol *scc);
    static int  comdat(Symbol *);
    static int  comdatsize(Symbol *, targ_size_t symsize);
    static void setcodeseg(int seg);
    static seg_data *tlsseg();
    static seg_data *tlsseg_bss();
    static int  fardata(char *name, targ_size_t size, targ_size_t *poffset);
    static void browse(char *, unsigned);
    static void end(void);
    static void export_symbol(Symbol *s, unsigned argsize);
    static void pubdef(int seg, Symbol *s, targ_size_t offset);
    static void pubdefsize(int seg, Symbol *s, targ_size_t offset, targ_size_t symsize);
    static int external(const char *);
    static int external_def(const char *);
    static int data_start(Symbol *sdata, targ_size_t datasize, int seg);
    static int external(Symbol *);
    static int common_block(Symbol *s, targ_size_t size, targ_size_t count);
    static int common_block(Symbol *s, int flag, targ_size_t size, targ_size_t count);
    static void lidata(int seg, targ_size_t offset, targ_size_t count);
    static void write_zeros(seg_data *pseg, targ_size_t count);
    static void write_byte(seg_data *pseg, unsigned byte);
    static void write_bytes(seg_data *pseg, unsigned nbytes, void *p);
    static void byte(int seg, targ_size_t offset, unsigned byte);
    static unsigned bytes(int seg, targ_size_t offset, unsigned nbytes, void *p);
    static void ledata(int seg, targ_size_t offset, targ_size_t data, unsigned lcfd, unsigned idx1, unsigned idx2);
    static void write_long(int seg, targ_size_t offset, unsigned long data, unsigned lcfd, unsigned idx1, unsigned idx2);
    static void reftodatseg(int seg, targ_size_t offset, targ_size_t val, unsigned targetdatum, int flags);
    static void reftofarseg(int seg, targ_size_t offset, targ_size_t val, int farseg, int flags);
    static void reftocodeseg(int seg, targ_size_t offset, targ_size_t val);
    static int reftoident(int seg, targ_size_t offset, Symbol *s, targ_size_t val, int flags);
    static void far16thunk(Symbol *s);
    static void fltused();
    static int data_readonly(char *p, int len, int *pseg);
    static int data_readonly(char *p, int len);
    static symbol *sym_cdata(tym_t, char *, int);
    static unsigned addstr(Outbuffer *strtab, const char *);
    static void func_start(Symbol *sfunc);
    static void func_term(Symbol *sfunc);

    static int getsegment(const char *sectname, unsigned long flags);

    static void addrel(int seg, targ_size_t offset, symbol *targsym,
        unsigned targseg, int rtype, int val);
    static void addrel(int seg, targ_size_t offset, unsigned type,
                                        unsigned symidx, targ_size_t val);
};

extern Obj *objmod;

#endif
