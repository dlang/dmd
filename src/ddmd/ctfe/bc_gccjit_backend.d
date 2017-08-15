module bc_gccjit_backend;

static if (!is(typeof ({ import gccjit.c;  })))
{
    pragma(msg, "gccjit header not there ... not compiling bc_gccjit backend");
}
else
    struct GCCJIT_Gen
{
    import gccjit.c;
    import ddmd.ctfe.bc_common;
    import std.stdio;
    import std.conv;
    import std.string;

    alias jctx = gcc_jit_context*;
    alias jfunc = gcc_jit_function*;
    alias jtype = gcc_jit_type*;
    alias jresult = gcc_jit_result*;
    alias jparam = gcc_jit_param*;
    alias jblock = gcc_jit_block*;
    alias jlvalue = gcc_jit_lvalue*;
    alias jrvalue = gcc_jit_rvalue*;

    static void bc_jit_main()
    {
        GCCJIT_Gen gen;
        with (gen)
        {
            Initialize();
            gcc_jit_context_set_bool_option(ctx, GCC_JIT_BOOL_OPTION_DUMP_EVERYTHING, 0);
            scope (exit) Finalize();
            {
                auto p1 = genParameter(i32Type, "p1");
                auto p2 = genParameter(i32Type, "p2");
                auto p3 = genParameter(i32Type, "p3");

                beginFunction(0);

                Add3(p1, p1, imm32('a'));
                auto j = beginCndJmp(p3.i32, true);
                Sub3(p2, p2, p1);
                endCndJmp(j, genLabel());
                Not(p1, p1);
                Ret(p1);

                endFunction();
            }
        }
    }


    struct BCFunction
    {
        void* fd;

        jfunc func;
        alias func this;
        jparam[64] parameters;
        ubyte parameterCount;
        jblock[512] blocks;
        uint blockCount;
        jlvalue flag;
        jlvalue[1024] locals;
        uint localCount;
        jlvalue[4096] temporaries;
        uint temporaryCount;
        jlvalue[temporaries.length + locals.length] stackValues;

        uint cellCount;
    }

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

    private void newBlock(const char* name = null)
    {
        blocks[blockCount++] = gcc_jit_function_new_block(func, name);
    }

    private jparam param(ubyte paramIndex)
    {
        return parameters[paramIndex];
        //return gcc_jit_function_get_param(func, paramIndex);
    }

    private jrvalue zero(jtype type = null)
    {
        type = type ? type : i64type;
        return gcc_jit_context_zero(ctx, type);
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

    private jrvalue rvalue(jlvalue val)
    {
            return gcc_jit_lvalue_as_rvalue(val);
    }


    void Initialize()
    {
        ctx = gcc_jit_context_acquire();

        i32type = ctx.gcc_jit_context_get_type(GCC_JIT_TYPE_INT);
        i64type = ctx.gcc_jit_context_get_type(GCC_JIT_TYPE_LONG_LONG);

        // debug stuff
        ctx.gcc_jit_context_set_bool_option(
            GCC_JIT_BOOL_OPTION_DUMP_INITIAL_GIMPLE, 1
         );

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
        newBlock("functionBegin");
    }

    BCFunction endFunction()
    {
        return functions[functionCount++];
    }

    BCValue genTemporary(BCType bct)
    {
        //TODO replace i64Type maybe depding on bct
        auto type = i64type;
        temporaries[temporaryCount++] = gcc_jit_function_new_local(func, null, type, &name[0]);
        auto addr = addStackValue(locals[temporaryCount - 1]);


    }

    BCValue genLocal(BCType bct, string name)
    {
        assert(name, "locals have to have a name");
        //TODO replace i64Type maybe depding on bct
        auto type = i64type;
        locals[localCount++] = gcc_jit_function_new_local(func, null, type, &name[0]);
        auto addr = addStackValue(locals[localCount -1 ]);
        return BCLocal(localCount, bct, addr, name);
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

    BCAddr beginJmp()
    {
        newBlock("beginJmp");
        return BCAddr(blockCount - 2);
    }

    void endJmp(BCAddr atIp, BCLabel target)
    {
        gcc_jit_block_end_with_jump(blocks[atIp], null, blocks[target.addr]);
    }

    BCLabel genLabel()
    {
        newBlock("genLabel");
        gcc_jit_block_end_with_jump(blocks[blockCount - 2], null, block);
        return BCLabel(BCAddr(blockCount-1));
    }

    CndJmpBegin beginCndJmp(BCValue cond = BCValue.init, bool ifTrue = false)
    {
        newBlock("CndJmp_fallthrough");
        auto cjb = CndJmpBegin(BCAddr(blockCount-2), cond, ifTrue);

        return cjb;
    }
    void endCndJmp(CndJmpBegin jmp, BCLabel target)
    {
        //newBlock("endCndJmp");
        auto targetBlock = blocks[target.addr.addr];
        auto falltroughBlock = blocks[jmp.at.addr + 1];

        jblock true_block;
        jblock false_block;

        if (jmp.ifTrue)
        {
            true_block = targetBlock;
            false_block = falltroughBlock;
        }
        else
        {
            true_block = falltroughBlock;
            false_block = targetBlock;
        }

        auto cond = gcc_jit_context_new_comparison(ctx, null,
            GCC_JIT_COMPARISON_NE, rvalue(jmp.cond), zero
        );

        gcc_jit_block_end_with_conditional(blocks[jmp.at.addr], null,
            cond, true_block, false_block);
    }

    void genJump(BCLabel target)
    {
        gcc_jit_block_end_with_jump(block, null, blocks[target.addr.addr]);
        newBlock();
    }

    void emitFlg(BCValue lhs)
    {
        gcc_jit_block_add_assignment(block, null, lvalue(lhs), rvalue(flag));
    }

    void Alloc(BCValue heapPtr, BCValue size);
    void Assert(BCValue value, BCValue err);

    void Not(BCValue result, BCValue val)
    {
        gcc_jit_block_add_assignment(block, null, lvalue(result),
            gcc_jit_context_new_unary_op(ctx, null, GCC_JIT_UNARY_OP_LOGICAL_NEGATE, i64type, rvalue(val))
        );
    }

    void Set(BCValue lhs, BCValue rhs)
    {
        gcc_jit_block_add_assignment(block, null, lvalue(lhs), rvalue(rhs));
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
            lvalue(result), _result
        );
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
            lvalue(result), _result
        );
    }

    void Mul3(BCValue result, BCValue lhs, BCValue rhs)
    {
        assert(lhs.type == i32Type && rhs.type == i32Type);
        assert(lhs.isStackValueOrParameter);
        assert(rhs.isStackValueOrParameter || rhs.vType == BCValueType.Immediate);


        auto _result = gcc_jit_context_new_binary_op (
            ctx, null,
            GCC_JIT_BINARY_OP_MULT, i64type,
            rvalue(lhs),
            rvalue(rhs)
        );
        gcc_jit_block_add_assignment(block, null,
            lvalue(result), _result
        );
    }

    void Div3(BCValue result, BCValue lhs, BCValue rhs)
    {
        assert(lhs.type == i32Type && rhs.type == i32Type);
        assert(lhs.isStackValueOrParameter);
        assert(rhs.isStackValueOrParameter || rhs.vType == BCValueType.Immediate);


        auto _result = gcc_jit_context_new_binary_op (
            ctx, null,
            GCC_JIT_BINARY_OP_DIVIDE, i64type,
            rvalue(lhs),
            rvalue(rhs)
        );
        gcc_jit_block_add_assignment(block, null,
            lvalue(result), _result
        );

    }

    void And3(BCValue result, BCValue lhs, BCValue rhs)
    {
        assert(lhs.type == i32Type && rhs.type == i32Type);
        assert(lhs.isStackValueOrParameter);
        assert(rhs.isStackValueOrParameter || rhs.vType == BCValueType.Immediate);


        auto _result = gcc_jit_context_new_binary_op (
            ctx, null,
            GCC_JIT_BINARY_OP_BITWISE_AND, i64type,
            rvalue(lhs),
            rvalue(rhs)
        );

        gcc_jit_block_add_assignment(block, null,
            lvalue(result), _result
        );

    }

    void Or3(BCValue result, BCValue lhs, BCValue rhs)
    {
        assert(lhs.type == i32Type && rhs.type == i32Type);
        assert(lhs.isStackValueOrParameter);
        assert(rhs.isStackValueOrParameter || rhs.vType == BCValueType.Immediate);


        auto _result = gcc_jit_context_new_binary_op (
            ctx, null,
            GCC_JIT_BINARY_OP_BITWISE_OR, i64type,
            rvalue(lhs),
            rvalue(rhs)
        );

        gcc_jit_block_add_assignment(block, null,
            lvalue(result), _result
        );

    }

    void Xor3(BCValue result, BCValue lhs, BCValue rhs)
    {
        assert(lhs.type == i32Type && rhs.type == i32Type);
        assert(lhs.isStackValueOrParameter);
        assert(rhs.isStackValueOrParameter || rhs.vType == BCValueType.Immediate);


        auto _result = gcc_jit_context_new_binary_op (
            ctx, null,
            GCC_JIT_BINARY_OP_BITWISE_XOR, i64type,
            rvalue(lhs),
            rvalue(rhs)
        );

        gcc_jit_block_add_assignment(block, null,
            lvalue(result), _result
        );

    }

    void Lsh3(BCValue result, BCValue lhs, BCValue rhs)
    {
        assert(lhs.type == i32Type && rhs.type == i32Type);
        assert(lhs.isStackValueOrParameter);
        assert(rhs.isStackValueOrParameter || rhs.vType == BCValueType.Immediate);


        auto _result = gcc_jit_context_new_binary_op (
            ctx, null,
            GCC_JIT_BINARY_OP_LSHIFT, i64type,
            rvalue(lhs),
            rvalue(rhs)
        );

        gcc_jit_block_add_assignment(block, null,
            lvalue(result), _result
        );

    }
    void Rsh3(BCValue result, BCValue lhs, BCValue rhs)
    {
        assert(lhs.type == i32Type && rhs.type == i32Type);
        assert(lhs.isStackValueOrParameter);
        assert(rhs.isStackValueOrParameter || rhs.vType == BCValueType.Immediate);


        auto _result = gcc_jit_context_new_binary_op (
            ctx, null,
            GCC_JIT_BINARY_OP_LSHIFT, i64type,
            rvalue(lhs),
            rvalue(rhs)
        );

        gcc_jit_block_add_assignment(block, null,
            lvalue(result), _result
        );

    }
    void Mod3(BCValue result, BCValue lhs, BCValue rhs)
    {
        assert(lhs.type == i32Type && rhs.type == i32Type);
        assert(lhs.isStackValueOrParameter);
        assert(rhs.isStackValueOrParameter || rhs.vType == BCValueType.Immediate);


        auto _result = gcc_jit_context_new_binary_op (
            ctx, null,
            GCC_JIT_BINARY_OP_MODULO, i64type,
            rvalue(lhs),
            rvalue(rhs)
        );

        gcc_jit_block_add_assignment(block, null,
            lvalue(result), _result
        );
    }

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

