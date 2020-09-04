/**
 * Determines the platform to use for the compiler backend.
 * At the moment this the platform is defined statically by the host compiler.
 *
 * Copyright:   Copyright (C) 1999-2020 by The D Language Foundation, All Rights Reserved
 * Authors:     $(LINK2 http://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/src/dmd/target_platform.d, _target_platform.d)
 * Documentation:  https://dlang.org/phobos/dmd_target_platform.html
 * Coverage:    https://codecov.io/gh/dlang/dmd/src/master/src/dmd/target_platform.d
 */

module dmd.target_platform;

// Supported platforms by the backend
enum Platform
{
    Linux,
    OSX,
    FreeBSD,
    OpenBSD,
    Solaris,
    Windows,
    DragonFlyBSD,
}

extern(D):

// provide a global platform until globals does not use platform anymore
version (Windows)
    enum platform = Platform.Windows;
else version (linux)
    enum platform = Platform.Linux;
else version (OSX)
    enum platform = Platform.OSX;
else version (FreeBSD)
    enum platform = Platform.FreeBSD;
else version (OpenBSD)
    enum platform = Platform.Solaris;
else version (DragonFlyBSD)
    enum platform = Platform.DragonFlyBSD;
else
    static assert(0, "Unknown platform");
