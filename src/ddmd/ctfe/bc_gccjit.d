module bc_gccjit;

static if (!is(typeof ({ import gccjit.c;  })))
{
    pragma(msg, "gccjit header not there ... not compiling bc_gccjit backend");
}
else
{
import gccjit.c;
import ddmd.ctfe.bc_common;
import std.stdio;
import std.conv;
import std.string;

alias jctx = gcc_jit_context*;
alias jfunc = gcc_jit_function*;
alias jtype = gcc_jit_type *;
alias jresult = gcc_jit_result*;
alias jparam = gcc_jit_param*;
alias jblock = gcc_jit_block*;
alias jlvalue = gcc_jit_lvalue*;
alias jrvalue = gcc_jit_rvalue*;

struct BCFunction
{
    jfunc func;
    alias func this;
    jparam[64] parameters;
    ubyte parameterCount;
    jblock[512] blocks;
    uint blockCount;
    jlvalue flag;
    jlvalue[1024] locals;
    uint cellCount;
}

void bc_jit_main()
{
    import std.stdio;
    GccJitGen gen;
    with (gen)
    {
        Initialize();
        gcc_jit_context_set_bool_option(ctx, GCC_JIT_BOOL_OPTION_DUMP_EVERYTHING, 0);
        scope (exit) Finalize();
        {
            auto p1 = genParameter(i32Type, "p1");
            auto p2 = genParameter(i32Type, "p2");
            beginFunction(0);

                Add3(p1, p1, imm32('a'));
                Sub3(p2, p2, p1);
                Ret(p1);
        
            endFunction();
        }
    }

}

struct GccJitGen
{
    jctx ctx;
    jresult result;

    BCFunction[265] functions;
    uint functionCount;

    BCFunction* currentFunc()
    {
        return &functions[functionCount];
    }

    alias currentFunc this;

    jtype i32type;
    jtype i64type;

    private jblock block()
    {
        return blocks[blockCount - 1];
    }

    private void newBlock()
    {
        blocks[blockCount++] = gcc_jit_function_new_block(func);
    }

    private jparam param(ubyte paramIndex)
    {
        return parameters[paramIndex];
        //return gcc_jit_function_get_param(func, paramIndex);
    }

    private jlvalue lvalue(BCValue val)
    {
        assert(val.vType != BCValueType.Immediate);
        if (val.vType == BCValueType.Parameter)
        {
            return gcc_jit_param_as_lvalue(param(val.paramIndex));
        }
        else
            assert(0, "vType: " ~ enumToString(val.vType) ~ " is current not supported");

    }

    private jrvalue rvalue(BCValue val)
    {
        //assert(val.isStackValueOrParameter);
        if (val.vType == BCValueType.Parameter)
        {
            return gcc_jit_param_as_rvalue(param(val.paramIndex));
        }
        else if (val.vType == BCValueType.Immediate)
        {
            assert(val.type == i32Type);
            return gcc_jit_context_new_rvalue_from_int(ctx, i64type, val.imm32.imm32);
        }
        else
            assert(0, "vType: " ~ enumToString(val.vType) ~ " is current not supported");
    }

    void Initialize()
    {
        ctx = gcc_jit_context_acquire();

        i32type = ctx.gcc_jit_context_get_type(GCC_JIT_TYPE_INT);
        i64type = ctx.gcc_jit_context_get_type(GCC_JIT_TYPE_LONG_LONG);

        // debug stuff
        ctx.gcc_jit_context_set_bool_option(
            GCC_JIT_BOOL_OPTION_DUMP_INITIAL_GIMPLE,
           0);
          
    }

    void Finalize()
    {
        gcc_jit_context_dump_to_file(ctx, "ctx.c", 0);
        result = ctx.gcc_jit_context_compile();
    }

    void beginFunction(uint fnId, string name = null)
    {
        writeln("parameterCount: ", parameterCount);
        writeln ("functionIndex: ", (&functions[0])  - currentFunc);
        func = gcc_jit_context_new_function(ctx,
            null, GCC_JIT_FUNCTION_EXPORTED, i64type, 
            name ? name.toStringz : ("f" ~ to!string(fnId)).toStringz ,
            parameterCount, &parameters[0], 0);
        blocks[blockCount++] = gcc_jit_function_new_block(func, null);
    }

    BCFunction endFunction()
    {
        import core.stdc.stdio;
        auto fobj = gcc_jit_function_as_object(func);

        printf ("function: %s\n", gcc_jit_object_get_debug_string (fobj));
        return functions[functionCount++];
    }
    BCValue genTemporary(BCType bct);

    BCValue genLocal(BCType bct, string name)
    {
        return BCValue.init;
    }

    BCValue genParameter(BCType bct, string name)
    {
        import std.string;
        if (bct != i32Type)
            assert(0, "can currently only create params of i32Type");
         parameters[parameterCount] = gcc_jit_context_new_param(ctx, null, i64type, name.toStringz);
        auto r = BCValue(BCParameter(parameterCount++, bct, StackAddr(0)));
        writeln("pCount: ",  parameterCount);
        writeln("funcIdx: ", (&functions[0])  - currentFunc);
        return r;

    }
    BCAddr beginJmp();
    void endJmp(BCAddr atIp, BCLabel target);
    void incSp();
    StackAddr currSp();
    BCLabel genLabel()
    {
        newBlock();
        return BCLabel(BCAddr(blockCount-1));
    }
    CndJmpBegin beginCndJmp(BCValue cond = BCValue.init, bool ifTrue = false)
    {
        auto cjb = CndJmpBegin(block, cond, ifTrue);
        newBlock();
        return cjb;
    }
    void endCndJmp(CndJmpBegin jmp, BCLabel target)
    {
        newBlock();
        auto targetBlock = blocks[target.addr.addr];

        jblock true_block;
        jblock false_block;

        if (jmp.ifTrue)
        {
            true_block = targetBlock;
            false_block = block;
        }
        else
        {
            true_block = block;
            false_block = targetBlock;
        }

        gcc_jit_block_end_with_conditional(blocks[jmp.at.addr], null,
            rvalue(jmp.cond), true_block, false_block); 
    }

    void genJump(BCLabel target);
    void emitFlg(BCValue lhs)
    {
        gcc_jit_block_add_assignment(blocks, null, lvalue(lhs), flag);
    }
    void Alloc(BCValue heapPtr, BCValue size);
    void Assert(BCValue value, BCValue err);

    void Not(BCValue result, BCValue val)
    {
        gcc_jit_block_add_assignment(blocks, null, lvalue(result), 
            gcc_jit_context_new_unary_op(ctx, null, GCC_JIT_UNARY_OP_LOGICAL_NEGATE, i64type, rvalue(val))
        );
    }

    void Set(BCValue lhs, BCValue rhs)
    {
        gcc_jit_block_add_assignment(blocks, null, lvalue(lhs), rvalue(rhs));
    }

    void Lt3(BCValue result, BCValue lhs, BCValue rhs)
    {
        auto _result = result ? lvalue(result) : flag;
        gcc_jit_block_add_assignment(block, null, _result,
            gcc_jit_context_new_comparison(ctx, null, GCC_JIT_COMPARISON_LT, rvalue(lhs), rvalue(rhs))
        );
    }

    void Le3(BCValue result, BCValue lhs, BCValue rhs)
    {
        auto _result = result ? lvalue(result) : flag;
        gcc_jit_block_add_assignment(block, null, _result,
            gcc_jit_context_new_comparison(ctx, null, GCC_JIT_COMPARISON_LE, rvalue(lhs), rvalue(rhs))
        );
    }

    void Gt3(BCValue result, BCValue lhs, BCValue rhs)
    {
        auto _result = result ? lvalue(result) : flag;
        gcc_jit_block_add_assignment(block, null, _result,
            gcc_jit_context_new_comparison(ctx, null, GCC_JIT_COMPARISON_GT, rvalue(lhs), rvalue(rhs))
        );
    }

    void Ge3(BCValue result, BCValue lhs, BCValue rhs)
    {
        auto _result = result ? lvalue(result) : flag;
        gcc_jit_block_add_assignment(block, null, _result,
            gcc_jit_context_new_comparison(ctx, null, GCC_JIT_COMPARISON_GE, rvalue(lhs), rvalue(rhs))
        );
    }

    void Eq3(BCValue result, BCValue lhs, BCValue rhs)
    {
        auto _result = result ? lvalue(result) : flag;
        gcc_jit_block_add_assignment(block, null, _result,
            gcc_jit_context_new_comparison(ctx, null, GCC_JIT_COMPARISON_EQ, rvalue(lhs), rvalue(rhs))
        );
    }

    void Neq3(BCValue result, BCValue lhs, BCValue rhs)
    {
        auto _result = result ? lvalue(result) : flag;
        gcc_jit_block_add_assignment(block, null, _result,
            gcc_jit_context_new_comparison(ctx, null, GCC_JIT_COMPARISON_NE, rvalue(lhs), rvalue(rhs))
        );
    }

    void Add3(BCValue result, BCValue lhs, BCValue rhs)
    {
        assert(lhs.type == i32Type && rhs.type == i32Type);
        assert(lhs.isStackValueOrParameter);
        assert(rhs.isStackValueOrParameter || rhs.vType == BCValueType.Immediate);


        auto _result = gcc_jit_context_new_binary_op (
            ctx, null,
            GCC_JIT_BINARY_OP_PLUS, i64type,
            rvalue(lhs),
            rvalue(rhs)
        );
        gcc_jit_block_add_assignment(block, null,
            lvalue(result), _result);
    }

    void Sub3(BCValue result, BCValue lhs, BCValue rhs)
    {
        assert(lhs.type == i32Type && rhs.type == i32Type);
        assert(lhs.isStackValueOrParameter);
        assert(rhs.isStackValueOrParameter || rhs.vType == BCValueType.Immediate);


        auto _result = gcc_jit_context_new_binary_op (
            ctx, null,
            GCC_JIT_BINARY_OP_MINUS, i64type,
            rvalue(lhs),
            rvalue(rhs)
        );
        gcc_jit_block_add_assignment(block, null,
            lvalue(result), _result);
    }

    void Mul3(BCValue result, BCValue lhs, BCValue rhs);
    void Div3(BCValue result, BCValue lhs, BCValue rhs);
    void And3(BCValue result, BCValue lhs, BCValue rhs);
    void Or3(BCValue result, BCValue lhs, BCValue rhs);
    void Xor3(BCValue result, BCValue lhs, BCValue rhs);
    void Lsh3(BCValue result, BCValue lhs, BCValue rhs);
    void Rsh3(BCValue result, BCValue lhs, BCValue rhs);
    void Mod3(BCValue result, BCValue lhs, BCValue rhs);
//    import ddmd.globals : Loc;

    void Call(BCValue result, BCValue fn, BCValue[] args);
    void Load32(BCValue _to, BCValue from);
    void Store32(BCValue _to, BCValue value);
    void Load64(BCValue _to, BCValue from);
    void Store64(BCValue _to, BCValue value);

    void Ret(BCValue val)
    {
        gcc_jit_block_end_with_return(block, null, rvalue(val));
    }
}
}
