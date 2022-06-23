/**
 * This module defines:
 *     - The abstract meaning and memory layout of the instruction set.
 *     - The `BCGen` utility for building bytecode programs.
 *
 * Copyright:   Copyright (C) 2022 by The D Language Foundation, All Rights Reserved
 * Authors:     Stefan Koch, Max Haughton
 */
module dmd.ctfe.bc;

import dmd.ctfe.bc_common;
import dmd.ctfe.bc_limits;
import dmd.ctfe.bc_abi;
import core.stdc.stdio;


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
    uint[ushort.max * 16] byteCodeArray;

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

    RetainedCall[ubyte.max * 255] calls;
    uint callCount;

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

        assert(pSize == 4 || pSize == 8, "we only support 4byte and 8byte params: " ~ enumToString(bct.type));

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
                goto case;
            case 0 :
                byteCodeArray[ip++] = lastField;
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

    @trusted void Comment(lazy const (char)[] comment)
    {
        //debug
        {
            uint commentLength = cast(uint) comment.length + 1;

            emitLongInst(LongInst.Comment, StackAddr(0), Imm32(commentLength));

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

    void emitArithInstruction(LongInst inst, BCValue lhs, BCValue rhs, scope BCTypeEnum* resultTypeEnum = null)
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



//pragma(msg, testRelJmp().interpret([]));
//import dmd.ctfe.bc_test;

//static assert(test!BCGen());
