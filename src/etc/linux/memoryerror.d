/**
 * Handle page protection error using Errors. NullPointerError is throw when deferencing null. A system dependant error is throw in other cases.
 * Note: Only x86 and x86_64 are supported for now.
 *
 * License: Distributed under the
 *      $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0).
 *    (See accompanying file LICENSE_1_0.txt)
 * Authors:   Amaury SECHET, FeepingCreature, Vladimir Panteleev
 * Source: $(DRUNTIMESRC src/etc/linux/memory.d)
 */
module etc.linux.memoryerror;

version(linux)
{

private :
import core.sys.posix.signal;
import core.sys.posix.ucontext;

// Init

shared static this()
{
    sigaction_t action;
    action.sa_sigaction = &handleSignal;
    action.sa_flags = SA_SIGINFO;
    sigaction(SIGSEGV, &action, null);
}

// Sighandler space

alias typeof({ucontext_t uc; return uc.uc_mcontext.gregs[0];}()) REG_TYPE;

version(X86_64)
{
    static REG_TYPE saved_RDI, saved_RSI;

    extern(C)
    void handleSignal(int signum, siginfo_t* info, void* contextPtr)
    {
        auto context = cast(ucontext_t*)contextPtr;

        // Save registers into global thread local, to allow recovery.
        saved_RDI = context.uc_mcontext.gregs[REG_RDI];
        saved_RSI = context.uc_mcontext.gregs[REG_RSI];

        // Hijack current context so we call our handler.
        auto rip = context.uc_mcontext.gregs[REG_RIP];
        auto addr = cast(REG_TYPE) info.si_addr;
        context.uc_mcontext.gregs[REG_RDI] = addr;
        context.uc_mcontext.gregs[REG_RSI] = rip;
        context.uc_mcontext.gregs[REG_RIP] = (rip != addr)?(cast(REG_TYPE) &sigsegv_data_handler):(cast(REG_TYPE) &sigsegv_code_handler);
    }

    // All handler functions must be called with faulting address in RDI and original RIP in RSI.

    // This function is called when the segfault's cause is to call an invalid function pointer.
    void sigsegv_code_handler()
    {
        asm
        {
            naked;

            // Handle the stack for an invalid function call (segfault at RIP).
            // With the return pointer, the stack is now alligned.
            push RBP;
            mov RBP, RSP;

            jmp sigsegv_data_handler;
        }
    }

    void sigsegv_data_handler()
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
            call sigsegv_userspace_process;

            // Restore RDI and RSI values.
            call restore_RDI;
            push RAX;   // RDI is in RAX. It is pushed and will be poped back to RDI.

            call restore_RSI;
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
    REG_TYPE restore_RDI()
    {
        return saved_RDI;
    }

    REG_TYPE restore_RSI()
    {
        return saved_RSI;
    }
}
else version(X86)
{
    static REG_TYPE saved_EAX, saved_EDX;

    extern(C)
    void handleSignal(int signum, siginfo_t* info, void* contextPtr)
    {
        auto context = cast(ucontext_t*)contextPtr;

        // Save registers into global thread local, to allow recovery.
        saved_EAX = context.uc_mcontext.gregs[REG_EAX];
        saved_EDX = context.uc_mcontext.gregs[REG_EDX];

        // Hijack current context so we call our handler.
        auto eip = context.uc_mcontext.gregs[REG_EIP];
        auto addr = cast(REG_TYPE) info.si_addr;
        context.uc_mcontext.gregs[REG_EAX] = addr;
        context.uc_mcontext.gregs[REG_EDX] = eip;
        context.uc_mcontext.gregs[REG_EIP] = (eip != addr)?(cast(REG_TYPE) &sigsegv_code_handler + 0x03):(cast(REG_TYPE) &sigsegv_data_handler);
    }

    // All handler functions must be called with faulting address in EAX and original EIP in EDX.

    // This function is called when the segfault's cause is to call an invalid function pointer.
    void sigsegv_code_handler()
    {
        asm
        {
            naked;

            // Handle the stack for an invalid function call (segfault at EIP).
            // 4 bytes are used for function pointer; We need 12 byte to keep stack aligned.
            sub ESP, 12;
            mov 8[ESP], EBP;
            mov EBP, ESP;

            jmp sigsegv_data_handler;
        }
    }

    void sigsegv_data_handler()
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
            call sigsegv_userspace_process;

            // Restore register values and return.
            call restore_registers;

            pop ECX;
            popfd;      // Restore flags.

            // Return
            pop EBP;
            ret;
        }
    }

    // The return value is stored in EAX and EDX, so this function restore the correct value for theses registers.
    REG_TYPE[2] restore_registers()
    {
        REG_TYPE[2] restore;
        restore[0] = saved_EAX;
        restore[1] = saved_EDX;

        return restore;
    }
}

// This should be calculated by druntime.
enum PAGE_SIZE = 4096;

// The first 64Kb are reserved for detecting null pointer dereferencess.
enum MEMORY_RESERVED_FOR_NULL_DEREFERENCE = 4096 * 16;

// User space handler
void sigsegv_userspace_process(void* address)
{
    // The first page is protected to detect null dereferences.
    if((cast(size_t) address) < MEMORY_RESERVED_FOR_NULL_DEREFERENCE)
    {
        throw new NullPointerError();
    }

    throw new InvalidPointerError();
}

public :

/**
 * Thrown on POSIX systems when a SIGSEGV signal is received.
 */
class InvalidPointerError : Error
{
    this(string file = __FILE__, size_t line = __LINE__, Throwable next = null)
    {
        super("", file, line, next);
    }

    this(Throwable next, string file = __FILE__, size_t line = __LINE__)
    {
        super("", file, line, next);
    }
}

/**
 * Thrown on null pointer dereferences.
 */
class NullPointerError : InvalidPointerError
{
    this(string file = __FILE__, size_t line = __LINE__, Throwable next = null)
    {
        super(file, line, next);
    }

    this(Throwable next, string file = __FILE__, size_t line = __LINE__)
    {
        super(file, line, next);
    }
}

}

