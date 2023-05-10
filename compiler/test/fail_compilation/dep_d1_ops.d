/*
REQUIRED_ARGS: -de
TEST_OUTPUT:
---
fail_compilation/dep_d1_ops.d(157): Error: incompatible types for `(s) + (1)`: `S` and `int`
fail_compilation/dep_d1_ops.d(158): Error: incompatible types for `(1) + (s)`: `int` and `S`
fail_compilation/dep_d1_ops.d(159): Error: incompatible types for `(s) - (1)`: `S` and `int`
fail_compilation/dep_d1_ops.d(160): Error: incompatible types for `(1) - (s)`: `int` and `S`
fail_compilation/dep_d1_ops.d(161): Error: incompatible types for `(s) * (1)`: `S` and `int`
fail_compilation/dep_d1_ops.d(162): Error: incompatible types for `(1) * (s)`: `int` and `S`
fail_compilation/dep_d1_ops.d(163): Error: incompatible types for `(s) / (1)`: `S` and `int`
fail_compilation/dep_d1_ops.d(164): Error: incompatible types for `(1) / (s)`: `int` and `S`
fail_compilation/dep_d1_ops.d(165): Error: incompatible types for `(s) % (1)`: `S` and `int`
fail_compilation/dep_d1_ops.d(166): Error: incompatible types for `(1) % (s)`: `int` and `S`
fail_compilation/dep_d1_ops.d(168): Error: incompatible types for `(s) & (1)`: `S` and `int`
fail_compilation/dep_d1_ops.d(169): Error: incompatible types for `(s) | (1)`: `S` and `int`
fail_compilation/dep_d1_ops.d(170): Error: incompatible types for `(s) ^ (1)`: `S` and `int`
fail_compilation/dep_d1_ops.d(172): Error: `s` is not of integral type, it is a `S`
fail_compilation/dep_d1_ops.d(173): Error: `s` is not of integral type, it is a `S`
fail_compilation/dep_d1_ops.d(174): Error: `s` is not of integral type, it is a `S`
fail_compilation/dep_d1_ops.d(175): Error: `s` is not of integral type, it is a `S`
fail_compilation/dep_d1_ops.d(176): Error: `s` is not of integral type, it is a `S`
fail_compilation/dep_d1_ops.d(177): Error: `s` is not of integral type, it is a `S`
fail_compilation/dep_d1_ops.d(179): Error: incompatible types for `(s) ~ (1)`: `S` and `int`
fail_compilation/dep_d1_ops.d(180): Error: incompatible types for `(1) ~ (s)`: `int` and `S`
fail_compilation/dep_d1_ops.d(182): Error: `s` is not of arithmetic type, it is a `S`
fail_compilation/dep_d1_ops.d(183): Error: `s` is not of arithmetic type, it is a `S`
fail_compilation/dep_d1_ops.d(184): Error: `s` is not of integral type, it is a `S`
fail_compilation/dep_d1_ops.d(185): Error: `s` is not a scalar, it is a `S`
fail_compilation/dep_d1_ops.d(186): Error: `s` is not a scalar, it is a `S`
fail_compilation/dep_d1_ops.d(187): Error: can only `*` a pointer, not a `S`
fail_compilation/dep_d1_ops.d(189): Error: incompatible types for `(s) in (1)`: `S` and `int`
fail_compilation/dep_d1_ops.d(190): Error: incompatible types for `(1) in (s)`: `int` and `S`
fail_compilation/dep_d1_ops.d(192): Error: `s` is not a scalar, it is a `S`
fail_compilation/dep_d1_ops.d(193): Error: `s` is not a scalar, it is a `S`
fail_compilation/dep_d1_ops.d(194): Error: `s` is not a scalar, it is a `S`
fail_compilation/dep_d1_ops.d(195): Error: `s` is not a scalar, it is a `S`
fail_compilation/dep_d1_ops.d(196): Error: `s` is not a scalar, it is a `S`
fail_compilation/dep_d1_ops.d(197): Error: `s` is not a scalar, it is a `S`
fail_compilation/dep_d1_ops.d(198): Error: `s` is not a scalar, it is a `S`
fail_compilation/dep_d1_ops.d(199): Error: `s` is not a scalar, it is a `S`
fail_compilation/dep_d1_ops.d(200): Error: `s` is not a scalar, it is a `S`
fail_compilation/dep_d1_ops.d(201): Error: `s` is not a scalar, it is a `S`
fail_compilation/dep_d1_ops.d(202): Error: `s` is not a scalar, it is a `S`
fail_compilation/dep_d1_ops.d(203): Error: cannot append type `int` to type `S`
fail_compilation/dep_d1_ops.d(207): Error: incompatible types for `(c) + (1)`: `dep_d1_ops.C` and `int`
fail_compilation/dep_d1_ops.d(208): Error: incompatible types for `(1) + (c)`: `int` and `dep_d1_ops.C`
fail_compilation/dep_d1_ops.d(209): Error: incompatible types for `(c) - (1)`: `dep_d1_ops.C` and `int`
fail_compilation/dep_d1_ops.d(210): Error: incompatible types for `(1) - (c)`: `int` and `dep_d1_ops.C`
fail_compilation/dep_d1_ops.d(211): Error: incompatible types for `(c) * (1)`: `dep_d1_ops.C` and `int`
fail_compilation/dep_d1_ops.d(212): Error: incompatible types for `(1) * (c)`: `int` and `dep_d1_ops.C`
fail_compilation/dep_d1_ops.d(213): Error: incompatible types for `(c) / (1)`: `dep_d1_ops.C` and `int`
fail_compilation/dep_d1_ops.d(214): Error: incompatible types for `(1) / (c)`: `int` and `dep_d1_ops.C`
fail_compilation/dep_d1_ops.d(215): Error: incompatible types for `(c) % (1)`: `dep_d1_ops.C` and `int`
fail_compilation/dep_d1_ops.d(216): Error: incompatible types for `(1) % (c)`: `int` and `dep_d1_ops.C`
fail_compilation/dep_d1_ops.d(218): Error: incompatible types for `(c) & (1)`: `dep_d1_ops.C` and `int`
fail_compilation/dep_d1_ops.d(219): Error: incompatible types for `(c) | (1)`: `dep_d1_ops.C` and `int`
fail_compilation/dep_d1_ops.d(220): Error: incompatible types for `(c) ^ (1)`: `dep_d1_ops.C` and `int`
fail_compilation/dep_d1_ops.d(222): Error: `c` is not of integral type, it is a `dep_d1_ops.C`
fail_compilation/dep_d1_ops.d(223): Error: `c` is not of integral type, it is a `dep_d1_ops.C`
fail_compilation/dep_d1_ops.d(224): Error: `c` is not of integral type, it is a `dep_d1_ops.C`
fail_compilation/dep_d1_ops.d(225): Error: `c` is not of integral type, it is a `dep_d1_ops.C`
fail_compilation/dep_d1_ops.d(226): Error: `c` is not of integral type, it is a `dep_d1_ops.C`
fail_compilation/dep_d1_ops.d(227): Error: `c` is not of integral type, it is a `dep_d1_ops.C`
fail_compilation/dep_d1_ops.d(229): Error: incompatible types for `(c) ~ (1)`: `dep_d1_ops.C` and `int`
fail_compilation/dep_d1_ops.d(230): Error: incompatible types for `(1) ~ (c)`: `int` and `dep_d1_ops.C`
fail_compilation/dep_d1_ops.d(232): Error: `c` is not of arithmetic type, it is a `dep_d1_ops.C`
fail_compilation/dep_d1_ops.d(233): Error: `c` is not of arithmetic type, it is a `dep_d1_ops.C`
fail_compilation/dep_d1_ops.d(234): Error: `c` is not of integral type, it is a `dep_d1_ops.C`
fail_compilation/dep_d1_ops.d(235): Error: `c` is not a scalar, it is a `dep_d1_ops.C`
fail_compilation/dep_d1_ops.d(236): Error: `c` is not a scalar, it is a `dep_d1_ops.C`
fail_compilation/dep_d1_ops.d(237): Error: can only `*` a pointer, not a `dep_d1_ops.C`
fail_compilation/dep_d1_ops.d(239): Error: incompatible types for `(c) in (1)`: `dep_d1_ops.C` and `int`
fail_compilation/dep_d1_ops.d(240): Error: incompatible types for `(1) in (c)`: `int` and `dep_d1_ops.C`
fail_compilation/dep_d1_ops.d(242): Error: `c` is not a scalar, it is a `dep_d1_ops.C`
fail_compilation/dep_d1_ops.d(243): Error: `c` is not a scalar, it is a `dep_d1_ops.C`
fail_compilation/dep_d1_ops.d(244): Error: `c` is not a scalar, it is a `dep_d1_ops.C`
fail_compilation/dep_d1_ops.d(245): Error: `c` is not a scalar, it is a `dep_d1_ops.C`
fail_compilation/dep_d1_ops.d(246): Error: `c` is not a scalar, it is a `dep_d1_ops.C`
fail_compilation/dep_d1_ops.d(247): Error: `c` is not a scalar, it is a `dep_d1_ops.C`
fail_compilation/dep_d1_ops.d(248): Error: `c` is not a scalar, it is a `dep_d1_ops.C`
fail_compilation/dep_d1_ops.d(249): Error: `c` is not a scalar, it is a `dep_d1_ops.C`
fail_compilation/dep_d1_ops.d(250): Error: `c` is not a scalar, it is a `dep_d1_ops.C`
fail_compilation/dep_d1_ops.d(251): Error: `c` is not a scalar, it is a `dep_d1_ops.C`
fail_compilation/dep_d1_ops.d(252): Error: `c` is not a scalar, it is a `dep_d1_ops.C`
fail_compilation/dep_d1_ops.d(253): Error: cannot append type `int` to type `dep_d1_ops.C`
fail_compilation/dep_d1_ops.d(262): Error: `nd` is not of integral type, it is a `dep_d1_ops.NoDeprecation`
---
*/

#line 50
struct S
{
    int opAdd(int i) { return 0; }
    int opAdd_r(int i) { return 0; }
    int opSub(int i) { return 0; }
    int opSub_r(int i) { return 0; }
    int opMul(int i) { return 0; }
    int opMul_r(int i) { return 0; }
    int opDiv(int i) { return 0; }
    int opDiv_r(int i) { return 0; }
    int opMod(int i) { return 0; }
    int opMod_r(int i) { return 0; }

    int opAnd(int i) { return 0; }
    int opOr(int i) { return 0; }
    int opXor(int i) { return 0; }

    int opShl(int i) { return 0; }
    int opShl_r(int i) { return 0; }
    int opShr(int i) { return 0; }
    int opShr_r(int i) { return 0; }
    int opUShr(int i) { return 0; }
    int opUShr_r(int i) { return 0; }

    int opCat(int i) { return 0; }
    int opCat_r(int i) { return 0; }

    int opPos() { return 0; }
    int opNeg() { return 0; }
    int opCom() { return 0; }
    int opPostInc() { return 0; }
    int opPostDec() { return 0; }
    int opStar() { return 0; }

    int opIn(int i) { return 0; }
    int opIn_r(int i) { return 0; }

    int opAddAssign(int i) { return 0; }
    int opSubAssign(int i) { return 0; }
    int opMulAssign(int i) { return 0; }
    int opDivAssign(int i) { return 0; }
    int opModAssign(int i) { return 0; }
    int opAndAssign(int i) { return 0; }
    int opOrAssign(int i) { return 0; }
    int opXorAssign(int i) { return 0; }
    int opShlAssign(int i) { return 0; }
    int opShrAssign(int i) { return 0; }
    int opUShrAssign(int i) { return 0; }
    int opCatAssign(int i) { return 0; }
}

class C
{
    int opAdd(int i) { return 0; }
    int opAdd_r(int i) { return 0; }
    int opSub(int i) { return 0; }
    int opSub_r(int i) { return 0; }
    int opMul(int i) { return 0; }
    int opMul_r(int i) { return 0; }
    int opDiv(int i) { return 0; }
    int opDiv_r(int i) { return 0; }
    int opMod(int i) { return 0; }
    int opMod_r(int i) { return 0; }

    int opAnd(int i) { return 0; }
    int opOr(int i) { return 0; }
    int opXor(int i) { return 0; }

    int opShl(int i) { return 0; }
    int opShl_r(int i) { return 0; }
    int opShr(int i) { return 0; }
    int opShr_r(int i) { return 0; }
    int opUShr(int i) { return 0; }
    int opUShr_r(int i) { return 0; }

    int opCat(int i) { return 0; }
    int opCat_r(int i) { return 0; }

    int opPos() { return 0; }
    int opNeg() { return 0; }
    int opCom() { return 0; }
    int opPostInc() { return 0; }
    int opPostDec() { return 0; }
    int opStar() { return 0; }

    int opIn(int i) { return 0; }
    int opIn_r(int i) { return 0; }

    int opAddAssign(int i) { return 0; }
    int opSubAssign(int i) { return 0; }
    int opMulAssign(int i) { return 0; }
    int opDivAssign(int i) { return 0; }
    int opModAssign(int i) { return 0; }
    int opAndAssign(int i) { return 0; }
    int opOrAssign(int i) { return 0; }
    int opXorAssign(int i) { return 0; }
    int opShlAssign(int i) { return 0; }
    int opShrAssign(int i) { return 0; }
    int opUShrAssign(int i) { return 0; }
    int opCatAssign(int i) { return 0; }
}

void main()
{
    int i;
    {
        S s;
        i = s + 1;
        i = 1 + s;
        i = s - 1;
        i = 1 - s;
        i = s * 1;
        i = 1 * s;
        i = s / 1;
        i = 1 / s;
        i = s % 1;
        i = 1 % s;

        i = s & 1;
        i = s | 1;
        i = s ^ 1;

        i = s << 1;
        i = 1 << s;
        i = s >> 1;
        i = 1 >> s;
        i = s >>> 1;
        i = 1 >>> s;

        i = s ~ 1;
        i = 1 ~ s;

        i = +s;
        i = -s;
        i = ~s;
        s++;
        s--;
        i = *s;

        i = s in 1;
        i = 1 in s;

        s += 1;
        s -= 1;
        s *= 1;
        s /= 1;
        s %= 1;
        s &= 1;
        s |= 1;
        s ^= 1;
        s <<= 1;
        s >>= 1;
        s >>>= 1;
        s ~= 1;
    }
    {
        C c;
        i = c + 1;
        i = 1 + c;
        i = c - 1;
        i = 1 - c;
        i = c * 1;
        i = 1 * c;
        i = c / 1;
        i = 1 / c;
        i = c % 1;
        i = 1 % c;

        i = c & 1;
        i = c | 1;
        i = c ^ 1;

        i = c << 1;
        i = 1 << c;
        i = c >> 1;
        i = 1 >> c;
        i = c >>> 1;
        i = 1 >>> c;

        i = c ~ 1;
        i = 1 ~ c;

        i = +c;
        i = -c;
        i = ~c;
        c++;
        c--;
        i = *c;

        i = c in 1;
        i = 1 in c;

        c += 1;
        c -= 1;
        c *= 1;
        c /= 1;
        c %= 1;
        c &= 1;
        c |= 1;
        c ^= 1;
        c <<= 1;
        c >>= 1;
        c >>>= 1;
        c ~= 1;
    }

    scope nd = new NoDeprecation;
    assert((42 in nd) == 0);
    assert((nd in 42) == 0);
    assert((nd ~ 42) == 0);
    assert((42 ~ nd) == 0);

    ~nd;
}

/// See https://github.com/dlang/dmd/pull/10716
class NoDeprecation
{
    int opIn(int i) { return 0; }
    int opIn_r(int i) { return 0; }
    int opCat(int i) { return 0; }
    int opCat_r(int i) { return 0; }

    /// This is considered because there is no `opUnary`
    /// However, the other overloads (`opBinary` / `opBinaryRight`)
    /// means that other operator overloads would not be considered.
    int opCom() { return 0; }

    int opBinary(string op)(int arg)
        if (op == "in" || op == "~")
    {
        static if (op == "in")
            return this.opIn(arg);
        else static if (op == "~")
            return this.opCat(arg);
    }

    int opBinaryRight(string op)(int arg)
        if (op == "in" || op == "~")
    {
        static if (op == "in")
            return this.opIn_r(arg);
        else static if (op == "~")
            return this.opCat_r(arg);
    }
}
