/*
REQUIRED_ARGS: -de
TEST_OUTPUT:
---
fail_compilation/dep_d1_ops.d(187): Error: `opAdd` is obsolete.  Use `opBinary(string op)(...) if (op == "+")` instead.
    i = s + 1;
        ^
fail_compilation/dep_d1_ops.d(188): Error: `opAdd_r` is obsolete.  Use `opBinaryRight(string op)(...) if (op == "+")` instead.
    i = 1 + s;
        ^
fail_compilation/dep_d1_ops.d(189): Error: `opSub` is obsolete.  Use `opBinary(string op)(...) if (op == "-")` instead.
    i = s - 1;
        ^
fail_compilation/dep_d1_ops.d(190): Error: `opSub_r` is obsolete.  Use `opBinaryRight(string op)(...) if (op == "-")` instead.
    i = 1 - s;
        ^
fail_compilation/dep_d1_ops.d(191): Error: `opMul` is obsolete.  Use `opBinary(string op)(...) if (op == "*")` instead.
    i = s * 1;
        ^
fail_compilation/dep_d1_ops.d(192): Error: `opMul_r` is obsolete.  Use `opBinaryRight(string op)(...) if (op == "*")` instead.
    i = 1 * s;
        ^
fail_compilation/dep_d1_ops.d(193): Error: `opDiv` is obsolete.  Use `opBinary(string op)(...) if (op == "/")` instead.
    i = s / 1;
        ^
fail_compilation/dep_d1_ops.d(194): Error: `opDiv_r` is obsolete.  Use `opBinaryRight(string op)(...) if (op == "/")` instead.
    i = 1 / s;
        ^
fail_compilation/dep_d1_ops.d(195): Error: `opMod` is obsolete.  Use `opBinary(string op)(...) if (op == "%")` instead.
    i = s % 1;
        ^
fail_compilation/dep_d1_ops.d(196): Error: `opMod_r` is obsolete.  Use `opBinaryRight(string op)(...) if (op == "%")` instead.
    i = 1 % s;
        ^
fail_compilation/dep_d1_ops.d(198): Error: `opAnd` is obsolete.  Use `opBinary(string op)(...) if (op == "&")` instead.
    i = s & 1;
        ^
fail_compilation/dep_d1_ops.d(199): Error: `opOr` is obsolete.  Use `opBinary(string op)(...) if (op == "|")` instead.
    i = s | 1;
        ^
fail_compilation/dep_d1_ops.d(200): Error: `opXor` is obsolete.  Use `opBinary(string op)(...) if (op == "^")` instead.
    i = s ^ 1;
        ^
fail_compilation/dep_d1_ops.d(202): Error: `opShl` is obsolete.  Use `opBinary(string op)(...) if (op == "<<")` instead.
    i = s << 1;
        ^
fail_compilation/dep_d1_ops.d(203): Error: `opShl_r` is obsolete.  Use `opBinaryRight(string op)(...) if (op == "<<")` instead.
    i = 1 << s;
        ^
fail_compilation/dep_d1_ops.d(204): Error: `opShr` is obsolete.  Use `opBinary(string op)(...) if (op == ">>")` instead.
    i = s >> 1;
        ^
fail_compilation/dep_d1_ops.d(205): Error: `opShr_r` is obsolete.  Use `opBinaryRight(string op)(...) if (op == ">>")` instead.
    i = 1 >> s;
        ^
fail_compilation/dep_d1_ops.d(206): Error: `opUShr` is obsolete.  Use `opBinary(string op)(...) if (op == ">>>")` instead.
    i = s >>> 1;
        ^
fail_compilation/dep_d1_ops.d(207): Error: `opUShr_r` is obsolete.  Use `opBinaryRight(string op)(...) if (op == ">>>")` instead.
    i = 1 >>> s;
        ^
fail_compilation/dep_d1_ops.d(209): Error: `opCat` is obsolete.  Use `opBinary(string op)(...) if (op == "~")` instead.
    i = s ~ 1;
        ^
fail_compilation/dep_d1_ops.d(210): Error: `opCat_r` is obsolete.  Use `opBinaryRight(string op)(...) if (op == "~")` instead.
    i = 1 ~ s;
        ^
fail_compilation/dep_d1_ops.d(212): Error: `opNeg` is obsolete.  Use `opUnary(string op)() if (op == "-")` instead.
    i = -s;
        ^
fail_compilation/dep_d1_ops.d(213): Error: `opCom` is obsolete.  Use `opUnary(string op)() if (op == "~")` instead.
    i = ~s;
        ^
fail_compilation/dep_d1_ops.d(214): Error: `opPostInc` is obsolete.  Use `opUnary(string op)() if (op == "++")` instead.
    s++;
     ^
fail_compilation/dep_d1_ops.d(215): Error: `opPostDec` is obsolete.  Use `opUnary(string op)() if (op == "--")` instead.
    s--;
     ^
fail_compilation/dep_d1_ops.d(216): Error: `opStar` is obsolete.  Use `opUnary(string op)() if (op == "*")` instead.
    i = *s;
        ^
fail_compilation/dep_d1_ops.d(218): Error: `opIn` is obsolete.  Use `opBinary(string op)(...) if (op == "in")` instead.
    i = s in 1;
        ^
fail_compilation/dep_d1_ops.d(219): Error: `opIn_r` is obsolete.  Use `opBinaryRight(string op)(...) if (op == "in")` instead.
    i = 1 in s;
        ^
fail_compilation/dep_d1_ops.d(221): Error: `opAddAssign` is obsolete.  Use `opOpAssign(string op)(...) if (op == "+")` instead.
    s += 1;
      ^
fail_compilation/dep_d1_ops.d(222): Error: `opSubAssign` is obsolete.  Use `opOpAssign(string op)(...) if (op == "-")` instead.
    s -= 1;
      ^
fail_compilation/dep_d1_ops.d(223): Error: `opMulAssign` is obsolete.  Use `opOpAssign(string op)(...) if (op == "*")` instead.
    s *= 1;
      ^
fail_compilation/dep_d1_ops.d(224): Error: `opDivAssign` is obsolete.  Use `opOpAssign(string op)(...) if (op == "/")` instead.
    s /= 1;
      ^
fail_compilation/dep_d1_ops.d(225): Error: `opModAssign` is obsolete.  Use `opOpAssign(string op)(...) if (op == "%")` instead.
    s %= 1;
      ^
fail_compilation/dep_d1_ops.d(226): Error: `opAndAssign` is obsolete.  Use `opOpAssign(string op)(...) if (op == "&")` instead.
    s &= 1;
      ^
fail_compilation/dep_d1_ops.d(227): Error: `opOrAssign` is obsolete.  Use `opOpAssign(string op)(...) if (op == "|")` instead.
    s |= 1;
      ^
fail_compilation/dep_d1_ops.d(228): Error: `opXorAssign` is obsolete.  Use `opOpAssign(string op)(...) if (op == "^")` instead.
    s ^= 1;
      ^
fail_compilation/dep_d1_ops.d(229): Error: `opShlAssign` is obsolete.  Use `opOpAssign(string op)(...) if (op == "<<")` instead.
    s <<= 1;
      ^
fail_compilation/dep_d1_ops.d(230): Error: `opShrAssign` is obsolete.  Use `opOpAssign(string op)(...) if (op == ">>")` instead.
    s >>= 1;
      ^
fail_compilation/dep_d1_ops.d(231): Error: `opUShrAssign` is obsolete.  Use `opOpAssign(string op)(...) if (op == ">>>")` instead.
    s >>>= 1;
      ^
fail_compilation/dep_d1_ops.d(232): Error: `opCatAssign` is obsolete.  Use `opOpAssign(string op)(...) if (op == "~")` instead.
    s ~= 1;
      ^
fail_compilation/dep_d1_ops.d(240): Error: `opCom` is obsolete.  Use `opUnary(string op)() if (op == "~")` instead.
    ~nd;
    ^
---
*/

// Line 50 starts here
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
    S s;
    int i;

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
