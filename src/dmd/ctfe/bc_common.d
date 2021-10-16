module dmd.ctfe.bc_common;

import dmd.ctfe.fpconv_ctfe;

/// functions with index skipFn will be skipped
/// calling them is equivlent to an expensive nop
/// this is true for direct and indirect calls
enum skipFn = uint.max;
enum nodeFromName = uint.max - 1;
enum currentScope = uint.max - 2;

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

static void storeu32(ubyte* ptr, const uint v32) pure nothrow
{
    pragma(inline, true);
    ptr[0] = (v32 >> 0)  & 0xFF;
    ptr[1] = (v32 >> 8)  & 0xFF;
    ptr[2] = (v32 >> 16) & 0xFF;
    ptr[3] = (v32 >> 24) & 0xFF;
}

static uint loadu32(const ubyte* ptr) pure nothrow
{
    pragma(inline, true);
    uint v32 = (ptr[0] << 0)
             | (ptr[1] << 8)
             | (ptr[2] << 16)
             | (ptr[3] << 24);
    return v32;
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

uint adjustmentMask(BCTypeEnum t)
{
    uint mask = 0;
    const typeSize = basicTypeSize(t);
    if (typeSize == 1)
        mask = 0xFF;
    else if (typeSize == 2)
        mask = 0xFFFF;

    return mask;
}


const(uint) fastLog10(const uint val) pure nothrow @nogc @safe
{
    return (val < 10) ? 0 : (val < 100) ? 1 : (val < 1000) ? 2 : (val < 10000) ? 3
        : (val < 100000) ? 4 : (val < 1000000) ? 5 : (val < 10000000) ? 6
        : (val < 100000000) ? 7 : (val < 1000000000) ? 8 : 9;
}

/*@unique*/
static immutable fastPow10tbl = [
    1, 10, 100, 1000, 10000, 100000, 1000000, 10000000, 100000000, 1000000000,
];

string itos(const uint val) pure @trusted nothrow
{
    immutable length = fastLog10(val) + 1;
    char[] result = new char[](length);

    foreach (i; 0 .. length)
    {
        immutable _val = val / fastPow10tbl[i];
        result[length - i - 1] = cast(char)((_val % 10) + '0');
    }

    return cast(string) result;
}

static assert(mixin(uint.max.itos) == uint.max);

string itos64(const ulong val) pure @trusted nothrow
{
    if (val <= uint.max)
        return itos(val & uint.max);

    uint lw = val & uint.max;
    uint hi = val >> 32;

    auto lwString = itos(lw);
    auto hiString = itos(hi);

    return cast(string) "((" ~ hiString ~ "UL << 32)" ~ "|" ~ lwString ~ ")";
}

string sitos(const int val) pure @trusted nothrow
{
    int sign = (val < 0) ? 1 : 0;
    uint abs_val = (val < 0) ? -val : val;

    immutable length = fastLog10(abs_val) + 1;
    char[] result;
    result.length = length + sign;

    foreach (i; 0 .. length)
    {
        immutable _val = abs_val / fastPow10tbl[i];
        result[length - i - !sign] = cast(char)((_val % 10) + '0');
    }

    if (sign)
    {
        result[0] = '-';
    }

    return cast(string) result;
}

string floatToString(float f)
{
    return fpconv_dtoa(f) ~ "f";
}

string doubleToString(double d)
{
   return fpconv_dtoa(d);
}

const(uint) basicTypeSize(const BCTypeEnum bct) @safe pure
{
    final switch (bct) with (BCTypeEnum)
    {

    case Undef:
        {
            debug (ctfe) {
                assert(0, "We should never encounter undef or bailout");
            } else {
                return 0;
            }
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
    case Delegate :
        {
            return 8;
        }
    case Ptr :
            assert(0, "Ptr is not supposed to be a basicType anymore");

    case string8, string16, string32:
        {
            //FIXME actually strings don't have a basicTypeSize as is
            return 16;
        }


    case Void, Array, Slice, Struct, Class, AArray:
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
    return !(bct.type == BCTypeEnum.Struct || bct.type == BCTypeEnum.Array || bct.type == BCTypeEnum.Class
            || bct.type == BCTypeEnum.Slice || bct.type == BCTypeEnum.Undef || bct.type == BCTypeEnum.Ptr
            || bct.type == BCTypeEnum.AArray);
}

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
    f106, /// 128 bit float mantissa has 106 bit (52+52)

    string8,
    string16,
    string32,

    Function, // synonymous to i32
    Delegate, // synonymous to {i32, i32}

    //  everything below here is not used by the bc layer.
    Array,
    AArray,
    Struct,
    Class,
    Ptr,
    Slice,

}

enum BCTypeFlags : ubyte
{
    None = 0,
    Const = 1 << 0,
}

string typeFlagsToString(BCTypeFlags flags) pure @safe
{
    string result;
 
    if (!flags)
    {
        result = "None";
        goto Lret;
    }

    if (flags & flags.Const)
    {
        result ~= "Const|";
    }

    // trim last |
    result = result[0 .. $-1];

Lret:
    return result;
}

struct RegStatusList(int STATIC_NREGS)
{
    static assert(STATIC_NREGS < 32);

    static if (STATIC_NREGS == 0)
    {
        const int NREGS;
        uint freeBitfield;

        this(int NREGS) pure
        {
            assert(NREGS < 32, "extending freeBitField is not yet done");
            this.NREGS = NREGS;
            freeBitfield = ((1 << NREGS) - 1);
        }
    }
    else
    {
        alias NREGS = STATIC_NREGS;
        uint freeBitfield = ((1 << NREGS) - 1);
    }

    uint unusedBitfield = 0;
    uint dirtyBitfield = 0;
    
    uint nextFree()
    {
        pragma(inline, true);
        import core.bitop : bsf;
        
        uint result = 0;
        if (freeBitfield != 0)
            result = bsf(freeBitfield) + 1;
        return result;
    }
    
    uint nextUnused()
    {
        pragma(inline, true);
        import core.bitop : bsf;
        
        uint result = 0;
        if (unusedBitfield)
            result = bsf(unusedBitfield) + 1;
        return result;
    }
    
    uint nextDirty()
    {
        pragma(inline, true);
        import core.bitop : bsf;
        
        uint result = 0;
        if (dirtyBitfield)
            result = bsf(dirtyBitfield) + 1;
        return result;
    }
    
    uint n_free()
    {
        pragma(inline, true);
        import core.bitop : popcnt;
        assert(popcnt(freeBitfield) <= NREGS);
        return popcnt(freeBitfield);
    }
    
    /// mark register as unoccupied
    void markFree(int regIdx)
    {
        pragma(inline, true);
        assert(regIdx && regIdx <= NREGS);
        freeBitfield |= (1 << (regIdx - 1));
    }
    
    /// mark register as eviction canidate
    void markUnused(int regIdx)
    {
        pragma(inline, true);
        assert(regIdx && regIdx <= NREGS);
        unusedBitfield |= (1 << (regIdx - 1));
    }
    
    /// mark register as used
    void markUsed(int regIdx)
    {
        pragma(inline, true);
        assert(regIdx && regIdx <= NREGS);
        freeBitfield &= ~(1 << (regIdx - 1));
        unusedBitfield &= ~(1 << (regIdx - 1));
    }
    
    void markClean(int regIdx)
    {
        pragma(inline, true);
        assert(regIdx && regIdx <= NREGS);
        dirtyBitfield &= ~(1 << (regIdx - 1));
    }
    
    void markDirty(int regIdx)
    {
        pragma(inline, true);
        assert(regIdx && regIdx <= NREGS);
        dirtyBitfield |= (1 << (regIdx - 1));
    }

    bool isDirty(int regIdx)
    {
        pragma(inline, true);
        assert(regIdx && regIdx <= NREGS);
        return (dirtyBitfield & (1 << (regIdx - 1))) != 0;
    }

    bool isUnused(int regIdx)
    {
        pragma(inline, true);
        assert(regIdx && regIdx <= NREGS);
        return (unusedBitfield & (1 << (regIdx - 1))) != 0;
    }

    bool isFree(int regIdx)
    {
        pragma(inline, true);
        assert(regIdx && regIdx <= NREGS);
        return (freeBitfield & (1 << (regIdx - 1))) != 0;
    }
}


static assert(()
    {
        RegStatusList!16 f;
        
        assert(f.n_free == 16);
        assert(f.nextDirty() == 0);
        assert(f.nextUnused() == 0);
        auto nextReg = f.nextFree();
        f.markUsed(nextReg);
        assert(f.n_free == 15);
        f.markDirty(nextReg);
        assert(f.nextDirty() == nextReg);
        f.markClean(nextReg);
        assert(f.nextDirty() == 0);
        foreach(r; 1 .. 17)
            f.markUnused(r);
        foreach(r; 0 .. 16)
        {
            auto nextUnused = f.nextUnused();
            f.markUsed(nextUnused);
        }
        assert(f.nextUnused() == 0);

        RegStatusList!0 d = RegStatusList!0(2);
        assert(d.n_free() == 2);

        return true;
    }
());


struct BCType
{
    BCTypeEnum type;
    uint typeIndex = 0;

    // additional information
    BCTypeFlags flags;

    string toString() const pure @safe
    {
        string result;

        result ~= "BCType(type: " ~ enumToString(type) ~ ", " ~ "typeIndex: " ~ itos(
                typeIndex) ~ ", " ~ "flags: " ~ typeFlagsToString(flags) ~ ")";

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
    HeapValue = 3 << 3,

    LastCond = 0xFB,
    Bailout = 0xFC,
    Exception = 0xFD,
    ErrorWithMessage = 0xFE,
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
            || val.type.type == BCTypeEnum.Array || val.type.type == BCTypeEnum.string8)
        return 0b0011;
    else
        assert(0, "ParameterType unsupported");
}

enum heapSizeOffset = BCHeap.init.heapSize.offsetof;
enum heapMaxOffset = BCHeap.init.heapMax.offsetof;
enum heapDataOffset = BCHeap.init.heapData.offsetof;

enum heapDataLengthOffset = heapDataOffset + 0; // should really be [].length.offsetof
enum heapDataPtrOffset = heapDataOffset + size_t.sizeof;  // should be [].ptr.offsetof        

struct BCHeap
{
    enum initHeapMax = (2 ^^ 15);
    uint heapMax = initHeapMax;
    uint heapSize = 4;
    ubyte[] heapData = new ubyte[](initHeapMax);
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
    string name;
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
    bool signed = true;
}

BCValue imm32(uint value, bool signed = false) pure @trusted
{
    BCValue ret;

    ret.vType = BCValueType.Immediate;
    ret.type.type = signed ? BCTypeEnum.i32 : BCTypeEnum.u32;
    ret.type.typeIndex = 0;
    ret.type.flags = BCTypeFlags.None;
    ret.imm32.imm32 = value;
    if (!__ctfe)
    {
        ret.imm64.imm64 &= uint.max;
    }
    return ret;
}

BCValue imm64(ulong value, bool signed = false) pure @trusted
{
    BCValue ret;

    ret.vType = BCValueType.Immediate;
    ret.type.type = signed ? BCTypeEnum.i64 : BCTypeEnum.u64;
    ret.type.typeIndex = 0;
    ret.type.flags = BCTypeFlags.None;
    ret.imm64.imm64 = value;
    return ret;
}

BCValue i32(BCValue val) pure @safe nothrow
{
    val.type.type = BCTypeEnum.i32;
    return val;
}

BCValue u32(BCValue val) pure @safe nothrow
{
    val.type.type = BCTypeEnum.u32;
    return val;
}


struct Imm64
{
    ulong imm64;
    alias imm64 this;
    bool signed = true;
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

    string name;

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
            this.name = that.name;
            break;

        case BCValueType.HeapValue:
            heapAddr = that.heapAddr;
            break;

        case BCValueType.Immediate:
            imm32 = that.imm32;
            break;

        default:
            assert(0, "vType unsupported: " ~ enumToString(that.vType));
        }
        vType = that.vType;
    }
}

struct BCValue
{
    BCType type;
    BCValueType vType;
    bool couldBeVoid = false;

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
/* for now we represent floats in imm32 or imm64 respectively
        Imm23f imm23f;
        Imm52f imm52f;
*/
        // instead of void*
        void* voidStar;
    }

    //TODO PERF minor: use a 32bit value for heapRef;
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
                assert(0, "toUint not implemented for " ~ enumToString(vType));
            }
        }

    }

    string toString() const pure @safe
    {
        string result = "vType: ";
        result ~= enumToString(vType);
        result ~= "\tType: "; 
        result ~= type.toString;
        result ~= "\n\tValue: ";
        result ~= valueToString;
        result ~= "\n";
        if (name)
            result ~= "\tname: " ~ name ~ "\n";

        return result;
    }

    string valueToString() const pure @safe
    {
        switch (vType)
        {
        case BCValueType.Local : goto case;
        case BCValueType.Parameter, BCValueType.Temporary,
                BCValueType.StackValue:
                return "stackAddr: " ~ itos(stackAddr);
        case BCValueType.HeapValue:
            return "heapAddr: " ~ itos(heapAddr);
        case BCValueType.Immediate:
            return "imm: " ~ (type.type == BCTypeEnum.i64 || type.type == BCTypeEnum.f52
                    ? itos64(imm64) : itos(imm32));
        default:
            return "unknown value format";
        }
    }

@safe pure:
    bool opCast(T : bool)() const pure
    {
        // the check for Undef is a workaround
        // consider removing it when everything works correctly.

        return this.vType != vType.Unknown && this.type.type != BCTypeEnum.Undef;
    }

    bool opEquals(const BCValue rhs) const
    {
        BCTypeEnum commonType = commonTypeEnum(this.type.type, rhs.type.type);
       
        if (this.vType == rhs.vType)
        {
            final switch (this.vType)
            {
            case BCValueType.StackValue,
                    BCValueType.Parameter, BCValueType.Local:
                    return this.stackAddr == rhs.stackAddr;
            case BCValueType.Temporary:
                return tmpIndex == rhs.tmpIndex;
            case BCValueType.Immediate:
                switch (commonType)
                {
                case BCTypeEnum.i32, BCTypeEnum.u32:
                    {
                        return imm32.imm32 == rhs.imm32.imm32;
                    }
                case BCTypeEnum.i64, BCTypeEnum.u64:
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
            case BCValueType.Error, BCValueType.ErrorWithMessage,
                        BCValueType.Exception:
                return false;
            case BCValueType.LastCond:
                return true;
            }

        }

        return false;
    }

    this(const Imm32 imm32) pure
    {
        this.type.type = imm32.signed ? BCTypeEnum.i32 : BCTypeEnum.u32;
        this.vType = BCValueType.Immediate;
        this.imm32.imm32 = imm32.imm32;
    }

    this(const Imm64 imm64) pure
    {
        this.type.type = imm64.signed ? BCTypeEnum.i64 : BCTypeEnum.u64;
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
        this.name = param.name;
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
            name = heapRef.name;
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
            assert(0, "vType unsupported: " ~ enumToString(vType));
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
__gshared static immutable u32Type = BCType(BCTypeEnum.u32);


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
    static assert(is(typeof(BCGenT.LoadFramePointer(BCValue.init, int.init))),
            BCGenT.stringof ~ " is missing void LoadFramePointer(BCValue _to, int offset = 0)");
    static assert(is(typeof(BCGenT.genLabel()) == BCLabel),
            BCGenT.stringof ~ " is missing BCLabel genLabel()");
    static assert(is(typeof(BCGenT.beginCndJmp(BCValue.init, bool.init)) == CndJmpBegin),
            BCGenT.stringof
            ~ " is missing CndJmpBegin beginCndJmp(BCValue cond = BCValue.init, bool ifTrue = false)");
    static assert(is(typeof(BCGenT.endCndJmp(CndJmpBegin.init, BCLabel.init)) == void),
            BCGenT.stringof ~ " is missing void endCndJmp(CndJmpBegin jmp, BCLabel target)");
    static assert(is(typeof(BCGenT.Jmp(BCLabel.init)) == void),
            BCGenT.stringof ~ " is missing void Jmp(BCLabel target)");
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

    static assert(is(typeof(BCGenT.Ult3(BCValue.init, BCValue.init, BCValue.init)) == void),
            BCGenT.stringof ~ " is missing void Ult3(BCValue result, BCValue lhs, BCValue rhs)");
    static assert(is(typeof(BCGenT.Ugt3(BCValue.init, BCValue.init, BCValue.init)) == void),
            BCGenT.stringof ~ " is missing void Ugt3(BCValue result, BCValue lhs, BCValue rhs)");

    static assert(is(typeof(BCGenT.Lt3(BCValue.init, BCValue.init, BCValue.init)) == void),
            BCGenT.stringof ~ " is missing void Lt3(BCValue result, BCValue lhs, BCValue rhs)");
    static assert(is(typeof(BCGenT.Gt3(BCValue.init, BCValue.init, BCValue.init)) == void),
            BCGenT.stringof ~ " is missing void Gt3(BCValue result, BCValue lhs, BCValue rhs)");

    static assert(is(typeof(BCGenT.Le3(BCValue.init, BCValue.init, BCValue.init)) == void),
            BCGenT.stringof ~ " is missing void Le3(BCValue result, BCValue lhs, BCValue rhs)");
    static assert(is(typeof(BCGenT.Ge3(BCValue.init, BCValue.init, BCValue.init)) == void),
            BCGenT.stringof ~ " is missing void Ge3(BCValue result, BCValue lhs, BCValue rhs)");

    static assert(is(typeof(BCGenT.Ule3(BCValue.init, BCValue.init, BCValue.init)) == void),
            BCGenT.stringof ~ " is missing void Ule3(BCValue result, BCValue lhs, BCValue rhs)");
    static assert(is(typeof(BCGenT.Uge3(BCValue.init, BCValue.init, BCValue.init)) == void),
            BCGenT.stringof ~ " is missing void Uge3(BCValue result, BCValue lhs, BCValue rhs)");

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
    static assert(is(typeof(BCGenT.Udiv3(BCValue.init, BCValue.init, BCValue.init)) == void),
            BCGenT.stringof ~ " is missing void Udiv3(BCValue result, BCValue lhs, BCValue rhs)");
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
    static assert(is(typeof(BCGenT.Umod3(BCValue.init, BCValue.init, BCValue.init)) == void),
            BCGenT.stringof ~ " is missing void Umod3(BCValue result, BCValue lhs, BCValue rhs)");
    static assert(is(typeof(BCGenT.Call(BCValue.init, BCValue.init,
            BCValue[].init)) == void),
            BCGenT.stringof ~ " is missing void Call(BCValue result, BCValue fn, BCValue[] args)");

    static assert(is(typeof(BCGenT.Load8(BCValue.init, BCValue.init)) == void),
            BCGenT.stringof ~ " is missing void Load8(BCValue _to, BCValue from)");
    static assert(is(typeof(BCGenT.Store8(BCValue.init, BCValue.init)) == void),
            BCGenT.stringof ~ " is missing void Store8(BCValue _to, BCValue value)");

    static assert(is(typeof(BCGenT.Load16(BCValue.init, BCValue.init)) == void),
            BCGenT.stringof ~ " is missing void Load162(BCValue _to, BCValue from)");
    static assert(is(typeof(BCGenT.Store16(BCValue.init, BCValue.init)) == void),
            BCGenT.stringof ~ " is missing void Store16(BCValue _to, BCValue value)");

    static assert(is(typeof(BCGenT.Load32(BCValue.init, BCValue.init)) == void),
            BCGenT.stringof ~ " is missing void Load32(BCValue _to, BCValue from)");
    static assert(is(typeof(BCGenT.Store32(BCValue.init, BCValue.init)) == void),
            BCGenT.stringof ~ " is missing void Store32(BCValue _to, BCValue value)");

    static assert(is(typeof(BCGenT.Load64(BCValue.init, BCValue.init)) == void),
        BCGenT.stringof ~ " is missing void Load64(BCValue _to, BCValue from)");
    static assert(is(typeof(BCGenT.Store64(BCValue.init, BCValue.init)) == void),
        BCGenT.stringof ~ " is missing void Store64(BCValue _to, BCValue value)");

    static assert(is(typeof(BCGenT.Ret(BCValue.init)) == void),
            BCGenT.stringof ~ " is missing void Ret(BCValue val)");
    static assert(is(typeof(BCGenT.insideFunction) == bool),
        BCGenT.stringof ~ " is missing bool insideFunction");

    enum ensureIsBCGen = true;
}

/// commonType enum used for implicit conversion
static immutable smallIntegerTypes = [BCTypeEnum.u16, BCTypeEnum.u8,
                                      BCTypeEnum.i16, BCTypeEnum.i8,
                                      BCTypeEnum.c32, BCTypeEnum.c16, BCTypeEnum.c8];

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
    else if (lhs == BCTypeEnum.u64 || rhs == BCTypeEnum.u64)
    {
        commonType = BCTypeEnum.u64;
    }
    else if (lhs == BCTypeEnum.i64 || rhs == BCTypeEnum.i64)
    {
        commonType = BCTypeEnum.i64;
    }
    else if (lhs == BCTypeEnum.u32 || rhs == BCTypeEnum.u32)
    {
        commonType = BCTypeEnum.u32;
    }
    else if (lhs == BCTypeEnum.i32 || rhs == BCTypeEnum.i32)
    {
        commonType = BCTypeEnum.i32;
    }
    else if (lhs.anyOf(smallIntegerTypes) || rhs.anyOf(smallIntegerTypes))
    {
        commonType = BCTypeEnum.i32;
    }

    if (commonType == BCTypeEnum.init)
    {
        import std.stdio;
        debug { if (!__ctfe) writeln("could not find common type for lhs: ", lhs, " and rhs: ", rhs); }
    }

    return commonType;
}
