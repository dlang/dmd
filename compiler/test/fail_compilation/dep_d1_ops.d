/*
REQUIRED_ARGS:
TEST_OUTPUT:
---
fail_compilation/dep_d1_ops.d(244): Error: operator `+` is not defined for type `S`
fail_compilation/dep_d1_ops.d(137):        perhaps overload the operator with `auto opBinary(string op : "+")(int rhs) {}`
fail_compilation/dep_d1_ops.d(245): Error: operator `+` is not defined for type `S`
fail_compilation/dep_d1_ops.d(137):        perhaps overload the operator with `auto opBinaryRight(string op : "+")(int rhs) {}`
fail_compilation/dep_d1_ops.d(246): Error: operator `-` is not defined for type `S`
fail_compilation/dep_d1_ops.d(137):        perhaps overload the operator with `auto opBinary(string op : "-")(int rhs) {}`
fail_compilation/dep_d1_ops.d(247): Error: operator `-` is not defined for type `S`
fail_compilation/dep_d1_ops.d(137):        perhaps overload the operator with `auto opBinaryRight(string op : "-")(int rhs) {}`
fail_compilation/dep_d1_ops.d(248): Error: operator `*` is not defined for type `S`
fail_compilation/dep_d1_ops.d(137):        perhaps overload the operator with `auto opBinary(string op : "*")(int rhs) {}`
fail_compilation/dep_d1_ops.d(249): Error: operator `*` is not defined for type `S`
fail_compilation/dep_d1_ops.d(137):        perhaps overload the operator with `auto opBinaryRight(string op : "*")(int rhs) {}`
fail_compilation/dep_d1_ops.d(250): Error: operator `/` is not defined for type `S`
fail_compilation/dep_d1_ops.d(137):        perhaps overload the operator with `auto opBinary(string op : "/")(int rhs) {}`
fail_compilation/dep_d1_ops.d(251): Error: operator `/` is not defined for type `S`
fail_compilation/dep_d1_ops.d(137):        perhaps overload the operator with `auto opBinaryRight(string op : "/")(int rhs) {}`
fail_compilation/dep_d1_ops.d(252): Error: operator `%` is not defined for type `S`
fail_compilation/dep_d1_ops.d(137):        perhaps overload the operator with `auto opBinary(string op : "%")(int rhs) {}`
fail_compilation/dep_d1_ops.d(253): Error: operator `%` is not defined for type `S`
fail_compilation/dep_d1_ops.d(137):        perhaps overload the operator with `auto opBinaryRight(string op : "%")(int rhs) {}`
fail_compilation/dep_d1_ops.d(255): Error: operator `&` is not defined for type `S`
fail_compilation/dep_d1_ops.d(137):        perhaps overload the operator with `auto opBinary(string op : "&")(int rhs) {}`
fail_compilation/dep_d1_ops.d(256): Error: operator `|` is not defined for type `S`
fail_compilation/dep_d1_ops.d(137):        perhaps overload the operator with `auto opBinary(string op : "|")(int rhs) {}`
fail_compilation/dep_d1_ops.d(257): Error: operator `^` is not defined for type `S`
fail_compilation/dep_d1_ops.d(137):        perhaps overload the operator with `auto opBinary(string op : "^")(int rhs) {}`
fail_compilation/dep_d1_ops.d(259): Error: operator `<<` is not defined for type `S`
fail_compilation/dep_d1_ops.d(137):        perhaps overload the operator with `auto opBinary(string op : "<<")(int rhs) {}`
fail_compilation/dep_d1_ops.d(260): Error: operator `<<` is not defined for type `S`
fail_compilation/dep_d1_ops.d(137):        perhaps overload the operator with `auto opBinaryRight(string op : "<<")(int rhs) {}`
fail_compilation/dep_d1_ops.d(261): Error: operator `>>` is not defined for type `S`
fail_compilation/dep_d1_ops.d(137):        perhaps overload the operator with `auto opBinary(string op : ">>")(int rhs) {}`
fail_compilation/dep_d1_ops.d(262): Error: operator `>>` is not defined for type `S`
fail_compilation/dep_d1_ops.d(137):        perhaps overload the operator with `auto opBinaryRight(string op : ">>")(int rhs) {}`
fail_compilation/dep_d1_ops.d(263): Error: operator `>>>` is not defined for type `S`
fail_compilation/dep_d1_ops.d(137):        perhaps overload the operator with `auto opBinary(string op : ">>>")(int rhs) {}`
fail_compilation/dep_d1_ops.d(264): Error: operator `>>>` is not defined for type `S`
fail_compilation/dep_d1_ops.d(137):        perhaps overload the operator with `auto opBinaryRight(string op : ">>>")(int rhs) {}`
fail_compilation/dep_d1_ops.d(266): Error: operator `~` is not defined for type `S`
fail_compilation/dep_d1_ops.d(137):        perhaps overload the operator with `auto opBinary(string op : "~")(int rhs) {}`
fail_compilation/dep_d1_ops.d(267): Error: operator `~` is not defined for type `S`
fail_compilation/dep_d1_ops.d(137):        perhaps overload the operator with `auto opBinaryRight(string op : "~")(int rhs) {}`
fail_compilation/dep_d1_ops.d(269): Error: operator `+` is not defined for `s` of type `S`
fail_compilation/dep_d1_ops.d(270): Error: operator `-` is not defined for `s` of type `S`
fail_compilation/dep_d1_ops.d(271): Error: `s` is not of integral type, it is a `S`
fail_compilation/dep_d1_ops.d(272): Error: `s` is not a scalar, it is a `S`
fail_compilation/dep_d1_ops.d(273): Error: `s` is not a scalar, it is a `S`
fail_compilation/dep_d1_ops.d(274): Error: can only `*` a pointer, not a `S`
fail_compilation/dep_d1_ops.d(276): Error: operator `in` is not defined for type `S`
fail_compilation/dep_d1_ops.d(137):        perhaps overload the operator with `auto opBinary(string op : "in")(int rhs) {}`
fail_compilation/dep_d1_ops.d(277): Error: operator `in` is not defined for type `S`
fail_compilation/dep_d1_ops.d(137):        perhaps overload the operator with `auto opBinaryRight(string op : "in")(int rhs) {}`
fail_compilation/dep_d1_ops.d(279): Error: `s` is not a scalar, it is a `S`
fail_compilation/dep_d1_ops.d(280): Error: `s` is not a scalar, it is a `S`
fail_compilation/dep_d1_ops.d(281): Error: `s` is not a scalar, it is a `S`
fail_compilation/dep_d1_ops.d(282): Error: `s` is not a scalar, it is a `S`
fail_compilation/dep_d1_ops.d(283): Error: `s` is not a scalar, it is a `S`
fail_compilation/dep_d1_ops.d(284): Error: `s` is not a scalar, it is a `S`
fail_compilation/dep_d1_ops.d(285): Error: `s` is not a scalar, it is a `S`
fail_compilation/dep_d1_ops.d(286): Error: `s` is not a scalar, it is a `S`
fail_compilation/dep_d1_ops.d(287): Error: `s` is not a scalar, it is a `S`
fail_compilation/dep_d1_ops.d(288): Error: `s` is not a scalar, it is a `S`
fail_compilation/dep_d1_ops.d(289): Error: `s` is not a scalar, it is a `S`
fail_compilation/dep_d1_ops.d(290): Error: cannot append type `int` to type `S`
fail_compilation/dep_d1_ops.d(294): Error: operator `+` is not defined for type `dep_d1_ops.C`
fail_compilation/dep_d1_ops.d(188):        perhaps overload the operator with `auto opBinary(string op : "+")(int rhs) {}`
fail_compilation/dep_d1_ops.d(295): Error: operator `+` is not defined for type `dep_d1_ops.C`
fail_compilation/dep_d1_ops.d(188):        perhaps overload the operator with `auto opBinaryRight(string op : "+")(int rhs) {}`
fail_compilation/dep_d1_ops.d(296): Error: operator `-` is not defined for type `dep_d1_ops.C`
fail_compilation/dep_d1_ops.d(188):        perhaps overload the operator with `auto opBinary(string op : "-")(int rhs) {}`
fail_compilation/dep_d1_ops.d(297): Error: operator `-` is not defined for type `dep_d1_ops.C`
fail_compilation/dep_d1_ops.d(188):        perhaps overload the operator with `auto opBinaryRight(string op : "-")(int rhs) {}`
fail_compilation/dep_d1_ops.d(298): Error: operator `*` is not defined for type `dep_d1_ops.C`
fail_compilation/dep_d1_ops.d(188):        perhaps overload the operator with `auto opBinary(string op : "*")(int rhs) {}`
fail_compilation/dep_d1_ops.d(299): Error: operator `*` is not defined for type `dep_d1_ops.C`
fail_compilation/dep_d1_ops.d(188):        perhaps overload the operator with `auto opBinaryRight(string op : "*")(int rhs) {}`
fail_compilation/dep_d1_ops.d(300): Error: operator `/` is not defined for type `dep_d1_ops.C`
fail_compilation/dep_d1_ops.d(188):        perhaps overload the operator with `auto opBinary(string op : "/")(int rhs) {}`
fail_compilation/dep_d1_ops.d(301): Error: operator `/` is not defined for type `dep_d1_ops.C`
fail_compilation/dep_d1_ops.d(188):        perhaps overload the operator with `auto opBinaryRight(string op : "/")(int rhs) {}`
fail_compilation/dep_d1_ops.d(302): Error: operator `%` is not defined for type `dep_d1_ops.C`
fail_compilation/dep_d1_ops.d(188):        perhaps overload the operator with `auto opBinary(string op : "%")(int rhs) {}`
fail_compilation/dep_d1_ops.d(303): Error: operator `%` is not defined for type `dep_d1_ops.C`
fail_compilation/dep_d1_ops.d(188):        perhaps overload the operator with `auto opBinaryRight(string op : "%")(int rhs) {}`
fail_compilation/dep_d1_ops.d(305): Error: operator `&` is not defined for type `dep_d1_ops.C`
fail_compilation/dep_d1_ops.d(188):        perhaps overload the operator with `auto opBinary(string op : "&")(int rhs) {}`
fail_compilation/dep_d1_ops.d(306): Error: operator `|` is not defined for type `dep_d1_ops.C`
fail_compilation/dep_d1_ops.d(188):        perhaps overload the operator with `auto opBinary(string op : "|")(int rhs) {}`
fail_compilation/dep_d1_ops.d(307): Error: operator `^` is not defined for type `dep_d1_ops.C`
fail_compilation/dep_d1_ops.d(188):        perhaps overload the operator with `auto opBinary(string op : "^")(int rhs) {}`
fail_compilation/dep_d1_ops.d(309): Error: operator `<<` is not defined for type `dep_d1_ops.C`
fail_compilation/dep_d1_ops.d(188):        perhaps overload the operator with `auto opBinary(string op : "<<")(int rhs) {}`
fail_compilation/dep_d1_ops.d(310): Error: operator `<<` is not defined for type `dep_d1_ops.C`
fail_compilation/dep_d1_ops.d(188):        perhaps overload the operator with `auto opBinaryRight(string op : "<<")(int rhs) {}`
fail_compilation/dep_d1_ops.d(311): Error: operator `>>` is not defined for type `dep_d1_ops.C`
fail_compilation/dep_d1_ops.d(188):        perhaps overload the operator with `auto opBinary(string op : ">>")(int rhs) {}`
fail_compilation/dep_d1_ops.d(312): Error: operator `>>` is not defined for type `dep_d1_ops.C`
fail_compilation/dep_d1_ops.d(188):        perhaps overload the operator with `auto opBinaryRight(string op : ">>")(int rhs) {}`
fail_compilation/dep_d1_ops.d(313): Error: operator `>>>` is not defined for type `dep_d1_ops.C`
fail_compilation/dep_d1_ops.d(188):        perhaps overload the operator with `auto opBinary(string op : ">>>")(int rhs) {}`
fail_compilation/dep_d1_ops.d(314): Error: operator `>>>` is not defined for type `dep_d1_ops.C`
fail_compilation/dep_d1_ops.d(188):        perhaps overload the operator with `auto opBinaryRight(string op : ">>>")(int rhs) {}`
fail_compilation/dep_d1_ops.d(316): Error: operator `~` is not defined for type `dep_d1_ops.C`
fail_compilation/dep_d1_ops.d(188):        perhaps overload the operator with `auto opBinary(string op : "~")(int rhs) {}`
fail_compilation/dep_d1_ops.d(317): Error: operator `~` is not defined for type `dep_d1_ops.C`
fail_compilation/dep_d1_ops.d(188):        perhaps overload the operator with `auto opBinaryRight(string op : "~")(int rhs) {}`
fail_compilation/dep_d1_ops.d(319): Error: operator `+` is not defined for `c` of type `dep_d1_ops.C`
fail_compilation/dep_d1_ops.d(320): Error: operator `-` is not defined for `c` of type `dep_d1_ops.C`
fail_compilation/dep_d1_ops.d(321): Error: `c` is not of integral type, it is a `dep_d1_ops.C`
fail_compilation/dep_d1_ops.d(322): Error: `c` is not a scalar, it is a `dep_d1_ops.C`
fail_compilation/dep_d1_ops.d(323): Error: `c` is not a scalar, it is a `dep_d1_ops.C`
fail_compilation/dep_d1_ops.d(324): Error: can only `*` a pointer, not a `dep_d1_ops.C`
fail_compilation/dep_d1_ops.d(326): Error: operator `in` is not defined for type `dep_d1_ops.C`
fail_compilation/dep_d1_ops.d(188):        perhaps overload the operator with `auto opBinary(string op : "in")(int rhs) {}`
fail_compilation/dep_d1_ops.d(327): Error: operator `in` is not defined for type `dep_d1_ops.C`
fail_compilation/dep_d1_ops.d(188):        perhaps overload the operator with `auto opBinaryRight(string op : "in")(int rhs) {}`
fail_compilation/dep_d1_ops.d(329): Error: `c` is not a scalar, it is a `dep_d1_ops.C`
fail_compilation/dep_d1_ops.d(330): Error: `c` is not a scalar, it is a `dep_d1_ops.C`
fail_compilation/dep_d1_ops.d(331): Error: `c` is not a scalar, it is a `dep_d1_ops.C`
fail_compilation/dep_d1_ops.d(332): Error: `c` is not a scalar, it is a `dep_d1_ops.C`
fail_compilation/dep_d1_ops.d(333): Error: `c` is not a scalar, it is a `dep_d1_ops.C`
fail_compilation/dep_d1_ops.d(334): Error: `c` is not a scalar, it is a `dep_d1_ops.C`
fail_compilation/dep_d1_ops.d(335): Error: `c` is not a scalar, it is a `dep_d1_ops.C`
fail_compilation/dep_d1_ops.d(336): Error: `c` is not a scalar, it is a `dep_d1_ops.C`
fail_compilation/dep_d1_ops.d(337): Error: `c` is not a scalar, it is a `dep_d1_ops.C`
fail_compilation/dep_d1_ops.d(338): Error: `c` is not a scalar, it is a `dep_d1_ops.C`
fail_compilation/dep_d1_ops.d(339): Error: `c` is not a scalar, it is a `dep_d1_ops.C`
fail_compilation/dep_d1_ops.d(340): Error: cannot append type `int` to type `dep_d1_ops.C`
fail_compilation/dep_d1_ops.d(349): Error: `nd` is not of integral type, it is a `dep_d1_ops.NoDeprecation`
---
*/

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
