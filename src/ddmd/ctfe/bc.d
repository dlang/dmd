module ddmd.ctfe.bc;
import ddmd.ctfe.bc_common;
import ddmd.ctfe.bc_limits;
import core.stdc.stdio;
import std.conv;

/**
 * Written By Stefan Koch in 2016/17
 */
debug = 0;
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
            LongInst.SetHighImm:
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
    Ret32,
    Ret64,
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
    Mod,
    Eq, //sets condflags
    Neq, //sets condflag
    Lt, //sets condflags
    Le,
    Gt, //sets condflags
    Ge,
    Set,
    And,
    And32,
    Or,
    Xor,
    Xor32,
    Lsh,
    Rsh,

    StrEq,
    Assert,

    // Immedate operand
    ImmAdd,
    ImmSub,
    ImmDiv,
    ImmMul,
    ImmMod,
    ImmEq,
    ImmNeq,
    ImmLt,
    ImmLe,
    ImmGt,
    ImmGe,
    ImmSet,
    ImmAnd,
    ImmAnd32,
    ImmOr,
    ImmXor,
    ImmXor32,
    ImmLsh,
    ImmRsh,

    FAdd32,
    FSub32,
    FDiv32,
    FMul32,
    FMod32,
    FEq32,
    FNeq32,
    FLt32,
    FLe32,
    FGt32,
    FGe32,
    F32ToF64,
    F32ToI,
    IToF32,

    FAdd64,
    FSub64,
    FDiv64,
    FMul64,
    FMod64,
    FEq64,
    FNeq64,
    FLt64,
    FLe64,
    FGt64,
    FGe64,
    F64ToF32,
    F64ToI,
    IToF64,

    SetHighImm,

    Call,
    HeapLoad32, ///SP[hi & 0xFFFF] = Heap[align4(SP[hi >> 16])]
    HeapStore32, ///Heap[align4(SP[hi & 0xFFFF)] = SP[hi >> 16]]
    HeapLoad64,
    HeapStore64,
    Alloc, /// SP[hi & 0xFFFF] = heapSize; heapSize += SP[hi >> 16]
    MemCpy,

    BuiltinCall, // call a builtin.
    Cat,
    Comment,
    Line,

}
//Imm-Intructuins and corrospinding 2Operand instructions have to be in the same order
static immutable bc_order_errors = () {
    string result;
    auto members = [__traits(allMembers, LongInst)];
    auto d1 = LongInst.ImmAdd - LongInst.Add;
    auto d2 = LongInst.ImmMod - LongInst.Mod;
    if (d1 != d2)
    {
        result ~= "mismatch between ImmAdd - Add and ImmMod-Mod\nThis indicates Imm insts that do not corrospond to 2stack insts";
    }

    foreach (i, member; members)
    {
        if (member.length > 3 && member[0 .. 3] == "Imm" && members[i - d1] != member[3 .. $])
        {
            result ~= "\nError: " ~ member ~ " should match to: " ~ member[3 .. $]
                ~ "; but it matches to: " ~ members[i - d1];
        }
    }
    return result;
} ();

static assert(!bc_order_errors.length, bc_order_errors);


pragma(msg, 2 ^^ 7 - LongInst.max, " opcodes remaining");
static assert(LongInst.ImmAdd - LongInst.Add == LongInst.ImmRsh - LongInst.Rsh);
static assert(LongInst.ImmAnd - LongInst.And == LongInst.ImmMod - LongInst.Mod);

enum InstMask = ubyte(0x7F); // mask for bit 0-6
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
* [0-7] Instruction
* [7-8] Flags
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
@safe pure const nothrow:
    this(const LongInst i, const BCAddr targetAddr)
    {
        lw = i;
        hi = targetAddr.addr;
    }

    this(const LongInst i, const StackAddr stackAddrLhs, const BCAddr targetAddr)
    {
        lw = i | stackAddrLhs.addr << 16;
        hi = targetAddr.addr;
    }

    this(const LongInst i, const StackAddr stackAddrLhs,
        const StackAddr stackAddrRhs)
    {
        lw = i;
        hi = stackAddrLhs.addr | stackAddrRhs.addr << 16;
    }

    this(const LongInst i, const StackAddr stackAddrLhs, const Imm32 rhs)
    {
        lw = i | stackAddrLhs.addr << 16;
        hi = rhs.imm32;
    }

    this(const LongInst i, const StackAddr stackAddrOp,
        const StackAddr stackAddrLhs, const StackAddr stackAddrRhs)
    {
        lw = i | stackAddrOp.addr << 16;
        hi = stackAddrLhs.addr | stackAddrRhs.addr << 16;
    }

}

static assert(LongInst.max < 0x7F, "Instruction do not fit in 7 bit anymore");

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

auto ShortInst16(const LongInst i, const int _imm) pure @safe
{
    short imm = cast(short) _imm;
    return i | imm << 16;
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

    immutable(int)[] byteCode;

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
    int[ushort.max] byteCodeArray;

    /// ip starts at 4 because 0 should be an invalid address;
    BCAddr ip = BCAddr(4);
    StackAddr sp = StackAddr(4);
    ubyte parameterCount;
    ushort localCount;
    ushort temporaryCount;
    uint functionId;
    void* fd;
    bool insideFunction;

    BCLocal[bc_max_locals] locals;

    RetainedCall[ubyte.max * 6] calls;
    uint callCount;
    auto interpret(BCValue[] args, BCHeap* heapPtr = null) const
    {
        return interpret_(cast(const) byteCodeArray[0 .. ip], args, heapPtr, null);
    }

@safe:

    string[ushort] stackMap()
    {
        string[ushort] result;
        foreach(local;locals[0 .. localCount])
        {
            result[local.addr] = local.name;
        }
        return result;
    }

    void beginFunction(uint fnId = 0, void* fd = null)
    {
        import ddmd.declaration : FuncDeclaration;
        import std.string;
        ip = BCAddr(4);
        //() @trusted { assert(!insideFunction, fd ? (cast(FuncDeclaration)fd).toChars.fromStringz : "fd:null"); } ();
        //TODO figure out why the above assert cannot always be true ... see issue 7667
        insideFunction = true;
        functionId = fnId;
    }

pure:
    /// The emitLongInst functions have be kept up to date if
    /// LongInst64 is changed.
    void emitLongInst(const LongInst i, const BCAddr targetAddr)
    {
        byteCodeArray[ip] = i;
        byteCodeArray[ip + 1] = targetAddr.addr;
        ip += 2;
    }

    void emitLongInst(const LongInst i, const StackAddr stackAddrLhs, const BCAddr targetAddr)
    {
        byteCodeArray[ip] = i | stackAddrLhs.addr << 16;
        byteCodeArray[ip + 1] = targetAddr.addr;
        ip += 2;
    }

    void emitLongInst(const LongInst i, const StackAddr stackAddrLhs,
        const StackAddr stackAddrRhs)
    {
        byteCodeArray[ip] = i;
        byteCodeArray[ip + 1] = stackAddrLhs.addr | stackAddrRhs.addr << 16;
        ip += 2;
    }

    void emitLongInst(const LongInst i, const StackAddr stackAddrLhs, const Imm32 rhs)
    {
        byteCodeArray[ip] = i | stackAddrLhs.addr << 16;
        byteCodeArray[ip + 1] = rhs.imm32;
        ip += 2;
    }

    void emitLongInst(const LongInst i, const StackAddr stackAddrOp,
        const StackAddr stackAddrLhs, const StackAddr stackAddrRhs)
    {
        byteCodeArray[ip] = i | stackAddrOp.addr << 16;
        byteCodeArray[ip + 1] = stackAddrLhs.addr | stackAddrRhs.addr << 16;
        ip += 2;
    }

    BCValue genTemporary(BCType bct)
    {
        auto tmpAddr = sp.addr;
        if (isBasicBCType(bct))
        {
            sp += align4(basicTypeSize(bct.type));
        }
        else
        {
            sp += 4;
        }

        return BCValue(StackAddr(tmpAddr), bct, ++temporaryCount);
    }

    extern (D) BCValue genLocal(BCType bct, string name)
    {
        auto localAddr = sp.addr;
        ushort localIdx = ++localCount;

        if (isBasicBCType(bct))
        {
            sp += align4(basicTypeSize(bct.type));
        }
        else
        {
            sp += 4;
        }

        string localName = name ? name : null;

        locals[localIdx - 1] = BCLocal(localIdx, bct, StackAddr(localAddr), localName);

        return BCValue(StackAddr(localAddr), bct, localIdx, localName);
    }

    void Initialize()
    {
        callCount = 0;
        parameterCount = 0;
        temporaryCount = 0;
        localCount = 0;
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

    BCFunction endFunction()
    {
        //assert(insideFunction);
        //I have no idea how this can fail ...

        insideFunction = false;
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

    BCValue genParameter(BCType bct, string name = null)
    {
        auto p = BCValue(BCParameter(++parameterCount, bct, sp));
        p.name = name;
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
        auto offset = isShortJump(target.addr - atIp);
        if (offset)
        {
            byteCodeArray[atIp] = ShortInst16(LongInst.RelJmp, offset);
        }
        else
        {
            byteCodeArray[atIp] = LongInst.Jmp;
            byteCodeArray[atIp + 1] = target.addr;
        }
    }

    BCLabel genLabel()
    {
        return BCLabel(ip);
    }

    CndJmpBegin beginCndJmp(BCValue cond = BCValue.init, bool ifTrue = false)
    {
        if (cond.vType == BCValueType.Immediate)
        {
            cond = pushOntoStack(cond);
        }

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

        if (isStackValueOrParameter(cond))
        {
            lj = (ifTrue ? LongInst64(LongInst.JmpNZ, cond.stackAddr,
                target.addr) : LongInst64(LongInst.JmpZ, cond.stackAddr, target.addr));
        }
        else // if (cond == bcLastCond)
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
        assert(isStackValueOrParameter(lhs), "Can only store flags in Stack Values");
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

        emitLongInst(LongInst.Alloc, heapPtr.stackAddr, size.stackAddr);
    }

    void Assert(BCValue value, BCValue err)
    {
        BCValue _msg;
        if (isStackValueOrParameter(err))
        {
            assert(0, "err.vType is not Error but: " ~ err.vType.to!string);
        }

        if (value)
        {
            emitLongInst(LongInst.Assert, pushOntoStack(value).stackAddr, err.imm32);
        }
        else
        {
            assert(0, "BCValue.init is no longer a valid value for assert");
        }

    }

    void MemCpy(BCValue dst, BCValue src, BCValue size)
    {
        size = pushOntoStack(size);
        src = pushOntoStack(src);
        dst = pushOntoStack(dst);

        emitLongInst(LongInst.MemCpy, size.stackAddr, dst.stackAddr, src.stackAddr);
    }

    void Line(uint line)
    {
        emitLongInst(LongInst.Line, StackAddr(0), Imm32(line));
    }

    void Comment(string comment)
    {
        debug
        {
        uint alignedLength = align4(cast(uint) comment.length) / 4;
        uint commentLength = cast(uint) comment.length;

        emitLongInst(LongInst.Comment, StackAddr.init, Imm32(commentLength));
        uint idx;
        while(commentLength >= 4)
        {
            byteCodeArray[ip++] = comment[idx] | comment[idx+1] << 8 | comment[idx+2] << 16 | comment[idx+3] << 24;
            idx += 4;
            commentLength -= 4;
        }

        switch(commentLength)
        {
            case 3 :
                byteCodeArray[ip] |= comment[idx+2] << 24;
            goto case;
            case 2 :
                byteCodeArray[ip] |= comment[idx+1] << 16;
            goto case;
            case 1 :
                 byteCodeArray[ip++] |= comment[idx] << 8;
            goto case;
            case 0 :
            break;
            default : assert(0);
        }
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

    void emitArithInstruction(LongInst inst, BCValue lhs, BCValue rhs, BCTypeEnum* resultTypeEnum = null)
    {
        assert(inst >= LongInst.Add && inst < LongInst.ImmAdd,
            "Instruction is not in Range for Arith Instructions");
        assert(lhs.vType.StackValue, "only StackValues are supported as lhs");

        BCTypeEnum commonType = commonTypeEnum(lhs.type.type, rhs.type.type);

        // FIXME remove the lhs.type == BCTypeEnum.Char as soon as we convert correctly.
        assert(commonType == BCTypeEnum.i32 || commonType == BCTypeEnum.i64
            || commonType == BCTypeEnum.f23 || commonType == BCTypeEnum.Char
            || commonType == BCTypeEnum.c8  || commonType == BCTypeEnum.f52,
            "only i32, i64, f23, f52, is supported for now not: " ~ to!string(commonType));
        //assert(lhs.type.type == rhs.type.type, lhs.type.type.to!string ~ " != " ~ rhs.type.type.to!string);

        if (lhs.vType == BCValueType.Immediate)
        {
            lhs = pushOntoStack(lhs);
        }

        if (resultTypeEnum !is null)
            *resultTypeEnum = commonType;

        if (lhs.type.type == BCTypeEnum.f23)
        {
            if(rhs.type.type == BCTypeEnum.i32)
            {
                if (rhs.vType == BCValueType.Immediate)
                () @trusted {
                    float frhs = float(rhs.imm32);
                    rhs = imm32(*cast(int*)&frhs);
                } ();
                else
                    rhs = castTo(rhs, BCTypeEnum.f23);
            }
            else if (rhs.type.type == BCTypeEnum.f23)
            {
                rhs = pushOntoStack(rhs);
            }
            else
                assert(0, "did not expecte type " ~ to!string(rhs.type.type) ~ "to be used in a float expression");

            if (inst != LongInst.Set)
                inst += (LongInst.FAdd32 - LongInst.Add);
        }
        else if (lhs.type.type == BCTypeEnum.f52)
        {
            if(rhs.type.type != BCTypeEnum.f52)
            {
                // TOOD there was
                // assert (rhs.type.type == BCTypeEnum.f52)
                // here before .... check of this is an invariant
                rhs = castTo(rhs, BCTypeEnum.f52);
            }

            rhs = pushOntoStack(rhs);

            if (inst != LongInst.Set)
                inst += (LongInst.FAdd64 - LongInst.Add);
        }
        else if (rhs.vType == BCValueType.Immediate)
        {
            if  (basicTypeSize(rhs.type) <= 4)
            {
                //Change the instruction into the corrosponding Imm Instruction;
                inst += (LongInst.ImmAdd - LongInst.Add);
                emitLongInst(inst, lhs.stackAddr, rhs.imm32);
                return ;
            }
            else
            {
                rhs = pushOntoStack(rhs);
            }
        }

        if (isStackValueOrParameter(rhs))
        {
            emitLongInst(inst, lhs.stackAddr, rhs.stackAddr);
        }
        else
        {
            assert(0, "Cannot handle: " ~ to!string(rhs.vType));
        }
    }

    void Set(BCValue lhs, BCValue rhs)
    {
        assert(isStackValueOrParameter(lhs), "Set lhs is has to be a StackValue");
        assert(rhs.vType == BCValueType.Immediate || isStackValueOrParameter(rhs), "Set rhs is has to be a StackValue or Imm not: " ~ rhs.vType.to!string);

        if (rhs.vType == BCValueType.Immediate && (rhs.type.type == BCTypeEnum.i64 || rhs.type.type == BCTypeEnum.f52))
        {
            emitLongInst(LongInst.ImmSet, lhs.stackAddr, rhs.imm32);
            if (rhs.type.type != BCTypeEnum.i64 || rhs.imm64 > uint.max) // if there are high bits
                emitLongInst(LongInst.SetHighImm, lhs.stackAddr, Imm32(rhs.imm64 >> 32));
        }

        else if (lhs != rhs) // do not emit self asignments;
        {
            emitArithInstruction(LongInst.Set, lhs, rhs);
        }
    }

    void SetHigh(BCValue lhs, BCValue rhs)
    {
        assert(isStackValueOrParameter(lhs), "SeHigt lhs is has to be a StackValue");
        assert(rhs.vType == BCValueType.Immediate || isStackValueOrParameter(rhs), "SetHigh rhs is has to be a StackValue or Imm");

        //two cases :
        //    lhs.type.size == 4 && rhs.type.size == 8
        // OR
        //    lhs.type.size == 8 && rhs.type.size == 4

    }

    void Lt3(BCValue result, BCValue lhs, BCValue rhs)
    {
        assert(result.vType == BCValueType.Unknown
            || isStackValueOrParameter(result),
            "The result for this must be Empty or a StackValue");
        emitArithInstruction(LongInst.Lt, lhs, rhs);

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
        emitArithInstruction(LongInst.Le, lhs, rhs);

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
        emitArithInstruction(LongInst.Gt, lhs, rhs);
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
        emitArithInstruction(LongInst.Ge, lhs, rhs);
        if (isStackValueOrParameter(result))
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
        emitArithInstruction(LongInst.Neq, lhs, rhs);

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

        emitArithInstruction(LongInst.Add, result, rhs, &result.type.type);
    }

    void Sub3(BCValue result, BCValue lhs, BCValue rhs)
    {
        assert(result.vType != BCValueType.Immediate, "Cannot sub to Immediate");

        result = (result ? result : lhs);
        if (lhs != result)
        {
            Set(result, lhs);
        }

        emitArithInstruction(LongInst.Sub, result, rhs, &result.type.type);
    }

    void Mul3(BCValue result, BCValue lhs, BCValue rhs)
    {
        assert(result.vType != BCValueType.Immediate, "Cannot mul to Immediate");

        result = (result ? result : lhs);
        if (lhs != result)
        {
            Set(result, lhs);
        }

        emitArithInstruction(LongInst.Mul, result, rhs, &result.type.type);
    }

    void Div3(BCValue result, BCValue lhs, BCValue rhs)
    {
        assert(result.vType != BCValueType.Immediate, "Cannot div to Immediate");

        result = (result ? result : lhs);
        if (lhs != result)
        {
            Set(result, lhs);
        }
        emitArithInstruction(LongInst.Div, result, rhs, &result.type.type);
    }

    void And3(BCValue result, BCValue lhs, BCValue rhs)
    {
        assert(result.vType != BCValueType.Immediate, "Cannot and to Immediate");

        result = (result ? result : lhs);
        if (lhs != result)
        {
            Set(result, lhs);
        }
        if (lhs.type.type == BCTypeEnum.i32 && rhs.type.type == BCTypeEnum.i32)
            emitArithInstruction(LongInst.And32, result, rhs);
        else
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
        if (lhs.type.type == BCTypeEnum.i32 && rhs.type.type == BCTypeEnum.i32)
            emitArithInstruction(LongInst.Xor32, result, rhs);
        else
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
        emitArithInstruction(LongInst.Mod, result, rhs, &result.type.type);
    }

    import ddmd.globals : Loc;
    void Call(BCValue result, BCValue fn, BCValue[] args, Loc l = Loc.init)
    {
        calls[callCount++] = RetainedCall(fn, args, functionId, ip, sp, l);
        emitLongInst(LongInst.Call, result.stackAddr, pushOntoStack(imm32(callCount)).stackAddr);
    }

    void Load32(BCValue _to, BCValue from)
    {
        if (!isStackValueOrParameter(from))
        {
            from = pushOntoStack(from);
        }
        if (!isStackValueOrParameter(_to))
        {
            _to = pushOntoStack(_to);
        }
        assert(isStackValueOrParameter(_to), "to has the vType " ~ to!string(_to.vType));
        assert(isStackValueOrParameter(from), "from has the vType " ~ to!string(from.vType));

        emitLongInst(LongInst.HeapLoad32, _to.stackAddr, from.stackAddr);
    }

    void Store32(BCValue _to, BCValue value)
    {
        if (!isStackValueOrParameter(value))
        {
            value = pushOntoStack(value);
        }
        if (!isStackValueOrParameter(_to))

        {
            _to = pushOntoStack(_to);
        }

        assert(isStackValueOrParameter(_to), "to has the vType " ~ to!string(_to.vType));
        assert(isStackValueOrParameter(value), "value has the vType " ~ to!string(value.vType));

        emitLongInst(LongInst.HeapStore32, _to.stackAddr, value.stackAddr);
    }

    void Load64(BCValue _to, BCValue from)
    {
        if (!isStackValueOrParameter(from))
        {
            from = pushOntoStack(from);
        }
        if (!isStackValueOrParameter(_to))
        {
            _to = pushOntoStack(_to);
        }
        assert(isStackValueOrParameter(_to), "to has the vType " ~ to!string(_to.vType));
        assert(isStackValueOrParameter(from), "from has the vType " ~ to!string(from.vType));

        emitLongInst(LongInst.HeapLoad64, _to.stackAddr, from.stackAddr);
    }

    void Store64(BCValue _to, BCValue value)
    {
        if (!isStackValueOrParameter(value))
        {
            value = pushOntoStack(value);
        }
        if (!isStackValueOrParameter(_to))

        {
            _to = pushOntoStack(_to);
        }

        assert(isStackValueOrParameter(_to), "to has the vType " ~ to!string(_to.vType));
        assert(isStackValueOrParameter(value), "value has the vType " ~ to!string(value.vType));

        emitLongInst(LongInst.HeapStore64, _to.stackAddr, value.stackAddr);
    }


    BCValue castTo(BCValue rhs, BCTypeEnum targetType)
    {
        auto sourceType = rhs.type.type;

        if (sourceType == targetType)
            return rhs;

        auto lhs = genTemporary(BCType(targetType));

        assert(isStackValueOrParameter(rhs));

        switch(targetType) with (BCTypeEnum)
        {
            case f52 :
                if (sourceType == f23)
                    emitLongInst(LongInst.F32ToF64, lhs.stackAddr, rhs.stackAddr);
                else
                    emitLongInst(LongInst.IToF64, lhs.stackAddr, rhs.stackAddr);
            break;
            case f23 :
                if (sourceType == f52)
                    emitLongInst(LongInst.F64ToF32, lhs.stackAddr, rhs.stackAddr);
                else
                    emitLongInst(LongInst.IToF32, lhs.stackAddr, rhs.stackAddr);
            break;
            case i32,i64 :
                if (sourceType == f23)
                    emitLongInst(LongInst.F32ToI, lhs.stackAddr, rhs.stackAddr);
                else if (sourceType == f52)
                    emitLongInst(LongInst.F64ToI, lhs.stackAddr, rhs.stackAddr);
            break;
            default :
                debug{assert(0, "me no have no cast for targetType " ~ to!string(targetType));}
            break;
        }

        return lhs;
    }

    BCValue pushOntoStack(BCValue val)
    {
        if (!isStackValueOrParameter(val))
        {

            auto stackref = BCValue(currSp(), val.type);
            Set(stackref.i32, val);

            sp += align4(basicTypeSize(val.type.type));
            return stackref;
        }
        else
        {
            return val;
        }
    }

    void Ret(BCValue val)
    {
        LongInst inst = basicTypeSize(val.type) == 8 ? LongInst.Ret64 : LongInst.Ret32;
        val = pushOntoStack(val);
        if (isStackValueOrParameter(val))
        {
            byteCodeArray[ip] = ShortInst16(inst, val.stackAddr);
            byteCodeArray[ip + 1] = 0;
            ip += 2;
        }
        else
        {
                assert(0, "I cannot deal with this type of return" ~ to!string(val.vType));
        }
    }

    void IToF32(BCValue result, BCValue rhs)
    {
        assert(isStackValueOrParameter(result));
        assert(isStackValueOrParameter(rhs));

        emitLongInst(LongInst.IToF32, result.stackAddr, rhs.stackAddr);
    }

    void IToF64(BCValue result, BCValue rhs)
    {
        assert(isStackValueOrParameter(result));
        assert(isStackValueOrParameter(rhs));

        emitLongInst(LongInst.IToF64, result.stackAddr, rhs.stackAddr);
    }

    void StrEq3(BCValue result, BCValue lhs, BCValue rhs)
    {
        assert(result.vType == BCValueType.Unknown
            || isStackValueOrParameter(result),
            "The result for this must be Empty or a StackValue not: " ~ to!string(result.vType));
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

        emitLongInst(LongInst.StrEq, lhs.stackAddr, rhs.stackAddr);

        if (isStackValueOrParameter(result))
        {
            emitFlg(result);
        }
    }

    void Cat3(BCValue result, BCValue lhs, BCValue rhs, const uint size)
    {

        assert(size <= 255);

        assert(isStackValueOrParameter(result));

        lhs = pushOntoStack(lhs);
        rhs = pushOntoStack(rhs);
        emitLongInst(LongInst.Cat, result.stackAddr, lhs.stackAddr, rhs.stackAddr);
        // Hack! we have no overload to store additional information in the 8 bit
        // after the inst so just dump it in there let's hope we don't overwrite
        // anything important
        byteCodeArray[ip-2] |= (size & 255) << 8;

    }

}

string printInstructions(const int[] arr, const string[ushort] stackMap = null) pure
{
    return printInstructions(arr.ptr, cast(uint) arr.length, stackMap);
}
/*
string localName(const string[ushort] stackMap, uint addr) pure
{
    localName(stackMap, cast(ushort)addr);
}
*/
string localName(const string[ushort] stackMap, ushort addr) pure
{

    const(string)* name;
    if (stackMap)
    {
        name = addr in stackMap;
    }

    if (name && *name !is null)
    {
        return *name;
    }
    else
    {
        return "SP[" ~ to!string(addr) ~ "]";
    }
}

string printInstructions(const int* startInstructions, uint length, const string[ushort] stackMap = null) pure
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
        case LongInst.SetHighImm:
            {
                result ~= "SetHigh " ~ (stackMap ? localName(stackMap, lw >> 16) : "SP[" ~ to!string(lw >> 16)~"]" ) ~ ", #" ~ to!string(hi) ~ "\n";
            }
            break;

        case LongInst.ImmSet:
            {
                result ~= "Set " ~ (stackMap ? localName(stackMap, lw >> 16) : "SP[" ~ to!string(lw >> 16)~"]" ) ~ ", #" ~ to!string(hi) ~ "\n";
            }
            break;

        case LongInst.ImmAdd:
            {
                result ~= "Add " ~ (stackMap ? localName(stackMap, lw >> 16) : "SP[" ~ to!string(lw >> 16)~"]" ) ~ ", #" ~ to!string(hi) ~ "\n";
            }
            break;
        case LongInst.ImmSub:
            {
                result ~= "Sub " ~ (stackMap ? localName(stackMap, lw >> 16) : "SP[" ~ to!string(lw >> 16)~"]" ) ~ ", #" ~ to!string(hi) ~ "\n";
            }
            break;
        case LongInst.ImmMul:
            {
                result ~= "Mul " ~ (stackMap ? localName(stackMap, lw >> 16) : "SP[" ~ to!string(lw >> 16)~"]" ) ~ ", #" ~ to!string(hi) ~ "\n";
            }
            break;
        case LongInst.ImmDiv:
            {
                result ~= "Div " ~ (stackMap ? localName(stackMap, lw >> 16) : "SP[" ~ to!string(lw >> 16)~"]" ) ~ ", #" ~ to!string(hi) ~ "\n";
            }
            break;

        case LongInst.ImmAnd:
            {
                result ~= "And " ~ (stackMap ? localName(stackMap, lw >> 16) : "SP[" ~ to!string(lw >> 16)~"]" ) ~ ", #" ~ to!string(hi) ~ "\n";
            }
            break;
        case LongInst.ImmAnd32:
            {
                result ~= "And32 " ~ (stackMap ? localName(stackMap, lw >> 16) : "SP[" ~ to!string(lw >> 16)~"]" ) ~ ", #" ~ to!string(hi) ~ "\n";
            }
            break;
        case LongInst.ImmOr:
            {
                result ~= "Or " ~ (stackMap ? localName(stackMap, lw >> 16) : "SP[" ~ to!string(lw >> 16)~"]" ) ~ ", #" ~ to!string(hi) ~ "\n";
            }
            break;
        case LongInst.ImmXor:
            {
                result ~= "Xor " ~ (stackMap ? localName(stackMap, lw >> 16) : "SP[" ~ to!string(lw >> 16)~"]" ) ~ ", #" ~ to!string(hi) ~ "\n";
            }
            break;
        case LongInst.ImmXor32:
            {
                result ~= "Xor32 " ~ (stackMap ? localName(stackMap, lw >> 16) : "SP[" ~ to!string(lw >> 16)~"]" ) ~ ", #" ~ to!string(hi) ~ "\n";
            }
            break;
        case LongInst.ImmLsh:
            {
                result ~= "Lsh " ~ (stackMap ? localName(stackMap, lw >> 16) : "SP[" ~ to!string(lw >> 16)~"]" ) ~ ", #" ~ to!string(hi) ~ "\n";
            }
            break;
        case LongInst.ImmRsh:
            {
                result ~= "Rsh " ~ (stackMap ? localName(stackMap, lw >> 16) : "SP[" ~ to!string(lw >> 16)~"]" ) ~ ", #" ~ to!string(hi) ~ "\n";
            }
            break;

        case LongInst.ImmMod:
            {
                result ~= "Mod " ~ (stackMap ? localName(stackMap, lw >> 16) : "SP[" ~ to!string(lw >> 16)~"]" ) ~ ", #" ~ to!string(hi) ~ "\n";
            }
            break;

        case LongInst.ImmEq:
            {
                result ~= "Eq " ~ (stackMap ? localName(stackMap, lw >> 16) : "SP[" ~ to!string(lw >> 16)~"]" ) ~ ", #" ~ to!string(hi) ~ "\n";
            }
            break;
        case LongInst.ImmNeq:
            {
                result ~= "Neq " ~ (stackMap ? localName(stackMap, lw >> 16) : "SP[" ~ to!string(lw >> 16)~"]" ) ~ ", #" ~ to!string(hi) ~ "\n";
            }
            break;

        case LongInst.ImmLt:
            {
                result ~= "Lt " ~ (stackMap ? localName(stackMap, lw >> 16) : "SP[" ~ to!string(lw >> 16)~"]" ) ~ ", #" ~ to!string(hi) ~ "\n";
            }
            break;
        case LongInst.ImmGt:
            {
                result ~= "Gt " ~ (stackMap ? localName(stackMap, lw >> 16) : "SP[" ~ to!string(lw >> 16)~"]" ) ~ ", #" ~ to!string(hi) ~ "\n";
            }
            break;
        case LongInst.ImmLe:
            {
                result ~= "Le " ~ (stackMap ? localName(stackMap, lw >> 16) : "SP[" ~ to!string(lw >> 16)~"]" ) ~ ", #" ~ to!string(hi) ~ "\n";
            }
            break;
        case LongInst.ImmGe:
            {
                result ~= "Ge " ~ (stackMap ? localName(stackMap, lw >> 16) : "SP[" ~ to!string(lw >> 16)~"]" ) ~ ", #" ~ to!string(hi) ~ "\n";
            }
            break;

        case LongInst.Add:
            {
                result ~= "Add " ~ (stackMap ? localName(stackMap, hi & 0xFFFF) : "SP[" ~ to!string(hi & 0xFFFF)~"]" ) ~ ", " ~ (stackMap ? localName(stackMap, hi >> 16) : "SP[" ~ to!string(hi >> 16)~"]" ) ~ "\n";
            }
            break;
        case LongInst.Sub:
            {
                result ~= "Sub " ~ (stackMap ? localName(stackMap, hi & 0xFFFF) : "SP[" ~ to!string(hi & 0xFFFF)~"]" ) ~ ", " ~ (stackMap ? localName(stackMap, hi >> 16) : "SP[" ~ to!string(hi >> 16)~"]" ) ~ "\n";
            }
            break;
        case LongInst.Mul:
            {
                result ~= "Mul " ~ (stackMap ? localName(stackMap, hi & 0xFFFF) : "SP[" ~ to!string(hi & 0xFFFF)~"]" ) ~ ", " ~ (stackMap ? localName(stackMap, hi >> 16) : "SP[" ~ to!string(hi >> 16)~"]" ) ~ "\n";
            }
            break;
        case LongInst.Div:
            {
                result ~= "Div " ~ (stackMap ? localName(stackMap, hi & 0xFFFF) : "SP[" ~ to!string(hi & 0xFFFF)~"]" ) ~ ", " ~ (stackMap ? localName(stackMap, hi >> 16) : "SP[" ~ to!string(hi >> 16)~"]" ) ~ "\n";
            }
            break;
        case LongInst.Mod:
            {
                result ~= "Mod " ~ (stackMap ? localName(stackMap, hi & 0xFFFF) : "SP[" ~ to!string(hi & 0xFFFF)~"]" ) ~ ", " ~ (stackMap ? localName(stackMap, hi >> 16) : "SP[" ~ to!string(hi >> 16)~"]" ) ~ "\n";
            }
            break;
        case LongInst.And:
            {
                result ~= "And " ~ (stackMap ? localName(stackMap, hi & 0xFFFF) : "SP[" ~ to!string(hi & 0xFFFF)~"]" ) ~ ", " ~ (stackMap ? localName(stackMap, hi >> 16) : "SP[" ~ to!string(hi >> 16)~"]" ) ~ "\n";
            }
            break;
        case LongInst.And32:
            {
                result ~= "And32 " ~ (stackMap ? localName(stackMap, hi & 0xFFFF) : "SP[" ~ to!string(hi & 0xFFFF)~"]" ) ~ ", " ~ (stackMap ? localName(stackMap, hi >> 16) : "SP[" ~ to!string(hi >> 16)~"]" ) ~ "\n";
            }
            break;
        case LongInst.Or:
            {
                result ~= "Or " ~ (stackMap ? localName(stackMap, hi & 0xFFFF) : "SP[" ~ to!string(hi & 0xFFFF)~"]" ) ~ ", " ~ (stackMap ? localName(stackMap, hi >> 16) : "SP[" ~ to!string(hi >> 16)~"]" ) ~ "\n";
            }
            break;
        case LongInst.Xor:
            {
                result ~= "Xor " ~ (stackMap ? localName(stackMap, hi & 0xFFFF) : "SP[" ~ to!string(hi & 0xFFFF)~"]" ) ~ ", " ~ (stackMap ? localName(stackMap, hi >> 16) : "SP[" ~ to!string(hi >> 16)~"]" ) ~ "\n";
            }
            break;
        case LongInst.Xor32:
            {
                result ~= "Xor32 " ~ (stackMap ? localName(stackMap, hi & 0xFFFF) : "SP[" ~ to!string(hi & 0xFFFF)~"]" ) ~ ", " ~ (stackMap ? localName(stackMap, hi >> 16) : "SP[" ~ to!string(hi >> 16)~"]" ) ~ "\n";
            }
            break;
        case LongInst.Lsh:
            {
                result ~= "Lsh " ~ (stackMap ? localName(stackMap, hi & 0xFFFF) : "SP[" ~ to!string(hi & 0xFFFF)~"]" ) ~ ", " ~ (stackMap ? localName(stackMap, hi >> 16) : "SP[" ~ to!string(hi >> 16)~"]" ) ~ "\n";
            }
            break;
        case LongInst.Rsh:
            {
                result ~= "Rsh " ~ (stackMap ? localName(stackMap, hi & 0xFFFF) : "SP[" ~ to!string(hi & 0xFFFF)~"]" ) ~ ", " ~ (stackMap ? localName(stackMap, hi >> 16) : "SP[" ~ to!string(hi >> 16)~"]" ) ~ "\n";
            }
            break;

        case LongInst.FEq32:
            {
                result ~= "FEq32 " ~ (stackMap ? localName(stackMap, hi & 0xFFFF) : "SP[" ~ to!string(hi & 0xFFFF)~"]" ) ~ ", " ~ (stackMap ? localName(stackMap, hi >> 16) : "SP[" ~ to!string(hi >> 16)~"]" ) ~ "\n";
            }
            break;
        case LongInst.FNeq32:
            {
                result ~= "FNeq32 " ~ (stackMap ? localName(stackMap, hi & 0xFFFF) : "SP[" ~ to!string(hi & 0xFFFF)~"]" ) ~ ", " ~ (stackMap ? localName(stackMap, hi >> 16) : "SP[" ~ to!string(hi >> 16)~"]" ) ~ "\n";
            }
            break;
        case LongInst.FLt32:
            {
                result ~= "FLt32 " ~ (stackMap ? localName(stackMap, hi & 0xFFFF) : "SP[" ~ to!string(hi & 0xFFFF)~"]" ) ~ ", " ~ (stackMap ? localName(stackMap, hi >> 16) : "SP[" ~ to!string(hi >> 16)~"]" ) ~ "\n";
            }
            break;
        case LongInst.FLe32:
            {
                result ~= "FLe32 " ~ (stackMap ? localName(stackMap, hi & 0xFFFF) : "SP[" ~ to!string(hi & 0xFFFF)~"]" ) ~ ", " ~ (stackMap ? localName(stackMap, hi >> 16) : "SP[" ~ to!string(hi >> 16)~"]" ) ~ "\n";
            }
            break;
        case LongInst.FGt32:
            {
                result ~= "FGt32 " ~ (stackMap ? localName(stackMap, hi & 0xFFFF) : "SP[" ~ to!string(hi & 0xFFFF)~"]" ) ~ ", " ~ (stackMap ? localName(stackMap, hi >> 16) : "SP[" ~ to!string(hi >> 16)~"]" ) ~ "\n";
            }
            break;
        case LongInst.FGe32:
            {
                result ~= "FGe32 " ~ (stackMap ? localName(stackMap, hi & 0xFFFF) : "SP[" ~ to!string(hi & 0xFFFF)~"]" ) ~ ", " ~ (stackMap ? localName(stackMap, hi >> 16) : "SP[" ~ to!string(hi >> 16)~"]" ) ~ "\n";
            }
            break;
        case LongInst.F32ToF64:
            {
                result ~= "F32ToF64 " ~ (stackMap ? localName(stackMap, hi & 0xFFFF) : "SP[" ~ to!string(hi & 0xFFFF)~"]" ) ~ ", " ~ (stackMap ? localName(stackMap, hi >> 16) : "SP[" ~ to!string(hi >> 16)~"]" ) ~ "\n";
            }
            break;
        case LongInst.F32ToI:
            {
                result ~= "F32ToI " ~ (stackMap ? localName(stackMap, hi & 0xFFFF) : "SP[" ~ to!string(hi & 0xFFFF)~"]" ) ~ ", " ~ (stackMap ? localName(stackMap, hi >> 16) : "SP[" ~ to!string(hi >> 16)~"]" ) ~ "\n";
            }
            break;
        case LongInst.IToF32:
            {
                result ~= "IToF32 " ~ (stackMap ? localName(stackMap, hi & 0xFFFF) : "SP[" ~ to!string(hi & 0xFFFF)~"]" ) ~ ", " ~ (stackMap ? localName(stackMap, hi >> 16) : "SP[" ~ to!string(hi >> 16)~"]" ) ~ "\n";
            }
            break;
        case LongInst.FAdd32:
            {
                result ~= "FAdd32 " ~ (stackMap ? localName(stackMap, hi & 0xFFFF) : "SP[" ~ to!string(hi & 0xFFFF)~"]" ) ~ ", " ~ (stackMap ? localName(stackMap, hi >> 16) : "SP[" ~ to!string(hi >> 16)~"]" ) ~ "\n";
            }
            break;
        case LongInst.FSub32:
            {
                result ~= "FSub32 " ~ (stackMap ? localName(stackMap, hi & 0xFFFF) : "SP[" ~ to!string(hi & 0xFFFF)~"]" ) ~ ", " ~ (stackMap ? localName(stackMap, hi >> 16) : "SP[" ~ to!string(hi >> 16)~"]" ) ~ "\n";
            }
            break;
        case LongInst.FMul32:
            {
                result ~= "FMul32 " ~ (stackMap ? localName(stackMap, hi & 0xFFFF) : "SP[" ~ to!string(hi & 0xFFFF)~"]" ) ~ ", " ~ (stackMap ? localName(stackMap, hi >> 16) : "SP[" ~ to!string(hi >> 16)~"]" ) ~ "\n";
            }
            break;
        case LongInst.FDiv32:
            {
                result ~= "FDiv32 " ~ (stackMap ? localName(stackMap, hi & 0xFFFF) : "SP[" ~ to!string(hi & 0xFFFF)~"]" ) ~ ", " ~ (stackMap ? localName(stackMap, hi >> 16) : "SP[" ~ to!string(hi >> 16)~"]" ) ~ "\n";
            }
            break;
        case LongInst.FMod32:
            {
                result ~= "FMod32 " ~ (stackMap ? localName(stackMap, hi & 0xFFFF) : "SP[" ~ to!string(hi & 0xFFFF)~"]" ) ~ ", " ~ (stackMap ? localName(stackMap, hi >> 16) : "SP[" ~ to!string(hi >> 16)~"]" ) ~ "\n";
            }
            break;

        case LongInst.FEq64:
            {
                result ~= "FEq64 " ~ (stackMap ? localName(stackMap, hi & 0xFFFF) : "SP[" ~ to!string(hi & 0xFFFF)~"]" ) ~ ", " ~ (stackMap ? localName(stackMap, hi >> 16) : "SP[" ~ to!string(hi >> 16)~"]" ) ~ "\n";
            }
            break;
        case LongInst.FNeq64:
            {
                result ~= "FNeq64 " ~ (stackMap ? localName(stackMap, hi & 0xFFFF) : "SP[" ~ to!string(hi & 0xFFFF)~"]" ) ~ ", " ~ (stackMap ? localName(stackMap, hi >> 16) : "SP[" ~ to!string(hi >> 16)~"]" ) ~ "\n";
            }
            break;
        case LongInst.FLt64:
            {
                result ~= "FLt64 " ~ (stackMap ? localName(stackMap, hi & 0xFFFF) : "SP[" ~ to!string(hi & 0xFFFF)~"]" ) ~ ", " ~ (stackMap ? localName(stackMap, hi >> 16) : "SP[" ~ to!string(hi >> 16)~"]" ) ~ "\n";
            }
            break;
        case LongInst.FLe64:
            {
                result ~= "FLe64 " ~ (stackMap ? localName(stackMap, hi & 0xFFFF) : "SP[" ~ to!string(hi & 0xFFFF)~"]" ) ~ ", " ~ (stackMap ? localName(stackMap, hi >> 16) : "SP[" ~ to!string(hi >> 16)~"]" ) ~ "\n";
            }
            break;
        case LongInst.FGt64:
            {
                result ~= "FGt64 " ~ (stackMap ? localName(stackMap, hi & 0xFFFF) : "SP[" ~ to!string(hi & 0xFFFF)~"]" ) ~ ", " ~ (stackMap ? localName(stackMap, hi >> 16) : "SP[" ~ to!string(hi >> 16)~"]" ) ~ "\n";
            }
            break;
        case LongInst.FGe64:
            {
                result ~= "FGe64 " ~ (stackMap ? localName(stackMap, hi & 0xFFFF) : "SP[" ~ to!string(hi & 0xFFFF)~"]" ) ~ ", " ~ (stackMap ? localName(stackMap, hi >> 16) : "SP[" ~ to!string(hi >> 16)~"]" ) ~ "\n";
            }
            break;
        case LongInst.F64ToF32:
            {
                result ~= "F64ToF32 " ~ (stackMap ? localName(stackMap, hi & 0xFFFF) : "SP[" ~ to!string(hi & 0xFFFF)~"]" ) ~ ", " ~ (stackMap ? localName(stackMap, hi >> 16) : "SP[" ~ to!string(hi >> 16)~"]" ) ~ "\n";
            }
            break;
        case LongInst.F64ToI:
            {
                result ~= "F64ToI " ~ (stackMap ? localName(stackMap, hi & 0xFFFF) : "SP[" ~ to!string(hi & 0xFFFF)~"]" ) ~ ", " ~ (stackMap ? localName(stackMap, hi >> 16) : "SP[" ~ to!string(hi >> 16)~"]" ) ~ "\n";
            }
            break;
        case LongInst.IToF64:
            {
                result ~= "IToF64 " ~ (stackMap ? localName(stackMap, hi & 0xFFFF) : "SP[" ~ to!string(hi & 0xFFFF)~"]" ) ~ ", " ~ (stackMap ? localName(stackMap, hi >> 16) : "SP[" ~ to!string(hi >> 16)~"]" ) ~ "\n";
            }
            break;
        case LongInst.FAdd64:
            {
                result ~= "FAdd64 " ~ (stackMap ? localName(stackMap, hi & 0xFFFF) : "SP[" ~ to!string(hi & 0xFFFF)~"]" ) ~ ", " ~ (stackMap ? localName(stackMap, hi >> 16) : "SP[" ~ to!string(hi >> 16)~"]" ) ~ "\n";
            }
            break;
        case LongInst.FSub64:
            {
                result ~= "FSub64 " ~ (stackMap ? localName(stackMap, hi & 0xFFFF) : "SP[" ~ to!string(hi & 0xFFFF)~"]" ) ~ ", " ~ (stackMap ? localName(stackMap, hi >> 16) : "SP[" ~ to!string(hi >> 16)~"]" ) ~ "\n";
            }
            break;
        case LongInst.FMul64:
            {
                result ~= "FMul64 " ~ (stackMap ? localName(stackMap, hi & 0xFFFF) : "SP[" ~ to!string(hi & 0xFFFF)~"]" ) ~ ", " ~ (stackMap ? localName(stackMap, hi >> 16) : "SP[" ~ to!string(hi >> 16)~"]" ) ~ "\n";
            }
            break;
        case LongInst.FDiv64:
            {
                result ~= "FDiv64 " ~ (stackMap ? localName(stackMap, hi & 0xFFFF) : "SP[" ~ to!string(hi & 0xFFFF)~"]" ) ~ ", " ~ (stackMap ? localName(stackMap, hi >> 16) : "SP[" ~ to!string(hi >> 16)~"]" ) ~ "\n";
            }
            break;
        case LongInst.FMod64:
            {
                result ~= "FMod64 " ~ (stackMap ? localName(stackMap, hi & 0xFFFF) : "SP[" ~ to!string(hi & 0xFFFF)~"]" ) ~ ", " ~ (stackMap ? localName(stackMap, hi >> 16) : "SP[" ~ to!string(hi >> 16)~"]" ) ~ "\n";
            }
            break;

        case LongInst.Assert:
            {
                result ~= "Assert " ~ (stackMap ? localName(stackMap, lw >> 16) : "SP[" ~ to!string(lw >> 16)~"]" ) ~ ", ErrNo #" ~  to!string(hi) ~ "\n";
            }
            break;
        case LongInst.StrEq:
            {
                result ~= "StrEq " ~ (stackMap ? localName(stackMap, hi & 0xFFFF) : "SP[" ~ to!string(hi & 0xFFFF)~"]" ) ~ ", " ~ (stackMap ? localName(stackMap, hi >> 16) : "SP[" ~ to!string(hi >> 16)~"]" ) ~ "\n";
            }
            break;
        case LongInst.Eq:
            {
                result ~= "Eq " ~ (stackMap ? localName(stackMap, hi & 0xFFFF) : "SP[" ~ to!string(hi & 0xFFFF)~"]" ) ~ ", " ~ (stackMap ? localName(stackMap, hi >> 16) : "SP[" ~ to!string(hi >> 16)~"]" ) ~ "\n";
            }
            break;
        case LongInst.Neq:
            {
                result ~= "Neq " ~ (stackMap ? localName(stackMap, hi & 0xFFFF) : "SP[" ~ to!string(hi & 0xFFFF)~"]" ) ~ ", " ~ (stackMap ? localName(stackMap, hi >> 16) : "SP[" ~ to!string(hi >> 16)~"]" ) ~ "\n";
            }
            break;

        case LongInst.Set:
            {
                result ~= "Set " ~ (stackMap ? localName(stackMap, hi & 0xFFFF) : "SP[" ~ to!string(hi & 0xFFFF)~"]" ) ~ ", " ~ (stackMap ? localName(stackMap, hi >> 16) : "SP[" ~ to!string(hi >> 16)~"]" ) ~ "\n";
            }
            break;

        case LongInst.Lt:
            {
                result ~= "Lt " ~ (stackMap ? localName(stackMap, hi & 0xFFFF) : "SP[" ~ to!string(hi & 0xFFFF)~"]" ) ~ ", " ~ (stackMap ? localName(stackMap, hi >> 16) : "SP[" ~ to!string(hi >> 16)~"]" ) ~ "\n";
            }
            break;
        case LongInst.Gt:
            {
                result ~= "Gt " ~ (stackMap ? localName(stackMap, hi & 0xFFFF) : "SP[" ~ to!string(hi & 0xFFFF)~"]" ) ~ ", " ~ (stackMap ? localName(stackMap, hi >> 16) : "SP[" ~ to!string(hi >> 16)~"]" ) ~ "\n";
            }
            break;
        case LongInst.Le:
            {
                result ~= "Le " ~ (stackMap ? localName(stackMap, hi & 0xFFFF) : "SP[" ~ to!string(hi & 0xFFFF)~"]" ) ~ ", " ~ (stackMap ? localName(stackMap, hi >> 16) : "SP[" ~ to!string(hi >> 16)~"]" ) ~ "\n";
            }
            break;
        case LongInst.Ge:
            {
                result ~= "Ge " ~ (stackMap ? localName(stackMap, hi & 0xFFFF) : "SP[" ~ to!string(hi & 0xFFFF)~"]" ) ~ ", " ~ (stackMap ? localName(stackMap, hi >> 16) : "SP[" ~ to!string(hi >> 16)~"]" ) ~ "\n";
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
                result ~= "JmpNZ " ~ (stackMap ? localName(stackMap, lw >> 16) : "SP[" ~ to!string(lw >> 16)~"]" ) ~ ", &" ~ to!string(
                    (has4ByteOffset ? hi - 4 : hi)) ~ "\n";
            }
            break;

        case LongInst.JmpZ:
            {
                result ~= "JmpZ " ~ (stackMap ? localName(stackMap, lw >> 16) : "SP[" ~ to!string(lw >> 16)~"]" ) ~ ", &" ~ to!string(
                    (has4ByteOffset ? hi - 4 : hi)) ~ "\n";
            }
            break;

        case LongInst.HeapLoad32:
            {
                result ~= "HeapLoad32 " ~ (stackMap ? localName(stackMap, hi & 0xFFFF) : "SP[" ~ to!string(hi & 0xFFFF)~"]" ) ~ ", HEAP[" ~ localName(stackMap, hi >> 16) ~  "]\n";
            }
            break;

        case LongInst.HeapStore32:
            {
                result ~= "HeapStore32 HEAP[" ~ (stackMap ? localName(stackMap, hi & 0xFFFF) : "SP[" ~ to!string(hi & 0xFFFF) ~ "]")  ~ "], " ~ localName(stackMap, hi >> 16) ~ "\n";
            }
            break;

        case LongInst.HeapLoad64:
            {
                result ~= "HeapLoad64 " ~ (stackMap ? localName(stackMap, hi & 0xFFFF) : "SP[" ~ to!string(hi & 0xFFFF)) ~ "], HEAP[SP[" ~ to!string(
                    hi >> 16) ~ "]]\n";
            }
            break;

        case LongInst.HeapStore64:
            {
                result ~= "HeapStore64 HEAP[" ~ (stackMap ? localName(stackMap, hi & 0xFFFF) : "SP[" ~ to!string(hi & 0xFFFF)~"]" ) ~ "], " ~ localName(stackMap, hi >> 16) ~ "\n";
            }
            break;
/*
        case LongInst.ExB:
            {
                result ~= "ExB " ~ (stackMap ? localName(stackMap, hi & 0xFFFF) : "SP[" ~ to!string(hi & 0xFFFF)~"]" ) ~ ", " ~ (stackMap ? localName(stackMap, hi >> 16) : "SP[" ~ to!string(hi >> 16)~"]" ) ~ "\n";
            }
            break;
*/
        case LongInst.Ret32:
            {
                result ~= "Ret32 " ~ (stackMap ? localName(stackMap, lw >> 16) : "SP[" ~ to!string(lw >> 16)~"]" ) ~ " \n";
            }
            break;
        case LongInst.Ret64:
            {
                result ~= "Ret64 " ~ (stackMap ? localName(stackMap, lw >> 16) : "SP[" ~ to!string(lw >> 16)~"]" ) ~ " \n";
            }
            break;
        case LongInst.RelJmp:
            {
                result ~= "RelJmp &" ~ to!string(cast(short)(lw >> 16) + (pos - 2)) ~ "\n";
            }
            break;
            /*case LongInst.Prt:
            {
                result ~= "Prt " ~ (stackMap ? localName(stackMap, lw >> 16) : "SP[" ~ to!string(lw >> 16)~"]" ) ~ " \n";
            }
            break;*/
        case LongInst.Not:
            {
                result ~= "Not " ~ (stackMap ? localName(stackMap, lw >> 16) : "SP[" ~ to!string(lw >> 16)~"]" ) ~ " \n";
            }
            break;

        case LongInst.Flg:
            {
                result ~= "Flg " ~ (stackMap ? localName(stackMap, lw >> 16) : "SP[" ~ to!string(lw >> 16)~"]" ) ~ " \n";
            }
            break;
        case LongInst.Call:
            {
                result ~= "Call " ~ (stackMap ? localName(stackMap, hi & 0xFFFF) : "SP[" ~ to!string(hi & 0xFFFF)~"]" ) ~ ", " ~ (stackMap ? localName(stackMap, hi >> 16) : "SP[" ~ to!string(hi >> 16)~"]" ) ~ "\n";
            }
            break;
        case LongInst.Cat:
            {
                result ~= "Cat " ~ localName(stackMap, lw >> 16) ~ ", " ~ (stackMap ? localName(stackMap, hi & 0xFFFF) : "SP[" ~ to!string(hi & 0xFFFF)~"]" ) ~ ", " ~ (stackMap ? localName(stackMap, hi >> 16) : "SP[" ~ to!string(hi >> 16)~"]" ) ~ "\n";
            }
            break;
        case LongInst.BuiltinCall:
            {
                result ~= "BuiltinCall Fn{" ~ to!string(lw >> 16) ~ "} (" ~ to!string(hi) ~ ")\n";
            }
            break;
        case LongInst.Alloc:
            {
                result ~= "Alloc " ~ (stackMap ? localName(stackMap, hi & 0xFFFF) : "SP[" ~ to!string(hi & 0xFFFF)~"]" ) ~ " " ~ (stackMap ? localName(stackMap, hi >> 16) : "SP[" ~ to!string(hi >> 16)~"]" ) ~ "\n";
            }
            break;
        case LongInst.MemCpy:
            {
                result ~= "MemCpy " ~ (stackMap ? localName(stackMap, hi & 0xFFFF) : "SP[" ~ to!string(hi & 0xFFFF)~"]" ) ~ " " ~ (stackMap ? localName(stackMap, hi >> 16) : "SP[" ~ to!string(hi >> 16)~"]" ) ~ " " ~ (stackMap ? localName(stackMap, lw >> 16) : "SP[" ~ to!string(lw >> 16)~"]" ) ~ "\n";
            }
            break;
        case LongInst.Comment:
            {
                auto commentLength = hi;
                auto alignedLength = align4(commentLength) / 4;
                result ~= "CommentBegin (CommentLength: " ~  to!string(commentLength) ~ ")\n";
                // alignLengthBy2
                assert(alignedLength <= length, "comment (" ~ to!string(alignedLength) ~") longer then code (" ~ to!string(length) ~ ")");

                foreach(c4i; pos .. pos + alignedLength)
                {
                    result ~= *(cast(const(char[4])*) &arr[c4i]);
                }
                pos += alignedLength;
                length -= alignedLength;
                result ~= "\nCommentEnd\n";
            }
            break;
        case LongInst.Line:
            {
                result ~= "Line #" ~ to!string(hi) ~ "\n";
            }
            break;

        }
    }
    return result ~ "\nEndInstructionDump\n";
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

enum DebugCmdEnum
{
    Invalid,
    Nothing,

    SetBreakpoint,
    UnsetBreakpoint,

    ReadStack,
    WriteStack,

    ReadHeap,
    WriteHeap,

    Continue,
}

struct DebugCommand
{
    DebugCmdEnum order;
    uint v1;
}

const(BCValue) interpret_(const int[] byteCode, const BCValue[] args,
    BCHeap* heapPtr = null, const BCFunction* functions = null,
    const RetainedCall* calls = null,
    BCValue* ev1 = null, BCValue* ev2 = null, BCValue* ev3 = null,
    BCValue* ev4 = null, const RE* errors = null,
    long[] stackPtr = null, const string[ushort] stackMap = null,
/+    DebugCommand function() reciveCommand = {return DebugCommand(DebugCmdEnum.Nothing);},
    BCValue* debugOutput = null,+/ uint stackOffset = 0)  @trusted
{
    __gshared static uint callDepth;
    import std.conv;
    import std.stdio;

    bool paused; // true if we are in a breakpoint.


    uint[] breakLines = [];
    uint lastLine;

    if (!__ctfe)
    {
        debug writeln("Args: ", args, "BC:", byteCode.printInstructions(stackMap));
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
/+
    struct Stack
    {
        long* opIndex(size_t idx) pure
        {
            long* result = &stack[0] + (stackOffset / 4) + idx;
            debug if (!__ctfe) { writeln("SP[", idx*4, "] = ", *result); }
            return result;
        }
    }
    auto stackP = Stack();
+/
    size_t argOffset = 4;
    foreach (arg; args)
    {
        switch (arg.type.type)
        {
        case BCTypeEnum.i32, BCTypeEnum.f23:
            {
                *(&stackP[argOffset / 4]) = arg.imm32;
                argOffset += uint.sizeof;
            }
            break;
        case BCTypeEnum.i64, BCTypeEnum.f52:
            {
                *(&stackP[0] + argOffset / 4) = arg.imm64;
                argOffset += uint.sizeof;
                //TODO find out why adding ulong.sizeof does not work here
                //make variable-sized stack possible ... if it should be needed

            }
            break;
        case BCTypeEnum.Struct, BCTypeEnum.String, BCTypeEnum.Array, BCTypeEnum.Ptr:
            {
                // This might need to be removed agaein ?
                *(&stackP[argOffset / 4]) = arg.heapAddr.addr;
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
/+
        DebugCommand command = reciveCommand();
        do
        {
            debug
            {
                import std.stdio;
                if (!__ctfe) writeln("Order: ", to!string(command.order));
            }

            Switch : final switch(command.order) with(DebugCmdEnum)
            {
                case Invalid : {assert(0, "Invalid DebugCmdEnum");} break;
                case SetBreakpoint :
                {
                    auto bl = command.v1;
                    foreach(_bl;breakLines)
                    {
                        if (bl == _bl)
                            break Switch;
                    }

                    breakLines ~= bl;
                } break;
                case UnsetBreakpoint :
                {
                    auto bl = command.v1;
                    foreach(uint i, _bl;breakLines)
                    {
                        if (_bl == bl)
                        {
                            breakLines[i] = breakLines[$-1];
                            breakLines = breakLines[0 .. $-1];
                            break;
                        }
                    }
                } break;
                case ReadStack : {assert(0);} break;
                case WriteStack : {assert(0);} break;
                case ReadHeap : {assert(0);} break;
                case WriteHeap : {assert(0);} break;
                case Continue : {paused = false;} break;
                case Nothing :
                {
                    if (!paused)
                    { /*__mmPause()*/ }
                } break;
            }

        } while (paused || command.order != DebugCmdEnum.Nothing);
+/
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
        // debug if (!__ctfe) writeln("ip: ", ip);
        const lw = byteCode[ip];
        const hi = byteCode[ip + 1];
        ip += 2;

        // consider splitting the stackPointer in stackHigh and stackLow

        const uint opRefOffset = (lw >> 16) & 0xFFFF;
        const uint lhsOffset = hi & 0xFFFF;
        const uint rhsOffset = (hi >> 16) & 0xFFFF;

        auto lhsRef = (&stackP[(lhsOffset / 4)]);
        auto rhs = (&stackP[(rhsOffset / 4)]);
        auto lhsStackRef = (&stackP[(opRefOffset / 4)]);
        auto opRef = &stackP[(opRefOffset / 4)];

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
                (*lhsStackRef) &= cast(uint)hi;
            }
            break;
        case LongInst.ImmAnd32:
            {
                *lhsStackRef = (cast(uint)*lhsStackRef) & cast(uint)hi;
            }
            break;
        case LongInst.ImmOr:
            {
                (*lhsStackRef) |= cast(uint)hi;
            }
            break;
        case LongInst.ImmXor:
            {
                (*lhsStackRef) ^= cast(uint)hi;
            }
            break;
        case LongInst.ImmXor32:
            {
                *lhsStackRef = (cast(uint)*lhsStackRef) ^ cast(uint)hi;
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
        case LongInst.SetHighImm:
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
        case LongInst.And32:
            {
               (*lhsRef) = (cast(uint) *lhsRef) & (cast(uint)*rhs);
            }
            break;
        case LongInst.Or:
            {
                (*lhsRef) |= *rhs;
            }
            break;
        case LongInst.Xor32:
            {
                (*lhsRef) = (cast(uint) *lhsRef) ^ (cast(uint)*rhs);
            }
            break;
        case LongInst.Xor:
            {
                (*lhsRef) ^= *rhs;
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
        case LongInst.FGt32 :
            {
                uint _lhs = *lhsRef & uint.max;
                float flhs = *cast(float*)&_lhs;
                uint _rhs = *rhs & uint.max;
                float frhs = *cast(float*)&_rhs;

                cond = flhs > frhs;
            }
            break;
        case LongInst.FGe32 :
            {
                uint _lhs = *lhsRef & uint.max;
                float flhs = *cast(float*)&_lhs;
                uint _rhs = *rhs & uint.max;
                float frhs = *cast(float*)&_rhs;

                cond = flhs >= frhs;
            }
            break;
        case LongInst.FEq32 :
            {
                uint _lhs = *lhsRef & uint.max;
                float flhs = *cast(float*)&_lhs;
                uint _rhs = *rhs & uint.max;
                float frhs = *cast(float*)&_rhs;

                cond = flhs == frhs;
            }
            break;
        case LongInst.FNeq32 :
            {
                uint _lhs = *lhsRef & uint.max;
                float flhs = *cast(float*)&_lhs;
                uint _rhs = *rhs & uint.max;
                float frhs = *cast(float*)&_rhs;

                cond = flhs != frhs;
            }
            break;
        case LongInst.FLt32 :
            {
                uint _lhs = *lhsRef & uint.max;
                float flhs = *cast(float*)&_lhs;
                uint _rhs = *rhs & uint.max;
                float frhs = *cast(float*)&_rhs;

                cond = flhs < frhs;
            }
            break;
        case LongInst.FLe32 :
            {
                uint _lhs = *lhsRef & uint.max;
                float flhs = *cast(float*)&_lhs;
                uint _rhs = *rhs & uint.max;
                float frhs = *cast(float*)&_rhs;

                cond = flhs <= frhs;
            }
            break;
        case LongInst.F32ToF64 :
            {
                uint rhs32 = (*rhs & uint.max);
                float frhs = *cast(float*)&rhs32;
                double flhs = frhs;
                *lhsRef = *cast(long*)&flhs;
            }
            break;
        case LongInst.F32ToI :
            {
                uint rhs32 = (*rhs & uint.max);
                float frhs = *cast(float*)&rhs32;
                uint _lhs = cast(int)frhs;
                *lhsRef = _lhs;
            }
            break;
        case LongInst.IToF32 :
            {
                float frhs = *rhs;
                uint _lhs = *cast(uint*)&frhs;
                *lhsRef = _lhs;
            }
            break;

        case LongInst.FAdd32:
            {
                uint _lhs = *lhsRef & uint.max;
                float flhs = *cast(float*)&_lhs;
                uint _rhs = *rhs & uint.max;
                float frhs = *cast(float*)&_rhs;

                flhs += frhs;

                _lhs = *cast(uint*)&flhs;
                *lhsRef = _lhs;
            }
            break;
        case LongInst.FSub32:
            {
                uint _lhs = *lhsRef & uint.max;
                float flhs = *cast(float*)&_lhs;
                uint _rhs = *rhs & uint.max;
                float frhs = *cast(float*)&_rhs;

                flhs -= frhs;

                _lhs = *cast(uint*)&flhs;
                *lhsRef = _lhs;
            }
            break;
        case LongInst.FMul32:
            {
                uint _lhs = *lhsRef & uint.max;
                float flhs = *cast(float*)&_lhs;
                uint _rhs = *rhs & uint.max;
                float frhs = *cast(float*)&_rhs;

                flhs *= frhs;

                _lhs = *cast(uint*)&flhs;
                *lhsRef = _lhs;
            }
            break;
        case LongInst.FDiv32:
            {
                uint _lhs = *lhsRef & uint.max;
                float flhs = *cast(float*)&_lhs;
                uint _rhs = *rhs & uint.max;
                float frhs = *cast(float*)&_rhs;

                flhs /= frhs;

                _lhs = *cast(uint*)&flhs;
                *lhsRef = _lhs;
            }
            break;
        case LongInst.FMod32:
            {
                uint _lhs = *lhsRef & uint.max;
                float flhs = *cast(float*)&_lhs;
                uint _rhs = *rhs & uint.max;
                float frhs = *cast(float*)&_rhs;

                flhs %= frhs;

                _lhs = *cast(uint*)&flhs;
                *lhsRef = _lhs;
            }
            break;
        case LongInst.FEq64 :
            {
                ulong _lhs = *lhsRef;
                double flhs = *cast(double*)&_lhs;
                ulong _rhs = *rhs;
                double frhs = *cast(double*)&_rhs;

                cond = flhs == frhs;
            }
            break;
        case LongInst.FNeq64 :
            {
                ulong _lhs = *lhsRef;
                double flhs = *cast(double*)&_lhs;
                ulong _rhs = *rhs;
                double frhs = *cast(double*)&_rhs;

                cond = flhs < frhs;
            }
            break;
        case LongInst.FLt64 :
            {
                ulong _lhs = *lhsRef;
                double flhs = *cast(double*)&_lhs;
                ulong _rhs = *rhs;
                double frhs = *cast(double*)&_rhs;

                cond = flhs < frhs;
            }
            break;
        case LongInst.FLe64 :
            {
                ulong _lhs = *lhsRef;
                double flhs = *cast(double*)&_lhs;
                ulong _rhs = *rhs;
                double frhs = *cast(double*)&_rhs;

                cond = flhs <= frhs;
            }
            break;
        case LongInst.FGt64 :
            {
                ulong _lhs = *lhsRef;
                double flhs = *cast(double*)&_lhs;
                ulong _rhs = *rhs;
                double frhs = *cast(double*)&_rhs;

                cond = flhs > frhs;
            }
            break;
        case LongInst.FGe64 :
            {
                ulong _lhs = *lhsRef;
                double flhs = *cast(double*)&_lhs;
                ulong _rhs = *rhs;
                double frhs = *cast(double*)&_rhs;

                cond = flhs >= frhs;
            }
            break;

        case LongInst.F64ToF32 :
            {
                double frhs = *cast(double*)rhs;
                float flhs = frhs;
                *lhsRef = *cast(uint*)&flhs;
            }
            break;
        case LongInst.F64ToI :
            {
                float frhs = *cast(double*)rhs;
                *lhsRef = cast(long)frhs;
            }
            break;
        case LongInst.IToF64 :
            {
                double frhs = cast(double)*rhs;
                *lhsRef = *cast(long*)&frhs;
            }
            break;

        case LongInst.FAdd64:
            {
                ulong _lhs = *lhsRef;
                double flhs = *cast(double*)&_lhs;
                ulong _rhs = *rhs;
                double frhs = *cast(double*)&_rhs;

                flhs += frhs;

                _lhs = *cast(ulong*)&flhs;
                *lhsRef = _lhs;
            }
            break;
        case LongInst.FSub64:
            {
                ulong _lhs = *lhsRef;
                double flhs = *cast(double*)&_lhs;
                ulong _rhs = *rhs;
                double frhs = *cast(double*)&_rhs;

                flhs -= frhs;

                _lhs = *cast(ulong*)&flhs;
                *lhsRef = _lhs;
            }
            break;
        case LongInst.FMul64:
            {
                ulong _lhs = *lhsRef;
                double flhs = *cast(double*)&_lhs;
                ulong _rhs = *rhs;
                double frhs = *cast(double*)&_rhs;

                flhs *= frhs;

                _lhs = *cast(ulong*)&flhs;
                *lhsRef = _lhs;
            }
            break;
        case LongInst.FDiv64:
            {
                ulong _lhs = *lhsRef;
                double flhs = *cast(double*)&_lhs;
                ulong _rhs = *rhs;
                double frhs = *cast(double*)&_rhs;

                flhs /= frhs;

                _lhs = *cast(ulong*)&flhs;
                *(cast(ulong*)lhsRef) = _lhs;
            }
            break;
        case LongInst.FMod64:
            {
                ulong _lhs = *lhsRef;
                double flhs = *cast(double*)&_lhs;
                ulong _rhs = *rhs;
                double frhs = *cast(double*)&_rhs;

                flhs %= frhs;

                _lhs = *cast(ulong*)&flhs;
                *(cast(ulong*)lhsRef) = _lhs;
            }
            break;

        case LongInst.Assert:
            {
                if (*opRef == 0)
                {
                    BCValue retval = imm32(hi);
                    retval.vType = BCValueType.Error;

                    static if (is(RetainedError))
                    {
                        if (hi - 1 < bc_max_errors)
                        {
                            auto err = errors[cast(uint)(hi - 1)];

                            *ev1 = imm32(stackP[err.v1.addr / 4] & uint.max);
                            *ev2 = imm32(stackP[err.v2.addr / 4] & uint.max);
                            *ev3 = imm32(stackP[err.v3.addr / 4] & uint.max);
                            *ev4 = imm32(stackP[err.v4.addr / 4] & uint.max);
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
                if ((*lhsStackRef) != 0)
                {
                    ip = hi;
                }
            }
            break;
        case LongInst.JmpZ:
            {
                if ((*lhsStackRef) == 0)
                {
                    ip = hi;
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
                debug
                {
                    import std.stdio;
                    writeln("Loaded[",*rhs,"] = ",*lhsRef);
                }
            }
            break;
        case LongInst.HeapStore32:
            {
                assert(*lhsRef, "trying to deref null pointer SP[" ~ to!string((lhsRef - &stackP[0])*4) ~ "] at : &" ~ to!string (ip - 2));
                (*(heapPtr._heap.ptr + *lhsRef)) = (*rhs) & 0xFF_FF_FF_FF;
                debug
                {
                    import std.stdio;
                    writeln("Store[",*lhsRef,"] = ",*rhs & uint.max);
                }

            }
            break;

        case LongInst.HeapLoad64:
            {
                assert(*rhs, "trying to deref null pointer");
                (*lhsRef) = *(heapPtr._heap.ptr + *rhs);
                (*lhsRef) |= long(*(heapPtr._heap.ptr + 4 + *rhs)) << 32;

                debug
                {
                    import std.stdio;
                    writeln("Loaded[",*rhs,"] = ",*lhsRef);
                }
            }
            break;

        case LongInst.HeapStore64:
            {
                assert(*lhsRef, "trying to deref null pointer SP[" ~ to!string((lhsRef - &stackP[0])*4) ~ "] at : &" ~ to!string (ip - 2));
                (*(heapPtr._heap.ptr + *lhsRef)) = (*rhs) & 0xFF_FF_FF_FF;
                (*(heapPtr._heap.ptr + 4 + *lhsRef)) = ((*rhs & 0xFF_FF_FF_FF_00_00_00_00) >> 32);
            }
            break;

/*
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
*/
        case LongInst.Ret32:
            {
                debug (bc)
                    if (!__ctfe)
                    {
                        import std.stdio;

                        writeln("Ret SP[", lhsOffset, "] (", *opRef, ")\n");
                    }
                return imm32(*opRef & uint.max);
            }
        case LongInst.Ret64:
            {
                debug (bc)
                    if (!__ctfe)
                    {
                        import std.stdio;

                        writeln("Ret SP[", lhsOffset, "] (", *opRef, ")\n");
                    }
                return BCValue(Imm64(*opRef));
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
        case LongInst.Cat:
            {
                if (*rhs == 0 && *lhsRef == 0)
                {
                    *lhsStackRef = 0;
                }
                else
                {
                    import ddmd.ctfe.ctfe_bc : SliceDescriptor;

                    const elemSize = (lw >> 8) & 255;
                    const uint _lhs =  *lhsRef & uint.max;
                    const uint _rhs =  *rhs & uint.max;

                    const lhsLength = _lhs ? heapPtr._heap[_lhs + SliceDescriptor.LengthOffset] : 0;
                    const rhsLength = _rhs ? heapPtr._heap[_rhs + SliceDescriptor.LengthOffset] : 0;

                    {
                        // TODO if lhs.capacity bla bla
                        const newLength = rhsLength + lhsLength;

                        const lhsBase = heapPtr._heap[_lhs + SliceDescriptor.BaseOffset];
                        const rhsBase = heapPtr._heap[_rhs + SliceDescriptor.BaseOffset];

                        const resultPtr = heapPtr.heapSize;

                        const resultLength = resultPtr + SliceDescriptor.LengthOffset;
                        const resultBaseP = resultPtr + SliceDescriptor.BaseOffset;
                        const resultBase = resultPtr + SliceDescriptor.Size;

                        const allocSize = (newLength * elemSize) + SliceDescriptor.Size;
                        const heapSize = heapPtr.heapSize;

                        if(heapSize + allocSize  >= heapPtr.heapMax)
                        {
                            if (heapPtr.heapMax >= 2 ^^ 30)
                                assert(0, "!!! HEAP OVERFLOW !!!");
                            else
                            {
                                // we will now resize the heap to 8 times of it's former size
                                auto newHeap = new uint[](heapPtr.heapMax * 8);
                                newHeap[0 .. heapSize] = heapPtr._heap[0 .. heapSize];
                                heapPtr._heap = newHeap;
                                heapPtr.heapMax *= 8;
                            }
                        }

                        heapPtr.heapSize += allocSize;

                        const scaledLhsLength = (lhsLength * elemSize);
                        const scaledRhsLength = (rhsLength * elemSize);
                        const resultLhsEnd = resultBase + scaledLhsLength;

                        heapPtr._heap[resultLength] = newLength;
                        heapPtr._heap[resultBaseP] = resultBase;

                        heapPtr._heap[resultBase .. resultLhsEnd] =
                            heapPtr._heap[lhsBase .. lhsBase + scaledLhsLength];

                        heapPtr._heap[resultLhsEnd ..  resultLhsEnd + scaledRhsLength] =
                            heapPtr._heap[rhsBase .. rhsBase + scaledRhsLength];

                        *lhsStackRef = resultPtr;
                    }
                }
            }
            break;

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
                        if(stackP[arg.stackAddr.addr / 4] <= uint.max)
                            callArgs[i] = imm32(stackP[arg.stackAddr.addr / 4] & uint.max);
                        else
                            callArgs[i] = BCValue(Imm64(stackP[arg.stackAddr.addr]));
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
                    callArgs[0 .. call.args.length], heapPtr, functions, calls, ev1, ev2, ev3, ev4, errors, stack, stackMap, stackOffsetCall);

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
                const allocSize = *rhs;
                const heapSize = heapPtr.heapSize;

                if(heapSize + allocSize  >= heapPtr.heapMax)
                {
                    if (heapPtr.heapMax >= 2 ^^ 30)
                        assert(0, "!!! HEAP OVERFLOW !!!");
                    else
                    {
                        // we will now resize the heap to 8 times of it's former size
                        auto newHeap = new uint[](heapPtr.heapMax * 8);
                        newHeap[0 .. heapSize] = heapPtr._heap[0 .. heapSize];
                        heapPtr._heap = newHeap;
                        heapPtr.heapMax *= 8;
                    }
                }

                *lhsRef = heapSize;
                heapPtr.heapSize += allocSize;

                debug
                {
                    writefln("Alloc(#%d) = &%d", allocSize, *lhsRef);
                }

            }
            break;
        case LongInst.MemCpy:
            {
                auto cpySize = cast(uint) *opRef;
                auto cpySrc = cast(uint) *rhs;
                auto cpyDst = cast(uint) *lhsRef;
                debug
                {
                    writefln("%d: MemCpy(dst: &Heap[%d], src: &Heap[%d], size: #%d", (ip-2), cpyDst, cpySrc, cpySize);
                }
                if (cpySrc != cpyDst)
                {

                    // assert(cpySize, "cpySize == 0");
                    assert(cpySrc, "cpySrc == 0");
                    assert(cpyDst, "cpyDst == 0");

                    assert(cpyDst >= cpySrc + cpySize || cpyDst + cpySize <= cpySrc, "Overlapping MemCpy is not supported --- src: " ~ to!string(cpySrc)
                        ~ " dst: " ~ to!string(cpyDst) ~ " size: " ~ to!string(cpySize));
                    heapPtr._heap[cpyDst .. cpyDst + cpySize] = heapPtr._heap[cpySrc .. cpySrc + cpySize];
                }
            }
            break;
        case LongInst.Comment:
            {
                ip += align4(hi) / 4;
            }
            break;
        case LongInst.StrEq:
            {
                cond = false;

                auto _lhs = cast(uint)*lhsRef;
                auto _rhs = cast(uint)*rhs;

                assert(_lhs && _rhs, "trying to deref nullPointers");
                if (_lhs == _rhs)
                {
                    cond = true;
                }
                else
                {
                    import ddmd.ctfe.ctfe_bc : SliceDescriptor;
                    immutable lhsLength = heapPtr._heap[_lhs + SliceDescriptor.LengthOffset];
                    immutable rhsLength = heapPtr._heap[_rhs + SliceDescriptor.LengthOffset];
                    if (lhsLength == rhsLength)
                    {
                        immutable lhsBase = heapPtr._heap[_lhs + SliceDescriptor.BaseOffset];
                        immutable rhsBase = heapPtr._heap[_rhs + SliceDescriptor.BaseOffset];
                        cond = true;
                        foreach (i; 0 .. lhsLength)
                        {
                            if (heapPtr._heap[rhsBase + i] != heapPtr._heap[lhsBase + i])
                            {
                                cond = false;
                                break;
                            }
                        }
                    }
                }
            }
            break;
        case LongInst.Line :
            {
                uint breakingOn;
                uint line = hi;
                lastLine = line;
                foreach(bl;breakLines)
                {
                    if (line == bl)
                    {
                        debug
                        if (!__ctfe)
                        {
                            import std.stdio;
                            writeln("breaking at: ", ip-2);

                        }
                        paused = true;
                    }
                    break;
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

static assert(interpret_(testRelJmp(), []) == imm32(12));
import ddmd.ctfe.bc_test;

static assert(test!BCGen());
