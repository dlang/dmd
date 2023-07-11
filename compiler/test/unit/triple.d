// See ../README.md for information about DMD unit tests.

module triple;

import support : afterEach, defaultImportPaths;
import dmd.target;
import dmd.dmdparams;
@afterEach deinitializeFrontend()
{
    import dmd.frontend : deinitializeDMD;
    deinitializeDMD();
}

@("-target=x86-unknown-windows-msvc")
unittest
{
    auto triple = Triple("x86-unknown-windows-msvc");
    assert(triple.os == Target.OS.Windows);
    assert(triple.isX86_64 == false);
    assert(triple.cenv == TargetC.Runtime.Microsoft);
}

@("-target=x64-apple-darwin20.3.0")
unittest
{
    auto triple = Triple("x64-apple-darwin20.3.0");
    assert(triple.os == Target.OS.OSX);
    assert(triple.isX86_64 == true);
}

@("-target=x86_64+avx2-apple-darwin20.3.0")
unittest
{
    auto triple = Triple("x86_64+avx2-apple-darwin20.3.0");
    assert(triple.os == Target.OS.OSX);
    assert(triple.isX86_64 == true);
    assert(triple.cpu == CPU.avx2);
}

@("-target=x86_64-unknown-linux-musl-clang")
unittest
{
    auto triple = Triple("x86_64-unknown-linux-musl-clang");
    assert(triple.isX86_64 == true);
    assert(triple.os == Target.OS.linux);
    assert(triple.cenv == TargetC.Runtime.Musl);
    assert(triple.cppenv == TargetCPP.Runtime.Clang);
}

@("-target=x86_64-freebsd12")
unittest
{
    auto triple = Triple("x86_64-freebsd12");
    assert(triple.os == Target.OS.FreeBSD);
    assert(triple.osMajor == 12);
}
