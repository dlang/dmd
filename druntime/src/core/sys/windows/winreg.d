/**
 * Windows API header module
 *
 * Translated from MinGW Windows headers
 *
 * Authors: Stewart Gordon
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source: $(DRUNTIMESRC core/sys/windows/_winreg.d)
 */
module core.sys.windows.winreg;
version (Windows):

version (ANSI) {} else version = Unicode;
pragma(lib, "advapi32");

import core.sys.windows.w32api, core.sys.windows.winbase, core.sys.windows.windef;

alias LSTATUS = LONG;

enum : HKEY { // for some reason, DMD errors if I don't give all the values explicitly
    HKEY_CLASSES_ROOT        = cast(HKEY) 0x80000000,
    HKEY_CURRENT_USER        = cast(HKEY) 0x80000001,
    HKEY_LOCAL_MACHINE       = cast(HKEY) 0x80000002,
    HKEY_USERS               = cast(HKEY) 0x80000003,
    HKEY_PERFORMANCE_DATA    = cast(HKEY) 0x80000004,
    HKEY_CURRENT_CONFIG      = cast(HKEY) 0x80000005,
    HKEY_DYN_DATA            = cast(HKEY) 0x80000006,
    HKEY_CURRENT_USER_LOCAL_SETTINGS = cast(HKEY) 0x80000007,
    HKEY_PERFORMANCE_TEXT    = cast(HKEY) 0x80000050,
    HKEY_PERFORMANCE_NLSTEXT = cast(HKEY) 0x80000060,
}

//enum : DWORD {
//    REG_OPTION_NON_VOLATILE,
//    REG_OPTION_VOLATILE
//}

enum : DWORD {
    REG_CREATED_NEW_KEY = 1,
    REG_OPENED_EXISTING_KEY
}

enum : DWORD {
    REG_NONE                       = 0,
    REG_SZ,
    REG_EXPAND_SZ,
    REG_BINARY,
    REG_DWORD_LITTLE_ENDIAN,
    REG_DWORD                      = REG_DWORD_LITTLE_ENDIAN,
    REG_DWORD_BIG_ENDIAN,
    REG_LINK,
    REG_MULTI_SZ,
    REG_RESOURCE_LIST,
    REG_FULL_RESOURCE_DESCRIPTOR,
    REG_RESOURCE_REQUIREMENTS_LIST,
    REG_QWORD_LITTLE_ENDIAN,
    REG_QWORD                      = REG_QWORD_LITTLE_ENDIAN
}

enum DWORD
    REG_NOTIFY_CHANGE_NAME       = 1,
    REG_NOTIFY_CHANGE_ATTRIBUTES = 2,
    REG_NOTIFY_CHANGE_LAST_SET   = 4,
    REG_NOTIFY_CHANGE_SECURITY   = 8;

alias REGSAM = ACCESS_MASK;

struct VALENTA {
    LPSTR ve_valuename;
    DWORD ve_valuelen;
    DWORD_PTR ve_valueptr;
    DWORD ve_type;
}
alias PVALENTA = VALENTA*;

struct VALENTW {
    LPWSTR ve_valuename;
    DWORD  ve_valuelen;
    DWORD_PTR ve_valueptr;
    DWORD  ve_type;
}
alias PVALENTW = VALENTW*;

enum PROVIDER_KEEPS_VALUE_LENGTH = 1;

struct val_context {
    int valuelen;
    LPVOID value_context;
    LPVOID val_buff_ptr;
}
alias PVALCONTEXT = val_context*;

struct PVALUEA {
    LPSTR pv_valuename;
    int pv_valuelen;
    LPVOID pv_value_context;
    DWORD pv_type;
}
alias PPVALUEA = PVALUEA*;

struct PVALUEW {
    LPWSTR pv_valuename;
    int pv_valuelen;
    LPVOID pv_value_context;
    DWORD pv_type;
}
alias PPVALUEW = PVALUEW*;

alias PQUERYHANDLER = extern (C) DWORD function(LPVOID keycontext, PVALCONTEXT val_list,
  DWORD num_vals, LPVOID outputbuffer, DWORD* total_outlen, DWORD input_blen);

struct REG_PROVIDER {
    PQUERYHANDLER pi_R0_1val;
    PQUERYHANDLER pi_R0_allvals;
    PQUERYHANDLER pi_R3_1val;
    PQUERYHANDLER pi_R3_allvals;
    DWORD pi_flags;
    LPVOID pi_key_context;
}
alias PPROVIDER = REG_PROVIDER*;

enum LPSTR WIN31_CLASS = null;

enum DWORD
    REG_PROCESS_APPKEY               = 0x00000001,
    REG_USE_CURRENT_SECURITY_CONTEXT = 0x00000002;

enum DWORD REG_MUI_STRING_TRUNCATE = 0x00000001;

enum ULONG
    REG_SECURE_CONNECTION         = 0x1,
    REG_ALLOW_TRANSPORT_FALLBACK  = 0x2,
    REG_ALLOW_UNSECURE_CONNECTION = 0x4;

static if (_WIN32_WINNT >= 0x501) {
    import core.sys.windows.reason;

    enum DWORD
        REASON_SWINSTALL    = SHTDN_REASON_MAJOR_SOFTWARE | SHTDN_REASON_MINOR_INSTALLATION,
        REASON_HWINSTALL    = SHTDN_REASON_MAJOR_HARDWARE | SHTDN_REASON_MINOR_INSTALLATION,
        REASON_SERVICEHANG  = SHTDN_REASON_MAJOR_SOFTWARE | SHTDN_REASON_MINOR_HUNG,
        REASON_UNSTABLE     = SHTDN_REASON_MAJOR_SYSTEM | SHTDN_REASON_MINOR_UNSTABLE,
        REASON_SWHWRECONF   = SHTDN_REASON_MAJOR_SOFTWARE | SHTDN_REASON_MINOR_RECONFIG,
        REASON_OTHER        = SHTDN_REASON_MAJOR_OTHER | SHTDN_REASON_MINOR_OTHER,
        REASON_UNKNOWN      = 0x000000FF,
        REASON_LEGACY_API   = SHTDN_REASON_MAJOR_LEGACY_API | SHTDN_REASON_FLAG_PLANNED,
        REASON_PLANNED_FLAG = SHTDN_REASON_FLAG_PLANNED;
}

enum DWORD MAX_SHUTDOWN_TIMEOUT = 10 * 365 * 24 * 60 * 60;

enum DWORD
    SHUTDOWN_FORCE_OTHERS          = 0x00000001,
    SHUTDOWN_FORCE_SELF            = 0x00000002,
    SHUTDOWN_RESTART               = 0x00000004,
    SHUTDOWN_POWEROFF              = 0x00000008,
    SHUTDOWN_NOREBOOT              = 0x00000010,
    SHUTDOWN_GRACE_OVERRIDE        = 0x00000020,
    SHUTDOWN_INSTALL_UPDATES       = 0x00000040,
    SHUTDOWN_RESTARTAPPS           = 0x00000080,
    SHUTDOWN_SKIP_SVC_PRESHUTDOWN  = 0x00000100,
    SHUTDOWN_HYBRID                = 0x00000200,
    SHUTDOWN_RESTART_BOOTOPTIONS   = 0x00000400,
    SHUTDOWN_SOFT_REBOOT           = 0x00000800,
    SHUTDOWN_MOBILE_UI             = 0x00001000,
    SHUTDOWN_ARSO                  = 0x00002000,
    SHUTDOWN_CHECK_SAFE_FOR_SERVER = 0x00004000,
    SHUTDOWN_VAIL_CONTAINER        = 0x00008000,
    SHUTDOWN_SYSTEM_INITIATED      = 0x00010000,
    SHUTDOWN_UPDATE_POWEROFF       = 0x00020000;

// RRF - Registry Routine Flags (for RegGetValue)
static if (_WIN32_WINNT >= 0x502) {
    enum : DWORD {
        RRF_RT_REG_NONE      = 0x00000001,
        RRF_RT_REG_SZ        = 0x00000002,
        RRF_RT_REG_EXPAND_SZ = 0x00000004,
        RRF_RT_REG_BINARY    = 0x00000008,
        RRF_RT_REG_DWORD     = 0x00000010,
        RRF_RT_REG_MULTI_SZ  = 0x00000020,
        RRF_RT_REG_QWORD     = 0x00000040,
        RRF_RT_DWORD         = RRF_RT_REG_BINARY | RRF_RT_REG_DWORD,
        RRF_RT_QWORD         = RRF_RT_REG_BINARY | RRF_RT_REG_QWORD,
        RRF_RT_ANY           = 0x0000FFFF,
        RRF_SUBKEY_WOW6464KEY = 0x00010000,
        RRF_SUBKEY_WOW6432KEY = 0x00020000,
        RRF_WOW64_MASK       = 0x00030000,
        RRF_NOEXPAND         = 0x10000000,
        RRF_ZEROONFAILURE    = 0x20000000
    }
}

extern (Windows) nothrow @nogc {
    LONG RegCloseKey(const scope HKEY);
    LONG RegConnectRegistryA(LPCSTR, HKEY, PHKEY);
    LONG RegConnectRegistryW(LPCWSTR, HKEY, PHKEY);
    LONG RegCreateKeyExA(const scope HKEY, LPCSTR, DWORD, LPSTR, DWORD, REGSAM,
      LPSECURITY_ATTRIBUTES, PHKEY, PDWORD);
    LONG RegCreateKeyExW(const scope HKEY, LPCWSTR, DWORD, LPWSTR, DWORD, REGSAM,
      LPSECURITY_ATTRIBUTES, PHKEY, PDWORD);
    LONG RegDeleteKeyA(const scope HKEY, LPCSTR);
    LONG RegDeleteKeyW(const scope HKEY, LPCWSTR);
    LONG RegDeleteValueA(const scope HKEY, LPCSTR);
    LONG RegDeleteValueW(const scope HKEY, LPCWSTR);
    LONG RegEnumKeyExA(const scope HKEY, DWORD, LPSTR, PDWORD, PDWORD, LPSTR, PDWORD,
      PFILETIME);
    LONG RegEnumKeyExW(const scope HKEY, DWORD, LPWSTR, PDWORD, PDWORD, LPWSTR, PDWORD,
      PFILETIME);
    LONG RegEnumValueA(const scope HKEY, DWORD, LPSTR, PDWORD, PDWORD, PDWORD, LPBYTE,
      PDWORD);
    LONG RegEnumValueW(const scope HKEY, DWORD, LPWSTR, PDWORD, PDWORD, PDWORD, LPBYTE,
      PDWORD);
    LONG RegFlushKey(const scope HKEY);
    LONG RegLoadKeyA(const scope HKEY, LPCSTR, LPCSTR);
    LONG RegLoadKeyW(const scope HKEY, LPCWSTR, LPCWSTR);
    LONG RegOpenKeyExA(const scope HKEY, LPCSTR, DWORD, REGSAM, PHKEY);
    LONG RegOpenKeyExW(const scope HKEY, LPCWSTR, DWORD, REGSAM, PHKEY);
    LONG RegQueryInfoKeyA(const scope HKEY, LPSTR, PDWORD, PDWORD, PDWORD, PDWORD,
      PDWORD, PDWORD, PDWORD, PDWORD, PDWORD, PFILETIME);
    LONG RegQueryInfoKeyW(const scope HKEY, LPWSTR, PDWORD, PDWORD, PDWORD, PDWORD,
      PDWORD, PDWORD, PDWORD, PDWORD, PDWORD, PFILETIME);
    LONG RegQueryMultipleValuesA(const scope HKEY, PVALENTA, DWORD, LPSTR, LPDWORD);
    LONG RegQueryMultipleValuesW(const scope HKEY, PVALENTW, DWORD, LPWSTR, LPDWORD);
    LONG RegQueryValueExA(const scope HKEY, LPCSTR, LPDWORD, LPDWORD, /*LPBYTE*/LPVOID, LPDWORD);
    LONG RegQueryValueExW(const scope HKEY, LPCWSTR, LPDWORD, LPDWORD, /*LPBYTE*/LPVOID, LPDWORD);
    LONG RegReplaceKeyA(const scope HKEY, LPCSTR, LPCSTR, LPCSTR);
    LONG RegReplaceKeyW(const scope HKEY, LPCWSTR, LPCWSTR, LPCWSTR);
    LONG RegSaveKeyA(const scope HKEY, LPCSTR, LPSECURITY_ATTRIBUTES);
    LONG RegSaveKeyW(const scope HKEY, LPCWSTR, LPSECURITY_ATTRIBUTES);
    LONG RegSetKeySecurity(const scope HKEY, SECURITY_INFORMATION, PSECURITY_DESCRIPTOR);
    LONG RegSetValueExA(const scope HKEY, LPCSTR, DWORD, DWORD, const(BYTE)*, DWORD);
    LONG RegSetValueExW(const scope HKEY, LPCWSTR, DWORD, DWORD, const(BYTE)*, DWORD);
    LONG RegUnLoadKeyA(const scope HKEY, LPCSTR);
    LONG RegUnLoadKeyW(const scope HKEY, LPCWSTR);
    LONG RegNotifyChangeKeyValue(const scope HKEY, BOOL, DWORD, HANDLE, BOOL);

    BOOL AbortSystemShutdownA(LPCSTR);
    BOOL AbortSystemShutdownW(LPCWSTR);
    BOOL InitiateSystemShutdownA(LPSTR, LPSTR, DWORD, BOOL, BOOL);
    BOOL InitiateSystemShutdownW(LPWSTR, LPWSTR, DWORD, BOOL, BOOL);
    LONG RegGetKeySecurity(const scope HKEY, SECURITY_INFORMATION,
      PSECURITY_DESCRIPTOR, PDWORD);
    LONG RegRestoreKeyA(const scope HKEY, LPCSTR, DWORD);
    LONG RegRestoreKeyW(const scope HKEY, LPCWSTR, DWORD);
    LONG RegOverridePredefKey(const scope HKEY, HKEY);
    LONG RegConnectRegistryExA(LPCSTR, HKEY, ULONG, PHKEY);
    LONG RegConnectRegistryExW(LPCWSTR, HKEY, ULONG, PHKEY);

    static if (_WIN32_WINNT >= 0x500) {
        LONG RegDisablePredefinedCache();
        LONG RegOpenCurrentUser(REGSAM, PHKEY);
        LONG RegOpenUserClassesRoot(HANDLE, DWORD, REGSAM, PHKEY);
    }

    static if (_WIN32_WINNT >= 0x501) {
        LONG RegSaveKeyExA(const scope HKEY, LPCSTR, LPSECURITY_ATTRIBUTES, DWORD);
        LONG RegSaveKeyExW(const scope HKEY, LPCWSTR, LPSECURITY_ATTRIBUTES, DWORD);
        BOOL InitiateSystemShutdownExA(LPSTR, LPSTR, DWORD, BOOL, BOOL, DWORD);
        BOOL InitiateSystemShutdownExW(LPWSTR, LPWSTR, DWORD, BOOL, BOOL, DWORD);
    }

    static if (_WIN32_WINNT >= 0x502) {
        LONG RegGetValueA(const scope HKEY hkey, LPCSTR lpSubKey, LPCSTR lpValue,
          DWORD dwFlags, LPDWORD pdwType, PVOID pvData, LPDWORD pcbData);
        LONG RegGetValueW(const scope HKEY hkey, LPCWSTR lpSubKey, LPCWSTR lpValue,
          DWORD dwFlags, LPDWORD pdwType, PVOID pvData, LPDWORD pcbData);
        LONG RegDeleteKeyExA(const scope HKEY, LPCSTR, REGSAM, DWORD);
        LONG RegDeleteKeyExW(const scope HKEY, LPCWSTR, REGSAM, DWORD);
        LONG RegDisableReflectionKey(HKEY);
        LONG RegEnableReflectionKey(HKEY);
        LONG RegQueryReflectionKey(HKEY, BOOL*);
    }

    static if (_WIN32_WINNT >= 0x600) {
        LONG RegCopyTreeA(const scope HKEY, LPCSTR, HKEY);
        LONG RegCopyTreeW(const scope HKEY, LPCWSTR, HKEY);
        LONG RegCreateKeyTransactedA(const scope HKEY, LPCSTR, DWORD, LPSTR, DWORD, REGSAM,
          LPSECURITY_ATTRIBUTES, PHKEY, LPDWORD, HANDLE, PVOID);
        LONG RegCreateKeyTransactedW(const scope HKEY, LPCWSTR, DWORD, LPWSTR, DWORD, REGSAM,
          LPSECURITY_ATTRIBUTES, PHKEY, LPDWORD, HANDLE, PVOID);
        LONG RegDeleteKeyTransactedA(const scope HKEY, LPCSTR, REGSAM, DWORD, HANDLE, PVOID);
        LONG RegDeleteKeyTransactedW(const scope HKEY, LPCWSTR, REGSAM, DWORD, HANDLE, PVOID);
        LONG RegDeleteKeyValueA(const scope HKEY, LPCSTR, LPCSTR);
        LONG RegDeleteKeyValueW(const scope HKEY, LPCWSTR, LPCWSTR);
        LONG RegDeleteTreeA(const scope HKEY, LPCSTR);
        LONG RegDeleteTreeW(const scope HKEY, LPCWSTR);
        LONG RegDisablePredefinedCacheEx();
        LONG RegLoadAppKeyA(LPCSTR, PHKEY, REGSAM, DWORD, DWORD);
        LONG RegLoadAppKeyW(LPCWSTR, PHKEY, REGSAM, DWORD, DWORD);
        LONG RegLoadMUIStringA(const scope HKEY, LPCSTR, LPSTR, DWORD, LPDWORD, DWORD, LPCSTR);
        LONG RegLoadMUIStringW(const scope HKEY, LPCWSTR, LPWSTR, DWORD, LPDWORD, DWORD, LPCWSTR);
        LONG RegOpenKeyTransactedA(const scope HKEY, LPCSTR, DWORD, REGSAM, PHKEY, HANDLE, PVOID);
        LONG RegOpenKeyTransactedW(const scope HKEY, LPCWSTR, DWORD, REGSAM, PHKEY, HANDLE, PVOID);
        LONG RegRenameKey(const scope HKEY, LPCWSTR, LPCWSTR);
        LONG RegSetKeyValueA(const scope HKEY, LPCSTR, LPCSTR, DWORD, LPCVOID, DWORD);
        LONG RegSetKeyValueW(const scope HKEY, LPCWSTR, LPCWSTR, DWORD, LPCVOID, DWORD);
        DWORD InitiateShutdownA(LPSTR, LPSTR, DWORD, DWORD, DWORD);
        DWORD InitiateShutdownW(LPWSTR, LPWSTR, DWORD, DWORD, DWORD);
    }

    static if (_WIN32_WINNT >= 0x602) {
        DWORD CheckForHiberboot(PBOOLEAN, BOOLEAN);
    }

    //deprecated {
        LONG RegCreateKeyA(const scope HKEY, LPCSTR, PHKEY);
        LONG RegCreateKeyW(const scope HKEY, LPCWSTR, PHKEY);
        LONG RegEnumKeyA(const scope HKEY, DWORD, LPSTR, DWORD);
        LONG RegEnumKeyW(const scope HKEY, DWORD, LPWSTR, DWORD);
        LONG RegOpenKeyA(const scope HKEY, LPCSTR, PHKEY);
        LONG RegOpenKeyW(const scope HKEY, LPCWSTR, PHKEY);
        LONG RegQueryValueA(const scope HKEY, LPCSTR, LPSTR, PLONG);
        LONG RegQueryValueW(const scope HKEY, LPCWSTR, LPWSTR, PLONG);
        LONG RegSetValueA(const scope HKEY, LPCSTR, DWORD, LPCSTR, DWORD);
        LONG RegSetValueW(const scope HKEY, LPCWSTR, DWORD, LPCWSTR, DWORD);
    //}
}

version (Unicode) {
    alias VALENT = VALENTW;
    alias RegConnectRegistry = RegConnectRegistryW;
    alias RegCreateKeyEx = RegCreateKeyExW;
    alias RegDeleteKey = RegDeleteKeyW;
    alias RegDeleteValue = RegDeleteValueW;
    alias RegEnumKeyEx = RegEnumKeyExW;
    alias RegEnumValue = RegEnumValueW;
    alias RegLoadKey = RegLoadKeyW;
    alias RegOpenKeyEx = RegOpenKeyExW;
    alias RegQueryInfoKey = RegQueryInfoKeyW;
    alias RegQueryMultipleValues = RegQueryMultipleValuesW;
    alias RegQueryValueEx = RegQueryValueExW;
    alias RegReplaceKey = RegReplaceKeyW;
    alias RegSaveKey = RegSaveKeyW;
    alias RegSetValueEx = RegSetValueExW;
    alias RegUnLoadKey = RegUnLoadKeyW;

    alias AbortSystemShutdown = AbortSystemShutdownW;
    alias InitiateSystemShutdown = InitiateSystemShutdownW;
    alias RegRestoreKey = RegRestoreKeyW;
    alias RegConnectRegistryEx = RegConnectRegistryExW;
    alias PVALUE = PVALUEW;
    static if (_WIN32_WINNT >= 0x501) {
        alias RegSaveKeyEx = RegSaveKeyExW;
        alias InitiateSystemShutdownEx = InitiateSystemShutdownExW;
    }
    static if (_WIN32_WINNT >= 0x502) {
        alias RegGetValue = RegGetValueW;
        alias RegDeleteKeyEx = RegDeleteKeyExW;
    }
    static if (_WIN32_WINNT >= 0x600) {
        alias RegCopyTree = RegCopyTreeW;
        alias RegCreateKeyTransacted = RegCreateKeyTransactedW;
        alias RegDeleteKeyTransacted = RegDeleteKeyTransactedW;
        alias RegDeleteKeyValue = RegDeleteKeyValueW;
        alias RegDeleteTree = RegDeleteTreeW;
        alias RegLoadAppKey = RegLoadAppKeyW;
        alias RegLoadMUIString = RegLoadMUIStringW;
        alias RegOpenKeyTransacted = RegOpenKeyTransactedW;
        alias RegSetKeyValue = RegSetKeyValueW;
        alias InitiateShutdown = InitiateShutdownW;
    }
    //deprecated {
        alias RegCreateKey = RegCreateKeyW;
        alias RegEnumKey = RegEnumKeyW;
        alias RegOpenKey = RegOpenKeyW;
        alias RegQueryValue = RegQueryValueW;
        alias RegSetValue = RegSetValueW;
    //}
} else {
    alias VALENT = VALENTA;
    alias RegConnectRegistry = RegConnectRegistryA;
    alias RegCreateKeyEx = RegCreateKeyExA;
    alias RegDeleteKey = RegDeleteKeyA;
    alias RegDeleteValue = RegDeleteValueA;
    alias RegEnumKeyEx = RegEnumKeyExA;
    alias RegEnumValue = RegEnumValueA;
    alias RegLoadKey = RegLoadKeyA;
    alias RegOpenKeyEx = RegOpenKeyExA;
    alias RegQueryInfoKey = RegQueryInfoKeyA;
    alias RegQueryMultipleValues = RegQueryMultipleValuesA;
    alias RegQueryValueEx = RegQueryValueExA;
    alias RegReplaceKey = RegReplaceKeyA;
    alias RegSaveKey = RegSaveKeyA;
    alias RegSetValueEx = RegSetValueExA;
    alias RegUnLoadKey = RegUnLoadKeyA;
    alias AbortSystemShutdown = AbortSystemShutdownA;
    alias InitiateSystemShutdown = InitiateSystemShutdownA;
    alias RegRestoreKey = RegRestoreKeyA;
    alias RegConnectRegistryEx = RegConnectRegistryExA;
    alias PVALUE = PVALUEA;
    static if (_WIN32_WINNT >= 0x501) {
        alias RegSaveKeyEx = RegSaveKeyExA;
        alias InitiateSystemShutdownEx = InitiateSystemShutdownExA;
    }
    static if (_WIN32_WINNT >= 0x502) {
        alias RegGetValue = RegGetValueA;
        alias RegDeleteKeyEx = RegDeleteKeyExA;
    }
    static if (_WIN32_WINNT >= 0x600) {
        alias RegCopyTree = RegCopyTreeA;
        alias RegCreateKeyTransacted = RegCreateKeyTransactedA;
        alias RegDeleteKeyTransacted = RegDeleteKeyTransactedA;
        alias RegDeleteKeyValue = RegDeleteKeyValueA;
        alias RegDeleteTree = RegDeleteTreeA;
        alias RegLoadAppKey = RegLoadAppKeyA;
        alias RegLoadMUIString = RegLoadMUIStringA;
        alias RegOpenKeyTransacted = RegOpenKeyTransactedA;
        alias RegSetKeyValue = RegSetKeyValueA;
        alias InitiateShutdown = InitiateShutdownA;
    }
    //deprecated {
        alias RegCreateKey = RegCreateKeyA;
        alias RegEnumKey = RegEnumKeyA;
        alias RegOpenKey = RegOpenKeyA;
        alias RegQueryValue = RegQueryValueA;
        alias RegSetValue = RegSetValueA;
    //}
}

alias PVALENT = VALENT*;
alias PPVALUE = PVALUE*;
