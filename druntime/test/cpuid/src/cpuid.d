module puid;
import core.cpuid;
import core.stdc.stdio;

mixin template printFlag(string name)
{
    int len = printf(name.ptr) + printf(": %s\n", mixin(name) ? "YES".ptr : "NO".ptr);
}

void main()
{
    printf("vendor:    %.*s\n", cast(int)vendor.length, vendor.ptr);
    printf("processor: %.*s\n", cast(int)processor.length, processor.ptr);

    printf("threadsPerCPU: %d\n", threadsPerCPU);
    printf("coresPerCPU:   %d\n", coresPerCPU);

    version(VERBOSE)
    {
        mixin printFlag!("x87onChip");
        mixin printFlag!("mmx");
        mixin printFlag!("sse");
        mixin printFlag!("sse2");
        mixin printFlag!("sse3");
        mixin printFlag!("ssse3");
        mixin printFlag!("sse41");
        mixin printFlag!("sse42");
        mixin printFlag!("sse4a");
        mixin printFlag!("aes");
        mixin printFlag!("hasPclmulqdq");
        mixin printFlag!("hasRdrand");
        mixin printFlag!("avx");
        mixin printFlag!("vaes");
        mixin printFlag!("hasVpclmulqdq");
        mixin printFlag!("fma");
        mixin printFlag!("fp16c");
        mixin printFlag!("avx2");
        mixin printFlag!("hle");
        mixin printFlag!("rtm");
        mixin printFlag!("hasRdseed");
        mixin printFlag!("hasSha");
        mixin printFlag!("amd3dnow");
        mixin printFlag!("amd3dnowExt");
        mixin printFlag!("amdMmx");
        mixin printFlag!("hasFxsr");
        mixin printFlag!("hasCmov");
        mixin printFlag!("hasRdtsc");
        mixin printFlag!("hasCmpxchg8b");
        mixin printFlag!("hasCmpxchg16b");
        mixin printFlag!("hasSysEnterSysExit");
        mixin printFlag!("has3dnowPrefetch");
        mixin printFlag!("hasLahfSahf");
        mixin printFlag!("hasPopcnt");
        mixin printFlag!("hasLzcnt");
        mixin printFlag!("isX86_64");
        mixin printFlag!("isItanium");
        mixin printFlag!("hyperThreading");
        mixin printFlag!("preferAthlon");
        mixin printFlag!("preferPentium4");
        mixin printFlag!("preferPentium1");
    }
}
