
// Compiler implementation of the D programming language
// Copyright (c) 1999-2011 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// http://www.digitalmars.com
// License for redistribution is by either the Artistic License
// in artistic.txt, or the GNU General Public License in gnu.txt.
// See the included readme.txt for details.

#include <stdio.h>
#include <stdlib.h>
#include <assert.h>
#include <math.h>

#if __DMC__
#include <complex.h>
#endif

#include "rmem.h"
#include "root.h"
#include "port.h"

#include "mtype.h"
#include "expression.h"
#include "aggregate.h"
#include "declaration.h"
#include "utf.h"

#define LOG 0

int RealEquals(real_t x1, real_t x2);

Expression *expType(Type *type, Expression *e)
{
    if (type != e->type)
    {
        e = e->copy();
        e->type = type;
    }
    return e;
}

/* ================================== isConst() ============================== */

int Expression::isConst()
{
    //printf("Expression::isConst(): %s\n", toChars());
    return 0;
}

int IntegerExp::isConst()
{
    return 1;
}

int RealExp::isConst()
{
    return 1;
}

int ComplexExp::isConst()
{
    return 1;
}

int NullExp::isConst()
{
    return 0;
}

int SymOffExp::isConst()
{
    return 2;
}

/* =============================== constFold() ============================== */

/* The constFold() functions were redundant with the optimize() ones,
 * and so have been folded in with them.
 */

/* ========================================================================== */

Expression *Neg(Type *type, Expression *e1)
{   Expression *e;
    Loc loc = e1->loc;

    if (e1->type->isreal())
    {
        e = new RealExp(loc, -e1->toReal(), type);
    }
    else if (e1->type->isimaginary())
    {
        e = new RealExp(loc, -e1->toImaginary(), type);
    }
    else if (e1->type->iscomplex())
    {
        e = new ComplexExp(loc, -e1->toComplex(), type);
    }
    else
        e = new IntegerExp(loc, -e1->toInteger(), type);
    return e;
}

Expression *Com(Type *type, Expression *e1)
{   Expression *e;
    Loc loc = e1->loc;

    e = new IntegerExp(loc, ~e1->toInteger(), type);
    return e;
}

Expression *Not(Type *type, Expression *e1)
{   Expression *e;
    Loc loc = e1->loc;

    e = new IntegerExp(loc, e1->isBool(0), type);
    return e;
}

Expression *Bool(Type *type, Expression *e1)
{   Expression *e;
    Loc loc = e1->loc;

    e = new IntegerExp(loc, e1->isBool(1), type);
    return e;
}

Expression *Add(Type *type, Expression *e1, Expression *e2)
{   Expression *e;
    Loc loc = e1->loc;

#if LOG
    printf("Add(e1 = %s, e2 = %s)\n", e1->toChars(), e2->toChars());
#endif
    if (type->isreal())
    {
        e = new RealExp(loc, e1->toReal() + e2->toReal(), type);
    }
    else if (type->isimaginary())
    {
        e = new RealExp(loc, e1->toImaginary() + e2->toImaginary(), type);
    }
    else if (type->iscomplex())
    {
        // This rigamarole is necessary so that -0.0 doesn't get
        // converted to +0.0 by doing an extraneous add with +0.0
        complex_t c1;
        real_t r1;
        real_t i1;

        complex_t c2;
        real_t r2;
        real_t i2;

        complex_t v;
        int x;

        if (e1->type->isreal())
        {   r1 = e1->toReal();
            x = 0;
        }
        else if (e1->type->isimaginary())
        {   i1 = e1->toImaginary();
            x = 3;
        }
        else
        {   c1 = e1->toComplex();
            x = 6;
        }

        if (e2->type->isreal())
        {   r2 = e2->toReal();
        }
        else if (e2->type->isimaginary())
        {   i2 = e2->toImaginary();
            x += 1;
        }
        else
        {   c2 = e2->toComplex();
            x += 2;
        }

        switch (x)
        {
#if __DMC__
            case 0+0:   v = (complex_t) (r1 + r2);      break;
            case 0+1:   v = r1 + i2 * I;                break;
            case 0+2:   v = r1 + c2;                    break;
            case 3+0:   v = i1 * I + r2;                break;
            case 3+1:   v = (complex_t) ((i1 + i2) * I); break;
            case 3+2:   v = i1 * I + c2;                break;
            case 6+0:   v = c1 + r2;                    break;
            case 6+1:   v = c1 + i2 * I;                break;
            case 6+2:   v = c1 + c2;                    break;
#else
            case 0+0:   v = complex_t(r1 + r2, 0);      break;
            case 0+1:   v = complex_t(r1, i2);          break;
            case 0+2:   v = complex_t(r1 + creall(c2), cimagl(c2));     break;
            case 3+0:   v = complex_t(r2, i1);          break;
            case 3+1:   v = complex_t(0, i1 + i2);      break;
            case 3+2:   v = complex_t(creall(c2), i1 + cimagl(c2));     break;
            case 6+0:   v = complex_t(creall(c1) + r2, cimagl(c2));     break;
            case 6+1:   v = complex_t(creall(c1), cimagl(c1) + i2);     break;
            case 6+2:   v = c1 + c2;                    break;
#endif
            default: assert(0);
        }
        e = new ComplexExp(loc, v, type);
    }
    else if (e1->op == TOKsymoff)
    {
        SymOffExp *soe = (SymOffExp *)e1;
        e = new SymOffExp(loc, soe->var, soe->offset + e2->toInteger());
        e->type = type;
    }
    else if (e2->op == TOKsymoff)
    {
        SymOffExp *soe = (SymOffExp *)e2;
        e = new SymOffExp(loc, soe->var, soe->offset + e1->toInteger());
        e->type = type;
    }
    else
        e = new IntegerExp(loc, e1->toInteger() + e2->toInteger(), type);
    return e;
}


Expression *Min(Type *type, Expression *e1, Expression *e2)
{   Expression *e;
    Loc loc = e1->loc;

    if (type->isreal())
    {
        e = new RealExp(loc, e1->toReal() - e2->toReal(), type);
    }
    else if (type->isimaginary())
    {
        e = new RealExp(loc, e1->toImaginary() - e2->toImaginary(), type);
    }
    else if (type->iscomplex())
    {
        // This rigamarole is necessary so that -0.0 doesn't get
        // converted to +0.0 by doing an extraneous add with +0.0
        complex_t c1;
        real_t r1;
        real_t i1;

        complex_t c2;
        real_t r2;
        real_t i2;

        complex_t v;
        int x;

        if (e1->type->isreal())
        {   r1 = e1->toReal();
            x = 0;
        }
        else if (e1->type->isimaginary())
        {   i1 = e1->toImaginary();
            x = 3;
        }
        else
        {   c1 = e1->toComplex();
            x = 6;
        }

        if (e2->type->isreal())
        {   r2 = e2->toReal();
        }
        else if (e2->type->isimaginary())
        {   i2 = e2->toImaginary();
            x += 1;
        }
        else
        {   c2 = e2->toComplex();
            x += 2;
        }

        switch (x)
        {
#if __DMC__
            case 0+0:   v = (complex_t) (r1 - r2);      break;
            case 0+1:   v = r1 - i2 * I;                break;
            case 0+2:   v = r1 - c2;                    break;
            case 3+0:   v = i1 * I - r2;                break;
            case 3+1:   v = (complex_t) ((i1 - i2) * I); break;
            case 3+2:   v = i1 * I - c2;                break;
            case 6+0:   v = c1 - r2;                    break;
            case 6+1:   v = c1 - i2 * I;                break;
            case 6+2:   v = c1 - c2;                    break;
#else
            case 0+0:   v = complex_t(r1 - r2, 0);      break;
            case 0+1:   v = complex_t(r1, -i2);         break;
            case 0+2:   v = complex_t(r1 - creall(c2), -cimagl(c2));    break;
            case 3+0:   v = complex_t(-r2, i1);         break;
            case 3+1:   v = complex_t(0, i1 - i2);      break;
            case 3+2:   v = complex_t(-creall(c2), i1 - cimagl(c2));    break;
            case 6+0:   v = complex_t(creall(c1) - r2, cimagl(c1));     break;
            case 6+1:   v = complex_t(creall(c1), cimagl(c1) - i2);     break;
            case 6+2:   v = c1 - c2;                    break;
#endif
            default: assert(0);
        }
        e = new ComplexExp(loc, v, type);
    }
    else if (e1->op == TOKsymoff)
    {
        SymOffExp *soe = (SymOffExp *)e1;
        e = new SymOffExp(loc, soe->var, soe->offset - e2->toInteger());
        e->type = type;
    }
    else
    {
        e = new IntegerExp(loc, e1->toInteger() - e2->toInteger(), type);
    }
    return e;
}

Expression *Mul(Type *type, Expression *e1, Expression *e2)
{   Expression *e;
    Loc loc = e1->loc;

    if (type->isfloating())
    {   complex_t c;
#ifdef IN_GCC
        real_t r;
#else
        d_float80 r;
#endif

        if (e1->type->isreal())
        {
#if __DMC__
            c = e1->toReal() * e2->toComplex();
#else
            r = e1->toReal();
            c = e2->toComplex();
            c = complex_t(r * creall(c), r * cimagl(c));
#endif
        }
        else if (e1->type->isimaginary())
        {
#if __DMC__
            c = e1->toImaginary() * I * e2->toComplex();
#else
            r = e1->toImaginary();
            c = e2->toComplex();
            c = complex_t(-r * cimagl(c), r * creall(c));
#endif
        }
        else if (e2->type->isreal())
        {
#if __DMC__
            c = e2->toReal() * e1->toComplex();
#else
            r = e2->toReal();
            c = e1->toComplex();
            c = complex_t(r * creall(c), r * cimagl(c));
#endif
        }
        else if (e2->type->isimaginary())
        {
#if __DMC__
            c = e1->toComplex() * e2->toImaginary() * I;
#else
            r = e2->toImaginary();
            c = e1->toComplex();
            c = complex_t(-r * cimagl(c), r * creall(c));
#endif
        }
        else
            c = e1->toComplex() * e2->toComplex();

        if (type->isreal())
            e = new RealExp(loc, creall(c), type);
        else if (type->isimaginary())
            e = new RealExp(loc, cimagl(c), type);
        else if (type->iscomplex())
            e = new ComplexExp(loc, c, type);
        else
            assert(0);
    }
    else
    {
        e = new IntegerExp(loc, e1->toInteger() * e2->toInteger(), type);
    }
    return e;
}

Expression *Div(Type *type, Expression *e1, Expression *e2)
{   Expression *e;
    Loc loc = e1->loc;

    if (type->isfloating())
    {   complex_t c;
#ifdef IN_GCC
        real_t r;
#else
        d_float80 r;
#endif

        //e1->type->print();
        //e2->type->print();
        if (e2->type->isreal())
        {
            if (e1->type->isreal())
            {
                e = new RealExp(loc, e1->toReal() / e2->toReal(), type);
                return e;
            }
#if __DMC__
            //r = e2->toReal();
            //c = e1->toComplex();
            //printf("(%Lg + %Lgi) / %Lg\n", creall(c), cimagl(c), r);

            c = e1->toComplex() / e2->toReal();
#else
            r = e2->toReal();
            c = e1->toComplex();
            c = complex_t(creall(c) / r, cimagl(c) / r);
#endif
        }
        else if (e2->type->isimaginary())
        {
#if __DMC__
            //r = e2->toImaginary();
            //c = e1->toComplex();
            //printf("(%Lg + %Lgi) / %Lgi\n", creall(c), cimagl(c), r);

            c = e1->toComplex() / (e2->toImaginary() * I);
#else
            r = e2->toImaginary();
            c = e1->toComplex();
            c = complex_t(cimagl(c) / r, -creall(c) / r);
#endif
        }
        else
        {
            c = e1->toComplex() / e2->toComplex();
        }

        if (type->isreal())
            e = new RealExp(loc, creall(c), type);
        else if (type->isimaginary())
            e = new RealExp(loc, cimagl(c), type);
        else if (type->iscomplex())
            e = new ComplexExp(loc, c, type);
        else
            assert(0);
    }
    else
    {   sinteger_t n1;
        sinteger_t n2;
        sinteger_t n;

        n1 = e1->toInteger();
        n2 = e2->toInteger();
        if (n2 == 0)
        {   e2->error("divide by 0");
            e2 = new IntegerExp(loc, 1, e2->type);
            n2 = 1;
        }
        if (e1->type->isunsigned() || e2->type->isunsigned())
            n = ((d_uns64) n1) / ((d_uns64) n2);
        else
            n = n1 / n2;
        e = new IntegerExp(loc, n, type);
    }
    return e;
}

Expression *Mod(Type *type, Expression *e1, Expression *e2)
{   Expression *e;
    Loc loc = e1->loc;

    if (type->isfloating())
    {
        complex_t c;

        if (e2->type->isreal())
        {   real_t r2 = e2->toReal();

#ifdef __DMC__
            c = Port::fmodl(e1->toReal(), r2) + Port::fmodl(e1->toImaginary(), r2) * I;
#elif defined(IN_GCC)
            c = complex_t(e1->toReal() % r2, e1->toImaginary() % r2);
#else
            c = complex_t(Port::fmodl(e1->toReal(), r2), Port::fmodl(e1->toImaginary(), r2));
#endif
        }
        else if (e2->type->isimaginary())
        {   real_t i2 = e2->toImaginary();

#ifdef __DMC__
            c = Port::fmodl(e1->toReal(), i2) + Port::fmodl(e1->toImaginary(), i2) * I;
#elif defined(IN_GCC)
            c = complex_t(e1->toReal() % i2, e1->toImaginary() % i2);
#else
            c = complex_t(Port::fmodl(e1->toReal(), i2), Port::fmodl(e1->toImaginary(), i2));
#endif
        }
        else
            assert(0);

        if (type->isreal())
            e = new RealExp(loc, creall(c), type);
        else if (type->isimaginary())
            e = new RealExp(loc, cimagl(c), type);
        else if (type->iscomplex())
            e = new ComplexExp(loc, c, type);
        else
            assert(0);
    }
    else
    {   sinteger_t n1;
        sinteger_t n2;
        sinteger_t n;

        n1 = e1->toInteger();
        n2 = e2->toInteger();
        if (n2 == 0)
        {   e2->error("divide by 0");
            e2 = new IntegerExp(loc, 1, e2->type);
            n2 = 1;
        }
        if (n2 == -1 && !type->isunsigned())
        {    // Check for int.min % -1
            if (n1 == 0xFFFFFFFF80000000ULL && type->toBasetype()->ty != Tint64)
            {
                e2->error("integer overflow: int.min % -1");
                e2 = new IntegerExp(loc, 1, e2->type);
                n2 = 1;
            }
            else if (n1 == 0x8000000000000000LL) // long.min % -1
            {
                e2->error("integer overflow: long.min % -1");
                e2 = new IntegerExp(loc, 1, e2->type);
                n2 = 1;
            }
        }
        if (e1->type->isunsigned() || e2->type->isunsigned())
            n = ((d_uns64) n1) % ((d_uns64) n2);
        else
            n = n1 % n2;
        e = new IntegerExp(loc, n, type);
    }
    return e;
}

Expression *Shl(Type *type, Expression *e1, Expression *e2)
{   Expression *e;
    Loc loc = e1->loc;

    e = new IntegerExp(loc, e1->toInteger() << e2->toInteger(), type);
    return e;
}

Expression *Shr(Type *type, Expression *e1, Expression *e2)
{
    Loc loc = e1->loc;

    dinteger_t value = e1->toInteger();
    dinteger_t dcount = e2->toInteger();
    assert(dcount <= 0xFFFFFFFF);
    unsigned count = (unsigned)dcount;
    switch (e1->type->toBasetype()->ty)
    {
        case Tint8:
                value = (d_int8)(value) >> count;
                break;

        case Tuns8:
                value = (d_uns8)(value) >> count;
                break;

        case Tint16:
                value = (d_int16)(value) >> count;
                break;

        case Tuns16:
                value = (d_uns16)(value) >> count;
                break;

        case Tint32:
                value = (d_int32)(value) >> count;
                break;

        case Tuns32:
                value = (d_uns32)(value) >> count;
                break;

        case Tint64:
                value = (d_int64)(value) >> count;
                break;

        case Tuns64:
                value = (d_uns64)(value) >> count;
                break;

        case Terror:
                return e1;

        default:
                assert(0);
    }
    Expression *e = new IntegerExp(loc, value, type);
    return e;
}

Expression *Ushr(Type *type, Expression *e1, Expression *e2)
{
    Loc loc = e1->loc;

    dinteger_t value = e1->toInteger();
    dinteger_t dcount = e2->toInteger();
    assert(dcount <= 0xFFFFFFFF);
    unsigned count = (unsigned)dcount;
    switch (e1->type->toBasetype()->ty)
    {
        case Tint8:
        case Tuns8:
                // Possible only with >>>=. >>> always gets promoted to int.
                value = (value & 0xFF) >> count;
                break;

        case Tint16:
        case Tuns16:
                // Possible only with >>>=. >>> always gets promoted to int.
                value = (value & 0xFFFF) >> count;
                break;

        case Tint32:
        case Tuns32:
                value = (value & 0xFFFFFFFF) >> count;
                break;

        case Tint64:
        case Tuns64:
                value = (d_uns64)(value) >> count;
                break;

        case Terror:
                return e1;

        default:
                assert(0);
    }
    Expression *e = new IntegerExp(loc, value, type);
    return e;
}

Expression *And(Type *type, Expression *e1, Expression *e2)
{
    Expression *e;
    e = new IntegerExp(e1->loc, e1->toInteger() & e2->toInteger(), type);
    return e;
}

Expression *Or(Type *type, Expression *e1, Expression *e2)
{   Expression *e;
    e = new IntegerExp(e1->loc, e1->toInteger() | e2->toInteger(), type);
    return e;
}

Expression *Xor(Type *type, Expression *e1, Expression *e2)
{   Expression *e;
    e = new IntegerExp(e1->loc, e1->toInteger() ^ e2->toInteger(), type);
    return e;
}

/* Also returns EXP_CANT_INTERPRET if cannot be computed.
 */
Expression *Equal(enum TOK op, Type *type, Expression *e1, Expression *e2)
{   Expression *e;
    Loc loc = e1->loc;
    int cmp;
    real_t r1;
    real_t r2;

    //printf("Equal(e1 = %s, e2 = %s)\n", e1->toChars(), e2->toChars());

    assert(op == TOKequal || op == TOKnotequal);

    if (e1->op == TOKnull)
    {
        if (e2->op == TOKnull)
            cmp = 1;
        else if (e2->op == TOKstring)
        {   StringExp *es2 = (StringExp *)e2;
            cmp = (0 == es2->len);
        }
        else if (e2->op == TOKarrayliteral)
        {   ArrayLiteralExp *es2 = (ArrayLiteralExp *)e2;
            cmp = !es2->elements || (0 == es2->elements->dim);
        }
        else
            return EXP_CANT_INTERPRET;
    }
    else if (e2->op == TOKnull)
    {
        if (e1->op == TOKstring)
        {   StringExp *es1 = (StringExp *)e1;
            cmp = (0 == es1->len);
        }
        else if (e1->op == TOKarrayliteral)
        {   ArrayLiteralExp *es1 = (ArrayLiteralExp *)e1;
            cmp = !es1->elements || (0 == es1->elements->dim);
        }
        else
            return EXP_CANT_INTERPRET;
    }
    else if (e1->op == TOKstring && e2->op == TOKstring)
    {   StringExp *es1 = (StringExp *)e1;
        StringExp *es2 = (StringExp *)e2;

        if (es1->sz != es2->sz)
        {
            assert(global.errors);
            return EXP_CANT_INTERPRET;
        }
        if (es1->len == es2->len &&
            memcmp(es1->string, es2->string, es1->sz * es1->len) == 0)
            cmp = 1;
        else
            cmp = 0;
    }
    else if (e1->op == TOKarrayliteral && e2->op == TOKarrayliteral)
    {   ArrayLiteralExp *es1 = (ArrayLiteralExp *)e1;
        ArrayLiteralExp *es2 = (ArrayLiteralExp *)e2;

        if ((!es1->elements || !es1->elements->dim) &&
            (!es2->elements || !es2->elements->dim))
            cmp = 1;            // both arrays are empty
        else if (!es1->elements || !es2->elements)
            cmp = 0;
        else if (es1->elements->dim != es2->elements->dim)
            cmp = 0;
        else
        {
            for (size_t i = 0; i < es1->elements->dim; i++)
            {   Expression *ee1 = (*es1->elements)[i];
                Expression *ee2 = (*es2->elements)[i];

                Expression *v = Equal(TOKequal, Type::tint32, ee1, ee2);
                if (v == EXP_CANT_INTERPRET)
                    return EXP_CANT_INTERPRET;
                cmp = v->toInteger();
                if (cmp == 0)
                    break;
            }
        }
    }
    else if (e1->op == TOKarrayliteral && e2->op == TOKstring)
    {   // Swap operands and use common code
        Expression *etmp = e1;
        e1 = e2;
        e2 = etmp;
        goto Lsa;
    }
    else if (e1->op == TOKstring && e2->op == TOKarrayliteral)
    {
     Lsa:
        StringExp *es1 = (StringExp *)e1;
        ArrayLiteralExp *es2 = (ArrayLiteralExp *)e2;
        size_t dim1 = es1->len;
        size_t dim2 = es2->elements ? es2->elements->dim : 0;
        if (dim1 != dim2)
            cmp = 0;
        else
        {
            cmp = 1;            // if dim1 winds up being 0
            for (size_t i = 0; i < dim1; i++)
            {
                uinteger_t c = es1->charAt(i);
                Expression *ee2 = (*es2->elements)[i];
                if (ee2->isConst() != 1)
                    return EXP_CANT_INTERPRET;
                cmp = (c == ee2->toInteger());
                if (cmp == 0)
                    break;
            }
        }
    }
    else if (e1->op == TOKstructliteral && e2->op == TOKstructliteral)
    {   StructLiteralExp *es1 = (StructLiteralExp *)e1;
        StructLiteralExp *es2 = (StructLiteralExp *)e2;

        if (es1->sd != es2->sd)
            cmp = 0;
        else if ((!es1->elements || !es1->elements->dim) &&
            (!es2->elements || !es2->elements->dim))
            cmp = 1;            // both arrays are empty
        else if (!es1->elements || !es2->elements)
            cmp = 0;
        else if (es1->elements->dim != es2->elements->dim)
            cmp = 0;
        else
        {
            cmp = 1;
            for (size_t i = 0; i < es1->elements->dim; i++)
            {   Expression *ee1 = (*es1->elements)[i];
                Expression *ee2 = (*es2->elements)[i];

                if (ee1 == ee2)
                    continue;
                if (!ee1 || !ee2)
                {   cmp = 0;
                    break;
                }
                Expression *v = Equal(TOKequal, Type::tint32, ee1, ee2);
                if (v == EXP_CANT_INTERPRET)
                    return EXP_CANT_INTERPRET;
                cmp = v->toInteger();
                if (cmp == 0)
                    break;
            }
        }
    }
#if 0 // Should handle this
    else if (e1->op == TOKarrayliteral && e2->op == TOKstring)
    {
    }
#endif
    else if (e1->isConst() != 1 || e2->isConst() != 1)
        return EXP_CANT_INTERPRET;
    else if (e1->type->isreal())
    {
        r1 = e1->toReal();
        r2 = e2->toReal();
        goto L1;
    }
    else if (e1->type->isimaginary())
    {
        r1 = e1->toImaginary();
        r2 = e2->toImaginary();
     L1:
#if __DMC__
        cmp = (r1 == r2);
#else
        if (Port::isNan(r1) || Port::isNan(r2)) // if unordered
        {
            cmp = 0;
        }
        else
        {
            cmp = (r1 == r2);
        }
#endif
    }
    else if (e1->type->iscomplex())
    {
        cmp = e1->toComplex() == e2->toComplex();
    }
    else if (e1->type->isintegral() || e1->type->toBasetype()->ty == Tpointer)
    {
        cmp = (e1->toInteger() == e2->toInteger());
    }
    else
        return EXP_CANT_INTERPRET;
    if (op == TOKnotequal)
        cmp ^= 1;
    e = new IntegerExp(loc, cmp, type);
    return e;
}

Expression *Identity(enum TOK op, Type *type, Expression *e1, Expression *e2)
{
    Loc loc = e1->loc;
    int cmp;

    if (e1->op == TOKnull)
    {
        cmp = (e2->op == TOKnull);
    }
    else if (e2->op == TOKnull)
    {
        cmp = 0;
    }
    else if (e1->op == TOKsymoff && e2->op == TOKsymoff)
    {
        SymOffExp *es1 = (SymOffExp *)e1;
        SymOffExp *es2 = (SymOffExp *)e2;

        cmp = (es1->var == es2->var && es1->offset == es2->offset);
    }
    else
    {
       if (e1->type->isreal())
       {
           cmp = RealEquals(e1->toReal(), e2->toReal());
       }
       else if (e1->type->isimaginary())
       {
           cmp = RealEquals(e1->toImaginary(), e2->toImaginary());
       }
       else if (e1->type->iscomplex())
       {
           complex_t v1 = e1->toComplex();
           complex_t v2 = e2->toComplex();
           cmp = RealEquals(creall(v1), creall(v2)) &&
                 RealEquals(cimagl(v1), cimagl(v1));
       }
       else
           return Equal((op == TOKidentity) ? TOKequal : TOKnotequal,
                   type, e1, e2);
    }
    if (op == TOKnotidentity)
        cmp ^= 1;
    return new IntegerExp(loc, cmp, type);
}


Expression *Cmp(enum TOK op, Type *type, Expression *e1, Expression *e2)
{   Expression *e;
    Loc loc = e1->loc;
    dinteger_t n;
    real_t r1;
    real_t r2;

    //printf("Cmp(e1 = %s, e2 = %s)\n", e1->toChars(), e2->toChars());

    if (e1->op == TOKstring && e2->op == TOKstring)
    {   StringExp *es1 = (StringExp *)e1;
        StringExp *es2 = (StringExp *)e2;
        size_t sz = es1->sz;
        assert(sz == es2->sz);

        size_t len = es1->len;
        if (es2->len < len)
            len = es2->len;

        int cmp = memcmp(es1->string, es2->string, sz * len);
        if (cmp == 0)
            cmp = es1->len - es2->len;

        switch (op)
        {
            case TOKlt: n = cmp <  0;   break;
            case TOKle: n = cmp <= 0;   break;
            case TOKgt: n = cmp >  0;   break;
            case TOKge: n = cmp >= 0;   break;

            case TOKleg:   n = 1;               break;
            case TOKlg:    n = cmp != 0;        break;
            case TOKunord: n = 0;               break;
            case TOKue:    n = cmp == 0;        break;
            case TOKug:    n = cmp >  0;        break;
            case TOKuge:   n = cmp >= 0;        break;
            case TOKul:    n = cmp <  0;        break;
            case TOKule:   n = cmp <= 0;        break;

            default:
                assert(0);
        }
    }
    else if (e1->isConst() != 1 || e2->isConst() != 1)
        return EXP_CANT_INTERPRET;
    else if (e1->type->isreal())
    {
        r1 = e1->toReal();
        r2 = e2->toReal();
        goto L1;
    }
    else if (e1->type->isimaginary())
    {
        r1 = e1->toImaginary();
        r2 = e2->toImaginary();
     L1:
#if __DMC__
        // DMC is the only compiler I know of that handles NAN arguments
        // correctly in comparisons.
        switch (op)
        {
            case TOKlt:    n = r1 <  r2;        break;
            case TOKle:    n = r1 <= r2;        break;
            case TOKgt:    n = r1 >  r2;        break;
            case TOKge:    n = r1 >= r2;        break;

            case TOKleg:   n = r1 <>=  r2;      break;
            case TOKlg:    n = r1 <>   r2;      break;
            case TOKunord: n = r1 !<>= r2;      break;
            case TOKue:    n = r1 !<>  r2;      break;
            case TOKug:    n = r1 !<=  r2;      break;
            case TOKuge:   n = r1 !<   r2;      break;
            case TOKul:    n = r1 !>=  r2;      break;
            case TOKule:   n = r1 !>   r2;      break;

            default:
                assert(0);
        }
#else
        // Don't rely on compiler, handle NAN arguments separately
        if (Port::isNan(r1) || Port::isNan(r2)) // if unordered
        {
            switch (op)
            {
                case TOKlt:     n = 0;  break;
                case TOKle:     n = 0;  break;
                case TOKgt:     n = 0;  break;
                case TOKge:     n = 0;  break;

                case TOKleg:    n = 0;  break;
                case TOKlg:     n = 0;  break;
                case TOKunord:  n = 1;  break;
                case TOKue:     n = 1;  break;
                case TOKug:     n = 1;  break;
                case TOKuge:    n = 1;  break;
                case TOKul:     n = 1;  break;
                case TOKule:    n = 1;  break;

                default:
                    assert(0);
            }
        }
        else
        {
            switch (op)
            {
                case TOKlt:     n = r1 <  r2;   break;
                case TOKle:     n = r1 <= r2;   break;
                case TOKgt:     n = r1 >  r2;   break;
                case TOKge:     n = r1 >= r2;   break;

                case TOKleg:    n = 1;          break;
                case TOKlg:     n = r1 != r2;   break;
                case TOKunord:  n = 0;          break;
                case TOKue:     n = r1 == r2;   break;
                case TOKug:     n = r1 >  r2;   break;
                case TOKuge:    n = r1 >= r2;   break;
                case TOKul:     n = r1 <  r2;   break;
                case TOKule:    n = r1 <= r2;   break;

                default:
                    assert(0);
            }
        }
#endif
    }
    else if (e1->type->iscomplex())
    {
        assert(0);
    }
    else
    {   sinteger_t n1;
        sinteger_t n2;

        n1 = e1->toInteger();
        n2 = e2->toInteger();
        if (e1->type->isunsigned() || e2->type->isunsigned())
        {
            switch (op)
            {
                case TOKlt:     n = ((d_uns64) n1) <  ((d_uns64) n2);   break;
                case TOKle:     n = ((d_uns64) n1) <= ((d_uns64) n2);   break;
                case TOKgt:     n = ((d_uns64) n1) >  ((d_uns64) n2);   break;
                case TOKge:     n = ((d_uns64) n1) >= ((d_uns64) n2);   break;

                case TOKleg:    n = 1;                                  break;
                case TOKlg:     n = ((d_uns64) n1) != ((d_uns64) n2);   break;
                case TOKunord:  n = 0;                                  break;
                case TOKue:     n = ((d_uns64) n1) == ((d_uns64) n2);   break;
                case TOKug:     n = ((d_uns64) n1) >  ((d_uns64) n2);   break;
                case TOKuge:    n = ((d_uns64) n1) >= ((d_uns64) n2);   break;
                case TOKul:     n = ((d_uns64) n1) <  ((d_uns64) n2);   break;
                case TOKule:    n = ((d_uns64) n1) <= ((d_uns64) n2);   break;

                default:
                    assert(0);
            }
        }
        else
        {
            switch (op)
            {
                case TOKlt:     n = n1 <  n2;   break;
                case TOKle:     n = n1 <= n2;   break;
                case TOKgt:     n = n1 >  n2;   break;
                case TOKge:     n = n1 >= n2;   break;

                case TOKleg:    n = 1;          break;
                case TOKlg:     n = n1 != n2;   break;
                case TOKunord:  n = 0;          break;
                case TOKue:     n = n1 == n2;   break;
                case TOKug:     n = n1 >  n2;   break;
                case TOKuge:    n = n1 >= n2;   break;
                case TOKul:     n = n1 <  n2;   break;
                case TOKule:    n = n1 <= n2;   break;

                default:
                    assert(0);
            }
        }
    }
    e = new IntegerExp(loc, n, type);
    return e;
}

/* Also returns EXP_CANT_INTERPRET if cannot be computed.
 *  to: type to cast to
 *  type: type to paint the result
 */

Expression *Cast(Type *type, Type *to, Expression *e1)
{   Expression *e = EXP_CANT_INTERPRET;
    Loc loc = e1->loc;

    //printf("Cast(type = %s, to = %s, e1 = %s)\n", type->toChars(), to->toChars(), e1->toChars());
    //printf("\te1->type = %s\n", e1->type->toChars());
    if (e1->type->equals(type) && type->equals(to))
        return e1;
    if (e1->type->implicitConvTo(to) >= MATCHconst ||
        to->implicitConvTo(e1->type) >= MATCHconst)
        return expType(to, e1);

    // Allow covariant converions of delegates
    // (Perhaps implicit conversion from pure to impure should be a MATCHconst,
    // then we wouldn't need this extra check.)
    if (e1->type->toBasetype()->ty == Tdelegate &&
        e1->type->implicitConvTo(to) == MATCHconvert)
        return expType(to, e1);

    Type *tb = to->toBasetype();
    Type *typeb = type->toBasetype();

    /* Allow casting from one string type to another
     */
    if (e1->op == TOKstring)
    {
        if (tb->ty == Tarray && typeb->ty == Tarray &&
            tb->nextOf()->size() == typeb->nextOf()->size())
        {
            return expType(to, e1);
        }
    }

    if (e1->op == TOKarrayliteral && typeb == tb)
        return e1;

    if (e1->isConst() != 1)
        return EXP_CANT_INTERPRET;

    if (tb->ty == Tbool)
        e = new IntegerExp(loc, e1->toInteger() != 0, type);
    else if (type->isintegral())
    {
        if (e1->type->isfloating())
        {   dinteger_t result;
            real_t r = e1->toReal();

            switch (typeb->ty)
            {
                case Tint8:     result = (d_int8)r;     break;
                case Tchar:
                case Tuns8:     result = (d_uns8)r;     break;
                case Tint16:    result = (d_int16)r;    break;
                case Twchar:
                case Tuns16:    result = (d_uns16)r;    break;
                case Tint32:    result = (d_int32)r;    break;
                case Tdchar:
                case Tuns32:    result = (d_uns32)r;    break;
                case Tint64:    result = (d_int64)r;    break;
                case Tuns64:    result = (d_uns64)r;    break;
                default:
                    assert(0);
            }

            e = new IntegerExp(loc, result, type);
        }
        else if (type->isunsigned())
            e = new IntegerExp(loc, e1->toUInteger(), type);
        else
            e = new IntegerExp(loc, e1->toInteger(), type);
    }
    else if (tb->isreal())
    {   real_t value = e1->toReal();

        e = new RealExp(loc, value, type);
    }
    else if (tb->isimaginary())
    {   real_t value = e1->toImaginary();

        e = new RealExp(loc, value, type);
    }
    else if (tb->iscomplex())
    {   complex_t value = e1->toComplex();

        e = new ComplexExp(loc, value, type);
    }
    else if (tb->isscalar())
        e = new IntegerExp(loc, e1->toInteger(), type);
    else if (tb->ty == Tvoid)
        e = EXP_CANT_INTERPRET;
    else if (tb->ty == Tstruct && e1->op == TOKint64)
    {   // Struct = 0;
        StructDeclaration *sd = tb->toDsymbol(NULL)->isStructDeclaration();
        assert(sd);
        Expressions *elements = new Expressions;
        for (size_t i = 0; i < sd->fields.dim; i++)
        {   Dsymbol *s = sd->fields.tdata()[i];
            VarDeclaration *v = s->isVarDeclaration();
            assert(v);

            Expression *exp = new IntegerExp(0);
            exp = Cast(v->type, v->type, exp);
            if (exp == EXP_CANT_INTERPRET)
                return exp;
            elements->push(exp);
        }
        e = new StructLiteralExp(loc, sd, elements);
        e->type = type;
    }
    else
    {
        if (type != Type::terror)
            error(loc, "cannot cast %s to %s", e1->type->toChars(), type->toChars());
        e = new ErrorExp();
    }
    return e;
}


Expression *ArrayLength(Type *type, Expression *e1)
{   Expression *e;
    Loc loc = e1->loc;

    if (e1->op == TOKstring)
    {   StringExp *es1 = (StringExp *)e1;

        e = new IntegerExp(loc, es1->len, type);
    }
    else if (e1->op == TOKarrayliteral)
    {   ArrayLiteralExp *ale = (ArrayLiteralExp *)e1;
        size_t dim;

        dim = ale->elements ? ale->elements->dim : 0;
        e = new IntegerExp(loc, dim, type);
    }
    else if (e1->op == TOKassocarrayliteral)
    {   AssocArrayLiteralExp *ale = (AssocArrayLiteralExp *)e1;
        size_t dim = ale->keys->dim;

        e = new IntegerExp(loc, dim, type);
    }
    else
        e = EXP_CANT_INTERPRET;
    return e;
}

/* Also return EXP_CANT_INTERPRET if this fails
 */
Expression *Index(Type *type, Expression *e1, Expression *e2)
{   Expression *e = EXP_CANT_INTERPRET;
    Loc loc = e1->loc;

    //printf("Index(e1 = %s, e2 = %s)\n", e1->toChars(), e2->toChars());
    assert(e1->type);
    if (e1->op == TOKstring && e2->op == TOKint64)
    {   StringExp *es1 = (StringExp *)e1;
        uinteger_t i = e2->toInteger();

        if (i >= es1->len)
            e1->error("string index %ju is out of bounds [0 .. %zu]", i, es1->len);
        else
        {
            e = new IntegerExp(loc, es1->charAt(i), type);
        }
    }
    else if (e1->type->toBasetype()->ty == Tsarray && e2->op == TOKint64)
    {   TypeSArray *tsa = (TypeSArray *)e1->type->toBasetype();
        uinteger_t length = tsa->dim->toInteger();
        uinteger_t i = e2->toInteger();

        if (i >= length)
        {   e1->error("array index %ju is out of bounds %s[0 .. %ju]", i, e1->toChars(), length);
        }
        else if (e1->op == TOKarrayliteral)
        {   ArrayLiteralExp *ale = (ArrayLiteralExp *)e1;
            e = ale->elements->tdata()[i];
            e->type = type;
            if (e->checkSideEffect(2))
                e = EXP_CANT_INTERPRET;
        }
    }
    else if (e1->type->toBasetype()->ty == Tarray && e2->op == TOKint64)
    {
        uinteger_t i = e2->toInteger();

        if (e1->op == TOKarrayliteral)
        {   ArrayLiteralExp *ale = (ArrayLiteralExp *)e1;
            if (i >= ale->elements->dim)
            {   e1->error("array index %ju is out of bounds %s[0 .. %u]", i, e1->toChars(), ale->elements->dim);
            }
            else
            {   e = ale->elements->tdata()[i];
                e->type = type;
                if (e->checkSideEffect(2))
                    e = EXP_CANT_INTERPRET;
            }
        }
    }
    else if (e1->op == TOKassocarrayliteral)
    {
        AssocArrayLiteralExp *ae = (AssocArrayLiteralExp *)e1;
        /* Search the keys backwards, in case there are duplicate keys
         */
        for (size_t i = ae->keys->dim; i;)
        {
            i--;
            Expression *ekey = ae->keys->tdata()[i];
            Expression *ex = Equal(TOKequal, Type::tbool, ekey, e2);
            if (ex == EXP_CANT_INTERPRET)
                return ex;
            if (ex->isBool(TRUE))
            {   e = ae->values->tdata()[i];
                e->type = type;
                if (e->checkSideEffect(2))
                    e = EXP_CANT_INTERPRET;
                break;
            }
        }
    }
    return e;
}

/* Also return EXP_CANT_INTERPRET if this fails
 */
Expression *Slice(Type *type, Expression *e1, Expression *lwr, Expression *upr)
{   Expression *e = EXP_CANT_INTERPRET;
    Loc loc = e1->loc;

#if LOG
    printf("Slice()\n");
    if (lwr)
    {   printf("\te1 = %s\n", e1->toChars());
        printf("\tlwr = %s\n", lwr->toChars());
        printf("\tupr = %s\n", upr->toChars());
    }
#endif
    if (e1->op == TOKstring && lwr->op == TOKint64 && upr->op == TOKint64)
    {   StringExp *es1 = (StringExp *)e1;
        uinteger_t ilwr = lwr->toInteger();
        uinteger_t iupr = upr->toInteger();

        if (iupr > es1->len || ilwr > iupr)
            e1->error("string slice [%ju .. %ju] is out of bounds", ilwr, iupr);
        else
        {
            void *s;
            size_t len = iupr - ilwr;
            int sz = es1->sz;
            StringExp *es;

            s = mem.malloc((len + 1) * sz);
            memcpy((unsigned char *)s, (unsigned char *)es1->string + ilwr * sz, len * sz);
            memset((unsigned char *)s + len * sz, 0, sz);

            es = new StringExp(loc, s, len, es1->postfix);
            es->sz = sz;
            es->committed = 1;
            es->type = type;
            e = es;
        }
    }
    else if (e1->op == TOKarrayliteral &&
            lwr->op == TOKint64 && upr->op == TOKint64 &&
            !e1->checkSideEffect(2))
    {   ArrayLiteralExp *es1 = (ArrayLiteralExp *)e1;
        uinteger_t ilwr = lwr->toInteger();
        uinteger_t iupr = upr->toInteger();

        if (iupr > es1->elements->dim || ilwr > iupr)
            e1->error("array slice [%ju .. %ju] is out of bounds", ilwr, iupr);
        else
        {
            Expressions *elements = new Expressions();
            elements->setDim(iupr - ilwr);
            memcpy(elements->tdata(),
                   es1->elements->tdata() + ilwr,
                   (iupr - ilwr) * sizeof(es1->elements->tdata()[0]));
            e = new ArrayLiteralExp(e1->loc, elements);
            e->type = type;
        }
    }
    return e;
}

/* Also return EXP_CANT_INTERPRET if this fails
 */
Expression *Cat(Type *type, Expression *e1, Expression *e2)
{   Expression *e = EXP_CANT_INTERPRET;
    Loc loc = e1->loc;
    Type *t;
    Type *t1 = e1->type->toBasetype();
    Type *t2 = e2->type->toBasetype();

    //printf("Cat(e1 = %s, e2 = %s)\n", e1->toChars(), e2->toChars());
    //printf("\tt1 = %s, t2 = %s, type = %s\n", t1->toChars(), t2->toChars(), type->toChars());

    if (e1->op == TOKnull && (e2->op == TOKint64 || e2->op == TOKstructliteral))
    {   e = e2;
        t = t1;
        goto L2;
    }
    else if ((e1->op == TOKint64 || e1->op == TOKstructliteral) && e2->op == TOKnull)
    {   e = e1;
        t = t2;
     L2:
        Type *tn = e->type->toBasetype();
        if (tn->ty == Tchar || tn->ty == Twchar || tn->ty == Tdchar)
        {
            // Create a StringExp
            void *s;
            StringExp *es;
            if (t->nextOf())
                t = t->nextOf()->toBasetype();
            int sz = t->size();

            dinteger_t v = e->toInteger();

            size_t len = (t->ty == tn->ty) ? 1 : utf_codeLength(sz, v);
            s = mem.malloc((len + 1) * sz);
            if (t->ty == tn->ty)
                memcpy((unsigned char *)s, &v, sz);
            else
                utf_encode(sz, s, v);

            // Add terminating 0
            memset((unsigned char *)s + len * sz, 0, sz);

            es = new StringExp(loc, s, len);
            es->sz = sz;
            es->committed = 1;
            e = es;
        }
        else
        {   // Create an ArrayLiteralExp
            Expressions *elements = new Expressions();
            elements->push(e);
            e = new ArrayLiteralExp(e->loc, elements);
        }
        e->type = type;
        return e;
    }
    else if (e1->op == TOKnull && e2->op == TOKnull)
    {
        if (type == e1->type)
            return e1;
        if (type == e2->type)
            return e2;
        return new NullExp(e1->loc, type);
    }
    else if (e1->op == TOKstring && e2->op == TOKstring)
    {
        // Concatenate the strings
        void *s;
        StringExp *es1 = (StringExp *)e1;
        StringExp *es2 = (StringExp *)e2;
        StringExp *es;
        size_t len = es1->len + es2->len;
        int sz = es1->sz;

        if (sz != es2->sz)
        {
            /* Can happen with:
             *   auto s = "foo"d ~ "bar"c;
             */
            assert(global.errors);
            return e;
        }
        s = mem.malloc((len + 1) * sz);
        memcpy(s, es1->string, es1->len * sz);
        memcpy((unsigned char *)s + es1->len * sz, es2->string, es2->len * sz);

        // Add terminating 0
        memset((unsigned char *)s + len * sz, 0, sz);

        es = new StringExp(loc, s, len);
        es->sz = sz;
        es->committed = es1->committed | es2->committed;
        es->type = type;
        e = es;
    }
    else if (e2->op == TOKstring && e1->op == TOKarrayliteral &&
        t1->nextOf()->isintegral())
    {
        // Concatenate the strings
        StringExp *es1 = (StringExp *)e2;
        ArrayLiteralExp *es2 = (ArrayLiteralExp *)e1;
        size_t len = es1->len + es2->elements->dim;
        int sz = es1->sz;

        void *s = mem.malloc((len + 1) * sz);
        memcpy((char *)s + sz * es2->elements->dim, es1->string, es1->len * sz);
        for (size_t i = 0; i < es2->elements->dim; i++)
        {   Expression *es2e = es2->elements->tdata()[i];
            if (es2e->op != TOKint64)
                return EXP_CANT_INTERPRET;
            dinteger_t v = es2e->toInteger();
            memcpy((unsigned char *)s + i * sz, &v, sz);
        }

        // Add terminating 0
        memset((unsigned char *)s + len * sz, 0, sz);

        StringExp *es = new StringExp(loc, s, len);
        es->sz = sz;
        es->committed = 0;
        es->type = type;
        e = es;
    }
    else if (e1->op == TOKstring && e2->op == TOKarrayliteral &&
        t2->nextOf()->isintegral())
    {
        // Concatenate the strings
        StringExp *es1 = (StringExp *)e1;
        ArrayLiteralExp *es2 = (ArrayLiteralExp *)e2;
        size_t len = es1->len + es2->elements->dim;
        int sz = es1->sz;

        void *s = mem.malloc((len + 1) * sz);
        memcpy(s, es1->string, es1->len * sz);
        for (size_t i = 0; i < es2->elements->dim; i++)
        {   Expression *es2e = es2->elements->tdata()[i];
            if (es2e->op != TOKint64)
                return EXP_CANT_INTERPRET;
            dinteger_t v = es2e->toInteger();
            memcpy((unsigned char *)s + (es1->len + i) * sz, &v, sz);
        }

        // Add terminating 0
        memset((unsigned char *)s + len * sz, 0, sz);

        StringExp *es = new StringExp(loc, s, len);
        es->sz = sz;
        es->committed = 0; //es1->committed;
        es->type = type;
        e = es;
    }
    else if (e1->op == TOKstring && e2->op == TOKint64)
    {
        // Concatenate the strings
        void *s;
        StringExp *es1 = (StringExp *)e1;
        StringExp *es;
        int sz = es1->sz;
        dinteger_t v = e2->toInteger();

        // Is it a concatentation of homogenous types?
        // (char[] ~ char, wchar[]~wchar, or dchar[]~dchar)
        bool homoConcat = (sz == t2->size());
        size_t len = es1->len;
        len += homoConcat ? 1 : utf_codeLength(sz, v);

        s = mem.malloc((len + 1) * sz);
        memcpy(s, es1->string, es1->len * sz);
        if (homoConcat)
             memcpy((unsigned char *)s + (sz * es1->len), &v, sz);
        else
             utf_encode(sz, (unsigned char *)s + (sz * es1->len), v);

        // Add terminating 0
        memset((unsigned char *)s + len * sz, 0, sz);

        es = new StringExp(loc, s, len);
        es->sz = sz;
        es->committed = es1->committed;
        es->type = type;
        e = es;
    }
    else if (e1->op == TOKint64 && e2->op == TOKstring)
    {
        // Concatenate the strings
        void *s;
        StringExp *es2 = (StringExp *)e2;
        StringExp *es;
        size_t len = 1 + es2->len;
        int sz = es2->sz;
        dinteger_t v = e1->toInteger();

        s = mem.malloc((len + 1) * sz);
        memcpy((unsigned char *)s, &v, sz);
        memcpy((unsigned char *)s + sz, es2->string, es2->len * sz);

        // Add terminating 0
        memset((unsigned char *)s + len * sz, 0, sz);

        es = new StringExp(loc, s, len);
        es->sz = sz;
        es->committed = es2->committed;
        es->type = type;
        e = es;
    }
    else if (e1->op == TOKarrayliteral && e2->op == TOKarrayliteral &&
        t1->nextOf()->equals(t2->nextOf()))
    {
        // Concatenate the arrays
        ArrayLiteralExp *es1 = (ArrayLiteralExp *)e1;
        ArrayLiteralExp *es2 = (ArrayLiteralExp *)e2;

        es1 = new ArrayLiteralExp(es1->loc, (Expressions *)es1->elements->copy());
        es1->elements->insert(es1->elements->dim, es2->elements);
        e = es1;

        if (type->toBasetype()->ty == Tsarray)
        {
            e->type = new TypeSArray(t1->nextOf(), new IntegerExp(loc, es1->elements->dim, Type::tindex));
            e->type = e->type->semantic(loc, NULL);
        }
        else
            e->type = type;
    }
    else if (e1->op == TOKarrayliteral && e2->op == TOKnull &&
        t1->nextOf()->equals(t2->nextOf()))
    {
        e = e1;
        goto L3;
    }
    else if (e1->op == TOKnull && e2->op == TOKarrayliteral &&
        t1->nextOf()->equals(t2->nextOf()))
    {
        e = e2;
     L3:
        // Concatenate the array with null
        ArrayLiteralExp *es = (ArrayLiteralExp *)e;

        es = new ArrayLiteralExp(es->loc, (Expressions *)es->elements->copy());
        e = es;

        if (type->toBasetype()->ty == Tsarray)
        {
            e->type = new TypeSArray(t1->nextOf(), new IntegerExp(loc, es->elements->dim, Type::tindex));
            e->type = e->type->semantic(loc, NULL);
        }
        else
            e->type = type;
    }
    else if ((e1->op == TOKarrayliteral || e1->op == TOKnull) &&
        e1->type->toBasetype()->nextOf()->equals(e2->type))
    {
        ArrayLiteralExp *es1;
        if (e1->op == TOKarrayliteral)
        {   es1 = (ArrayLiteralExp *)e1;
            es1 = new ArrayLiteralExp(es1->loc, (Expressions *)es1->elements->copy());
            es1->elements->push(e2);
        }
        else
        {
            es1 = new ArrayLiteralExp(e1->loc, e2);
        }
        e = es1;

        if (type->toBasetype()->ty == Tsarray)
        {
            e->type = new TypeSArray(e2->type, new IntegerExp(loc, es1->elements->dim, Type::tindex));
            e->type = e->type->semantic(loc, NULL);
        }
        else
            e->type = type;
    }
    else if (e2->op == TOKarrayliteral &&
        e2->type->toBasetype()->nextOf()->equals(e1->type))
    {
        ArrayLiteralExp *es2 = (ArrayLiteralExp *)e2;

        es2 = new ArrayLiteralExp(es2->loc, (Expressions *)es2->elements->copy());
        es2->elements->shift(e1);
        e = es2;

        if (type->toBasetype()->ty == Tsarray)
        {
            e->type = new TypeSArray(e1->type, new IntegerExp(loc, es2->elements->dim, Type::tindex));
            e->type = e->type->semantic(loc, NULL);
        }
        else
            e->type = type;
    }
    else if (e1->op == TOKnull && e2->op == TOKstring)
    {
        t = e1->type;
        e = e2;
        goto L1;
    }
    else if (e1->op == TOKstring && e2->op == TOKnull)
    {   e = e1;
        t = e2->type;
      L1:
        Type *tb = t->toBasetype();
        if (tb->ty == Tarray && tb->nextOf()->equals(e->type))
        {   Expressions *expressions = new Expressions();
            expressions->push(e);
            e = new ArrayLiteralExp(loc, expressions);
            e->type = t;
        }
        if (!e->type->equals(type))
        {   StringExp *se = (StringExp *)e->copy();
            e = se->castTo(NULL, type);
        }
    }
    return e;
}

Expression *Ptr(Type *type, Expression *e1)
{
    //printf("Ptr(e1 = %s)\n", e1->toChars());
    if (e1->op == TOKadd)
    {   AddExp *ae = (AddExp *)e1;
        if (ae->e1->op == TOKaddress && ae->e2->op == TOKint64)
        {   AddrExp *ade = (AddrExp *)ae->e1;
            if (ade->e1->op == TOKstructliteral)
            {   StructLiteralExp *se = (StructLiteralExp *)ade->e1;
                unsigned offset = ae->e2->toInteger();
                Expression *e = se->getField(type, offset);
                if (!e)
                    e = EXP_CANT_INTERPRET;
                return e;
            }
        }
    }
    return EXP_CANT_INTERPRET;
}

