module winsamp;

/+ Compile with:
 +  dmd winsamp winsamp.def
 + or:
 +  dmd winsamp -L-Subsystem:Windows
 +
 + 64 bit version:
 +  dmd -m64 winsamp -L-Subsystem:Windows user32.lib
 +/

pragma(lib, "gdi32.lib");
import core.runtime;
import core.sys.windows.windef;
import core.sys.windows.wingdi;
import core.sys.windows.winuser;
import std.string;

enum IDC_BTNCLICK     = 101;
enum IDC_BTNDONTCLICK = 102;

extern(Windows)
int WinMain(HINSTANCE hInstance, HINSTANCE hPrevInstance, LPSTR lpCmdLine, int iCmdShow)
{
    int result;

    try
    {
        Runtime.initialize();
        result = myWinMain(hInstance, hPrevInstance, lpCmdLine, iCmdShow);
        Runtime.terminate();
    }
    catch (Throwable e)
    {
        MessageBoxA(null, e.toString().toStringz, "Error", MB_OK | MB_ICONEXCLAMATION);
        result = 0;
    }

    return result;
}

int myWinMain(HINSTANCE hInstance, HINSTANCE hPrevInstance, LPSTR lpCmdLine, int iCmdShow)
{
    wstring caption = "The Hello Program";
    wstring className = "DWndClass";
    HWND hWnd, btnClick, btnDontClick;
    MSG  msg;
    WNDCLASSW wndclass;

    wndclass.style         = CS_OWNDC | CS_HREDRAW | CS_VREDRAW;
    wndclass.lpfnWndProc   = &WindowProc;
    wndclass.cbClsExtra    = 0;
    wndclass.cbWndExtra    = 0;
    wndclass.hInstance     = hInstance;
    wndclass.hIcon         = LoadIconW(null, IDI_APPLICATION);
    wndclass.hCursor       = LoadCursorW(null, IDC_CROSS);
    wndclass.hbrBackground = cast(HBRUSH)GetStockObject(WHITE_BRUSH);
    wndclass.lpszMenuName  = null;
    wndclass.lpszClassName = className.ptr;

    if (!RegisterClassW(&wndclass))
    {
        MessageBoxW(null, "Couldn't register Window Class!", caption.ptr, MB_ICONERROR);
        return 0;
    }

    hWnd = CreateWindowW(className.ptr,        // window class name
                         caption.ptr,          // window caption
                         WS_THICKFRAME   |
                         WS_MAXIMIZEBOX  |
                         WS_MINIMIZEBOX  |
                         WS_SYSMENU      |
                         WS_VISIBLE,           // window style
                         CW_USEDEFAULT,        // initial x position
                         CW_USEDEFAULT,        // initial y position
                         600,                  // initial x size
                         400,                  // initial y size
                         HWND_DESKTOP,         // parent window handle
                         null,                 // window menu handle
                         hInstance,            // program instance handle
                         null);                // creation parameters

    if (hWnd is null)
    {
        MessageBoxW(null, "Couldn't create window.", caption.ptr, MB_ICONERROR);
        return 0;
    }

    btnClick = CreateWindowW("BUTTON", "Click Me", WS_CHILD | WS_VISIBLE,
                             0, 0, 100, 25, hWnd, cast(HMENU)IDC_BTNCLICK, hInstance, null);

    btnDontClick = CreateWindowW("BUTTON", "DON'T CLICK!", WS_CHILD | WS_VISIBLE,
                                 110, 0, 100, 25, hWnd, cast(HMENU)IDC_BTNDONTCLICK, hInstance, null);

    ShowWindow(hWnd, iCmdShow);
    UpdateWindow(hWnd);

    while (GetMessageW(&msg, null, 0, 0))
    {
        TranslateMessage(&msg);
        DispatchMessageW(&msg);
    }

    return cast(int) msg.wParam;
}

int* p;
extern(Windows)
LRESULT WindowProc(HWND hWnd, UINT message, WPARAM wParam, LPARAM lParam) nothrow
{
    switch (message)
    {
        case WM_COMMAND:
        {
            switch (LOWORD(wParam))
            {
                case IDC_BTNCLICK:
                    if (HIWORD(wParam) == BN_CLICKED)
                        MessageBoxW(hWnd, "Hello, world!", "Greeting",
                                    MB_OK | MB_ICONINFORMATION);

                    break;

                case IDC_BTNDONTCLICK:
                    if (HIWORD(wParam) == BN_CLICKED)
                    {
                        MessageBoxW(hWnd, "You've been warned...", "Prepare to GP fault",
                                    MB_OK | MB_ICONEXCLAMATION);
                        *p = 1;
                    }

                    break;

                default:
            }

            break;
        }

        case WM_PAINT:
        {
            enum text = "D Does Windows";
            PAINTSTRUCT ps;

            HDC  dc = BeginPaint(hWnd, &ps);
            scope(exit) EndPaint(hWnd, &ps);
            RECT r;
            GetClientRect(hWnd, &r);
            HFONT font = CreateFontW(80, 0, 0, 0, FW_EXTRABOLD, FALSE, FALSE,
                                     FALSE, ANSI_CHARSET, OUT_DEFAULT_PRECIS, CLIP_DEFAULT_PRECIS,
                                     DEFAULT_QUALITY, DEFAULT_PITCH | FF_DONTCARE, "Arial");
            HGDIOBJ old = SelectObject(dc, cast(HGDIOBJ) font);
            SetTextAlign(dc, TA_CENTER | TA_BASELINE);
            TextOutA(dc, r.right / 2, r.bottom / 2, text.ptr, text.length);
            DeleteObject(SelectObject(dc, old));

            break;
        }

        case WM_DESTROY:
            PostQuitMessage(0);
            break;

        default:
            break;
    }

    return DefWindowProcW(hWnd, message, wParam, lParam);
}
