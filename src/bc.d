module ddmd.ctfe.bc;
import ddmd.ctfe.bc_common;
import core.stdc.stdio;
import std.conv;

/**
 * Written By Stefan Koch in 2016
 */

enum InstKind
{
    ShortInst,
    CndJumpInst,

    LongInst2Stack,
    LongInstImm32,

    StackInst,
}
/+ We don't need this right now ... maybe later
auto instKind(LongInst i)
{
    final switch (i)
    {
    case  /*LongInst.Prt,*/ LongInst.RelJmp, LongInst.Ret, LongInstc,
            LongInst.Flg, LongInst.Mod4:
        {
            return InstKind.ShortInst;
        }

    case LongInst.Jmp, LongInst.JmpFalse, LongInst.JmpTrue, LongInst.JmpZ, LongInst.JmpNZ:
        {
            return InstKind.CndJumpInst;
        }

    case LongInst.Add, LongInst.Sub, LongInst.Div, LongInst.Mul, LongInst.Eq, LongInst.Neq,
            LongInst.Lt, LongInst.Le, LongInst.Gt, LongInst.Ge, LongInst.Set, LongInst.And, LongInst.Or,
            LongInst.Xor, LongInst.Lsh, LongInst.Rsh, LongInst.Mod, // loadOps begin
            LongInst.HeapLoad32, LongInst.HeapStore32, LongInst.ExB, LongInst.Alloc:
        {
            return InstKind.LongInst2Stack;
        }

    case LongInst.ImmAdd, LongInst.ImmSub, LongInst.ImmDiv, LongInst.ImmMul,
            LongInst.ImmEq, LongInst.ImmNeq, LongInst.ImmLt, LongInst.ImmLe, LongInst.ImmGt, LongInst.ImmGe, LongInst.ImmSet,
            LongInst.ImmAnd, LongInst.ImmOr, LongInst.ImmXor, LongInst.ImmLsh,
            LongInst.ImmRsh, LongInst.ImmMod, LongInst.Call, LongInst.BuiltinCall,
            LongInst.ImmSetHigh:
        {
            return InstKind.LongInstImm32;
        }

    }
} +/

struct RetainedCall
{
    import ddmd.globals : Loc;
    BCValue fn;
    BCValue[] args;

    uint callerId;
    BCAddr callerIp;
    StackAddr callerSp;
    Loc loc;
}

enum LongInst : ushort
{
    //Former ShortInst
    //Prt,
    RelJmp,
    Ret,
    Not,

    Flg, // writes the conditionFlag into [lw >> 16]
    //End Former ShortInst

    Jmp,
    JmpFalse,
    JmpTrue,
    JmpZ,
    JmpNZ,

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

    StrEq,
    StrCat,
    Assert,
    AssertCnd,

    // Immidate operand
    ImmAdd,
    ImmSub,
    ImmDiv,
    ImmMul,
    ImmEq,
    ImmNeq,
    ImmLt,
    ImmLe,
    ImmGt,
    ImmGe,
    ImmSet,
    ImmAnd,
    ImmOr,
    ImmXor,
    ImmLsh,
    ImmRsh,
    ImmMod,

    ImmSetHigh,

    Call,
    HeapLoad32, ///SP[hi & 0xFFFF] = Heap[align4(SP[hi >> 16])]
    HeapStore32, ///Heap[align4(SP[hi & 0xFFFF)] = SP[hi >> 16]]
    ExB, /// extract Byte SP[hi & 0xFFFF] = extractByte(SP[hi & 0xFFFF], SP[hi >> 16])
    Alloc, /// SP[hi & 0xFFFF] = heapSize; heapSize += SP[hi >> 16]

    BuiltinCall, // call a builtin.

}
//Imm-Intructuins and corrospinding 2Operand instructions have to be in the same order
pragma(msg, 2 ^^ 6 - LongInst.max, " opcodes remaining");
static assert(LongInst.ImmAdd - LongInst.Add == LongInst.ImmRsh - LongInst.Rsh);
static assert(LongInst.ImmAnd - LongInst.And == LongInst.ImmMod - LongInst.Mod);

enum IndirectionFlagMask = ubyte(0x40); // check 7th bit

enum InstMask = ubyte(0x3F); // mask for bit 0-5
//enum CondFlagMask = ~ushort(0x2FF); // mask for 8-10th bit
enum CondFlagMask = 0b11_0000_0000;

/** 2StackInst Layout :
* [0-6] Instruction
* [6-8] Flags
* -----------------
* [8-12] CondFlag (or Padding)
* [12-32] Padding
* [32-48] StackOffset (lhs)
* [48-64] StackOffset (rhs)
* *************************
* ImmInstructions Layout :
* [0-6] Instruction
* [6-8] Flags
* ------------------------
* [8-12] CondFlag (or Padding)
* [12-16] Padding
* [16-32] StackOffset (lhs)
* [32-64] Imm32 (rhs)
*/
struct LongInst64
{
    uint lw;
    uint hi;
@safe pure const:
    this(const LongInst i, const BCAddr addr)
    {
        lw = i;
        hi = addr.addr;
    }

    this(const LongInst i, const StackAddr stackAddrLhs, const BCAddr targetAddr)
    {
        lw = i;
        hi = stackAddrLhs.addr | targetAddr.addr << 16;
    }

    this(const LongInst i, const StackAddr stackAddrLhs,
        const StackAddr stackAddrRhs, const bool indirect = false)
    {
        lw = i | indirect << 6;
        hi = stackAddrLhs.addr | stackAddrRhs.addr << 16;
    }

    this(const LongInst i, const StackAddr stackAddrLhs, const Imm32 rhs, const bool indirect = false)
    {
        lw = i | indirect << 6 | stackAddrLhs.addr << 16;
        hi = rhs.imm32;
    }
}

static bool isStackValueOrParameter(BCValue val) pure @safe nothrow
{
    return (val.vType == BCValueType.StackValue || val.vType == BCValueType.Parameter);
}

static assert(LongInst.max < 0x3F, "Instruction do not fit in 6 bit anymore");

static short isShortJump(const int offset) pure @safe
{
    assert(offset != 0, "An Jump to the Jump itself is invalid");

    const bool wasNegative = (offset < 0);
    int abs_offset = wasNegative ? offset * -1 : offset;

    if (abs_offset < (1 << 15))
    {
        return (cast(ushort)(wasNegative ? abs_offset *= -1 : abs_offset));
    }
    else
    {
        return 0;
    }
}

auto ShortInst16(const LongInst i, const int _imm, const bool indirect = false) pure @safe
{
    short imm = cast(short) _imm;
    return i | indirect << 6 | imm << 16;
}

auto ShortInst16Ex(const LongInst i, ubyte ex, const short imm) pure @safe
{
    return i | ex << 8 | imm << 16;
}


enum BCFunctionTypeEnum : byte
{
    undef,
    Builtin,
    Bytecode,
    Compiled,
}

//static if (is(typeof(() { import ddmd.declaration : FuncDeclaration; })))
//{
//    import ddmd.declaration : FuncDeclaration;
//    alias FT = FuncDeclaration;
//}
//else
//{
//    alias FT = void*;
//}

struct BCFunction
{
    void* funcDecl;
    uint fn;
    BCFunctionTypeEnum type;
    ushort nArgs;
    ushort maxStackUsed;

    union
    {
        immutable(int)[] byteCode;
        BCValue function(const BCValue[] arguments, uint[] heapPtr) _fBuiltin;
        BCValue function(const BCValue[] arguments, uint[] heapPtr, uint[] stackPtr) fPtr;
    }

    //    this(void* fd, BCFunctionTypeEnum type, int nr, const int[] byteCode, uint nArgs) pure
    //    {
    //        this.funcDecl = fd;
    //        this.nr = nr;
    //        this.type = BCFunctionTypeEnum.Builtin;
    //        this.byteCode = cast(immutable(int)[]) byteCode;
    //        this.nArgs = nArgs;
    //    }
    //
    //    this(int nr, BCValue function(const BCValue[] arguments, uint[] heapPtr) _fBuiltin,
    //        uint nArgs) pure
    //    {
    //        this.nr = nr;
    //        this.type = BCFunctionTypeEnum.Builtin;
    //        this._fBuiltin = _fBuiltin;
    //        this.nArgs = nArgs;
    //    }
    //
}

struct BCGen
{
    int[ushort.max / 4] byteCodeArray;

    /// ip starts at 4 because 0 should be an invalid address;
    BCAddr ip = BCAddr(4);
    StackAddr sp = StackAddr(4);
    ubyte parameterCount;
    ushort temporaryCount;
    uint functionId;
    void* fd;

    RetainedCall[ubyte.max * 6] calls;
    uint callCount;
    auto interpret(BCValue[] args, BCHeap* heapPtr) const
    {
        return interpret_(cast(const) byteCodeArray[0 .. ip], args, heapPtr, null);
    }

    auto interpret(BCValue[] args) const
    {
        return interpret_(cast(const) byteCodeArray[0 .. ip], args, null, null);
    }
@safe pure:

    void emitLongInst(LongInst64 i)
    {
        byteCodeArray[ip] = i.lw;
        byteCodeArray[ip + 1] = i.hi;
        ip += 2;
    }

    BCValue genTemporary(BCType bct)
    {
        auto tmpAddr = sp.addr;
        if (isBasicBCType(bct))
        {
            sp += align4(basicTypeSize(bct));
        }
        else
        {
            sp += 4;
        }

        return BCValue(StackAddr(tmpAddr), bct, ++temporaryCount);
    }

    BCValue genTemporary(uint size, BCType bct)
    {
        auto tmpAddr = sp.addr;
        sp += align4(size);

        return BCValue(StackAddr(tmpAddr), bct, ++temporaryCount);
    }

    void Initialize()
    {
        callCount = 0;
        parameterCount = 0;
        temporaryCount = 0;
        byteCodeArray[0] = 0;
        byteCodeArray[1] = 0;
        byteCodeArray[2] = 0;
        byteCodeArray[3] = 0;

        ip = BCAddr(4);
        sp = StackAddr(4);
    }

    void Finalize()
    {
        callCount = 0;

        //the [ip-1] may be wrong in some cases ?
/*        byteCodeArray[ip - 1] = 0;
        byteCodeArray[ip] = 0;
        byteCodeArray[ip + 1] = 0;
*/
    }

    void beginFunction(uint fnId = 0, void* fd = null)
    {
        ip = BCAddr(4);

        functionId = fnId;
    }

    BCFunction endFunction()
    {
        BCFunction result;
        result.type = BCFunctionTypeEnum.Bytecode;
        result.maxStackUsed = sp;
        result.fn = functionId;
        {
            // MUTEX BEGIN
            // result.byteCode = byteCodeArray[4 .. ip];
            // MUTEX END
        }
        sp = StackAddr(4);

        return result;
    }

    BCValue genParameter(BCType bct)
    {
        auto p = BCValue(BCParameter(++parameterCount, bct, sp));
        sp += 4;
        return p;
    }

    BCAddr beginJmp()
    {
        BCAddr atIp = ip;
        ip += 2;
        return atIp;
    }

    void incSp()
    {
        sp += 4;
    }

    StackAddr currSp()
    {
        return sp;
    }

    void endJmp(BCAddr atIp, BCLabel target)
    {
        if (auto offset = isShortJump(target.addr - atIp))
        {
            byteCodeArray[atIp] = ShortInst16(LongInst.RelJmp, offset);
        }
        else
        {
            LongInst64 lj = LongInst64(LongInst.Jmp, target.addr);
            byteCodeArray[atIp] = lj.lw;
            byteCodeArray[atIp + 1] = lj.hi;
        }
    }

    BCLabel genLabel()
    {
        return BCLabel(ip);
    }

    CndJmpBegin beginCndJmp(BCValue cond = BCValue.init, bool ifTrue = false)
    {
        auto result = CndJmpBegin(ip, cond, ifTrue);
        ip += 2;
        return result;
    }

    void endCndJmp(CndJmpBegin jmp, BCLabel target)
    {
        auto atIp = jmp.at;
        auto cond = jmp.cond;
        auto ifTrue = jmp.ifTrue;

        LongInst64 lj;
        if (isStackValueOrParameter(cond) && cond.type == BCType.i32)
        {
            lj = (ifTrue ? LongInst64(LongInst.JmpNZ, cond.stackAddr,
                target.addr) : LongInst64(LongInst.JmpZ, cond.stackAddr, target.addr));
        }
        else
        {
            lj = (ifTrue ? LongInst64(LongInst.JmpTrue,
                target.addr) : LongInst64(LongInst.JmpFalse, target.addr));
        }

        byteCodeArray[atIp] = lj.lw;
        byteCodeArray[atIp + 1] = lj.hi;
    }

    void genJump(BCLabel target)
    {
        assert(target.addr);
        if (ip != target.addr)
        {
            auto at = beginJmp();
            endJmp(at, target);
        }
    }

    void emitFlg(BCValue lhs)
    {
        assert(lhs.vType == BCValueType.StackValue, "Can only store flags in Stack Values");
        byteCodeArray[ip] = ShortInst16(LongInst.Flg, lhs.stackAddr.addr);
        byteCodeArray[ip + 1] = 0;
        ip += 2;
    }

    void Alloc(BCValue heapPtr, BCValue size)
    {
        assert(size.type.type == BCTypeEnum.i32, "Size for alloc needs to be an i32");
        if (size.vType == BCValueType.Immediate)
        {
            size = pushOntoStack(size);
        }
        assert(isStackValueOrParameter(size));
        assert(isStackValueOrParameter(heapPtr));

        emitLongInst(LongInst64(LongInst.Alloc, heapPtr.stackAddr, size.stackAddr));
    }

    void Assert(BCValue value, BCValue err)
    {
        BCValue _msg;
        if(err.vType == BCValueType.Error)
        {
            _msg = genTemporary(i32Type);
            Set(_msg, imm32(err.imm32));
        }
        else if (isStackValueOrParameter(err))
        {
            //assert(0, "err.vType is not Error but: " ~ err.vType.to!string);
            _msg = err;
        }

        if (value)
        {
            emitLongInst(LongInst64(LongInst.Assert, value.stackAddr, _msg.stackAddr));
        }
        else
        {
            emitLongInst(LongInst64(LongInst.AssertCnd, value.stackAddr, _msg.stackAddr));
        }

    }

    void Not(BCValue result, BCValue val)
    {
        if (result != val)
        {
            Set(result, val);
            val = result;
        }
        if (val.vType == BCValueType.Immediate)
            val = pushOntoStack(val);

        byteCodeArray[ip] = ShortInst16(LongInst.Not, val.stackAddr);
        byteCodeArray[ip + 1] = 0;
        ip += 2;
    }

    void emitArithInstruction(LongInst inst, BCValue lhs, BCValue rhs)
    {
        assert(inst >= LongInst.Add && inst < LongInst.ImmAdd,
            "Instruction is not in Range for Arith Instructions");
        assert(lhs.vType.StackValue, "only StackValues are supported as lhs");
        // FIXME remove the lhs.type == BCTypeEnum.Char as soon as we convert correctly.
        assert(lhs.type == BCTypeEnum.i32 || lhs.type == BCTypeEnum.i64 || lhs.type == BCTypeEnum.Char,
            "only i32 or i32Ptr is supported for now not: " ~ to!string(lhs.type.type));

        if (lhs.vType == BCValueType.Immediate)
        {
            lhs = pushOntoStack(lhs);
        }

        if (rhs.vType == BCValueType.Immediate)
        {
            //Change the instruction into the corrosponding Imm Instruction;
            inst += (LongInst.ImmAdd - LongInst.Add);
            emitLongInst(LongInst64(inst, lhs.stackAddr, rhs.imm32));
        }
        else if (isStackValueOrParameter(rhs))
        {
            emitLongInst(LongInst64(inst, lhs.stackAddr, rhs.stackAddr));
        }
        else
        {
            assert(0, "Cannot handle: " ~ to!string(rhs.vType));
        }
    }

    void Set(BCValue lhs, BCValue rhs)
    {
        if (lhs != rhs) // do not emit self asignments;
            emitArithInstruction(LongInst.Set, lhs, rhs);
    }

    void Lt3(BCValue result, BCValue lhs, BCValue rhs)
    {
        assert(result.vType == BCValueType.Unknown
            || isStackValueOrParameter(result),
            "The result for this must be Empty or a StackValue");
        emitArithInstruction(LongInst.Lt, lhs, rhs);

        if (result.vType == BCValueType.StackValue)
        {
            emitFlg(result);
        }
    }

    void Le3(BCValue result, BCValue lhs, BCValue rhs)
    {
        assert(result.vType == BCValueType.Unknown
            || isStackValueOrParameter(result),
            "The result for this must be Empty or a StackValue");
        emitArithInstruction(LongInst.Le, lhs, rhs);

        if (result.vType == BCValueType.StackValue)
        {
            emitFlg(result);
        }
    }

    void Gt3(BCValue result, BCValue lhs, BCValue rhs)
    {
        assert(result.vType == BCValueType.Unknown
            || isStackValueOrParameter(result),
            "The result for this must be Empty or a StackValue");
        emitArithInstruction(LongInst.Gt, lhs, rhs);
        if (result.vType == BCValueType.StackValue)
        {
            emitFlg(result);
        }
    }

    void Ge3(BCValue result, BCValue lhs, BCValue rhs)
    {
        assert(result.vType == BCValueType.Unknown
            || isStackValueOrParameter(result),
            "The result for this must be Empty or a StackValue");
        emitArithInstruction(LongInst.Ge, lhs, rhs);
        if (result.vType == BCValueType.StackValue)
        {
            emitFlg(result);
        }
    }

    void Eq3(BCValue result, BCValue lhs, BCValue rhs)
    {
        assert(result.vType == BCValueType.Unknown
            || isStackValueOrParameter(result),
            "The result for this must be Empty or a StackValue not " ~ to!string(result.vType) );
        emitArithInstruction(LongInst.Eq, lhs, rhs);

        if (result.vType == BCValueType.StackValue)
        {
            emitFlg(result);
        }
    }

    void Neq3(BCValue result, BCValue lhs, BCValue rhs)
    {
        assert(result.vType == BCValueType.Unknown
            || isStackValueOrParameter(result),
            "The result for this must be Empty or a StackValue");
        emitArithInstruction(LongInst.Neq, lhs, rhs);

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

        emitArithInstruction(LongInst.Add, result, rhs);
    }

    void Sub3(BCValue result, BCValue lhs, BCValue rhs)
    {
        assert(result.vType != BCValueType.Immediate, "Cannot sub to Immediate");

        result = (result ? result : lhs);
        if (lhs != result)
        {
            Set(result, lhs);
        }

        emitArithInstruction(LongInst.Sub, result, rhs);
    }

    void Mul3(BCValue result, BCValue lhs, BCValue rhs)
    {
        assert(result.vType != BCValueType.Immediate, "Cannot mul to Immediate");

        result = (result ? result : lhs);
        if (lhs != result)
        {
            Set(result, lhs);
        }

        emitArithInstruction(LongInst.Mul, result, rhs);
    }

    void Div3(BCValue result, BCValue lhs, BCValue rhs)
    {
        assert(result.vType != BCValueType.Immediate, "Cannot div to Immediate");

        result = (result ? result : lhs);
        if (lhs != result)
        {
            Set(result, lhs);
        }
        emitArithInstruction(LongInst.Div, result, rhs);
    }

    void And3(BCValue result, BCValue lhs, BCValue rhs)
    {
        assert(result.vType != BCValueType.Immediate, "Cannot and to Immediate");

        result = (result ? result : lhs);
        if (lhs != result)
        {
            Set(result, lhs);
        }
        emitArithInstruction(LongInst.And, result, rhs);

    }

    void Or3(BCValue result, BCValue lhs, BCValue rhs)
    {
        assert(result.vType != BCValueType.Immediate, "Cannot or to Immediate");

        result = (result ? result : lhs);
        if (lhs != result)
        {
            Set(result, lhs);
        }
        emitArithInstruction(LongInst.Or, result, rhs);

    }

    void Xor3(BCValue result, BCValue lhs, BCValue rhs)
    {
        assert(result.vType != BCValueType.Immediate, "Cannot or to Immediate");

        result = (result ? result : lhs);
        if (lhs != result)
        {
            Set(result, lhs);
        }
        emitArithInstruction(LongInst.Xor, result, rhs);
    }

    void Lsh3(BCValue result, BCValue lhs, BCValue rhs)
    {
        assert(result.vType != BCValueType.Immediate, "Cannot lsh to Immediate");

        result = (result ? result : lhs);
        if (lhs != result)
        {
            Set(result, lhs);
        }
        emitArithInstruction(LongInst.Lsh, result, rhs);
    }

    void Rsh3(BCValue result, BCValue lhs, BCValue rhs)
    {
        assert(result.vType != BCValueType.Immediate, "Cannot rsh to Immediate");

        result = (result ? result : lhs);
        if (lhs != result)
        {
            Set(result, lhs);
        }
        emitArithInstruction(LongInst.Rsh, result, rhs);
    }

    void Mod3(BCValue result, BCValue lhs, BCValue rhs)
    {
        assert(result.vType != BCValueType.Immediate, "Cannot and to Immediate");

        result = (result ? result : lhs);
        if (lhs != result)
        {
            Set(result, lhs);
        }
        emitArithInstruction(LongInst.Mod, result, rhs);
    }
    import ddmd.globals : Loc;
    void Call(BCValue result, BCValue fn, BCValue[] args, Loc l = Loc.init)
    {
        calls[callCount++] = RetainedCall(fn, args, functionId, ip, sp, l);
        emitLongInst(LongInst64(LongInst.Call, result.stackAddr, pushOntoStack(imm32(callCount)).stackAddr));
    }

    void Load32(BCValue _to, BCValue from)
    {
        if (from.vType != BCValueType.StackValue)
        {
            from = pushOntoStack(from);
        }
        if (_to.vType != BCValueType.StackValue)
        {
            _to = pushOntoStack(_to);
        }
        assert(isStackValueOrParameter(_to), "to has the vType " ~ to!string(_to.vType));
        assert(isStackValueOrParameter(from), "from has the vType " ~ to!string(from.vType));

        emitLongInst(LongInst64(LongInst.HeapLoad32, _to.stackAddr, from.stackAddr));
    }

    void Store32(BCValue _to, BCValue value)
    {
        if (value.vType != BCValueType.StackValue)
        {
            value = pushOntoStack(value);
        }
        if (_to.vType != BCValueType.StackValue)
        {
            _to = pushOntoStack(_to);
        }

        assert(isStackValueOrParameter(_to), "to has the vType " ~ to!string(_to.vType));
        assert(isStackValueOrParameter(value), "value has the vType " ~ to!string(value.vType));

        emitLongInst(LongInst64(LongInst.HeapStore32, _to.stackAddr, value.stackAddr));
    }

    void Byte3(BCValue result, BCValue word, BCValue idx)
    {
        if (word != result)
        {
            Set(result, word);
        }
        emitLongInst(LongInst64(LongInst.ExB, result.stackAddr, idx.stackAddr));
    }

    BCValue pushOntoStack(BCValue val)
    {
        if (val.vType != BCValueType.StackValue)
        {
            auto stackref = BCValue(currSp(), val.type);
            Set(stackref.i32, val);

            sp += align4(basicTypeSize(val.type));
            return stackref;
        }
        else
        {
            return val;
        }
    }

    void Ret(BCValue val)
    {
        if (val.vType == BCValueType.StackValue || val.vType == BCValueType.Parameter)
        {

            byteCodeArray[ip] = ShortInst16(LongInst.Ret, val.stackAddr);
            byteCodeArray[ip + 1] = 0;
            ip += 2;
        }
        else if (val.vType == BCValueType.Immediate)
        {
            auto sv = pushOntoStack(val);
            assert(sv.vType == BCValueType.StackValue);
            byteCodeArray[ip] = ShortInst16(LongInst.Ret, sv.stackAddr);
            byteCodeArray[ip + 1] = 0;
            ip += 2;
        }
        else
        {
                assert(0, "I cannot deal with this type of return" ~ to!string(val.vType));
        }
    }

    void StrEq3(BCValue result, BCValue lhs, BCValue rhs)
    {
        assert(result.vType == BCValueType.Unknown
            || result.vType == BCValueType.StackValue,
            "The result for this must be Empty or a StackValue");
        if (lhs.vType == BCValueType.Immediate)
        {
            lhs = pushOntoStack(lhs);
        }
        if (rhs.vType == BCValueType.Immediate)
        {
            rhs = pushOntoStack(rhs);
        }
        assert(isStackValueOrParameter(lhs),
            "The lhs of StrEq3 is not a StackValue " ~ to!string(rhs.vType));
        assert(isStackValueOrParameter(rhs),
            "The rhs of StrEq3 not a StackValue" ~ to!string(rhs.vType));

        emitLongInst(LongInst64(LongInst.StrEq, lhs.stackAddr, rhs.stackAddr, false));

        if (result.vType == BCValueType.StackValue)
        {
            emitFlg(result);
        }
    }

    void StrCat3(BCValue result, BCValue lhs, BCValue rhs)
    {
        assert(result.vType == BCValueType.StackValue, "The result of StrCat3 a StackValue");
        assert(result.vType == BCValueType.StackValue, "The lhs of StrCat3 a StackValue");
        assert(result.vType == BCValueType.StackValue, "The rhs of StrCat3 a StackValue");
        auto aLength = genTemporary(i32Type);
        auto bLength = genTemporary(i32Type);
        auto cLength = genTemporary(i32Type);
        auto newString = genTemporary(i32Type);
        Set(cLength, imm32(8));
        Load32(aLength, lhs);
        Load32(bLength, rhs);
        Add3(cLength, cLength, bLength);
        Add3(cLength, cLength, bLength);
        Div3(cLength, cLength, imm32(4));
        Alloc(newString, cLength);
        emitLongInst(LongInst64(LongInst.StrCat, newString.stackAddr, lhs.stackAddr,
            false));
        emitLongInst(LongInst64(LongInst.StrCat, newString.stackAddr, rhs.stackAddr,
            false));
        Set(result, newString);
    }

    void LoadIndexed(BCValue result, BCValue array, BCValue idx, BCValue arrayLength)
    {

        auto elmSize = imm32(basicTypeSize(result.type));

        assert(result.vType == BCValueType.StackValue);
        assert(idx.type.type == BCTypeEnum.i32);

        auto tmpPtr = genTemporary(BCType(BCType.i32));
        auto ptr = tmpPtr;

        version (boundscheck)
        {
            auto condResult = genTemporary(BCType.i32).value;
            Lt3(condResult, idx, arrayLength);
            Assert(condResult, "Index ", idx, " is bigger then ArrayLength ", arrayLength);
        }

        Mul3(ptr, idx, elmSize);
        Add3(ptr, ptr, array.i32);

        //TODO assert that idx is not out of bounds;
        assert(result.type.type == BCTypeEnum.i32, "currently only i32 is supported");

        emitLongInst(LongInst64(LongInst.HeapLoad32, result.stackAddr, ptr.stackAddr));
        //removeTemporary(tmpPtr);

    }

    void Cat(BCValue result, BCValue lhs, BCValue rhs, const uint size)
    {
        import ddmd.ctfe.bc_macro;
        CatMacro(&this, result, lhs, rhs, size);
    }

}

string printInstructions(const int[] arr) pure
{
    return printInstructions(arr.ptr, cast(uint) arr.length);
}

string printInstructions(const int* startInstructions, uint length) pure
{

    string result = "StartInstructionDump: \n";
    uint pos = 0;
    import std.conv;

    bool has4ByteOffset;
    if (length > 4 && startInstructions[0 .. 4] == [0, 0, 0, 0])
    {
        has4ByteOffset = true;
        //length -= 4;
        //startInstructions += 4;
        //pos += 4;
    }

    result ~= "Length : " ~ to!string(length) ~ "\n";
    auto arr = startInstructions[0 .. length];

    while (length--)
    {
        uint lw = arr[pos];
        result ~= pos.to!string ~ ":\t";
        ++pos;
        if (lw == 0)
        {
            result ~= "0x0 0x0 0x0 0x0\n";
            continue;
        }

        // We have a long instruction

        --length;
        uint hi = arr[pos++];

        final switch (cast(LongInst)(lw & InstMask))
        {
        case LongInst.ImmSetHigh:
            {
                result ~= "SetHigh SP[" ~ to!string(lw >> 16) ~ "], #" ~ to!string(hi) ~ "\n";
            }
            break;

        case LongInst.ImmSet:
            {
                result ~= "Set SP[" ~ to!string(lw >> 16) ~ "], #" ~ to!string(hi) ~ "\n";
            }
            break;

        case LongInst.ImmAdd:
            {
                result ~= "Add SP[" ~ to!string(lw >> 16) ~ "], #" ~ to!string(hi) ~ "\n";
            }
            break;
        case LongInst.ImmSub:
            {
                result ~= "Sub SP[" ~ to!string(lw >> 16) ~ "], #" ~ to!string(hi) ~ "\n";
            }
            break;
        case LongInst.ImmMul:
            {
                result ~= "Mul SP[" ~ to!string(lw >> 16) ~ "], #" ~ to!string(hi) ~ "\n";
            }
            break;
        case LongInst.ImmDiv:
            {
                result ~= "Div SP[" ~ to!string(lw >> 16) ~ "], #" ~ to!string(hi) ~ "\n";
            }
            break;

        case LongInst.ImmAnd:
            {
                result ~= "And SP[" ~ to!string(lw >> 16) ~ "], #" ~ to!string(hi) ~ "\n";
            }
            break;
        case LongInst.ImmOr:
            {
                result ~= "Or SP[" ~ to!string(lw >> 16) ~ "], #" ~ to!string(hi) ~ "\n";
            }
            break;
        case LongInst.ImmXor:
            {
                result ~= "Xor SP[" ~ to!string(lw >> 16) ~ "], #" ~ to!string(hi) ~ "\n";
            }
            break;
        case LongInst.ImmLsh:
            {
                result ~= "Lsh SP[" ~ to!string(lw >> 16) ~ "], #" ~ to!string(hi) ~ "\n";
            }
            break;
        case LongInst.ImmRsh:
            {
                result ~= "Rsh SP[" ~ to!string(lw >> 16) ~ "], #" ~ to!string(hi) ~ "\n";
            }
            break;

        case LongInst.ImmMod:
            {
                result ~= "Mod SP[" ~ to!string(lw >> 16) ~ "], #" ~ to!string(hi) ~ "\n";
            }
            break;

        case LongInst.ImmEq:
            {
                result ~= "Eq SP[" ~ to!string(lw >> 16) ~ "], #" ~ to!string(hi) ~ "\n";
            }
            break;
        case LongInst.ImmNeq:
            {
                result ~= "Neq SP[" ~ to!string(lw >> 16) ~ "], #" ~ to!string(hi) ~ "\n";
            }
            break;

        case LongInst.ImmLt:
            {
                result ~= "Lt SP[" ~ to!string(lw >> 16) ~ "], #" ~ to!string(hi) ~ "\n";
            }
            break;
        case LongInst.ImmGt:
            {
                result ~= "Gt SP[" ~ to!string(lw >> 16) ~ "], #" ~ to!string(hi) ~ "\n";
            }
            break;
        case LongInst.ImmLe:
            {
                result ~= "Le SP[" ~ to!string(lw >> 16) ~ "], #" ~ to!string(hi) ~ "\n";
            }
            break;
        case LongInst.ImmGe:
            {
                result ~= "Ge SP[" ~ to!string(lw >> 16) ~ "], #" ~ to!string(hi) ~ "\n";
            }
            break;

        case LongInst.Add:
            {
                result ~= "Add SP[" ~ to!string(hi & 0xFFFF) ~ "], SP[" ~ to!string(hi >> 16) ~ "]\n";
            }
            break;
        case LongInst.Sub:
            {
                result ~= "Sub SP[" ~ to!string(hi & 0xFFFF) ~ "], SP[" ~ to!string(hi >> 16) ~ "]\n";
            }
            break;
        case LongInst.Mul:
            {
                result ~= "Mul SP[" ~ to!string(hi & 0xFFFF) ~ "], SP[" ~ to!string(hi >> 16) ~ "]\n";
            }
            break;
        case LongInst.Div:
            {
                result ~= "Div SP[" ~ to!string(hi & 0xFFFF) ~ "], SP[" ~ to!string(hi >> 16) ~ "]\n";
            }
            break;
        case LongInst.And:
            {
                result ~= "And SP[" ~ to!string(hi & 0xFFFF) ~ "], SP[" ~ to!string(hi >> 16) ~ "]\n";
            }
            break;
        case LongInst.Or:
            {
                result ~= "Or SP[" ~ to!string(hi & 0xFFFF) ~ "], SP[" ~ to!string(hi >> 16) ~ "]\n";
            }
            break;
        case LongInst.Xor:
            {
                result ~= "Xor SP[" ~ to!string(hi & 0xFFFF) ~ "], SP[" ~ to!string(hi >> 16) ~ "]\n";
            }
            break;
        case LongInst.Lsh:
            {
                result ~= "Lsh SP[" ~ to!string(hi & 0xFFFF) ~ "], SP[" ~ to!string(hi >> 16) ~ "]\n";
            }
            break;
        case LongInst.Rsh:
            {
                result ~= "Rsh SP[" ~ to!string(hi & 0xFFFF) ~ "], SP[" ~ to!string(hi >> 16) ~ "]\n";
            }
            break;
        case LongInst.Mod:
            {
                result ~= "Mod SP[" ~ to!string(hi & 0xFFFF) ~ "], SP[" ~ to!string(hi >> 16) ~ "]\n";
            }
            break;
        case LongInst.Assert:
            {
                result ~= "Assert SP[" ~ to!string(hi & 0xFFFF) ~ "], ErrNo SP[" ~ to!string(
                    hi >> 16) ~ "]\n";
            }
            break;
        case LongInst.AssertCnd:
            {
                result ~= "AssertCnd ErrNo SP[" ~ to!string(hi >> 16) ~ "]]\n";
            }
            break;
        case LongInst.StrEq:
            {
                result ~= "StrEq SP[" ~ to!string(hi & 0xFFFF) ~ "], SP[" ~ to!string(hi >> 16) ~ "]\n";
            }
            break;
        case LongInst.StrCat:
            {
                result ~= "StrCat SP[" ~ to!string(hi & 0xFFFF) ~ "], SP[" ~ to!string(hi >> 16) ~ "]\n";
            }
            break;
        case LongInst.Eq:
            {
                result ~= "Eq SP[" ~ to!string(hi & 0xFFFF) ~ "], SP[" ~ to!string(hi >> 16) ~ "]\n";
            }
            break;
        case LongInst.Neq:
            {
                result ~= "Neq SP[" ~ to!string(hi & 0xFFFF) ~ "], SP[" ~ to!string(hi >> 16) ~ "]\n";
            }
            break;

        case LongInst.Set:
            {
                result ~= "Set SP[" ~ to!string(hi & 0xFFFF) ~ "], SP[" ~ to!string(hi >> 16) ~ "]\n";
            }
            break;

        case LongInst.Lt:
            {
                result ~= "Lt SP[" ~ to!string(hi & 0xFFFF) ~ "], SP[" ~ to!string(hi >> 16) ~ "]\n";
            }
            break;
        case LongInst.Gt:
            {
                result ~= "Gt SP[" ~ to!string(hi & 0xFFFF) ~ "], SP[" ~ to!string(hi >> 16) ~ "]\n";
            }
            break;
        case LongInst.Le:
            {
                result ~= "Le SP[" ~ to!string(hi & 0xFFFF) ~ "], SP[" ~ to!string(hi >> 16) ~ "]\n";
            }
            break;
        case LongInst.Ge:
            {
                result ~= "Ge SP[" ~ to!string(hi & 0xFFFF) ~ "], SP[" ~ to!string(hi >> 16) ~ "]\n";
            }
            break;

        case LongInst.Jmp:
            {
                result ~= "Jmp &" ~ to!string(hi) ~ "\n";
            }
            break;

        case LongInst.JmpFalse:
            {
                result ~= "JmpFalse &" ~ to!string((has4ByteOffset ? hi - 4 : hi)) ~ "\n";
            }
            break;
        case LongInst.JmpTrue:
            {
                result ~= "JmpTrue &" ~ to!string((has4ByteOffset ? hi - 4 : hi)) ~ "\n";
            }
            break;

        case LongInst.JmpNZ:
            {
                result ~= "JmpNZ SP[" ~ to!string(hi & 0xFFFF) ~ "], &" ~ to!string(
                    (has4ByteOffset ? (hi >> 16) - 4 : hi >> 16)) ~ "\n";
            }
            break;

        case LongInst.JmpZ:
            {
                result ~= "JmpZ SP[" ~ to!string(hi & 0xFFFF) ~ "], &" ~ to!string(
                    (has4ByteOffset ? (hi >> 16) - 4 : hi >> 16)) ~ "\n";
            }
            break;

        case LongInst.HeapLoad32:
            {
                result ~= "HeapLoad32 SP[" ~ to!string(hi & 0xFFFF) ~ "], HEAP[SP[" ~ to!string(
                    hi >> 16) ~ "]]\n";
            }
            break;

        case LongInst.HeapStore32:
            {
                result ~= "HeapStore32 HEAP[SP[" ~ to!string(hi & 0xFFFF) ~ "]], SP[" ~ to!string(
                    hi >> 16) ~ "]\n";
            }
            break;
        case LongInst.ExB:
            {
                result ~= "ExB SP[" ~ to!string(hi & 0xFFFF) ~ "], SP[" ~ to!string(hi >> 16) ~ "]\n";
            }
            break;
        case LongInst.Ret:
            {
                result ~= "Ret SP[" ~ to!string(lw >> 16) ~ "] \n";
            }
            break;
        case LongInst.RelJmp:
            {
                result ~= "RelJmp &" ~ to!string(cast(short)(lw >> 16) + (pos - 2)) ~ "\n";
            }
            break;
            /*case LongInst.Prt:
            {
                result ~= "Prt SP[" ~ to!string(lw >> 16) ~ "] \n";
            }
            break;*/
        case LongInst.Not:
            {
                result ~= "Not SP[" ~ to!string(lw >> 16) ~ "] \n";
            }
            break;

        case LongInst.Flg:
            {
                result ~= "Flg SP[" ~ to!string(lw >> 16) ~ "] \n";
            }
            break;
        case LongInst.Call:
            {
                result ~= "Call SP[" ~ to!string(hi & 0xFFFF) ~ "], SP[" ~ to!string(hi >> 16) ~ "]\n";
            }
            break;
        case LongInst.BuiltinCall:
            {
                result ~= "BuiltinCall Fn{" ~ to!string(lw >> 16) ~ "} (" ~ to!string(hi) ~ ")\n";
            }
            break;
        case LongInst.Alloc:
            {
                result ~= "Alloc SP[" ~ to!string(hi & 0xFFFF) ~ "] SP[" ~ to!string(hi >> 16) ~ "]\n";
            }
            break;
        }
    }
    return result ~ "\n EndInstructionDump";
}

static if (is(typeof(() { import ddmd.ctfe.ctfe_bc : RetainedError;  })))
{
    import ddmd.ctfe.ctfe_bc : RetainedError;

    alias RE = RetainedError;
}
else
{
    alias RE = void;
}

__gshared int[ushort.max * 2] byteCodeCache;
__gshared int byteCodeCacheTop = 4;
/*
BCValue interpret(const BCGen* gen, const BCValue[] args,
    BCFunction* functions = null, BCHeap* heapPtr = null, BCValue* ev1 = null,
    BCValue* ev2 = null, const RE* errors = null) @safe
{
    return interpret_(gen.byteCodeArray[0 .. gen.ip], args, heapPtr, functions, ev2,
        ev2, errors);
}
*/
const(BCValue) interpret_(const int[] byteCode, const BCValue[] args,
    BCHeap* heapPtr = null, const BCFunction* functions = null,
    const RetainedCall* calls = null,
    BCValue* ev1 = null, BCValue* ev2 = null, const RE* errors = null,
    long[] stackPtr = null, uint stackOffset = 0)  @trusted
{
    __gshared static uint callDepth;
    import std.conv;
    import std.stdio;

    if (!__ctfe)
    {
        debug writeln("Args: ", args, "BC:", byteCode.printInstructions);
    }
    auto stack = stackPtr ? stackPtr : new long[](ushort.max / 4);

    // first push the args on
    debug (bc)
        if (!__ctfe)
        {
            import std.stdio;

            writeln("before pushing args");
        }
    long* stackP = &stack[0] + (stackOffset / 4);

    size_t argOffset = 4;
    foreach (arg; args)
    {
        switch (arg.type.type)
        {
        case BCTypeEnum.i32:
            {
                *(stackP + argOffset / 4) = arg.imm32;
                argOffset += uint.sizeof;
            }
            break;
        case BCTypeEnum.i64:
            {
                *(stackP + argOffset / 4) = arg.imm64;
                argOffset += uint.sizeof;
                //TODO find out why adding ulong.sizeof does not work here
                //make variable-sized stack possible ... if it should be needed

            }
            break;
        case BCTypeEnum.Struct, BCTypeEnum.String, BCTypeEnum.Array, BCTypeEnum.Ptr:
            {
                // This might need to be removed agaein ?
                *(stackP + argOffset / 4) = arg.heapAddr.addr;
                argOffset += uint.sizeof;
            }
            break;
        default:
            //return -1;
            //       assert(0, "unsupported Type " ~ to!string(arg.type));
        }
    }
    uint ip = 4;
    bool cond;

    BCValue returnValue;

    // debug(bc) { import std.stdio; writeln("BC.len = ", byteCode.length); }
    if (byteCode.length < 6 || byteCode.length <= ip)
        return typeof(return).init;

    if (!__ctfe) debug writeln("Interpreter started");
    while (true && ip <= byteCode.length - 1)
    {
        import std.range;

        debug (bc_stack)
            foreach (si; 0 .. stackOffset + 32)
            {
                if (!__ctfe)
                {
                    printf("StackIndex %d, Content %x\t".ptr, si, stack[cast(uint) si]);
                    printf("HeapIndex %d, Content %x\n".ptr, si, heapPtr._heap[cast(uint) si]);
                }
            }

        const lw = byteCode[ip];
        const hi = byteCode[ip + 1];
        ip += 2;

        // consider splitting the stackPointer in stackHigh and stackLow

        const uint opRefOffset = (lw >> 16) & 0xFFFF;
        const uint lhsOffset = hi & 0xFFFF;
        const uint rhsOffset = (hi >> 16) & 0xFFFF;

        auto lhsRef = (stackP + (lhsOffset / 4));
        auto rhs = (stackP + (rhsOffset / 4));
        auto lhsStackRef = (stackP + (opRefOffset / 4));
        auto opRef = stackP + (opRefOffset / 4);

        if (!lw)
        { // Skip NOPS
            continue;
        }

        final switch (cast(LongInst)(lw & InstMask))
        {
        case LongInst.ImmAdd:
            {
                (*lhsStackRef) += hi;
            }
            break;

        case LongInst.ImmSub:
            {
                (*lhsStackRef) -= hi;
            }
            break;

        case LongInst.ImmMul:
            {
                (*lhsStackRef) *= hi;
            }
            break;

        case LongInst.ImmDiv:
            {
                (*lhsStackRef) /= hi;
            }
            break;

        case LongInst.ImmAnd:
            {
                (*lhsStackRef) &= hi;
            }
            break;
        case LongInst.ImmOr:
            {
                (*lhsStackRef) |= hi;
            }
            break;

        case LongInst.ImmXor:
            {
                (*lhsStackRef) ^= hi;
            }
            break;

        case LongInst.ImmLsh:
            {
                (*lhsStackRef) <<= hi;
            }
            break;
        case LongInst.ImmRsh:
            {
                (*lhsStackRef) >>>= hi;
            }
            break;

        case LongInst.ImmMod:
            {
                (*lhsStackRef) %= hi;
            }
            break;

        case LongInst.ImmSet:
            {
                (*lhsStackRef) = hi;
            }
            break;
        case LongInst.ImmSetHigh:
            {
                *lhsStackRef = (*lhsStackRef & 0x00_00_00_00_FF_FF_FF_FF) | (ulong(hi) << 32UL);
            }
            break;
        case LongInst.ImmEq:
            {
                if ((*lhsStackRef) == hi)
                {
                    cond = true;
                }
                else
                {
                    cond = false;
                }
            }
            break;
        case LongInst.ImmNeq:
            {
                if ((*lhsStackRef) != hi)
                {
                    cond = true;
                }
                else
                {
                    cond = false;
                }
            }
            break;
        case LongInst.ImmLt:
            {
                if ((*lhsStackRef) < hi)
                {
                    cond = true;
                }
                else
                {
                    cond = false;
                }
            }
            break;
        case LongInst.ImmGt:
            {
                if ((*lhsStackRef) > hi)
                {
                    cond = true;
                }
                else
                {
                    cond = false;
                }
            }
            break;
        case LongInst.ImmLe:
            {
                if ((*lhsStackRef) <= hi)
                {
                    cond = true;
                }
                else
                {
                    cond = false;
                }

            }
            break;
        case LongInst.ImmGe:
            {
                if ((*lhsStackRef) >= hi)
                {
                    cond = true;
                }
                else
                {
                    cond = false;
                }

            }
            break;

        case LongInst.Add:
            {
                (*lhsRef) += *rhs;
            }
            break;
        case LongInst.Sub:
            {
                (*lhsRef) -= *rhs;
            }
            break;
        case LongInst.Mul:
            {
                (*lhsRef) *= *rhs;
            }
            break;
        case LongInst.Div:
            {
                (*lhsRef) /= *rhs;
            }
            break;
        case LongInst.And:
            {
                (*lhsRef) &= *rhs;
            }
            break;
        case LongInst.Or:
            {
                (*lhsRef) |= *rhs;
            }
            break;
        case LongInst.Xor:
            {
                (*lhsRef) ^= hi;
            }
            break;

        case LongInst.Lsh:
            {
                (*lhsRef) <<= *rhs;
            }
            break;
        case LongInst.Rsh:
            {
                (*lhsRef) >>>= *rhs;
            }
            break;
        case LongInst.Mod:
            {
                (*lhsRef) %= *rhs;
            }
            break;
        case LongInst.Assert:
            {
                if (*lhsRef == 0)
                {
                    BCValue retval = imm32((*rhs) & uint.max);
                    retval.vType = BCValueType.Error;

                    static if (is(RetainedError))
                    {
                        if (*rhs - 1 < ubyte.sizeof * 4)
                        {
                            auto err = errors[cast(uint)(*rhs - 1)];
                            if (err.v1.vType != BCValueType.Immediate)
                            {
                                *ev1 = imm32(stackP[err.v1.toUint / 4] & uint.max);
                            }
                            else
                            {
                                *ev1 = err.v1;
                            }

                            if (err.v2.vType != BCValueType.Immediate)
                            {
                                *ev2 = imm32(stackP[err.v2.toUint / 4] & uint.max);
                            }
                            else
                            {
                                *ev2 = err.v2;
                            }
                        }
                    }
                    return retval;

                }
            }
            break;
        case LongInst.AssertCnd:
            {
                if (!cond)
                {
                    BCValue retval = imm32((*rhs) & uint.max);
                    retval.vType = BCValueType.Error;
                    static if (is(RetainedError))
                    {
                        if (*rhs - 1 < ubyte.sizeof * 4)
                        {
                            auto err = errors[cast(uint)(*rhs - 1)];
                            if (err.v1.vType != BCValueType.Immediate)
                            {
                                *ev1 = imm32(stackP[err.v1.toUint / 4] & uint.max);
                            }
                            else
                            {
                                *ev1 = err.v1;
                            }

                            if (err.v2.vType != BCValueType.Immediate)
                            {
                                *ev2 = imm32(stackP[err.v2.toUint / 4] & uint.max);
                            }
                            else
                            {
                                *ev2 = err.v2;
                            }
                        }
                    }
                    return retval;
                }
            }
            break;
        case LongInst.Eq:
            {
                if ((*lhsRef) == *rhs)
                {
                    cond = true;
                }
                else
                {
                    cond = false;
                }

            }
            break;

        case LongInst.Neq:
            {
                if ((*lhsRef) != *rhs)
                {
                    cond = true;
                }
                else
                {
                    cond = false;
                }
            }
            break;

        case LongInst.Set:
            {
                (*lhsRef) = *rhs;
            }
            break;

        case LongInst.Lt:
            {
                if ((*lhsRef) < *rhs)
                {
                    cond = true;
                }
                else
                {
                    cond = false;
                }

            }
            break;
        case LongInst.Gt:
            {
                if ((*lhsRef) > *rhs)
                {
                    cond = true;
                }
                else
                {
                    cond = false;
                }

            }
            break;
        case LongInst.Le:
            {
                if ((*lhsRef) <= *rhs)
                {
                    cond = true;
                }
                else
                {
                    cond = false;
                }

            }
            break;
        case LongInst.Ge:
            {
                if ((*lhsRef) >= *rhs)
                {
                    cond = true;
                }
                else
                {
                    cond = false;
                }

            }
            break;

        case LongInst.Jmp:
            {
                ip = hi;
            }
            break;
        case LongInst.JmpNZ:
            {
                if ((*lhsRef) != 0)
                {
                    ip = rhsOffset;
                }
            }
            break;
        case LongInst.JmpZ:
            {
                if ((*lhsRef) == 0)
                {
                    ip = rhsOffset;
                }
            }
            break;
        case LongInst.JmpFalse:
            {
                if (!cond)
                {
                    ip = (hi);
                }
            }
            break;
        case LongInst.JmpTrue:
            {
                if (cond)
                {
                    ip = (hi);
                }
            }
            break;

        case LongInst.HeapLoad32:
            {
                assert(*rhs, "trying to deref null pointer");
                (*lhsRef) = *(heapPtr._heap.ptr + *rhs);
                debug(bc)
                {
                    import std.stdio;
                    writeln("Loaded[",*rhs,"] = ",*lhsRef);
                }
            }
            break;
        case LongInst.HeapStore32:
            {
                assert(*lhsRef, "trying to deref null pointer SP[" ~ to!string((lhsRef - stackP)*4) ~ "] at : &" ~ to!string (ip - 2));
                (*(heapPtr._heap.ptr + *lhsRef)) = (*rhs) & 0xFF_FF_FF_FF;
            }
            break;
        case LongInst.ExB:
            {
                final switch ((*rhs) & 3)
                {
                case 0:
                    (*lhsRef) = (*lhsRef) & 0xFF;
                    break;
                case 1:
                    (*lhsRef) = ((*lhsRef) >> 8) & 0xFF;
                    break;
                case 2:
                    (*lhsRef) = ((*lhsRef) >> 16) & 0xFF;
                    break;
                case 3:
                    (*lhsRef) = ((*lhsRef) >> 24) & 0xFF;
                    break;
                }
            }
            break;
        case LongInst.Ret:
            {
                debug (bc)
                    if (!__ctfe)
                    {
                        import std.stdio;

                        writeln("Ret SP[", lhsOffset, "] (", *opRef, ")\n");
                    }
                return imm32(*opRef & uint.max);
            }

        case LongInst.RelJmp:
            {
                ip += (cast(short)(lw >> 16)) - 2;
            }
            break;
        case LongInst.Not:
            {
                (*opRef) = ~(*opRef);
            }
            break;
        case LongInst.Flg:
            {
                (*opRef) = cond;
            }
            break;

        case LongInst.BuiltinCall:
            {
                assert(0, "Unsupported right now: BCBuiltin");
            }
        case LongInst.Call:
            {
                assert(functions, "When calling functions you need functions to call");
                auto call = calls[uint((*rhs & uint.max)) - 1];

                auto fn = (call.fn.vType == BCValueType.Immediate ?
                    call.fn.imm32 :
                    (stackP[call.fn.stackAddr.addr / 4] & uint.max)
                    );
                auto stackOffsetCall = stackOffset + call.callerSp;
                if (!__ctfe)
                {
                    debug writeln("call.fn = ", call.fn);
                    debug writeln("fn = ", fn);
                    debug writeln((functions + fn - 1).byteCode.printInstructions);
                    debug writeln("stackOffsetCall: ", stackOffsetCall);
                }

                BCValue[16] callArgs = void;

                foreach(i,ref arg;call.args)
                {
                    if(isStackValueOrParameter(arg))
                    {
                        assert(stackP[arg.stackAddr.addr / 4] <= uint.max, "64bit argument would be truncated");
                        callArgs[i] = imm32(stackP[arg.stackAddr.addr / 4] & uint.max);
                    }
                    else if (arg.vType == BCValueType.Immediate)
                    {
                        callArgs[i] = arg;
                    }
                    else
                    {
                        import ddmd.declaration : FuncDeclaration;
                        import core.stdc.string : strlen;
                        const string fnString = cast(string)(cast(FuncDeclaration)functions[cast(size_t)(fn - 1)].funcDecl).ident.toString;

                        assert(0, "Argument " ~ to!string(i) ~" ValueType unhandeled: " ~ to!string(arg.vType) ~"\n Calling Function: " ~ fnString ~ " from: " ~ call.loc.toChars[0 .. strlen(call.loc.toChars)]);
                    }
                }
                if (callDepth++ == 2000)
                {
                        BCValue bailoutValue;
                        bailoutValue.vType = BCValueType.Bailout;
                        bailoutValue.imm32 = 2000;
                        return bailoutValue;
                }
                auto cRetval = interpret_(functions[cast(size_t)(fn - 1)].byteCode,
                    callArgs[0 .. call.args.length], heapPtr, functions, calls, ev1, ev2, errors, stack, stackOffsetCall);

                if (cRetval.vType == BCValueType.Error || cRetval.vType == BCValueType.Bailout)
                {
                    return cRetval;
                }
                *lhsRef = cRetval.imm32;
                callDepth--;
            }
            break;
        case LongInst.Alloc:
            {
                if (heapPtr.heapSize + *rhs < heapPtr.heapMax)
                {
                    *lhsRef = heapPtr.heapSize;
                    heapPtr.heapSize += *rhs;
                }
                else
                {
                    assert(0, "HEAP OVERFLOW!");
                }
            }
            break;
        case LongInst.StrEq:
            {
                auto _lhs = cast(uint)*lhsRef;
                auto _rhs = cast(uint)*rhs;

                assert(_lhs && _rhs, "trying to deref nullPointers");
                if (_lhs == _rhs)
                {
                    cond = true;
                }
                else
                {
                    auto lhsLength = heapPtr._heap[_lhs++];
                    auto rhsLength = heapPtr._heap[_rhs++];
                    if (lhsLength == rhsLength)
                    {
                        cond = true;
                        foreach (i; 0 .. align4(lhsLength) / 4)
                        {
                            if (heapPtr._heap[_lhs + i] != heapPtr._heap[_rhs + i])
                            {
                                cond = false;
                                break;
                            }
                        }
                    }
                }
            }
            break;
        case LongInst.StrCat:
            {
                auto _lhs = cast(uint)*lhsRef;
                auto _rhs = cast(uint)*rhs;

                assert(_lhs && _rhs, "trying to deref nullPointers");
                assert(_lhs != _rhs);
                auto result = &heapPtr._heap[0] + _lhs;
                auto b = &heapPtr._heap[0] + _rhs;
                uint bi = 1;
                auto lhsLength = heapPtr._heap[_lhs];
                auto rhsLength = heapPtr._heap[_rhs++];
                auto cLength = lhsLength + rhsLength;
                heapPtr._heap[_lhs++] = cLength;
                auto bDollar = (align4(rhsLength) / 4);
                auto resultPosition = (align4(lhsLength) / 4) + 1;
                auto end = resultPosition + bDollar;
                auto offset = lhsLength & 3;

                if (offset)
                {
                    auto OffsetTimesEight = offset * 8;
                    auto FourMinusOffsetTimesEight = (4 - offset) * 8;
                    auto FirstAnd = (1 << FourMinusOffsetTimesEight) - 1;
                    auto SecondAnd = (~FirstAnd) & uint.max;

                    resultPosition--;
                    for (uint cb = b[bi]; bi != bDollar; bi++)
                    {
                        result[resultPosition++] |= (cb & FirstAnd) << OffsetTimesEight;
                        if (resultPosition == end)
                            break;
                        result[resultPosition] |= (cb & SecondAnd) >> FourMinusOffsetTimesEight;
                    }
                }
                else
                {
                    for (uint cb = b[bi]; bi != bDollar; bi++)
                    {
                        result[resultPosition++] = cb;
                    }
                }
            }
            break;

        }
    }
    Lbailout :
    BCValue bailoutValue;
    bailoutValue.vType = BCValueType.Bailout;
    return bailoutValue;

    debug (cttfe)
    {
        assert(0, "I would be surprised if we got here -- withBC: " ~ byteCode.printInstructions);
    }
}

int[] testRelJmp()
{
    BCGen gen;
    with (gen)
    {
        Initialize();
        auto result = genTemporary(i32Type);
        Set(result, BCValue(Imm32(2)));
        auto evalCond = genLabel();
        Eq3(BCValue.init, result, BCValue(Imm32(12)));
        auto cndJmp = beginCndJmp();
        Ret(result);
        endCndJmp(cndJmp, genLabel());
        Add3(result, result, BCValue(Imm32(1)));
        genJump(evalCond);
        Finalize();
        return byteCodeArray[0 .. ip].dup;
    }
}

static assert(interpret_(testRelJmp(), []) == BCValue(Imm32(12)));
import bc_test;

static assert(test!BCGen());
