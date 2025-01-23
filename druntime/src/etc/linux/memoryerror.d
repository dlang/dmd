/**
 * Handle page protection errors using D errors (exceptions) or asserts.
 *
 * License: Distributed under the
 *      $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0).
 *    (See accompanying file LICENSE_1_0.txt)
 * Authors:   Amaury SECHET, FeepingCreature, Vladimir Panteleev
 * Source: $(DRUNTIMESRC etc/linux/memoryerror.d)
 */

module etc.linux.memoryerror;

version (linux)
{
    version (DigitalMars)
    {
        version (CRuntime_Glibc)
        {
            version (X86)
                version = MemoryErrorSupported;
            else version (X86_64)
                version = MemoryErrorSupported;
        }
    }
}

version (linux)
{
    version (X86)
        version = MemoryAssertSupported;
    else version (X86_64)
        version = MemoryAssertSupported;
    else version (ARM)
        version = MemoryAssertSupported;
    else version (AArch64)
        version = MemoryAssertSupported;
    else version (PPC64)
        version = MemoryAssertSupported;
}

version (MemoryErrorSupported)
    version = AnySupported;
else version (MemoryErrorSupported)
    version = AnySupported;

version (AnySupported):

import core.sys.posix.signal : SA_SIGINFO, sigaction, sigaction_t, siginfo_t, SIGSEGV;
import ucontext = core.sys.posix.ucontext;

version (MemoryAssertSupported)
{
    import core.sys.posix.signal : SA_ONSTACK, sigaltstack, SIGSTKSZ, stack_t;
}

@system:

// The first 64Kb are reserved for detecting null pointer dereferences.
// TODO: this is a platform-specific assumption, can be made more robust
private enum size_t MEMORY_RESERVED_FOR_NULL_DEREFERENCE = 4096 * 16;

version (MemoryErrorSupported)
{
    /**
     * Register memory error handler, store the old handler.
     *
     * `NullPointerError` is thrown when dereferencing null pointers.
     * A generic `InvalidPointerError` error is thrown in other cases.
     *
     * Returns: whether the registration was successful
     *
     * Limitations: Only x86 and x86_64 are supported for now.
     */
    bool registerMemoryErrorHandler() nothrow
    {
        sigaction_t action;
        action.sa_sigaction = &handleSignal;
        action.sa_flags = SA_SIGINFO;

        auto oldptr = &oldSigactionMemoryError;

        return !sigaction(SIGSEGV, &action, oldptr);
    }

    /**
     * Revert the memory error handler back to the one from before calling `registerMemoryErrorHandler()`.
     *
     * Returns: whether the registration of the old handler was successful
     */
    bool deregisterMemoryErrorHandler() nothrow
    {
        auto oldptr = &oldSigactionMemoryError;

        return !sigaction(SIGSEGV, oldptr, null);
    }

    /**
     * Thrown on POSIX systems when a SIGSEGV signal is received.
     */
    class InvalidPointerError : Error
    {
        this(string file = __FILE__, size_t line = __LINE__, Throwable next = null) nothrow
        {
            super("", file, line, next);
        }

        this(Throwable next, string file = __FILE__, size_t line = __LINE__) nothrow
        {
            super("", file, line, next);
        }
    }

    /**
     * Thrown on null pointer dereferences.
     */
    class NullPointerError : InvalidPointerError
    {
        this(string file = __FILE__, size_t line = __LINE__, Throwable next = null) nothrow
        {
            super(file, line, next);
        }

        this(Throwable next, string file = __FILE__, size_t line = __LINE__) nothrow
        {
            super(file, line, next);
        }
    }

    unittest
    {
        int* getNull() { return null; }

        assert(registerMemoryErrorHandler());

        bool b;

        try
        {
            *getNull() = 42;
        }
        catch (NullPointerError)
        {
            b = true;
        }

        assert(b);

        b = false;

        try
        {
            *getNull() = 42;
        }
        catch (InvalidPointerError)
        {
            b = true;
        }

        assert(b);

        assert(deregisterMemoryErrorHandler());
    }

    // Signal handler space.

    private:

    __gshared sigaction_t oldSigactionMemoryError;

    alias RegType = typeof(ucontext.ucontext_t.init.uc_mcontext.gregs[0]);

    version (X86_64)
    {
        static RegType savedRDI, savedRSI;

        extern(C)
        void handleSignal(int signum, siginfo_t* info, void* contextPtr) nothrow
        {
            auto context = cast(ucontext.ucontext_t*)contextPtr;

            // Save registers into global thread local, to allow recovery.
            savedRDI = context.uc_mcontext.gregs[ucontext.REG_RDI];
            savedRSI = context.uc_mcontext.gregs[ucontext.REG_RSI];

            // Hijack current context so we call our handler.
            auto rip = context.uc_mcontext.gregs[ucontext.REG_RIP];
            auto addr = cast(RegType) info.si_addr;
            context.uc_mcontext.gregs[ucontext.REG_RDI] = addr;
            context.uc_mcontext.gregs[ucontext.REG_RSI] = rip;
            context.uc_mcontext.gregs[ucontext.REG_RIP] = cast(RegType) ((rip != addr)?&sigsegvDataHandler:&sigsegvCodeHandler);
        }

        // All handler functions must be called with faulting address in RDI and original RIP in RSI.

        // This function is called when the segfault's cause is to call an invalid function pointer.
        void sigsegvCodeHandler()
        {
            asm
            {
                naked;

                // Handle the stack for an invalid function call (segfault at RIP).
                // With the return pointer, the stack is now alligned.
                push RBP;
                mov RBP, RSP;

                jmp sigsegvDataHandler;
            }
        }

        void sigsegvDataHandler()
        {
            asm
            {
                naked;

                push RSI;   // return address (original RIP).
                push RBP;   // old RBP
                mov RBP, RSP;

                pushfq;     // Save flags.
                push RAX;   // RAX, RCX, RDX, and R8 to R11 are trash registers and must be preserved as local variables.
                push RCX;
                push RDX;
                push R8;
                push R9;
                push R10;
                push R11;    // With 10 pushes, the stack is still aligned.

                // Parameter address is already set as RAX.
                call sigsegvUserspaceProcess;

                // Restore RDI and RSI values.
                call restoreRDI;
                push RAX;   // RDI is in RAX. It is pushed and will be poped back to RDI.

                call restoreRSI;
                mov RSI, RAX;

                pop RDI;

                // Restore trash registers value.
                pop R11;
                pop R10;
                pop R9;
                pop R8;
                pop RDX;
                pop RCX;
                pop RAX;
                popfq;      // Restore flags.

                // Return
                pop RBP;
                ret;
            }
        }

        // The return value is stored in EAX and EDX, so this function restore the correct value for theses registers.
        RegType restoreRDI()
        {
            return savedRDI;
        }

        RegType restoreRSI()
        {
            return savedRSI;
        }
    }
    else version (X86)
    {
        static RegType savedEAX, savedEDX;

        extern(C)
        void handleSignal(int signum, siginfo_t* info, void* contextPtr) nothrow
        {
            auto context = cast(ucontext.ucontext_t*)contextPtr;

            // Save registers into global thread local, to allow recovery.
            savedEAX = context.uc_mcontext.gregs[ucontext.REG_EAX];
            savedEDX = context.uc_mcontext.gregs[ucontext.REG_EDX];

            // Hijack current context so we call our handler.
            auto eip = context.uc_mcontext.gregs[ucontext.REG_EIP];
            auto addr = cast(RegType) info.si_addr;
            context.uc_mcontext.gregs[ucontext.REG_EAX] = addr;
            context.uc_mcontext.gregs[ucontext.REG_EDX] = eip;
            context.uc_mcontext.gregs[ucontext.REG_EIP] = cast(RegType) ((eip != addr)?&sigsegvDataHandler:&sigsegvCodeHandler);
        }

        // All handler functions must be called with faulting address in EAX and original EIP in EDX.

        // This function is called when the segfault's cause is to call an invalid function pointer.
        void sigsegvCodeHandler()
        {
            asm
            {
                naked;

                // Handle the stack for an invalid function call (segfault at EIP).
                // 4 bytes are used for function pointer; We need 12 byte to keep stack aligned.
                sub ESP, 12;
                mov [ESP + 8], EBP;
                mov EBP, ESP;

                jmp sigsegvDataHandler;
            }
        }

        void sigsegvDataHandler()
        {
            asm
            {
                naked;

                // We jump directly here if we are in a valid function call case.
                push EDX;   // return address (original EIP).
                push EBP;   // old EBP
                mov EBP, ESP;

                pushfd;     // Save flags.
                push ECX;   // ECX is a trash register and must be preserved as local variable.
                            // 4 pushes have been done. The stack is aligned.

                // Parameter address is already set as EAX.
                call sigsegvUserspaceProcess;

                // Restore register values and return.
                call restoreRegisters;

                pop ECX;
                popfd;      // Restore flags.

                // Return
                pop EBP;
                ret;
            }
        }

        // The return value is stored in EAX and EDX, so this function restore the correct value for theses registers.
        RegType[2] restoreRegisters()
        {
            RegType[2] restore;
            restore[0] = savedEAX;
            restore[1] = savedEDX;

            return restore;
        }
    }
    else
    {
        static assert(false, "Unsupported architecture.");
    }

    // User space handler
    void sigsegvUserspaceProcess(void* address)
    {
        // SEGV_MAPERR, SEGV_ACCERR.
        // The first page is protected to detect null dereferences.
        if ((cast(size_t) address) < MEMORY_RESERVED_FOR_NULL_DEREFERENCE)
        {
            throw new NullPointerError();
        }

        throw new InvalidPointerError();
    }
}

version (MemoryAssertSupported)
{
    private __gshared sigaction_t oldSigactionMemoryAssert; // sigaction before calling `registerMemoryAssertHandler`

    /**
     * Registers a signal handler for SIGSEGV that turns them into an assertion failure,
     * providing a more descriptive error message and stack trace if the program is
     * compiled with debug info and D assertions (as opposed to C assertions).
     *
     * Differences with the `registerMemoryErrorHandler` version are:
     * - The handler is registered with SA_ONSTACK, so it can handle stack overflows.
     * - It uses `assert(0)` instead of `throw new Error` and doesn't support catching the error.
     * - This is a template so that the -check and -checkaction flags of the compiled program are used,
     *   instead of the ones used for compiling druntime.
     *
     * Returns: whether the registration was successful
     */
    bool registerMemoryAssertHandler()()
    {
        nothrow @nogc extern(C)
        void _d_handleSignalAssert(int signum, siginfo_t* info, void* contextPtr)
        {
            // Guess the reason for the segfault by seeing if the faulting address
            // is close to the stack pointer or the null pointer.

            const void* segfaultingPtr = info.si_addr;

            auto context = cast(ucontext.ucontext_t*) contextPtr;
            version (X86_64)
                const stackPtr = cast(void*) context.uc_mcontext.gregs[ucontext.REG_RSP];
            else version (X86)
                const stackPtr = cast(void*) context.uc_mcontext.gregs[ucontext.REG_ESP];
            else version (ARM)
                const stackPtr = cast(void*) context.uc_mcontext.arm_sp;
            else version (AArch64)
                const stackPtr = cast(void*) context.uc_mcontext.sp;
            else version (PPC64)
                const stackPtr = cast(void*) context.uc_mcontext.regs.gpr[1];
            else
                static assert(false, "Unsupported architecture."); // TODO: other architectures
            auto distanceToStack = cast(ptrdiff_t) (stackPtr - segfaultingPtr);
            if (distanceToStack < 0)
                distanceToStack = -distanceToStack;

            if (stackPtr && distanceToStack <= 4096)
                assert(false, "segmentation fault: call stack overflow");
            else if (cast(size_t) segfaultingPtr < MEMORY_RESERVED_FOR_NULL_DEREFERENCE)
                assert(false, "segmentation fault: null pointer read/write operation");
            else
                assert(false, "segmentation fault: invalid pointer read/write operation");
        }

        sigaction_t action;
        action.sa_sigaction = &_d_handleSignalAssert;
        action.sa_flags = SA_SIGINFO | SA_ONSTACK;

        // Set up alternate stack, because segfaults can be caused by stack overflow,
        // in which case the stack is already exhausted
        __gshared ubyte[SIGSTKSZ] altStack;
        stack_t ss;
        ss.ss_sp = altStack.ptr;
        ss.ss_size = altStack.length;
        ss.ss_flags = 0;
        if (sigaltstack(&ss, null) == -1)
            return false;

        return !sigaction(SIGSEGV, &action, &oldSigactionMemoryAssert);
    }

    /**
     * Revert the memory error handler back to the one from before calling `registerMemoryAssertHandler()`.
     *
     * Returns: whether the registration of the old handler was successful
     */
    bool deregisterMemoryAssertHandler()
    {
        return !sigaction(SIGSEGV, &oldSigactionMemoryAssert, null);
    }

    unittest
    {
        // Testing actual memory errors is done in the test suite
        assert(registerMemoryAssertHandler());
        assert(deregisterMemoryAssertHandler());
    }
}
