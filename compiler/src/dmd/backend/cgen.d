/**
 * Generate code instructions
 *
 * Copyright:   Copyright (C) 1985-1998 by Symantec
 *              Copyright (C) 2000-2025 by The D Language Foundation, All Rights Reserved
 * Authors:     $(LINK2 https://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 https://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/compiler/src/dmd/backend/cgen.d, backend/cgen.d)
 * Documentation:  https://dlang.org/phobos/dmd_backend_cgen.html
 * Coverage:    https://codecov.io/gh/dlang/dmd/src/master/compiler/src/dmd/backend/cgen.d
 */

module dmd.backend.cgen;

import core.stdc.stdio;
import core.stdc.stdlib;
import core.stdc.string;

import dmd.backend.barray;
import dmd.backend.cc;
import dmd.backend.cdef;
import dmd.backend.code;
import dmd.backend.x86.code_x86;
import dmd.backend.codebuilder;
import dmd.backend.mem;
import dmd.backend.el;
import dmd.backend.global;
import dmd.backend.obj;
import dmd.backend.ty;
import dmd.backend.type;


nothrow:
@safe:

public import dmd.backend.dt : dt_get_nzeros;
public import dmd.backend.x86.cgcod : cgstate;

/*****************************
 * Find last code in list.
 */

code* code_last(code* c)
{
    if (c)
    {   while (c.next)
            c = c.next;
    }
    return c;
}

/*****************************
 * Set flag bits on last code in list.
 */

void code_orflag(code* c,uint flag)
{
    if (flag && c)
    {   while (c.next)
            c = c.next;
        c.Iflags |= flag;
    }
}

/*****************************
 * Set rex bits on last code in list.
 */

void code_orrex(code* c,uint rex)
{
    if (rex && c)
    {   while (c.next)
            c = c.next;
        c.Irex |= rex;
    }
}


/*****************************
 * Concatenate two code lists together. Return pointer to result.
 */

code* cat(code* c1,code* c2)
{   code** pc;

    if (!c1)
        return c2;
    for (pc = &c1.next; *pc; pc = &(*pc).next)
    { }
    *pc = c2;
    return c1;
}


/*****************************
 * Add code to end of linked list.
 * Note that unused operands are garbage.
 * gen1() and gen2() are shortcut routines.
 * Input:
 *      c ->    linked list that code is to be added to end of
 *      cs ->   data for the code
 * Returns:
 *      pointer to start of code list
 */
private
code* gen(code* c, ref code cs)
{
    assert(I64 || cs.Irex == 0);
    code* ce = code_malloc();
    *ce = cs;
    //printf("ce = %p %02x\n", ce, ce.Iop);
    //ccheck(ce);
    simplify_code(ce);
    ce.next = null;
    if (c)
    {   code* cstart = c;
        while (code_next(c)) c = code_next(c);  /* find end of list     */
        c.next = ce;                      /* link into list       */
        return cstart;
    }
    return ce;
}

code* gen1(code* c,opcode_t op)
{
    code* ce;
    code* cstart;

  ce = code_calloc();
  ce.Iop = op;
  //ccheck(ce);
  assert(op != LEA);
  if (c)
  {     cstart = c;
        while (code_next(c)) c = code_next(c);  /* find end of list     */
        c.next = ce;                      /* link into list       */
        return cstart;
  }
  return ce;
}

code* gen2(code* c,opcode_t op,uint rm)
{
    code* ce;
    code* cstart;

  cstart = ce = code_calloc();
  /*cxcalloc++;*/
  ce.Iop = op;
  ce.Iea = rm;
  //ccheck(ce);
  if (c)
  {     cstart = c;
        while (code_next(c)) c = code_next(c);  /* find end of list     */
        c.next = ce;                      /* link into list       */
  }
  return cstart;
}


code* genc2(code* c,opcode_t op,uint ea,targ_size_t EV2)
{   code cs;

    cs.Iop = op;
    cs.Iea = ea;
    //ccheck(&cs);
    cs.Iflags = CFoff;
    cs.IFL2 = FL.const_;
    cs.IEV2.Vsize_t = EV2;
    return gen(c,cs);
}


/********************************
 * Generate 'nop'
 */

code* gennop(code* c)
{
    return gen1(c,NOP);
}


/****************************************
 * Clean stack after call to codelem().
 */

@trusted
void gencodelem(ref CodeBuilder cdb,elem* e,ref regm_t pretregs,bool constflag)
{
    if (e)
    {
        const stackpushsave = cgstate.stackpush;
        const stackcleansave = cgstate.stackclean;
        cgstate.stackclean = 0;                         // defer cleaning of stack
        codelem(cgstate,cdb,e,pretregs,constflag);
        assert(cgstate.stackclean == 0);
        cgstate.stackclean = stackcleansave;
        genstackclean(cdb,cgstate.stackpush - stackpushsave,pretregs);       // do defered cleaning
    }
}

/**********************************
 * Determine if one of the registers in regm has value in it.
 * Returns:
 *      if so, true and preg is set to which register it is.
 *      otherwise, false and preg is set to 0.
 */

@trusted
bool reghasvalue(regm_t regm,targ_size_t value, out reg_t preg)
{
    //printf("reghasvalue(%s, %llx)\n", regm_str(regm), cast(ulong)value);
    /* See if another register has the right value      */
    reg_t r = 0;
    for (regm_t mreg = cgstate.regcon.immed.mval; mreg; mreg >>= 1)
    {
        if (mreg & regm & 1 && cgstate.regcon.immed.value[r] == value)
        {   preg = r;
            return true;
        }
        r++;
        regm >>= 1;
    }
    return false;
}

/**************************************
 * Load a register from the mask regm with value.
 * Returns:
 *      the register selected
 */
@trusted
reg_t regwithvalue(ref CodeBuilder cdb,regm_t regm,targ_size_t value, regm_t flags)
{
    //printf("regwithvalue(value = %lld)\n", cast(long)value);
    reg_t found;
    if (reghasvalue(regm,value,found))
        return found; // already have a register with the right value in it

    regm_t save = cgstate.regcon.immed.mval;
    const reg = allocreg(cdb,regm,TYint);  // allocate register
    cgstate.regcon.immed.mval = save;
    movregconst(cdb,reg,value,flags);   // store value into reg
    return reg;
}

/************************
 * When we don't know whether a function symbol is defined or not
 * within this module, we stuff it in an array of references to be
 * fixed up later.
 */
struct Fixup
{
    Symbol      *sym;       // the referenced Symbol
    int         seg;        // where the fixup is going (CODE or DATA, never UDATA)
    int         flags;      // CFxxxx
    targ_size_t offset;     // addr of reference to Symbol
    targ_size_t val;        // value to add into location
    Symbol      *funcsym;   // function the Symbol goes in
}

private __gshared Barray!Fixup fixups;

/****************************
 * Add to the fix list.
 */
@trusted
size_t addtofixlist(Symbol* s,targ_size_t offset,int seg,targ_size_t val,int flags)
{
        static immutable ubyte[8] zeros = 0;

        //printf("addtofixlist(%p '%s')\n",s,s.Sident.ptr);
        //assert(I32 || flags); // add AArch64
        Fixup* f = fixups.push();
        f.sym = s;
        f.offset = offset;
        f.seg = seg;
        f.flags = flags;
        f.val = val;
        f.funcsym = funcsym_p;

        size_t numbytes;
if (TARGET_SEGMENTED)
{
        switch (flags & (CFoff | CFseg))
        {
            case CFoff:         numbytes = tysize(TYnptr);      break;
            case CFseg:         numbytes = 2;                   break;
            case CFoff | CFseg: numbytes = tysize(TYfptr);      break;
            default:            assert(0);
        }
}
else
{
        numbytes = tysize(TYnptr);
        if (I64 && !(flags & CFoffset64))
            numbytes = 4;

if (config.exe & EX_windos)
{
        /* This can happen when generating CV8 data
         */
        if (flags & CFseg)
            numbytes += 2;
}
}
        debug assert(numbytes <= zeros.sizeof);
        objmod.bytes(seg,offset,cast(uint)numbytes,cast(ubyte*)zeros.ptr);
        return numbytes;
}

/****************************
 * Output fixups as references to external or static Symbol.
 * First emit data for still undefined static Symbols or mark non-static Symbols as SCextern.
 */
@trusted
private void outfixup(ref Fixup f)
{
    symbol_debug(f.sym);
    //printf("outfixup '%s' offset %04x\n", f.sym.Sident, f.offset);

static if (TARGET_SEGMENTED)
{
    if (tybasic(f.sym.ty()) == TYf16func)
    {
        Obj.far16thunk(f.sym);          /* make it into a thunk         */
        objmod.reftoident(f.seg, f.offset, f.sym, f.val, f.flags);
        return;
    }
}

    if (f.sym.Sxtrnnum == 0)
    {
        if (f.sym.Sclass == SC.static_)
        {
            // OBJ_OMF does not set Sxtrnnum for static Symbols, so check
            // whether the Symbol was assigned to a segment instead, compare
            // outdata(Symbol* s)
            if (f.sym.Sseg == UNKNOWN)
            {
                error(Srcpos.init, "no definition found for static `%s` in this module, statics defined in one module cannot be referenced from another",
                    prettyident(f.sym)); // no definition found for static
                err_exit(); // BUG: do better
            }
        }
        else if (f.sym.Sflags & SFLwasstatic)
        {
            // Put it in BSS
            f.sym.Sclass = SC.static_;
            f.sym.Sfl = FL.unde;
            f.sym.Sdt = dt_get_nzeros(cast(uint)type_size(f.sym.Stype));
            outdata(f.sym);
        }
        else if (f.sym.Sclass != SC.sinline)
        {
            f.sym.Sclass = SC.extern_;   /* make it external             */
            objmod.external(f.sym);
            if (f.sym.Sflags & SFLweak)
                objmod.wkext(f.sym, null);
        }
    }

if (config.exe & (EX_OSX | EX_OSX64))
{
    Symbol* funcsymsave = funcsym_p;
    funcsym_p = f.funcsym;
    objmod.reftoident(f.seg, f.offset, f.sym, f.val, f.flags);
    funcsym_p = funcsymsave;
}
else
{
    objmod.reftoident(f.seg, f.offset, f.sym, f.val, f.flags);
}
}

/****************************
 * End of module. Output fixups as references
 * to external Symbols.
 */
@trusted
void outfixlist()
{
    foreach (ref f; fixups)
        outfixup(f);
    fixups.reset();
}
