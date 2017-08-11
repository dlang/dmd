module ddmd.ctfe.bc_common;

struct CndJmpBegin
{
    BCAddr at;
    BCValue cond;
    bool ifTrue;
}

const(uint) align4(const uint val) @safe pure @nogc
{
    return ((val + 3) & ~3);
}

static assert(align4(1) == 4);

static assert(align4(9) == 12);
static assert(align4(11) == 12);
static assert(align4(12) == 12);
static assert(align4(15) == 16);

const(uint) align16(const uint val) pure
{
    return ((val + 15) & ~15);
}

string enumToString(E)(E v)
{
    static assert(is(E == enum),
        "emumToString is only meant for enums");
    string result;

    Switch : switch(v)
    {
        foreach(m;__traits(allMembers, E))
        {
            case mixin("E." ~ m) :
                result = m;
            break Switch;
        }

        default :
        {
            result = "cast(" ~ E.stringof ~ ")";
            uint val = v;
            enum headLength = cast(uint)(E.stringof.length + "cast()".length);
            uint log10Val = (val < 10) ? 0 : (val < 100) ? 1 : (val < 1000) ? 2 :
                (val < 10000) ? 3 : (val < 100000) ? 4 : (val < 1000000) ? 5 :
                (val < 10000000) ? 6 : (val < 100000000) ? 7 : (val < 1000000000) ? 8 : 9;
            result.length += log10Val + 1;
            for(uint i;i != log10Val + 1;i++)
            {
                cast(char)result[headLength + log10Val - i] = cast(char) ('0' + (val % 10));
                val /= 10;
            }

        }
    }

    return result;
}


const(uint) basicTypeSize(const BCTypeEnum bct) @safe pure
{
    final switch (bct) with (BCTypeEnum)
    {

    case Undef:
        {
            debug (ctfe)
                assert(0, "We should never encounter undef or bailout");
            return 0;
        }
    case c8, i8, u8:
        {
            return 1;
        }
    case c16, i16, u16:
        {
            return 2;
        }
    case c32, i32, u32, f23:
        {
            return 4;
        }
    case i64, u64, f52:
        {
            return 8;
        }
    case f106:
        {
            return 16;
        }

    case Function, Null :
        {
            return 4;
        }
    case Ptr :
            assert(0, "Ptr is not suppsed to be a basicType anymore");

    case string8, string16, string32:
        {
            //FIXME actually strings don't have a basicTypeSize as is
            return 16;
        }


    case Void, Array, Slice, Struct:
        {
            return 0;
        }
    }
}

bool anyOf(BCTypeEnum type, const BCTypeEnum[] acceptedTypes) pure @safe
{
    bool result = false;

    foreach(acceptedType;acceptedTypes)
    {
        if (type == acceptedType)
        {
            result = true;
            break;
        }
    }

    return result;
}

bool isFloat(BCType bct) @safe pure nothrow
{
    return bct.type == BCTypeEnum.f23 || bct.type == BCTypeEnum.f52;
}

bool isBasicBCType(BCType bct) @safe pure
{
    return !(bct.type == BCTypeEnum.Struct || bct.type == BCTypeEnum.Array
            || bct.type == BCTypeEnum.Slice || bct.type == BCTypeEnum.Undef || bct.type == BCTypeEnum.Ptr);
}

static assert(!isBasicBCType(BCType(BCTypeEnum.Array, 1)));

const(bool) isStackValueOrParameter(const BCValue val) pure @safe nothrow
{
    return (val.vType == BCValueType.StackValue || val.vType == BCValueType.Parameter || val.vType == BCValueType.Local);
}

enum BCTypeEnum : ubyte
{
    Undef,

    Null,
    Void,

    c8,
    c16,
    c32,
    Char = c32,
    /// signed by default
    i8,
    /// DITTO
    i16,
    /// DITTO
    i32,
    /// DITTO
    i64,

    u8,
    u16,
    u32,
    u64,

    f23, /// 32  bit float mantissa has 23 bit
    f52, /// 64  bit float mantissa has 52 bit
    f106, /// 128 bit float mantissa has 106 but (52+52)

    string8,
    String = string8,
    string16,
    string32,

    Function, // synonymous to i32
    //  everything below here is not used by the bc layer.
    Array,
    Struct,
    Ptr,
    Slice,

}

enum BCTypeFlags : ubyte
{
    None = 0x0,
    Const = 0x1,
}

struct BCType
{
    BCTypeEnum type;
    alias type this;
    uint typeIndex;
    // additional information
    BCTypeFlags flags;

    string toString() const pure @safe
    {
        import std.conv;

        string result;

        result ~= "BCType(type: " ~ to!string(type) ~ ", " ~ "typeIndex: " ~ to!string(
                typeIndex) ~ ", " ~ "flags: " ~ to!string(flags) ~ ")";

        return result;
    }
}

enum BCValueType : ubyte
{
    Unknown = 0,

    Temporary = 1,
    Parameter = 2,
    Local = 3,

    StackValue = 1 << 3,
    Immediate = 2 << 3,
    VoidValue = 3 << 3,

    HeapValue = 4 << 3,

    LastCond = 0xFD,
    Bailout = 0xFE,
    Error = 0xFF, //Pinned = 0x80,
    /// Pinned values can be returned
    /// And should be kept in the compacted heap

}

const(ubyte) toParamCode(const BCValue val) pure @safe @nogc
{
    if (val.type.type == BCTypeEnum.i32)
        return 0b0000;
    /*else if (val.type.type)
        return 0b0001;*/
    else if (val.type.type == BCTypeEnum.Struct)
        return 0b0010;
    else if (val.type.type == BCTypeEnum.Slice
            || val.type.type == BCTypeEnum.Array || val.type.type == BCTypeEnum.String)
        return 0b0011;
    else
        assert(0, "ParameterType unsupported");
}

struct BCHeap
{
    static struct HeapEntry
    {
        uint address;
        BCType type;
        uint size;
    }

    HeapEntry[] entries;
    uint[] _heap = new uint[](2 ^^ 15);
    uint heapMax = (2 ^^ 15);
    uint heapSize = 4;

    HeapAddr pushString(const char* _string, const uint size) pure
    {
        auto result = HeapAddr(heapSize);
        //entries ~= HeapEntry(heapSize, BCType(BCTypeEnum.String, 0), size);

        assert(heapSize + size + 1 < heapMax, "Heap overflow");

        _heap[heapSize++] = size;

        immutable SizeOverFour = size / 4;

        foreach (i; 0 .. SizeOverFour)
        {
            _heap[heapSize++] = (*(_string + (i * 4))) | (
                    *(_string + (i * 4) + 1)) << 8 | (
                    *(_string + (i * 4) + 2)) << 16 | (*(_string + (i * 4) + 3)) << 24;
        }

        final switch (size - 1 & 3)
        {
        case 3:
            _heap[heapSize] |= (*(_string + (SizeOverFour * 4) + 3)) << 24;
            goto case 2;
        case 2:
            _heap[heapSize] |= (*(_string + (SizeOverFour * 4) + 2)) << 16;
            goto case 1;
        case 1:
            _heap[heapSize] |= (*(_string + (SizeOverFour * 4) + 1)) << 8;
            goto case 0;
        case 0:
            _heap[heapSize++] |= (*(_string + (SizeOverFour * 4)));
        }

        if ((size & 3) == 3)
        {
            heapSize++;
        }

        heapSize = align4(heapSize);
        return result;
    }
}

struct BCLabel
{
    BCAddr addr;
}

struct BCAddr
{
    uint addr;
    alias addr this;

    //    T opCast(T : bool)()
    //    {
    //        return addr != 0;
    //    }
}

struct BCLocal
{
    ushort idx;
    BCType type;
    StackAddr addr;
    string name;
}

struct BCParameter
{
    ubyte idx;
    BCType type;
    StackAddr pOffset;
}

struct HeapAddr
{
    uint addr;
    alias addr this;
}

struct StackAddr
{
    short addr;
    alias addr this;
}

struct Imm32
{
    uint imm32;
    alias imm32 this;
}

BCValue imm32(uint value) pure @trusted
{
    BCValue ret = void;
    ret.vType = BCValueType.Immediate;
    ret.type.type = BCTypeEnum.i32;
    ret.type.flags = BCTypeFlags.None;
    ret.imm32 = value;
    return ret;
}

BCValue i32(BCValue val) pure @safe
{
    val.type.type = BCTypeEnum.i32;
    return val;
}

struct Imm64
{
    ulong imm64;
    alias imm64 this;
}

struct Imm23f
{
    float imm23f;
    alias imm23f this;
}

struct Imm52f
{
    double imm52f;
    alias imm52f this;
}

struct BCBlock
{
@safe pure:
    bool opCast(T : bool)()
    {
        // since 0 is an invalid address it is enough to check if begin is 0
        return !!begin.addr.addr;
    }

    BCLabel begin;
    BCLabel end;
}

struct BCBranch
{
    BCLabel ifTrue;
    BCLabel ifFalse;
}

struct BCHeapRef
{
    BCValueType vType;
    union
    {
        ushort tmpIndex;
        ushort localIndex;
    }

    union
    {
        HeapAddr heapAddr;
        StackAddr stackAddr;
        Imm32 imm32;
    }

@safe pure:
    bool opCast(T : bool)() const pure
    {
        // the check for Undef is a workaround
        // consider removing it when everything works correctly.

        return this.vType != vType.Unknown;
    }

    this(const(BCValue) that)
    {
        switch (that.vType)
        {
        case BCValueType.StackValue, BCValueType.Parameter:
        case BCValueType.Temporary:
            stackAddr = that.stackAddr;
            tmpIndex = that.tmpIndex;
            break;

        case BCValueType.Local:
            stackAddr = that.stackAddr;
            localIndex = that.localIndex;
            break;

        case BCValueType.HeapValue:
            heapAddr = that.heapAddr;
            break;

        case BCValueType.Immediate:
            imm32 = that.imm32;
            break;

        default:
            import std.conv : to;

            assert(0, "vType unsupported: " ~ to!string(that.vType));
        }
        vType = that.vType;
    }
}

struct BCValue
{
    uint _; // avoid compile-time issues

    BCType type;
    BCValueType vType;
    union
    {
        byte paramIndex;
        ushort tmpIndex;
        ushort localIndex;
    }

    union
    {
        StackAddr stackAddr;
        HeapAddr heapAddr;
        Imm32 imm32;
        Imm64 imm64;
/* for now we represent floats in imm32 or imm64 respectivly
        Imm23f imm23f;
        Imm52f imm52f;
*/
        // instead of void*
        void* voidStar;
    }

    //TOTO PERF minor: use a 32bit value for heapRef;
    BCHeapRef heapRef;
    string name;

    uint toUint() const pure
    {
        switch (this.vType)
        {
        case BCValueType.Parameter, BCValueType.Temporary,
                BCValueType.StackValue:
                return stackAddr;
        case BCValueType.HeapValue:
            return heapAddr;
        case BCValueType.Immediate:
            return imm32;
        case BCValueType.Unknown:
            return this.imm32;
        default:
            {
                import std.conv : to;

                assert(0, "toUint not implement for " ~ vType.to!string);
            }
        }

    }

    string toString() const pure @safe
    {

        string result = "vType: ";
        result ~= enumToString(vType);
        result ~= "\tType: "; 
        result ~= type.toString;
        result ~= "\tValue: ";
        result ~= valueToString;
        result ~= "\n";

        return result;
    }

    string valueToString() const pure @safe
    {
        import std.conv;

        switch (vType)
        {
        case BCValueType.Local : goto case;
        case BCValueType.Parameter, BCValueType.Temporary,
                BCValueType.StackValue:
                return "stackAddr: " ~ to!string(stackAddr);
        case BCValueType.HeapValue:
            return "heapAddr: " ~ to!string(heapAddr);
        case BCValueType.Immediate:
            return "imm: " ~ (type.type == BCTypeEnum.i64 || type.type == BCTypeEnum.f52
                    ? to!string(imm64) : to!string(imm32));
        default:
            return "unkown value format";
        }
    }

@safe pure:
    bool opCast(T : bool)() const pure
    {
        // the check for Undef is a workaround
        // consider removing it when everything works correctly.

        return this.vType != vType.Unknown && this.type.type != BCTypeEnum.Undef
            && this.vType != vType.VoidValue;
    }

    bool opEquals(const BCValue rhs) pure const
    {
        if (this.vType == rhs.vType && this.type == rhs.type)
        {
            final switch (this.vType)
            {
            case BCValueType.StackValue, BCValueType.VoidValue,
                    BCValueType.Parameter, BCValueType.Local:
                    return this.stackAddr == rhs.stackAddr;
            case BCValueType.Temporary:
                return tmpIndex == rhs.tmpIndex;
            case BCValueType.Immediate:
                switch (this.type.type)
                {
                case BCTypeEnum.i32:
                    {
                        return imm32.imm32 == rhs.imm32.imm32;
                    }
                case BCTypeEnum.i64:
                    {
                        return imm64.imm64 == rhs.imm64.imm64;
                    }

                default:
                    assert(0, "No comperasion for immediate");
                }
            case BCValueType.HeapValue:
                return this.heapAddr == rhs.heapAddr;

            case BCValueType.Unknown, BCValueType.Bailout:
                return false;
            case BCValueType.Error:
                return false;
            case BCValueType.LastCond:
                return true;
            }

        }

        return false;
    }

    this(const Imm32 imm32) pure
    {
        this.type.type = BCTypeEnum.i32;
        this.vType = BCValueType.Immediate;
        this.imm32 = imm32;
    }

    this(const Imm64 imm64) pure
    {
        this.type.type = BCTypeEnum.i64;
        this.vType = BCValueType.Immediate;
        this.imm64 = imm64;
    }

    this(const Imm23f imm23f) pure @trusted
    {
        this.type.type = BCTypeEnum.f23;
        this.vType = BCValueType.Immediate;
        this.imm32.imm32 = *cast(uint*)&imm23f;
    }

    this(const Imm52f imm52f) pure @trusted
    {
        this.type.type = BCTypeEnum.f52;
        this.vType = BCValueType.Immediate;
        this.imm64.imm64 = *cast(ulong*)&imm52f;
    }

    this(const BCParameter param) pure
    {
        this.vType = BCValueType.Parameter;
        this.type = param.type;
        this.paramIndex = param.idx;
        this.stackAddr = param.pOffset;
    }

    this(const StackAddr sp, const BCType type, const ushort tmpIndex = 0) pure
    {
        this.vType = BCValueType.StackValue;
        this.stackAddr = sp;
        this.type = type;
        this.tmpIndex = tmpIndex;
    }

    this(const StackAddr sp, const BCType type, const ushort localIndex, string name) pure
    {
        this.vType = BCValueType.Local;
        this.stackAddr = sp;
        this.type = type;
        this.localIndex = localIndex;
        this.name = name;
    }

    this(const void* base, const short addr, const BCType type) pure
    {
        this.vType = BCValueType.StackValue;
        this.stackAddr = StackAddr(addr);
        this.type = type;
    }

    this(const HeapAddr addr, const BCType type = i32Type) pure
    {
        this.vType = BCValueType.HeapValue;
        this.type = type;
        this.heapAddr = addr;
    }

    this(const BCHeapRef heapRef) pure
    {
        this.vType = heapRef.vType;
        switch (vType)
        {
        case BCValueType.StackValue, BCValueType.Parameter:
            stackAddr = heapRef.stackAddr;
            tmpIndex = heapRef.tmpIndex;
            break;
        case BCValueType.Local:
            stackAddr = heapRef.stackAddr;
            tmpIndex = heapRef.localIndex;
            break;

        case BCValueType.Temporary:
            stackAddr = heapRef.stackAddr;
            tmpIndex = heapRef.tmpIndex;
            break;

        case BCValueType.HeapValue:
            heapAddr = heapRef.heapAddr;
            break;

        case BCValueType.Immediate:
            imm32 = heapRef.imm32;
            break;

        default:
            import std.conv : to;

            assert(0, "vType unsupported: " ~ to!string(vType));
        }
    }
}

pragma(msg, "Sizeof BCValue: ", BCValue.sizeof);
__gshared static immutable bcLastCond = () {
    BCValue result;
    result.vType = BCValueType.LastCond;
    return result;
}();

__gshared static immutable bcNull = () {
    BCValue result;
    result.vType = BCValueType.Immediate;
    result.type.type = BCTypeEnum.Null;
    return result;
}();

__gshared static immutable bcFour = BCValue(Imm32(4));
__gshared static immutable bcOne = BCValue(Imm32(1));
__gshared static immutable bcZero = BCValue(Imm32(0));
__gshared static immutable i32Type = BCType(BCTypeEnum.i32);

template BCGenFunction(T, alias fn)
{
    static assert(ensureIsBCGen!T && is(typeof(fn()) == T));
    BCValue[] params;

    static if (is(typeof(T.init.functionalize()) == string))
    {
        static immutable BCGenFunction = mixin(fn().functionalize);
    }
    else /*static if (is(typeof(T.init.interpret(typeof(T.init.byteCode), typeof(params).init)()) : int))*/
    {
        static immutable BCGenFunction = ((BCValue[] args,
                BCHeap* heapPtr) => fn().interpret(args, heapPtr));
    }
}

template ensureIsBCGen(BCGenT)
{
    static assert(is(typeof(BCGenT.beginFunction(uint.init)) == void),
            BCGenT.stringof ~ " is missing void beginFunction(uint)");
    static assert(is(typeof(BCGenT.endFunction())), BCGenT.stringof ~ " is missing endFunction()");
    static assert(is(typeof(BCGenT.Initialize()) == void),
            BCGenT.stringof ~ " is missing void Initialize()");
    static assert(is(typeof(BCGenT.Finalize()) == void),
            BCGenT.stringof ~ " is missing void Finalize()");
    static assert(is(typeof(BCGenT.genTemporary(BCType.init)) == BCValue),
            BCGenT.stringof ~ " is missing BCValue genTemporary(BCType bct)");
    static assert(is(typeof(BCGenT.genParameter(BCType.init, string.init)) == BCValue),
            BCGenT.stringof ~ " is missing BCValue genParameter(BCType bct, string name)");
    static assert(is(typeof(BCGenT.beginJmp()) == BCAddr),
            BCGenT.stringof ~ " is missing BCAddr beginJmp()");
    static assert(is(typeof(BCGenT.endJmp(BCAddr.init, BCLabel.init)) == void),
            BCGenT.stringof ~ " is missing void endJmp(BCAddr atIp, BCLabel target)");
    static assert(is(typeof(BCGenT.incSp()) == void), BCGenT.stringof ~ " is missing void incSp()");
    static assert(is(typeof(BCGenT.currSp()) == StackAddr),
            BCGenT.stringof ~ " is missing StackAddr currSp()");
    static assert(is(typeof(BCGenT.genLabel()) == BCLabel),
            BCGenT.stringof ~ " is missing BCLabel genLabel()");
    static assert(is(typeof(BCGenT.beginCndJmp(BCValue.init, bool.init)) == CndJmpBegin),
            BCGenT.stringof
            ~ " is missing CndJmpBegin beginCndJmp(BCValue cond = BCValue.init, bool ifTrue = false)");
    static assert(is(typeof(BCGenT.endCndJmp(CndJmpBegin.init, BCLabel.init)) == void),
            BCGenT.stringof ~ " is missing void endCndJmp(CndJmpBegin jmp, BCLabel target)");
    static assert(is(typeof(BCGenT.genJump(BCLabel.init)) == void),
            BCGenT.stringof ~ " is missing void genJump(BCLabel target)");
    static assert(is(typeof(BCGenT.emitFlg(BCValue.init)) == void),
            BCGenT.stringof ~ " is missing void emitFlg(BCValue lhs)");
    static assert(is(typeof(BCGenT.Alloc(BCValue.init, BCValue.init)) == void),
            BCGenT.stringof ~ " is missing void Alloc(BCValue heapPtr, BCValue size)");
    static assert(is(typeof(BCGenT.Assert(BCValue.init, BCValue.init)) == void),
            BCGenT.stringof ~ " is missing void Assert(BCValue value, BCValue message)");
    static assert(is(typeof(BCGenT.Not(BCValue.init, BCValue.init)) == void),
            BCGenT.stringof ~ " is missing void Not(BCValue result, BCValue val)");
    static assert(is(typeof(BCGenT.Set(BCValue.init, BCValue.init)) == void),
            BCGenT.stringof ~ " is missing void Set(BCValue lhs, BCValue rhs)");
    static assert(is(typeof(BCGenT.Lt3(BCValue.init, BCValue.init, BCValue.init)) == void),
            BCGenT.stringof ~ " is missing void Lt3(BCValue result, BCValue lhs, BCValue rhs)");
    static assert(is(typeof(BCGenT.Gt3(BCValue.init, BCValue.init, BCValue.init)) == void),
            BCGenT.stringof ~ " is missing void Gt3(BCValue result, BCValue lhs, BCValue rhs)");
    static assert(is(typeof(BCGenT.Eq3(BCValue.init, BCValue.init, BCValue.init)) == void),
            BCGenT.stringof ~ " is missing void Eq3(BCValue result, BCValue lhs, BCValue rhs)");
    static assert(is(typeof(BCGenT.Neq3(BCValue.init, BCValue.init, BCValue.init)) == void),
            BCGenT.stringof ~ " is missing void Neq3(BCValue result, BCValue lhs, BCValue rhs)");
    static assert(is(typeof(BCGenT.Add3(BCValue.init, BCValue.init, BCValue.init)) == void),
            BCGenT.stringof ~ " is missing void Add3(BCValue result, BCValue lhs, BCValue rhs)");
    static assert(is(typeof(BCGenT.Sub3(BCValue.init, BCValue.init, BCValue.init)) == void),
            BCGenT.stringof ~ " is missing void Sub3(BCValue result, BCValue lhs, BCValue rhs)");
    static assert(is(typeof(BCGenT.Mul3(BCValue.init, BCValue.init, BCValue.init)) == void),
            BCGenT.stringof ~ " is missing void Mul3(BCValue result, BCValue lhs, BCValue rhs)");
    static assert(is(typeof(BCGenT.Div3(BCValue.init, BCValue.init, BCValue.init)) == void),
            BCGenT.stringof ~ " is missing void Div3(BCValue result, BCValue lhs, BCValue rhs)");
    static assert(is(typeof(BCGenT.And3(BCValue.init, BCValue.init, BCValue.init)) == void),
            BCGenT.stringof ~ " is missing void And3(BCValue result, BCValue lhs, BCValue rhs)");
    static assert(is(typeof(BCGenT.Or3(BCValue.init, BCValue.init, BCValue.init)) == void),
            BCGenT.stringof ~ " is missing void Or3(BCValue result, BCValue lhs, BCValue rhs)");
    static assert(is(typeof(BCGenT.Xor3(BCValue.init, BCValue.init, BCValue.init)) == void),
            BCGenT.stringof ~ " is missing void Xor3(BCValue result, BCValue lhs, BCValue rhs)");
    static assert(is(typeof(BCGenT.Lsh3(BCValue.init, BCValue.init, BCValue.init)) == void),
            BCGenT.stringof ~ " is missing void Lsh3(BCValue result, BCValue lhs, BCValue rhs)");
    static assert(is(typeof(BCGenT.Rsh3(BCValue.init, BCValue.init, BCValue.init)) == void),
            BCGenT.stringof ~ " is missing void Rsh3(BCValue result, BCValue lhs, BCValue rhs)");
    static assert(is(typeof(BCGenT.Mod3(BCValue.init, BCValue.init, BCValue.init)) == void),
            BCGenT.stringof ~ " is missing void Mod3(BCValue result, BCValue lhs, BCValue rhs)");
    static assert(is(typeof(BCGenT.Call(BCValue.init, BCValue.init,
            BCValue[].init)) == void),
            BCGenT.stringof ~ " is missing void Call(BCValue result, BCValue fn, BCValue[] args)");
    static assert(is(typeof(BCGenT.Load32(BCValue.init, BCValue.init)) == void),
            BCGenT.stringof ~ " is missing void Load32(BCValue _to, BCValue from)");
    static assert(is(typeof(BCGenT.Store32(BCValue.init, BCValue.init)) == void),
            BCGenT.stringof ~ " is missing void Store32(BCValue _to, BCValue value)");
/*
    static assert(is(typeof(BCGenT.Load64(BCValue.init, BCValue.init)) == void),
        BCGenT.stringof ~ " is missing void Load64(BCValue _to, BCValue from)");
    static assert(is(typeof(BCGenT.Store64(BCValue.init, BCValue.init)) == void),
        BCGenT.stringof ~ " is missing void Store64(BCValue _to, BCValue value)");
*/
    static assert(is(typeof(BCGenT.Ret(BCValue.init)) == void),
            BCGenT.stringof ~ " is missing void Ret(BCValue val)");
    static assert(is(typeof(BCGenT.insideFunction) == bool),
        BCGenT.stringof ~ " is missing bool insideFunction");

    enum ensureIsBCGen = true;
}

/// commonType enum used for implicit conversion
static immutable smallIntegerTypes = [BCTypeEnum.i32, BCTypeEnum.i16, BCTypeEnum.i8];

BCTypeEnum commonTypeEnum(BCTypeEnum lhs, BCTypeEnum rhs) pure @safe
{
    // HACK

    BCTypeEnum commonType;

    if (lhs == BCTypeEnum.f52 || rhs == BCTypeEnum.f52)
    {
        commonType = BCTypeEnum.f52;
    }
    else if (lhs == BCTypeEnum.f23 || rhs == BCTypeEnum.f23)
    {
        commonType = BCTypeEnum.f23;
    }
    else if (lhs == BCTypeEnum.i64 || rhs == BCTypeEnum.i64)
    {
        commonType = BCTypeEnum.i64;
    }
    else if (lhs.anyOf(smallIntegerTypes) || rhs.anyOf(smallIntegerTypes))
        commonType = BCTypeEnum.i32;

    return commonType;
}
