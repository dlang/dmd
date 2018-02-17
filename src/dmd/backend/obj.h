/**
 * Compiler implementation of the
 * $(LINK2 http://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (C) 2012-2018 by The D Language Foundation, All Rights Reserved
 * Authors:     $(LINK2 http://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/src/dmd/backend/obj.d, backend/obj.d)
 */

/* Interface to object file format
 */

//#pragma once
#ifndef OBJ_H
#define OBJ_H        1

struct seg_data;

#if MARS && TARGET_WINDOS && !HTOD
#define OMFandMSCOFF 1
#define VIRTUAL virtual
#else

#if TARGET_WINDOS
#define OMF 1
#elif (TARGET_LINUX || TARGET_FREEBSD || TARGET_OPENBSD || TARGET_DRAGONFLYBSD || TARGET_SOLARIS)
#define ELF 1
#elif TARGET_OSX
#define MACH 1
#endif

#define VIRTUAL static
#endif


#if OMF
    class Obj
    {
      public:
        static Obj *init(Outbuffer *, const char *filename, const char *csegname);
        static void initfile(const char *filename, const char *csegname, const char *modname);
        static void termfile();
        static void term(const char *objfilename);
        static size_t mangle(Symbol *s,char *dest);
        static void _import(elem *e);
        static void linnum(Srcpos srcpos, int seg, targ_size_t offset);
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
        static void _alias(const char *n1,const char *n2);
        static void theadr(const char *modname);
        static void segment_group(targ_size_t codesize, targ_size_t datasize, targ_size_t cdatasize, targ_size_t udatasize);
        static void staticctor(Symbol *s,int dtor,int seg);
        static void staticdtor(Symbol *s);
        static void setModuleCtorDtor(Symbol *s, bool isCtor);
        static void ehtables(Symbol *sfunc,unsigned size,Symbol *ehsym);
        static void ehsections();
        static void moduleinfo(Symbol *scc);
        int  comdat(Symbol *);
        int  comdatsize(Symbol *, targ_size_t symsize);
        int readonly_comdat(Symbol *s);
        static void setcodeseg(int seg);
        static seg_data *tlsseg();
        static seg_data *tlsseg_bss();
        static seg_data *tlsseg_data();
        static int  fardata(char *name, targ_size_t size, targ_size_t *poffset);
        static void export_symbol(Symbol *s, unsigned argsize);
        static void pubdef(int seg, Symbol *s, targ_size_t offset);
        static void pubdefsize(int seg, Symbol *s, targ_size_t offset, targ_size_t symsize);
        static int external_def(const char *);
        static int data_start(Symbol *sdata, targ_size_t datasize, int seg);
        static int external(Symbol *);
        static int common_block(Symbol *s, targ_size_t size, targ_size_t count);
        static int common_block(Symbol *s, int flag, targ_size_t size, targ_size_t count);
        static void lidata(int seg, targ_size_t offset, targ_size_t count);
        static void write_zeros(seg_data *pseg, targ_size_t count);
        static void write_byte(seg_data *pseg, unsigned byte);
        static void write_bytes(seg_data *pseg, unsigned nbytes, void *p);
        static void _byte(int seg, targ_size_t offset, unsigned byte);
        static unsigned bytes(int seg, targ_size_t offset, unsigned nbytes, void *p);
        static void ledata(int seg, targ_size_t offset, targ_size_t data, unsigned lcfd, unsigned idx1, unsigned idx2);
        static void write_long(int seg, targ_size_t offset, unsigned data, unsigned lcfd, unsigned idx1, unsigned idx2);
        static void reftodatseg(int seg, targ_size_t offset, targ_size_t val, unsigned targetdatum, int flags);
        static void reftofarseg(int seg, targ_size_t offset, targ_size_t val, int farseg, int flags);
        static void reftocodeseg(int seg, targ_size_t offset, targ_size_t val);
        static int reftoident(int seg, targ_size_t offset, Symbol *s, targ_size_t val, int flags);
        static void far16thunk(Symbol *s);
        static void fltused();
        static int data_readonly(char *p, int len, int *pseg);
        static int data_readonly(char *p, int len);
        static int string_literal_segment(unsigned sz);
        static symbol *sym_cdata(tym_t, char *, int);
        static void func_start(Symbol *sfunc);
        static void func_term(Symbol *sfunc);
        static void write_pointerRef(Symbol* s, unsigned off);
        static int jmpTableSegment(Symbol* s);

        static symbol *tlv_bootstrap();

        static void gotref(symbol *s);

#if TARGET_LINUX || TARGET_OSX || TARGET_FREEBSD || TARGET_OPENBSD || TARGET_DRAGONFLYBSD || TARGET_SOLARIS
        static unsigned addstr(Outbuffer *strtab, const char *);
        static symbol *getGOTsym();
        static void refGOTsym();
#endif

#if TARGET_WINDOS
        static int seg_debugT();           // where the symbolic debug type data goes
#endif
    };

#else

class Obj
{
  public:
    static Obj *init(Outbuffer *, const char *filename, const char *csegname);
    VIRTUAL void initfile(const char *filename, const char *csegname, const char *modname);
    VIRTUAL void termfile();
    VIRTUAL void term(const char *objfilename);

    VIRTUAL size_t mangle(Symbol *s,char *dest);
    VIRTUAL void _import(elem *e);
    VIRTUAL void linnum(Srcpos srcpos, int seg, targ_size_t offset);
    VIRTUAL int codeseg(char *name,int suffix);
    VIRTUAL void dosseg(void);
    VIRTUAL void startaddress(Symbol *);
    VIRTUAL bool includelib(const char *);
    VIRTUAL bool allowZeroSize();
    VIRTUAL void exestr(const char *p);
    VIRTUAL void user(const char *p);
    VIRTUAL void compiler();
    VIRTUAL void wkext(Symbol *,Symbol *);
    VIRTUAL void lzext(Symbol *,Symbol *);
    VIRTUAL void _alias(const char *n1,const char *n2);
    VIRTUAL void theadr(const char *modname);
    VIRTUAL void segment_group(targ_size_t codesize, targ_size_t datasize, targ_size_t cdatasize, targ_size_t udatasize);
    VIRTUAL void staticctor(Symbol *s,int dtor,int seg);
    VIRTUAL void staticdtor(Symbol *s);
    VIRTUAL void setModuleCtorDtor(Symbol *s, bool isCtor);
    VIRTUAL void ehtables(Symbol *sfunc,unsigned size,Symbol *ehsym);
    VIRTUAL void ehsections();
    VIRTUAL void moduleinfo(Symbol *scc);
    virtual int  comdat(Symbol *);
    virtual int  comdatsize(Symbol *, targ_size_t symsize);
    virtual int readonly_comdat(Symbol *s);
    VIRTUAL void setcodeseg(int seg);
    virtual seg_data *tlsseg();
    virtual seg_data *tlsseg_bss();
    VIRTUAL seg_data *tlsseg_data();
    static int  fardata(char *name, targ_size_t size, targ_size_t *poffset);
    VIRTUAL void export_symbol(Symbol *s, unsigned argsize);
    VIRTUAL void pubdef(int seg, Symbol *s, targ_size_t offset);
    VIRTUAL void pubdefsize(int seg, Symbol *s, targ_size_t offset, targ_size_t symsize);
    VIRTUAL int external_def(const char *);
    VIRTUAL int data_start(Symbol *sdata, targ_size_t datasize, int seg);
    VIRTUAL int external(Symbol *);
    VIRTUAL int common_block(Symbol *s, targ_size_t size, targ_size_t count);
    VIRTUAL int common_block(Symbol *s, int flag, targ_size_t size, targ_size_t count);
    VIRTUAL void lidata(int seg, targ_size_t offset, targ_size_t count);
    VIRTUAL void write_zeros(seg_data *pseg, targ_size_t count);
    VIRTUAL void write_byte(seg_data *pseg, unsigned byte);
    VIRTUAL void write_bytes(seg_data *pseg, unsigned nbytes, void *p);
    VIRTUAL void _byte(int seg, targ_size_t offset, unsigned byte);
    VIRTUAL unsigned bytes(int seg, targ_size_t offset, unsigned nbytes, void *p);
    VIRTUAL void ledata(int seg, targ_size_t offset, targ_size_t data, unsigned lcfd, unsigned idx1, unsigned idx2);
    VIRTUAL void write_long(int seg, targ_size_t offset, unsigned data, unsigned lcfd, unsigned idx1, unsigned idx2);
    VIRTUAL void reftodatseg(int seg, targ_size_t offset, targ_size_t val, unsigned targetdatum, int flags);
    VIRTUAL void reftofarseg(int seg, targ_size_t offset, targ_size_t val, int farseg, int flags);
    VIRTUAL void reftocodeseg(int seg, targ_size_t offset, targ_size_t val);
    VIRTUAL int reftoident(int seg, targ_size_t offset, Symbol *s, targ_size_t val, int flags);
    VIRTUAL void far16thunk(Symbol *s);
    VIRTUAL void fltused();
    VIRTUAL int data_readonly(char *p, int len, int *pseg);
    VIRTUAL int data_readonly(char *p, int len);
    VIRTUAL int string_literal_segment(unsigned sz);
    VIRTUAL symbol *sym_cdata(tym_t, char *, int);
    VIRTUAL void func_start(Symbol *sfunc);
    VIRTUAL void func_term(Symbol *sfunc);
    VIRTUAL void write_pointerRef(Symbol* s, unsigned off);
    VIRTUAL int jmpTableSegment(Symbol* s);

    VIRTUAL symbol *tlv_bootstrap();

    static void gotref(symbol *s);

#if TARGET_LINUX || TARGET_OSX || TARGET_FREEBSD || TARGET_OPENBSD || TARGET_DRAGONFLYBSD || TARGET_SOLARIS
    static unsigned addstr(Outbuffer *strtab, const char *);
    static symbol *getGOTsym();
    static void refGOTsym();
#endif

#if TARGET_WINDOS
    VIRTUAL int seg_debugT();           // where the symbolic debug type data goes
#endif
};

class ElfObj : public Obj
{
  public:
    static int getsegment(const char *name, const char *suffix,
        int type, int flags, int align);
    static void addrel(int seg, targ_size_t offset, unsigned type,
                       unsigned symidx, targ_size_t val);
    static size_t writerel(int targseg, size_t offset, unsigned type,
                           unsigned symidx, targ_size_t val);
};

class MachObj : public Obj
{
  public:
    static int getsegment(const char *sectname, const char *segname,
        int align, int flags);
    static void addrel(int seg, targ_size_t offset, symbol *targsym,
        unsigned targseg, int rtype, int val = 0);
};

class MachObj64 : public MachObj
{
  public:
    seg_data *tlsseg();
    seg_data *tlsseg_bss();
};

class MsCoffObj : public Obj
{
  public:
    static MsCoffObj *init(Outbuffer *, const char *filename, const char *csegname);
    VIRTUAL void initfile(const char *filename, const char *csegname, const char *modname);
    VIRTUAL void termfile();
    VIRTUAL void term(const char *objfilename);

//    VIRTUAL size_t mangle(Symbol *s,char *dest);
//    VIRTUAL void _import(elem *e);
    VIRTUAL void linnum(Srcpos srcpos, int seg, targ_size_t offset);
    VIRTUAL int codeseg(char *name,int suffix);
//    VIRTUAL void dosseg(void);
    VIRTUAL void startaddress(Symbol *);
    VIRTUAL bool includelib(const char *);
    VIRTUAL bool allowZeroSize();
    VIRTUAL void exestr(const char *p);
    VIRTUAL void user(const char *p);
    VIRTUAL void compiler();
    VIRTUAL void wkext(Symbol *,Symbol *);
//    VIRTUAL void lzext(Symbol *,Symbol *);
    VIRTUAL void _alias(const char *n1,const char *n2);
//    VIRTUAL void theadr(const char *modname);
//    VIRTUAL void segment_group(targ_size_t codesize, targ_size_t datasize, targ_size_t cdatasize, targ_size_t udatasize);
    VIRTUAL void staticctor(Symbol *s,int dtor,int seg);
    VIRTUAL void staticdtor(Symbol *s);
    VIRTUAL void setModuleCtorDtor(Symbol *s, bool isCtor);
    VIRTUAL void ehtables(Symbol *sfunc,unsigned size,Symbol *ehsym);
    VIRTUAL void ehsections();
    VIRTUAL void moduleinfo(Symbol *scc);
    virtual int  comdat(Symbol *);
    virtual int  comdatsize(Symbol *, targ_size_t symsize);
    virtual int readonly_comdat(Symbol *s);
    VIRTUAL void setcodeseg(int seg);
    virtual seg_data *tlsseg();
    virtual seg_data *tlsseg_bss();
    virtual seg_data *tlsseg_data();
    VIRTUAL void export_symbol(Symbol *s, unsigned argsize);
    VIRTUAL void pubdef(int seg, Symbol *s, targ_size_t offset);
    VIRTUAL void pubdefsize(int seg, Symbol *s, targ_size_t offset, targ_size_t symsize);
//    VIRTUAL int external(const char *);
    VIRTUAL int external_def(const char *);
    VIRTUAL int data_start(Symbol *sdata, targ_size_t datasize, int seg);
    VIRTUAL int external(Symbol *);
    VIRTUAL int common_block(Symbol *s, targ_size_t size, targ_size_t count);
    VIRTUAL int common_block(Symbol *s, int flag, targ_size_t size, targ_size_t count);
    VIRTUAL void lidata(int seg, targ_size_t offset, targ_size_t count);
    VIRTUAL void write_zeros(seg_data *pseg, targ_size_t count);
    VIRTUAL void write_byte(seg_data *pseg, unsigned byte);
    VIRTUAL void write_bytes(seg_data *pseg, unsigned nbytes, void *p);
    VIRTUAL void _byte(int seg, targ_size_t offset, unsigned byte);
    VIRTUAL unsigned bytes(int seg, targ_size_t offset, unsigned nbytes, void *p);
//    VIRTUAL void ledata(int seg, targ_size_t offset, targ_size_t data, unsigned lcfd, unsigned idx1, unsigned idx2);
//    VIRTUAL void write_long(int seg, targ_size_t offset, unsigned data, unsigned lcfd, unsigned idx1, unsigned idx2);
    VIRTUAL void reftodatseg(int seg, targ_size_t offset, targ_size_t val, unsigned targetdatum, int flags);
//    VIRTUAL void reftofarseg(int seg, targ_size_t offset, targ_size_t val, int farseg, int flags);
    VIRTUAL void reftocodeseg(int seg, targ_size_t offset, targ_size_t val);
    VIRTUAL int reftoident(int seg, targ_size_t offset, Symbol *s, targ_size_t val, int flags);
    VIRTUAL void far16thunk(Symbol *s);
    VIRTUAL void fltused();
    VIRTUAL int data_readonly(char *p, int len, int *pseg);
    VIRTUAL int data_readonly(char *p, int len);
    VIRTUAL int string_literal_segment(unsigned sz);
    VIRTUAL symbol *sym_cdata(tym_t, char *, int);
    static unsigned addstr(Outbuffer *strtab, const char *);
    VIRTUAL void func_start(Symbol *sfunc);
    VIRTUAL void func_term(Symbol *sfunc);
    VIRTUAL void write_pointerRef(Symbol* s, unsigned off);
    VIRTUAL int jmpTableSegment(Symbol* s);

    static int getsegment(const char *sectname, unsigned long flags);
    static int getsegment2(unsigned shtidx);
    static unsigned addScnhdr(const char *scnhdr_name, unsigned long flags);

    static void addrel(int seg, targ_size_t offset, symbol *targsym,
        unsigned targseg, int rtype, int val);
//    static void addrel(int seg, targ_size_t offset, unsigned type,
//                                        unsigned symidx, targ_size_t val);

    static int seg_drectve();
    static int seg_pdata();
    static int seg_xdata();
    static int seg_pdata_comdat(Symbol *sfunc);
    static int seg_xdata_comdat(Symbol *sfunc);

    static int seg_debugS();
    VIRTUAL int seg_debugT();
    static int seg_debugS_comdat(Symbol *sfunc);

    VIRTUAL symbol *tlv_bootstrap();
};

#endif

extern Obj *objmod;

#undef OMF
#undef OMFandMSCOFF
#undef ELF
#undef MACH

#undef VIRTUAL

#endif
