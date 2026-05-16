/**
 * Windows API header module
 *
 * Translated from MinGW Windows headers
 *
 * Authors: Stewart Gordon
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source: $(DRUNTIMESRC core/sys/windows/_windef.d)
 */
module core.sys.windows.windef;
version (Windows):

public import core.sys.windows.winnt;
import core.sys.windows.w32api;

enum size_t MAX_PATH = 260;

pure nothrow @nogc {
    ushort MAKEWORD(ubyte a, ubyte b) {
        return cast(ushort) ((b << 8) | a);
    }

    ushort MAKEWORD(ushort a, ushort b) {
        assert((a & 0xFF00) == 0);
        assert((b & 0xFF00) == 0);
        return MAKEWORD(cast(ubyte)a, cast(ubyte)b);
    }

    uint MAKELONG(ushort a, ushort b) {
        return cast(uint) ((b << 16) | a);
    }

    uint MAKELONG(uint a, uint b) {
        assert((a & 0xFFFF0000) == 0);
        assert((b & 0xFFFF0000) == 0);
        return MAKELONG(cast(ushort)a, cast(ushort)b);
    }

    ushort LOWORD(ulong l) {
        return cast(ushort) l;
    }

    ushort HIWORD(ulong l) {
        return cast(ushort) (l >>> 16);
    }

    ubyte LOBYTE(ushort w) {
        return cast(ubyte) w;
    }

    ubyte HIBYTE(ushort w) {
        return cast(ubyte) (w >>> 8);
    }
}

enum NULL = null;
static assert (is(typeof({
    void test(int* p) {}
    test(NULL);
})));

alias BYTE = ubyte;
alias PBYTE = ubyte*, LPBYTE = ubyte*;
alias USHORT = ushort, WORD = ushort, ATOM = ushort;
alias PUSHORT = ushort*, PWORD = ushort*, LPWORD = ushort*;
alias ULONG = uint, DWORD = uint, UINT = uint, COLORREF = uint;
alias PULONG = uint*, PDWORD = uint*, LPDWORD = uint*, PUINT = uint*, LPUINT = uint*, LPCOLORREF = uint*;
alias WINBOOL = int, BOOL = int, INT = int, LONG = int, HFILE = int, HRESULT = int;
alias PWINBOOL = int*, LPWINBOOL = int*, PBOOL = int*, LPBOOL = int*, PINT = int*, LPINT = int*, LPLONG = int*;
alias FLOAT = float;
alias PFLOAT = float*;
alias PCVOID = const(void)*, LPCVOID = const(void)*;

alias WPARAM = UINT_PTR;
alias LPARAM = LONG_PTR, LRESULT = LONG_PTR;

alias HHOOK = HANDLE;
alias HGLOBAL = HANDLE;
alias HLOCAL = HANDLE;
alias GLOBALHANDLE = HANDLE;
alias LOCALHANDLE = HANDLE;
alias HGDIOBJ = HANDLE;
alias HACCEL = HANDLE;
alias HBITMAP = HGDIOBJ;
alias HBRUSH = HGDIOBJ;
alias HCOLORSPACE = HANDLE;
alias HDC = HANDLE;
alias HGLRC = HANDLE;
alias HDESK = HANDLE;
alias HENHMETAFILE = HANDLE;
alias HFONT = HGDIOBJ;
alias HICON = HANDLE;
alias HINSTANCE = HANDLE;
alias HKEY = HANDLE;
alias HMENU = HANDLE;
alias HMETAFILE = HANDLE;
alias HMODULE = HANDLE;
alias HMONITOR = HANDLE;
alias HPALETTE = HANDLE;
alias HPEN = HGDIOBJ;
alias HRGN = HGDIOBJ;
alias HRSRC = HANDLE;
alias HSTR = HANDLE;
alias HTASK = HANDLE;
alias HWND = HANDLE;
alias HWINSTA = HANDLE;
alias HKL = HANDLE;
alias HCURSOR = HANDLE;
alias PHKEY = HKEY*;

static if (_WIN32_WINNT >= 0x500) {
    alias HTERMINAL = HANDLE;
    alias HWINEVENTHOOK = HANDLE;
}

alias FARPROC = extern (Windows) INT_PTR function() nothrow, NEARPROC = extern (Windows) INT_PTR function() nothrow, PROC = extern (Windows) INT_PTR function() nothrow;

struct RECT {
    LONG left;
    LONG top;
    LONG right;
    LONG bottom;
}
alias RECTL = RECT;
alias PRECT = RECT*, NPRECT = RECT*, LPRECT = RECT*, PRECTL = RECT*, LPRECTL = RECT*;
alias LPCRECT = const(RECT)*, LPCRECTL = const(RECT)*;

struct POINT {
    LONG x;
    LONG y;
}
alias POINTL = POINT;
alias PPOINT = POINT*, NPPOINT = POINT*, LPPOINT = POINT*, PPOINTL = POINT*, LPPOINTL = POINT*;

struct SIZE {
    LONG cx;
    LONG cy;
}
alias SIZEL = SIZE;
alias PSIZE = SIZE*, LPSIZE = SIZE*, PSIZEL = SIZE*, LPSIZEL = SIZE*;

struct POINTS {
    SHORT x;
    SHORT y;
}
alias PPOINTS = POINTS*, LPPOINTS = POINTS*;

enum : BOOL {
    FALSE = 0,
    TRUE  = 1
}
