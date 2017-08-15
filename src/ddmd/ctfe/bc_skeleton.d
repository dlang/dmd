module ddmd.ctfe.bc_skeleton;
import ddmd.ctfe.bc_common;

struct BCFunction
{
    void* fd; // set to the function descriptor of the frontend

    // all the other state you need to represent a callable function
}

struct Skeleton_Gen
{
    void Initialize();
    void Finalize();
    void beginFunction(uint);
    BCFunction endFunction();
    BCValue genTemporary(BCType bct);
    BCValue genParameter(BCType bct);
    BCAddr beginJmp();
    void endJmp(BCAddr atIp, BCLabel target);
    void incSp();
    StackAddr currSp();
    BCLabel genLabel();
    CndJmpBegin beginCndJmp(BCValue cond = BCValue.init, bool ifTrue = false);
    void endCndJmp(CndJmpBegin jmp, BCLabel target);
    void genJump(BCLabel target);
    void emitFlg(BCValue lhs);
    void Alloc(BCValue heapPtr, BCValue size);
    void Assert(BCValue value, BCValue err);
    void Not(BCValue result, BCValue val);
    void Set(BCValue lhs, BCValue rhs);
    void Lt3(BCValue result, BCValue lhs, BCValue rhs);
    void Le3(BCValue result, BCValue lhs, BCValue rhs);
    void Gt3(BCValue result, BCValue lhs, BCValue rhs);
    void Eq3(BCValue result, BCValue lhs, BCValue rhs);
    void Neq3(BCValue result, BCValue lhs, BCValue rhs);
    void Add3(BCValue result, BCValue lhs, BCValue rhs);
    void Sub3(BCValue result, BCValue lhs, BCValue rhs);
    void Mul3(BCValue result, BCValue lhs, BCValue rhs);
    void Div3(BCValue result, BCValue lhs, BCValue rhs);
    void And3(BCValue result, BCValue lhs, BCValue rhs);
    void Or3(BCValue result, BCValue lhs, BCValue rhs);
    void Xor3(BCValue result, BCValue lhs, BCValue rhs);
    void Lsh3(BCValue result, BCValue lhs, BCValue rhs);
    void Rsh3(BCValue result, BCValue lhs, BCValue rhs);
    void Mod3(BCValue result, BCValue lhs, BCValue rhs);
    import ddmd.globals : Loc;

    void Call(BCValue result, BCValue fn, BCValue[] args, Loc l = Loc.init);
    void Load32(BCValue _to, BCValue from);
    void Store32(BCValue _to, BCValue value);
    void Ret(BCValue val);
}
