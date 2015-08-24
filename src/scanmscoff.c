
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
    if (buflen < sizeof(BIGOBJ_HEADER))
    {
        reason = __LINE__;
      Lcorrupt:
        error(loc, "MS-Coff object module %s is corrupt, %d", module_name, reason);
        return;
    }

    BIGOBJ_HEADER *header = (BIGOBJ_HEADER *)buf;
    char is_old_coff = false;
    if (header->Sig2 != 0xFFFF && header->Version != 2) {
        is_old_coff = true;
        IMAGE_FILE_HEADER *header_old;
        header_old = (IMAGE_FILE_HEADER *) malloc(sizeof(IMAGE_FILE_HEADER));
        memcpy(header_old, buf, sizeof(IMAGE_FILE_HEADER));

        header = (BIGOBJ_HEADER *) malloc(sizeof(BIGOBJ_HEADER));
        memset(header, 0, sizeof(BIGOBJ_HEADER));
        header->Machine = header_old->Machine;
        header->NumberOfSections = header_old->NumberOfSections;
        header->TimeDateStamp = header_old->TimeDateStamp;
        header->PointerToSymbolTable = header_old->PointerToSymbolTable;
        header->NumberOfSymbols = header_old->NumberOfSymbols;
        free(header_old);
    }

    switch (header->Machine)
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
                        module_name, header->Machine, IMAGE_FILE_MACHINE_AMD64);
            return;
    }

    // Get string table:  string_table[0..string_len]
    size_t off = header->PointerToSymbolTable;
    if (off == 0)
    {
        error(loc, "MS-Coff object module %s has no string table", module_name);
        return;
    }
    off += header->NumberOfSymbols * (is_old_coff?sizeof(SymbolTable):sizeof(SymbolTable32));
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

    for (int i = 0; i < header->NumberOfSymbols; i++)
    {
        SymbolTable32 *n;

        char s[8 + 1];
        char *p;

#if LOG
        printf("Symbol %d:\n",i);
#endif
        off = header->PointerToSymbolTable + i * (is_old_coff?sizeof(SymbolTable):sizeof(SymbolTable32));

        if (off > buflen)
        {   reason = __LINE__;
            goto Lcorrupt;
        }

        n = (SymbolTable32 *)(buf + off);

        if (is_old_coff) {
            SymbolTable *n2;
            n2 = (SymbolTable *) malloc(sizeof(SymbolTable));
            memcpy(n2, (buf + off), sizeof(SymbolTable));
            n = (SymbolTable32 *) malloc(sizeof(SymbolTable32));
            memcpy(n, n2, sizeof(n2->Name));
            n->Value = n2->Value;
            n->SectionNumber = n2->SectionNumber;
            n->Type = n2->Type;
            n->StorageClass = n2->StorageClass;
            n->NumberOfAuxSymbols = n2->NumberOfAuxSymbols;
            free(n2);
        }
        if (n->Zeros)
        {   strncpy(s,(const char *)n->Name,8);
            s[SYMNMLEN] = 0;
            p = s;
        }
        else
            p = string_table + n->Offset - 4;
        i += n->NumberOfAuxSymbols;
#if LOG
        printf("n_name    = '%s'\n",p);
        printf("n_value   = x%08lx\n",n->Value);
        printf("n_scnum   = %d\n", n->SectionNumber);
        printf("n_type    = x%04x\n",n->Type);
        printf("n_sclass  = %d\n", n->StorageClass);
        printf("n_numaux  = %d\n",n->NumberOfAuxSymbols);
#endif
        switch (n->SectionNumber)
        {   case IMAGE_SYM_DEBUG:
                continue;
            case IMAGE_SYM_ABSOLUTE:
                if (strcmp(p, "@comp.id") == 0)
                    continue;
                break;
            case IMAGE_SYM_UNDEFINED:
                // A non-zero value indicates a common block
                if (n->Value)
                    break;
                continue;

            default:
                break;
        }
        switch (n->StorageClass)
        {
            case IMAGE_SYM_CLASS_EXTERNAL:
                break;
            case IMAGE_SYM_CLASS_STATIC:
                if (n->Value == 0)            // if it's a section name
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

