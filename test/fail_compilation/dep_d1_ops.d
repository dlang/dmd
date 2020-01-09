/*
REQUIRED_ARGS: -de
TEST_OUTPUT:
---
fail_compilation/dep_d1_ops.d(103): Deprecation: `opAdd` is deprecated.  Use `opBinary(string op)(...) if (op == "+")` instead.
fail_compilation/dep_d1_ops.d(104): Deprecation: `opAdd_r` is deprecated.  Use `opBinaryRight(string op)(...) if (op == "+")` instead.
fail_compilation/dep_d1_ops.d(105): Deprecation: `opSub` is deprecated.  Use `opBinary(string op)(...) if (op == "-")` instead.
fail_compilation/dep_d1_ops.d(106): Deprecation: `opSub_r` is deprecated.  Use `opBinaryRight(string op)(...) if (op == "-")` instead.
fail_compilation/dep_d1_ops.d(107): Deprecation: `opMul` is deprecated.  Use `opBinary(string op)(...) if (op == "*")` instead.
fail_compilation/dep_d1_ops.d(108): Deprecation: `opMul_r` is deprecated.  Use `opBinaryRight(string op)(...) if (op == "*")` instead.
fail_compilation/dep_d1_ops.d(109): Deprecation: `opDiv` is deprecated.  Use `opBinary(string op)(...) if (op == "/")` instead.
fail_compilation/dep_d1_ops.d(110): Deprecation: `opDiv_r` is deprecated.  Use `opBinaryRight(string op)(...) if (op == "/")` instead.
fail_compilation/dep_d1_ops.d(111): Deprecation: `opMod` is deprecated.  Use `opBinary(string op)(...) if (op == "%")` instead.
fail_compilation/dep_d1_ops.d(112): Deprecation: `opMod_r` is deprecated.  Use `opBinaryRight(string op)(...) if (op == "%")` instead.
fail_compilation/dep_d1_ops.d(114): Deprecation: `opAnd` is deprecated.  Use `opBinary(string op)(...) if (op == "&")` instead.
fail_compilation/dep_d1_ops.d(115): Deprecation: `opOr` is deprecated.  Use `opBinary(string op)(...) if (op == "|")` instead.
fail_compilation/dep_d1_ops.d(116): Deprecation: `opXor` is deprecated.  Use `opBinary(string op)(...) if (op == "^")` instead.
fail_compilation/dep_d1_ops.d(118): Deprecation: `opShl` is deprecated.  Use `opBinary(string op)(...) if (op == "<<")` instead.
fail_compilation/dep_d1_ops.d(119): Deprecation: `opShl_r` is deprecated.  Use `opBinaryRight(string op)(...) if (op == "<<")` instead.
fail_compilation/dep_d1_ops.d(120): Deprecation: `opShr` is deprecated.  Use `opBinary(string op)(...) if (op == ">>")` instead.
fail_compilation/dep_d1_ops.d(121): Deprecation: `opShr_r` is deprecated.  Use `opBinaryRight(string op)(...) if (op == ">>")` instead.
fail_compilation/dep_d1_ops.d(122): Deprecation: `opUShr` is deprecated.  Use `opBinary(string op)(...) if (op == ">>>")` instead.
fail_compilation/dep_d1_ops.d(123): Deprecation: `opUShr_r` is deprecated.  Use `opBinaryRight(string op)(...) if (op == ">>>")` instead.
fail_compilation/dep_d1_ops.d(125): Deprecation: `opCat` is deprecated.  Use `opBinary(string op)(...) if (op == "~")` instead.
fail_compilation/dep_d1_ops.d(126): Deprecation: `opCat_r` is deprecated.  Use `opBinaryRight(string op)(...) if (op == "~")` instead.
fail_compilation/dep_d1_ops.d(128): Deprecation: `opNeg` is deprecated.  Use `opUnary(string op)() if (op == "-")` instead.
fail_compilation/dep_d1_ops.d(129): Deprecation: `opCom` is deprecated.  Use `opUnary(string op)() if (op == "~")` instead.
fail_compilation/dep_d1_ops.d(130): Deprecation: `opPostInc` is deprecated.  Use `opUnary(string op)() if (op == "++")` instead.
fail_compilation/dep_d1_ops.d(131): Deprecation: `opPostDec` is deprecated.  Use `opUnary(string op)() if (op == "--")` instead.
fail_compilation/dep_d1_ops.d(132): Deprecation: `opStar` is deprecated.  Use `opUnary(string op)() if (op == "*")` instead.
fail_compilation/dep_d1_ops.d(134): Deprecation: `opIn` is deprecated.  Use `opBinary(string op)(...) if (op == "in")` instead.
fail_compilation/dep_d1_ops.d(135): Deprecation: `opIn_r` is deprecated.  Use `opBinaryRight(string op)(...) if (op == "in")` instead.
fail_compilation/dep_d1_ops.d(137): Deprecation: `opAddAssign` is deprecated.  Use `opOpAssign(string op)(...) if (op == "+")` instead.
fail_compilation/dep_d1_ops.d(138): Deprecation: `opSubAssign` is deprecated.  Use `opOpAssign(string op)(...) if (op == "-")` instead.
fail_compilation/dep_d1_ops.d(139): Deprecation: `opMulAssign` is deprecated.  Use `opOpAssign(string op)(...) if (op == "*")` instead.
fail_compilation/dep_d1_ops.d(140): Deprecation: `opDivAssign` is deprecated.  Use `opOpAssign(string op)(...) if (op == "/")` instead.
fail_compilation/dep_d1_ops.d(141): Deprecation: `opModAssign` is deprecated.  Use `opOpAssign(string op)(...) if (op == "%")` instead.
fail_compilation/dep_d1_ops.d(142): Deprecation: `opAndAssign` is deprecated.  Use `opOpAssign(string op)(...) if (op == "&")` instead.
fail_compilation/dep_d1_ops.d(143): Deprecation: `opOrAssign` is deprecated.  Use `opOpAssign(string op)(...) if (op == "|")` instead.
fail_compilation/dep_d1_ops.d(144): Deprecation: `opXorAssign` is deprecated.  Use `opOpAssign(string op)(...) if (op == "^")` instead.
fail_compilation/dep_d1_ops.d(145): Deprecation: `opShlAssign` is deprecated.  Use `opOpAssign(string op)(...) if (op == "<<")` instead.
fail_compilation/dep_d1_ops.d(146): Deprecation: `opShrAssign` is deprecated.  Use `opOpAssign(string op)(...) if (op == ">>")` instead.
fail_compilation/dep_d1_ops.d(147): Deprecation: `opUShrAssign` is deprecated.  Use `opOpAssign(string op)(...) if (op == ">>>")` instead.
fail_compilation/dep_d1_ops.d(148): Deprecation: `opCatAssign` is deprecated.  Use `opOpAssign(string op)(...) if (op == "~")` instead.
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
}
