/**
 * Windows API header module
 *
 * Translated from Windows headers
 *
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source: ...\Windows Kits\10\Include\10.0.26100.0\um\dpapi.h
 */
module core.sys.windows.dpapi;

version (Windows):
extern (Windows):
@nogc:
nothrow:

public import core.sys.windows.windef : BOOL, BYTE, DWORD, HWND;
public import core.sys.windows.winnt : LPCWSTR, LPVOID, LPWSTR, PSID, PVOID;

pragma(lib, "Crypt32");

struct _CRYPTOAPI_BLOB
{
    DWORD cbData;
    BYTE* pbData; // _Field_size_bytes_
}
alias CRYPT_INTEGER_BLOB = _CRYPTOAPI_BLOB;
alias PCRYPT_INTEGER_BLOB = _CRYPTOAPI_BLOB*;
alias CRYPT_UINT_BLOB = _CRYPTOAPI_BLOB;
alias PCRYPT_UINT_BLOB = _CRYPTOAPI_BLOB*;
alias CRYPT_OBJID_BLOB = _CRYPTOAPI_BLOB;
alias PCRYPT_OBJID_BLOB = _CRYPTOAPI_BLOB*;
alias CERT_NAME_BLOB = _CRYPTOAPI_BLOB;
alias PCERT_NAME_BLOB = _CRYPTOAPI_BLOB*;
alias CERT_RDN_VALUE_BLOB = _CRYPTOAPI_BLOB;
alias PCERT_RDN_VALUE_BLOB = _CRYPTOAPI_BLOB*;
alias CERT_BLOB = _CRYPTOAPI_BLOB;
alias PCERT_BLOB = _CRYPTOAPI_BLOB*;
alias CRL_BLOB = _CRYPTOAPI_BLOB;
alias PCRL_BLOB = _CRYPTOAPI_BLOB*;
alias DATA_BLOB = _CRYPTOAPI_BLOB;
alias PDATA_BLOB = _CRYPTOAPI_BLOB*;
alias CRYPT_DATA_BLOB = _CRYPTOAPI_BLOB;
alias PCRYPT_DATA_BLOB = _CRYPTOAPI_BLOB*;
alias CRYPT_HASH_BLOB = _CRYPTOAPI_BLOB;
alias PCRYPT_HASH_BLOB = _CRYPTOAPI_BLOB*;
alias CRYPT_DIGEST_BLOB = _CRYPTOAPI_BLOB;
alias PCRYPT_DIGEST_BLOB = _CRYPTOAPI_BLOB*;
alias CRYPT_DER_BLOB = _CRYPTOAPI_BLOB;
alias PCRYPT_DER_BLOB = _CRYPTOAPI_BLOB*;
alias CRYPT_ATTR_BLOB = _CRYPTOAPI_BLOB;
alias PCRYPT_ATTR_BLOB = _CRYPTOAPI_BLOB*;


//
// Registry value for controlling Data Protection API (DPAPI) UI settings.
//

static immutable string szFORCE_KEY_PROTECTION = "ForceKeyProtection";

enum dwFORCE_KEY_PROTECTION_DISABLED = 0x0;
enum dwFORCE_KEY_PROTECTION_USER_SELECT = 0x1;
enum dwFORCE_KEY_PROTECTION_HIGH = 0x2;

//
// Data protection APIs enable applications to easily secure data.
//
// The base provider provides protection based on the users' logon
// credentials. The data secured with these APIs follow the same
// roaming characteristics as HKCU -- if HKCU roams, the data
// protected by the base provider may roam as well. This makes
// the API ideal for the munging of data stored in the registry.
//

//
// Prompt struct -- what to tell users about the access
//
struct _CRYPTPROTECT_PROMPTSTRUCT
{
    DWORD cbSize;
    DWORD dwPromptFlags;
    HWND  hwndApp;
    LPCWSTR szPrompt;
}
alias CRYPTPROTECT_PROMPTSTRUCT = _CRYPTPROTECT_PROMPTSTRUCT;
alias PCRYPTPROTECT_PROMPTSTRUCT = _CRYPTPROTECT_PROMPTSTRUCT*;

//
// base provider action
//
import core.sys.windows.basetyps : GUID;
enum GUID CRYPTPROTECT_DEFAULT_PROVIDER = {0xdf9d8cd0, 0x1501, 0x11d1, [0x8c, 0x7a, 0x00, 0xc0, 0x4f, 0xc2, 0x97, 0xeb]};

//
// CryptProtect PromptStruct dwPromtFlags
//

// prompt on unprotect
enum CRYPTPROTECT_PROMPT_ON_UNPROTECT = 0x1;  // 1<<0

// prompt on protect
enum CRYPTPROTECT_PROMPT_ON_PROTECT = 0x2;  // 1<<1
enum CRYPTPROTECT_PROMPT_RESERVED = 0x04; // reserved, do not use.

// default to strong variant UI protection (user supplied password currently).
enum CRYPTPROTECT_PROMPT_STRONG = 0x08; // 1<<3

// require strong variant UI protection (user supplied password currently).
enum CRYPTPROTECT_PROMPT_REQUIRE_STRONG = 0x10; // 1<<4

//
// CryptProtectData and CryptUnprotectData dwFlags
//

// for remote-access situations where ui is not an option
// if UI was specified on protect or unprotect operation, the call
// will fail and GetLastError() will indicate ERROR_PASSWORD_RESTRICTION
enum CRYPTPROTECT_UI_FORBIDDEN = 0x1;

// per machine protected data -- any user on machine where CryptProtectData
// took place may CryptUnprotectData
enum CRYPTPROTECT_LOCAL_MACHINE = 0x4;

// force credential synchronize during CryptProtectData()
// Synchronize is only operation that occurs during this operation
enum CRYPTPROTECT_CRED_SYNC = 0x8;

//
// Generate an Audit on protect and unprotect operations
//
enum CRYPTPROTECT_AUDIT = 0x10;

//
// Protect data with a non-recoverable key
//
enum CRYPTPROTECT_NO_RECOVERY = 0x20;

//
// Verify the protection of a protected blob
//
enum CRYPTPROTECT_VERIFY_PROTECTION = 0x40;

//
// Regenerate the local machine protection
//
enum CRYPTPROTECT_CRED_REGENERATE = 0x80;

// flags reserved for system use
enum CRYPTPROTECT_FIRST_RESERVED_FLAGVAL = 0x0FFFFFFF;
enum CRYPTPROTECT_LAST_RESERVED_FLAGVAL = 0xFFFFFFFF;


BOOL CryptProtectData(
    scope DATA_BLOB*      pDataIn,                   // _In_
    scope LPCWSTR         szDataDescr,               // _In_opt_
    scope DATA_BLOB*      pOptionalEntropy,          // _In_opt_
    PVOID                 pvReserved,                // _Reserved_
    scope CRYPTPROTECT_PROMPTSTRUCT*  pPromptStruct, // _In_opt_
    DWORD                 dwFlags,                   // _In_
    DATA_BLOB*            pDataOut                   // _Out_           out encr blob
    );

BOOL CryptUnprotectData(
    scope DATA_BLOB*      pDataIn,                   // _In_            in encr blob
    LPWSTR*               ppszDataDescr,             // _Outptr_opt_result_maybenull_  out
    scope DATA_BLOB*      pOptionalEntropy,          // _In_opt_
    PVOID                 pvReserved,                // _Reserved_
    scope CRYPTPROTECT_PROMPTSTRUCT*  pPromptStruct, // _In_opt_
    DWORD                 dwFlags,                   // _In_
    DATA_BLOB*            pDataOut                   // _Out_
    );

//#if (NTDDI_VERSION >= NTDDI_WIN8)
BOOL CryptProtectDataNoUI(
    scope DATA_BLOB*      pDataIn,                   // _In_
    LPCWSTR               szDataDescr,               // _In_opt_
    scope DATA_BLOB*      pOptionalEntropy,          // _In_opt_
    PVOID                 pvReserved,                // _Reserved_
    scope CRYPTPROTECT_PROMPTSTRUCT*  pPromptStruct, // _In_opt_
    DWORD                 dwFlags,                   // _In_
    scope const BYTE*     pbOptionalPassword,        // _In_reads_bytes_opt_(cbOptionalPassword)
    DWORD                 cbOptionalPassword,
    DATA_BLOB*            pDataOut                   // _Out_           out encr blob
    );

//#if (NTDDI_VERSION >= NTDDI_WIN8)
BOOL CryptUnprotectDataNoUI(
    scope DATA_BLOB*      pDataIn,                   // _In_            in encr blob
    LPWSTR*               ppszDataDescr,             // _Outptr_opt_result_maybenull_  out
    scope DATA_BLOB*      pOptionalEntropy,          // _In_opt_
    PVOID                 pvReserved,                // _Reserved_
    scope CRYPTPROTECT_PROMPTSTRUCT*  pPromptStruct, // _In_opt_
    DWORD                 dwFlags,                   // _In_
    scope const BYTE*     pbOptionalPassword,        // _In_reads_bytes_opt_(cbOptionalPassword)
    DWORD                 cbOptionalPassword,
    DATA_BLOB*            pDataOut                   // _Out_
    );

//#if (NTDDI_VERSION >= NTDDI_VISTA)
BOOL CryptUpdateProtectedState(
    scope PSID    pOldSid,          // _In_opt_
    scope LPCWSTR pwszOldPassword,  // _In_opt_
    DWORD         dwFlags,          // _In_
    DWORD*        pdwSuccessCount,  // _Out_opt_
    DWORD*        pdwFailureCount   // _Out_opt_
    );


//
// The buffer length passed into CryptProtectMemory and CryptUnprotectMemory
// must be a multiple of this length (or zero).
//
enum CRYPTPROTECTMEMORY_BLOCK_SIZE = 16;


//
// CryptProtectMemory/CryptUnprotectMemory dwFlags
//

//
// Encrypt/Decrypt within current process context.
//
enum CRYPTPROTECTMEMORY_SAME_PROCESS = 0x00;

//
// Encrypt/Decrypt across process boundaries.
// eg: encrypted buffer passed across LPC to another process which calls CryptUnprotectMemory.
//
enum CRYPTPROTECTMEMORY_CROSS_PROCESS = 0x01;

//
// Encrypt/Decrypt across callers with same LogonId.
// eg: encrypted buffer passed across LPC to another process which calls CryptUnprotectMemory whilst impersonating.
//
enum CRYPTPROTECTMEMORY_SAME_LOGON = 0x02;

BOOL CryptProtectMemory(
    LPVOID pDataIn,             // _Inout_         in out data to encrypt
    DWORD  cbDataIn,            // _In_            multiple of CRYPTPROTECTMEMORY_BLOCK_SIZE
    DWORD  dwFlags              // _In_
    );

BOOL CryptUnprotectMemory(
    LPVOID pDataIn,             // _Inout_         in out data to decrypt
    DWORD  cbDataIn,            // _In_            multiple of CRYPTPROTECTMEMORY_BLOCK_SIZE
    DWORD  dwFlags              // _In_
    );
