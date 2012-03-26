/**
 * Written in the D programming language.
 * Handle page protection error using Errors. NullPointerError is throw when deferencing null. A system dependant error is throw in other cases.
 * Note : Only linux on x86 and x86_64 is supported for now.
 *
 * Copyright: Copyright Digital Mars 2000 - 2012.
 * License: Distributed under the
 *      $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0).
 *    (See accompanying file LICENSE_1_0.txt)
 * Authors:   Amaury SECHET, FeepingCreature, Vladimir Panteleev
 * Source: $(DRUNTIMESRC src/core/nullpointererror.d)
 */
module core.nullpointererror;

version(linux) {

private :
import core.sys.posix.signal;
import core.sys.posix.ucontext;

// Missing details from Druntime

version(X86_64) {
	enum {
		REG_R8 = 0,
		REG_R9,
		REG_R10,
		REG_R11,
		REG_R12,
		REG_R13,
		REG_R14,
		REG_R15,
		REG_RDI,
		REG_RSI,
		REG_RBP,
		REG_RBX,
		REG_RDX,
		REG_RAX,
		REG_RCX,
		REG_RSP,
		REG_RIP,
		REG_EFL,
		REG_CSGSFS,		/* Actually short cs, gs, fs, __pad0.  */
		REG_ERR,
		REG_TRAPNO,
		REG_OLDMASK,
		REG_CR2
	}
} else version(X86) {
	enum {
		REG_GS = 0,
		REG_FS,
		REG_ES,
		REG_DS,
		REG_EDI,
		REG_ESI,
		REG_EBP,
		REG_ESP,
		REG_EBX,
		REG_EDX,
		REG_ECX,
		REG_EAX,
		REG_TRAPNO,
		REG_ERR,
		REG_EIP,
		REG_CS,
		REG_EFL,
		REG_UESP,
		REG_SS
	}
}

// Init

shared static this() {
	sigaction_t action;
	action.sa_sigaction = &handleSignal;
	action.sa_flags = SA_SIGINFO;
	sigaction(SIGSEGV, &action, null);
}

// Sighandler space

alias typeof({ucontext_t uc; return uc.uc_mcontext.gregs[0];}()) REG_TYPE;

version(X86_64) {
	static REG_TYPE saved_RDI, saved_RSI;
	
	extern(C)
	void handleSignal(int signum, siginfo_t* info, void* contextPtr) {
		auto context = cast(ucontext_t*)contextPtr;
		
		// Save registers into global thread local, to allow recovery.
		saved_RDI = context.uc_mcontext.gregs[REG_RDI];
		saved_RSI = context.uc_mcontext.gregs[REG_RSI];
		
		// Hijack current context so we call our handler.
		auto rip = context.uc_mcontext.gregs[REG_RIP];
		auto addr = cast(REG_TYPE) info.si_addr;
		context.uc_mcontext.gregs[REG_RDI] = addr;
		context.uc_mcontext.gregs[REG_RSI] = rip;
		context.uc_mcontext.gregs[REG_RIP] = (rip != addr)?(cast(REG_TYPE) &sigsegv_userspace_handler + 0x04):(cast(REG_TYPE) &sigsegv_userspace_handler);
	}
	
	// User space
	
	// This function must be called with faulting address in RDI and original RIP in RSI.
	void sigsegv_userspace_handler() {
		asm {
			naked;
			
			// Handle the stack for an invalid function call (segfault at RIP).
			push RBP;
			mov RBP, RSP;
			
			// We jump directly here if we are in a valid function call case.
			push RSI;	// return address (original RIP).
			push RBP;	// old RBP
			mov RBP, RSP;
			
			pushf;		// Save flags.
			push RAX;	// RAX, RCX, RDX, and R8 to R11 are trash registers and must be preserved as local variables.
			push RCX;
			push RDX;
			push R8;
			push R9;
			push R10;
			push R11;
			
			// Parameter address is already set as RAX.
			call sigsegv_userspace_process;
			
			// Restore RDI and RSI values.
			call restore_RDI;
			push RAX;
			
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
			popf;		// Restore flags.
			
			// Return
			pop RBP;
			ret;
		}
	}
	
	// The return value is stored in EAX and EDX, so this function restore the correct value for theses registers.
	REG_TYPE restore_RDI() {
		return saved_RDI;
	}
	
	REG_TYPE restore_RSI() {
		return saved_RSI;
	}
} else version(X86) {
	static REG_TYPE saved_EAX, saved_EDX;
	
	extern(C)
	void handleSignal(int signum, siginfo_t* info, void* contextPtr) {
		auto context = cast(ucontext_t*)contextPtr;
		
		// Save registers into global thread local, to allow recovery.
		saved_EAX = context.uc_mcontext.gregs[REG_EAX];
		saved_EDX = context.uc_mcontext.gregs[REG_EDX];
		
		// Hijack current context so we call our handler.
		auto eip = context.uc_mcontext.gregs[REG_EIP];
		auto addr = cast(REG_TYPE) info.si_addr;
		context.uc_mcontext.gregs[REG_EAX] = addr;
		context.uc_mcontext.gregs[REG_EDX] = eip;
		context.uc_mcontext.gregs[REG_EIP] = (eip != addr)?(cast(REG_TYPE) &sigsegv_userspace_handler + 0x03):(cast(REG_TYPE) &sigsegv_userspace_handler);
	}
	
	// User space
	
	// This function must be called with faulting address in EAX and original EIP in EDX.
	void sigsegv_userspace_handler() {
		asm {
			naked;
			
			// Handle the stack for an invalid function call (segfault at EIP).
			push EBP;
			mov EBP, ESP;
			
			// We jump directly here if we are in a valid function call case.
			push EDX;	// return address (original EIP).
			push EBP;	// old EBP
			mov EBP, ESP;
			
			pushf;		// Save flags.
			push ECX;	// ECX is a trash register and must be preserved as local variable.
			
			// Parameter address is already set as EAX.
			call sigsegv_userspace_process;
			
			// Restore register values and return.
			call restore_registers;
			
			pop ECX;
			popf;		// Restore flags.
			
			// Return
			pop EBP;
			ret;
		}
	}
	
	// The return value is stored in EAX and EDX, so this function restore the correct value for theses registers.
	REG_TYPE[2] restore_registers() {
		return [saved_EAX, saved_EDX];
	}
}

// This should be calculated by druntime.
enum PAGE_SIZE = 4096;

// The first 64Kb are reserved for detecting null pointer deferences.
enum MEMORY_RESERVED_FOR_NULL_DEFERENCE = 4096 * 16;

// User space handler

void sigsegv_userspace_process(void* address) {
	// The first page is protected to detect null deference.
	if((cast(size_t) address) < MEMORY_RESERVED_FOR_NULL_DEFERENCE) {
		throw new NullPointerError();
	}
	
	throw new SignalError(SIGSEGV);
}

public :

/**
 * Thrown on posix system when a signal is recieved. Is only throw for SIGSEGV.
 */
class SignalError : Error {
	private int _signum;
	
	this(int signum, string file = __FILE__, size_t line = __LINE__, Throwable next = null) {
		_signum = signum;
		super("", file, line, next);
	}
	
	this(int signum, Throwable next, string file = __FILE__, size_t line = __LINE__) {
		_signum = signum;
		super("", file, line, next);
	}
	
	/**
	 * Property that returns the signal number.
	 */
	@property
	int signum() const {
		return _signum;
	}
}

/**
 * Throw on null pointer deference.
 */
class NullPointerError : SignalError {
	this(string file = __FILE__, size_t line = __LINE__, Throwable next = null) {
		super(SIGSEGV, file, line, next);
	}
	
	this(Throwable next, string file = __FILE__, size_t line = __LINE__) {
		super(SIGSEGV, file, line, next);
	}
}

}

