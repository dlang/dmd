module testthrow;

import core.runtime;
import std.c.windows.windows;
import std.string;
import std.exception;

extern(Windows)
int WinMain(HINSTANCE hInstance, HINSTANCE hPrevInstance, LPSTR lpCmdLine, int iCmdShow)
{
    int result;
    void exceptionHandler(Throwable e) { throw e; }

    try
    {
        Runtime.initialize(&exceptionHandler);
        result = myWinMain(hInstance, hPrevInstance, lpCmdLine, iCmdShow);
        Runtime.terminate(&exceptionHandler);
    }
    catch (Throwable e)
    {
        MyException me = cast(MyException)e;
        assert(me.x == 42);
        result = 0;
    }

    return result;
}

int myWinMain(HINSTANCE hInstance, HINSTANCE hPrevInstance, LPSTR lpCmdLine, int iCmdShow)
{
    string className = "DWndClass";
    MSG  msg;
    WNDCLASS wndclass;

    wndclass.style         = CS_OWNDC | CS_HREDRAW | CS_VREDRAW;
    wndclass.lpfnWndProc   = &WindowProc;
    wndclass.cbClsExtra    = 0;
    wndclass.cbWndExtra    = 0;
    wndclass.hInstance     = hInstance;
    wndclass.hIcon         = LoadIconA(null, IDI_APPLICATION);
    wndclass.hCursor       = LoadCursorA(null, IDC_CROSS);
    wndclass.hbrBackground = null;
    wndclass.lpszMenuName  = null;
    wndclass.lpszClassName = className.toStringz();

    if (!RegisterClassA(&wndclass))
    {
        MessageBoxA(null, "Couldn't register Window Class!", null, MB_ICONERROR);
        return 0;
    }

    HWND hWnd = CreateWindowA(className.toStringz(),  // window class name
                         null,    // window caption
                         WS_THICKFRAME   |
                         WS_MAXIMIZEBOX  |
                         WS_MINIMIZEBOX  |
                         WS_SYSMENU      |
                         WS_VISIBLE,           // window style
                         CW_USEDEFAULT,        // initial x position
                         CW_USEDEFAULT,        // initial y position
                         0,                  // initial x size
                         0,                  // initial y size
                         HWND_DESKTOP,         // parent window handle
                         null,                 // window menu handle
                         hInstance,            // program instance handle
                         null);                // creation parameters

    if (hWnd is null)
    {
        MessageBoxA(null, "Couldn't create window.", null, MB_ICONERROR);
        return 0;
    }

    ShowWindow(hWnd, iCmdShow);
    UpdateWindow(hWnd);

    while (GetMessageA(&msg, null, 0, 0))
    {
        TranslateMessage(&msg);
        DispatchMessageA(&msg);
    }

    return msg.wParam;
}

class MyException : Exception
{
    int x;
    this(int x)
    {
        this.x = x;
        super("");
    }
}

extern(Windows)
LRESULT WindowProc(HWND hWnd, UINT message, WPARAM wParam, LPARAM lParam)
{
    throw new MyException(42);
}
