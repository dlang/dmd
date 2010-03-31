
// Copyright (c) 1999-2002 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// http://www.digitalmars.com
// License for redistribution is by either the Artistic License
// in artistic.txt, or the GNU General Public License in gnu.txt.
// See the included readme.txt for details.

// Routines to convert expressions to elems.

#include        <stdio.h>
#include        <string.h>
#include        <time.h>

#include        "cc.h"
#include        "el.h"
#include        "oper.h"
#include        "global.h"
#include        "code.h"
#include        "type.h"
#include        "dt.h"

static char __file__[] = __FILE__;      /* for tassert.h                */
#include        "tassert.h"

/**********************************************
 * Generate code for:
 *      (*eb)[ei] = ev;
 * ev should already be a bit type.
 * result:
 *      0       don't want result
 *      1       want result in flags
 *      2       want value of result
 */

#if 1
#define BIT_SHIFT       3
#define BIT_MASK        7
#define TYbit           TYuchar
#else
#define BIT_SHIFT       5
#define BIT_MASK        31
#define TYbit           TYuint
#endif

elem *bit_assign(enum OPER op, elem *eb, elem *ei, elem *ev, int result)
{
#if 1
    elem *e;
    elem *es;
    elem *er;

    es = el_bin(OPbts, TYbit, eb, ei);
    er = el_copytree(es);
    er->Eoper = OPbtr;
    es = el_bin(OPcomma, TYbit, es, el_long(TYbit, 1));
    er = el_bin(OPcomma, TYbit, er, el_long(TYbit, 0));

    e = el_bin(OPcolon, TYvoid, es, er);
    e = el_bin(OPcond, ev->Ety, ev, e);
    return e;
#else
    /*
        The idea is:

        *(eb + (ei >> 5)) &= ~(1 << (ei & 31));
        *(eb + (ei >> 5)) |= ev << (ei & 31);
        ev;

        So we generate:

        et = (eb + (ei >> 5));
        em = (eit & 31);
        *ett = (*et & ~(1 << em)) | (ev << em);
        evt;
     */

    printf("bit_assign()\n");

    elem *e;
    elem *em;
    elem *eit = el_same(&ei);
    elem *et;
    elem *ett;
    elem *evt = el_same(&ev);

    ei->Ety = TYuint;
    et = el_bin(OPshr, TYuint, ei, el_long(TYuint, BIT_SHIFT));
    et = el_bin(OPadd, TYnptr, eb, et);
    ett = el_same(&et);

    eit->Ety = TYbit;
    em = el_bin(OPand, TYbit, eit, el_long(TYbit, BIT_MASK));

    e = el_bin(OPshl, TYbit, el_long(TYbit, 1), em);
    e = el_una(OPcom, TYbit, e);
    et = el_una(OPind, TYbit, et);
    e = el_bin(OPand, TYbit, et, e);

    ev->Ety = TYbit;
    e = el_bin(OPor, TYbit, e, el_bin(OPshl, TYbit, ev, el_copytree(em)));
    ett = el_una(OPind, TYbit, ett);
    e = el_bin(OPeq, TYbit, ett, e);

    e = el_bin(OPcomma, evt->Ety, e, evt);
    return e;
#endif
}

/**********************************************
 * Generate code for:
 *      (*eb)[ei]
 * ev should already be a bit type.
 * result:
 *      0       don't want result
 *      1       want result in flags
 *      2       want value of result
 *      3       ?
 */

elem *bit_read(elem *eb, elem *ei, int result)
{
#if 1
    elem *e;

    e = el_bin(OPbt, TYbit, eb, ei);
    e = el_bin(OPand, TYbit, e, el_long(TYbit, 1));
    return e;
#else
    // eb[ei] => (eb[ei >>> 5] >> (ei & 31)) & 1
    elem *e;
    elem *eit = el_same(&ei);

    // Now generate ((*(eb + (ei >>> 5)) >>> (eit & 31)) & 1

    ei->Ety = TYuint;
    e = el_bin(OPshr, TYuint, ei, el_long(TYuint, BIT_SHIFT));
    e = el_bin(OPadd, TYnptr, eb, e);
    e = el_una(OPind, TYbit, e);
    eit->Ety = TYbit;
    eit = el_bin(OPand, TYbit, eit, el_long(TYbit, BIT_MASK));
    e = el_bin(OPshr, TYbit, e, eit);
    e = el_bin(OPand, TYbit, e, el_long(TYbit, 1));

    // BUG: what about return type of e?
    return e;
#endif
}
