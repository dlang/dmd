#include "utils.h"

#if _WIN32

// Encode Unicode/Wide string to UTF-8 string
char *wideToUTF8(const LPCWSTR wstr)
{
    if (!wstr) return NULL;
    int reqchars = WideCharToMultiByte(CP_UTF8, 0, wstr, -1, NULL, 0, NULL, NULL);
    char *str = (char *)malloc(reqchars * sizeof(char));
    WideCharToMultiByte(CP_UTF8, 0, wstr, -1, (LPSTR)str, reqchars, NULL, NULL);
    return str;
}

// Encode UTF-8 string to Unicode/Wide string
LPCWSTR UTF8toWide(const char *str)
{
    if (!str) return NULL;
    int reqchars = MultiByteToWideChar(CP_UTF8, 0, str, -1, NULL, 0);
    LPCWSTR wstr = (LPCWSTR)malloc(reqchars * sizeof(WCHAR));
    MultiByteToWideChar(CP_UTF8, 0, str, -1, (LPWSTR)wstr, reqchars);
    return wstr;
}

// get argvs in UTF-8
const char **getUTF8argvs(int argc, const wchar_t *wargv[])
{
    if (wargv != NULL && argc > 0) {
        const char **argv = (const char **)malloc(argc * sizeof(char *));
        for (size_t i = 0; i < argc; i++)
        {
            argv[i] = wideToUTF8(wargv[i]);
        }
        return argv;
    };
    return NULL;
}

void freeUTF8argvs(int argc, const char *argv[])
{
    for (size_t i = 0; i < argc; i++) {
        free((void *)argv[i]);
    };
    free(argv);
}

// get ENV variable in UTF-8
char* dgetenv(const char *name) {
    LPCWSTR wname = UTF8toWide(name);
    char *var = NULL;
#if defined(_MSC_VER) && _MSC_VER >= 1400
    size_t reqsz = 0;
    if (_wgetenv_s(&reqsz, NULL, 0, wname) == 0 && reqsz > 0) {
        LPWSTR wvar = (LPWSTR)malloc(reqsz * sizeof(WCHAR));
        _wgetenv_s(&reqsz, wvar, reqsz, wname);
        var = wideToUTF8(wvar);
        free((void *)wvar);
    }
#else
    LPWSTR wvar =_wgetenv(wname);
    if (wvar) var = wideToUTF8(wvar);
#endif
    free((void *)wname);
    return var;
}

int dputenv(const char *env) {
    LPCWSTR wenv = UTF8toWide(env);
    int s = _wputenv(wenv);
    free((void *)wenv);
    return s;
}

int dmkdir(const char *name) {
    LPCWSTR wname = UTF8toWide(name);
    int r = _wmkdir(wname);
    free((void *)wname);
    return r;
}

// Quote and escape argument if needed
LPCWSTR escape_arg(LPCWSTR wstr) {
    if (!wstr) return NULL;
    bool need_escape = false;
    int extra = 0;
    LPWSTR p = (LPWSTR)wstr;
    WCHAR c;
    // count how many extra chars will
    // be needed for backslashes
    while (*p != 0) {
        c = *p;
        if (c == '\\') {
            extra++;
        }
        else if (c == '"') {
            extra++;
            need_escape = true;
        }
        else if (iswspace(c)) {
            need_escape = true;
        }
        p++;
    };
    if (!need_escape) return wstr;
    size_t len = p - wstr;
    extra += 3; // for quotes and null
    LPWSTR quoted_str = (LPWSTR)malloc((len + extra) * sizeof(WCHAR));
    *quoted_str = '"';
    p = quoted_str + 1;
    for (size_t i = 0; i < len; i++) {
        c = wstr[i];
        // escape
        if (c == '"' || c == '\\') {
            *p = '\\';
            p++;
        };
        *p = c;
        p++;
    };
    *p = '"';
    p++;
    *p = 0;
    return quoted_str;
}

int dspawnlp(int mode, const char *file, const char *arg0, const char *arg1, const char *arg2) {
    LPCWSTR wfile = UTF8toWide(file);
    LPCWSTR warg0 = UTF8toWide(arg0);
    LPCWSTR warg1 = UTF8toWide(arg1);
    LPCWSTR warg2 = UTF8toWide(arg2);
    LPCWSTR escaped_warg0 = escape_arg(warg0);
    intptr_t h = _wspawnlp(mode, wfile, escaped_warg0, warg1, warg2);
    if (escaped_warg0 != warg0) free((void *)escaped_warg0);
    free((void *)wfile);
    free((void *)warg0);
    free((void *)warg1);
    free((void *)warg2);
    return h;
}

int dspawnl(int mode, const char *file, const char *arg0, const char *arg1, const char *arg2) {
    LPCWSTR wfile = UTF8toWide(file);
    LPCWSTR warg0 = UTF8toWide(arg0);
    LPCWSTR warg1 = UTF8toWide(arg1);
    LPCWSTR warg2 = UTF8toWide(arg2);
    LPCWSTR escaped_warg0 = escape_arg(warg0);
    intptr_t h = _wspawnl(mode, wfile, escaped_warg0, warg1, warg2);
    if (escaped_warg0 != warg0) free((void *)escaped_warg0);
    free((void *)wfile);
    free((void *)warg0);
    free((void *)warg1);
    free((void *)warg2);
    return h;
}

int dspawnv(int mode, const char *file, const char *const *argv) {
    LPCWSTR wfile = UTF8toWide(file);
    int argc = 0;
    while (argv[argc] != NULL) { argc++; };
    LPCWSTR *wargv = (LPCWSTR *)malloc((argc + 1) * sizeof(LPCWSTR));
    LPCWSTR warg;
    for (size_t i = 0; i < argc; i++)
    {
        warg = UTF8toWide(argv[i]);
        wargv[i] = escape_arg(warg);
        if (wargv[i] != warg) free((void *)warg);
    };
    wargv[argc] = NULL;
    intptr_t h = _wspawnv(mode, wfile, wargv);
    free((void *)wfile);
    for (size_t i = 0; i < argc; i++)
    {
         free((void *)wargv[i]);
    }
    free((void *)wargv);
    return h;
}

#else

char *dgetenv(const char *name) {
    return getenv(name);
}

int dputenv(const char *env) {
    return putenv(env);
}

int dmkdir(const char *name) {
    return mkdir(name, (7 << 6) | (7 << 3) | 7);
}

int dspawnlp(int mode, const char *file, const char *arg0, const char *arg1, const char *arg2) {
    return spawnlp(mode, file, arg0, arg1, arg2);
}

int dspawnl(int mode, const char *file, const char *arg0, const char *arg1, const char *arg2) {
    return dspawnl(mode, file, arg0, arg1, arg2);
}

#endif
