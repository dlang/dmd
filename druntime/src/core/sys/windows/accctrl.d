/**
 * Windows API header module
 *
 * Translated from MinGW Windows headers
 *
 * Authors: Stewart Gordon
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source: $(DRUNTIMESRC core/sys/windows/_accctrl.d)
 */
module core.sys.windows.accctrl;
version (Windows):

version (ANSI) {} else version = Unicode;

import core.sys.windows.basetyps, core.sys.windows.w32api, core.sys.windows.winbase, core.sys.windows.windef;

// FIXME: check types and grouping of constants
// FIXME: check Windows version support

alias AccFree = LocalFree;

enum uint
    ACTRL_RESERVED            = 0x00000000,
    ACTRL_ACCESS_PROTECTED    = 0x00000001,
    ACTRL_ACCESS_ALLOWED      = 0x00000001,
    ACTRL_ACCESS_DENIED       = 0x00000002,
    ACTRL_AUDIT_SUCCESS       = 0x00000004,
    ACTRL_AUDIT_FAILURE       = 0x00000008,
    ACTRL_SYSTEM_ACCESS       = 0x04000000,
    ACTRL_DELETE              = 0x08000000,
    ACTRL_READ_CONTROL        = 0x10000000,
    ACTRL_CHANGE_ACCESS       = 0x20000000,
    ACTRL_CHANGE_OWNER        = 0x40000000,
    ACTRL_SYNCHRONIZE         = 0x80000000,
    ACTRL_STD_RIGHTS_ALL      = 0xf8000000;

enum uint
    ACTRL_FILE_READ           = 0x00000001,
    ACTRL_FILE_WRITE          = 0x00000002,
    ACTRL_FILE_APPEND         = 0x00000004,
    ACTRL_FILE_READ_PROP      = 0x00000008,
    ACTRL_FILE_WRITE_PROP     = 0x00000010,
    ACTRL_FILE_EXECUTE        = 0x00000020,
    ACTRL_FILE_READ_ATTRIB    = 0x00000080,
    ACTRL_FILE_WRITE_ATTRIB   = 0x00000100,
    ACTRL_FILE_CREATE_PIPE    = 0x00000200;

enum uint
    ACTRL_DIR_LIST            = 0x00000001,
    ACTRL_DIR_CREATE_OBJECT   = 0x00000002,
    ACTRL_DIR_CREATE_CHILD    = 0x00000004,
    ACTRL_DIR_DELETE_CHILD    = 0x00000040,
    ACTRL_DIR_TRAVERSE        = 0x00000020;

enum uint
    ACTRL_KERNEL_TERMINATE    = 0x00000001,
    ACTRL_KERNEL_THREAD       = 0x00000002,
    ACTRL_KERNEL_VM           = 0x00000004,
    ACTRL_KERNEL_VM_READ      = 0x00000008,
    ACTRL_KERNEL_VM_WRITE     = 0x00000010,
    ACTRL_KERNEL_DUP_HANDLE   = 0x00000020,
    ACTRL_KERNEL_PROCESS      = 0x00000040,
    ACTRL_KERNEL_SET_INFO     = 0x00000080,
    ACTRL_KERNEL_GET_INFO     = 0x00000100,
    ACTRL_KERNEL_CONTROL      = 0x00000200,
    ACTRL_KERNEL_ALERT        = 0x00000400,
    ACTRL_KERNEL_GET_CONTEXT  = 0x00000800,
    ACTRL_KERNEL_SET_CONTEXT  = 0x00001000,
    ACTRL_KERNEL_TOKEN        = 0x00002000,
    ACTRL_KERNEL_IMPERSONATE  = 0x00004000,
    ACTRL_KERNEL_DIMPERSONATE = 0x00008000;

enum uint
    ACTRL_PRINT_SADMIN        = 0x00000001,
    ACTRL_PRINT_SLIST         = 0x00000002,
    ACTRL_PRINT_PADMIN        = 0x00000004,
    ACTRL_PRINT_PUSE          = 0x00000008,
    ACTRL_PRINT_JADMIN        = 0x00000010;

enum uint
    ACTRL_SVC_GET_INFO        = 0x00000001,
    ACTRL_SVC_SET_INFO        = 0x00000002,
    ACTRL_SVC_STATUS          = 0x00000004,
    ACTRL_SVC_LIST            = 0x00000008,
    ACTRL_SVC_START           = 0x00000010,
    ACTRL_SVC_STOP            = 0x00000020,
    ACTRL_SVC_PAUSE           = 0x00000040,
    ACTRL_SVC_INTERROGATE     = 0x00000080,
    ACTRL_SVC_UCONTROL        = 0x00000100;

enum uint
    ACTRL_REG_QUERY           = 0x00000001,
    ACTRL_REG_SET             = 0x00000002,
    ACTRL_REG_CREATE_CHILD    = 0x00000004,
    ACTRL_REG_LIST            = 0x00000008,
    ACTRL_REG_NOTIFY          = 0x00000010,
    ACTRL_REG_LINK            = 0x00000020;

enum uint
    ACTRL_WIN_CLIPBRD         = 0x00000001,
    ACTRL_WIN_GLOBAL_ATOMS    = 0x00000002,
    ACTRL_WIN_CREATE          = 0x00000004,
    ACTRL_WIN_LIST_DESK       = 0x00000008,
    ACTRL_WIN_LIST            = 0x00000010,
    ACTRL_WIN_READ_ATTRIBS    = 0x00000020,
    ACTRL_WIN_WRITE_ATTRIBS   = 0x00000040,
    ACTRL_WIN_SCREEN          = 0x00000080,
    ACTRL_WIN_EXIT            = 0x00000100;

enum : uint {
    ACTRL_ACCESS_NO_OPTIONS              = 0x00000000,
    ACTRL_ACCESS_SUPPORTS_OBJECT_ENTRIES = 0x00000001
}

const TCHAR[] ACCCTRL_DEFAULT_PROVIDER = "Windows NT Access Provider";

enum uint
    TRUSTEE_ACCESS_ALLOWED    = 0x00000001,
    TRUSTEE_ACCESS_READ       = 0x00000002,
    TRUSTEE_ACCESS_WRITE      = 0x00000004,
    TRUSTEE_ACCESS_EXPLICIT   = 0x00000001,
    TRUSTEE_ACCESS_READ_WRITE = 0x00000006,
    TRUSTEE_ACCESS_ALL        = 0xFFFFFFFF;

enum uint
    NO_INHERITANCE                     = 0x0,
    SUB_OBJECTS_ONLY_INHERIT           = 0x1,
    SUB_CONTAINERS_ONLY_INHERIT        = 0x2,
    SUB_CONTAINERS_AND_OBJECTS_INHERIT = 0x3,
    INHERIT_NO_PROPAGATE               = 0x4,
    INHERIT_ONLY                       = 0x8,
    INHERITED_ACCESS_ENTRY             = 0x10,
    INHERITED_PARENT                   = 0x10000000,
    INHERITED_GRANDPARENT              = 0x20000000;

alias INHERIT_FLAGS = ULONG, ACCESS_RIGHTS = ULONG;
alias PINHERIT_FLAGS = ULONG*, PACCESS_RIGHTS = ULONG*;

enum ACCESS_MODE {
    NOT_USED_ACCESS,
    GRANT_ACCESS,
    SET_ACCESS,
    DENY_ACCESS,
    REVOKE_ACCESS,
    SET_AUDIT_SUCCESS,
    SET_AUDIT_FAILURE
}

enum SE_OBJECT_TYPE {
    SE_UNKNOWN_OBJECT_TYPE,
    SE_FILE_OBJECT,
    SE_SERVICE,
    SE_PRINTER,
    SE_REGISTRY_KEY,
    SE_LMSHARE,
    SE_KERNEL_OBJECT,
    SE_WINDOW_OBJECT,
    SE_DS_OBJECT,
    SE_DS_OBJECT_ALL,
    SE_PROVIDER_DEFINED_OBJECT,
    SE_WMIGUID_OBJECT,
    SE_REGISTRY_WOW64_32KEY
}

enum TRUSTEE_TYPE {
    TRUSTEE_IS_UNKNOWN,
    TRUSTEE_IS_USER,
    TRUSTEE_IS_GROUP,
    TRUSTEE_IS_DOMAIN,
    TRUSTEE_IS_ALIAS,
    TRUSTEE_IS_WELL_KNOWN_GROUP,
    TRUSTEE_IS_DELETED,
    TRUSTEE_IS_INVALID,
    TRUSTEE_IS_COMPUTER
}

enum TRUSTEE_FORM {
    TRUSTEE_IS_SID,
    TRUSTEE_IS_NAME,
    TRUSTEE_BAD_FORM,
    TRUSTEE_IS_OBJECTS_AND_SID,
    TRUSTEE_IS_OBJECTS_AND_NAME
}

enum MULTIPLE_TRUSTEE_OPERATION {
    NO_MULTIPLE_TRUSTEE,
    TRUSTEE_IS_IMPERSONATE
}

struct TRUSTEE_A {
    TRUSTEE_A*                 pMultipleTrustee;
    MULTIPLE_TRUSTEE_OPERATION MultipleTrusteeOperation;
    TRUSTEE_FORM               TrusteeForm;
    TRUSTEE_TYPE               TrusteeType;
    LPSTR                      ptstrName;
}
alias TRUSTEEA = TRUSTEE_A;
alias PTRUSTEE_A = TRUSTEE_A*, PTRUSTEEA = TRUSTEE_A*;

struct TRUSTEE_W {
    TRUSTEE_W*                 pMultipleTrustee;
    MULTIPLE_TRUSTEE_OPERATION MultipleTrusteeOperation;
    TRUSTEE_FORM               TrusteeForm;
    TRUSTEE_TYPE               TrusteeType;
    LPWSTR                     ptstrName;
}
alias TRUSTEEW = TRUSTEE_W;
alias PTRUSTEE_W = TRUSTEEW*, PTRUSTEEW = TRUSTEEW*;

struct ACTRL_ACCESS_ENTRYA {
    TRUSTEE_A     Trustee;
    ULONG         fAccessFlags;
    ACCESS_RIGHTS Access;
    ACCESS_RIGHTS ProvSpecificAccess;
    INHERIT_FLAGS Inheritance;
    LPCSTR        lpInheritProperty;
}
alias PACTRL_ACCESS_ENTRYA = ACTRL_ACCESS_ENTRYA*;

struct ACTRL_ACCESS_ENTRYW {
    TRUSTEE_W     Trustee;
    ULONG         fAccessFlags;
    ACCESS_RIGHTS Access;
    ACCESS_RIGHTS ProvSpecificAccess;
    INHERIT_FLAGS Inheritance;
    LPCWSTR       lpInheritProperty;
}
alias PACTRL_ACCESS_ENTRYW = ACTRL_ACCESS_ENTRYW*;

struct ACTRL_ACCESS_ENTRY_LISTA {
    ULONG                cEntries;
    ACTRL_ACCESS_ENTRYA* pAccessList;
}
alias PACTRL_ACCESS_ENTRY_LISTA = ACTRL_ACCESS_ENTRY_LISTA*;

struct ACTRL_ACCESS_ENTRY_LISTW {
    ULONG                cEntries;
    ACTRL_ACCESS_ENTRYW* pAccessList;
}
alias PACTRL_ACCESS_ENTRY_LISTW = ACTRL_ACCESS_ENTRY_LISTW*;

struct ACTRL_PROPERTY_ENTRYA {
    LPCSTR                    lpProperty;
    PACTRL_ACCESS_ENTRY_LISTA pAccessEntryList;
    ULONG                     fListFlags;
}
alias PACTRL_PROPERTY_ENTRYA = ACTRL_PROPERTY_ENTRYA*;

struct ACTRL_PROPERTY_ENTRYW {
    LPCWSTR                   lpProperty;
    PACTRL_ACCESS_ENTRY_LISTW pAccessEntryList;
    ULONG                     fListFlags;
}
alias PACTRL_PROPERTY_ENTRYW = ACTRL_PROPERTY_ENTRYW*;

struct ACTRL_ACCESSA {
    ULONG                  cEntries;
    PACTRL_PROPERTY_ENTRYA pPropertyAccessList;
}
alias ACTRL_AUDITA = ACTRL_ACCESSA;
alias PACTRL_ACCESSA = ACTRL_ACCESSA*, PACTRL_AUDITA = ACTRL_ACCESSA*;

struct ACTRL_ACCESSW {
    ULONG                  cEntries;
    PACTRL_PROPERTY_ENTRYW pPropertyAccessList;
}
alias ACTRL_AUDITW = ACTRL_ACCESSW;
alias PACTRL_ACCESSW = ACTRL_ACCESSW*, PACTRL_AUDITW = ACTRL_ACCESSW*;

struct TRUSTEE_ACCESSA {
    LPSTR         lpProperty;
    ACCESS_RIGHTS Access;
    ULONG         fAccessFlags;
    ULONG         fReturnedAccess;
}
alias PTRUSTEE_ACCESSA = TRUSTEE_ACCESSA*;

struct TRUSTEE_ACCESSW {
    LPWSTR        lpProperty;
    ACCESS_RIGHTS Access;
    ULONG         fAccessFlags;
    ULONG         fReturnedAccess;
}
alias PTRUSTEE_ACCESSW = TRUSTEE_ACCESSW*;

struct ACTRL_OVERLAPPED {
    union {
        PVOID Provider;
        ULONG Reserved1;
    }
    ULONG     Reserved2;
    HANDLE    hEvent;
}
alias PACTRL_OVERLAPPED = ACTRL_OVERLAPPED*;

struct ACTRL_ACCESS_INFOA {
    ULONG fAccessPermission;
    LPSTR lpAccessPermissionName;
}
alias PACTRL_ACCESS_INFOA = ACTRL_ACCESS_INFOA*;

struct ACTRL_ACCESS_INFOW {
    ULONG  fAccessPermission;
    LPWSTR lpAccessPermissionName;
}
alias PACTRL_ACCESS_INFOW = ACTRL_ACCESS_INFOW*;

struct ACTRL_CONTROL_INFOA {
    LPSTR lpControlId;
    LPSTR lpControlName;
}
alias PACTRL_CONTROL_INFOA = ACTRL_CONTROL_INFOA*;

struct ACTRL_CONTROL_INFOW {
    LPWSTR lpControlId;
    LPWSTR lpControlName;
}
alias PACTRL_CONTROL_INFOW = ACTRL_CONTROL_INFOW*;

struct EXPLICIT_ACCESS_A {
    DWORD       grfAccessPermissions;
    ACCESS_MODE grfAccessMode;
    DWORD       grfInheritance;
    TRUSTEE_A   Trustee;
}
alias EXPLICIT_ACCESSA = EXPLICIT_ACCESS_A;
alias PEXPLICIT_ACCESS_A = EXPLICIT_ACCESS_A*, PEXPLICIT_ACCESSA = EXPLICIT_ACCESS_A*;

struct EXPLICIT_ACCESS_W {
    DWORD       grfAccessPermissions;
    ACCESS_MODE grfAccessMode;
    DWORD       grfInheritance;
    TRUSTEE_W   Trustee;
}
alias EXPLICIT_ACCESSW = EXPLICIT_ACCESS_W;
alias PEXPLICIT_ACCESS_W = EXPLICIT_ACCESS_W*, PEXPLICIT_ACCESSW = EXPLICIT_ACCESS_W*;

struct OBJECTS_AND_SID {
    DWORD ObjectsPresent;
    GUID  ObjectTypeGuid;
    GUID  InheritedObjectTypeGuid;
    SID*  pSid;
}
alias POBJECTS_AND_SID = OBJECTS_AND_SID*;

struct OBJECTS_AND_NAME_A {
    DWORD          ObjectsPresent;
    SE_OBJECT_TYPE ObjectType;
    LPSTR          ObjectTypeName;
    LPSTR          InheritedObjectTypeName;
    LPSTR          ptstrName;
}
alias POBJECTS_AND_NAME_A = OBJECTS_AND_NAME_A*;

struct OBJECTS_AND_NAME_W {
    DWORD          ObjectsPresent;
    SE_OBJECT_TYPE ObjectType;
    LPWSTR         ObjectTypeName;
    LPWSTR         InheritedObjectTypeName;
    LPWSTR         ptstrName;
}
alias POBJECTS_AND_NAME_W = OBJECTS_AND_NAME_W*;

static if (_WIN32_WINNT >= 0x501) {
    struct INHERITED_FROMA {
        LONG  GenerationGap;
        LPSTR AncestorName;
    }
    alias PINHERITED_FROMA = INHERITED_FROMA*;

    struct INHERITED_FROMW {
        LONG   GenerationGap;
        LPWSTR AncestorName;
    }
    alias PINHERITED_FROMW = INHERITED_FROMW*;
}

version (Unicode) {
    alias TRUSTEE = TRUSTEEW;
    alias ACTRL_ACCESS = ACTRL_ACCESSW;
    alias ACTRL_ACCESS_ENTRY_LIST = ACTRL_ACCESS_ENTRY_LISTW;
    alias ACTRL_ACCESS_INFO = ACTRL_ACCESS_INFOW;
    alias ACTRL_ACCESS_ENTRY = ACTRL_ACCESS_ENTRYW;
    alias ACTRL_AUDIT = ACTRL_AUDITW;
    alias ACTRL_CONTROL_INFO = ACTRL_CONTROL_INFOW;
    alias EXPLICIT_ACCESS = EXPLICIT_ACCESSW;
    alias TRUSTEE_ACCESS = TRUSTEE_ACCESSW;
    alias OBJECTS_AND_NAME_ = OBJECTS_AND_NAME_W;
    static if (_WIN32_WINNT >= 0x501) {
        alias INHERITED_FROM = INHERITED_FROMW;
    }
} else {
    alias TRUSTEE = TRUSTEEA;
    alias ACTRL_ACCESS = ACTRL_ACCESSA;
    alias ACTRL_ACCESS_ENTRY_LIST = ACTRL_ACCESS_ENTRY_LISTA;
    alias ACTRL_ACCESS_INFO = ACTRL_ACCESS_INFOA;
    alias ACTRL_ACCESS_ENTRY = ACTRL_ACCESS_ENTRYA;
    alias ACTRL_AUDIT = ACTRL_AUDITA;
    alias ACTRL_CONTROL_INFO = ACTRL_CONTROL_INFOA;
    alias EXPLICIT_ACCESS = EXPLICIT_ACCESSA;
    alias TRUSTEE_ACCESS = TRUSTEE_ACCESSA;
    alias OBJECTS_AND_NAME_ = OBJECTS_AND_NAME_A;
    static if (_WIN32_WINNT >= 0x501) {
        alias INHERITED_FROM = INHERITED_FROMA;
    }
}

alias TRUSTEE_ = TRUSTEE;
alias PTRUSTEE = TRUSTEE*, PTRUSTEE_ = TRUSTEE*;
alias PACTRL_ACCESS = ACTRL_ACCESS*;
alias PACTRL_ACCESS_ENTRY_LIST = ACTRL_ACCESS_ENTRY_LIST*;
alias PACTRL_ACCESS_INFO = ACTRL_ACCESS_INFO*;
alias PACTRL_ACCESS_ENTRY = ACTRL_ACCESS_ENTRY*;
alias PACTRL_AUDIT = ACTRL_AUDIT*;
alias PACTRL_CONTROL_INFO = ACTRL_CONTROL_INFO*;
alias EXPLICIT_ACCESS_ = EXPLICIT_ACCESS;
alias PEXPLICIT_ACCESS = EXPLICIT_ACCESS*, PEXPLICIT_ACCESS_ = EXPLICIT_ACCESS*;
alias PTRUSTEE_ACCESS = TRUSTEE_ACCESS*;
alias POBJECTS_AND_NAME_ = OBJECTS_AND_NAME_*;
static if (_WIN32_WINNT >= 0x501) {
    alias PINHERITED_FROM = INHERITED_FROM*;
}
