
/* Compile with:
 *      dmd winsamp gdi32.lib winsamp.def
 */

import std.c.windows.windows;
import std.c.stdio;

const int IDC_BTNCLICK     = 101;
const int IDC_BTNDONTCLICK = 102;

extern (Windows)
int WindowProc(HWND hWnd, uint uMsg, WPARAM wParam, LPARAM lParam)
{
    switch (uMsg)
    {
        case WM_COMMAND:
        {
            switch (LOWORD(wParam))
            {
                case IDC_BTNCLICK:

                    if (HIWORD(wParam) == BN_CLICKED)
                        MessageBoxA(hWnd, "Hello, world!", "Greeting",
                                    MB_OK | MB_ICONINFORMATION);

                    break;

                case IDC_BTNDONTCLICK:

                    if (HIWORD(wParam) == BN_CLICKED)
                    {
                        MessageBoxA(hWnd, "You've been warned...", "Prepare to GP fault",
                                    MB_OK | MB_ICONEXCLAMATION);
                        *(cast(int*) null) = 666;
                    }

                    break;

                default:
                    break;
            }

            break;
        }

        case WM_PAINT:
        {
            static string text = "D Does Windows";
            PAINTSTRUCT ps;
            HDC  dc = BeginPaint(hWnd, &ps);
            RECT r;
            GetClientRect(hWnd, &r);
            HFONT font = CreateFontA(80, 0, 0, 0, FW_EXTRABOLD, FALSE, FALSE,
                                     FALSE, ANSI_CHARSET, OUT_DEFAULT_PRECIS, CLIP_DEFAULT_PRECIS,
                                     DEFAULT_QUALITY, DEFAULT_PITCH | FF_DONTCARE, "Arial");
            HGDIOBJ old = SelectObject(dc, cast(HGDIOBJ) font);
            SetTextAlign(dc, TA_CENTER | TA_BASELINE);
            TextOutA(dc, r.right / 2, r.bottom / 2, text.ptr, text.length);
            SelectObject(dc, old);
            EndPaint(hWnd, &ps);
            break;
        }

        case WM_DESTROY:
            PostQuitMessage(0);
            break;

        default:
            break;
    }

    return DefWindowProcA(hWnd, uMsg, wParam, lParam);
}

int doit()
{
    HINSTANCE hInst = GetModuleHandleA(null);
    WNDCLASS  wc;

    wc.lpszClassName = "DWndClass";
    wc.style         = CS_OWNDC | CS_HREDRAW | CS_VREDRAW;
    wc.lpfnWndProc   = &WindowProc;
    wc.hInstance     = hInst;
    wc.hIcon         = LoadIconA(cast(HINSTANCE) null, IDI_APPLICATION);
    wc.hCursor       = LoadCursorA(cast(HINSTANCE) null, IDC_CROSS);
    wc.hbrBackground = cast(HBRUSH) (COLOR_WINDOW + 1);
    wc.lpszMenuName  = null;
    wc.cbClsExtra    = wc.cbWndExtra = 0;
    auto a = RegisterClassA(&wc);
    assert(a);

    HWND hWnd, btnClick, btnDontClick;
    hWnd = CreateWindowA("DWndClass", "Just a window", WS_THICKFRAME |
                         WS_MAXIMIZEBOX | WS_MINIMIZEBOX | WS_SYSMENU | WS_VISIBLE,
                         CW_USEDEFAULT, CW_USEDEFAULT, 400, 300, HWND_DESKTOP,
                         cast(HMENU) null, hInst, null);
    assert(hWnd);

    btnClick = CreateWindowA("BUTTON", "Click Me", WS_CHILD | WS_VISIBLE,
                             0, 0, 100, 25, hWnd, cast(HMENU) IDC_BTNCLICK, hInst, null);

    btnDontClick = CreateWindowA("BUTTON", "DON'T CLICK!", WS_CHILD | WS_VISIBLE,
                                 110, 0, 100, 25, hWnd, cast(HMENU) IDC_BTNDONTCLICK, hInst, null);

    MSG msg;

    while (GetMessageA(&msg, cast(HWND) null, 0, 0))
    {
        TranslateMessage(&msg);
        DispatchMessageA(&msg);
    }

    return 1;
}

/**********************************************************/

/* Note the similarity of this code to the console D startup
 * code in \dmd\src\phobos\dmain2.d
 * You'll also need a .def file with at least the following in it:
 *      EXETYPE NT
 *      SUBSYSTEM WINDOWS
 */

extern (C) void gc_init();

extern (C) void gc_term();

extern (C) void _minit();

extern (C) void _moduleCtor();

// ~ extern (C) void _moduleUnitTests();         //~ errors out

extern (Windows)
int WinMain(HINSTANCE hInstance, HINSTANCE hPrevInstance, LPSTR lpCmdLine, int nCmdShow)
{
    int result;

    gc_init();                  // initialize garbage collector
    _minit();                   // initialize module constructor table

    try
    {
        _moduleCtor();          // call module constructors
        // ~ _moduleUnitTests();        // run unit tests (optional) //~ errors out

        result = doit();        // insert user code here
    }

    catch (Exception e)         // catch any uncaught exceptions
    {
        MessageBoxA(null, cast(char *) e.toString(), "Error",
                    MB_OK | MB_ICONEXCLAMATION);
        result = 0;             // failed
    }

    gc_term();                  // run finalizers; terminate garbage collector
    return result;
}
