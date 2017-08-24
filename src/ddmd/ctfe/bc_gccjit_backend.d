module ddmd.ctfe.bc_gccjit_backend;
static if (!is(typeof ({ import gccjit.c;  })))
{
    pragma(msg, "gccjit header not there ... not compiling bc_gccjit backend");
}
else
{
    import gccjit.c;

    alias jctx = gcc_jit_context*;
    alias jfunc = gcc_jit_function*;
    alias jtype = gcc_jit_type*;
    alias jresult = gcc_jit_result*;
    alias jparam = gcc_jit_param*;
    alias jblock = gcc_jit_block*;
    alias jlvalue = gcc_jit_lvalue*;
    alias jrvalue = gcc_jit_rvalue*;

    struct BCFunction
    {
        void* fd;

        jfunc func;
        char* fname;
        alias func this;
        jlvalue[64] parameters;
        ubyte parameterCount;
        jblock[512] blocks;
        uint blockCount;
        jlvalue[1024] locals;
        ushort localCount;
        jlvalue[2096] temporaries;
        ushort temporaryCount;
        jlvalue[temporaries.length + locals.length] stackValues;
        ushort stackValueCount;
    }
}

version (Have_libgccjit)
    struct GCCJIT_BCGen
{
    enum max_params = 64;
    import gccjit.c;
    import ddmd.ctfe.bc_common;
    import std.stdio;
    import std.conv;
    import std.string;

/*
    static void bc_jit_main()
    {

        BCHeap heap;
        heap.heapSize = 100;
        writeln(heap.heapSize);

        auto hello_world = heap.pushString("Hello World.\nI've been missing you.");

        GCCJIT_Gen *gen = new GCCJIT_Gen();
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
                auto tmp1 = genTemporary(i32Type);
                Set(tmp1, imm32(3));
                Add3(tmp1, tmp1, imm32('a'));

                auto j = beginCndJmp(imm32(3), true);
                Not(tmp1, tmp1);
                endCndJmp(j, genLabel());
                auto arrayPtr = genTemporary(i32Type);
                Alloc(arrayPtr, imm32(67));
                Sub3(genTemporary(i32Type), imm32(32), imm32(64));
                printHeapString(hello_world.imm32);
                Sub3(genTemporary(i32Type), imm32(32), imm32(64));
                Ret(arrayPtr);

                endFunction();
            }
        }

        auto rv = gen.run(0, [imm32(64),imm32(32),imm32(32)], &heap);

        writeln(heap.heapSize, " rv: ", rv);
    }
*/
    BCValue run(uint fnId, BCValue[] args, BCHeap *heapPtr)
    {
        extern (C) struct ReturnType
        {
            ulong imm64;
            uint flags;
        }

        assert(result, "No result did you try to run before calling Finalize");

        alias fType = extern (C) ReturnType function(long[max_params] args, uint* heapSize, uint* heap);

        auto func = cast(fType)
            gcc_jit_result_get_code(result, functions[fnId].fname);

        long[max_params] fnArgs;
        foreach(i, arg;args)
        {
            fnArgs[i] = arg.imm64.imm64;
        }

        auto ret = func(fnArgs, &heapPtr.heapSize, &heapPtr._heap[0]);

        return BCValue(Imm64(ret.imm64));


    }


    jctx ctx;
    jresult result;
    jlvalue flag;
    jlvalue heapSize;
    jlvalue _heap;

    void* heapSizePtrPtr;
    void* heapArrayPtrPtr;

    BCFunction[128] functions;
    gcc_jit_location* currentLoc;

    uint functionCount;

    bool insideFunction = false;

    BCFunction* currentFunc()
    {
        return &functions[functionCount];
    }

    alias currentFunc this;

    jtype i32type;
    jtype i64type;
    jtype u32type;
    jtype u64type;

    private void print_int(BCValue v)
    {
        print_int(rvalue(v));
    }

    private void print_int(jrvalue val)
    {
        jrvalue[2] args;
        args[0] = gcc_jit_context_new_rvalue_from_ptr(ctx, gcc_jit_context_get_type(ctx, GCC_JIT_TYPE_CONST_CHAR_PTR),  cast(void*)"%d\n".ptr);
        args[1] = val;
        auto printf = gcc_jit_context_get_builtin_function(ctx, "printf");
        auto call = gcc_jit_context_new_call(ctx, currentLoc, printf, 2, &args[0]);
        gcc_jit_block_add_eval(block, currentLoc, call);
    }

    private void print_ptr(jrvalue val)
    {
        jrvalue[2] args;
        args[0] = gcc_jit_context_new_rvalue_from_ptr(ctx, gcc_jit_context_get_type(ctx, GCC_JIT_TYPE_CONST_CHAR_PTR),  cast(void*)"%p\n".ptr);
        args[1] = val;
        auto printf = gcc_jit_context_get_builtin_function(ctx, "printf");
        auto call = gcc_jit_context_new_call(ctx, currentLoc, printf, 2, &args[0]);
        gcc_jit_block_add_eval(block, currentLoc, call);
    }

    private void print_string(jrvalue base, jrvalue length)
    {
        jrvalue[3] args;
        auto c_char_p = gcc_jit_context_get_type(ctx, GCC_JIT_TYPE_CONST_CHAR_PTR);
        auto void_p = gcc_jit_context_get_type(ctx, GCC_JIT_TYPE_VOID_PTR);
        args[0] = gcc_jit_context_new_rvalue_from_ptr(ctx, c_char_p,  cast(void*)"\"%.*s\"\n".ptr);

        jrvalue length_times_four = gcc_jit_context_new_binary_op (
            ctx, null,
            GCC_JIT_BINARY_OP_MULT, i32type,
            length,
            rvalue_int(4)
        );

        args[1] = length_times_four;

        jlvalue ptr = gcc_jit_function_new_local(func, currentLoc, void_p, "ptr");
        gcc_jit_block_add_assignment(block, currentLoc, ptr, gcc_jit_context_null(ctx, void_p));
        print_ptr(rvalue(_heap));

        auto addr = gcc_jit_lvalue_get_address(gcc_jit_context_new_array_access(ctx, currentLoc, rvalue(_heap), base), null);
        gcc_jit_block_add_assignment(block, null,
            ptr, addr);


        args[2] = rvalue(ptr);
        print_ptr(rvalue(ptr));
        auto printf = gcc_jit_context_get_builtin_function(ctx, "printf");
        auto call = gcc_jit_context_new_call(ctx, currentLoc, printf, 3, &args[0]);
        gcc_jit_block_add_eval(block, currentLoc, call);
    }


    private void call_puts(jrvalue arg)
    {
        auto puts = gcc_jit_context_get_builtin_function(ctx, "puts");
        auto call = gcc_jit_context_new_call(ctx, currentLoc, puts, 1, &arg);
        gcc_jit_block_add_eval(block, currentLoc, call);
    }

    private void printHeapString(uint addr)
    {
        jlvalue base = gcc_jit_context_new_array_access(ctx, null,
            rvalue(_heap), rvalue(addr)
        );

        jlvalue length = gcc_jit_context_new_array_access(ctx, null,
            rvalue(_heap), rvalue(addr + 4)
        );

        auto heapBase = gcc_jit_lvalue_get_address(_heap, null);



        print_int(rvalue(base));

        print_string(rvalue(base), rvalue(length));
    }

    private jblock block()
    {
        return blocks[blockCount - 1];
    }

    private void newBlock(const char* name = null)
    {
        blocks[blockCount++] = gcc_jit_function_new_block(func, name);
    }

    private jlvalue param(ubyte paramIndex)
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
            return param(val.paramIndex);
        }
        else if (val.vType == BCValueType.StackValue)
        {
            return stackValues[val.stackAddr];
        }
        else
            assert(0, "vType: " ~ enumToString(val.vType) ~ " is current not supported");

    }

    private jrvalue rvalue(BCValue val)
    {
        //assert(val.isStackValueOrParameter);
        if (val.vType == BCValueType.Parameter)
        {
            return rvalue(param(val.paramIndex));
        }
        else if (val.vType == BCValueType.Immediate)
        {
            assert(val.type == i32Type);
            return gcc_jit_context_new_rvalue_from_int(ctx, i64type, val.imm32.imm32);
        }
        else if (val.vType == BCValueType.StackValue)
        {
            return rvalue(stackValues[val.stackAddr]);
        }
        else
            assert(0, "vType: " ~ enumToString(val.vType) ~ " is current not supported");
    }

    private jrvalue rvalue(jlvalue val)
    {
            return gcc_jit_lvalue_as_rvalue(val);
    }

    private jrvalue rvalue(jrvalue val)
    {
            return val;
    }


    private jrvalue rvalue(long v)
    {
        return gcc_jit_context_new_rvalue_from_long(ctx, i64type, v);
    }

    private jrvalue rvalue_int(int v)
    {
        return gcc_jit_context_new_rvalue_from_int(ctx, i32type, v);
    }

    private StackAddr addStackValue(jlvalue val)
    {
        stackValues[stackValueCount] = val;
        return StackAddr(stackValueCount++);
    }

    jtype heapType;
    jfunc memcpy;

    void Initialize()
    {
        ctx = gcc_jit_context_acquire();
      //  u32type = gcc_jit_context_get_int_type(ctx, 32, 0);
      //  u64type = gcc_jit_context_get_int_type(ctx, 64, 0);
        i32type =  gcc_jit_context_get_type(ctx,GCC_JIT_TYPE_INT);//gcc_jit_context_get_int_type(ctx, 32, 1);
        i64type = gcc_jit_context_get_type(ctx, GCC_JIT_TYPE_LONG_LONG);//gcc_jit_context_get_int_type(ctx, 64, 1);

        memcpy = gcc_jit_context_get_builtin_function(ctx, "memcpy");

        heapType =
            gcc_jit_type_get_pointer(i32type);

        // debug stuff
        ctx.gcc_jit_context_set_bool_option(
            GCC_JIT_BOOL_OPTION_DUMP_INITIAL_GIMPLE, 1
         );

        memcpy = gcc_jit_context_get_builtin_function(ctx, "memcpy");
    }

    void Finalize()
    {
        gcc_jit_context_dump_to_file(ctx, "ctx.c", 0);
        result = gcc_jit_context_compile(ctx);
    }

    void beginFunction(uint fnId, void* fd = null)
    {
        insideFunction = true;
        writeln("parameterCount: ", parameterCount);
        writeln ("functionIndex: ", (&functions[0])  - currentFunc);
        jparam[3] p;
        import ddmd.func : FuncDeclaration;
        auto name = (cast(FuncDeclaration) fd).toChars;

        p[0] = gcc_jit_context_new_param(ctx, currentLoc, gcc_jit_context_new_array_type(ctx, currentLoc, i64type, max_params), "paramArray");// long[64] args;
        p[1] = gcc_jit_context_new_param(ctx, currentLoc, gcc_jit_type_get_pointer(i32type), "heapSize"); //uint* heapSize
        p[2] = gcc_jit_context_new_param(ctx, currentLoc, heapType, "heap"); //uint[2^^26] heap

        fname = cast(char*) (name ? name : ("f" ~ to!string(fnId)).toStringz);
        func = gcc_jit_context_new_function(ctx,
            null, GCC_JIT_FUNCTION_EXPORTED, i64type,
            cast(const) fname,
            cast(int)p.length, cast(jparam*)&p, 0
        );

        newBlock("prologue");

        foreach(uint _p;0 .. parameterCount)
        {
            parameters[_p] = gcc_jit_context_new_array_access(ctx, null,
                gcc_jit_param_as_rvalue(p[0]), rvalue(_p)
            );
        }

        heapSize = gcc_jit_param_as_lvalue(p[1]);
        _heap = gcc_jit_param_as_lvalue(p[2]);

        newBlock("body");

        gcc_jit_block_end_with_jump(blocks[blockCount - 2], currentLoc, block);
    }

    BCFunction endFunction()
    {
        insideFunction = false;
        return functions[functionCount++];
    }

    BCValue genTemporary(BCType bct)
    {
        //TODO replace i64Type maybe depding on bct
        auto type = i64type;
        char[20] name = "tmp";
        sprintf(&name[3], "%d", temporaryCount);
        temporaries[temporaryCount++] = gcc_jit_function_new_local(func, currentLoc, type, &name[0]);
        auto addr = addStackValue(temporaries[temporaryCount - 1]);
        return BCValue(addr, bct, temporaryCount);
    }

    BCValue genLocal(BCType bct, string name)
    {
        assert(name, "locals have to have a name");
        //TODO replace i64Type maybe depding on bct
        auto type = i64type;
        locals[localCount++] = gcc_jit_function_new_local(func, currentLoc, type, &name[0]);
        auto addr = addStackValue(locals[localCount - 1]);
        return BCValue(addr, bct, localCount, name);
    }

    BCValue genParameter(BCType bct, string name = null)
    {
        import std.string;
        if (bct != i32Type)
            assert(0, "can currently only create params of i32Type");
        //parameters[parameterCount] =
        auto r = BCValue(BCParameter(parameterCount++, bct, StackAddr(0)));
        return r;

    }

    BCAddr beginJmp()
    {
        newBlock("beginJmp");
        return BCAddr(blockCount - 2);
    }

    void endJmp(BCAddr atIp, BCLabel target)
    {
        gcc_jit_block_end_with_jump(blocks[atIp], currentLoc, blocks[target.addr]);
    }

    BCLabel genLabel()
    {
        newBlock("genLabel");
        gcc_jit_block_end_with_jump(blocks[blockCount - 2], currentLoc, block);
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
        gcc_jit_block_end_with_jump(block, currentLoc, blocks[target.addr.addr]);
        newBlock();
    }

    void emitFlg(BCValue lhs)
    {
        gcc_jit_block_add_assignment(block, currentLoc, lvalue(lhs), rvalue(flag));
    }

    void Alloc(BCValue heapPtr, BCValue size)
    {
        auto _size = rvalue(size);
        _size = gcc_jit_context_new_cast(ctx, null,
            _size, i32type
        );

        auto _heapSize = gcc_jit_rvalue_dereference(rvalue(heapSize), null);

        auto rheapSize = gcc_jit_context_new_cast(ctx, null,
            rvalue(_heapSize), i64type
        );

        auto lheapSize = _heapSize;

        auto result = lvalue(heapPtr);

        gcc_jit_block_add_assignment(block, null,
            result, rheapSize,
        );

        gcc_jit_block_add_assignment_op(block, null,
            lheapSize, GCC_JIT_BINARY_OP_PLUS, _size
        );
    }

    void Assert(BCValue value, BCValue err);

    void Not(BCValue result, BCValue val)
    {
        gcc_jit_block_add_assignment(block, currentLoc, lvalue(result),
            gcc_jit_context_new_unary_op(ctx, currentLoc, GCC_JIT_UNARY_OP_LOGICAL_NEGATE, i64type, rvalue(val))
        );
    }

    void Set(BCValue lhs, BCValue rhs)
    {
        gcc_jit_block_add_assignment(block, currentLoc, lvalue(lhs), rvalue(rhs));
    }

    void Lt3(BCValue result, BCValue lhs, BCValue rhs)
    {
        auto _result = result ? lvalue(result) : flag;
        gcc_jit_block_add_assignment(block, currentLoc, _result,
            gcc_jit_context_new_comparison(ctx, currentLoc, GCC_JIT_COMPARISON_LT, rvalue(lhs), rvalue(rhs))
        );
    }

    void Le3(BCValue result, BCValue lhs, BCValue rhs)
    {
        auto _result = result ? lvalue(result) : flag;
        gcc_jit_block_add_assignment(block, currentLoc, _result,
            gcc_jit_context_new_comparison(ctx, currentLoc, GCC_JIT_COMPARISON_LE, rvalue(lhs), rvalue(rhs))
        );
    }

    void Gt3(BCValue result, BCValue lhs, BCValue rhs)
    {
        auto _result = result ? lvalue(result) : flag;
        gcc_jit_block_add_assignment(block, currentLoc, _result,
            gcc_jit_context_new_comparison(ctx, currentLoc, GCC_JIT_COMPARISON_GT, rvalue(lhs), rvalue(rhs))
        );
    }

    void Ge3(BCValue result, BCValue lhs, BCValue rhs)
    {
        auto _result = result ? lvalue(result) : flag;
        gcc_jit_block_add_assignment(block, currentLoc, _result,
            gcc_jit_context_new_comparison(ctx, currentLoc, GCC_JIT_COMPARISON_GE, rvalue(lhs), rvalue(rhs))
        );
    }

    void Eq3(BCValue result, BCValue lhs, BCValue rhs)
    {
        auto _result = result ? lvalue(result) : flag;
        gcc_jit_block_add_assignment(block, currentLoc, _result,
            gcc_jit_context_new_comparison(ctx, currentLoc, GCC_JIT_COMPARISON_EQ, rvalue(lhs), rvalue(rhs))
        );
    }

    void Neq3(BCValue result, BCValue lhs, BCValue rhs)
    {
        auto _result = result ? lvalue(result) : flag;
        gcc_jit_block_add_assignment(block, currentLoc, _result,
            gcc_jit_context_new_comparison(ctx, currentLoc, GCC_JIT_COMPARISON_NE, rvalue(lhs), rvalue(rhs))
        );
    }

    void Add3(BCValue result, BCValue lhs, BCValue rhs)
    {
        assert(lhs.type == i32Type && rhs.type == i32Type);
        assert(lhs.isStackValueOrParameter || lhs.vType == BCValueType.Immediate || lhs.vType == BCValueType.Immediate);
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
        assert(lhs.isStackValueOrParameter || lhs.vType == BCValueType.Immediate);
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
        assert(lhs.isStackValueOrParameter || lhs.vType == BCValueType.Immediate);
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
        assert(lhs.isStackValueOrParameter || lhs.vType == BCValueType.Immediate);
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
        assert(lhs.isStackValueOrParameter || lhs.vType == BCValueType.Immediate);
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
        assert(lhs.isStackValueOrParameter || lhs.vType == BCValueType.Immediate);
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
        assert(lhs.isStackValueOrParameter || lhs.vType == BCValueType.Immediate);
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
        assert(lhs.isStackValueOrParameter || lhs.vType == BCValueType.Immediate);
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
        assert(lhs.isStackValueOrParameter || lhs.vType == BCValueType.Immediate);
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
        assert(lhs.isStackValueOrParameter || lhs.vType == BCValueType.Immediate);
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
    void IToF32(BCValue _to, BCValue value);
    void IToF64(BCValue _to, BCValue value);


    void Comment(string msg)
    {
        gcc_jit_block_add_comment(block, currentLoc, msg.toStringz);
    }

    void Line(uint line)
    {
        currentLoc = gcc_jit_context_new_location(ctx,
            "ctfeModule", line, 0
        );
        gcc_jit_block_add_comment(block, currentLoc, ("# Line (" ~ to!string(line) ~ ")").toStringz);
    }

    void Ret(BCValue val)
    {
        gcc_jit_block_end_with_return(block, currentLoc, rvalue(val));
    }

    void MemCpy(BCValue lhs, BCValue rhs, BCValue size)
    {
        jrvalue _lhs = rvalue(lhs.i32);
        jrvalue _rhs = rvalue(rhs.i32);
        jrvalue _size = rvalue(size);


        jrvalue size_times_four = gcc_jit_context_new_binary_op (
            ctx, null,
            GCC_JIT_BINARY_OP_MULT, i64type,
            _size,
            rvalue(uint.sizeof)
        );

        auto rHeap = rvalue(_heap);
        jrvalue[3] args;
        args[0] = gcc_jit_lvalue_get_address(gcc_jit_context_new_array_access(ctx, currentLoc, rHeap, _lhs), currentLoc); // dest
        args[1] = gcc_jit_lvalue_get_address(gcc_jit_context_new_array_access(ctx, currentLoc, rHeap, _rhs), currentLoc); // src
        args[2] = size_times_four;

        auto memcpyCall = gcc_jit_context_new_call(ctx, currentLoc, memcpy, 3, &args[0]);
        gcc_jit_block_add_eval(block, currentLoc, memcpyCall);

    }
}
