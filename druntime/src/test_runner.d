import core.runtime, core.time : MonoTime;
import core.stdc.stdio;

version (ARM)     version = ARM_Any;
version (AArch64) version = ARM_Any;

version (ARM_Any) version (D_HardFloat) version = ARM_Any_HardFloat;

ModuleInfo* getModuleInfo(string name)
{
    foreach (m; ModuleInfo)
        if (m.name == name) return m;
    assert(0, "module '"~name~"' not found");
}

UnitTestResult tester()
{
    version (ARM_Any_HardFloat)
    {
        disableFPUFastMode();
        scope (exit)
            restoreFPUMode();
    }

    return Runtime.args.length > 1 ? testModules() : testAll();
}

string mode;


UnitTestResult testModules()
{
    UnitTestResult ret;
    ret.summarize = false;
    ret.runMain = false;
    foreach (name; Runtime.args[1..$])
    {
        immutable pkg = ".package";
        immutable pkgLen = pkg.length;

        if (name.length > pkgLen && name[$ - pkgLen .. $] == pkg)
            name = name[0 .. $ - pkgLen];

        doTest(getModuleInfo(name), ret);
    }

    return ret;
}

UnitTestResult testAll()
{
    UnitTestResult ret;
    ret.summarize = false;
    ret.runMain = false;
    foreach (moduleInfo; ModuleInfo)
    {
        doTest(moduleInfo, ret);
    }

    return ret;
}


void doTest(ModuleInfo* moduleInfo, ref UnitTestResult ret)
{
    if (auto fp = moduleInfo.unitTest)
    {
        auto name = moduleInfo.name;
        ++ret.executed;
        try
        {
            immutable t0 = MonoTime.currTime;
            fp();
            ++ret.passed;
            printf("%.3fs PASS %.*s %.*s\n",
                   (MonoTime.currTime - t0).total!"msecs" / 1000.0,
                   cast(uint)mode.length, mode.ptr,
                   cast(uint)name.length, name.ptr);
        }
        catch (Throwable e)
        {
            auto msg = e.toString();
            printf("****** FAIL %.*s %.*s\n%.*s\n",
                   cast(uint)mode.length, mode.ptr,
                   cast(uint)name.length, name.ptr,
                   cast(uint)msg.length, msg.ptr);
        }
    }
}


shared static this()
{
    version (D_Coverage)
    {
        import core.runtime : dmd_coverSetMerge;
        dmd_coverSetMerge(true);
    }
    Runtime.extendedModuleUnitTester = &tester;

    debug mode = "debug";
    else  mode =  "release";
    static if ((void*).sizeof == 4) mode ~= "32";
    else static if ((void*).sizeof == 8) mode ~= "64";
    else static assert(0, "You must be from the future!");
}

void main()
{
}

version (ARM_Any_HardFloat):

/*
iOS has ARM/AArch64 FPU in run fast mode, so need to disable these things to
help math tests to pass all their cases.  In a real iOS app, probably would not
depend on such behavior that math unit tests expect.

FPSCR(ARM)/ FPCR(AArch64) mode bits of interest. ARM has both bits 24,25 set by
default, AArch64 has just bit 25 set by default.

[25] DN Default NaN mode enable bit:
0 = default NaN mode disabled 1 = default NaN mode enabled.
[24] FZ Flush-to-zero mode enable bit:
0 = flush-to-zero mode disabled 1 = flush-to-zero mode enabled.
*/
void disableFPUFastMode()
{
    int dummy;
    version (ARM)
    {
        asm
        {
            "vmrs %0, fpscr
             bic %0, #(3 << 24)
             vmsr fpscr, %0"
            : "=r" (dummy);
        }
    }
    else version (AArch64)
    {
        asm
        {
            "mrs %0, fpcr
             and %0, %0, #~(1 << 25)
             msr fpcr, %0"
            : "=r" (dummy);
        }
    }
    else
        static assert(0);
}

void restoreFPUMode()
{
    int dummy;
    version (ARM)
    {
        asm
        {
            "vmrs %0, fpscr
             orr %0, #(3 << 24)
             vmsr fpscr, %0"
            : "=r" (dummy);
        }
    }
    else version (AArch64)
    {
        asm
        {
            "mrs %0, fpcr
             orr %0, %0, #(1 << 25)
             msr fpcr, %0"
            : "=r" (dummy);
        }
    }
    else
        static assert(0);
}
