
/* Compiler implementation of the D programming language
 * Copyright (c) 1999-2014 by Digital Mars
 * All Rights Reserved
 * written by Walter Bright
 * http://www.digitalmars.com
 * Distributed under the Boost Software License, Version 1.0.
 * http://www.boost.org/LICENSE_1_0.txt
 * https://github.com/D-Programming-Language/dmd/blob/master/src/scanmscoff.c
 */

/* Implements scanning an object module for names to go in the library table of contents.
 * The object module format is MS-COFF.
 * This format is described in the Microsoft document
 * "Microsoft Portable Executable and Common Object File Format Specification"
 * Revision 8.2 September 21, 2010
 */

#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <assert.h>

#include "mscoff.h"

#include "root.h"
#include "mars.h"

#define LOG 0


/*****************************************
 * Reads an object module from base[0..buflen] and passes the names
 * of any exported symbols to (*pAddSymbol)().
 * Input:
 *      pctx            context pointer, pass to *pAddSymbol
 *      pAddSymbol      function to pass the names to
 *      base[0..buflen] contains contents of object module
 *      module_name     name of the object module (used for error messages)
 *      loc             location to use for error printing
 */

void scanMSCoffObjModule(void* pctx, void (*pAddSymbol)(void* pctx, char* name, int pickAny), void *base, size_t buflen, const char *module_name, Loc loc)
{
#if LOG
    printf("scanMSCoffObjModule(%s)\n", module_name);
#endif

    unsigned char *buf = (unsigned char *)base;
    int reason;

    /* First do sanity checks on object file
     */
    if (buflen < sizeof(struct filehdr))
    {
        reason = __LINE__;
      Lcorrupt:
        error(loc, "MS-Coff object module %s is corrupt, %d", module_name, reason);
        return;
    }

    struct filehdr *header = (struct filehdr *)buf;
    char is_old_coff = false;
    if (header->f_sig2 != 0xFFFF && header->f_minver != 2) {
        is_old_coff = true;
        struct filehdr_old *header_old;
        header_old = (filehdr_old *) malloc(sizeof(filehdr_old));
        memcpy(header_old, buf, sizeof(filehdr_old));
        
        header = (filehdr *) malloc(sizeof(filehdr));
        memset(header, 0, sizeof(filehdr));
        header->f_magic = header_old->f_magic;
        header->f_nscns = header_old->f_nscns;
        header->f_timdat = header_old->f_timdat;
        header->f_symptr = header_old->f_symptr;
        header->f_nsyms = header_old->f_nsyms;
        free(header_old);
    }
    
    switch (header->f_magic)
    {
        case IMAGE_FILE_MACHINE_UNKNOWN:
        case IMAGE_FILE_MACHINE_I386:
        case IMAGE_FILE_MACHINE_AMD64:
            break;

        default:
            if (buf[0] == 0x80)
                error(loc, "Object module %s is 32 bit OMF, but it should be 64 bit MS-Coff",
                        module_name);
            else
                error(loc, "MS-Coff object module %s has magic = %x, should be %x",
                        module_name, header->f_magic, IMAGE_FILE_MACHINE_AMD64);
            return;
    }

    // Get string table:  string_table[0..string_len]
    size_t off = header->f_symptr;
    if (off == 0)
    {
        error(loc, "MS-Coff object module %s has no string table", module_name);
        return;
    }
    off += header->f_nsyms * (is_old_coff?sizeof(struct syment_old):sizeof(struct syment));
    if (off + 4 > buflen)
    {   reason = __LINE__;
        goto Lcorrupt;
    }
    unsigned string_len = *(unsigned *)(buf + off);
    char *string_table = (char *)(buf + off + 4);
    if (off + string_len > buflen)
    {   reason = __LINE__;
        goto Lcorrupt;
    }
    string_len -= 4;

    for (int i = 0; i < header->f_nsyms; i++)
    {   
        struct syment *n;
        
        char s[8 + 1];
        char *p;

#if LOG
        printf("Symbol %d:\n",i);
#endif
        off = header->f_symptr + i * (is_old_coff?sizeof(syment_old):sizeof(syment));
        
        if (off > buflen)
        {   reason = __LINE__;
            goto Lcorrupt;
        }
        
        n = (struct syment *)(buf + off);
        
        if (is_old_coff) {
            struct syment_old *n2;
            n2 = (syment_old *) malloc(sizeof(syment_old));
            memcpy(n2, (buf + off), sizeof(syment_old));
            n = (syment *) malloc(sizeof(syment));
            memcpy(n, n2, sizeof(n2->_n));
            n->n_value = n2->n_value;
            n->n_scnum = n2->n_scnum;
            n->n_type = n2->n_type;
            n->n_sclass = n2->n_sclass;
            n->n_numaux = n2->n_numaux;
            free(n2);
        }
        if (n->n_zeroes)
        {   strncpy(s,n->n_name,8);
            s[SYMNMLEN] = 0;
            p = s;
        }
        else
            p = string_table + n->n_offset - 4;
        i += n->n_numaux;
#if LOG
        printf("n_name    = '%s'\n",p);
        printf("n_value   = x%08lx\n",n->n_value);
        printf("n_scnum   = %d\n", n->n_scnum);
        printf("n_type    = x%04x\n",n->n_type);
        printf("n_sclass  = %d\n", n->n_sclass);
        printf("n_numaux  = %d\n",n->n_numaux);
#endif
        switch (n->n_scnum)
        {   case IMAGE_SYM_DEBUG:
                continue;
            case IMAGE_SYM_ABSOLUTE:
                if (strcmp(p, "@comp.id") == 0)
                    continue;
                break;
            case IMAGE_SYM_UNDEFINED:
                // A non-zero value indicates a common block
                if (n->n_value)
                    break;
                continue;

            default:
                break;
        }
        switch (n->n_sclass)
        {
            case IMAGE_SYM_CLASS_EXTERNAL:
                break;
            case IMAGE_SYM_CLASS_STATIC:
                if (n->n_value == 0)            // if it's a section name
                    continue;
                continue;
            case IMAGE_SYM_CLASS_FUNCTION:
            case IMAGE_SYM_CLASS_FILE:
            case IMAGE_SYM_CLASS_LABEL:
                continue;
            default:
                continue;
        }
        (*pAddSymbol)(pctx, p, 1);
    }
}

