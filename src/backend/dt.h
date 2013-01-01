// Copyright (C) 1984-1995 by Symantec
// Copyright (C) 2000-2010 by Digital Mars
// All Rights Reserved
// http://www.digitalmars.com
// Written by Walter Bright
/*
 * This source file is made available for personal use
 * only. The license is in backendlicense.txt
 * For any other uses, please contact Digital Mars.
 */

//#pragma once
#ifndef DT_H
#define DT_H    1

/**********************************
 * Data definitions
 *      DTibytes        1..7 bytes
 *      DT1byte         one byte of data follows
 *                      n
 *      DTabytes        offset of bytes of data
 *                      a { a data bytes }
 *      DTnbytes        bytes of data
 *                      a { a data bytes }
 *                      a = offset
 *      DTazeros        # of 0 bytes
 *                      a
 *      DTsymsize       same as DTazeros, but the type of the symbol gives
 *                      the size
 *      DTcommon        # of 0 bytes (in a common block)
 *                      a
 *      DTxoff          offset from symbol
 *                      w a
 *                      w = symbol number (pointer for CPP)
 *                      a = offset
 *      DTcoff          offset into code segment
 *      DTend           mark end of list
 */

struct dt_t
{   dt_t *DTnext;                       // next in list
    char dt;                            // type (DTxxxx)
    unsigned char Dty;                  // pointer type
    union
    {
        struct                          // DTibytes
        {   char DTn_;                  // number of bytes
            #define DTn _DU._DI.DTn_
            char DTdata_[8];            // data
            #define DTdata _DU._DI.DTdata_
        }_DI;
        char DTonebyte_;                // DT1byte
        #define DTonebyte _DU.DTonebyte_
        targ_size_t DTazeros_;          // DTazeros,DTcommon,DTsymsize
        #define DTazeros _DU.DTazeros_
        struct                          // DTabytes
        {
            char *DTpbytes_;            // pointer to the bytes
            #define DTpbytes _DU._DN.DTpbytes_
            unsigned DTnbytes_;         // # of bytes
            #define DTnbytes _DU._DN.DTnbytes_
            int DTseg_;                 // segment it went into
            #define DTseg _DU._DN.DTseg_
            targ_size_t DTabytes_;              // offset of abytes for DTabytes
            #define DTabytes _DU._DN.DTabytes_
        }_DN;
        struct                          // DTxoff
        {
            symbol *DTsym_;             // symbol pointer
            #define DTsym _DU._DS.DTsym_
            targ_size_t DToffset_;      // offset from symbol
            #define DToffset _DU._DS.DToffset_
        }_DS;
    }_DU;
};

enum
{
    DT_abytes,
    DT_azeros,  // 1
    DT_xoff,
    DT_1byte,
    DT_nbytes,
    DT_common,
    DT_symsize,
    DT_coff,
    DT_ibytes, // 8
};

dt_t *dt_calloc(char dtx);
void dt_free(dt_t *);
void dt_term(void);

dt_t **dtnbytes(dt_t **,targ_size_t,const char *);
dt_t **dtabytes(dt_t **pdtend,tym_t ty, targ_size_t offset, targ_size_t size, const char *ptr);
dt_t **dtdword(dt_t **, int value);
dt_t **dtsize_t(dt_t **, targ_size_t value);
dt_t **dtnzeros(dt_t **pdtend,targ_size_t size);
dt_t **dtxoff(dt_t **pdtend,symbol *s,targ_size_t offset,tym_t ty);
dt_t **dtselfoff(dt_t **pdtend,targ_size_t offset,tym_t ty);
dt_t **dtcoff(dt_t **pdtend,targ_size_t offset);
dt_t ** dtcat(dt_t **pdtend,dt_t *dt);
void dt_optimize(dt_t *dt);
void dtsymsize(symbol *);
void init_common(symbol *);
unsigned dt_size(dt_t *dtstart);

#endif /* DT_H */

