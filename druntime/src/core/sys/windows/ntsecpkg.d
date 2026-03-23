/**
 * Windows API header module
 *
 * Translated from MinGW Windows headers
 *
 * Authors: Ellery Newcomer
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source: $(DRUNTIMESRC core/sys/windows/_ntsecpkg.d)
 */
module core.sys.windows.ntsecpkg;
version (Windows):

import core.sys.windows.windef, core.sys.windows.ntsecapi, core.sys.windows.security, core.sys.windows.ntdef, core.sys.windows.sspi;
import core.sys.windows.basetyps : GUID;
import core.sys.windows.winbase;

extern(Windows):

enum :ULONG{
    ISC_REQ_DELEGATE = 1,
    ISC_REQ_MUTUAL_AUTH = 2,
    ISC_REQ_REPLAY_DETECT = 4,
    ISC_REQ_SEQUENCE_DETECT = 8,
    ISC_REQ_CONFIDENTIALITY  = 16,
    ISC_REQ_USE_SESSION_KEY = 32,
    ISC_REQ_PROMPT_FOR_CREDS = 64,
    ISC_REQ_USE_SUPPLIED_CREDS  = 128,
    ISC_REQ_ALLOCATE_MEMORY = 256,
    ISC_REQ_USE_DCE_STYLE = 512,
    ISC_REQ_DATAGRAM = 1024,
    ISC_REQ_CONNECTION = 2048,
    ISC_REQ_EXTENDED_ERROR = 16384,
    ISC_REQ_STREAM = 32768,
    ISC_REQ_INTEGRITY = 65536,
    ISC_REQ_MANUAL_CRED_VALIDATION = 524288,
    ISC_REQ_HTTP  = 268435456,
}

enum ISC_RET_EXTENDED_ERROR = 16384;

enum :ULONG{
    ASC_REQ_DELEGATE = 1,
    ASC_REQ_MUTUAL_AUTH = 2,
    ASC_REQ_REPLAY_DETECT = 4,
    ASC_REQ_SEQUENCE_DETECT = 8,
    ASC_REQ_CONFIDENTIALITY = 16,
    ASC_REQ_USE_SESSION_KEY = 32,
    ASC_REQ_ALLOCATE_MEMORY = 256,
    ASC_REQ_USE_DCE_STYLE = 512,
    ASC_REQ_DATAGRAM = 1024,
    ASC_REQ_CONNECTION = 2048,
    ASC_REQ_EXTENDED_ERROR = 32768,
    ASC_REQ_STREAM = 65536,
    ASC_REQ_INTEGRITY = 131072,
}

enum SECURITY_NATIVE_DREP  = 16;
enum SECURITY_NETWORK_DREP = 0;

enum :ULONG{
    SECPKG_STATE_ENCRYPTION_PERMITTED               = 0x01,
    SECPKG_STATE_STRONG_ENCRYPTION_PERMITTED        = 0x02,
    SECPKG_STATE_DOMAIN_CONTROLLER                  = 0x04,
    SECPKG_STATE_WORKSTATION                        = 0x08,
    SECPKG_STATE_STANDALONE                         = 0x10,
}

/* enum definitions for Secure Service Provider/Authentication Packages */
enum LSA_TOKEN_INFORMATION_TYPE {
    LsaTokenInformationNull,
    LsaTokenInformationV1
}
alias PLSA_TOKEN_INFORMATION_TYPE = LSA_TOKEN_INFORMATION_TYPE*;
enum SECPKG_EXTENDED_INFORMATION_CLASS
{
    SecpkgGssInfo = 1,
    SecpkgContextThunks,
    SecpkgMutualAuthLevel,
    SecpkgMaxInfo
}
enum SECPKG_NAME_TYPE {
    SecNameSamCompatible,
    SecNameAlternateId,
    SecNameFlat,
    SecNameDN
}

/* struct definitions for SSP/AP */
struct SECPKG_PRIMARY_CRED {
    LUID LogonId;
    UNICODE_STRING DownlevelName;
    UNICODE_STRING DomainName;
    UNICODE_STRING Password;
    UNICODE_STRING OldPassword;
    PSID UserSid;
    ULONG Flags;
    UNICODE_STRING DnsDomainName;
    UNICODE_STRING Upn;
    UNICODE_STRING LogonServer;
    UNICODE_STRING Spare1;
    UNICODE_STRING Spare2;
    UNICODE_STRING Spare3;
    UNICODE_STRING Spare4;
}
alias PSECPKG_PRIMARY_CRED = SECPKG_PRIMARY_CRED*;
struct SECPKG_SUPPLEMENTAL_CRED {
    UNICODE_STRING PackageName;
    ULONG CredentialSize;
    PUCHAR Credentials;
}
alias PSECPKG_SUPPLEMENTAL_CRED = SECPKG_SUPPLEMENTAL_CRED*;
struct SECPKG_SUPPLEMENTAL_CRED_ARRAY {
    ULONG CredentialCount;
    SECPKG_SUPPLEMENTAL_CRED[1] Credentials;
}
alias PSECPKG_SUPPLEMENTAL_CRED_ARRAY = SECPKG_SUPPLEMENTAL_CRED_ARRAY*;
struct SECPKG_PARAMETERS {
    ULONG Version;
    ULONG MachineState;
    ULONG SetupMode;
    PSID DomainSid;
    UNICODE_STRING DomainName;
    UNICODE_STRING DnsDomainName;
    GUID DomainGuid;
}
alias PSECPKG_PARAMETERS = SECPKG_PARAMETERS*, PSECPKG_EVENT_DOMAIN_CHANGE = SECPKG_PARAMETERS*;
alias SECPKG_EVENT_DOMAIN_CHANGE = SECPKG_PARAMETERS;
struct SECPKG_CLIENT_INFO {
  LUID LogonId;
  ULONG ProcessID;
  ULONG ThreadID;
  BOOLEAN HasTcbPrivilege;
  BOOLEAN Impersonating;
  BOOLEAN Restricted;
}
alias PSECPKG_CLIENT_INFO = SECPKG_CLIENT_INFO*;
struct SECURITY_USER_DATA {
    SECURITY_STRING UserName;
    SECURITY_STRING LogonDomainName;
    SECURITY_STRING LogonServer;
    PSID pSid;
}
alias PSECURITY_USER_DATA = SECURITY_USER_DATA*, PSecurityUserData = SECURITY_USER_DATA*;
alias SecurityUserData = SECURITY_USER_DATA;
struct SECPKG_GSS_INFO {
    ULONG EncodedIdLength;
    UCHAR[4] EncodedId;
}
alias PSECPKG_GSS_INFO = SECPKG_GSS_INFO*;
struct SECPKG_CONTEXT_THUNKS {
    ULONG InfoLevelCount;
    ULONG[1] Levels;
}
alias PSECPKG_CONTEXT_THUNKS = SECPKG_CONTEXT_THUNKS*;
struct SECPKG_MUTUAL_AUTH_LEVEL {
    ULONG MutualAuthLevel;
}
alias PSECPKG_MUTUAL_AUTH_LEVEL = SECPKG_MUTUAL_AUTH_LEVEL*;
struct SECPKG_CALL_INFO {
    ULONG ProcessId;
    ULONG ThreadId;
    ULONG Attributes;
    ULONG CallCount;
}
alias PSECPKG_CALL_INFO = SECPKG_CALL_INFO*;
struct SECPKG_EXTENDED_INFORMATION {
    SECPKG_EXTENDED_INFORMATION_CLASS Class;
    union _Info{
        SECPKG_GSS_INFO GssInfo;
        SECPKG_CONTEXT_THUNKS ContextThunks;
        SECPKG_MUTUAL_AUTH_LEVEL MutualAuthLevel;
    }
    _Info Info;
}
alias PSECPKG_EXTENDED_INFORMATION = SECPKG_EXTENDED_INFORMATION*;

/* callbacks implemented by SSP/AP dlls and called by the LSA */
alias PLSA_CALLBACK_FUNCTION = void function(ULONG_PTR, ULONG_PTR, PSecBuffer,
 PSecBuffer);

/* misc typedefs used in the below prototypes */
alias PLSA_CLIENT_REQUEST = PVOID*;
alias LSA_SEC_HANDLE = ULONG_PTR;
alias PLSA_SEC_HANDLE = LSA_SEC_HANDLE*;
alias SEC_THREAD_START = LPTHREAD_START_ROUTINE;
alias SEC_ATTRS = PSECURITY_ATTRIBUTES;

/* functions used by SSP/AP obtainable by dispatch tables */
alias PLSA_REGISTER_CALLBACK = NTSTATUS function(ULONG, PLSA_CALLBACK_FUNCTION);
alias PLSA_CREATE_LOGON_SESSION = NTSTATUS function(PLUID);
alias PLSA_DELETE_LOGON_SESSION = NTSTATUS function(PLUID);
alias PLSA_ADD_CREDENTIAL = NTSTATUS function(PLUID, ULONG, PLSA_STRING,
 PLSA_STRING);
alias PLSA_GET_CREDENTIALS = NTSTATUS function(PLUID, ULONG, PULONG, BOOLEAN,
 PLSA_STRING, PULONG, PLSA_STRING);
alias PLSA_DELETE_CREDENTIAL = NTSTATUS function(PLUID, ULONG, PLSA_STRING);
alias PLSA_ALLOCATE_LSA_HEAP = PVOID function(ULONG);
alias PLSA_FREE_LSA_HEAP = void function(PVOID);
alias PLSA_ALLOCATE_CLIENT_BUFFER = NTSTATUS function(PLSA_CLIENT_REQUEST,
 ULONG, PVOID*);
alias PLSA_FREE_CLIENT_BUFFER = NTSTATUS function(PLSA_CLIENT_REQUEST, PVOID);
alias PLSA_COPY_TO_CLIENT_BUFFER = NTSTATUS function(PLSA_CLIENT_REQUEST, ULONG,
 PVOID, PVOID);
alias PLSA_COPY_FROM_CLIENT_BUFFER = NTSTATUS function(PLSA_CLIENT_REQUEST,
 ULONG, PVOID, PVOID);
alias PLSA_IMPERSONATE_CLIENT = NTSTATUS function();
alias PLSA_UNLOAD_PACKAGE = NTSTATUS function();
alias PLSA_DUPLICATE_HANDLE = NTSTATUS function(HANDLE, PHANDLE);
alias PLSA_SAVE_SUPPLEMENTAL_CREDENTIALS = NTSTATUS function(PLUID, ULONG,
 PVOID, BOOLEAN);
alias PLSA_CREATE_THREAD = HANDLE function(SEC_ATTRS, ULONG, SEC_THREAD_START,
 PVOID, ULONG, PULONG);
alias PLSA_GET_CLIENT_INFO = NTSTATUS function(PSECPKG_CLIENT_INFO);
alias PLSA_REGISTER_NOTIFICATION = HANDLE function(SEC_THREAD_START, PVOID,
 ULONG, ULONG, ULONG, ULONG, HANDLE);
alias PLSA_CANCEL_NOTIFICATION = NTSTATUS function(HANDLE);
alias PLSA_MAP_BUFFER = NTSTATUS function(PSecBuffer, PSecBuffer);
alias PLSA_CREATE_TOKEN = NTSTATUS function(PLUID, PTOKEN_SOURCE,
 SECURITY_LOGON_TYPE, SECURITY_IMPERSONATION_LEVEL, LSA_TOKEN_INFORMATION_TYPE,
 PVOID, PTOKEN_GROUPS, PUNICODE_STRING, PUNICODE_STRING, PUNICODE_STRING,
 PUNICODE_STRING, PHANDLE, PNTSTATUS);
alias PLSA_AUDIT_LOGON = void function(NTSTATUS, NTSTATUS, PUNICODE_STRING,
 PUNICODE_STRING, PUNICODE_STRING, PSID, SECURITY_LOGON_TYPE,
 PTOKEN_SOURCE, PLUID);
alias PLSA_CALL_PACKAGE = NTSTATUS function(PUNICODE_STRING, PVOID, ULONG,
 PVOID*, PULONG, PNTSTATUS);
alias PLSA_GET_CALL_INFO = BOOLEAN function(PSECPKG_CALL_INFO);
alias PLSA_CALL_PACKAGEEX = NTSTATUS function(PUNICODE_STRING, PVOID, PVOID,
 ULONG, PVOID*, PULONG, PNTSTATUS);
alias PLSA_CREATE_SHARED_MEMORY = PVOID function(ULONG, ULONG);
alias PLSA_ALLOCATE_SHARED_MEMORY = PVOID function(PVOID, ULONG);
alias PLSA_FREE_SHARED_MEMORY = void function(PVOID, PVOID);
alias PLSA_DELETE_SHARED_MEMORY = BOOLEAN function(PVOID);
alias PLSA_OPEN_SAM_USER = NTSTATUS function(PSECURITY_STRING, SECPKG_NAME_TYPE,
 PSECURITY_STRING, BOOLEAN, ULONG, PVOID*);
alias PLSA_GET_USER_CREDENTIALS = NTSTATUS function(PVOID, PVOID *, PULONG,
 PVOID *, PULONG);
alias PLSA_GET_USER_AUTH_DATA = NTSTATUS function(PVOID, PUCHAR *, PULONG);
alias PLSA_CLOSE_SAM_USER = NTSTATUS function(PVOID);
alias PLSA_CONVERT_AUTH_DATA_TO_TOKEN = NTSTATUS function(PVOID, ULONG,
 SECURITY_IMPERSONATION_LEVEL, PTOKEN_SOURCE, SECURITY_LOGON_TYPE,
 PUNICODE_STRING, PHANDLE, PLUID, PUNICODE_STRING, PNTSTATUS);
alias PLSA_CLIENT_CALLBACK = NTSTATUS function(PCHAR, ULONG_PTR, ULONG_PTR,
 PSecBuffer, PSecBuffer);
alias PLSA_UPDATE_PRIMARY_CREDENTIALS = NTSTATUS function(PSECPKG_PRIMARY_CRED, PSECPKG_SUPPLEMENTAL_CRED_ARRAY);
alias PLSA_GET_AUTH_DATA_FOR_USER = NTSTATUS function(PSECURITY_STRING,
 SECPKG_NAME_TYPE, PSECURITY_STRING, PUCHAR *, PULONG, PUNICODE_STRING);
alias PLSA_CRACK_SINGLE_NAME = NTSTATUS function(ULONG, BOOLEAN,
 PUNICODE_STRING, PUNICODE_STRING, ULONG, PUNICODE_STRING, PUNICODE_STRING,
 PULONG);
alias PLSA_AUDIT_ACCOUNT_LOGON = NTSTATUS function(ULONG, BOOLEAN,
 PUNICODE_STRING, PUNICODE_STRING, PUNICODE_STRING, NTSTATUS);
alias PLSA_CALL_PACKAGE_PASSTHROUGH = NTSTATUS function(PUNICODE_STRING, PVOID,
 PVOID, ULONG, PVOID*, PULONG, PNTSTATUS);

/* Dispatch tables of functions used by SSP/AP */
struct SECPKG_DLL_FUNCTIONS {
    PLSA_ALLOCATE_LSA_HEAP AllocateHeap;
    PLSA_FREE_LSA_HEAP FreeHeap;
    PLSA_REGISTER_CALLBACK RegisterCallback;
}
alias PSECPKG_DLL_FUNCTIONS = SECPKG_DLL_FUNCTIONS*;
struct LSA_DISPATCH_TABLE {
    PLSA_CREATE_LOGON_SESSION CreateLogonSession;
    PLSA_DELETE_LOGON_SESSION DeleteLogonSession;
    PLSA_ADD_CREDENTIAL AddCredential;
    PLSA_GET_CREDENTIALS GetCredentials;
    PLSA_DELETE_CREDENTIAL DeleteCredential;
    PLSA_ALLOCATE_LSA_HEAP AllocateLsaHeap;
    PLSA_FREE_LSA_HEAP FreeLsaHeap;
    PLSA_ALLOCATE_CLIENT_BUFFER AllocateClientBuffer;
    PLSA_FREE_CLIENT_BUFFER FreeClientBuffer;
    PLSA_COPY_TO_CLIENT_BUFFER CopyToClientBuffer;
    PLSA_COPY_FROM_CLIENT_BUFFER CopyFromClientBuffer;
}
alias PLSA_DISPATCH_TABLE = LSA_DISPATCH_TABLE*;
struct LSA_SECPKG_FUNCTION_TABLE {
    PLSA_CREATE_LOGON_SESSION CreateLogonSession;
    PLSA_DELETE_LOGON_SESSION DeleteLogonSession;
    PLSA_ADD_CREDENTIAL AddCredential;
    PLSA_GET_CREDENTIALS GetCredentials;
    PLSA_DELETE_CREDENTIAL DeleteCredential;
    PLSA_ALLOCATE_LSA_HEAP AllocateLsaHeap;
    PLSA_FREE_LSA_HEAP FreeLsaHeap;
    PLSA_ALLOCATE_CLIENT_BUFFER AllocateClientBuffer;
    PLSA_FREE_CLIENT_BUFFER FreeClientBuffer;
    PLSA_COPY_TO_CLIENT_BUFFER CopyToClientBuffer;
    PLSA_COPY_FROM_CLIENT_BUFFER CopyFromClientBuffer;
    PLSA_IMPERSONATE_CLIENT ImpersonateClient;
    PLSA_UNLOAD_PACKAGE UnloadPackage;
    PLSA_DUPLICATE_HANDLE DuplicateHandle;
    PLSA_SAVE_SUPPLEMENTAL_CREDENTIALS SaveSupplementalCredentials;
    PLSA_CREATE_THREAD CreateThread;
    PLSA_GET_CLIENT_INFO GetClientInfo;
    PLSA_REGISTER_NOTIFICATION RegisterNotification;
    PLSA_CANCEL_NOTIFICATION CancelNotification;
    PLSA_MAP_BUFFER MapBuffer;
    PLSA_CREATE_TOKEN CreateToken;
    PLSA_AUDIT_LOGON AuditLogon;
    PLSA_CALL_PACKAGE CallPackage;
    PLSA_FREE_LSA_HEAP FreeReturnBuffer;
    PLSA_GET_CALL_INFO GetCallInfo;
    PLSA_CALL_PACKAGEEX CallPackageEx;
    PLSA_CREATE_SHARED_MEMORY CreateSharedMemory;
    PLSA_ALLOCATE_SHARED_MEMORY AllocateSharedMemory;
    PLSA_FREE_SHARED_MEMORY FreeSharedMemory;
    PLSA_DELETE_SHARED_MEMORY DeleteSharedMemory;
    PLSA_OPEN_SAM_USER OpenSamUser;
    PLSA_GET_USER_CREDENTIALS GetUserCredentials;
    PLSA_GET_USER_AUTH_DATA GetUserAuthData;
    PLSA_CLOSE_SAM_USER CloseSamUser;
    PLSA_CONVERT_AUTH_DATA_TO_TOKEN ConvertAuthDataToToken;
    PLSA_CLIENT_CALLBACK ClientCallback;
    PLSA_UPDATE_PRIMARY_CREDENTIALS UpdateCredentials;
    PLSA_GET_AUTH_DATA_FOR_USER GetAuthDataForUser;
    PLSA_CRACK_SINGLE_NAME CrackSingleName;
    PLSA_AUDIT_ACCOUNT_LOGON AuditAccountLogon;
    PLSA_CALL_PACKAGE_PASSTHROUGH CallPackagePassthrough;
}
alias PLSA_SECPKG_FUNCTION_TABLE = LSA_SECPKG_FUNCTION_TABLE*;

/* functions implemented by SSP/AP obtainable by dispatch tables */
alias PLSA_AP_INITIALIZE_PACKAGE = NTSTATUS function(ULONG, PLSA_DISPATCH_TABLE,
 PLSA_STRING, PLSA_STRING, PLSA_STRING *);
alias PLSA_AP_LOGON_USER = NTSTATUS function(LPWSTR, LPWSTR, LPWSTR, LPWSTR,
 DWORD, DWORD, PHANDLE);
alias PLSA_AP_CALL_PACKAGE = NTSTATUS function(PUNICODE_STRING, PVOID, ULONG,
 PVOID *, PULONG, PNTSTATUS);
alias PLSA_AP_LOGON_TERMINATED = void function(PLUID);
alias PLSA_AP_CALL_PACKAGE_UNTRUSTED = NTSTATUS function(PLSA_CLIENT_REQUEST,
 PVOID, PVOID, ULONG, PVOID *, PULONG, PNTSTATUS);
alias PLSA_AP_CALL_PACKAGE_PASSTHROUGH = NTSTATUS function(PUNICODE_STRING,
 PVOID, PVOID, ULONG, PVOID *, PULONG, PNTSTATUS);
alias PLSA_AP_LOGON_USER_EX = NTSTATUS function(PLSA_CLIENT_REQUEST,
 SECURITY_LOGON_TYPE, PVOID, PVOID, ULONG, PVOID *, PULONG, PLUID, PNTSTATUS,
 PLSA_TOKEN_INFORMATION_TYPE, PVOID *, PUNICODE_STRING *, PUNICODE_STRING *,
 PUNICODE_STRING *);
alias PLSA_AP_LOGON_USER_EX2 = NTSTATUS function(PLSA_CLIENT_REQUEST,
 SECURITY_LOGON_TYPE, PVOID, PVOID, ULONG, PVOID *, PULONG, PLUID, PNTSTATUS,
 PLSA_TOKEN_INFORMATION_TYPE, PVOID *, PUNICODE_STRING *, PUNICODE_STRING *,
 PUNICODE_STRING *, PSECPKG_PRIMARY_CRED, PSECPKG_SUPPLEMENTAL_CRED_ARRAY *);
alias SpInitializeFn = NTSTATUS function(ULONG_PTR, PSECPKG_PARAMETERS,
 PLSA_SECPKG_FUNCTION_TABLE);
alias SpShutDownFn = NTSTATUS function();
alias SpGetInfoFn = NTSTATUS function(PSecPkgInfoW);
alias SpAcceptCredentialsFn = NTSTATUS function(SECURITY_LOGON_TYPE,
 PUNICODE_STRING, PSECPKG_PRIMARY_CRED, PSECPKG_SUPPLEMENTAL_CRED);
alias SpAcquireCredentialsHandleFn = NTSTATUS function(PUNICODE_STRING, ULONG,
 PLUID, PVOID, PVOID, PVOID, PLSA_SEC_HANDLE, PTimeStamp);
alias SpQueryCredentialsAttributesFn = NTSTATUS function(LSA_SEC_HANDLE, ULONG, PVOID);
alias SpFreeCredentialsHandleFn = NTSTATUS function(LSA_SEC_HANDLE);
alias SpSaveCredentialsFn = NTSTATUS function(LSA_SEC_HANDLE, PSecBuffer);
alias SpGetCredentialsFn = NTSTATUS function(LSA_SEC_HANDLE, PSecBuffer);
alias SpDeleteCredentialsFn = NTSTATUS function(LSA_SEC_HANDLE, PSecBuffer);
alias SpInitLsaModeContextFn = NTSTATUS function(LSA_SEC_HANDLE, LSA_SEC_HANDLE,
 PUNICODE_STRING, ULONG, ULONG, PSecBufferDesc, PLSA_SEC_HANDLE, PSecBufferDesc,
 PULONG, PTimeStamp, PBOOLEAN, PSecBuffer);
alias SpAcceptLsaModeContextFn = NTSTATUS function(LSA_SEC_HANDLE,
 LSA_SEC_HANDLE, PSecBufferDesc, ULONG, ULONG, PLSA_SEC_HANDLE, PSecBufferDesc,
 PULONG, PTimeStamp, PBOOLEAN, PSecBuffer);
alias SpDeleteContextFn = NTSTATUS function(LSA_SEC_HANDLE);
alias SpApplyControlTokenFn = NTSTATUS function(LSA_SEC_HANDLE, PSecBufferDesc);
alias SpGetUserInfoFn = NTSTATUS function(PLUID, ULONG, PSecurityUserData *);
alias SpGetExtendedInformationFn = NTSTATUS function(SECPKG_EXTENDED_INFORMATION_CLASS, PSECPKG_EXTENDED_INFORMATION *);
alias SpQueryContextAttributesFn = NTSTATUS function(LSA_SEC_HANDLE, ULONG, PVOID);
alias SpAddCredentialsFn = NTSTATUS function(LSA_SEC_HANDLE, PUNICODE_STRING,
 PUNICODE_STRING, ULONG, PVOID, PVOID, PVOID, PTimeStamp);
alias SpSetExtendedInformationFn = NTSTATUS function(
 SECPKG_EXTENDED_INFORMATION_CLASS, PSECPKG_EXTENDED_INFORMATION);
alias SpInstanceInitFn = NTSTATUS function(ULONG, PSECPKG_DLL_FUNCTIONS,
 PVOID *);
alias SpInitUserModeContextFn = NTSTATUS function(LSA_SEC_HANDLE, PSecBuffer);
alias SpMakeSignatureFn = NTSTATUS function(LSA_SEC_HANDLE, ULONG,
 PSecBufferDesc, ULONG);
alias SpVerifySignatureFn = NTSTATUS function(LSA_SEC_HANDLE, PSecBufferDesc,
 ULONG, PULONG);
alias SpSealMessageFn = NTSTATUS function(LSA_SEC_HANDLE, ULONG, PSecBufferDesc,
 ULONG);
alias SpUnsealMessageFn = NTSTATUS function(LSA_SEC_HANDLE, PSecBufferDesc,
 ULONG, PULONG);
alias SpGetContextTokenFn = NTSTATUS function(LSA_SEC_HANDLE, PHANDLE);
alias SpCompleteAuthTokenFn = NTSTATUS function(LSA_SEC_HANDLE, PSecBufferDesc);
alias SpFormatCredentialsFn = NTSTATUS function(PSecBuffer, PSecBuffer);
alias SpMarshallSupplementalCredsFn = NTSTATUS function(ULONG, PUCHAR, PULONG,
 PVOID *);
alias SpExportSecurityContextFn = NTSTATUS function(LSA_SEC_HANDLE, ULONG,
 PSecBuffer, PHANDLE);
alias SpImportSecurityContextFn = NTSTATUS function(PSecBuffer, HANDLE,
 PLSA_SEC_HANDLE);

/* Dispatch tables of functions implemented by SSP/AP */
struct SECPKG_FUNCTION_TABLE {
    PLSA_AP_INITIALIZE_PACKAGE InitializePackage;
    PLSA_AP_LOGON_USER LogonUser;
    PLSA_AP_CALL_PACKAGE CallPackage;
    PLSA_AP_LOGON_TERMINATED LogonTerminated;
    PLSA_AP_CALL_PACKAGE_UNTRUSTED CallPackageUntrusted;
    PLSA_AP_CALL_PACKAGE_PASSTHROUGH CallPackagePassthrough;
    PLSA_AP_LOGON_USER_EX LogonUserEx;
    PLSA_AP_LOGON_USER_EX2 LogonUserEx2;
    SpInitializeFn *Initialize;
    SpShutDownFn *Shutdown;
    SpGetInfoFn *GetInfo;
    SpAcceptCredentialsFn *AcceptCredentials;
    SpAcquireCredentialsHandleFn *AcquireCredentialsHandle;
    SpQueryCredentialsAttributesFn *QueryCredentialsAttributes;
    SpFreeCredentialsHandleFn *FreeCredentialsHandle;
    SpSaveCredentialsFn *SaveCredentials;
    SpGetCredentialsFn *GetCredentials;
    SpDeleteCredentialsFn *DeleteCredentials;
    SpInitLsaModeContextFn *InitLsaModeContext;
    SpAcceptLsaModeContextFn *AcceptLsaModeContext;
    SpDeleteContextFn *DeleteContext;
    SpApplyControlTokenFn *ApplyControlToken;
    SpGetUserInfoFn *GetUserInfo;
    SpGetExtendedInformationFn *GetExtendedInformation;
    SpQueryContextAttributesFn *QueryContextAttributes;
    SpAddCredentialsFn *AddCredentials;
    SpSetExtendedInformationFn *SetExtendedInformation;
}
alias PSECPKG_FUNCTION_TABLE = SECPKG_FUNCTION_TABLE*;

struct SECPKG_USER_FUNCTION_TABLE {
    SpInstanceInitFn *InstanceInit;
    SpInitUserModeContextFn *InitUserModeContext;
    SpMakeSignatureFn *MakeSignature;
    SpVerifySignatureFn *VerifySignature;
    SpSealMessageFn *SealMessage;
    SpUnsealMessageFn *UnsealMessage;
    SpGetContextTokenFn *GetContextToken;
    SpQueryContextAttributesFn *QueryContextAttributes;
    SpCompleteAuthTokenFn *CompleteAuthToken;
    SpDeleteContextFn *DeleteUserModeContext;
    SpFormatCredentialsFn *FormatCredentials;
    SpMarshallSupplementalCredsFn *MarshallSupplementalCreds;
    SpExportSecurityContextFn *ExportContext;
    SpImportSecurityContextFn *ImportContext;
}
alias PSECPKG_USER_FUNCTION_TABLE = SECPKG_USER_FUNCTION_TABLE*;

/* Entry points to SSP/AP */
alias SpLsaModeInitializeFn = NTSTATUS function(ULONG, PULONG,
 PSECPKG_FUNCTION_TABLE *, PULONG);
alias SpUserModeInitializeFn = NTSTATUS function(ULONG, PULONG,
 PSECPKG_USER_FUNCTION_TABLE *, PULONG);
