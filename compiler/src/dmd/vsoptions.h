
/* Compiler implementation of the D programming language
 * Copyright (C) 2009-2024 by The D Language Foundation, All Rights Reserved
 * written by Walter Bright
 * https://www.digitalmars.com
 * Distributed under the Boost Software License, Version 1.0.
 * https://www.boost.org/LICENSE_1_0.txt
 * https://github.com/dlang/dmd/blob/master/src/dmd/vsoptions.h
 */

#pragma once

#ifdef _WIN32

struct VSOptions
{
    const char *WindowsSdkDir = nullptr;
    const char *WindowsSdkVersion = nullptr;
    const char *UCRTSdkDir = nullptr;
    const char *UCRTVersion = nullptr;
    const char *VSInstallDir = nullptr;
    const char *VCInstallDir = nullptr;
    const char *VCToolsInstallDir = nullptr; // used by VS 2017+

    void initialize();
    const char *getVCBinDir(bool x64, const char *&addpath) const;
    const char *getVCLibDir(bool x64) const;
    const char *getVCIncludeDir() const;
    const char *getUCRTLibPath(bool x64) const;
    const char *getSDKLibPath(bool x64) const;
    const char *getSDKIncludePath() const;
};

#endif // _WIN32
