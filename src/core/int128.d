/* 128 bit integer arithmetic.
 *
 * Not optimized for speed.
 *
 * Copyright: Copyright D Language Foundation 2022.
 * License:   $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Authors:   Walter Bright
 * Source:    $(DRUNTIMESRC core/_int128.d)
 */

module core.int128;

nothrow:
@safe:
@nogc:

alias I = long;
alias U = ulong;
enum Ubits = U.sizeof * 8;

align(16) struct Cent
{
    U lo;      // low 64 bits
    U hi;      // high 64 bits
}

enum One = Cent(1);
enum Zero = Cent();
enum MinusOne = neg(One);

/*****************************
 * Test against 0
 * Params:
 *      c = Cent to test
 * Returns:
 *      true if != 0
 */
pure
bool tst(Cent c)
{
    return c.hi || c.lo;
}


/*****************************
 * Complement
 * Params:
 *      c = Cent to complement
 * Returns:
 *      complemented value
 */
pure
Cent com(Cent c)
{
    c.lo = ~c.lo;
    c.hi = ~c.hi;
    return c;
}

/*****************************
 * Negate
 * Params:
 *      c = Cent to negate
 * Returns:
 *      negated value
 */
pure
Cent neg(Cent c)
{
    return inc(com(c)); // ~c + 1
}

/*****************************
 * Increment
 * Params:
 *      c = Cent to increment
 * Returns:
 *      incremented value
 */
pure
Cent inc(Cent c)
{
    return add(c, One);
}

/*****************************
 * Decrement
 * Params:
 *      c = Cent to decrement
 * Returns:
 *      incremented value
 */
pure
Cent dec(Cent c)
{
    return sub(c, One);
}

/*****************************
 * Shift left one bit
 * Params:
 *      c = Cent to shift
 * Returns:
 *      shifted value
 */
pure
Cent shl1(Cent c)
{
    c.hi = (c.hi << 1) | (cast(I)c.lo < 0);
    c.lo <<= 1;
    return c;
}

/*****************************
 * Unsigned shift right one bit
 * Params:
 *      c = Cent to shift
 * Returns:
 *      shifted value
 */
pure
Cent shr1(Cent c)
{
    c.lo = (c.lo >> 1) | ((c.hi & 1) << (Ubits - 1));
    c.hi >>= 1;
    return c;
}


/*****************************
 * Arithmetic shift right one bit
 * Params:
 *      c = Cent to shift
 * Returns:
 *      shifted value
 */
pure
Cent sar1(Cent c)
{
    c.lo = (c.lo >> 1) | ((c.hi & 1) << (Ubits - 1));
    c.hi = cast(I)c.hi >> 1;
    return c;
}

/*****************************
 * Shift left n bits
 * Params:
 *      c = Cent to shift
 *      n = number of bits to shift
 * Returns:
 *      shifted value
 */
pure
Cent shl(Cent c, uint n)
{
    if (n >= Ubits * 2)
        return Zero;

    if (n >= Ubits)
    {
        c.hi = c.lo << (n - Ubits);
        c.lo = 0;
    }
    else
    {
        c.hi = ((c.hi << n) | (c.lo >> (Ubits - n - 1) >> 1));
        c.lo = c.lo << n;
    }
    return c;
}

/*****************************
 * Unsigned shift right n bits
 * Params:
 *      c = Cent to shift
 *      n = number of bits to shift
 * Returns:
 *      shifted value
 */
pure
Cent shr(Cent c, uint n)
{
    if (n >= Ubits * 2)
        return Zero;

    if (n >= Ubits)
    {
        c.lo = c.hi >> (n - Ubits);
        c.hi = 0;
    }
    else
    {
        c.lo = ((c.lo >> n) | (c.hi << (Ubits - n - 1) << 1));
        c.hi = c.hi >> n;
    }
    return c;
}

/*****************************
 * Arithmetic shift right n bits
 * Params:
 *      c = Cent to shift
 *      n = number of bits to shift
 * Returns:
 *      shifted value
 */
pure
Cent sar(Cent c, uint n)
{
    if (n >= Ubits * 2)
    {
        if (cast(I)c.hi < 0)
            return com(Zero);
        return Zero;
    }

    foreach (i; 0 .. n)
        c = sar1(c);
    return c;
}

/*****************************
 * Rotate left one bit
 * Params:
 *      c = Cent to rotate
 * Returns:
 *      rotated value
 */
pure
Cent rol1(Cent c)
{
    int carry = cast(I)c.hi < 0;

    c.hi = (c.hi << 1) | (cast(I)c.lo < 0);
    c.lo = (c.lo << 1) | carry;
    return c;
}

/*****************************
 * Rotate right one bit
 * Params:
 *      c = Cent to rotate
 * Returns:
 *      rotated value
 */
pure
Cent ror1(Cent c)
{
    int carry = c.lo & 1;
    c.lo = (c.lo >> 1) | (cast(U)(c.hi & 1) << (Ubits - 1));
    c.hi = (c.hi >> 1) | (cast(U)carry << (Ubits - 1));
    return c;
}


/*****************************
 * Rotate left n bits
 * Params:
 *      c = Cent to rotate
 *      n = number of bits to rotate
 * Returns:
 *      rotated value
 */
pure
Cent rol(Cent c, uint n)
{
    n &= Ubits * 2 - 1;
    foreach (i; 0 .. n)
        c = rol1(c);
    return c;
}

/*****************************
 * Rotate right n bits
 * Params:
 *      c = Cent to rotate
 *      n = number of bits to rotate
 * Returns:
 *      rotated value
 */
pure
Cent ror(Cent c, uint n)
{
    n &= Ubits * 2 - 1;
    foreach (i; 0 .. n)
        c = ror1(c);
    return c;
}

/****************************
 * And c1 & c2.
 * Params:
 *      c1 = operand 1
 *      c2 = operand 2
 * Returns:
 *      c1 & c2
 */
pure
Cent and(Cent c1, Cent c2)
{
    return Cent(c1.lo & c2.lo, c1.hi & c2.hi);
}

/****************************
 * Or c1 | c2.
 * Params:
 *      c1 = operand 1
 *      c2 = operand 2
 * Returns:
 *      c1 | c2
 */
pure
Cent or(Cent c1, Cent c2)
{
    return Cent(c1.lo | c2.lo, c1.hi | c2.hi);
}

/****************************
 * Xor c1 ^ c2.
 * Params:
 *      c1 = operand 1
 *      c2 = operand 2
 * Returns:
 *      c1 ^ c2
 */
pure
Cent xor(Cent c1, Cent c2)
{
    return Cent(c1.lo ^ c2.lo, c1.hi ^ c2.hi);
}

/****************************
 * Add c1 to c2.
 * Params:
 *      c1 = operand 1
 *      c2 = operand 2
 * Returns:
 *      c1 + c2
 */
pure
Cent add(Cent c1, Cent c2)
{
    U r = cast(U)(c1.lo + c2.lo);
    return Cent(r, cast(U)(c1.hi + c2.hi + (r < c1.lo)));
}

/****************************
 * Subtract c2 from c1.
 * Params:
 *      c1 = operand 1
 *      c2 = operand 2
 * Returns:
 *      c1 - c2
 */
pure
Cent sub(Cent c1, Cent c2)
{
    return add(c1, neg(c2));
}

/****************************
 * Multiply c1 * c2.
 * Params:
 *      c1 = operand 1
 *      c2 = operand 2
 * Returns:
 *      c1 * c2
 */
pure
Cent mul(Cent c1, Cent c2)
{
    Cent r;
    foreach (i; 0 .. Ubits * 2)
    {
        if (c1.lo & 1)
            r = add(r, c2);

        c1 = shr1(c1);
        if (!tst(c1))
            break;

        c2 = shl1(c2);
        if (!tst(c2))
            break;
    }
    return r;
}


/****************************
 * Unsigned divide c1 / c2.
 * Params:
 *      c1 = dividend
 *      c2 = divisor
 * Returns:
 *      quotient c1 / c2
 */
pure
Cent udiv(Cent c1, Cent c2)
{
    Cent modulus;
    return udivmod(c1, c2, modulus);
}

/****************************
 * Unsigned divide c1 / c2. The remainder after division is stored to modulus.
 * Params:
 *      c1 = dividend
 *      c2 = divisor
 *      modulus = set to c1 % c2
 * Returns:
 *      quotient c1 / c2
 */
pure
Cent udivmod(Cent c1, Cent c2, out Cent modulus)
{
    //printf("udiv c1(%llx,%llx) c2(%llx,%llx)\n", c1.lo, c1.hi, c2.lo, c2.hi);
    if (!tst(c2))
    {
        // Divide by zero
        modulus = Zero;
        return com(modulus);
    }

    // left justify c2
    uint shifts = 1;
    while (cast(I)c2.hi >= 0)
    {
        c2 = shl1(c2);
        ++shifts;
    }

    // subtract and shift, just like 3rd grade long division
    Cent quotient;
    while (shifts--)
    {
        //printf("shifts %d c1(%llx,%llx) c2(%llx,%llx)\n", shifts, c1.lo, c1.hi, c2.lo, c2.hi);
        quotient = shl1(quotient);
        if (uge(c1, c2))
        {
            //printf("sub\n");
            c1 = sub(c1, c2);
            quotient.lo |= 1;
        }
        c2 = shr1(c2);
    }
    modulus = c1;
    //printf("quotient "); print(quotient);
    //printf("modulus  "); print(modulus);
    return quotient;
}


/****************************
 * Signed divide c1 / c2.
 * Params:
 *      c1 = dividend
 *      c2 = divisor
 * Returns:
 *      quotient c1 / c2
 */
pure
Cent div(Cent c1, Cent c2)
{
    Cent modulus;
    return divmod(c1, c2, modulus);
}

/****************************
 * Signed divide c1 / c2. The remainder after division is stored to modulus.
 * Params:
 *      c1 = dividend
 *      c2 = divisor
 *      modulus = set to c1 % c2
 * Returns:
 *      quotient c1 / c2
 */
pure
Cent divmod(Cent c1, Cent c2, out Cent modulus)
{
    /* Muck about with the signs so we can use the unsigned divide
     */
    if (cast(I)c1.hi < 0)
    {
        if (cast(I)c2.hi < 0)
        {
            Cent r = udivmod(neg(c1), neg(c2), modulus);
            modulus = neg(modulus);
            return r;
        }
        Cent r = neg(udivmod(neg(c1), c2, modulus));
        modulus = neg(modulus);
        return r;
    }
    else if (cast(I)c2.hi < 0)
    {
        return neg(udivmod(c1, neg(c2), modulus));
    }
    else
        return udivmod(c1, c2, modulus);
}

/****************************
 * If c1 > c2 unsigned
 * Params:
 *      c1 = operand 1
 *      c2 = operand 2
 * Returns:
 *      true if c1 > c2
 */
pure
bool ugt(Cent c1, Cent c2)
{
    return (c1.hi == c2.hi) ? (c1.lo > c2.lo) : (c1.hi > c2.hi);
}

/****************************
 * If c1 >= c2 unsigned
 * Params:
 *      c1 = operand 1
 *      c2 = operand 2
 * Returns:
 *      true if c1 >= c2
 */
pure
bool uge(Cent c1, Cent c2)
{
    return !ugt(c2, c1);
}

/****************************
 * If c1 < c2 unsigned
 * Params:
 *      c1 = operand 1
 *      c2 = operand 2
 * Returns:
 *      true if c1 < c2
 */
pure
bool ult(Cent c1, Cent c2)
{
    return ugt(c2, c1);
}

/****************************
 * If c1 <= c2 unsigned
 * Params:
 *      c1 = operand 1
 *      c2 = operand 2
 * Returns:
 *      true if c1 <= c2
 */
pure
bool ule(Cent c1, Cent c2)
{
    return !ugt(c1, c2);
}

/****************************
 * If c1 > c2 signed
 * Params:
 *      c1 = operand 1
 *      c2 = operand 2
 * Returns:
 *      true if c1 > c2
 */
pure
bool gt(Cent c1, Cent c2)
{
    if (cast(I)c1.hi >= 0)
    {
        if (cast(I)c2.hi >= 0)
            return ugt(c1, c2);
        return true;
    }
    if (cast(I)c2.hi >= 0)
        return false;
    return ugt(c1, c2);

}

/****************************
 * If c1 >= c2 signed
 * Params:
 *      c1 = operand 1
 *      c2 = operand 2
 * Returns:
 *      true if c1 >= c2
 */
pure
bool ge(Cent c1, Cent c2)
{
    return !gt(c2, c1);
}

/****************************
 * If c1 < c2 signed
 * Params:
 *      c1 = operand 1
 *      c2 = operand 2
 * Returns:
 *      true if c1 < c2
 */
pure
bool lt(Cent c1, Cent c2)
{
    return gt(c2, c1);
}

/****************************
 * If c1 <= c2 signed
 * Params:
 *      c1 = operand 1
 *      c2 = operand 2
 * Returns:
 *      true if c1 <= c2
 */
pure
bool le(Cent c1, Cent c2)
{
    return !gt(c1, c2);
}

/*******************************************************/

version (unittest)
{
    version (none)
    {
        import core.stdc.stdio;

        @trusted
        void print(Cent c)
        {
            printf("%lld, %lld\n", cast(ulong)c.lo, cast(ulong)c.hi);
            printf("x%llx, x%llx\n", cast(ulong)c.lo, cast(ulong)c.hi);
        }
    }
}

unittest
{
    const C0 = Zero;
    const C1 = One;
    const C2 = Cent(2);
    const C3 = Cent(3);
    const C5 = Cent(5);
    const C10 = Cent(10);
    const C20 = Cent(20);
    const C30 = Cent(30);

    const Cm1 =  neg(One);
    const Cm3 =  neg(C3);
    const Cm10 = neg(C10);

    const C3_1 = Cent(1,3);
    const C3_2 = Cent(2,3);
    const C4_8  = Cent(8, 4);
    const C7_1 = Cent(1,7);
    const C7_9 = Cent(9,7);
    const C9_3 = Cent(3,9);
    const C10_0 = Cent(0,10);
    const C10_1 = Cent(1,10);
    const C10_3 = Cent(3,10);
    const C11_3 = Cent(3,11);
    const C20_0 = Cent(0,20);
    const C90_30 = Cent(30,90);

    enum Cs_3 = Cent(3, I.min);

    /************************/

    assert( ugt(C1, C0) );
    assert( ult(C1, C2) );
    assert( uge(C1, C0) );
    assert( ule(C1, C2) );

    assert( !ugt(C0, C1) );
    assert( !ult(C2, C1) );
    assert( !uge(C0, C1) );
    assert( !ule(C2, C1) );

    assert( !ugt(C1, C1) );
    assert( !ult(C1, C1) );
    assert( uge(C1, C1) );
    assert( ule(C2, C2) );

    assert( ugt(C10_3, C10_1) );
    assert( ugt(C11_3, C10_3) );
    assert( !ugt(C9_3, C10_3) );
    assert( !ugt(C9_3, C9_3) );

    assert( gt(C2, C1) );
    assert( !gt(C1, C2) );
    assert( !gt(C1, C1) );
    assert( gt(C0, Cm1) );
    assert( gt(Cm1, neg(C10)));
    assert( !gt(Cm1, Cm1) );
    assert( !gt(Cm1, C0) );

    assert( !lt(C2, C1) );
    assert( !le(C2, C1) );
    assert( ge(C2, C1) );

    assert(add(C7_1,C3_2) == C10_3);
    assert(sub(C1,C2) == Cm1);

    assert(inc(C3_1) == C3_2);
    assert(dec(C3_2) == C3_1);

    assert(shl(C10,Ubits) == C10_0);
    assert(shl(C10,1) == C20);
    assert(shl(C10,Ubits * 2) == C0);
    assert(shr(C10_0,Ubits) == C10);
    assert(shr(C10_0,Ubits - 1) == C20);
    assert(shr(C10_0,Ubits * 2) == C0);
    assert(sar(C10_0,Ubits) == C10);
    assert(sar(C10_0,Ubits * 2) == C0);
    assert(sar(Cm1,Ubits * 2) == Cm1);

    Cent modulus;

    assert(udiv(C10,C2) == C5);
    assert(udivmod(C10,C2, modulus) ==  C5);   assert(modulus == C0);
    assert(udivmod(C10,C3, modulus) ==  C3);   assert(modulus == C1);
    assert(udivmod(C10,C0, modulus) == Cm1);   assert(modulus == C0);

    assert(div(C10,C3) == C3);
    assert(divmod( C10,  C3, modulus) ==  C3); assert(modulus ==  C1);
    assert(divmod(Cm10,  C3, modulus) == Cm3); assert(modulus == Cm1);
    assert(divmod( C10, Cm3, modulus) == Cm3); assert(modulus ==  C1);
    assert(divmod(Cm10, Cm3, modulus) ==  C3); assert(modulus == Cm1);

    assert(mul(Cm10, C1) == Cm10);
    assert(mul(C1, Cm10) == Cm10);
    assert(mul(C9_3, C10) == C90_30);
    assert(mul(Cs_3, C10) == C30);

    assert( or(C4_8, C3_1) == C7_9);
    assert(and(C4_8, C7_9) == C4_8);
    assert(xor(C4_8, C7_9) == C3_1);

    assert(rol(Cm1,  1) == Cm1);
    assert(ror(Cm1, 45) == Cm1);
    assert(rol(ror(C7_9, 5), 5) == C7_9);
}


