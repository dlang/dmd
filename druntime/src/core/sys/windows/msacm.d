/**
 * Windows API header module
 *
 * Translated from MinGW Windows headers
 *
 * Authors: Stewart Gordon
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source: $(DRUNTIMESRC core/sys/windows/_msacm.d)
 */
module core.sys.windows.msacm;
version (Windows):

version (ANSI) {} else version = Unicode;

import core.sys.windows.basetsd, core.sys.windows.mmsystem, core.sys.windows.windef;

alias HACMDRIVERID = HANDLE;
alias HACMDRIVER = HANDLE;
alias LPHACMDRIVER = HACMDRIVER*;

enum size_t
    ACMDRIVERDETAILS_SHORTNAME_CHARS =  32,
    ACMDRIVERDETAILS_LONGNAME_CHARS  = 128,
    ACMDRIVERDETAILS_COPYRIGHT_CHARS =  80,
    ACMDRIVERDETAILS_LICENSING_CHARS = 128,
    ACMDRIVERDETAILS_FEATURES_CHARS  = 512;

enum size_t
    ACMFORMATDETAILS_FORMAT_CHARS       = 128,
    ACMFORMATTAGDETAILS_FORMATTAG_CHARS = 48;

align(1):

struct ACMFORMATDETAILSA {
    DWORD          cbStruct = ACMFORMATDETAILSA.sizeof;
    DWORD          dwFormatIndex;
    DWORD          dwFormatTag;
    DWORD          fdwSupport;
    LPWAVEFORMATEX pwfx;
    DWORD          cbwfx;
    char[ACMFORMATDETAILS_FORMAT_CHARS] szFormat = 0;
}
alias LPACMFORMATDETAILSA = ACMFORMATDETAILSA*;

struct ACMFORMATDETAILSW {
    DWORD          cbStruct = ACMFORMATDETAILSW.sizeof;
    DWORD          dwFormatIndex;
    DWORD          dwFormatTag;
    DWORD          fdwSupport;
    LPWAVEFORMATEX pwfx;
    DWORD          cbwfx;
    WCHAR[ACMFORMATDETAILS_FORMAT_CHARS] szFormat = 0;
}
alias LPACMFORMATDETAILSW = ACMFORMATDETAILSW*;

struct ACMFORMATTAGDETAILSA {
    DWORD cbStruct = ACMFORMATTAGDETAILSA.sizeof;
    DWORD dwFormatTagIndex;
    DWORD dwFormatTag;
    DWORD cbFormatSize;
    DWORD fdwSupport;
    DWORD cStandardFormats;
    char[ACMFORMATTAGDETAILS_FORMATTAG_CHARS] szFormatTag = 0;
}
alias LPACMFORMATTAGDETAILSA = ACMFORMATTAGDETAILSA*;

struct ACMFORMATTAGDETAILSW {
    DWORD cbStruct = ACMFORMATTAGDETAILSW.sizeof;
    DWORD dwFormatTagIndex;
    DWORD dwFormatTag;
    DWORD cbFormatSize;
    DWORD fdwSupport;
    DWORD cStandardFormats;
    WCHAR[ACMFORMATTAGDETAILS_FORMATTAG_CHARS] szFormatTag = 0;
}
alias LPACMFORMATTAGDETAILSW = ACMFORMATTAGDETAILSW*;

struct ACMDRIVERDETAILSA {
align(1):
    DWORD  cbStruct = ACMDRIVERDETAILSA.sizeof;
    FOURCC fccType;
    FOURCC fccComp;
    WORD   wMid;
    WORD   wPid;
    DWORD  vdwACM;
    DWORD  vdwDriver;
    DWORD  fdwSupport;
    DWORD  cFormatTags;
    DWORD  cFilterTags;
    HICON  hicon;
    char[ACMDRIVERDETAILS_SHORTNAME_CHARS] szShortName = 0;
    char[ACMDRIVERDETAILS_LONGNAME_CHARS]  szLongName = 0;
    char[ACMDRIVERDETAILS_COPYRIGHT_CHARS] szCopyright = 0;
    char[ACMDRIVERDETAILS_LICENSING_CHARS] szLicensing = 0;
    char[ACMDRIVERDETAILS_FEATURES_CHARS]  szFeatures = 0;
}
alias LPACMDRIVERDETAILSA = ACMDRIVERDETAILSA*;

struct ACMDRIVERDETAILSW {
align(1):
    DWORD  cbStruct = ACMDRIVERDETAILSW.sizeof;
    FOURCC fccType;
    FOURCC fccComp;
    WORD   wMid;
    WORD   wPid;
    DWORD  vdwACM;
    DWORD  vdwDriver;
    DWORD  fdwSupport;
    DWORD  cFormatTags;
    DWORD  cFilterTags;
    HICON  hicon;
    WCHAR[ACMDRIVERDETAILS_SHORTNAME_CHARS] szShortName = 0;
    WCHAR[ACMDRIVERDETAILS_LONGNAME_CHARS]  szLongName = 0;
    WCHAR[ACMDRIVERDETAILS_COPYRIGHT_CHARS] szCopyright = 0;
    WCHAR[ACMDRIVERDETAILS_LICENSING_CHARS] szLicensing = 0;
    WCHAR[ACMDRIVERDETAILS_FEATURES_CHARS]  szFeatures = 0;
}
alias LPACMDRIVERDETAILSW = ACMDRIVERDETAILSW*;

extern (Windows) {
    alias ACMFORMATENUMCBA = BOOL function(HACMDRIVERID hadid, LPACMFORMATDETAILSA pafd,
      DWORD_PTR dwInstance, DWORD fdwSupport);
    alias ACMFORMATENUMCBW = BOOL function(HACMDRIVERID hadid, LPACMFORMATDETAILSW pafd,
      DWORD_PTR dwInstance, DWORD fdwSupport);
    alias ACMFORMATTAGENUMCBA = BOOL function(HACMDRIVERID hadid, LPACMFORMATTAGDETAILSA paftd,
      DWORD_PTR dwInstance, DWORD fdwSupport);
    alias ACMFORMATTAGENUMCBW = BOOL function(HACMDRIVERID hadid, LPACMFORMATTAGDETAILSW paftd,
      DWORD_PTR dwInstance, DWORD fdwSupport);
    alias ACMDRIVERENUMCB = BOOL function(HACMDRIVERID hadid, DWORD_PTR dwInstance,
      DWORD fdwSupport);

    MMRESULT acmDriverOpen(LPHACMDRIVER phad, HACMDRIVERID hadid,
      DWORD fdwOpen);
    MMRESULT acmDriverEnum(ACMDRIVERENUMCB fnCallback, DWORD_PTR dwInstance,
      DWORD fdwEnum);
    MMRESULT acmFormatEnumA(HACMDRIVER had, LPACMFORMATDETAILSA pafd,
      ACMFORMATENUMCBA fnCallback, DWORD_PTR dwInstance, DWORD fdwEnum);
    MMRESULT acmFormatEnumW(HACMDRIVER had, LPACMFORMATDETAILSW pafd,
      ACMFORMATENUMCBW fnCallback, DWORD_PTR dwInstance, DWORD fdwEnum);
    MMRESULT acmDriverClose(HACMDRIVER had, DWORD fdwClose);
    MMRESULT acmDriverDetailsA(HACMDRIVERID hadid, LPACMDRIVERDETAILSA padd,
      DWORD fdwDetails);
    MMRESULT acmDriverDetailsW(HACMDRIVERID hadid, LPACMDRIVERDETAILSW padd,
      DWORD fdwDetails);
    MMRESULT acmFormatTagEnumA(HACMDRIVER had, LPACMFORMATTAGDETAILSA paftd,
      ACMFORMATTAGENUMCBA fnCallback, DWORD_PTR dwInstance, DWORD fdwEnum);
    MMRESULT acmFormatTagEnumW(HACMDRIVER had, LPACMFORMATTAGDETAILSW paftd,
      ACMFORMATTAGENUMCBW fnCallback, DWORD_PTR dwInstance, DWORD fdwEnum);
}

version (Unicode) {
    alias ACMFORMATDETAILS = ACMFORMATDETAILSW;
    alias ACMFORMATTAGDETAILS = ACMFORMATTAGDETAILSW;
    alias ACMDRIVERDETAILS = ACMDRIVERDETAILSW;
    alias ACMFORMATENUMCB = ACMFORMATENUMCBW;
    alias ACMFORMATTAGENUMCB = ACMFORMATTAGENUMCBW;
    alias acmFormatEnum = acmFormatEnumW;
    alias acmDriverDetails = acmDriverDetailsW;
    alias acmFormatTagEnum = acmFormatTagEnumW;
} else {
    alias ACMFORMATDETAILS = ACMFORMATDETAILSA;
    alias ACMFORMATTAGDETAILS = ACMFORMATTAGDETAILSA;
    alias ACMDRIVERDETAILS = ACMDRIVERDETAILSA;
    alias ACMFORMATENUMCB = ACMFORMATENUMCBA;
    alias ACMFORMATTAGENUMCB = ACMFORMATTAGENUMCBA;
    alias acmFormatEnum = acmFormatEnumA;
    alias acmDriverDetails = acmDriverDetailsA;
    alias acmFormatTagEnum = acmFormatTagEnumA;
}

alias LPACMFORMATDETAILS = ACMFORMATDETAILS*;
alias LPACMFORMATTAGDETAILS = ACMFORMATTAGDETAILS*;
alias LPACMDRIVERDETAILS = ACMDRIVERDETAILS*;
