// Copyright (C) 1984-1996 by Symantec
// Copyright (C) 2000-2012 by Digital Mars
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

/* cgobj.c */
void obj_init(Outbuffer *, const char *filename, const char *csegname);
void obj_initfile(const char *filename, const char *csegname, const char *modname);
size_t obj_mangle(Symbol *s,char *dest);
void obj_termfile(void);
void obj_term(void);
void obj_import(elem *e);
void objlinnum(Srcpos srcpos, targ_size_t offset);
void obj_dosseg(void);
void obj_startaddress(Symbol *);
bool obj_includelib(const char *);
bool obj_allowZeroSize();
void obj_exestr(const char *p);
void obj_user(const char *p);
void obj_compiler();
void obj_wkext(Symbol *,Symbol *);
void obj_lzext(Symbol *,Symbol *);
void obj_alias(const char *n1,const char *n2);
void obj_theadr(const char *modname);
void objseggrp(targ_size_t codesize, targ_size_t datasize, targ_size_t cdatasize, targ_size_t udatasize);
void obj_staticctor(Symbol *s,int dtor,int seg);
void obj_staticdtor(Symbol *s);
void obj_funcptr(Symbol *s);
void obj_ehtables(Symbol *sfunc,targ_size_t size,Symbol *ehsym);
void obj_ehsections();
void obj_moduleinfo(Symbol *scc);
int  obj_comdat(Symbol *);
int  obj_comdatsize(Symbol *, targ_size_t symsize);
void obj_setcodeseg(int seg);
int  obj_codeseg(char *name,int suffix);
seg_data *obj_tlsseg();
seg_data *obj_tlsseg_bss();
int  obj_fardata(char *name, targ_size_t size, targ_size_t *poffset);
void obj_browse(char *, unsigned);
void objend(void);
void obj_export(Symbol *s, unsigned argsize);
void objpubdef(int seg, Symbol *s, targ_size_t offset);
void objpubdefsize(int seg, Symbol *s, targ_size_t offset, targ_size_t symsize);
#if ELFOBJ
void objpubdefsize(int seg, Symbol *s, targ_size_t offset, targ_size_t symsize);
#elif MACHOBJ
    #define objpubdefsize(seg, s, offset, symsize) objpubdef(seg, s, offset)
#endif
int objextdef(const char *);
int elf_data_start(Symbol *sdata, targ_size_t datasize, int seg);
int objextern(Symbol *);
int obj_comdef(Symbol *s, int flag, targ_size_t size, targ_size_t count);
void obj_lidata(int seg, targ_size_t offset, targ_size_t count);
void obj_write_zeros(seg_data *pseg, targ_size_t count);
void obj_write_byte(seg_data *pseg, unsigned byte);
void obj_write_bytes(seg_data *pseg, unsigned nbytes, void *p);
void obj_byte(int seg, targ_size_t offset, unsigned byte);
unsigned obj_bytes(int seg, targ_size_t offset, unsigned nbytes, void *p);
void objledata(int seg, targ_size_t offset, targ_size_t data, unsigned lcfd, unsigned idx1, unsigned idx2);
void obj_long(int seg, targ_size_t offset, unsigned long data, unsigned lcfd, unsigned idx1, unsigned idx2);
void reftodatseg(int seg, targ_size_t offset, targ_size_t val, unsigned targetdatum, int flags);
void reftofarseg(int seg, targ_size_t offset, targ_size_t val, int farseg, int flags);
void reftocodseg(int seg, targ_size_t offset, targ_size_t val);
int reftoident(int seg, targ_size_t offset, Symbol *s, targ_size_t val, int flags);
void obj_far16thunk(Symbol *s);
void obj_fltused();
int elf_data_cdata(char *p, int len, int *pseg);
int elf_data_cdata(char *p, int len);


#endif
