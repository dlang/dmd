module ddmd.ctfe.bc_printer_backend;

import ddmd.ctfe.bc_common;

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
}

struct Print_BCGen
{
    import std.conv;

    struct FunctionState
    {
        uint cndJumpCount;
        uint jmpCount;
        ubyte parameterCount;
        ushort temporaryCount;
        uint labelCount;
        bool sameLabel;
        StackAddr sp = StackAddr(4);
    }
    bool insideFunction = false;

    FunctionState[ubyte.max * 8] functionStates;
    uint functionStateCount;
    uint currentFunctionStateNumber;

    @property FunctionState* currentFunctionState()
    {
        return &functionStates[currentFunctionStateNumber];
    }

    @property string functionSuffix()
    {
        return currentFunctionStateNumber > 0 ? "_fn_" ~ to!string(currentFunctionStateNumber) : "";
    }

    alias currentFunctionState this;

    string result = "\n";

    string print(BCLabel label)
    {
        return ("label" ~ to!string(label.addr.addr));
    }

    string print(BCType type)
    {
        return "BCType(BCTypeEnum." ~ to!string(type.type) ~ (
            isBasicBCType(type) ? ")" : (", " ~ to!string(type.typeIndex) ~ ")"));
    }

    string print(BCValue val)
    {
        string result = "BCValue(";

        switch (val.vType)
        {
        case BCValueType.Immediate:
            {
                if (val.type == BCTypeEnum.i32)
                {
                    result ~= "Imm32(" ~ to!string(val.imm32.imm32) ~ ")";
                }
                else if (val.type == BCTypeEnum.i64)
                {
                    result ~= "Imm64(" ~ to!string(val.imm64.imm64) ~ ")";
                }
                else if (val.type == BCTypeEnum.Null)
                {
                    result ~= "Imm32(0/*null*/)";
                }
                else if (val.type == BCTypeEnum.Array)
                {
                    result ~= "Imm32(" ~ to!string(val.imm32.imm32) ~ "/*Array*/)";
                }
                else
                {
                    assert(0, "Unexpeced Immediate of Type" ~ to!string(val.type.type));
                }
            }
            break;

        case BCValueType.StackValue:
            {
                if (val.tmpIndex)
                {
                    return "tmp" ~ to!string(val.tmpIndex) ~ functionSuffix;
                }
                result ~= "StackAddr(" ~ to!string(val.stackAddr.addr) ~ "), " ~ print(val.type);
            }
            break;
        case BCValueType.Temporary:
            {
                return "tmp" ~ to!string(val.tmpIndex) ~ functionSuffix;
            }
        case BCValueType.Parameter:
            {
                return "p" ~ to!string(val.param) ~ functionSuffix;
            }
        case BCValueType.Error:
            {
                return "Imm32(" ~ to!string(val.imm32) ~ ")/*Error*/";
            }
        case BCValueType.Unknown:
            {
                return "BCValue.init";
            }
        default:
            assert(0, "printing for " ~ to!string(val.vType) ~ " unimplemented ");
        }

        result ~= ")";

        return result;
    }

    BCLabel genLabel()
    {
        if (!sameLabel)
        {
            ++labelCount;
            result ~= "    ";
            sameLabel = true;
        }
        else
        {
            result ~= "    //";
        }
        result ~= "auto label" ~ to!string(labelCount) ~ " = genLabel();\n";
        return BCLabel(BCAddr(labelCount));
    }

    void incSp()
    {
        sameLabel = false;
        sp += 4;
        result ~= "    incSp();\n";
    }

    StackAddr currSp()
    {
        result ~= "//currSp();//SP[" ~ to!string(sp.addr) ~ "]\n";
        return sp;
    }

    void Initialize()
    {
        result ~= "    Initialize(" ~ ");\n";
    }

    void Finalize()
    {
        result ~= "    Finalize(" ~ ");\n";
    }

    void beginFunction(uint f = 0, void* fnDecl = null)
    {
        sameLabel = false;
        import ddmd.declaration : FuncDeclaration;
        import std.string;
        auto fd = cast(FuncDeclaration) fnDecl;
        result ~= "    beginFunction(" ~ to!string(f) ~ ");//" ~ fd.toChars.fromStringz ~ "\n";
    }

    void endFunction()
    {
        currentFunctionStateNumber++;
        result ~= "    endFunction(" ~ ");\n\n";
    }

    BCValue genParameter(BCType bct)
    {
        //currentFunctionStateNumber++;
        if (!parameterCount)
        {
            //write a newline when we effectivly begin a new function;
            result ~= "\n";
        }
        result ~= "    auto p" ~ to!string(++parameterCount) ~ functionSuffix ~ " = genParameter(" ~ print(
            bct) ~ ");//SP[" ~ to!string(sp) ~ "]\n";
        //currentFunctionStateNumber--;
        sp += 4;
        return BCValue(BCParameter(parameterCount, bct));
    }

    BCValue genTemporary(BCType bct)
    {
        sameLabel = false;
        auto tmpAddr = sp.addr;
        sp += align4(basicTypeSize(bct));

        result ~= "    auto tmp" ~ to!string(++temporaryCount) ~ functionSuffix ~ " = genTemporary(" ~ print(
            bct) ~ ");//SP[" ~ to!string(tmpAddr) ~ "]\n";
        return BCValue(StackAddr(tmpAddr), bct, temporaryCount);
    }

    BCAddr beginJmp()
    {
        sameLabel = false;
        result ~= "    auto jmp" ~ to!string(++jmpCount) ~ functionSuffix ~ " = beginJmp();\n";
        return BCAddr(jmpCount);
    }

    void endJmp(BCAddr atIp, BCLabel target)
    {
        sameLabel = false;
        result ~= "    endJmp(jmp" ~ to!string(atIp.addr) ~ functionSuffix ~ ", " ~ print(target) ~ functionSuffix ~ ");\n";
    }

    void genJump(BCLabel target)
    {
        sameLabel = false;
        result ~= "    genJump(" ~ print(target) ~ ");\n";
    }

    CndJmpBegin beginCndJmp(BCValue cond = BCValue.init, bool ifTrue = false)
    {
        sameLabel = false;
        result ~= "    auto cndJmp" ~ to!string(++cndJumpCount) ~ functionSuffix ~ " = beginCndJmp(" ~ (
            cond ? (print(cond) ~ (ifTrue ? ", true" : "")) : "") ~ ");\n";
        return CndJmpBegin(BCAddr(cndJumpCount), cond, ifTrue);
    }

    void endCndJmp(CndJmpBegin jmp, BCLabel target)
    {
        sameLabel = false;
        result ~= "    endCndJmp(cndJmp" ~ to!string(jmp.at.addr) ~ ", " ~ print(target) ~ ");\n";
    }

    void emitFlg(BCValue lhs)
    {
        sameLabel = false;
        result ~= "    emitFlg(" ~ print(lhs) ~ ");\n";
    }

    void Set(BCValue lhs, BCValue rhs)
    {
        if (lhs == rhs)
            return;
        sameLabel = false;
        result ~= "    Set(" ~ print(lhs) ~ ", " ~ print(rhs) ~ ");\n";
    }

    void Lt3(BCValue _result, BCValue lhs, BCValue rhs)
    {
        sameLabel = false;
        result ~= "    Lt3(" ~ print(_result) ~ ", " ~ print(lhs) ~ ", " ~ print(rhs) ~ ");\n";
    }

    void Gt3(BCValue _result, BCValue lhs, BCValue rhs)
    {
        sameLabel = false;
        result ~= "    Gt3(" ~ print(_result) ~ ", " ~ print(lhs) ~ ", " ~ print(rhs) ~ ");\n";
    }

    void Le3(BCValue _result, BCValue lhs, BCValue rhs)
    {
        sameLabel = false;
        result ~= "    Le3(" ~ print(_result) ~ ", " ~ print(lhs) ~ ", " ~ print(rhs) ~ ");\n";
    }

    void Ge3(BCValue _result, BCValue lhs, BCValue rhs)
    {
        sameLabel = false;
        result ~= "    Ge3(" ~ print(_result) ~ ", " ~ print(lhs) ~ ", " ~ print(rhs) ~ ");\n";
    }

    void Eq3(BCValue _result, BCValue lhs, BCValue rhs)
    {
        sameLabel = false;
        result ~= "    Eq3(" ~ print(_result) ~ ", " ~ print(lhs) ~ ", " ~ print(rhs) ~ ");\n";
    }

    void Neq3(BCValue _result, BCValue lhs, BCValue rhs)
    {
        sameLabel = false;
        result ~= "    Neq3(" ~ print(_result) ~ ", " ~ print(lhs) ~ ", " ~ print(rhs) ~ ");\n";
    }

    void Add3(BCValue _result, BCValue lhs, BCValue rhs)
    {
        sameLabel = false;
        result ~= "    Add3(" ~ print(_result) ~ ", " ~ print(lhs) ~ ", " ~ print(rhs) ~ ");\n";
    }

    void Sub3(BCValue _result, BCValue lhs, BCValue rhs)
    {
        sameLabel = false;
        result ~= "    Sub3(" ~ print(_result) ~ ", " ~ print(lhs) ~ ", " ~ print(rhs) ~ ");\n";
    }

    void Mul3(BCValue _result, BCValue lhs, BCValue rhs)
    {
        sameLabel = false;
        result ~= "    Mul3(" ~ print(_result) ~ ", " ~ print(lhs) ~ ", " ~ print(rhs) ~ ");\n";
    }

    void Div3(BCValue _result, BCValue lhs, BCValue rhs)
    {
        sameLabel = false;
        result ~= "    Div3(" ~ print(_result) ~ ", " ~ print(lhs) ~ ", " ~ print(rhs) ~ ");\n";
    }

    void And3(BCValue _result, BCValue lhs, BCValue rhs)
    {
        sameLabel = false;
        result ~= "    And3(" ~ print(_result) ~ ", " ~ print(lhs) ~ ", " ~ print(rhs) ~ ");\n";
    }

    void Or3(BCValue _result, BCValue lhs, BCValue rhs)
    {
        sameLabel = false;
        result ~= "    Or3(" ~ print(_result) ~ ", " ~ print(lhs) ~ ", " ~ print(rhs) ~ ");\n";
    }

    void Xor3(BCValue _result, BCValue lhs, BCValue rhs)
    {
        sameLabel = false;
        result ~= "    Xor3(" ~ print(_result) ~ ", " ~ print(lhs) ~ ", " ~ print(rhs) ~ ");\n";
    }

    void Lsh3(BCValue _result, BCValue lhs, BCValue rhs)
    {
        sameLabel = false;
        result ~= "    Lsh3(" ~ print(_result) ~ ", " ~ print(lhs) ~ ", " ~ print(rhs) ~ ");\n";
    }

    void Rsh3(BCValue _result, BCValue lhs, BCValue rhs)
    {
        sameLabel = false;
        result ~= "    Rsh3(" ~ print(_result) ~ ", " ~ print(lhs) ~ ", " ~ print(rhs) ~ ");\n";
    }

    void Mod3(BCValue _result, BCValue lhs, BCValue rhs)
    {
        sameLabel = false;
        result ~= "    Mod3(" ~ print(_result) ~ ", " ~ print(lhs) ~ ", " ~ print(rhs) ~ ");\n";
    }

    void Byte3(BCValue _result, BCValue word, BCValue idx)
    {
        sameLabel = false;
        result ~= "    Byte3(" ~ print(_result) ~ ", " ~ print(word) ~ ", " ~ print(idx) ~ ");\n";
    }
    import ddmd.globals : Loc;
    void Call(BCValue _result, BCValue fn, BCValue[] args, Loc l = Loc.init)
    {
        import std.algorithm : map;
        import std.range : join;

        sameLabel = false;

        result ~= "    Call(" ~ print(_result) ~ ", " ~ print(fn) ~ ", [" ~ args.map!(
            a => print(a)).join(", ") ~ "]);\n";
    }

    void Load32(BCValue to, BCValue from)
    {
        sameLabel = false;
        result ~= "    Load32(" ~ print(to) ~ ", " ~ print(from) ~ ");\n";
    }

    void Store32(BCValue to, BCValue from)
    {
        sameLabel = false;
        result ~= "    Store32(" ~ print(to) ~ ", " ~ print(from) ~ ");\n";
    }

    void Alloc(BCValue heapPtr, BCValue size)
    {
        sameLabel = false;
        result ~= "    Alloc(" ~ print(heapPtr) ~ ", " ~ print(size) ~ ");\n";
    }

    void Not(BCValue _result, BCValue val)
    {
        sameLabel = false;
        result ~= "    Not(" ~ print(_result) ~ ", " ~ print(val) ~ ");\n";
    }

    void Ret(BCValue val)
    {
        sameLabel = false;
        result ~= "    Ret(" ~ print(val) ~ ");\n";
    }

    void Cat(BCValue _result, BCValue lhs, BCValue rhs, const uint elmSize)
    {
        sameLabel = false;
        result ~= "    Cat(" ~ print(_result) ~ ", " ~ print(lhs) ~ ", " ~ print(rhs) ~ ", " ~ to!string(
            elmSize) ~ ");\n";
    }

    void Assert(BCValue value, BCValue err)
    {
        sameLabel = false;
        result ~= "    Assert(" ~ print(value) ~ ", " ~ print(err) ~ ");\n";
    }
}

enum genString = q{
    auto tmp1 = genTemporary(BCType(BCTypeEnum.i32));//SP[4]
    Mul3(tmp1, BCValue(Imm32(2)), BCValue(Imm32(16)));
    Div3(tmp1, tmp1, BCValue(Imm32(4)));
    Sub3(tmp1, tmp1, BCValue(Imm32(1)));
    Ret(tmp1);
};

static assert(ensureIsBCGen!Print_BCGen);
