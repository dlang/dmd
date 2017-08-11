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

struct BCFunction
{
  void* funcDecl;
  uint fnIdx;
}

struct C_BCGen
{
    struct FunctionState
    {
        uint cndJumpCount;
        uint jmpCount;
        ubyte parameterCount;
        ushort temporaryCount;
        ushort localCount;
        uint labelCount;
        bool sameLabel;
        StackAddr sp = StackAddr(4);
        bool requireIntrinsics;
    }
    bool insideFunction;
    FunctionState[ubyte.max * 8] functionStates;
    uint functionStateCount;
    uint currentFunctionStateNumber;

    string[102_000] errorMessages;
    uint errorMessageCount;

    uint addErrorMessage(string msg)
    {
        if (errorMessageCount < errorMessages.length)
        {
            errorMessages[errorMessageCount++] = msg;
            return errorMessageCount;
        }

        return 0;
    }

    void genFunctionSwitch()
    {
       code ~= "\nBCValue fn(uint fnIdx, BCValue[] args, BCHeap* heapPtr) {\n";
       code ~= "\tswitch(fnIdx) {\n";
       foreach(i;0 .. currentFunctionStateNumber)
       {
           code ~= "\t\tcase " ~ to!string(i) ~ " :\n";
           code ~= "\t\t\treturn fn" ~ to!string(i) ~ "(args, heapPtr);\n\n";
       }
       code ~= "\t\tdefault : assert(0, \"invalid fnIdx\");\n";
       code ~= "\t}\n";
       code ~= "}\n\n";
    }

    @property string functionSuffix()
    {
        return currentFunctionStateNumber > 0 ? "_fn_" ~ to!string(currentFunctionStateNumber) : "";
    }

    alias currentFunctionState this;


    ///for nameless functions generate functionLiteral
    string functionalize(const string fname = null) pure
    {
        import std.algorithm;
        import std.range;

        // first we generate the signature
        return (
            (
            (fname is null) ? "((BCValue[] args, BCHeap* heapPtr) @safe {\n"
            : "BCValue " ~ fname ~ "(BCValue[] args) {\n") ~ "\n\tint stackOffset;\n\tBCValue retval;\n\nint[" ~ to!string(
            align4(sp + 400)) ~ "] stack;\n\tint cond;\n\n" ~ q{
        foreach(i, arg;args)
        {
            assert(arg.type.type == BCTypeEnum.i32, "only i32 args are supported at this point");
            assert(arg.vType == BCValueType.Immediate, "only imm32 args are supported at this point");
            stack[stackOffset+(4*(i+1))] = arg.imm32;
        }
                } ~ cast(
            string) code ~ q{return fn0(args);} ~ ((fname is null) ? "\n})" : "\n}"));
    }


    char[] code;

    void incSp()
    {
        sp += 4;
    }

    StackAddr currSp()
    {
        return sp;
    }

    void Initialize()
    {
        code = code.init;
        foreach(i;0 .. currentFunctionStateNumber)
        {
            functionStates[i] = functionStates[0].init;
        }
        currentFunctionStateNumber = 0;
    }

    void Finalize()
    {
        genFunctionSwitch();
    }
pure:

    @property FunctionState* currentFunctionState()
    {
        return &functionStates[currentFunctionStateNumber];
    }


    void beginFunction(uint fn = 0, void* fnDecl = null)
    {
        sameLabel = false;
        insideFunction = true;
        code ~= "\nBCValue fn" ~  to!string(currentFunctionStateNumber) ~ "(BCValue[] args, BCHeap* heapPtr = null) {\n";

    }

    void endFunction()
    {
        insideFunction = false;
        code ~= "\n}\n";
        currentFunctionStateNumber++;
    }

    BCValue genTemporary(BCType bct)
    {
        auto tmp = BCValue(sp, bct, temporaryCount++);
        currentFunctionState.sp += align4(basicTypeSize(bct.type)); //sharedState.size(bct.type, typeIndex));

        return tmp;
    }

    string toCode(BCValue v) pure const
    {
        if (v.type.type == BCTypeEnum.Char)
            v = v.i32;
        else if (v.type.type == BCTypeEnum.String)
            v = v.i32;
        else if (v.type.type == BCTypeEnum.Ptr)
            v = v.i32;
        else if (v.type.type == BCTypeEnum.Array)
            v = v.i32;
        else if (v.type.type == BCTypeEnum.Slice)
            v = v.i32;
        else if (v.type.type == BCTypeEnum.Struct)
            v = v.i32;
        else if (v.type.type == BCTypeEnum.Function)
            v = v.i32;
        // the next one is highly doubious
        else if (v.type.type == BCTypeEnum.i64)
            v = v.i32;
        // this one is highly doubious too
        if (v.type.type == BCTypeEnum.Void || v.type.type == BCTypeEnum.Null)
        {
            v = imm32(0);
        }

        assert(v.type.type == BCTypeEnum.i32,
            "i32 expected not: " ~ to!string(v.type.type));

        if (v.vType == BCValueType.StackValue)
        {
            return "stack[stackOffset+" ~ to!string(v.stackAddr) ~ "]";
        }
        else if (v.vType == BCValueType.Parameter)
        {
            return "stack[stackOffset+" ~ to!string(v.stackAddr) ~ "]";
        }
        else if (v.vType == BCValueType.Local)
        {
            return "stack[stackOffset+" ~ to!string(v.stackAddr) ~ "]";
        }
        else if (v.vType == BCValueType.Immediate)
        {
            return to!string(v.imm32.imm32);
        }
        else if (v.vType == BCValueType.Error)
        {
            return to!string(v.imm32.imm32);

        }
        else
        {
            assert(0, "unsupported " ~ to!string(v.vType));
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

    CndJmpBegin beginCndJmp(BCValue cond = BCValue.init, bool ifTrue = false)
    {
        sameLabel = false;
        string prefix = ifTrue ? "" : "!";
        if ((cond.vType == BCValueType.StackValue || cond.vType == BCValueType.Parameter) && cond.type.type == BCTypeEnum.i32)
        {
            code ~= "\tif (" ~ prefix ~ "(" ~ toCode(cond) ~ "))\n\t";
        }
        else
        {
            code ~= "\tif (" ~ prefix ~ "cond)\n\t";
        }
        auto labelAt = beginJmp();

        return CndJmpBegin(labelAt, cond, ifTrue);
    }

    void endCndJmp(CndJmpBegin jmp, BCLabel target)
    {
        sameLabel = false;
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

    BCValue genParameter(BCType bct, string name = null)
    {
        auto p = BCValue(BCParameter(++parameterCount, bct, sp));
        p.name = name;
        sp += 4;
        return p;
    }

    BCValue genLocal(BCType bct, string name = null)
    {
        auto l = BCValue(StackAddr(sp), bct, localCount, name);
        sp += 4;
        return l;
    }


    void emitArithInstruction(CInst inst, BCValue lhs, BCValue rhs)
    {
        sameLabel = false;
        assert(lhs.vType.StackValue, "only StackValues are supported as lhs");
        // FIXME remove the lhs.type == BCTypeEnum.Char as soon as we convert correctly.
/*        assert(lhs.type == BCTypeEnum.i32 || lhs.type == BCTypeEnum.Char,
            "only i32 is supported for now not: " ~ to!string(lhs.type.type));
        assert(rhs.type == BCTypeEnum.i32,
            "only i32 is supported for now, not: " ~ to!string(rhs.type.type));
*/
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
        sameLabel = false;
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

    void MemCpy(BCValue target, BCValue source, BCValue size)
    {
        code ~= "assert(" ~ toCode(target) ~ ");\n";
        code ~= "assert(" ~ toCode(source) ~ ");\n";
        code ~= "if (" ~ toCode(source) ~  " != " ~ toCode(target) ~ ")\n";
        code ~= "\theapPtr._heap[" ~ toCode(target) ~ " .. " ~ toCode(target) ~ " + " ~ toCode(size) ~
            "] = heapPtr._heap[" ~ toCode(source) ~ " .. " ~ toCode(source) ~ " + " ~ toCode(size) ~"];\n\n";
    }
    void Assert(BCValue val, BCValue error)
    {
        sameLabel = false;
        code ~= "assert(" ~ toCode(val) ~ ", \"" ~ errorMessages[error.imm32 - 1] ~ "\"));\n";
    }

    void Load32(BCValue to, BCValue from)
    {
        sameLabel = false;
        //assert(to.vType == BCValueType.StackValue);
        code ~= "\t" ~ toCode(to) ~ " = heapPtr._heap[cast(uint)" ~ toCode(from) ~ "];\n";
    }

    void Store32(BCValue to, BCValue from)
    {
        sameLabel = false;
        code ~= "\theapPtr._heap[" ~ toCode(to) ~ "] = (" ~ toCode(from) ~ " & uint.max);\n";
    }

    void Load64(BCValue to, BCValue from)
    {
        sameLabel = false;
        //assert(to.vType == BCValueType.StackValue);
        code ~= "\t" ~ toCode(to) ~ " |= heapPtr._heap[" ~ toCode(from) ~ "];\n";
        code ~= "\t" ~ toCode(to) ~ " |= (heapPtr._heap[" ~ toCode(from) ~ " + 4] >> 32);\n";
    }
    
    void Store64(BCValue to, BCValue from)
    {
        sameLabel = false;
        code ~= "\theapPtr._heap[" ~ toCode(to) ~ "] = (" ~ toCode(from) ~ " & uint.max);\n";
        code ~= "\theapPtr._heap[" ~ toCode(to) ~ " + 4] = (" ~ toCode(from) ~ " >> 32);\n";
    }


    void emitFlg(BCValue result)
    {
        sameLabel = false;
        assert(isStackValueOrParameter(result));
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
            || isStackValueOrParameter(result),
            "The result for this must be Empty or a StackValue");
        emitArithInstruction(CInst.Lt, lhs, rhs);
        if (isStackValueOrParameter(result))
        {
            emitFlg(result);
        }

    }

    void Gt3(BCValue result, BCValue lhs, BCValue rhs)
    {
        assert(result.vType == BCValueType.Unknown
            || isStackValueOrParameter(result),
            "The result for this must be Empty or a StackValue");
        emitArithInstruction(CInst.Gt, lhs, rhs);
        if (isStackValueOrParameter(result))
        {
            emitFlg(result);
        }

    }

    void Le3(BCValue result, BCValue lhs, BCValue rhs)
    {
        assert(result.vType == BCValueType.Unknown
            || isStackValueOrParameter(result),
            "The result for this must be Empty or a StackValue");
        emitArithInstruction(CInst.Le, lhs, rhs);
        if (isStackValueOrParameter(result))
        {
            emitFlg(result);
        }

    }

    void Ge3(BCValue result, BCValue lhs, BCValue rhs)
    {
        assert(result.vType == BCValueType.Unknown
            || isStackValueOrParameter(result),
            "The result for this must be Empty or a StackValue");
        emitArithInstruction(CInst.Ge, lhs, rhs);
        if (isStackValueOrParameter(result))
        {
            emitFlg(result);
        }

    }

    void Eq3(BCValue result, BCValue lhs, BCValue rhs)
    {
        assert(result.vType == BCValueType.Unknown
            || isStackValueOrParameter(result),
            "The result for this must be Empty or a StackValue");
        emitArithInstruction(CInst.Eq, lhs, rhs);
        if (isStackValueOrParameter(result))
        {
            emitFlg(result);
        }

    }

    void Neq3(BCValue result, BCValue lhs, BCValue rhs)
    {
        assert(result.vType == BCValueType.Unknown
            || isStackValueOrParameter(result),
            "The result for this must be Empty or a StackValue");
        emitArithInstruction(CInst.Neq, lhs, rhs);
        if (isStackValueOrParameter(result))
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
        sameLabel = false;
        requireIntrinsics = true;
        code ~= "\t" ~ toCode(result) ~ " = intrin_Byte3(" ~ toCode(word) ~ ", " ~ toCode(idx) ~ ");\n";
    }

    import ddmd.globals : Loc;
    void Call(BCValue result, BCValue fn, BCValue[] args, Loc l = Loc.init)
    {
        sameLabel = false;
        assert(isStackValueOrParameter(result));
        string resultString = ((result && result.stackAddr != 0) ? toCode(result) ~ " = " : "");
        string functionString =  (fn.vType == BCValueType.Immediate ? "fn" ~ toCode(fn)~ "(" : "fn(" ~ toCode(fn) ~ ", ");

        import std.algorithm : map;
        import std.range : join;

        code ~= "\t" ~ resultString ~ functionString ~ "[" ~ args.map!(
            a => "imm32(" ~ toCode(a) ~ ")").join(", ") ~ "], heapPtr).imm32;\n";
    }

    void IToF32(BCValue target, BCValue source)
    {
        assert(0);
    }


    void IToF64(BCValue target, BCValue source)
    {
        assert(0);
    }

    void Comment(string comment)
    {
        code ~= "// " ~ comment ~ "\n";
    }

    void Line(uint line)
    {
        code ~= "/***** Line (" ~ to!string(line) ~ ") *****/\n";
    }

   /* void CallBuiltin(BCValue result, BCBuiltin fn, BCValue[] args)
    {
        assert(isStackValueOrParameter(result));
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



}
static assert(ensureIsBCGen!C_BCGen);
int interpret(const C_BCGen gen)(BCValue[] args)
{
    auto fn = mixin(gen.functionalize(null));
    return fn(args);
}

import ddmd.ctfe.bc_test;

static assert(test!C_BCGen);
