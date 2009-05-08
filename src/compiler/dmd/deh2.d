/**
 * Implementation of exception handling support routines for Posix.
 *
 * Copyright: Copyright Digital Mars 2000 - 2009.
 * License:   <a href="http://www.boost.org/LICENSE_1_0.txt>Boost License 1.0</a>.
 * Authors:   Walter Bright
 *
 *          Copyright Digital Mars 2000 - 2009.
 * Distributed under the Boost Software License, Version 1.0.
 *    (See accompanying file LICENSE_1_0.txt or copy at
 *          http://www.boost.org/LICENSE_1_0.txt)
 */
module rt.deh2;

//debug=1;

extern (C)
{
    extern __gshared
    {
	void* _deh_beg;
	void* _deh_end;
    }

    int _d_isbaseof(ClassInfo oc, ClassInfo c);
}

alias int (*fp_t)();   // function pointer in ambient memory model

struct DHandlerInfo
{
    uint offset;                // offset from function address to start of guarded section
    uint endoffset;             // offset of end of guarded section
    int prev_index;             // previous table index
    uint cioffset;              // offset to DCatchInfo data from start of table (!=0 if try-catch)
    void *finally_code;         // pointer to finally code to execute
                                // (!=0 if try-finally)
}

// Address of DHandlerTable, searched for by eh_finddata()

struct DHandlerTable
{
    void *fptr;                 // pointer to start of function
    uint espoffset;             // offset of ESP from EBP
    uint retoffset;             // offset from start of function to return code
    uint nhandlers;             // dimension of handler_info[]
    DHandlerInfo handler_info[1];
}

struct DCatchBlock
{
    ClassInfo type;             // catch type
    uint bpoffset;              // EBP offset of catch var
    void *code;                 // catch handler code
}

// Create one of these for each try-catch
struct DCatchInfo
{
    uint ncatches;                      // number of catch blocks
    DCatchBlock catch_block[1];         // data for each catch block
}

// One of these is generated for each function with try-catch or try-finally

struct FuncTable
{
    void *fptr;                 // pointer to start of function
    DHandlerTable *handlertable; // eh data for this function
    uint fsize;         // size of function in bytes
}

void terminate()
{
    asm
    {
        hlt ;
    }
}

/*******************************************
 * Given address that is inside a function,
 * figure out which function it is in.
 * Return DHandlerTable if there is one, NULL if not.
 */

DHandlerTable *__eh_finddata(void *address)
{
    FuncTable *ft;

//    debug printf("__eh_finddata(address = x%x)\n", address);
//    debug printf("_deh_beg = x%x, _deh_end = x%x\n", &_deh_beg, &_deh_end);
    for (ft = cast(FuncTable *)&_deh_beg;
         ft < cast(FuncTable *)&_deh_end;
         ft++)
    {
//      debug printf("\tfptr = x%x, fsize = x%03x, handlertable = x%x\n",
//              ft.fptr, ft.fsize, ft.handlertable);

        if (ft.fptr <= address &&
            address < cast(void *)(cast(char *)ft.fptr + ft.fsize))
        {
//          debug printf("\tfound handler table\n");
            return ft.handlertable;
        }
    }
//    debug printf("\tnot found\n");
    return null;
}


/******************************
 * Given EBP, find return address to caller, and caller's EBP.
 * Input:
 *   regbp       Value of EBP for current function
 *   *pretaddr   Return address
 * Output:
 *   *pretaddr   return address to caller
 * Returns:
 *   caller's EBP
 */

uint __eh_find_caller(uint regbp, uint *pretaddr)
{
    uint bp = *cast(uint *)regbp;

    if (bp)         // if not end of call chain
    {
        // Perform sanity checks on new EBP.
        // If it is screwed up, terminate() hopefully before we do more damage.
        if (bp <= regbp)
            // stack should grow to smaller values
            terminate();

        *pretaddr = *cast(uint *)(regbp + int.sizeof);
    }
    return bp;
}

/***********************************
 * Throw a D object.
 */

extern (Windows) void _d_throw(Object *h)
{
    uint regebp;

    debug
    {
        printf("_d_throw(h = %p, &h = %p)\n", h, &h);
        printf("\tvptr = %p\n", *cast(void **)h);
    }

    asm
    {
        mov regebp,EBP  ;
    }

//static uint abc;
//if (++abc == 2) *(char *)0=0;

//int count = 0;
    while (1)           // for each function on the stack
    {
        DHandlerTable *handler_table;
        FuncTable *pfunc;
        DHandlerInfo *phi;
        uint retaddr;
        uint funcoffset;
        uint spoff;
        uint retoffset;
        int index;
        int dim;
        int ndx;
        int prev_ndx;

        regebp = __eh_find_caller(regebp,&retaddr);
        if (!regebp)
        {   // if end of call chain
            debug printf("end of call chain\n");
            break;
        }

        debug printf("found caller, EBP = x%x, retaddr = x%x\n", regebp, retaddr);
//if (++count == 12) *(char*)0=0;
        handler_table = __eh_finddata(cast(void *)retaddr);   // find static data associated with function
        if (!handler_table)         // if no static data
        {
            debug printf("no handler table\n");
            continue;
        }
        funcoffset = cast(uint)handler_table.fptr;
        spoff = handler_table.espoffset;
        retoffset = handler_table.retoffset;

        debug
        {
            printf("retaddr = x%x\n",cast(uint)retaddr);
            printf("regebp=x%04x, funcoffset=x%04x, spoff=x%x, retoffset=x%x\n",
            regebp,funcoffset,spoff,retoffset);
        }

        // Find start index for retaddr in static data
        dim = handler_table.nhandlers;

        debug
        {
            printf("handler_info[]:\n");
            for (int i = 0; i < dim; i++)
            {
                phi = &handler_table.handler_info[i];
                printf("\t[%d]: offset = x%04x, endoffset = x%04x, prev_index = %d, cioffset = x%04x, finally_code = %x\n",
                        i, phi.offset, phi.endoffset, phi.prev_index, phi.cioffset, phi.finally_code);
            }
        }

        index = -1;
        for (int i = 0; i < dim; i++)
        {
            phi = &handler_table.handler_info[i];

            debug printf("i = %d, phi.offset = %04x\n", i, funcoffset + phi.offset);
            if (cast(uint)retaddr > funcoffset + phi.offset &&
                cast(uint)retaddr <= funcoffset + phi.endoffset)
                index = i;
        }
        debug printf("index = %d\n", index);

        // walk through handler table, checking each handler
        // with an index smaller than the current table_index
        for (ndx = index; ndx != -1; ndx = prev_ndx)
        {
            phi = &handler_table.handler_info[ndx];
            prev_ndx = phi.prev_index;
            if (phi.cioffset)
            {
                // this is a catch handler (no finally)
                DCatchInfo *pci;
                int ncatches;
                int i;

                pci = cast(DCatchInfo *)(cast(char *)handler_table + phi.cioffset);
                ncatches = pci.ncatches;
                for (i = 0; i < ncatches; i++)
                {
                    DCatchBlock *pcb;
                    ClassInfo ci = **cast(ClassInfo **)h;

                    pcb = &pci.catch_block[i];

                    if (_d_isbaseof(ci, pcb.type))
                    {   // Matched the catch type, so we've found the handler.

                        // Initialize catch variable
                        *cast(void **)(regebp + (pcb.bpoffset)) = h;

                        // Jump to catch block. Does not return.
                        {
                            uint catch_esp;
                            fp_t catch_addr;

                            catch_addr = cast(fp_t)(pcb.code);
                            catch_esp = regebp - handler_table.espoffset - fp_t.sizeof;
                            asm
                            {
                                mov     EAX,catch_esp   ;
                                mov     ECX,catch_addr  ;
                                mov     [EAX],ECX       ;
                                mov     EBP,regebp      ;
                                mov     ESP,EAX         ; // reset stack
                                ret                     ; // jump to catch block
                            }
                        }
                    }
                }
            }
            else if (phi.finally_code)
            {   // Call finally block
                // Note that it is unnecessary to adjust the ESP, as the finally block
                // accesses all items on the stack as relative to EBP.

                void *blockaddr = phi.finally_code;

                version (OSX)
                {
                    asm
                    {
                        sub     ESP,4           ; // align stack to 16
                        push    EBX             ;
                        mov     EBX,blockaddr   ;
                        push    EBP             ;
                        mov     EBP,regebp      ;
                        call    EBX             ;
                        pop     EBP             ;
                        pop     EBX             ;
                        add     ESP,4           ;
                    }
                }
                else
                {
                    asm
                    {
                        push        EBX             ;
                        mov         EBX,blockaddr   ;
                        push        EBP             ;
                        mov         EBP,regebp      ;
                        call        EBX             ;
                        pop         EBP             ;
                        pop         EBX             ;
                    }
                }
            }
        }
    }
}
