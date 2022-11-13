/**
 * Varargs implementation for the x86_64 System V ABI (not used for Win64).
 * Used by core.stdc.stdarg and core.vararg.
 *
 * Reference: https://www.uclibc.org/docs/psABI-x86_64.pdf
 *
 * Copyright: Copyright Digital Mars 2009 - 2020.
 * License:   $(HTTP www.boost.org/LICENSE_1_0.txt, Boost License 1.0).
 * Authors:   Walter Bright, Hauke Duden
 * Source: $(DRUNTIMESRC core/internal/vararg/sysv_x64.d)
 */

module core.internal.vararg.sysv_x64;

version (X86_64)
{
    version (Windows) { /* different ABI */ }
    else version = SysV_x64;
}

version (SysV_x64):

import core.stdc.stdarg : alignUp;

//@nogc:    // Not yet, need to make TypeInfo's member functions @nogc first
nothrow:

// Layout of this struct must match __gnuc_va_list for C ABI compatibility
struct __va_list_tag
{
    uint offset_regs = 6 * 8;            // no regs
    uint offset_fpregs = 6 * 8 + 8 * 16; // no fp regs
    void* stack_args;
    void* reg_args;
}
alias __va_list = __va_list_tag;

/**
 * Making it an array of 1 causes va_list to be passed as a pointer in
 * function argument lists
 */
alias va_list = __va_list*;

///
T va_arg(T)(va_list ap)
{
    static if (is(T U == __argTypes))
    {
        static if (U.length == 0 || T.sizeof > 16 || (U[0].sizeof > 8 && !is(U[0] == __vector)))
        {   // Always passed in memory
            // The arg may have more strict alignment than the stack
            void* p = ap.stack_args.alignUp!(T.alignof);
            ap.stack_args = p + T.sizeof.alignUp;
            return *cast(T*) p;
        }
        else static if (U.length == 1)
        {   // Arg is passed in one register
            alias U[0] T1;
            static if (is(T1 == double) || is(T1 == float) || is(T1 == __vector))
            {   // Passed in XMM register
                if (ap.offset_fpregs < (6 * 8 + 16 * 8))
                {
                    auto p = cast(T*) (ap.reg_args + ap.offset_fpregs);
                    ap.offset_fpregs += 16;
                    return *p;
                }
                else
                {
                    auto p = cast(T*) ap.stack_args;
                    ap.stack_args += T1.sizeof.alignUp;
                    return *p;
                }
            }
            else
            {   // Passed in regular register
                if (ap.offset_regs < 6 * 8 && T.sizeof <= 8)
                {
                    auto p = cast(T*) (ap.reg_args + ap.offset_regs);
                    ap.offset_regs += 8;
                    return *p;
                }
                else
                {
                    void* p = ap.stack_args.alignUp!(T.alignof);
                    ap.stack_args = p + T.sizeof.alignUp;
                    return *cast(T*) p;
                }
            }
        }
        else static if (U.length == 2)
        {   // Arg is passed in two registers
            alias U[0] T1;
            alias U[1] T2;

            T result = void;
            auto p1 = cast(T1*) &result;
            auto p2 = cast(T2*) ((cast(void*) &result) + 8);

            // Both must be in registers, or both on stack, hence 4 cases

            static if ((is(T1 == double) || is(T1 == float)) &&
                       (is(T2 == double) || is(T2 == float)))
            {
                if (ap.offset_fpregs < (6 * 8 + 16 * 8) - 16)
                {
                    *p1 = *cast(T1*) (ap.reg_args + ap.offset_fpregs);
                    *p2 = *cast(T2*) (ap.reg_args + ap.offset_fpregs + 16);
                    ap.offset_fpregs += 32;
                }
                else
                {
                    *p1 = *cast(T1*) ap.stack_args;
                    ap.stack_args += T1.sizeof.alignUp;
                    *p2 = *cast(T2*) ap.stack_args;
                    ap.stack_args += T2.sizeof.alignUp;
                }
            }
            else static if (is(T1 == double) || is(T1 == float))
            {
                void* a = void;
                if (ap.offset_fpregs < (6 * 8 + 16 * 8) &&
                    ap.offset_regs < 6 * 8 && T2.sizeof <= 8)
                {
                    *p1 = *cast(T1*) (ap.reg_args + ap.offset_fpregs);
                    ap.offset_fpregs += 16;
                    a = ap.reg_args + ap.offset_regs;
                    ap.offset_regs += 8;
                }
                else
                {
                    *p1 = *cast(T1*) ap.stack_args;
                    ap.stack_args += T1.sizeof.alignUp;
                    a = ap.stack_args;
                    ap.stack_args += 8;
                }
                // Be careful not to go past the size of the actual argument
                const sz2 = T.sizeof - 8;
                (cast(void*) p2)[0..sz2] = a[0..sz2];
            }
            else static if (is(T2 == double) || is(T2 == float))
            {
                if (ap.offset_regs < 6 * 8 && T1.sizeof <= 8 &&
                    ap.offset_fpregs < (6 * 8 + 16 * 8))
                {
                    *p1 = *cast(T1*) (ap.reg_args + ap.offset_regs);
                    ap.offset_regs += 8;
                    *p2 = *cast(T2*) (ap.reg_args + ap.offset_fpregs);
                    ap.offset_fpregs += 16;
                }
                else
                {
                    *p1 = *cast(T1*) ap.stack_args;
                    ap.stack_args += 8;
                    *p2 = *cast(T2*) ap.stack_args;
                    ap.stack_args += T2.sizeof.alignUp;
                }
            }
            else // both in regular registers
            {
                void* a = void;
                if (ap.offset_regs < 5 * 8 && T1.sizeof <= 8 && T2.sizeof <= 8)
                {
                    *p1 = *cast(T1*) (ap.reg_args + ap.offset_regs);
                    ap.offset_regs += 8;
                    a = ap.reg_args + ap.offset_regs;
                    ap.offset_regs += 8;
                }
                else
                {
                    *p1 = *cast(T1*) ap.stack_args;
                    ap.stack_args += 8;
                    a = ap.stack_args;
                    ap.stack_args += 8;
                }
                // Be careful not to go past the size of the actual argument
                const sz2 = T.sizeof - 8;
                (cast(void*) p2)[0..sz2] = a[0..sz2];
            }

            return result;
        }
        else
        {
            static assert(false);
        }
    }
    else
    {
        static assert(false, "not a valid argument type for va_arg");
    }
}

///
void va_arg()(va_list ap, TypeInfo ti, void* parmn)
{
    TypeInfo arg1, arg2;
    if (!ti.argTypes(arg1, arg2))
    {
        bool inXMMregister(TypeInfo arg) pure nothrow @safe
        {
            return (arg.flags & 2) != 0;
        }

        TypeInfo_Vector v1 = arg1 ? cast(TypeInfo_Vector) arg1 : null;
        if (arg1 && (arg1.tsize <= 8 || v1))
        {   // Arg is passed in one register
            auto tsize = arg1.tsize;
            void* p;
            bool stack = false;
            auto offset_fpregs_save = ap.offset_fpregs;
            auto offset_regs_save = ap.offset_regs;
        L1:
            if (inXMMregister(arg1) || v1)
            {   // Passed in XMM register
                if (ap.offset_fpregs < (6 * 8 + 16 * 8) && !stack)
                {
                    p = ap.reg_args + ap.offset_fpregs;
                    ap.offset_fpregs += 16;
                }
                else
                {
                    p = ap.stack_args;
                    ap.stack_args += tsize.alignUp;
                    stack = true;
                }
            }
            else
            {   // Passed in regular register
                if (ap.offset_regs < 6 * 8 && !stack)
                {
                    p = ap.reg_args + ap.offset_regs;
                    ap.offset_regs += 8;
                }
                else
                {
                    p = ap.stack_args;
                    ap.stack_args += 8;
                    stack = true;
                }
            }
            parmn[0..tsize] = p[0..tsize];

            if (arg2)
            {
                if (inXMMregister(arg2))
                {   // Passed in XMM register
                    if (ap.offset_fpregs < (6 * 8 + 16 * 8) && !stack)
                    {
                        p = ap.reg_args + ap.offset_fpregs;
                        ap.offset_fpregs += 16;
                    }
                    else
                    {
                        if (!stack)
                        {   // arg1 is really on the stack, so rewind and redo
                            ap.offset_fpregs = offset_fpregs_save;
                            ap.offset_regs = offset_regs_save;
                            stack = true;
                            goto L1;
                        }
                        p = ap.stack_args;
                        ap.stack_args += arg2.tsize.alignUp;
                    }
                }
                else
                {   // Passed in regular register
                    if (ap.offset_regs < 6 * 8 && !stack)
                    {
                        p = ap.reg_args + ap.offset_regs;
                        ap.offset_regs += 8;
                    }
                    else
                    {
                        if (!stack)
                        {   // arg1 is really on the stack, so rewind and redo
                            ap.offset_fpregs = offset_fpregs_save;
                            ap.offset_regs = offset_regs_save;
                            stack = true;
                            goto L1;
                        }
                        p = ap.stack_args;
                        ap.stack_args += 8;
                    }
                }
                auto sz = ti.tsize - 8;
                (parmn + 8)[0..sz] = p[0..sz];
            }
        }
        else
        {   // Always passed in memory
            // The arg may have more strict alignment than the stack
            auto talign = ti.talign;
            auto tsize = ti.tsize;
            auto p = cast(void*) ((cast(size_t) ap.stack_args + talign - 1) & ~(talign - 1));
            ap.stack_args = p + tsize.alignUp;
            parmn[0..tsize] = p[0..tsize];
        }
    }
    else
    {
        assert(false, "not a valid argument type for va_arg");
    }
}
