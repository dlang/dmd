module dmd.ctfe.bc;

import dmd.ctfe.bc_common;
import dmd.ctfe.bc_limits;
import dmd.ctfe.bc_abi;
import core.stdc.stdio;

/**
 * Written By Stefan Koch in 2016/2017/2019/2020/2021
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
            LongInst.ImmRsh, LongInst.ImmMod, LongInst, LongInst.BuiltinCall,
            LongInst.SetHighImm:
        {
            return InstKind.LongInstImm32;
        }

    }
} +/


static if (is(typeof({import dmd.globals : Loc; })))
{
    import dmd.globals : Loc;
}
else
{
    struct Loc {}
}

struct RetainedCall
{
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
    PrintValue,
    RelJmp,
    Ret32,
    Ret64,
    RetS32,
    RetS64,
    Not,

    Flg, // writes the conditionFlag into [lw >> 16]
    //End Former ShortInst

    Jmp,
    JmpFalse,
    JmpTrue,
    JmpZ,
    JmpNZ,

    PushCatch,
    PopCatch,
    Throw,

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
    Ult,
    Ule,
    Ugt,
    Uge,
    Udiv,
    Umod,
    And,
    And32,
    Or,
    Xor,
    Xor32,
    Lsh,
    Rsh,
    Set,

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
    ImmUlt,
    ImmUle,
    ImmUgt,
    ImmUge,
    ImmUdiv,
    ImmUmod,
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

    SetHighImm32,
    SetImm32,
    SetImm8,

    Call,
    HeapLoad8,
    HeapStore8,
    HeapLoad16,
    HeapStore16,
    HeapLoad32, ///SP[hi & 0xFFFF] = Heap[align4(SP[hi >> 16])]
    HeapStore32, ///Heap[align4(SP[hi & 0xFFFF)] = SP[hi >> 16]]
    HeapLoad64,
    HeapStore64,
    Alloc, /// SP[hi & 0xFFFF] = heapSize; heapSize += SP[hi >> 16]
    LoadFramePointer, // SP[lw >> 16] = FramePointer + hi
    MemCpy,

    BuiltinCall, // call a builtin.
    Cat,
    Comment,
    Line,
    File,
    //Push32,
/+
    PushImm32,
    Alloca
+/    
}
//Imm-Instructions and corresponding 2Operand instructions have to be in the same order
static immutable bc_order_errors = () {
    string result;
    auto members = [__traits(allMembers, LongInst)];
    auto d1 = LongInst.ImmAdd - LongInst.Add;
    auto d2 = LongInst.ImmMod - LongInst.Mod;
    if (d1 != d2)
    {
        result ~= "mismatch between ImmAdd - Add and ImmMod-Mod\nThis indicates Imm insts that do not correspond to 2stack insts";
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
* [6-7] Unused
* -----------------
* [8-31] Unused
* [32-48] Register (lhs)
* [48-64] Register (rhs)
* *************************
* ImmInstructions Layout :
* [0-6] Instruction
* [6-7] Unused
* ------------------------
* [8-15] Unused
* [16-32] Register (lhs)
* [32-64] Imm32 (rhs)
****************************
* 3 OperandInstuctions // memcpy
* [0-6] Instruction
* [6-7] Unused
* -----------------
* [8-31]  Register (extra_data)
* [32-48] Register (lhs)
* [48-64] Register (rhs) 
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

static assert(LongInst.max < 0x7F, "Instructions do not fit in 7 bits anymore");

static short isShortJump(const int offset) pure @safe
{
    assert(offset != 0, "A Jump to the Jump itself is invalid");

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

//static if (is(typeof(() { import dmd.declaration : FuncDeclaration; })))
//{
//    import dmd.declaration : FuncDeclaration;
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

    uint[] byteCode; // should be const but currently we need to assign to this;

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

enum max_call_depth = 2000;
struct BCGen
{
    uint[ushort.max] byteCodeArray;

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
    auto interpret(BCValue[] args, BCHeap* heapPtr = null) const @trusted
    {
        BCFunction f = BCFunction(cast(void*)fd,
            1,
            BCFunctionTypeEnum.Bytecode,
            parameterCount,
            cast(ushort)(temporaryCount + localCount + parameterCount),
            cast(uint[])byteCodeArray[0 .. ip]
        );
        return interpret_(0, args, heapPtr, &f, &calls[0]);
    }

@safe:

    string[ushort] stackMap() pure
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
//        import dmd.declaration : FuncDeclaration;
        ip = BCAddr(4);
        //() @trusted { assert(!insideFunction, fd ? (cast(FuncDeclaration)fd).toChars.fromStringz : "fd:null"); } ();
        //TODO figure out why the above assert cannot always be true ... see issue 7667
        insideFunction = true;
        functionId = fnId;
    }

//pure:
    /// The emitLongInst functions have to be kept up to date if
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

    void destroyTemporary(BCValue tmp)
    {
        assert(isStackValueOrParameter(tmp), "tmporary has to be stack-value");
        uint sz;
        if (isBasicBCType(tmp.type))
        {
            sz = align4(basicTypeSize(tmp.type.type));
        }
        else
        {
            sz = 4;
        }
        if (sp - sz == tmp.stackAddr)
        {
            // this is the last thing we pushed on
            // free the stack space immediately.
            sp -= sz;
        }
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
        localCount = 0;

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

        // import std.stdio; writeln("bc: ", printInstructions(byteCodeArray[4 .. ip]));

        return result;
    }

    BCValue genParameter(BCType bct, string name = null)
    {
        auto p = BCValue(BCParameter(++parameterCount, bct, sp));
        p.name = name;
        // everything that's not a basic type is a pointer
        // and therefore has size 4
        auto pSize = 4;

        if (isBasicBCType(bct))
        {
            pSize = align4(basicTypeSize(bct.type));
        }

        assert(pSize == 4 || pSize == 8, "we only support 4byte and 8byte params");

        sp += pSize;

        return p;
    }

    BCAddr beginJmp()
    {
        BCAddr atIp = ip;
        ip += 2;
        return atIp;
    }

    StackAddr currSp()
    {
        return sp;
    }

    void LoadFramePointer(BCValue intoHere, int offset)
    {
        emitLongInst(LongInst.LoadFramePointer, intoHere.stackAddr, imm32(offset).imm32);
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

    void Jmp(BCLabel target)
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

    void Alloc(BCValue heapPtr, BCValue size, uint line = __LINE__)
    {
        assert(size.type.type == BCTypeEnum.u32, "Size for alloc needs to be an u32" ~ " called by:" ~ itos(line));
        if (size.vType == BCValueType.Immediate)
        {
            size = pushOntoStack(size);
        }
        assert(isStackValueOrParameter(size));
        assert(isStackValueOrParameter(heapPtr));

        emitLongInst(LongInst.Alloc, heapPtr.stackAddr, size.stackAddr);
    }

    void Assert(BCValue value, BCValue err, uint l = __LINE__)
    {
        BCValue _msg;
        if (isStackValueOrParameter(err))
        {
            assert(0, "err.vType is not Error but: " ~ enumToString(err.vType));
        }

        if (value)
        {
            emitLongInst(LongInst.Assert, pushOntoStack(value).stackAddr, err.imm32);
        }
        else
        {
            assert(0, "BCValue.init is no longer a valid value for assert -- fromLine: " ~ itos(l));
        }

    }

    void MemCpy(BCValue dst, BCValue src, BCValue size)
    {
        size = pushOntoStack(size);
        src = pushOntoStack(src);
        dst = pushOntoStack(dst);

        emitLongInst(LongInst.MemCpy, size.stackAddr, dst.stackAddr, src.stackAddr);
    }


    void outputBytes(const (char)[] s)
    {
        outputBytes(cast(const ubyte[]) s);
    }

    void outputBytes (const ubyte[] bytes)
    {
        auto len = bytes.length;
        size_t idx = 0;

        while (len >= 4)
        {
            byteCodeArray[ip++] =
                bytes[idx+0] << 0 |
                bytes[idx+1] << 8 |
                bytes[idx+2] << 16 |
                bytes[idx+3] << 24;

            idx += 4;
            len -= 4;
        }

        uint lastField;

        final switch(len)
        {
            case 3 :
                lastField |= bytes[idx+2] << 16;
                goto case;
            case 2 :
                lastField |= bytes[idx+1] << 8;
                goto case;
            case 1 :
                lastField |= bytes[idx+0] << 0;
                byteCodeArray[ip++] = lastField;
                goto case;
            case 0 :
                break;
        }
    }

    void File(string filename)
    {
        auto filenameLength = cast(uint) filename.length;

        emitLongInst(LongInst.File, StackAddr.init, Imm32(filenameLength));

        outputBytes(filename);
    }

    void Line(uint line)
    {
         emitLongInst(LongInst.Line, StackAddr(0), Imm32(line));
    }

    void Comment(lazy const (char)[] comment)
    {
        debug
        {
            uint commentLength = cast(uint) comment.length;

            emitLongInst(LongInst.Comment, StackAddr.init, Imm32(commentLength));

            outputBytes(comment);
        }
    }

    void Prt(BCValue value, bool isString = false)
    {
        if (value.vType == BCValueType.Immediate)
            value = pushOntoStack(value);

        byteCodeArray[ip] = ShortInst16Ex(LongInst.PrintValue, isString, value.stackAddr);
        byteCodeArray[ip + 1] = 0;
        ip += 2;
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

        BCTypeEnum commonType = commonTypeEnum(lhs.type.type, rhs.type.type);

        // FIXME Implement utf8 <-> utf32 conversion
        assert(commonType == BCTypeEnum.i32 || commonType == BCTypeEnum.i64
            || commonType == BCTypeEnum.u32 || commonType == BCTypeEnum.u64
            || commonType == BCTypeEnum.f23 || commonType == BCTypeEnum.c32
            || commonType == BCTypeEnum.c8  || commonType == BCTypeEnum.f52,
            "only i32, i64, f23, f52, is supported for now not: " ~ enumToString(commonType));
        //assert(lhs.type.type == rhs.type.type, enumToString(lhs.type.type) ~ " != " ~ enumToString(rhs.type.type));

        if (lhs.vType == BCValueType.Immediate)
        {
            lhs = pushOntoStack(lhs);
        }

        if (resultTypeEnum !is null)
            *resultTypeEnum = commonType;

        if (lhs.type.type == BCTypeEnum.f23)
        {
            if(rhs.type.type == BCTypeEnum.i32 || rhs.type.type == BCTypeEnum.u32)
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
            else if (rhs.type.type == BCTypeEnum.f52)
            {
                rhs = castTo(rhs, lhs.type.type);
            }
            else
                assert(0, "did not expect type " ~ enumToString(rhs.type.type) ~ "to be used in a float expression");
            if (inst != LongInst.Set)
            {
                // if (!__ctfe) () @trusted { printf("newInst: %s\n", enumToString(inst).ptr); } ();
                inst += (LongInst.FAdd32 - LongInst.Add);
                // if (!__ctfe) () @trusted { printf("newInst: %s\n", enumToString(inst).ptr); } ();
            }
        }
        else if (lhs.type.type == BCTypeEnum.f52)
        {
            if(rhs.type.type != BCTypeEnum.f52)
            {
                // TOOD there was
                // assert (rhs.type.type == BCTypeEnum.f52)
                // here before .... check if this is an invariant
                rhs = castTo(rhs, BCTypeEnum.f52);
            }

            rhs = pushOntoStack(rhs);
            if (inst != LongInst.Set)
            {
                // if (!__ctfe) () @trusted { printf("newInst: %s\n", enumToString(inst).ptr); } ();
                inst += (LongInst.FAdd64 - LongInst.Add);
                // if (!__ctfe) () @trusted { printf("newInst: %s\n", enumToString(inst).ptr); } ();
            }
        }
        else if (rhs.vType == BCValueType.Immediate)
        {
            const imm64s = (basicTypeSize(rhs.type.type) == 8 ? cast(long)rhs.imm64 : 0);
            if  (basicTypeSize(rhs.type.type) <= 4 || (imm64s <= int.max && imm64s > -int.max))
            {
                //Change the instruction into the corresponding Imm Instruction;
                if (inst != LongInst.Set)
                {
                    // if (!__ctfe) () @trusted { printf("newInst: %s\n", enumToString(inst).ptr); } ();
                    inst += (LongInst.ImmAdd - LongInst.Add);
                    // if (!__ctfe) () @trusted { printf("newInst: %s\n", enumToString(inst).ptr); } ();
                }
                else
                {
                    inst = LongInst.SetImm32;
                }
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
            assert(0, "Cannot handle: " ~ enumToString(rhs.vType));
        }
    }

    void Set(BCValue lhs, BCValue rhs)
    {
        assert(isStackValueOrParameter(lhs), "Set lhs is has to be a StackValue. Not: " ~ enumToString(lhs.vType));
        assert(rhs.vType == BCValueType.Immediate || isStackValueOrParameter(rhs), "Set rhs is has to be a StackValue or Imm not: " ~ rhs.vType.enumToString);

        if (rhs.vType == BCValueType.Immediate && (rhs.type.type == BCTypeEnum.i64 || rhs.type.type == BCTypeEnum.u64 || rhs.type.type == BCTypeEnum.f52))
        {
            emitLongInst(LongInst.SetImm32, lhs.stackAddr, imm32(rhs.imm64 & uint.max).imm32);
            if ((((rhs.type.type == BCTypeEnum.u64 || rhs.type.type == BCTypeEnum.i64)) && rhs.imm64 > uint.max) || rhs.type.type == BCTypeEnum.f52) // if there are high bits
                emitLongInst(LongInst.SetHighImm32, lhs.stackAddr, Imm32(rhs.imm64 >> 32));
        }

        else if (lhs != rhs) // do not emit self assignments;
        {
            emitArithInstruction(LongInst.Set, lhs, rhs);
        }
    }

    void SetHigh(BCValue lhs, BCValue rhs)
    {
        assert(isStackValueOrParameter(lhs), "SetHigh lhs is has to be a StackValue");
        assert(rhs.vType == BCValueType.Immediate || isStackValueOrParameter(rhs), "SetHigh rhs is has to be a StackValue or Imm");
        assert(0, "SetHigh is not implemented");
        //two cases :
        //    lhs.type.size == 4 && rhs.type.size == 8
        // OR
        //    lhs.type.size == 8 && rhs.type.size == 4

    }

    void Ult3(BCValue result, BCValue lhs, BCValue rhs)
    {
        assert(result.vType == BCValueType.Unknown
            || isStackValueOrParameter(result),
            "The result for this must be Empty or a StackValue");
        emitArithInstruction(LongInst.Ult, lhs, rhs);

        if (isStackValueOrParameter(result))
        {
            emitFlg(result);
        }
    }

    void Ule3(BCValue result, BCValue lhs, BCValue rhs)
    {
        assert(result.vType == BCValueType.Unknown
            || isStackValueOrParameter(result),
            "The result for this must be Empty or a StackValue");
        emitArithInstruction(LongInst.Ule, lhs, rhs);

        if (isStackValueOrParameter(result))
        {
            emitFlg(result);
        }
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

    void Ugt3(BCValue result, BCValue lhs, BCValue rhs)
    {
        assert(result.vType == BCValueType.Unknown
            || isStackValueOrParameter(result),
            "The result for this must be Empty or a StackValue");
        emitArithInstruction(LongInst.Ugt, lhs, rhs);
        if (isStackValueOrParameter(result))
        {
            emitFlg(result);
        }
    }

    void Uge3(BCValue result, BCValue lhs, BCValue rhs)
    {
        assert(result.vType == BCValueType.Unknown
            || isStackValueOrParameter(result),
            "The result for this must be Empty or a StackValue");
        emitArithInstruction(LongInst.Uge, lhs, rhs);
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
            "The result for this must be Empty or a StackValue not " ~ enumToString(result.vType) );
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

        // Prt(result); Prt(lhs); Prt(rhs);

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

    void Udiv3(BCValue result, BCValue lhs, BCValue rhs)
    {
        assert(result.vType != BCValueType.Immediate, "Cannot div to Immediate");

        result = (result ? result : lhs);
        if (lhs != result)
        {
            Set(result, lhs);
        }
        emitArithInstruction(LongInst.Udiv, result, rhs, &result.type.type);
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
        assert(result.vType != BCValueType.Immediate, "Cannot xor to Immediate");

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
        assert(result.vType != BCValueType.Immediate, "Cannot mod to Immediate");

        result = (result ? result : lhs);
        if (lhs != result)
        {
            Set(result, lhs);
        }
        emitArithInstruction(LongInst.Mod, result, rhs, &result.type.type);
    }

    void Umod3(BCValue result, BCValue lhs, BCValue rhs)
    {
        assert(result.vType != BCValueType.Immediate, "Cannot mod to Immediate");

        result = (result ? result : lhs);
        if (lhs != result)
        {
            Set(result, lhs);
        }
        emitArithInstruction(LongInst.Umod, result, rhs, &result.type.type);
    }

    void Call(BCValue result, BCValue fn, BCValue[] args, Loc l = Loc.init)
    {
        auto call_id = pushOntoStack(imm32(callCount + 1)).stackAddr;
        calls[callCount++] = RetainedCall(fn, args, functionId, ip, sp, l);
        emitLongInst(LongInst.Call, result.stackAddr, call_id);
    }

    void Load8(BCValue _to, BCValue from)
    {
        if (!isStackValueOrParameter(from))
        {
            from = pushOntoStack(from);
        }
        if (!isStackValueOrParameter(_to))
        {
            _to = pushOntoStack(_to);
        }
        assert(isStackValueOrParameter(_to), "to has the vType " ~ enumToString(_to.vType));
        assert(isStackValueOrParameter(from), "from has the vType " ~ enumToString(from.vType));
        
        emitLongInst(LongInst.HeapLoad8, _to.stackAddr, from.stackAddr);
    }

    void Store8(BCValue _to, BCValue value)
    {
        if (!isStackValueOrParameter(value))
        {
            value = pushOntoStack(value);
        }

        if (!isStackValueOrParameter(_to))
        {
            _to = pushOntoStack(_to);
        }

        assert(isStackValueOrParameter(_to), "to has the vType " ~ enumToString(_to.vType));
        assert(isStackValueOrParameter(value), "value has the vType " ~ enumToString(value.vType));

        emitLongInst(LongInst.HeapStore8, _to.stackAddr, value.stackAddr);
    }

    void Load16(BCValue _to, BCValue from)
    {
        if (!isStackValueOrParameter(from))
        {
            from = pushOntoStack(from);
        }
        if (!isStackValueOrParameter(_to))
        {
            _to = pushOntoStack(_to);
        }
        assert(isStackValueOrParameter(_to), "to has the vType " ~ enumToString(_to.vType));
        assert(isStackValueOrParameter(from), "from has the vType " ~ enumToString(from.vType));
        
        emitLongInst(LongInst.HeapLoad16, _to.stackAddr, from.stackAddr);
    }
    
    void Store16(BCValue _to, BCValue value)
    {
        if (!isStackValueOrParameter(value))
        {
            value = pushOntoStack(value);
        }
        
        if (!isStackValueOrParameter(_to))
        {
            _to = pushOntoStack(_to);
        }
        
        assert(isStackValueOrParameter(_to), "to has the vType " ~ enumToString(_to.vType));
        assert(isStackValueOrParameter(value), "value has the vType " ~ enumToString(value.vType));
        
        emitLongInst(LongInst.HeapStore16, _to.stackAddr, value.stackAddr);
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
        
        assert(isStackValueOrParameter(_to), "to has the vType " ~ enumToString(_to.vType));
        assert(isStackValueOrParameter(from), "from has the vType " ~ enumToString(from.vType));
        
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

        assert(isStackValueOrParameter(_to), "to has the vType " ~ enumToString(_to.vType));
        assert(isStackValueOrParameter(value), "value has the vType " ~ enumToString(value.vType));

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
        assert(isStackValueOrParameter(_to), "to has the vType " ~ enumToString(_to.vType));
        assert(isStackValueOrParameter(from), "from has the vType " ~ enumToString(from.vType));

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

        assert(isStackValueOrParameter(_to), "to has the vType " ~ enumToString(_to.vType));
        assert(isStackValueOrParameter(value), "value has the vType " ~ enumToString(value.vType));

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
                debug{assert(0, "me no have no cast for targetType " ~ enumToString(targetType));}
            //break;
        }

        return lhs;
    }

    BCValue pushOntoStack(BCValue val)
    {
        if (!__ctfe) debug { import std.stdio; writeln("pushOntoStack: ", val); }
        if (!isStackValueOrParameter(val))
        {
            auto stackref = BCValue(currSp(), val.type);
            assert(isStackValueOrParameter(stackref));
            Set(stackref.u32, val);

            sp += align4(basicTypeSize(val.type.type));
            return stackref;
        }
        else
        {
            return val;
        }
    }

    void Throw(BCValue e)
    {
        assert(isStackValueOrParameter(e));
        byteCodeArray[ip] = ShortInst16(LongInst.Throw, e.stackAddr);
        byteCodeArray[ip + 1] = 0;
        ip += 2;
    }

    void PushCatch()
    {
        byteCodeArray[ip] = ShortInst16(LongInst.PushCatch, 0);
        byteCodeArray[ip + 1] = 0;
        ip += 2;
    }

    void PopCatch()
    {
        byteCodeArray[ip] = ShortInst16(LongInst.PopCatch, 0);
        byteCodeArray[ip + 1] = 0;
        ip += 2;
    }

    void Ret(BCValue val)
    {
        LongInst inst = basicTypeSize(val.type.type) == 8 ? LongInst.Ret64 : LongInst.Ret32;
        val = pushOntoStack(val);
        if (isStackValueOrParameter(val))
        {
            byteCodeArray[ip] = ShortInst16(inst, val.stackAddr);
            byteCodeArray[ip + 1] = 0;
            ip += 2;
        }
        else
        {
            assert(0, "I cannot deal with this type of return" ~ enumToString(val.vType));
        }
    }
/+
    void Push(BCValue v)
    {
        const sz = basicTypeSize(v.typ.type);
        assert(sz >= 1 && sz <= 4);
        if (v.vType == BCValueType.Immediate)
        {
            byteCodeArray[ip] = LongInst.PushImm32;
            byteCodeArray[ip + 1] = v.imm32.imm32;
        }
        else
        {
            byteCodeArray[ip] = ShortInst16(LongInst.Push32, v.stackAddr);
            byteCodeArray[ip + 1] = 0;
        }
        ip += 2;
    }
+/
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

    void F32ToI(BCValue result, BCValue rhs)
    {
        assert(isStackValueOrParameter(result));
        assert(isStackValueOrParameter(rhs));

        emitLongInst(LongInst.F32ToI, result.stackAddr, rhs.stackAddr);
    }

    void F64ToI(BCValue result, BCValue rhs)
    {
        assert(isStackValueOrParameter(result));
        assert(isStackValueOrParameter(rhs));

        emitLongInst(LongInst.F64ToI, result.stackAddr, rhs.stackAddr);
    }

    void F32ToF64(BCValue result, BCValue rhs)
    {
        assert(isStackValueOrParameter(result));
        assert(isStackValueOrParameter(rhs));

        emitLongInst(LongInst.F32ToF64, result.stackAddr, rhs.stackAddr);

    }

    void F64ToF32(BCValue result, BCValue rhs)
    {
        assert(isStackValueOrParameter(result));
        assert(isStackValueOrParameter(rhs));

        emitLongInst(LongInst.F64ToF32, result.stackAddr, rhs.stackAddr);
    }


    void StrEq3(BCValue result, BCValue lhs, BCValue rhs)
    {
        assert(result.vType == BCValueType.Unknown
            || isStackValueOrParameter(result),
            "The result for this must be Empty or a StackValue not: " ~ enumToString(result.vType));
        if (lhs.vType == BCValueType.Immediate)
        {
            lhs = pushOntoStack(lhs);
        }
        if (rhs.vType == BCValueType.Immediate)
        {
            rhs = pushOntoStack(rhs);
        }
        assert(isStackValueOrParameter(lhs),
            "The lhs of StrEq3 is not a StackValue " ~ enumToString(rhs.vType));
        assert(isStackValueOrParameter(rhs),
            "The rhs of StrEq3 not a StackValue" ~ enumToString(rhs.vType));

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

string printInstructions(const uint[] arr, const string[ushort] stackMap = null) pure @trusted
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
        if (name && *name !is null)
        {
            return *name;
        }
    }

    return "SP[" ~ itos(addr) ~ "]";
}

string printInstructions(const uint* startInstructions, uint length, const string[ushort] stackMap = null) pure
{

    char[] result = cast(char[])"StartInstructionDump: \n";
    uint pos = 0;

    bool has4ByteOffset;
    if (length > 4 && startInstructions[0 .. 4] == [0, 0, 0, 0])
    {
        has4ByteOffset = true;
        //length -= 4;
        //startInstructions += 4;
        //pos += 4;
    }

    result ~= "Length : " ~ itos(cast(int)length) ~ "\n";
    auto arr = startInstructions[0 .. length];

    void printText(uint textLength)
    {
        const lengthOverFour = textLength / 4;
        auto restLength =  textLength % 4;
        const alignedLength = align4(textLength) / 4;
        
        // alignLengthBy2
        assert(alignedLength <= length, "text (" ~ itos(alignedLength) ~") longer then code (" ~ itos(length) ~ ")");
        auto insertPos = result.length;
        result.length += textLength;
        
        result[insertPos .. insertPos + textLength] = '_';
        
        foreach(chars; arr[pos .. pos + lengthOverFour])
        {
            result[insertPos++] = chars >> 0x00 & 0xFF;
            result[insertPos++] = chars >> 0x08 & 0xFF;
            result[insertPos++] = chars >> 0x10 & 0xFF;
            result[insertPos++] = chars >> 0x18 & 0xFF;
        }
        
        int shiftAmount = 0;
        const lastChars = restLength ? arr[pos + lengthOverFour] : 0;
        
        while(restLength--)
        {
            result[insertPos++] = lastChars >> shiftAmount & 0xFF;
            shiftAmount += 8;
        }
        
        pos += alignedLength;
        length -= alignedLength;
    }

    while (length--)
    {
        uint lw = arr[pos];
        result ~= itos(pos) ~ ":\t";
        ++pos;
        if (lw == 0)
        {
            result ~= "0x0 0x0 0x0 0x0\n";
            continue;
        }

        // We have a long instruction

        --length;
        const uint hi = arr[pos];
        const int imm32c = (*cast(int*)&arr[pos++]);

        final switch (cast(LongInst)(lw & InstMask))
        {
        case LongInst.SetHighImm32:
            {
                result ~= "SetHigh " ~ localName(stackMap, lw >> 16) ~ ", #" ~ itos(hi) ~ "\n";
            }
            break;

        case LongInst.SetImm32:
            {
                result ~= "Set " ~ localName(stackMap, lw >> 16) ~ ", #" ~ itos(hi) ~ "\n";
            }
            break;

         case LongInst.SetImm8:
            {
                result ~= "Set " ~ localName(stackMap, lw >> 16) ~ ", #" ~ itos(hi) ~ "\n";
            }
            break;

        case LongInst.ImmAdd:
            {
                result ~= "Add " ~ localName(stackMap, lw >> 16) ~ ", #" ~ itos(imm32c) ~ "\n";
            }
            break;
        case LongInst.ImmSub:
            {
                result ~= "Sub " ~ localName(stackMap, lw >> 16) ~ ", #" ~ itos(imm32c) ~ "\n";
            }
            break;
        case LongInst.ImmMul:
            {
                result ~= "Mul " ~ localName(stackMap, lw >> 16) ~ ", #" ~ itos(imm32c) ~ "\n";
            }
            break;
        case LongInst.ImmDiv:
            {
                result ~= "Div " ~ localName(stackMap, lw >> 16) ~ ", #" ~ itos(imm32c) ~ "\n";
            }
            break;

        case LongInst.ImmUdiv:
            {
                result ~= "Udiv " ~ localName(stackMap, lw >> 16) ~ ", #" ~ itos(hi) ~ "\n";
            }
            break;

        case LongInst.ImmAnd:
            {
                result ~= "And " ~ localName(stackMap, lw >> 16) ~ ", #" ~ itos(hi) ~ "\n";
            }
            break;
        case LongInst.ImmAnd32:
            {
                result ~= "And32 " ~ localName(stackMap, lw >> 16) ~ ", #" ~ itos(hi) ~ "\n";
            }
            break;
        case LongInst.ImmOr:
            {
                result ~= "Or " ~ localName(stackMap, lw >> 16) ~ ", #" ~ itos(hi) ~ "\n";
            }
            break;
        case LongInst.ImmXor:
            {
                result ~= "Xor " ~ localName(stackMap, lw >> 16) ~ ", #" ~ itos(hi) ~ "\n";
            }
            break;
        case LongInst.ImmXor32:
            {
                result ~= "Xor32 " ~ localName(stackMap, lw >> 16) ~ ", #" ~ itos(hi) ~ "\n";
            }
            break;
        case LongInst.ImmLsh:
            {
                result ~= "Lsh " ~ localName(stackMap, lw >> 16) ~ ", #" ~ itos(hi) ~ "\n";
            }
            break;
        case LongInst.ImmRsh:
            {
                result ~= "Rsh " ~ localName(stackMap, lw >> 16) ~ ", #" ~ itos(hi) ~ "\n";
            }
            break;

        case LongInst.ImmMod:
            {
                result ~= "Mod " ~ localName(stackMap, lw >> 16) ~ ", #" ~ itos(imm32c) ~ "\n";
            }
            break;

        case LongInst.ImmUmod:
            {
                result ~= "Umod " ~ localName(stackMap, lw >> 16) ~ ", #" ~ itos(hi) ~ "\n";
            }
            break;

        case LongInst.ImmEq:
            {
                result ~= "Eq " ~ localName(stackMap, lw >> 16) ~ ", #" ~ itos(imm32c) ~ "\n";
            }
            break;
        case LongInst.ImmNeq:
            {
                result ~= "Neq " ~ localName(stackMap, lw >> 16) ~ ", #" ~ itos(imm32c) ~ "\n";
            }
            break;

        case LongInst.ImmUlt:
            {
                result ~= "Ult " ~ localName(stackMap, lw >> 16) ~ ", #" ~ itos(hi) ~ "\n";
            }
            break;
        case LongInst.ImmUgt:
            {
                result ~= "Ugt " ~ localName(stackMap, lw >> 16) ~ ", #" ~ itos(hi) ~ "\n";
            }
            break;
        case LongInst.ImmUle:
            {
                result ~= "Ule " ~ localName(stackMap, lw >> 16) ~ ", #" ~ itos(hi) ~ "\n";
            }
            break;
        case LongInst.ImmUge:
            {
                result ~= "Uge " ~ localName(stackMap, lw >> 16) ~ ", #" ~ itos(hi) ~ "\n";
            }
            break;

        case LongInst.ImmLt:
            {
                result ~= "Lt " ~ localName(stackMap, lw >> 16) ~ ", #" ~ itos(imm32c) ~ "\n";
            }
            break;
        case LongInst.ImmGt:
            {
                result ~= "Gt " ~ localName(stackMap, lw >> 16) ~ ", #" ~ itos(imm32c) ~ "\n";
            }
            break;
        case LongInst.ImmLe:
            {
                result ~= "Le " ~ localName(stackMap, lw >> 16) ~ ", #" ~ itos(imm32c) ~ "\n";
            }
            break;
        case LongInst.ImmGe:
            {
                result ~= "Ge " ~ localName(stackMap, lw >> 16) ~ ", #" ~ itos(imm32c) ~ "\n";
            }
            break;

        case LongInst.Add:
            {
                result ~= "Add " ~ localName(stackMap, hi & 0xFFFF) ~ ", " ~ localName(stackMap, hi >> 16) ~ "\n";
            }
            break;
        case LongInst.Sub:
            {
                result ~= "Sub " ~ localName(stackMap, hi & 0xFFFF) ~ ", " ~ localName(stackMap, hi >> 16) ~ "\n";
            }
            break;
        case LongInst.Mul:
            {
                result ~= "Mul " ~ localName(stackMap, hi & 0xFFFF) ~ ", " ~ localName(stackMap, hi >> 16) ~ "\n";
            }
            break;
        case LongInst.Div:
            {
                result ~= "Div " ~ localName(stackMap, hi & 0xFFFF) ~ ", " ~ localName(stackMap, hi >> 16) ~ "\n";
            }
            break;
        case LongInst.Udiv:
            {
                result ~= "Udiv " ~ localName(stackMap, hi & 0xFFFF) ~ ", " ~ localName(stackMap, hi >> 16) ~ "\n";
            }
            break;
        case LongInst.Mod:
            {
                result ~= "Mod " ~ localName(stackMap, hi & 0xFFFF) ~ ", " ~ localName(stackMap, hi >> 16) ~ "\n";
            }
            break;
        case LongInst.Umod:
            {
                result ~= "Umod " ~ localName(stackMap, hi & 0xFFFF) ~ ", " ~ localName(stackMap, hi >> 16) ~ "\n";
            }
            break;
        case LongInst.And:
            {
                result ~= "And " ~ localName(stackMap, hi & 0xFFFF) ~ ", " ~ localName(stackMap, hi >> 16) ~ "\n";
            }
            break;
        case LongInst.And32:
            {
                result ~= "And32 " ~ localName(stackMap, hi & 0xFFFF) ~ ", " ~ localName(stackMap, hi >> 16) ~ "\n";
            }
            break;
        case LongInst.Or:
            {
                result ~= "Or " ~ localName(stackMap, hi & 0xFFFF) ~ ", " ~ localName(stackMap, hi >> 16) ~ "\n";
            }
            break;
        case LongInst.Xor:
            {
                result ~= "Xor " ~ localName(stackMap, hi & 0xFFFF) ~ ", " ~ localName(stackMap, hi >> 16) ~ "\n";
            }
            break;
        case LongInst.Xor32:
            {
                result ~= "Xor32 " ~ localName(stackMap, hi & 0xFFFF) ~ ", " ~ localName(stackMap, hi >> 16) ~ "\n";
            }
            break;
        case LongInst.Lsh:
            {
                result ~= "Lsh " ~ localName(stackMap, hi & 0xFFFF) ~ ", " ~ localName(stackMap, hi >> 16) ~ "\n";
            }
            break;
        case LongInst.Rsh:
            {
                result ~= "Rsh " ~ localName(stackMap, hi & 0xFFFF) ~ ", " ~ localName(stackMap, hi >> 16) ~ "\n";
            }
            break;

        case LongInst.FEq32:
            {
                result ~= "FEq32 " ~ localName(stackMap, hi & 0xFFFF) ~ ", " ~ localName(stackMap, hi >> 16) ~ "\n";
            }
            break;
        case LongInst.FNeq32:
            {
                result ~= "FNeq32 " ~ localName(stackMap, hi & 0xFFFF) ~ ", " ~ localName(stackMap, hi >> 16) ~ "\n";
            }
            break;
        case LongInst.FLt32:
            {
                result ~= "FLt32 " ~ localName(stackMap, hi & 0xFFFF) ~ ", " ~ localName(stackMap, hi >> 16) ~ "\n";
            }
            break;
        case LongInst.FLe32:
            {
                result ~= "FLe32 " ~ localName(stackMap, hi & 0xFFFF) ~ ", " ~ localName(stackMap, hi >> 16) ~ "\n";
            }
            break;
        case LongInst.FGt32:
            {
                result ~= "FGt32 " ~ localName(stackMap, hi & 0xFFFF) ~ ", " ~ localName(stackMap, hi >> 16) ~ "\n";
            }
            break;
        case LongInst.FGe32:
            {
                result ~= "FGe32 " ~ localName(stackMap, hi & 0xFFFF) ~ ", " ~ localName(stackMap, hi >> 16) ~ "\n";
            }
            break;
        case LongInst.F32ToF64:
            {
                result ~= "F32ToF64 " ~ localName(stackMap, hi & 0xFFFF) ~ ", " ~ localName(stackMap, hi >> 16) ~ "\n";
            }
            break;
        case LongInst.F32ToI:
            {
                result ~= "F32ToI " ~ localName(stackMap, hi & 0xFFFF) ~ ", " ~ localName(stackMap, hi >> 16) ~ "\n";
            }
            break;
        case LongInst.IToF32:
            {
                result ~= "IToF32 " ~ localName(stackMap, hi & 0xFFFF) ~ ", " ~ localName(stackMap, hi >> 16) ~ "\n";
            }
            break;
        case LongInst.FAdd32:
            {
                result ~= "FAdd32 " ~ localName(stackMap, hi & 0xFFFF) ~ ", " ~ localName(stackMap, hi >> 16) ~ "\n";
            }
            break;
        case LongInst.FSub32:
            {
                result ~= "FSub32 " ~ localName(stackMap, hi & 0xFFFF) ~ ", " ~ localName(stackMap, hi >> 16) ~ "\n";
            }
            break;
        case LongInst.FMul32:
            {
                result ~= "FMul32 " ~ localName(stackMap, hi & 0xFFFF) ~ ", " ~ localName(stackMap, hi >> 16) ~ "\n";
            }
            break;
        case LongInst.FDiv32:
            {
                result ~= "FDiv32 " ~ localName(stackMap, hi & 0xFFFF) ~ ", " ~ localName(stackMap, hi >> 16) ~ "\n";
            }
            break;
        case LongInst.FMod32:
            {
                result ~= "FMod32 " ~ localName(stackMap, hi & 0xFFFF) ~ ", " ~ localName(stackMap, hi >> 16) ~ "\n";
            }
            break;

        case LongInst.FEq64:
            {
                result ~= "FEq64 " ~ localName(stackMap, hi & 0xFFFF) ~ ", " ~ localName(stackMap, hi >> 16) ~ "\n";
            }
            break;
        case LongInst.FNeq64:
            {
                result ~= "FNeq64 " ~ localName(stackMap, hi & 0xFFFF) ~ ", " ~ localName(stackMap, hi >> 16) ~ "\n";
            }
            break;
        case LongInst.FLt64:
            {
                result ~= "FLt64 " ~ localName(stackMap, hi & 0xFFFF) ~ ", " ~ localName(stackMap, hi >> 16) ~ "\n";
            }
            break;
        case LongInst.FLe64:
            {
                result ~= "FLe64 " ~ localName(stackMap, hi & 0xFFFF) ~ ", " ~ localName(stackMap, hi >> 16) ~ "\n";
            }
            break;
        case LongInst.FGt64:
            {
                result ~= "FGt64 " ~ localName(stackMap, hi & 0xFFFF) ~ ", " ~ localName(stackMap, hi >> 16) ~ "\n";
            }
            break;
        case LongInst.FGe64:
            {
                result ~= "FGe64 " ~ localName(stackMap, hi & 0xFFFF) ~ ", " ~ localName(stackMap, hi >> 16) ~ "\n";
            }
            break;
        case LongInst.F64ToF32:
            {
                result ~= "F64ToF32 " ~ localName(stackMap, hi & 0xFFFF) ~ ", " ~ localName(stackMap, hi >> 16) ~ "\n";
            }
            break;
        case LongInst.F64ToI:
            {
                result ~= "F64ToI " ~ localName(stackMap, hi & 0xFFFF) ~ ", " ~ localName(stackMap, hi >> 16) ~ "\n";
            }
            break;
        case LongInst.IToF64:
            {
                result ~= "IToF64 " ~ localName(stackMap, hi & 0xFFFF) ~ ", " ~ localName(stackMap, hi >> 16) ~ "\n";
            }
            break;
        case LongInst.FAdd64:
            {
                result ~= "FAdd64 " ~ localName(stackMap, hi & 0xFFFF) ~ ", " ~ localName(stackMap, hi >> 16) ~ "\n";
            }
            break;
        case LongInst.FSub64:
            {
                result ~= "FSub64 " ~ localName(stackMap, hi & 0xFFFF) ~ ", " ~ localName(stackMap, hi >> 16) ~ "\n";
            }
            break;
        case LongInst.FMul64:
            {
                result ~= "FMul64 " ~ localName(stackMap, hi & 0xFFFF) ~ ", " ~ localName(stackMap, hi >> 16) ~ "\n";
            }
            break;
        case LongInst.FDiv64:
            {
                result ~= "FDiv64 " ~ localName(stackMap, hi & 0xFFFF) ~ ", " ~ localName(stackMap, hi >> 16) ~ "\n";
            }
            break;
        case LongInst.FMod64:
            {
                result ~= "FMod64 " ~ localName(stackMap, hi & 0xFFFF) ~ ", " ~ localName(stackMap, hi >> 16) ~ "\n";
            }
            break;

        case LongInst.Assert:
            {
                result ~= "Assert " ~ localName(stackMap, lw >> 16) ~ ", ErrNo #" ~  itos(hi) ~ "\n";
            }
            break;
        case LongInst.StrEq:
            {
                result ~= "StrEq " ~ localName(stackMap, hi & 0xFFFF) ~ ", " ~ localName(stackMap, hi >> 16) ~ "\n";
            }
            break;
        case LongInst.Eq:
            {
                result ~= "Eq " ~ localName(stackMap, hi & 0xFFFF) ~ ", " ~ localName(stackMap, hi >> 16) ~ "\n";
            }
            break;
        case LongInst.Neq:
            {
                result ~= "Neq " ~ localName(stackMap, hi & 0xFFFF) ~ ", " ~ localName(stackMap, hi >> 16) ~ "\n";
            }
            break;

        case LongInst.Set:
            {
                result ~= "Set " ~ localName(stackMap, hi & 0xFFFF) ~ ", " ~ localName(stackMap, hi >> 16) ~ "\n";
            }
            break;

        case LongInst.Ule:
            {
                result ~= "Ule " ~ localName(stackMap, hi & 0xFFFF) ~ ", " ~ localName(stackMap, hi >> 16) ~ "\n";
            }
            break;
        case LongInst.Ult:
            {
                result ~= "Ult " ~ localName(stackMap, hi & 0xFFFF) ~ ", " ~ localName(stackMap, hi >> 16) ~ "\n";
            }
            break;
        case LongInst.Le:
            {
                result ~= "Le " ~ localName(stackMap, hi & 0xFFFF) ~ ", " ~ localName(stackMap, hi >> 16) ~ "\n";
            }
            break;
        case LongInst.Lt:
            {
                result ~= "Lt " ~ localName(stackMap, hi & 0xFFFF) ~ ", " ~ localName(stackMap, hi >> 16) ~ "\n";
            }
            break;

        case LongInst.Ugt:
            {
                result ~= "Ugt " ~ localName(stackMap, hi & 0xFFFF) ~ ", " ~ localName(stackMap, hi >> 16) ~ "\n";
            }
            break;
        case LongInst.Uge:
            {
                result ~= "Uge " ~ localName(stackMap, hi & 0xFFFF) ~ ", " ~ localName(stackMap, hi >> 16) ~ "\n";
            }
            break;
        case LongInst.Gt:
            {
                result ~= "Gt " ~ localName(stackMap, hi & 0xFFFF) ~ ", " ~ localName(stackMap, hi >> 16) ~ "\n";
            }
            break;
        case LongInst.Ge:
            {
                result ~= "Ge " ~ localName(stackMap, hi & 0xFFFF) ~ ", " ~ localName(stackMap, hi >> 16) ~ "\n";
            }
            break;

        case LongInst.Jmp:
            {
                result ~= "Jmp &" ~ itos(hi) ~ "\n";
            }
            break;

        case LongInst.JmpFalse:
            {
                result ~= "JmpFalse &" ~ itos((has4ByteOffset ? hi - 4 : hi)) ~ "\n";
            }
            break;
        case LongInst.JmpTrue:
            {
                result ~= "JmpTrue &" ~ itos((has4ByteOffset ? hi - 4 : hi)) ~ "\n";
            }
            break;

        case LongInst.JmpNZ:
            {
                result ~= "JmpNZ " ~ localName(stackMap, lw >> 16) ~ ", &" ~ itos(
                    (has4ByteOffset ? hi - 4 : hi)) ~ "\n";
            }
            break;

        case LongInst.JmpZ:
            {
                result ~= "JmpZ " ~ localName(stackMap, lw >> 16) ~ ", &" ~ itos(
                    (has4ByteOffset ? hi - 4 : hi)) ~ "\n";
            }
            break;

        case LongInst.PopCatch:
            {
                result ~= "PopCatch\n";
            }
            break;

        case LongInst.PushCatch:
            {
                result ~= "PushCatch\n";
            }
            break;
        case LongInst.Throw:
            {
                result ~= "Throw " ~ localName(stackMap,  lw >> 16) ~ "\n";
            }
            break;
        case LongInst.HeapLoad8:
            {
                result ~= "HeapLoad8 " ~ localName(stackMap, hi & 0xFFFF) ~ ", HEAP[" ~ localName(stackMap, hi >> 16) ~  "]\n";
            }
            break;        
        case LongInst.HeapStore8:
            {
                result ~= "HeapStore8 HEAP[" ~ localName(stackMap, hi & 0xFFFF)  ~ "], " ~ localName(stackMap, hi >> 16) ~ "\n";
            }
            break;

        case LongInst.HeapLoad16:
            {
                result ~= "HeapLoad16 " ~ localName(stackMap, hi & 0xFFFF) ~ ", HEAP[" ~ localName(stackMap, hi >> 16) ~  "]\n";
            }
            break;        
        case LongInst.HeapStore16:
            {
                result ~= "HeapStore16 HEAP[" ~ localName(stackMap, hi & 0xFFFF)  ~ "], " ~ localName(stackMap, hi >> 16) ~ "\n";
            }
        break;
            
        case LongInst.HeapLoad32:
            {
                result ~= "HeapLoad32 " ~ localName(stackMap, hi & 0xFFFF) ~ ", HEAP[" ~ localName(stackMap, hi >> 16) ~  "]\n";
            }
            break;
        case LongInst.HeapStore32:
            {
                result ~= "HeapStore32 HEAP[" ~ localName(stackMap, hi & 0xFFFF)  ~ "], " ~ localName(stackMap, hi >> 16) ~ "\n";
            }
            break;

        case LongInst.HeapLoad64:
            {
                result ~= "HeapLoad64 " ~ localName(stackMap, hi & 0xFFFF) ~ ", HEAP[" ~ localName(stackMap, hi >> 16) ~ "]\n";
            }
            break;

        case LongInst.HeapStore64:
            {
                result ~= "HeapStore64 HEAP[" ~ localName(stackMap, hi & 0xFFFF) ~ "], " ~ localName(stackMap, hi >> 16) ~ "\n";
            }
            break;
        case LongInst.Ret32, LongInst.RetS32:
            {
                result ~= "Ret32 " ~ localName(stackMap, lw >> 16) ~ " \n";
            }
            break;
        case LongInst.Ret64, LongInst.RetS64:
            {
                result ~= "Ret64 " ~ localName(stackMap, lw >> 16) ~ " \n";
            }
            break;
        case LongInst.RelJmp:
            {
                result ~= "RelJmp &" ~ itos(cast(short)(lw >> 16) + (pos - 2)) ~ "\n";
            }
            break;
        case LongInst.PrintValue:
            {
                result ~= "Prt " ~ localName(stackMap, lw >> 16) ~ " \n";
            }
            break;
        case LongInst.Not:
            {
                result ~= "Not " ~ localName(stackMap, lw >> 16) ~ " \n";
            }
            break;

        case LongInst.Flg:
            {
                result ~= "Flg " ~ localName(stackMap, lw >> 16) ~ " \n";
            }
            break;
        case LongInst.Call:
            {
                result ~= "Call " ~ localName(stackMap, hi & 0xFFFF) ~ ", " ~ localName(stackMap, hi >> 16) ~ "\n";
            }
            break;
        case LongInst.Cat:
            {
                result ~= "Cat " ~ localName(stackMap, lw >> 16) ~ ", " ~ localName(stackMap, hi & 0xFFFF) ~ ", " ~ localName(stackMap, hi >> 16) ~ "\n";
            break;
            }
        case LongInst.BuiltinCall:
            {
                result ~= "BuiltinCall Fn{" ~ itos(lw >> 16) ~ "} (" ~ itos(hi) ~ ")\n";
            }
            break;
        case LongInst.Alloc:
            {
                result ~= "Alloc " ~ localName(stackMap, hi & 0xFFFF) ~ " " ~ localName(stackMap, hi >> 16) ~ "\n";
            }
            break;
        case LongInst.LoadFramePointer:
            {
                result ~= "LoadFramePointer " ~ localName(stackMap, lw >> 16) ~ " +#" ~ itos(hi) ~ "\n";
            }
            break;
        case LongInst.MemCpy:
            {
                result ~= "MemCpy " ~ localName(stackMap, hi & 0xFFFF) ~ " " ~ localName(stackMap, hi >> 16) ~ " " ~ localName(stackMap, lw >> 16) ~ "\n";
            }
            break;
        case LongInst.Comment:
            {
                auto commentLength = hi;

                result ~= "// ";

                printText(commentLength);

                result ~= "\n";
            }
            break;
        case LongInst.File:
            {
                result ~= "File (";

                printText(hi);

                result ~= ")\n";
            }
            break;
        case LongInst.Line:
            {
                result ~= "Line #" ~ itos(hi) ~ "\n";
            }
            break;

        }
    }
    return (cast(string)result) ~ "\nEndInstructionDump\n";
}

//static if (__traits(isModule, dmd.ctfe.ctfe_bc))
//{

//    alias RE = RetainedError;
//}
//else
//{
    alias RE = void;
    pragma(msg, "not chosing retained error branch");
//}

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

const (uint[])* getCodeForId (const int fnId, const BCFunction* functions) pure
{
    return &functions[fnId].byteCode;
}

struct Catch
{
    uint ip;
    uint stackDepth;
}

struct ReturnAddr
{
    uint ip;
    uint fnId;
    uint stackSize;
    long* retval;
}

const(BCValue) interpret_(int fnId, const BCValue[] args,
    BCHeap* heapPtr = null, const BCFunction* functions = null,
    const RetainedCall* calls = null,
    BCValue* ev1 = null, BCValue* ev2 = null, BCValue* ev3 = null,
    BCValue* ev4 = null, const RE* errors = null,
    long[] stackPtr = null,
    const string[ushort] stackMap = null,
    /+    DebugCommand function() reciveCommand = {return DebugCommand(DebugCmdEnum.Nothing);},
    BCValue* debugOutput = null,+/ uint stackOffset = 0)  @trusted
{
    const (uint[])* byteCode = getCodeForId(fnId, functions);

    uint callDepth = 0;
    uint inThrow = false;
    import std.stdio;

    bool paused; /// true if we are in a breakpoint.


    uint[] breakLines = [];
    uint lastLine;
    BCValue cRetval;
    ReturnAddr[max_call_depth] returnAddrs;
    Catch[] catches;
    uint n_return_addrs;
    if (!__ctfe)
    {
        // writeln("Args: ", args, "BC:", (*byteCode).printInstructions(stackMap));
    }
    auto stack = stackPtr ? stackPtr : new long[](ushort.max / 4);

    // first push the args on
    debug (bc)
        if (!__ctfe)
        {
            printf("before pushing args");
        }
    long* framePtr = &stack[0] + (stackOffset / 4);
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
    size_t argOffset = 1;
    foreach (arg; args)
    {
        switch (arg.type.type)
        {
            case BCTypeEnum.u32, BCTypeEnum.f23, BCTypeEnum.c8:
            case BCTypeEnum.u16, BCTypeEnum.u8, BCTypeEnum.c16, BCTypeEnum.c32:
            case BCTypeEnum.i32, BCTypeEnum.i16, BCTypeEnum.i8:
            {
                (framePtr[argOffset++]) = cast(uint)arg.imm32;
            }
            break;

            case BCTypeEnum.i64, BCTypeEnum.u64, BCTypeEnum.f52:
            {
                (framePtr[argOffset]) = arg.imm64;
                argOffset += 2;
            }
            break;
            // all of thsose get passed by pointer and therefore just take one stack slot
            case BCTypeEnum.Struct, BCTypeEnum.Class, BCTypeEnum.string8, BCTypeEnum.Array, BCTypeEnum.Ptr, BCTypeEnum.Null:
                {
                    // This might need to be removed again?
                    (framePtr[argOffset++]) = arg.heapAddr.addr;
                }
                break;
            default:
            //return -1;
                   assert(0, "unsupported Type " ~ enumToString(arg.type.type));
        }
    }
    uint ip = 4;
    bool cond;

    BCValue returnValue;

    bool HandleExp()
    {
            if (cRetval.vType == BCValueType.Exception)
            {
                debug { if (!__ctfe) writeln("Exception in flight ... length of catches: ", catches ? catches.length : -1) ; }
                debug { if (!__ctfe) writeln("catches: ", catches);  }

                // we return to unroll
                // lets first handle the case in which there are catches on the catch stack
                if (catches.length)
                {
                    const catch_ = catches[$-1];
                    debug { if (!__ctfe) writefln("CallDepth:(%d) Catches (%s)", callDepth, catches); }

                    // in case we are above at the callDepth of the next catch
                    // we need to pass this return value on
                    if (catch_.stackDepth < callDepth)
                    {
                        auto returnAddr = returnAddrs[--n_return_addrs];
                        ip = returnAddr.ip;
                        debug { if (!__ctfe) writefln("CatchDepth:(%d) lower than current callStack:(%d) Depth. Returning to ip = %d", catch_.stackDepth, callDepth, ip); }
                        byteCode = getCodeForId(returnAddr.fnId, functions);
                        fnId = returnAddr.fnId;
                        --callDepth;
                        return false;
                    }
                    // In case we are at the callDepth we need to go to the right catch
                    else if (catch_.stackDepth == callDepth)
                    {
                        debug { if (!__ctfe) writeln("stackdepth == Calldepth. Executing catch at: ip=", ip, " byteCode.length="); }
                        ip = catch_.ip;
                        // we need to also remove the catches so we don't end up here next time
                        catches = catches[0 .. $-1];
                        // resume execution at execption handler block
                        return false;
                    }
                    // in case we end up here there is a catch handler but we skipped it
                    // this can happen if non of the handlers matched we return the execption
                    // out of the function .. we can ignore the state of the stack and such
                    else
                    {
                       
                        debug { if (!__ctfe) writeln("we have not been able to catch the expection returning."); }
                        return true;
                    }
                }
                // if we go here it means there are no catches anymore to catch this.
                // we will go on returning this out of the callstack until we hit the end
                else
                {
                    return true;
                }

                // in case we are at the depth we need to jump to Throw
                // assert(!catches.length, "We should goto the catchBlock here.");
            }
            else
                assert(0);
    }
     

    bool Return()
    {
        if (n_return_addrs)
        {
            auto returnAddr = returnAddrs[--n_return_addrs];
            byteCode = getCodeForId(returnAddr.fnId, functions);
            fnId = returnAddr.fnId;
            ip = returnAddr.ip;

            framePtr = framePtr - (returnAddr.stackSize / 4);
            callDepth--;
            if (cRetval.vType == BCValueType.Exception)
            {
                return HandleExp();
            }
            if (cRetval.vType == BCValueType.Error || cRetval.vType == BCValueType.Bailout)
            {
                return true;
            }
            if (cRetval.type.type == BCTypeEnum.i64 || cRetval.type.type == BCTypeEnum.u64 || cRetval.type.type == BCTypeEnum.f52)
            {
                (*returnAddr.retval) = cRetval.imm64;
            }
            else
            {
                (*returnAddr.retval) = cRetval.imm32;
            }
            return false;
        }
        else
        {
            return true;
        }
    }

    // debug(bc) { import std.stdio; writeln("BC.len = ", byteCode.length); }
    if ((*byteCode).length < 6 || (*byteCode).length <= ip)
        return typeof(return).init;

    while (true && ip <= (*byteCode).length - 1)
    {
/+
        DebugCommand command = reciveCommand();
        do
        {
            debug
            {
                import std.stdio;
                if (!__ctfe) writeln("Order: ", enumToString(command.order));
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
        debug (bc_stack)
            foreach (si; 0 .. stackOffset + 32)
            {
                if (!__ctfe)
                {
                    printf("StackIndex %d, Content %x\t".ptr, si, stack[cast(uint) si]);
                    printf("HeapIndex %d, Content %x\n".ptr, si, heapPtr.heapData[cast(uint) si]);
                }
            }
        // debug if (!__ctfe) writeln("ip: ", ip);
        const lw = (*byteCode)[ip];
        const uint hi = (*byteCode)[ip + 1];
        const int imm32c = *(cast(int*)&((*byteCode)[ip + 1]));
        ip += 2;

        // consider splitting the stackPointer in stackHigh and stackLow

        const uint opRefOffset = (lw >> 16) & 0xFFFF;
        const uint lhsOffset = hi & 0xFFFF;
        const uint rhsOffset = (hi >> 16) & 0xFFFF;

        auto lhsRef = (&framePtr[(lhsOffset / 4)]);
        auto rhs = (&framePtr[(rhsOffset / 4)]);
        auto lhsStackRef = (&framePtr[(opRefOffset / 4)]);
        auto opRef = &framePtr[(opRefOffset / 4)];

        if (!lw)
        { // Skip NOPS
            continue;
        }

        final switch (cast(LongInst)(lw & InstMask))
        {
        case LongInst.ImmAdd:
            {
                (*lhsStackRef) += imm32c;
            }
            break;

        case LongInst.ImmSub:
            {
                (*lhsStackRef) -= imm32c;
            }
            break;

        case LongInst.ImmMul:
            {
                (*lhsStackRef) *= imm32c;
            }
            break;

        case LongInst.ImmDiv:
            {
                (*lhsStackRef) /= imm32c;
            }
            break;

        case LongInst.ImmUdiv:
            {
                (*cast(ulong*)lhsStackRef) /= imm32c;
            }
            break;

        case LongInst.ImmAnd:
            {
                (*lhsStackRef) &= hi;
            }
            break;
        case LongInst.ImmAnd32:
            {
                *lhsStackRef = (cast(uint)*lhsStackRef) & hi;
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
        case LongInst.ImmXor32:
            {
                *lhsStackRef = (cast(uint)*lhsStackRef) ^ hi;
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
                (*lhsStackRef) %= imm32c;
            }
            break;
        case LongInst.ImmUmod:
            {
                (*cast(ulong*)lhsStackRef) %= imm32c;
            }
            break;

        case LongInst.SetImm8:
            {
                (*lhsStackRef) = hi;
                assert(hi <= ubyte.max);
            }
            break;
        case LongInst.SetImm32:
            {
                (*lhsStackRef) = hi;
            }
            break;
        case LongInst.SetHighImm32:
            {
                *lhsStackRef = (*lhsStackRef & 0x00_00_00_00_FF_FF_FF_FF) | (ulong(hi) << 32UL);
            }
            break;
        case LongInst.ImmEq:
            {
                if ((*lhsStackRef) == imm32c)
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
                if ((*lhsStackRef) != imm32c)
                {
                    cond = true;
                }
                else
                {
                    cond = false;
                }
            }
            break;

        case LongInst.ImmUlt:
            {
                if ((cast(ulong)(*lhsStackRef)) < cast(uint)hi)
                {
                    cond = true;
                }
                else
                {
                    cond = false;
                }
            }
            break;
        case LongInst.ImmUgt:
            {
                if ((cast(ulong)(*lhsStackRef)) > cast(uint)hi)
                {
                    cond = true;
                }
                else
                {
                    cond = false;
                }
            }
            break;
        case LongInst.ImmUle:
            {
                if ((cast(ulong)(*lhsStackRef)) <= cast(uint)hi)
                {
                    cond = true;
                }
                else
                {
                    cond = false;
                }
            }
            break;
        case LongInst.ImmUge:
            {
                if ((cast(ulong)(*lhsStackRef)) >= cast(uint)hi)
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
                if ((*lhsStackRef) < imm32c)
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
                if (cast()(*lhsStackRef) > imm32c)
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
                if ((*lhsStackRef) <= imm32c)
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
                if ((*lhsStackRef) >= imm32c)
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
        case LongInst.Udiv:
            {
                (*cast(ulong*)lhsRef) /= (*cast(ulong*)rhs);
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
        case LongInst.Umod:
            {
                (*cast(ulong*)lhsRef) %= (*cast(ulong*)rhs);
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
                debug
                {
	            //writeln((*byteCode).printInstructions(stackMap));

                    writeln("ip:", ip, "Assert(&", opRefOffset, " *",  *opRef, ")");
                }
                if (*opRef == 0)
                {
                    BCValue retval = imm32(hi);
                    retval.vType = BCValueType.Error;

                    static if (is(RetainedError))
                    {
                        if (hi - 1 < bc_max_errors)
                        {
                            auto err = errors[cast(uint)(hi - 1)];

                            *ev1 = imm32(framePtr[err.v1.addr / 4] & uint.max);
                            *ev2 = imm32(framePtr[err.v2.addr / 4] & uint.max);
                            *ev3 = imm32(framePtr[err.v3.addr / 4] & uint.max);
                            *ev4 = imm32(framePtr[err.v4.addr / 4] & uint.max);
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

        case LongInst.Ult:
            {
                if ((cast(ulong)(*lhsRef)) < (cast(ulong)*rhs))
                {
                    cond = true;
                }
                else
                {
                    cond = false;
                }
            }
            break;
        case LongInst.Ugt:
            {
                if (cast(ulong)(*lhsRef) > cast(ulong)*rhs)
                {
                    cond = true;
                }
                else
                {
                    cond = false;
                }
            }
            break;
        case LongInst.Ule:
            {
                if ((cast(ulong)(*lhsRef)) <= (cast(ulong)*rhs))
                {
                    cond = true;
                }
                else
                {
                    cond = false;
                }
            }
            break;
        case LongInst.Uge:
            {
                if ((cast(ulong)(*lhsRef)) >= (cast(ulong)*rhs))
                {
                    cond = true;
                }
                else
                {
                    cond = false;
                }

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

        case LongInst.PushCatch:
            {
                debug
                {
                    printf("PushCatch is executing\n");
                }
                Catch catch_ = Catch(ip, callDepth);
                catches ~= catch_;
            }
            break;

            case LongInst.PopCatch:
            {
                debug { if (!__ctfe) writeln("Poping a Catch"); }
                catches = catches[0 .. $-1];
            }
            break;

            case LongInst.Throw:
            {
                uint expP = ((*opRef) & uint.max);
                debug { if (!__ctfe) writeln("*opRef: ", expP); } 
                auto expTypeIdx = heapPtr.heapData[expP + ClassMetaData.TypeIdIdxOffset];
                auto expValue = BCValue(HeapAddr(expP), BCType(BCTypeEnum.Class, expTypeIdx));
                expValue.vType = BCValueType.Exception;

                cRetval = expValue;
                if (HandleExp())
                    return cRetval;
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

        case LongInst.HeapLoad8:
            {
                assert(*rhs, "trying to deref null pointer inLine: " ~ itos(lastLine));
                (*lhsRef) = heapPtr.heapData[*rhs];
                debug
                {
                    import std.stdio;
                    writeln("Loaded[",*rhs,"] = ",*lhsRef);
                }
            }
            break;
        case LongInst.HeapStore8:
            {
                assert(*lhsRef, "trying to deref null pointer SP[" ~ itos(cast(int)((lhsRef - &framePtr[0])*4)) ~ "] at : &" ~ itos (ip - 2));
                heapPtr.heapData[*lhsRef] = ((*rhs) & 0xFF);
                debug
                {
                    import std.stdio;
                    if (!__ctfe)
                    {
                        writeln(ip,":Store[",*lhsRef,"] = ",*rhs & uint.max);
                    }
                }
            }
            break;

            case LongInst.HeapLoad16:
            {
                assert(*rhs, "trying to deref null pointer inLine: " ~ itos(lastLine));
                const addr = *lhsRef;
                (*lhsRef) =  heapPtr.heapData[addr]
                          | (heapPtr.heapData[addr + 1] << 8);

                debug
                {
                    import std.stdio;
                    writeln("Loaded[",*rhs,"] = ",*lhsRef);
                }
            }
            break;
            case LongInst.HeapStore16:
            {
                assert(*lhsRef, "trying to deref null pointer SP[" ~ itos(cast(int)((lhsRef - &framePtr[0])*4)) ~ "] at : &" ~ itos (ip - 2));
                const addr = *lhsRef;
                heapPtr.heapData[addr    ] = ((*rhs     ) & 0xFF);
                heapPtr.heapData[addr + 1] = ((*rhs >> 8) & 0xFF);
                debug
                {
                    import std.stdio;
                    if (!__ctfe)
                    {
                        writeln(ip,":Store[",*lhsRef,"] = ",*rhs & uint.max);
                    }
                }
            }
            break;

            case LongInst.HeapLoad32:
            {
                const addr = cast(uint) *rhs;
                if (isStackAddress(addr))
                {
                    auto sAddr = toStackOffset(addr);
                    (*lhsRef) = stackPtr[sAddr / 4];
                    continue;
                }


                assert(*rhs, "trying to deref null pointer inLine: " ~ itos(lastLine));
                (*lhsRef) = loadu32(heapPtr.heapData.ptr + addr);
                debug
                {
                    import std.stdio;
                    writeln("Loaded[",*rhs,"] = ",*lhsRef);
                }
            }
            break;
        case LongInst.HeapStore32:
            {
                assert(*lhsRef, "trying to deref null pointer SP[" ~ itos(cast(int)((lhsRef - &framePtr[0])*4)) ~ "] at : &" ~ itos (ip - 2));

                const addr = cast(uint) *lhsRef;
                if (isStackAddress(addr))
                {
                    auto sAddr = toStackOffset(addr);
                    stackPtr[sAddr / 4] = ((*rhs) & uint.max);
                    continue;
                }

                storeu32((&heapPtr.heapData[*lhsRef]),  (*rhs) & uint.max);

                debug
                {
                    import std.stdio;
                    if (!__ctfe)
                    {
                        writeln(ip,":Store[",*lhsRef,"] = ",*rhs & uint.max);
                    }
                }
            }
            break;

        case LongInst.HeapLoad64:
            {
                assert(*rhs, "trying to deref null pointer ");
                const addr = *rhs;
                (*lhsRef) =       loadu32(&heapPtr.heapData[addr])
                          | ulong(loadu32(&heapPtr.heapData[addr + 4])) << 32UL;

                debug
                {
                    import std.stdio;
                    if (!__ctfe)
                    {
                        writeln(ip,":Loaded[",*rhs,"] = ",*lhsRef);
                    }
                }
            }
            break;

        case LongInst.HeapStore64:
            {
                assert(*lhsRef, "trying to deref null pointer SP[" ~ itos(cast(int)(lhsRef - &framePtr[0])*4) ~ "] at : &" ~ itos (ip - 2));
                const heapOffset = *lhsRef;
                assert(heapOffset < heapPtr.heapSize, "Store out of range at ip: &" ~ itos(ip - 2) ~ " atLine: " ~ itos(lastLine));
                auto basePtr = (heapPtr.heapData.ptr + *lhsRef);
                const addr = *lhsRef;
                const value = *rhs;

                storeu32(&heapPtr.heapData[addr],     value & uint.max);
                storeu32(&heapPtr.heapData[addr + 4], cast(uint)(value >> 32));
            }
            break;

        case LongInst.Ret32:
            {
                debug (bc)
                    if (!__ctfe)
                    {
                        import std.stdio;

                        writeln("Ret32 SP[", lhsOffset, "] (", *opRef, ")\n");
                    }
                cRetval = imm32(*opRef & uint.max);
                if (Return()) return cRetval;
            }
            break;
        case LongInst.RetS32:
            {
                debug (bc)
                    if (!__ctfe)
                {
                    import std.stdio;
                    writeln("Ret32 SP[", lhsOffset, "] (", *opRef, ")\n");
                }
                cRetval = imm32(*opRef & uint.max, true);
                if (Return()) return cRetval;
            }
            break;
        case LongInst.RetS64:
            {
                cRetval = BCValue(Imm64(*opRef, true));
                if (Return()) return cRetval;
            }
            break;

        case LongInst.Ret64:
            {
                cRetval = BCValue(Imm64(*opRef, false));
                if (Return()) return cRetval;
            }
            break;
        case LongInst.RelJmp:
            {
                ip += (cast(short)(lw >> 16)) - 2;
            }
            break;
        case LongInst.PrintValue:
            {
                if (!__ctfe)
                {
                    if ((lw & ushort.max) >> 8)
                    {
                        auto offset = *opRef;
                        auto length = heapPtr.heapData[offset];
                        auto string_start = cast(char*)&heapPtr.heapData[offset + 1];
                        printf("Printing string: '%.*s'\n", length, string_start);
                    }
                    else
                    {
                        printf("Addr: %lu, Value %lx\n", (opRef - framePtr) * 4, *opRef);
                    }
                }
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
                    const elemSize = (lw >> 8) & 255;
                    const uint _lhs =  *lhsRef & uint.max;
                    const uint _rhs =  *rhs & uint.max;

                    const llbasep = &heapPtr.heapData[_lhs + SliceDescriptor.LengthOffset];
                    const rlbasep = &heapPtr.heapData[_rhs + SliceDescriptor.LengthOffset];

                    const lhs_length = _lhs ? loadu32(llbasep) : 0;
                    const rhs_length = _rhs ? loadu32(rlbasep) : 0;

                    if (const newLength = lhs_length + rhs_length)
                    {
                        // TODO if lhs.capacity bla bla
                        const lhsBase = loadu32(&heapPtr.heapData[_lhs + SliceDescriptor.BaseOffset]);
                        const rhsBase = loadu32(&heapPtr.heapData[_rhs + SliceDescriptor.BaseOffset]);

                        const resultPtr = heapPtr.heapSize;

                        const resultLengthP = resultPtr + SliceDescriptor.LengthOffset;
                        const resultBaseP   = resultPtr + SliceDescriptor.BaseOffset;
                        const resultBase    = resultPtr + SliceDescriptor.Size;

                        const allocSize = (newLength * elemSize) + SliceDescriptor.Size;
                        const heapSize  = heapPtr.heapSize;

                        if(heapSize + allocSize  >= heapPtr.heapMax)
                        {
                            // we will now resize the heap to 8 times its former size
                            const newHeapMax =
                                ((allocSize < heapPtr.heapMax * 4) ?
                                    heapPtr.heapMax * 8 :
                                    align4(cast(uint)(heapPtr.heapMax + allocSize)) * 4);

                            if (newHeapMax >= 2 ^^ 31)
                                assert(0, "!!! HEAP OVERFLOW !!!");

                            auto newHeap = new ubyte[](newHeapMax);
                            assert(newHeap && newHeap.ptr && newHeapMax > heapSize);
                            newHeap[0 .. heapSize] = heapPtr.heapData[0 .. heapSize];
                            if (!__ctfe) heapPtr.heapData.destroy();

                            heapPtr.heapData = newHeap;
                            heapPtr.heapMax = newHeapMax;

                        }

                        heapPtr.heapSize += allocSize;

                        const scaled_lhs_length = (lhs_length * elemSize);
                        const scaled_rhs_length = (rhs_length * elemSize);
                        const result_lhs_end    = resultBase + scaled_lhs_length;

                        storeu32(&heapPtr.heapData[resultBaseP],  resultBase);
                        storeu32(&heapPtr.heapData[resultLengthP], newLength);

                        heapPtr.heapData[resultBase .. result_lhs_end] =
                            heapPtr.heapData[lhsBase .. lhsBase + scaled_lhs_length];

                        heapPtr.heapData[result_lhs_end ..  result_lhs_end + scaled_rhs_length] =
                            heapPtr.heapData[rhsBase .. rhsBase + scaled_rhs_length];

                        *lhsStackRef = resultPtr;
                    }
                }
            }
            break;

        case LongInst.Call:
            {
                assert(functions, "When calling functions you need functions to call");
                auto call = calls[uint((*rhs & uint.max)) - 1];
                auto returnAddr = ReturnAddr(ip, fnId, call.callerSp, lhsRef);

                uint fn = (call.fn.vType == BCValueType.Immediate ?
                    call.fn.imm32 :
                    framePtr[call.fn.stackAddr.addr / 4]
                ) & uint.max;

                fnId = fn - 1;

                auto stackOffsetCall = stackOffset + call.callerSp;
                auto newStack = framePtr + (call.callerSp / 4);

                if (fn == skipFn)
                    continue;

                static if (__traits(compiles, { import dmd.reflect; }))
                {

                    if (fn == nodeFromName)
                    {
                        import dmd.arraytypes : Expressions; 
                        scope eArgs = new Expressions(call.args.length);
                        // now we convert our args from bc_values to expressions
                        import dmd.reflect;
                        import dmd.mtype;
                        import dmd.ctfe.ctfe_bc : genArg;
                        auto tFlags = ReflectionVisitor.getEd("ReflectFlags").type;
                        auto tScope = ReflectionVisitor.getCd("Scope").type;
                        Type[3] argTypes = [Type.tstring, tFlags, tScope];
                        foreach(size_t i, ref arg;call.args)
                        {
                            BCValue a = arg;
                            import dmd.ctfe.ctfe_bc : toExpression;
                            printf("bcArg: %s\n", arg.toString().ptr);
                            if (arg.vType != BCValueType.Immediate)
                            {
                                a = imm32(framePtr[arg.stackAddr / 4] & uint.max);
                            }
                            (*eArgs)[i] = toExpression(a, argTypes[i]);
                            printf("eArg: %s\n" ,(*eArgs)[i].toChars());
                        }
                        auto refl_result = eval_reflect(Loc.initial, REFLECT.nodeFromName, eArgs, null);
                        *lhsRef = genArg(refl_result).imm32;
                        printf("reflection resulted in: %s\n", refl_result.toChars());
                        continue;
                        // assert(0, "got nodeFromName");
                    }
                    else if (fn == currentScope)
                    {
                        assert(0, "got currentScope\n");
                    }
                }

                if (!__ctfe)
                {
                    debug writeln("call.fn = ", call.fn);
                    debug writeln("fn = ", fn);
                    debug writeln((functions + fn - 1).byteCode.printInstructions);
                    debug writeln("stackOffsetCall: ", stackOffsetCall);
                    debug writeln("call.args = ", call.args);
                }


                foreach(size_t i,ref arg;call.args)
                {
                    const argOffset_ = (i * 1) + 1;
                    if(isStackValueOrParameter(arg))
                    {
                            newStack[argOffset_] = framePtr[arg.stackAddr.addr / 4];
                    }
                    else if (arg.vType == BCValueType.Immediate)
                    {
                        newStack[argOffset_] = arg.imm64;
                    }
                    else
                    {
                        assert(0, "Argument " ~ itos(cast(int)i) ~" ValueType unhandeled: " ~ enumToString(arg.vType));
                    }
                }

                debug { if (!__ctfe) writeln("Stack after pushing: ", newStack[0 .. 64]); }

                if (callDepth++ == max_call_depth)
                {
                        BCValue bailoutValue;
                        bailoutValue.vType = BCValueType.Bailout;
                        bailoutValue.imm32.imm32 = 2000;
                        return bailoutValue;
                }
                {
                    returnAddrs[n_return_addrs++] = returnAddr;
                    framePtr = framePtr + (call.callerSp / 4);
                    byteCode = getCodeForId(cast(int)(fn - 1), functions);
                    ip = 4;
                }
/+
                auto cRetval = interpret_(fn - 1,
                    callArgs[0 .. call.args.length], heapPtr, functions, calls, ev1, ev2, ev3, ev4, errors, stack, catches, stackMap, stackOffsetCall);
+/
        LreturnTo:
            }
            break;

        case LongInst.Alloc:
            {
                const allocSize = *rhs;
                const heapSize = heapPtr.heapSize;
                // T(1) << bsr(val)
                static uint nextPow2(uint n)
                {
                    import core.bitop;
                    return (1 << (bsr(n) + 1));
                }
                if(heapSize + allocSize  >= heapPtr.heapMax)
                {
                    auto newHeapMax =
                        ((allocSize < heapPtr.heapMax * 1.6) ?
                            nextPow2(cast(uint)(heapPtr.heapMax * 1.6)) :
                            nextPow2(cast(uint)(heapPtr.heapMax + allocSize * 1.3)));

                    // our last try to avoid to the heap overflow!
                    if (newHeapMax > maxHeapAddress && (heapSize + allocSize) <= maxHeapAddress)
                    {
                        newHeapMax = maxHeapAddress;
                    }
                    //if (!__ctfe) printf("newHeapMax: %u\n", newHeapMax);
                    if (newHeapMax > maxHeapAddress || newHeapMax < heapPtr.heapMax)
                        assert(0, "!!! HEAP OVERFLOW !!!");

                    auto newHeap = new ubyte[](newHeapMax);

                    assert(newHeap && newHeap.ptr);
                    assert(newHeapMax > heapSize);
                    newHeap[0 .. heapSize] = heapPtr.heapData[0 .. heapSize];
                    if (!__ctfe) heapPtr.heapData.destroy();

                    heapPtr.heapData = newHeap;
                    heapPtr.heapMax = newHeapMax;
                }

                *lhsRef = heapSize;
                heapPtr.heapSize += allocSize;

                debug
                {
                    if (!__ctfe)
                    {
                        printf("Alloc(#%llu) = &%lld\n", allocSize, *lhsRef);
                    }
                }

            }
            break;
        case LongInst.LoadFramePointer:
            {
                // lets compute the offset from the beginning of the stack
                const uint FP = ((framePtr - &stack[0]) & uint.max) | stackAddrMask;
                (*lhsStackRef) = (FP + imm32c);
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
                if (cpySrc != cpyDst && cpySize != 0)
                {
                    // assert(cpySize, "cpySize == 0");
                    assert(cpySrc, "cpySrc == 0" ~ " inLine: " ~ itos(lastLine));

                    assert(cpyDst, "cpyDst == 0" ~ " inLine: " ~ itos(lastLine));

                    assert(cpyDst >= cpySrc + cpySize || cpyDst + cpySize <= cpySrc, "Overlapping MemCpy is not supported --- src: " ~ itos(cpySrc)
                        ~ " dst: " ~ itos(cpyDst) ~ " size: " ~ itos(cpySize));
                    heapPtr.heapData[cpyDst .. cpyDst + cpySize] = heapPtr.heapData[cpySrc .. cpySrc + cpySize];
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
                    immutable lhUlength = heapPtr.heapData[_lhs + SliceDescriptor.LengthOffset];
                    immutable rhUlength = heapPtr.heapData[_rhs + SliceDescriptor.LengthOffset];
                    if (lhUlength == rhUlength)
                    {
                        immutable lhsBase = heapPtr.heapData[_lhs + SliceDescriptor.BaseOffset];
                        immutable rhsBase = heapPtr.heapData[_rhs + SliceDescriptor.BaseOffset];
                        cond = true;
                        foreach (i; 0 .. lhUlength)
                        {
                            if (heapPtr.heapData[rhsBase + i] != heapPtr.heapData[lhsBase + i])
                            {
                                cond = false;
                                break;
                            }
                        }
                    }
                }
            }
            break;
        case LongInst.File :
            {
                goto case LongInst.Comment;
            }
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

    debug (ctfe)
    {
        assert(0, "I would be surprised if we got here -- withBC: " ~ (*byteCode).printInstructions);
    }
}

auto testRelJmp()
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
        Jmp(evalCond);
        Finalize();
        return gen;
    }
}


// Fact(n) = (n > 1 ? ( n*(n-1) * Fact(n-2) ) : 1);
auto testFact()
{
    BCGen gen;
    with (gen)
    {
        Initialize();
        {
            auto n = genParameter(i32Type, "n");
            beginFunction(0);
            {
                auto result = genLocal(i32Type, "result");
                Gt3(BCValue.init, n, imm32(1, true));
                auto j_n_lt_1 = beginCndJmp();
                {
                    auto n_sub_1 = genTemporary(i32Type);
                    Sub3(n_sub_1, n, imm32(1));
                    auto n_mul_n_sub_1 = genTemporary(i32Type);
                    Mul3(n_mul_n_sub_1, n, n_sub_1);
                    Sub3(n, n, imm32(2));

                    auto result_fact = genTemporary(i32Type);
                    Call(result_fact, imm32(1), [n]);

                    Mul3(result, n_mul_n_sub_1, result_fact);
                    Ret(result);
                }
                auto l_n_lt_1 = genLabel();
                {
                    Set(result, imm32(1));
                    Ret(result);
                }
                endCndJmp(j_n_lt_1, l_n_lt_1);
            }
            endFunction();
        }
        Finalize();
        return gen;
    }
}

static assert(testFact().interpret([imm32(5)]) == imm32(120));

//pragma(msg, testRelJmp().interpret([]));
//import dmd.ctfe.bc_test;

//static assert(test!BCGen());
