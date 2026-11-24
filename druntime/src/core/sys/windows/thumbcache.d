/**
 * Windows API header module
 *
 * Translated from Windows SDK 10.0.28000.0 um/thumbcache.h
 *
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source: $(DRUNTIMESRC core/sys/windows/_thumbcache.d)
 */
module core.sys.windows.thumbcache;
version (Windows):

import core.sys.windows.basetyps, core.sys.windows.unknwn, core.sys.windows.w32api,
  core.sys.windows.windef, core.sys.windows.winnt;

static if (_WIN32_WINNT >= 0x600):

import core.sys.windows.shlobj : IShellItem;

alias WTS_FLAGS = int;
enum : WTS_FLAGS {
    WTS_NONE                 = 0,
    WTS_EXTRACT              = 0,
    WTS_INCACHEONLY          = 0x1,
    WTS_FASTEXTRACT          = 0x2,
    WTS_FORCEEXTRACTION      = 0x4,
    WTS_SLOWRECLAIM          = 0x8,
    WTS_EXTRACTDONOTCACHE    = 0x20,
    WTS_SCALETOREQUESTEDSIZE = 0x40,
    WTS_SKIPFASTEXTRACT      = 0x80,
    WTS_EXTRACTINPROC        = 0x100,
    WTS_CROPTOSQUARE         = 0x200,
    WTS_INSTANCESURROGATE    = 0x400,
    WTS_REQUIRESURROGATE     = 0x800,
    WTS_APPSTYLE             = 0x2000,
    WTS_WIDETHUMBNAILS       = 0x4000,
    WTS_IDEALCACHESIZEONLY   = 0x8000,
    WTS_SCALEUP              = 0x10000
}

alias WTS_CACHEFLAGS = int;
enum : WTS_CACHEFLAGS {
    WTS_DEFAULT    = 0,
    WTS_LOWQUALITY = 0x1,
    WTS_CACHED     = 0x2
}

alias WTS_CONTEXTFLAGS = int;
enum : WTS_CONTEXTFLAGS {
    WTSCF_DEFAULT  = 0,
    WTSCF_APPSTYLE = 0x1,
    WTSCF_SQUARE   = 0x2,
    WTSCF_WIDE     = 0x4,
    WTSCF_FAST     = 0x8
}

alias WTS_ALPHATYPE = int;
enum : WTS_ALPHATYPE {
    WTSAT_UNKNOWN = 0,
    WTSAT_RGB     = 1,
    WTSAT_ARGB    = 2
}

enum : HRESULT {
    WTS_E_FAILEDEXTRACTION                  = cast(HRESULT) 0x8004B200,
    WTS_E_EXTRACTIONTIMEDOUT                = cast(HRESULT) 0x8004B201,
    WTS_E_SURROGATEUNAVAILABLE              = cast(HRESULT) 0x8004B202,
    WTS_E_FASTEXTRACTIONNOTSUPPORTED        = cast(HRESULT) 0x8004B203,
    WTS_E_DATAFILEUNAVAILABLE               = cast(HRESULT) 0x8004B204,
    WTS_E_EXTRACTIONPENDING                 = cast(HRESULT) 0x8004B205,
    WTS_E_EXTRACTIONBLOCKED                 = cast(HRESULT) 0x8004B206,
    WTS_E_NOSTORAGEPROVIDERTHUMBNAILHANDLER = cast(HRESULT) 0x8004B207
}

struct WTS_THUMBNAILID {
    BYTE[16] rgbKey;
}

interface ISharedBitmap : IUnknown {
    HRESULT GetSharedBitmap(HBITMAP*);
    HRESULT GetSize(SIZE*);
    HRESULT GetFormat(WTS_ALPHATYPE*);
    HRESULT InitializeBitmap(HBITMAP, WTS_ALPHATYPE);
    HRESULT Detach(HBITMAP*);
}

interface IThumbnailCache : IUnknown {
    HRESULT GetThumbnail(IShellItem, UINT, WTS_FLAGS, ISharedBitmap*, WTS_CACHEFLAGS*, WTS_THUMBNAILID*);
    HRESULT GetThumbnailByID(WTS_THUMBNAILID, UINT, ISharedBitmap*, WTS_CACHEFLAGS*);
}

interface IThumbnailProvider : IUnknown {
    HRESULT GetThumbnail(UINT, HBITMAP*, WTS_ALPHATYPE*);
}

static if (_WIN32_WINNT >= 0x602) {
    interface IThumbnailSettings : IUnknown {
        HRESULT SetContext(WTS_CONTEXTFLAGS);
    }

    interface IThumbnailCachePrimer : IUnknown {
        HRESULT PageInThumbnail(IShellItem, WTS_FLAGS, UINT);
    }
}
