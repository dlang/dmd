module ddmd.ctfe.bc_c_backend;
import ddmd.ctfe.bc_common;

import std.conv;

enum CInst : ushort
{
    // 2 StackOperands
    Add,
    Sub,
    Div,
    Mul,
    Eq, //sets condflags
    Neq, //sets condflag
    Lt, //sets condflags
    Le,
    Gt, //sets condflags
    Ge,
    Set,
    And,
    Or,
    Xor,
    Lsh,
    Rsh,
    Mod,

}

struct C_BCGen
{ ///for nameless functions generate functionLiteral
    string functionalize(const string fname = null) pure const
    {
        import std.algorithm;
        import std.range;

        // first we generate the signature
        return (
            (
            (fname is null) ? "((BCValue[] args, BCHeap* heapPtr) @safe {\n"
            : "BCValue " ~ fname ~ "(BCValue[] args) {\n") ~ intrinsicFunctions ~ "\n\tint stackOffset;\n\tBCValue retval;\n\tint[" ~ to!string(
            align4(sp + 400)) ~ "] stack;\n\tint cond;\n\n" ~ q{
        foreach(i, arg;args)
        {
            assert(arg.type.type == BCTypeEnum.i32, "only i32 args are supported at this point");
            assert(arg.vType == BCValueType.Immediate, "only imm32 args are supported at this point");
            stack[stackOffset+(4*(i+1))] = arg.imm32;
        }
                } ~ cast(
            string) code ~ ((fname is null) ? "\n})" : "\n}"));
    }

    enum intrinsicFunctions = q{static if (!is(C_BCGen_Intrinsics)) {
    alias C_BCGen_Intrinsics = void;

    uint intrin_Byte3(int word, int idx) {
        switch(idx) {
            case 0 :
                return word & 0xFF;
            case 1 :
                return (word & 0xFF00) >> 8;
            case 2 :
                return (word & 0xFF0000) >> 16;
            case 3 :
                return (word & 0xFF000000) >> 24;

            default : assert(0, "index must go from 0 to 3");
        }
    }
}};

    char[] code;
pure:
    bool requireIntrinsics;
    uint labelCount;
    bool sameLabel;
    StackAddr sp = StackAddr(4);
    ushort temporaryCount;
    ubyte parameterCount;

    void incSp()
    {
        sp += 4;
    }

    StackAddr currSp() const
    {
        return sp;
    }

    void Initialize()
    {
    }

    void Finalize()
    {
    }

    void beginFunction()
    {
        sameLabel = false;
    }

    void endFunction()
    {
    }

    BCValue genTemporary( /*BCValue size*/ BCType bct)
    {
        auto tmp = BCValue(StackAddr(sp), bct, temporaryCount++);
        //assert(size.vType == BCValueType.Immidiate);
        sp += align4(basicTypeSize(bct)); //sharedState.size(bct.type, typeIndex));

        return tmp;
    }

    string toCode(BCValue v) pure const
    {
        if (v.type.type == BCTypeEnum.Char)
            v = v.i32;
        else if (v.type.type == BCTypeEnum.String)
            v = v.i32;
        else if (v.type.type == BCTypeEnum.Slice)
            v = v.i32;

        assert(v.type.type == BCTypeEnum.i32 || v.type.type == BCTypeEnum.i32Ptr,
            "i32 or i32Ptr expected not: " ~ to!string(v.type.type));

        if (v.type.type == BCTypeEnum.i32Ptr)
        {
            assert(v.vType == BCValueType.StackValue);
            return "stack[stack[stackOffset+" ~ to!string(v.stackAddr) ~ "]]";
        }
        else if (v.vType == BCValueType.StackValue)
        {
            return "stack[stackOffset+" ~ to!string(v.stackAddr) ~ "]";
        }
        else if (v.vType == BCValueType.Parameter)
        {
            return "stack[stackOffset+" ~ to!string(v.stackAddr) ~ "]";

        }
        else if (v.vType == BCValueType.Immediate)
        {
            return to!string(v.imm32.imm32);
        }
        else
        {
            assert(0, "unsupported");
        }
    }

    BCAddr beginJmp()
    {
        sameLabel = false;
        code ~= "\tgoto label_xxxx;\n";
        return BCAddr(cast(uint) code.length - 6);
    }

    void endJmp(BCAddr atIp, BCLabel target)
    {
        import std.format;

        string lns = format("%04d", target.addr);
        assert(lns.length == 4);
        foreach (i, c; lns)
        {
            code[atIp + i] = c;
        }
    }

    void genJump(BCLabel target)
    {
        endJmp(beginJmp(), target);
    }

    CndJmpBegin beginCndJmp(BCValue cond = BCValue.init, bool ifFalse = true)
    {
        sameLabel = false;
        string prefix = ifFalse ? "!" : "";
        if (cond.vType == BCValueType.StackValue && cond.type == BCType.i32)
        {
            code ~= "\tif (" ~ prefix ~ "(" ~ toCode(cond) ~ "))\n\t";
        }
        else
        {
            code ~= "\tif (" ~ prefix ~ "cond)\n\t";
        }
        auto labelAt = beginJmp();

        return CndJmpBegin(labelAt, cond, ifFalse);
    }

    void endCndJmp(CndJmpBegin jmp, BCLabel target)
    {
        endJmp(jmp.at, target);
    }

    BCLabel genLabel()
    {
        import std.format;

        if (!sameLabel)
        {
            code ~= format("label_%04d", ++labelCount) ~ ":\n";
            sameLabel = true;
            return BCLabel(BCAddr(labelCount));
        }
        else
        {
            return BCLabel(BCAddr(labelCount));
        }
    }

    BCValue genParameter(BCType bct)
    {
        auto p = BCValue(BCParameter(++parameterCount, bct, sp));
        sp += 4;
        return p;
    }

    void emitArithInstruction(CInst inst, BCValue lhs, BCValue rhs)
    {
        sameLabel = false;
        assert(lhs.vType.StackValue, "only StackValues are supported as lhs");
        // FIXME remove the lhs.type == BCTypeEnum.Char as soon as we convert correctly.
        assert(lhs.type == BCTypeEnum.i32 || lhs.type == BCTypeEnum.i32Ptr
            || lhs.type == BCTypeEnum.Char,
            "only i32 or i32Ptr is supported for now not: " ~ to!string(lhs.type.type));
        assert(rhs.type == BCTypeEnum.i32,
            "only i32 is supported for now, not: " ~ to!string(rhs.type.type));
        code ~= "\t";

        switch (inst)
        {
        case CInst.Add:
            code ~= toCode(lhs) ~ " += " ~ toCode(rhs) ~ ";\n";
            break;
        case CInst.Sub:
            code ~= toCode(lhs) ~ " -= " ~ toCode(rhs) ~ ";\n";
            break;
        case CInst.Mul:
            code ~= toCode(lhs) ~ " *= " ~ toCode(rhs) ~ ";\n";
            break;
        case CInst.Div:
            code ~= toCode(lhs) ~ " /= " ~ toCode(rhs) ~ ";\n";
            break;
        case CInst.Mod:
            code ~= toCode(lhs) ~ " %= " ~ toCode(rhs) ~ ";\n";

            break;
        case CInst.Lsh:
            code ~= toCode(lhs) ~ " <<= " ~ toCode(rhs) ~ ";\n";
            break;
        case CInst.Rsh:
            code ~= toCode(lhs) ~ " >>= " ~ toCode(rhs) ~ ";\n";
            break;
        case CInst.And:
            code ~= toCode(lhs) ~ " &= " ~ toCode(rhs) ~ ";\n";
            break;
        case CInst.Or:
            code ~= toCode(lhs) ~ " |= " ~ toCode(rhs) ~ ";\n";
            break;
        case CInst.Xor:
            code ~= toCode(lhs) ~ " ^= " ~ toCode(rhs) ~ ";\n";
            break;
        case CInst.Set:
            code ~= toCode(lhs) ~ " = " ~ toCode(rhs) ~ ";\n";
            break;
        case CInst.Eq:
            code ~= "cond = (" ~ toCode(lhs) ~ " == " ~ toCode(rhs) ~ ");\n";
            break;
        case CInst.Neq:
            code ~= "cond = (" ~ toCode(lhs) ~ " != " ~ toCode(rhs) ~ ");\n";
            break;
        case CInst.Lt:
            code ~= "cond = (" ~ toCode(lhs) ~ " < " ~ toCode(rhs) ~ ");\n";
            break;
        case CInst.Gt:
            code ~= "cond = (" ~ toCode(lhs) ~ " > " ~ toCode(rhs) ~ ");\n";
            break;
        case CInst.Le:
            code ~= "cond = (" ~ toCode(lhs) ~ " <= " ~ toCode(rhs) ~ ");\n";
            break;
        case CInst.Ge:
            code ~= "cond = (" ~ toCode(lhs) ~ " >= " ~ toCode(rhs) ~ ");\n";
            break;
        default:
            assert(0, "Inst unsupported " ~ to!string(inst));

        }
    }

    void Alloc(BCValue heapPtr, BCValue size)
    {
        import std.format;

        code ~= format(q{
        if ((heapPtr.heapSize + (%s)) < heapPtr.heapMax) {
            (%s) = heapPtr.heapSize;
            heapPtr.heapSize += (%s);
        } else {
            assert(0, "HEAP OVERFLOW!");
        }
        },
            toCode(size), toCode(heapPtr), toCode(size));
    }
    void AssertError(BCValue val, BCValue error) {}
    void Load32(BCValue to, BCValue from)
    {
        sameLabel = false;
        //assert(to.vType == BCValueType.StackValue);
        code ~= "\t" ~ toCode(to) ~ " = heapPtr._heap[" ~ toCode(from) ~ "];\n";
    }

    void Store32(BCValue to, BCValue from)
    {
        sameLabel = false;
        code ~= "\theapPtr._heap[" ~ toCode(to) ~ "] = " ~ toCode(from) ~ ";\n";
    }

    void emitFlg(BCValue result)
    {
        sameLabel = false;
        assert(result.vType == BCValueType.StackValue);
        code ~= ("\t" ~ toCode(result.i32) ~ " = cond;\n");
    }

    void Set(BCValue lhs, BCValue rhs)
    {
        if (lhs != rhs) // do not emit self asignments;
            emitArithInstruction(CInst.Set, lhs, rhs);

        // if (!__ctfe) assert(lhs.stackAddr != 32 && rhs.stackAddr != 12);
    }

    void Lt3(BCValue result, BCValue lhs, BCValue rhs)
    {
        assert(result.vType == BCValueType.Unknown
            || result.vType == BCValueType.StackValue,
            "The result for this must be Empty or a StackValue");
        emitArithInstruction(CInst.Lt, lhs, rhs);
        if (result.vType == BCValueType.StackValue)
        {
            emitFlg(result);
        }

    }

    void Gt3(BCValue result, BCValue lhs, BCValue rhs)
    {
        assert(result.vType == BCValueType.Unknown
            || result.vType == BCValueType.StackValue,
            "The result for this must be Empty or a StackValue");
        emitArithInstruction(CInst.Gt, lhs, rhs);
        if (result.vType == BCValueType.StackValue)
        {
            emitFlg(result);
        }

    }
    void Le3(BCValue result, BCValue lhs, BCValue rhs)
    {
        assert(result.vType == BCValueType.Unknown
            || result.vType == BCValueType.StackValue,
            "The result for this must be Empty or a StackValue");
        emitArithInstruction(CInst.Le, lhs, rhs);
        if (result.vType == BCValueType.StackValue)
        {
            emitFlg(result);
        }

    }

    void Ge3(BCValue result, BCValue lhs, BCValue rhs)
    {
        assert(result.vType == BCValueType.Unknown
            || result.vType == BCValueType.StackValue,
            "The result for this must be Empty or a StackValue");
        emitArithInstruction(CInst.Ge, lhs, rhs);
        if (result.vType == BCValueType.StackValue)
        {
            emitFlg(result);
        }

    }

    void Eq3(BCValue result, BCValue lhs, BCValue rhs)
    {
        assert(result.vType == BCValueType.Unknown
            || result.vType == BCValueType.StackValue,
            "The result for this must be Empty or a StackValue");
        emitArithInstruction(CInst.Eq, lhs, rhs);
        if (result.vType == BCValueType.StackValue)
        {
            emitFlg(result);
        }

    }

    void Neq3(BCValue result, BCValue lhs, BCValue rhs)
    {
        assert(result.vType == BCValueType.Unknown
            || result.vType == BCValueType.StackValue,
            "The result for this must be Empty or a StackValue");
        emitArithInstruction(CInst.Neq, lhs, rhs);
        if (result.vType == BCValueType.StackValue)
        {
            emitFlg(result);
        }
    }

    void Add3(BCValue result, BCValue lhs, BCValue rhs)
    {
        assert(result.vType != BCValueType.Immediate, "Cannot add to Immediate");

        result = (result ? result : lhs);
        if (lhs != result)
        {
            Set(result, lhs);
        }
        emitArithInstruction(CInst.Add, result, rhs);

    }

    void Sub3(BCValue result, BCValue lhs, BCValue rhs)
    {
        assert(result.vType != BCValueType.Immediate, "Cannot sub to Immediate");

        result = (result ? result : lhs);
        if (lhs != result)
        {
            Set(result, lhs);
        }
        emitArithInstruction(CInst.Sub, result, rhs);

    }

    void Mul3(BCValue result, BCValue lhs, BCValue rhs)
    {
        assert(result.vType != BCValueType.Immediate, "Cannot mul to Immediate");

        result = (result ? result : lhs);
        if (lhs != result)
        {
            Set(result, lhs);
        }
        emitArithInstruction(CInst.Mul, result, rhs);

    }

    void Div3(BCValue result, BCValue lhs, BCValue rhs)
    {
        assert(result.vType != BCValueType.Immediate, "Cannot div to Immediate");

        result = (result ? result : lhs);
        if (lhs != result)
        {
            Set(result, lhs);
        }
        emitArithInstruction(CInst.Div, result, rhs);

    }

    void And3(BCValue result, BCValue lhs, BCValue rhs)
    {
        assert(result.vType != BCValueType.Immediate, "Cannot and to Immediate");

        result = (result ? result : lhs);
        if (lhs != result)
        {
            Set(result, lhs);
        }
        emitArithInstruction(CInst.And, result, rhs);

    }

    void Or3(BCValue result, BCValue lhs, BCValue rhs)
    {
        assert(result.vType != BCValueType.Immediate, "Cannot or to Immediate");

        result = (result ? result : lhs);
        if (lhs != result)
        {
            Set(result, lhs);
        }
        emitArithInstruction(CInst.Or, result, rhs);

    }

    void Xor3(BCValue result, BCValue lhs, BCValue rhs)
    {
        assert(result.vType != BCValueType.Immediate, "Cannot or to Immediate");

        result = (result ? result : lhs);
        if (lhs != result)
        {
            Set(result, lhs);
        }
        emitArithInstruction(CInst.Xor, result, rhs);

    }

    void Lsh3(BCValue result, BCValue lhs, BCValue rhs)
    {
        assert(result.vType != BCValueType.Immediate, "Cannot lsh to Immediate");

        result = (result ? result : lhs);
        if (lhs != result)
        {
            Set(result, lhs);
        }
        emitArithInstruction(CInst.Lsh, result, rhs);

    }

    void Rsh3(BCValue result, BCValue lhs, BCValue rhs)
    {
        assert(result.vType != BCValueType.Immediate, "Cannot rsh to Immediate");

        result = (result ? result : lhs);
        if (lhs != result)
        {
            Set(result, lhs);
        }
        emitArithInstruction(CInst.Rsh, result, rhs);

    }

    void Mod3(BCValue result, BCValue lhs, BCValue rhs)
    {
        assert(result.vType != BCValueType.Immediate, "Cannot and to Immediate");

        result = (result ? result : lhs);
        if (lhs != result)
        {
            Set(result, lhs);
        }
        emitArithInstruction(CInst.Mod, result, rhs);
    }

    void Not(BCValue result, BCValue val)
    {
        sameLabel = false;
        assert(val.vType == BCValueType.StackValue || val.vType == BCValueType.Parameter);
        code ~= "\t" ~ toCode(result) ~ " = ~" ~ toCode(val) ~ ";\n";
    }

    void Ret(BCValue val)
    {
        sameLabel = false;
        code ~= "\treturn BCValue(Imm32(" ~ toCode(val) ~ "));\n";
    }

    void Byte3(BCValue result, BCValue word, BCValue idx)
    {
        requireIntrinsics = true;
        code ~= "\t" ~ toCode(result) ~ " = intrin_Byte3(" ~ toCode(word) ~ ", " ~ toCode(idx) ~ ");\n";
    }

    void Call(BCValue result, BCValue fn, BCValue[] args)
    {
        sameLabel = false;
        assert(result.vType == BCValueType.StackValue);
        string resultString = (result ? toCode(result) ~ " = " : "");
        import std.algorithm : map;
        import std.range : join;

        code ~= "\t" ~ resultString ~ "fn" ~ toCode(fn) ~ "(" ~ args.map!(
            a => toCode(a)).join(", ") ~ ");\n";
    }

   /* void CallBuiltin(BCValue result, BCBuiltin fn, BCValue[] args)
    {
        assert(result.vType == BCValueType.StackValue);
        string resultString = (result ? toCode(result) ~ " = " : "");
        switch (fn)
        {
        case BCBuiltin.StringCat:
            {

            }
        default:
            assert(0, "Unsupported builtin " ~ to!string(fn));
        }
        //emitLongInst(LongInst64(LongInst.BuiltinCall, StackAddr(cast(short)fn), StackAddr(cast(short)args.length)));
    } */

    void Cat(BCValue result, BCValue lhs, BCValue rhs, const uint size)
    {
    }
}
static assert(ensureIsBCGen!C_BCGen);
int interpret(const C_BCGen gen)(BCValue[] args)
{
    auto fn = mixin(gen.functionalize(null));
    return fn(args);
}

import bc_test;

//static assert(bc_test.test!C_BCGen);
