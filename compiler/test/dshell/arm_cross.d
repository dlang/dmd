#!/usr/bin/env rdmd
/**
Cross-compile AArch64 runnable tests and execute them under qemu-aarch64.

Can be run directly or via test runner:
```
rdmd compiler/test/dshell/arm_cross.d
compiler/test/run.d arm
```
Or via the test runner:
Install prerequisites:

Debian/Ubuntu:
```
sudo apt install qemu-user clang lld gcc-aarch64-linux-gnu
```

Arch Linux:
```
sudo pacman -S qemu-user clang lld aarch64-linux-gnu-gcc
```
*/
module arm_cross;

import std.array : join;
import std.file : exists, mkdirRecurse, remove, tempDir;
import std.file : fileWrite = write;
import std.path;
import std.process;
import std.stdio;

// When run via run.d the DMD env var is set; otherwise fall back to the built binary.
string dmd()
{
    import tools.paths : dmdPath;

    auto env = environment.get("DMD");
    return env ? env : dmdPath;
}

int main()
{
    foreach (tool; ["qemu-aarch64", "clang", "ld.lld"])
    {
        if (!toolExists(tool))
        {
            writeln("Skipping arm_cross: '", tool, "' not found in PATH");
            return 0;
        }
    }

    immutable scriptDir = __FILE_FULL_PATH__.dirName;
    immutable testDir = scriptDir.buildPath("..", "runnable");
    immutable drImport = scriptDir.buildPath("..", "..", "druntime", "import");
    immutable outDir = tempDir.buildPath("arm_cross_tests");

    if (!outDir.exists)
        outDir.mkdirRecurse;

    int result = 0;
    foreach (testName; [
        "ai",
        "arm",
        "bcraii",
        "bcraii2",
        "opcolon",
        "powinline",
        "test18472",
        "test21416",
        "test24884",
    ])
        result |= runTest(outDir, testDir, drImport, testName);
    return result;
}

int runTest(string outDir, string testDir, string drImport, string testName)
{
    immutable armO = buildPath(outDir, testName ~ ".o");
    immutable armExe = buildPath(outDir, testName);
    immutable armSrc = buildPath(testDir, testName ~ ".d");

    writefln("--- %s (AArch64) ---", testName);

    if (run([
            dmd, "-marm64", "-betterC", "-c", armSrc, "-I" ~ drImport,
            "-of=" ~ armO
        ]) != 0)
        return 1;

    if (run([
        "clang", "--target=aarch64-linux-gnu", "-fuse-ld=lld", "-static",
        armO, "-o", armExe
    ]) != 0)
        return 1;

    return run(["qemu-aarch64", armExe]);
}

int run(string[] args)
{
    writeln("+ ", args.join(" "));
    stdout.flush();
    return spawnProcess(args).wait;
}

bool toolExists(string program)
{
    return execute(["which", program]).status == 0;
}
