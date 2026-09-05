// Fiber-switch GC scan regression test for callee-saved FP registers.
//
// On AArch64 (d8-d15) and LoongArch64 (fs0-fs7), the callee-saved FP
// registers may hold a live GC pointer across a suspension point
// (e.g. fmov d8, x0).  fiber_switchContext used to report sp + 9*8 as
// the stack top, hiding the saved return address and FP registers
// from the GC scan - a pointer whose only copy sat in a saved FP
// register could be collected while the fiber was suspended.
//
// The test holds the sole reference to a canary object in the first
// callee-saved FP register across a yield (via an ABI-conformant
// helper in fiber_gc_scan_asm.S that mirrors the code a compiler
// emits when it allocates a value to such a register across a call;
// all other copies are XOR-obfuscated), forces collections plus heap
// churn from the main context, then resumes and checks the canary
// survived.

version (AArch64)          version = TestFiberFpRegGcScan;
else version (LoongArch64) version = TestFiberFpRegGcScan;

version (TestFiberFpRegGcScan)
{
    import core.memory : GC;
    import core.thread : Fiber;

    alias YieldFn = extern (C) void function() nothrow @nogc;

    extern (C) nothrow @nogc
    {
        size_t hold_in_fpreg_and_yield(size_t obf, size_t key, YieldFn yield);
        void scrub_regs();
        void compiler_barrier(void* p);
    }

    extern (C) void doYield() nothrow @nogc
    {
        Fiber.yield();
    }

    enum size_t MAGIC = 0xDEAD_BEEF_CAFE_F00D;
    enum size_t KEY = 0xA5A5_A5A5_A5A5_A5A5;
    enum PAYLOAD_WORDS = (4 * 1024 * 1024) / size_t.sizeof;

    class Canary
    {
        __gshared bool collected;
        size_t[] payload;
        ~this() { collected = true; }
    }

    // Returns the canary address XOR-obfuscated so the raw pointer has
    // no GC-visible copy outside the fiber's saved FP register.
    size_t makeCanary()
    {
        pragma(inline, false);
        auto c = new Canary;
        c.payload = new size_t[PAYLOAD_WORDS];
        c.payload[] = MAGIC;
        return (cast(size_t) cast(void*) c) ^ KEY;
    }

    // Zero the stack below the current frame to wipe stale spills of
    // the raw pointer left behind by makeCanary.
    void scrubStack()
    {
        pragma(inline, false);
        size_t[1024] z = 0;
        compiler_barrier(z.ptr);
    }

    __gshared bool sawCollected;
    __gshared bool payloadIntact;

    void fiberFunc()
    {
        size_t obf = makeCanary();
        scrubStack();

        // Suspend with the pointer's only copy held in the callee-saved
        // FP register; the obfuscated value in this frame is invisible
        // to the GC scan.
        auto c = cast(Canary) cast(void*) hold_in_fpreg_and_yield(obf, KEY, &doYield);

        sawCollected = Canary.collected;
        if (!sawCollected)
            payloadIntact = c.payload.length == PAYLOAD_WORDS
                && c.payload[0] == MAGIC && c.payload[$ - 1] == MAGIC;
    }

    void main()
    {
        auto fib = new Fiber(&fiberFunc);
        fib.call();

        // The canary now lives only in the suspended fiber's saved FP
        // register.
        scrub_regs();
        GC.collect();
        foreach (i; 0 .. 8)
        {
            auto junk = new size_t[PAYLOAD_WORDS];
            junk[] = 0x0101_0101_0101_0101;
            compiler_barrier(junk.ptr);
        }
        GC.collect();

        fib.call();
        assert(!sawCollected, "canary collected: saved FP register was hidden from the GC scan");
        assert(payloadIntact, "canary payload corrupted");
    }
}
else
{
    void main() {} // only meaningful on AArch64 / LoongArch64
}
