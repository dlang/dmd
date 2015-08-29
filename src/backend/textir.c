
#if MARS

#include        <stdio.h>
#include        <string.h>
#include        <time.h>
#include        <stdlib.h>
#include        <stdarg.h>

#include        "cc.h"
#include        "oper.h"
#include        "type.h"
#include        "el.h"
#include        "token.h"
#include        "global.h"
#include        "vec.h"
#include        "go.h"
#include        "code.h"
#include        "outbuf.h"

static char __file__[] = __FILE__;      /* for tassert.h                */
#include        "tassert.h"

extern const char *debtab[OPMAX];

#define TYMAP \
    X(ullong2) \
    X(llong2) \
    X(ulong4) \
    X(long4) \
    X(ushort8) \
    X(short8) \
    X(uchar16) \
    X(schar16) \
    X(double2) \
    X(float4) \
    X(cent) \
    X(ucent) \
    X(npfunc) \
    X(ptr) \
    X(mfunc) \
    X(dchar) \
    X(enum) \
    X(nsfunc) \
    X(nref) \
    X(struct) \
    X(bool) \
    X(void) \
    X(int) \
    X(uint) \
    X(nptr) \
    X(jfunc) \
    X(nfunc) \
    X(ullong) \
    X(schar) \
    X(uchar) \
    X(char) \
    X(ushort) \
    X(short) \
    X(llong) \
    X(ldouble) \
    X(double) \
    X(float) \
    X(wchar_t) \
    X(ulong) \
    X(cdouble) \
    X(cldouble) \
    X(cfloat) \
    X(idouble) \
    X(ildouble) \
    X(ifloat) \
    X(long) \
    X(array)

#define OPMAP \
    X(128_64) \
    X(unord) \
    X(lg) \
    X(leg) \
    X(ule) \
    X(ul) \
    X(uge) \
    X(ug) \
    X(ue) \
    X(d_u64) \
    X(inp) \
    X(outp) \
    X(d_u16) \
    X(d_s16) \
    X(s16_d) \
    X(u64_d) \
    X(modass) \
    X(memcpy) \
    X(rint) \
    X(yl2xp1) \
    X(yl2x) \
    X(abs) \
    X(rndtol) \
    X(sqrt) \
    X(sin) \
    X(cos) \
    X(bool) \
    X(ddtor) \
    X(dctor) \
    X(info) \
    X(ashrass) \
    X(shlass) \
    X(ld_u64) \
    X(d_s32) \
    X(scale) \
    X(popcnt) \
    X(btc) \
    X(bsf) \
    X(s32_d) \
    X(c_i) \
    X(c_r) \
    X(xor) \
    X(d_u32) \
    X(s8_16) \
    X(bsr) \
    X(u32_d) \
    X(d_f) \
    X(com) \
    X(f_d) \
    X(btr) \
    X(bts) \
    X(bswap) \
    X(u16_32) \
    X(orass) \
    X(s16_32) \
    X(xorass) \
    X(shrass) \
    X(s64_d) \
    X(d_ld) \
    X(ld_d) \
    X(d_s64) \
    X(mulass) \
    X(strpar) \
    X(ashr) \
    X(postdec) \
    X(string) \
    X(or) \
    X(divass) \
    X(32_16) \
    X(16_8) \
    X(streq) \
    X(ucall) \
    X(div) \
    X(le) \
    X(ge) \
    X(s32_64) \
    X(andass) \
    X(shl) \
    X(neg) \
    X(mod) \
    X(ucallns) \
    X(callns) \
    X(halt) \
    X(and) \
    X(frameptr) \
    X(minass) \
    X(shr) \
    X(memset) \
    X(u32_64) \
    X(ne) \
    X(min) \
    X(gt) \
    X(colon) \
    X(cond) \
    X(postinc) \
    X(lt) \
    X(u8_16) \
    X(mul) \
    X(msw) \
    X(memcmp) \
    X(64_32) \
    X(addass) \
    X(addr) \
    X(not) \
    X(andand) \
    X(eqeq) \
    X(pair) \
    X(eq) \
    X(ind) \
    X(add) \
    X(relconst) \
    X(var) \
    X(oror) \
    X(const) \
    X(call) \
    X(param) \
    X(comma)

#define BCMAP \
    X(unde) \
    X(goto) \
    X(iftrue) \
    X(ret) \
    X(retexp) \
    X(exit) \
    X(asm) \
    X(switch) \
    X(_try) \
    X(_finally) \
    X(_ret) \
    X(jcatch)

class IRDumper
{
public:
    Outbuffer buf;
    size_t blockCount;

    IRDumper()
    {
        blockCount = 0;
    }

    void xprintf(const char *format, ...)
    {
        va_list va;
        va_start(va, format);
        buf.reserve(1024 * 1024);
        buf.p += vsprintf((char *)buf.p, format, va);
        va_end(va);
    }

    void dumpFunc(symbol *sfunc)
    {
        func_t *f = sfunc->Sfunc;
        xprintf("function: %s\n", sfunc->Sident);

        unsigned i = 0;
        for (block* b = f->Fstartblock; b; b = b->Bnext)
        {
            b->Bweight = i++;
        }
        for (block* b = f->Fstartblock; b; b = b->Bnext)
        {
            dumpBlock(b);
        }
    }

    void dumpBlock(block *b)
    {
        xprintf("block: %llu\n", (unsigned long long)b->Bweight);

        if (b->Belem)
        {
            xprintf("    exp: ");
            dumpElem(b->Belem);
            buf.writeByte('\n');
        }
    #define X(bc) case BC##bc: xprintf("    bc: " #bc); break;
        switch (b->BC)
        {
        BCMAP
        default:
            dbg_printf("unknown BC: %d\n", b->BC);
            assert(0);
        }
    #undef X
        dumpBlockList(b->Bsucc);
        buf.writeByte('\n');
    }

    void dumpBlockList(list_t bl)
    {
        for (; bl; bl = list_next(bl))
        {
            block *b = list_block(bl);
            xprintf(" %d", b->Bweight);
        }
    }

    void dumpOper(unsigned char oper)
    {
    #define X(op) case OP##op: xprintf(#op); break;
        switch (oper)
        {
        OPMAP
        default:
            dbg_printf("Invalid oper ");
            WROP(oper);
            dbg_printf("\n");
            assert(0);
        }
    #undef X
    }

    void dumpTY(tym_t t)
    {
    #define X(ty) case TY##ty: xprintf(#ty); break;
        if (t & mTYconst)
            xprintf("const ");
        if (t & mTYvolatile)
            xprintf("volatile ");
        switch (tybasic(t))
        {
        TYMAP
        default:
            dbg_printf("Invalid type %d", t);
            WRTYxx(t);
            dbg_printf("\n");
            assert(0);
        }
    #undef X
    }

    void dumpElem(elem *e)
    {
        buf.writeByte('(');
        dumpOper(e->Eoper);
        buf.writeByte(' ');
        dumpTY(e->Ety);
        buf.writeByte(' ');

        if (OTunary(e->Eoper) && !e->E2) // Means optionally binary?
        {
            dumpElem(e->E1);
        }
        else if (OTbinary(e->Eoper))
        {
            dumpElem(e->E1);
            buf.writeByte(' ');
            dumpElem(e->E2);
        }
        else
        {
            switch (e->Eoper)
            {
            case OPrelconst:
            case OPvar:
                if (e->Eoffset)
                    xprintf("%s %llu", e->EV.sp.Vsym->Sident, (unsigned long long)e->Eoffset);
                else
                    xprintf("%s", e->EV.sp.Vsym->Sident);
                break;
            case OPasm:
            case OPstring:
                xprintf("\"%*s\" %lld",e->EV.ss.Voffset, e->EV.ss.Vstring,(unsigned long long)e->EV.ss.Voffset);
                break;
            case OPconst:
                dumpConst(e);
                break;

            default:
                break;
            }
        }
        buf.writeByte(')');
    }

    void dumpConst(elem *e)
    {
        assert(e->Eoper == OPconst);
        tym_t tym = tybasic(typemask(e));

        switch (tym)
        {
        case TYbool:
        case TYchar:
        case TYschar:
        case TYuchar:
            xprintf("%d", e->EV.Vuchar);
            break;
        case TYenum:
        case TYint:
        case TYuint:
        case TYvoid:        /* in case (void)(1)    */
            if (tysize[TYint] == LONGSIZE)
                goto L1;
        case TYshort:
        case TYwchar_t:
        case TYushort:
        case TYchar16:
        L3:
            xprintf("%d", e->EV.Vint);
            break;
        case TYlong:
        case TYulong:
        case TYdchar:
        L1:
            xprintf("%d", e->EV.Vlong);
            break;

        case TYllong:
        L2:
            xprintf("%lld", e->EV.Vllong);
            break;

        case TYnptr:
        case TYullong:
            xprintf("%llu", e->EV.Vullong);
            break;

        case TYfloat4:
        case TYdouble2:
        case TYschar16:
        case TYuchar16:
        case TYshort8:
        case TYushort8:
        case TYlong4:
        case TYulong4:
        case TYllong2:
        case TYullong2:
        case TYcent:
        case TYucent:
            xprintf("%08llX%08llX", e->EV.Vcent.msw, e->EV.Vcent.lsw);
            break;

        case TYfloat:
            xprintf("<float>");
            // xprintf("%gf ",(double)e->EV.Vfloat);
            // assert(0);
            break;
        case TYdouble:
        case TYdouble_alias:
            xprintf("<double>");
            // xprintf("%g ",(double)e->EV.Vdouble);
            // assert(0);
            break;
        case TYldouble:
        {
            xprintf("<ldouble>");
            // assert(0);
// #if _MSC_VER
            // char buffer[3 + 3 * sizeof(targ_ldouble) + 1];
            // ld_sprint(buffer, 'g', e->EV.Vldouble);
            // xprintf(buffer);
// #else
            // xprintf("%Lg ", e->EV.Vldouble);
// #endif
            break;
        }
        case TYifloat:
            xprintf("<ifloat>");
            // dbg_printf("%gfi ", (double)e->EV.Vfloat);
            break;

        case TYidouble:
            xprintf("<idouble>");
            // dbg_printf("%gi ", (double)e->EV.Vdouble);
            break;

        case TYildouble:
            xprintf("<cdouble>");
            // dbg_printf("%gLi ", (double)e->EV.Vldouble);
            break;

        case TYcfloat:
            xprintf("<cfloat>");
            // dbg_printf("%gf+%gfi ", (double)e->EV.Vcfloat.re, (double)e->EV.Vcfloat.im);
            break;

        case TYcdouble:
            xprintf("<cdouble>");
            // dbg_printf("%g+%gi ", (double)e->EV.Vcdouble.re, (double)e->EV.Vcdouble.im);
            break;

        case TYcldouble:
            xprintf("<cldouble>");
            // dbg_printf("%gL+%gLi ", (double)e->EV.Vcldouble.re, (double)e->EV.Vcldouble.im);
            break;

        default:

            dbg_printf("Invalid type %d", typemask(e));
            WRTYxx(typemask(e));
            dbg_printf("\n");
            assert(0);
        }
    }
};

void dumpFunc(symbol *sfunc)
{
    IRDumper v;
    v.dumpFunc(sfunc);
    dbg_printf(v.buf.toString());
}

#endif
