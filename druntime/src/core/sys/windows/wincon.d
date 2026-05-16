/**
 * Windows API header module
 *
 * Translated from MinGW Windows headers
 *
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source: $(DRUNTIMESRC core/sys/windows/_wincon.d)
 */
module core.sys.windows.wincon;
version (Windows):

version (ANSI) {} else version = Unicode;
pragma(lib, "kernel32");

import core.sys.windows.w32api, core.sys.windows.windef;

// FIXME: clean up Windows version support

enum {
    FOREGROUND_BLUE             = 0x0001,
    FOREGROUND_GREEN            = 0x0002,
    FOREGROUND_RED              = 0x0004,
    FOREGROUND_INTENSITY        = 0x0008,
    BACKGROUND_BLUE             = 0x0010,
    BACKGROUND_GREEN            = 0x0020,
    BACKGROUND_RED              = 0x0040,
    BACKGROUND_INTENSITY        = 0x0080,

    COMMON_LVB_LEADING_BYTE     = 0x0100,
    COMMON_LVB_TRAILING_BYTE    = 0x0200,
    COMMON_LVB_GRID_HORIZONTAL  = 0x0400,
    COMMON_LVB_GRID_LVERTICAL   = 0x0800,
    COMMON_LVB_GRID_RVERTICAL   = 0x1000,
    COMMON_LVB_REVERSE_VIDEO    = 0x4000,
    COMMON_LVB_UNDERSCORE       = 0x8000,

    COMMON_LVB_SBCSDBCS         = 0x0300,
}

static if (_WIN32_WINNT >= 0x501) {
    enum {
        CONSOLE_FULLSCREEN_MODE = 1,
        CONSOLE_WINDOWED_MODE   = 0
    }
}

enum {
    CTRL_C_EVENT        = 0,
    CTRL_BREAK_EVENT    = 1,
    CTRL_CLOSE_EVENT    = 2,
    CTRL_LOGOFF_EVENT   = 5,
    CTRL_SHUTDOWN_EVENT = 6
}

enum {
    ENABLE_PROCESSED_INPUT        = 1,
    ENABLE_LINE_INPUT             = 2,
    ENABLE_ECHO_INPUT             = 4,
    ENABLE_WINDOW_INPUT           = 8,
    ENABLE_MOUSE_INPUT            = 16,
    ENABLE_INSERT_MODE            = 32,
    ENABLE_QUICK_EDIT_MODE        = 64,
    ENABLE_EXTENDED_FLAGS         = 128,
    ENABLE_AUTO_POSITION          = 256,
    ENABLE_VIRTUAL_TERMINAL_INPUT = 512
}

enum {
    ENABLE_PROCESSED_OUTPUT            = 1,
    ENABLE_WRAP_AT_EOL_OUTPUT          = 2,
    ENABLE_VIRTUAL_TERMINAL_PROCESSING = 4,
    DISABLE_NEWLINE_AUTO_RETURN        = 8,
    ENABLE_LVB_GRID_WORLDWIDE          = 16
}

enum {
    KEY_EVENT                 = 1,
    MOUSE_EVENT               = 2,
    WINDOW_BUFFER_SIZE_EVENT  = 4,
    MENU_EVENT                = 8,
    FOCUS_EVENT               = 16
}
enum {
    RIGHT_ALT_PRESSED  = 1,
    LEFT_ALT_PRESSED   = 2,
    RIGHT_CTRL_PRESSED = 4,
    LEFT_CTRL_PRESSED  = 8,
    SHIFT_PRESSED      = 16,
    NUMLOCK_ON         = 32,
    SCROLLLOCK_ON      = 64,
    CAPSLOCK_ON        = 128,
    ENHANCED_KEY       = 256
}
enum {
    FROM_LEFT_1ST_BUTTON_PRESSED  = 1,
    RIGHTMOST_BUTTON_PRESSED      = 2,
    FROM_LEFT_2ND_BUTTON_PRESSED  = 4,
    FROM_LEFT_3RD_BUTTON_PRESSED  = 8,
    FROM_LEFT_4TH_BUTTON_PRESSED  = 16
}

enum {
    MOUSE_MOVED   = 1,
    DOUBLE_CLICK  = 2,
    MOUSE_WHEELED = 4
}

struct CHAR_INFO {
    union _Char {
        WCHAR UnicodeChar = 0;
        CHAR AsciiChar;
    }
    union {
        _Char Char;
        WCHAR UnicodeChar;
        CHAR AsciiChar;
    }
    WORD Attributes;
}
alias PCHAR_INFO = CHAR_INFO*;

struct SMALL_RECT {
    SHORT Left;
    SHORT Top;
    SHORT Right;
    SHORT Bottom;
}
alias PSMALL_RECT = SMALL_RECT*;

struct CONSOLE_CURSOR_INFO {
    DWORD dwSize;
    BOOL  bVisible;
}
alias PCONSOLE_CURSOR_INFO = CONSOLE_CURSOR_INFO*;

struct COORD {
    SHORT X;
    SHORT Y;
}
alias PCOORD = COORD*;

struct CONSOLE_FONT_INFO {
    DWORD nFont;
    COORD dwFontSize;
}
alias PCONSOLE_FONT_INFO = CONSOLE_FONT_INFO*;

struct CONSOLE_SCREEN_BUFFER_INFO {
    COORD      dwSize;
    COORD      dwCursorPosition;
    WORD       wAttributes;
    SMALL_RECT srWindow;
    COORD      dwMaximumWindowSize;
}
alias PCONSOLE_SCREEN_BUFFER_INFO = CONSOLE_SCREEN_BUFFER_INFO*;

alias PHANDLER_ROUTINE = extern(Windows) BOOL function(DWORD) nothrow;

struct KEY_EVENT_RECORD {
    BOOL  bKeyDown;
    WORD  wRepeatCount;
    WORD  wVirtualKeyCode;
    WORD  wVirtualScanCode;
    union _uChar {
        WCHAR UnicodeChar = 0;
        CHAR  AsciiChar;
    }
    union {
        WCHAR UnicodeChar = 0;
        CHAR  AsciiChar;
        _uChar uChar;
    }
    DWORD dwControlKeyState;
}
alias PKEY_EVENT_RECORD = KEY_EVENT_RECORD*;

struct MOUSE_EVENT_RECORD {
    COORD dwMousePosition;
    DWORD dwButtonState;
    DWORD dwControlKeyState;
    DWORD dwEventFlags;
}
alias PMOUSE_EVENT_RECORD = MOUSE_EVENT_RECORD*;

struct WINDOW_BUFFER_SIZE_RECORD {
    COORD dwSize;
}
alias PWINDOW_BUFFER_SIZE_RECORD = WINDOW_BUFFER_SIZE_RECORD*;

struct MENU_EVENT_RECORD {
    UINT dwCommandId;
}
alias PMENU_EVENT_RECORD = MENU_EVENT_RECORD*;

struct FOCUS_EVENT_RECORD {
    BOOL bSetFocus;
}
alias PFOCUS_EVENT_RECORD = FOCUS_EVENT_RECORD*;

struct INPUT_RECORD {
    WORD EventType;
    union _Event {
        KEY_EVENT_RECORD KeyEvent;
        MOUSE_EVENT_RECORD MouseEvent;
        WINDOW_BUFFER_SIZE_RECORD WindowBufferSizeEvent;
        MENU_EVENT_RECORD MenuEvent;
        FOCUS_EVENT_RECORD FocusEvent;
    }
    union {
        KEY_EVENT_RECORD KeyEvent;
        MOUSE_EVENT_RECORD MouseEvent;
        WINDOW_BUFFER_SIZE_RECORD WindowBufferSizeEvent;
        MENU_EVENT_RECORD MenuEvent;
        FOCUS_EVENT_RECORD FocusEvent;
        _Event Event;
    }
}
alias PINPUT_RECORD = INPUT_RECORD*;

extern (Windows) nothrow @nogc:

BOOL AllocConsole();
HANDLE CreateConsoleScreenBuffer(DWORD, DWORD, const(SECURITY_ATTRIBUTES)*, DWORD, LPVOID);
BOOL FillConsoleOutputAttribute(HANDLE, WORD, DWORD, COORD, PDWORD);
BOOL FillConsoleOutputCharacterA(HANDLE, CHAR, DWORD, COORD, PDWORD);
BOOL FillConsoleOutputCharacterW(HANDLE, WCHAR, DWORD, COORD, PDWORD);
BOOL FlushConsoleInputBuffer(HANDLE);
BOOL FreeConsole();
BOOL GenerateConsoleCtrlEvent(DWORD, DWORD);
UINT GetConsoleCP();
BOOL GetConsoleCursorInfo(HANDLE, PCONSOLE_CURSOR_INFO);
BOOL GetConsoleMode(HANDLE,PDWORD);
UINT GetConsoleOutputCP();
BOOL GetConsoleScreenBufferInfo(HANDLE, PCONSOLE_SCREEN_BUFFER_INFO);
DWORD GetConsoleTitleA(LPSTR, DWORD);
DWORD GetConsoleTitleW(LPWSTR, DWORD);
COORD GetLargestConsoleWindowSize(HANDLE);
BOOL GetNumberOfConsoleInputEvents(HANDLE, PDWORD);
BOOL GetNumberOfConsoleMouseButtons(PDWORD);
BOOL PeekConsoleInputA(HANDLE, PINPUT_RECORD, DWORD, PDWORD);
BOOL PeekConsoleInputW(HANDLE, PINPUT_RECORD, DWORD, PDWORD);
BOOL ReadConsoleA(HANDLE, PVOID, DWORD, PDWORD, PVOID);
BOOL ReadConsoleW(HANDLE, PVOID, DWORD, PDWORD, PVOID);
BOOL ReadConsoleInputA(HANDLE, PINPUT_RECORD, DWORD, PDWORD);
BOOL ReadConsoleInputW(HANDLE, PINPUT_RECORD, DWORD, PDWORD);
BOOL ReadConsoleOutputAttribute(HANDLE, LPWORD, DWORD, COORD, LPDWORD);
BOOL ReadConsoleOutputCharacterA(HANDLE, LPSTR, DWORD, COORD, PDWORD);
BOOL ReadConsoleOutputCharacterW(HANDLE, LPWSTR, DWORD, COORD, PDWORD);
BOOL ReadConsoleOutputA(HANDLE, PCHAR_INFO, COORD, COORD, PSMALL_RECT);
BOOL ReadConsoleOutputW(HANDLE, PCHAR_INFO, COORD, COORD, PSMALL_RECT);
BOOL ScrollConsoleScreenBufferA(HANDLE, const(SMALL_RECT)*, const(SMALL_RECT)*, COORD, const(CHAR_INFO)*);
BOOL ScrollConsoleScreenBufferW(HANDLE, const(SMALL_RECT)*, const(SMALL_RECT)*, COORD, const(CHAR_INFO)*);
BOOL SetConsoleActiveScreenBuffer(HANDLE);
BOOL SetConsoleCP(UINT);
BOOL SetConsoleCtrlHandler(PHANDLER_ROUTINE, BOOL);
BOOL SetConsoleCursorInfo(HANDLE, const(CONSOLE_CURSOR_INFO)*);
BOOL SetConsoleCursorPosition(HANDLE, COORD);


static if (_WIN32_WINNT >= 0x500) {
BOOL GetConsoleDisplayMode(LPDWORD);
HWND GetConsoleWindow();
}

static if (_WIN32_WINNT >= 0x501) {
BOOL AttachConsole(DWORD);
BOOL SetConsoleDisplayMode(HANDLE, DWORD, PCOORD);
enum DWORD ATTACH_PARENT_PROCESS = cast(DWORD)-1;
}

BOOL SetConsoleMode(HANDLE, DWORD);
BOOL SetConsoleOutputCP(UINT);
BOOL SetConsoleScreenBufferSize(HANDLE, COORD);
BOOL SetConsoleTextAttribute(HANDLE, WORD);
BOOL SetConsoleTitleA(LPCSTR);
BOOL SetConsoleTitleW(LPCWSTR);
BOOL SetConsoleWindowInfo(HANDLE, BOOL, const(SMALL_RECT)*);
BOOL WriteConsoleA(HANDLE, PCVOID, DWORD, PDWORD, PVOID);
BOOL WriteConsoleW(HANDLE, PCVOID, DWORD, PDWORD, PVOID);
BOOL WriteConsoleInputA(HANDLE, const(INPUT_RECORD)*, DWORD, PDWORD);
BOOL WriteConsoleInputW(HANDLE, const(INPUT_RECORD)*, DWORD, PDWORD);
BOOL WriteConsoleOutputA(HANDLE, const(CHAR_INFO)*, COORD, COORD, PSMALL_RECT);
BOOL WriteConsoleOutputW(HANDLE, const(CHAR_INFO)*, COORD, COORD, PSMALL_RECT);
BOOL WriteConsoleOutputAttribute(HANDLE, const(WORD)*, DWORD, COORD, PDWORD);
BOOL WriteConsoleOutputCharacterA(HANDLE, LPCSTR, DWORD, COORD, PDWORD);
BOOL WriteConsoleOutputCharacterW(HANDLE, LPCWSTR, DWORD, COORD, PDWORD);

version (Unicode) {
    alias FillConsoleOutputCharacter = FillConsoleOutputCharacterW;
    alias GetConsoleTitle = GetConsoleTitleW;
    alias PeekConsoleInput = PeekConsoleInputW;
    alias ReadConsole = ReadConsoleW;
    alias ReadConsoleInput = ReadConsoleInputW;
    alias ReadConsoleOutput = ReadConsoleOutputW;
    alias ReadConsoleOutputCharacter = ReadConsoleOutputCharacterW;
    alias ScrollConsoleScreenBuffer = ScrollConsoleScreenBufferW;
    alias SetConsoleTitle = SetConsoleTitleW;
    alias WriteConsole = WriteConsoleW;
    alias WriteConsoleInput = WriteConsoleInputW;
    alias WriteConsoleOutput = WriteConsoleOutputW;
    alias WriteConsoleOutputCharacter = WriteConsoleOutputCharacterW;
} else {
    alias FillConsoleOutputCharacter = FillConsoleOutputCharacterA;
    alias GetConsoleTitle = GetConsoleTitleA;
    alias PeekConsoleInput = PeekConsoleInputA;
    alias ReadConsole = ReadConsoleA;
    alias ReadConsoleInput = ReadConsoleInputA;
    alias ReadConsoleOutput = ReadConsoleOutputA;
    alias ReadConsoleOutputCharacter = ReadConsoleOutputCharacterA;
    alias ScrollConsoleScreenBuffer = ScrollConsoleScreenBufferA;
    alias SetConsoleTitle = SetConsoleTitleA;
    alias WriteConsole = WriteConsoleA;
    alias WriteConsoleInput = WriteConsoleInputA;
    alias WriteConsoleOutput = WriteConsoleOutputA;
    alias WriteConsoleOutputCharacter = WriteConsoleOutputCharacterA;
}
