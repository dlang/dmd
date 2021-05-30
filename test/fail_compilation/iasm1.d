// REQUIRED_ARGS: -m64
/*
TEST_OUTPUT:
---
fail_compilation/iasm1.d(103): Error: bad type/size of operands `and`
fail_compilation/iasm1.d(104): Error: bad type/size of operands `and`
---
*/

// https://issues.dlang.org/show_bug.cgi?id=15999

#line 100

void test100(ulong bar)
{
    asm { and RAX, 0xFFFFFFFF00000000; ret; }
    asm { and RAX, 0x00000000FFFFFFFF; ret; }
}

/***********************************************/

/*
TEST_OUTPUT:
---
fail_compilation/iasm1.d(213): Error: bad type/size of operands `opDispatch!"foo"`
---
*/

// https://issues.dlang.org/show_bug.cgi?id=15239

#line 200

struct T
{
    template opDispatch(string Name, P...)
    {
        static void opDispatch(P) {}
    }
}

void test2()
{
    asm
    {
        call T.foo;
    }
}

/*********************************************/

/* TEST_OUTPUT:
---
fail_compilation/iasm1.d(306): Error: operand cannot have both R8 and [R9]
fail_compilation/iasm1.d(307): Error: operand cannot have both RDX and 0x3
fail_compilation/iasm1.d(308): Error: cannot have two symbols in addressing mode
fail_compilation/iasm1.d(309): Error: cannot have two symbols in addressing mode
fail_compilation/iasm1.d(310): Error: cannot have two symbols in addressing mode
---
*/

// https://issues.dlang.org/show_bug.cgi?id=17616
// https://issues.dlang.org/show_bug.cgi?id=18373

#line 300

void test3()
{
    asm
    {
        naked;
        mov RAX,[R9][R10]R8;
        mov RAX,[3]RDX;
	mov RAX,[RIP][RIP];
	mov RAX,[RIP][RCX];
	mov RAX,[RIP]RCX;
    }
}

/*********************************************/

/*
TEST_OUTPUT:
---
fail_compilation/iasm1.d(403): Error: expression expected not `;`
---
*/

#line 400

void test4()
{
    asm { inc [; }
}

/*********************************************/

/* TEST_OUTPUT:
---
fail_compilation/iasm1.d(505): Error: function `iasm1.test5` label `L1` is undefined
---
*/

#line 500

void test5()
{
    asm
    {
        jmp L1;
    L2:
        nop;
    }
}

/*********************************************/

/* TEST_OUTPUT:
---
fail_compilation/iasm1.d(615): Error: delegate `iasm1.test6.__foreachbody1` label `L1` is undefined
---
*/

#line 600

struct S
{
    static int opApply(int delegate(ref int) dg)
    {
        return 0;
    }
}

void test6()
{
    foreach(f; S)
    {
        asm
        {
            jmp L1;
        }
        goto L1;
    }
    L1:;
}

