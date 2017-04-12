/+
module ddmd.ctfe.bc_recorder;

import ddmd.ctfe.bc_common;

enum BCInst
{
    beginFunction,
    endFunction,
    Initialize,
    Finalize,

    genTemporary,
    genParameter,

    beginJmp,
    endJmp,

    incSp,
    currSp,

    genLabel,

    beginCndJmp,
    endCndJmp,

    genJump,
    emitFlg,

    Assert,
    Alloc,
    Load32,
    Store32,
    Set,
    Not,

    Lt3,
    Gt3,
    Le3,
    Ge3,
    Eq3,
    Neq3,
    Add3,
    Sub3,
    Mul3,
    Div3,
    And3,
    Or3,
    Xor3,
    Lsh3,
    Rsh3,
    Mod3,

    Cat,
    
    Call,
}

struct BCRecord
{
  BCInst inst;
  unoion
  {
    uint fnNr;
    struct {
      BCValue value;
      bool ifTrue;
    }

    struct {
      union {
        BCAddr addr;
        CndJmpBegin cndJmpBegin;
      }
      BCLabel label;
    }
    BCValue[2] val2;
    BCValue[3] val3;
    BCType type;
    struct {
      BCValue retval;
      BCValue fn;
      BCValue[] args;
    }
  }
}

struct BCRecorderGen
{
    import std.conv;

    BCRecord[255] records;
    uint recordCount;

    uint labelCount;
    uint paramemterCount;
    uint temporaryCount;
    uint jmpCount;
    uint ip;
    uint sp;

    BCRecord* addRecord(BCInst inst)
    {
      records[recordCount].inst = inst;
      return &records[recordCount++];
    }

    playBack(Gen)(ref Gen gen)
    {
        foreach(r;records[0 .. recordCount])
        {
            with (BCInst) final switch(r)
            {
              case beginFunction :
              {
                  gen.beginFunction(r.fnNr);
              }
              break;
              case endFunction :
              {
                  gen.endFunction();
              }
              break;
              case Initialize :
              {
                  gen.Initialze();
              }
              break;
              case Finalzize :
              {
                  gen.Finalize();
              }
              break;
              case genTemporary :
              {
                   gen.genTemporary(r.type)
              }
              break;
              case genParameter :
              {
                   gen.genParameter(r.type);
              }
              break;
            }
        }
    }

    BCLabel genLabel()
    {
        if (!sameLabel)
        {
            ++labelCount;
            sameLabel = true;
            addRecord(BCInst.genLabel);
        }
        return BCLabel(BCAddr(labelCount));
    }

    void incSp()
    {
        sameLabel = false;
        sp += 4;
        addRecord(BCInst.incSp);
    }

    StackAddr currSp()
    {
        addRecord(BCInst.currSp);
        return sp;
    }

    void Initialize()
    {
        addRecord(BCInst.Initialize);
    }

    void Finalize()
    {
        addRecord(BCInst.Finalaize);
    }

    void beginFunction(uint f = 0)
    {
        sameLabel = false;
        addRecord(BCInst.beginFunction).fnNr = f;
    }

    void endFunction()
    {
        addRecord(BCInst.endFunction);
    }

    BCValue genParameter(BCType bct)
    {
        sameLabel = false;
        addRecord(BCInst.genParameter).type = bct;
        sp += 4;
        return BCValue(BCParameter(++parameterCount, bct));
    }


    BCValue genTemporary(BCType bct)
    {
        sameLabel = false;
        addRecord(BCInst.genTemporary).type = bct;        
        auto tmpAddr = sp.addr;
        sp += align4(basicTypeSize(bct));
        return BCValue(StackAddr(tmpAddr), bct, ++temporaryCount);
    }

    BCAddr beginJmp()
    {
        sameLabel = false;
        addRecord(BCInst.beginJmp);
        return BCAddr(++jmpCount);
    }

    void endJmp(BCAddr atIp, BCLabel target)
    {
        sameLabel = false;
        auto rec = addRecord(BCInst.endJmp);
        rec.addr = atIp;
        rec.label = target;
    }

    void genJump(BCLabel target)
    {
        addRecord(BCInst.genJmp).label = target;
    }

    CndJmpBegin beginCndJmp(BCValue cond = BCValue.init, bool ifTrue = false)
    {
        sameLabel = false;
        auto rec = addRecord(BCInst.beginCndJmp);
        rec.value = cond;
        rec.ifTrue = ifTrue;
        return CndJmpBegin(BCAddr(++cndJumpCount), cond, ifTrue);
    }

    void endCndJmp(CndJmpBegin jmp, BCLabel target)
    {
        sameLabel = false;
        auto rec = addRecord(BCInst.endCndJmp);
        rec.cndJmpBegin = jmp;
        rec.label = target;
    }

    void emitFlg(BCValue lhs)
    {
        sameLabel = false;
        addRecord(BCInst.emitFlg).value = lhs;
    }

    void Set(BCValue lhs, BCValue rhs)
    {
        if (lhs == rhs)
            return;
        sameLabel = false;
        addRecord(BCInst.Set).val2 = [lhs, rhs];
    }

    void Lt3(BCValue _result, BCValue lhs, BCValue rhs)
    {
        sameLabel = false;
        addRecord(BCInst.Lt3).val3 = [_result, lhs, rhs];
    }

    void Gt3(BCValue _result, BCValue lhs, BCValue rhs)
    {
        sameLabel = false;
        addRecord(BCInst.Gt3).val3 = [_result, lhs, rhs];
    }

    void Le3(BCValue _result, BCValue lhs, BCValue rhs)
    {
        sameLabel = false;
        addRecord(BCInst.Le3).val3 = [_result, lhs, rhs];
    }

    void Ge3(BCValue _result, BCValue lhs, BCValue rhs)
    {
        sameLabel = false;
        addRecord(BCInst.Ge3).val3 = [_result, lhs, rhs];
    }

    void Eq3(BCValue _result, BCValue lhs, BCValue rhs)
    {
        sameLabel = false;
        addRecord(BCInst.Eq3).val3 = [_result, lhs, rhs];
    }

    void Neq3(BCValue _result, BCValue lhs, BCValue rhs)
    {
        sameLabel = false;
        addRecord(BCInst.Neq3).val3 = [_result, lhs, rhs];
    }

    void Add3(BCValue _result, BCValue lhs, BCValue rhs)
    {
        sameLabel = false;
        addRecord(BCInst.Add3).val3 = [_result, lhs, rhs];
    }

    void Sub3(BCValue _result, BCValue lhs, BCValue rhs)
    {
        sameLabel = false;
        addRecord(BCInst.Sub3).val3 = [_result, lhs, rhs];
    }

    void Mul3(BCValue _result, BCValue lhs, BCValue rhs)
    {
        sameLabel = false;
        addRecord(BCInst.Mul3).val3 = [_result, lhs, rhs];
    }

    void Div3(BCValue _result, BCValue lhs, BCValue rhs)
    {
        sameLabel = false;
        addRecord(BCInst.Div3).val3 = [_result, lhs, rhs];
    }

    void And3(BCValue _result, BCValue lhs, BCValue rhs)
    {
        sameLabel = false;
        addRecord(BCInst.And3).val3 = [_result, lhs, rhs];
    }

    void Or3(BCValue _result, BCValue lhs, BCValue rhs)
    {
        sameLabel = false;
        addRecord(BCInst.Or3).val3 = [_result, lhs, rhs];
    }

    void Xor3(BCValue _result, BCValue lhs, BCValue rhs)
    {
        sameLabel = false;
        addRecord(BCInst.Xor3).val3 = [_result, lhs, rhs];
    }

    void Lsh3(BCValue _result, BCValue lhs, BCValue rhs)
    {
        sameLabel = false;
        addRecord(BCInst.Lsh3).val3 = [_result, lhs, rhs];
    }

    void Rsh3(BCValue _result, BCValue lhs, BCValue rhs)
    {
        sameLabel = false;
        addRecord(BCInst.Rsh3).val3 = [_result, lhs, rhs];

    }

    void Mod3(BCValue _result, BCValue lhs, BCValue rhs)
    {
        sameLabel = false;
        addRecord(BCInst.Mod3).val3 = [_result, lhs, rhs];
    }

    void Byte3(BCValue _result, BCValue word, BCValue idx)
    {
        sameLabel = false;
        addRecord(BCInst.Byte3).val3 = [_result, word, idx];
    }

    import ddmd.globals : Loc;
    void Call(BCValue _result, BCValue fn, BCValue[] args, Loc l = Loc.init)
    {
        sameLabel = false;
        auto r = addRecord(BCInst.Call);
        r.retval = _result;
        r.fn = fn;
        r.args = args;
    }

    void Load32(BCValue to, BCValue from)
    {
        sameLabel = false;
        addRecord(BCInst.Load32).val2 = [to, from];
    }

    void Store32(BCValue to, BCValue from)
    {
        sameLabel = false;
        addRecord(BCInst.Store32).val2 = [to, from];
    }

    void Alloc(BCValue heapPtr, BCValue size)
    {
        sameLabel = false;
        addRecord(BCInst.Alloc).val2 = [heapPtr, size];
    }

    void Not(BCValue _result, BCValue val)
    {
        sameLabel = false;
        addRecord(BCInst.Not).val2 = [_result, val];
    }

    void Ret(BCValue val)
    {
        sameLabel = false;
        addRecord(BCInst.Ret).value = val;
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
        addRecord(BCInst.Assert).val2 = [val, err];
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
+/
