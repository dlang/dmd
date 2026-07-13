/**
 * Windows API header module
 *
 * Translated from MinGW Windows headers
 *
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source: $(DRUNTIMESRC core/sys/windows/_ras.d)
 */
module core.sys.windows.ras;
version (Windows):

version (ANSI) {} else version = Unicode;
pragma(lib, "rasapi32");

import core.sys.windows.basetyps, core.sys.windows.lmcons, core.sys.windows.w32api, core.sys.windows.windef;

align(4):

enum RAS_MaxDeviceType = 16;
enum RAS_MaxPhoneNumber = 128;
enum RAS_MaxIpAddress = 15;
enum RAS_MaxIpxAddress = 21;
enum RAS_MaxEntryName = 256;
enum RAS_MaxDeviceName = 128;
enum RAS_MaxCallbackNumber = RAS_MaxPhoneNumber;
enum RAS_MaxAreaCode = 10;
enum RAS_MaxPadType = 32;
enum RAS_MaxX25Address = 200;
enum RAS_MaxFacilities = 200;
enum RAS_MaxUserData = 200;
enum RAS_MaxReplyMessage = 1024;

enum RDEOPT_UsePrefixSuffix           = 0x00000001;
enum RDEOPT_PausedStates              = 0x00000002;
enum RDEOPT_IgnoreModemSpeaker        = 0x00000004;
enum RDEOPT_SetModemSpeaker           = 0x00000008;
enum RDEOPT_IgnoreSoftwareCompression = 0x00000010;
enum RDEOPT_SetSoftwareCompression    = 0x00000020;
enum RDEOPT_DisableConnectedUI        = 0x00000040;
enum RDEOPT_DisableReconnectUI        = 0x00000080;
enum RDEOPT_DisableReconnect          = 0x00000100;
enum RDEOPT_NoUser                    = 0x00000200;
enum RDEOPT_PauseOnScript             = 0x00000400;
enum RDEOPT_Router                    = 0x00000800;

enum REN_User = 0x00000000;
enum REN_AllUsers = 0x00000001;
enum VS_Default = 0;
enum VS_PptpOnly = 1;
enum VS_PptpFirst = 2;
enum VS_L2tpOnly = 3;
enum VS_L2tpFirst = 4;

enum RASDIALEVENT = "RasDialEvent";
enum WM_RASDIALEVENT = 0xCCCD;

enum RASEO_UseCountryAndAreaCodes = 0x00000001;
enum RASEO_SpecificIpAddr = 0x00000002;
enum RASEO_SpecificNameServers = 0x00000004;
enum RASEO_IpHeaderCompression = 0x00000008;
enum RASEO_RemoteDefaultGateway = 0x00000010;
enum RASEO_DisableLcpExtensions = 0x00000020;
enum RASEO_TerminalBeforeDial = 0x00000040;
enum RASEO_TerminalAfterDial = 0x00000080;
enum RASEO_ModemLights = 0x00000100;
enum RASEO_SwCompression = 0x00000200;
enum RASEO_RequireEncryptedPw = 0x00000400;
enum RASEO_RequireMsEncryptedPw = 0x00000800;
enum RASEO_RequireDataEncryption = 0x00001000;
enum RASEO_NetworkLogon = 0x00002000;
enum RASEO_UseLogonCredentials = 0x00004000;
enum RASEO_PromoteAlternates = 0x00008000;
enum RASNP_NetBEUI = 0x00000001;
enum RASNP_Ipx = 0x00000002;
enum RASNP_Ip = 0x00000004;
enum RASFP_Ppp = 0x00000001;
enum RASFP_Slip = 0x00000002;
enum RASFP_Ras = 0x00000004;

const TCHAR[]
    RASDT_Modem = "modem",
    RASDT_Isdn = "isdn",
    RASDT_X25 = "x25",
    RASDT_Vpn = "vpn",
    RASDT_Pad = "pad",
    RASDT_Generic = "GENERIC",
    RASDT_Serial = "SERIAL",
    RASDT_FrameRelay = "FRAMERELAY",
    RASDT_Atm = "ATM",
    RASDT_Sonet = "SONET",
    RASDT_SW56 = "SW56",
    RASDT_Irda = "IRDA",
    RASDT_Parallel = "PARALLEL";

enum RASET_Phone = 1;
enum RASET_Vpn = 2;
enum RASET_Direct = 3;
enum RASET_Internet = 4;

static if (_WIN32_WINNT >= 0x401) {
enum RASEO_SecureLocalFiles = 0x00010000;
enum RASCN_Connection = 0x00000001;
enum RASCN_Disconnection = 0x00000002;
enum RASCN_BandwidthAdded = 0x00000004;
enum RASCN_BandwidthRemoved = 0x00000008;
enum RASEDM_DialAll = 1;
enum RASEDM_DialAsNeeded = 2;
enum RASIDS_Disabled = 0xffffffff;
enum RASIDS_UseGlobalValue = 0;
enum RASADFLG_PositionDlg = 0x00000001;
enum RASCM_UserName = 0x00000001;
enum RASCM_Password = 0x00000002;
enum RASCM_Domain = 0x00000004;
enum RASADP_DisableConnectionQuery = 0;
enum RASADP_LoginSessionDisable = 1;
enum RASADP_SavedAddressesLimit = 2;
enum RASADP_FailedConnectionTimeout = 3;
enum RASADP_ConnectionQueryTimeout = 4;
}
//static if (_WIN32_WINNT >= 0x500) {
enum RDEOPT_CustomDial = 0x00001000;
enum RASLCPAP_PAP = 0xC023;
enum RASLCPAP_SPAP = 0xC027;
enum RASLCPAP_CHAP = 0xC223;
enum RASLCPAP_EAP = 0xC227;
enum RASLCPAD_CHAP_MD5 = 0x05;
enum RASLCPAD_CHAP_MS = 0x80;
enum RASLCPAD_CHAP_MSV2 = 0x81;
enum RASLCPO_PFC    = 0x00000001;
enum RASLCPO_ACFC   = 0x00000002;
enum RASLCPO_SSHF   = 0x00000004;
enum RASLCPO_DES_56 = 0x00000008;
enum RASLCPO_3_DES  = 0x00000010;

enum RASCCPCA_MPPC = 0x00000006;
enum RASCCPCA_STAC = 0x00000005;

enum RASCCPO_Compression      = 0x00000001;
enum RASCCPO_HistoryLess      = 0x00000002;
enum RASCCPO_Encryption56bit  = 0x00000010;
enum RASCCPO_Encryption40bit  = 0x00000020;
enum RASCCPO_Encryption128bit = 0x00000040;

enum RASEO_RequireEAP          = 0x00020000;
enum RASEO_RequirePAP          = 0x00040000;
enum RASEO_RequireSPAP         = 0x00080000;
enum RASEO_Custom              = 0x00100000;
enum RASEO_PreviewPhoneNumber  = 0x00200000;
enum RASEO_SharedPhoneNumbers  = 0x00800000;
enum RASEO_PreviewUserPw       = 0x01000000;
enum RASEO_PreviewDomain       = 0x02000000;
enum RASEO_ShowDialingProgress = 0x04000000;
enum RASEO_RequireCHAP         = 0x08000000;
enum RASEO_RequireMsCHAP       = 0x10000000;
enum RASEO_RequireMsCHAP2      = 0x20000000;
enum RASEO_RequireW95MSCHAP    = 0x40000000;
enum RASEO_CustomScript        = 0x80000000;

enum RASIPO_VJ = 0x00000001;
enum RCD_SingleUser = 0;
enum RCD_AllUsers = 0x00000001;
enum RCD_Eap = 0x00000002;
enum RASEAPF_NonInteractive = 0x00000002;
enum RASEAPF_Logon = 0x00000004;
enum RASEAPF_Preview = 0x00000008;
enum ET_40Bit = 1;
enum ET_128Bit = 2;
enum ET_None = 0;
enum ET_Require = 1;
enum ET_RequireMax = 2;
enum ET_Optional = 3;
//}

enum RASCS_PAUSED = 0x1000;
enum RASCS_DONE = 0x2000;
enum RASCONNSTATE {
    RASCS_OpenPort = 0,
    RASCS_PortOpened,
    RASCS_ConnectDevice,
    RASCS_DeviceConnected,
    RASCS_AllDevicesConnected,
    RASCS_Authenticate,
    RASCS_AuthNotify,
    RASCS_AuthRetry,
    RASCS_AuthCallback,
    RASCS_AuthChangePassword,
    RASCS_AuthProject,
    RASCS_AuthLinkSpeed,
    RASCS_AuthAck,
    RASCS_ReAuthenticate,
    RASCS_Authenticated,
    RASCS_PrepareForCallback,
    RASCS_WaitForModemReset,
    RASCS_WaitForCallback,
    RASCS_Projected,
    RASCS_StartAuthentication,
    RASCS_CallbackComplete,
    RASCS_LogonNetwork,
    RASCS_SubEntryConnected,
    RASCS_SubEntryDisconnected,
    RASCS_Interactive = RASCS_PAUSED,
    RASCS_RetryAuthentication,
    RASCS_CallbackSetByCaller,
    RASCS_PasswordExpired,
//  static if (_WIN32_WINNT >= 0x500) {
        RASCS_InvokeEapUI,
//  }
    RASCS_Connected = RASCS_DONE,
    RASCS_Disconnected
}
alias LPRASCONNSTATE = RASCONNSTATE*;

enum RASPROJECTION {
    RASP_Amb =      0x10000,
    RASP_PppNbf =   0x803F,
    RASP_PppIpx =   0x802B,
    RASP_PppIp =    0x8021,
//  static if (_WIN32_WINNT >= 0x500) {
        RASP_PppCcp =   0x80FD,
//  }
    RASP_PppLcp =   0xC021,
    RASP_Slip =     0x20000
}
alias LPRASPROJECTION = RASPROJECTION*;

alias HRASCONN = HANDLE;
alias LPHRASCONN = HRASCONN*;

struct RASCONNW {
align(4):
    DWORD dwSize;
    HRASCONN hrasconn;
    align {
    WCHAR[RAS_MaxEntryName + 1] szEntryName = 0;
    WCHAR[RAS_MaxDeviceType + 1] szDeviceType = 0;
    WCHAR[RAS_MaxDeviceName + 1] szDeviceName = 0;
    }
    //static if (_WIN32_WINNT >= 0x401) {
        WCHAR[MAX_PATH] szPhonebook = 0;
        DWORD dwSubEntry;
    //}
    //static if (_WIN32_WINNT >= 0x500) {
        GUID guidEntry;
    //}
    static if (_WIN32_WINNT >= 0x501) {
        DWORD dwFlags;
        LUID luid;
    }
}
alias LPRASCONNW = RASCONNW*;

struct RASCONNA {
align(4):
    DWORD dwSize;
    HRASCONN hrasconn;
    align {
    CHAR[RAS_MaxEntryName + 1] szEntryName = 0;
    CHAR[RAS_MaxDeviceType + 1] szDeviceType = 0;
    CHAR[RAS_MaxDeviceName + 1] szDeviceName = 0;
    }
    //static if (_WIN32_WINNT >= 0x401) {
        CHAR[MAX_PATH] szPhonebook = 0;
        DWORD dwSubEntry;
    //}
    //static if (_WIN32_WINNT >= 0x500) {
        GUID guidEntry;
    //}
    static if (_WIN32_WINNT >= 0x501) {
        DWORD dwFlags;
        LUID luid;
    }
}
alias LPRASCONNA = RASCONNA*;

struct RASCONNSTATUSW {
    DWORD dwSize;
    RASCONNSTATE rasconnstate;
    DWORD dwError;
    WCHAR[RAS_MaxDeviceType + 1] szDeviceType = 0;
    WCHAR[RAS_MaxDeviceName + 1] szDeviceName = 0;
    static if (_WIN32_WINNT >= 0x401) {
        WCHAR[RAS_MaxPhoneNumber + 1] szPhoneNumber = 0;
    }
}
alias LPRASCONNSTATUSW = RASCONNSTATUSW*;

struct RASCONNSTATUSA {
    DWORD dwSize;
    RASCONNSTATE rasconnstate;
    DWORD dwError;
    CHAR[RAS_MaxDeviceType + 1] szDeviceType = 0;
    CHAR[RAS_MaxDeviceName + 1] szDeviceName = 0;
    static if (_WIN32_WINNT >= 0x401) {
        CHAR[RAS_MaxPhoneNumber + 1] szPhoneNumber = 0;
    }
}
alias LPRASCONNSTATUSA = RASCONNSTATUSA*;

struct RASDIALPARAMSW {
align(4):
    DWORD dwSize;
align {
    WCHAR[RAS_MaxEntryName + 1] szEntryName = 0;
    WCHAR[RAS_MaxPhoneNumber + 1] szPhoneNumber = 0;
    WCHAR[RAS_MaxCallbackNumber + 1] szCallbackNumber = 0;
    WCHAR[UNLEN + 1] szUserName = 0;
    WCHAR[PWLEN + 1] szPassword = 0;
    WCHAR[DNLEN + 1] szDomain = 0;
}
    static if (_WIN32_WINNT >= 0x401) {
        DWORD dwSubEntry;
        ULONG_PTR dwCallbackId;
    }
}
alias LPRASDIALPARAMSW = RASDIALPARAMSW*;

struct RASDIALPARAMSA{
align(4):
    DWORD dwSize;
align {
    CHAR[RAS_MaxEntryName + 1] szEntryName = 0;
    CHAR[RAS_MaxPhoneNumber + 1] szPhoneNumber = 0;
    CHAR[RAS_MaxCallbackNumber + 1] szCallbackNumber = 0;
    CHAR[UNLEN + 1] szUserName = 0;
    CHAR[PWLEN + 1] szPassword = 0;
    CHAR[DNLEN + 1] szDomain = 0;
}
    static if (_WIN32_WINNT >= 0x401) {
        DWORD dwSubEntry;
        ULONG_PTR dwCallbackId;
    }
}
alias LPRASDIALPARAMSA = RASDIALPARAMSA*;

//static if (_WIN32_WINNT >= 0x500) {
    struct RASEAPINFO {
    align(4):
        DWORD dwSizeofEapInfo;
        BYTE *pbEapInfo;
    }
//}

struct RASDIALEXTENSIONS {
align(4):
    DWORD dwSize;
    DWORD dwfOptions;
    HWND hwndParent;
    ULONG_PTR reserved;
    //static if (_WIN32_WINNT >= 0x500) {
        ULONG_PTR reserved1;
        RASEAPINFO RasEapInfo;
    //}
}
alias LPRASDIALEXTENSIONS = RASDIALEXTENSIONS*;

struct RASENTRYNAMEW {
    DWORD dwSize;
    WCHAR[RAS_MaxEntryName + 1] szEntryName = 0;
    //static if (_WIN32_WINNT >= 0x500) {
        DWORD dwFlags;
        WCHAR[MAX_PATH + 1] szPhonebookPath = 0;
    //}
}
alias LPRASENTRYNAMEW = RASENTRYNAMEW*;

struct RASENTRYNAMEA{
    DWORD dwSize;
    CHAR[RAS_MaxEntryName + 1] szEntryName = 0;
    //static if (_WIN32_WINNT >= 0x500) {
        DWORD dwFlags;
        CHAR[MAX_PATH + 1] szPhonebookPath = 0;
    //}
}
alias LPRASENTRYNAMEA = RASENTRYNAMEA*;

struct RASAMBW{
    DWORD dwSize;
    DWORD dwError;
    WCHAR[NETBIOS_NAME_LEN + 1] szNetBiosError = 0;
    BYTE bLana;
}
alias LPRASAMBW = RASAMBW*;

struct RASAMBA{
    DWORD dwSize;
    DWORD dwError;
    CHAR[NETBIOS_NAME_LEN + 1] szNetBiosError = 0;
    BYTE bLana;
}
alias LPRASAMBA = RASAMBA*;

struct RASPPPNBFW{
    DWORD dwSize;
    DWORD dwError;
    DWORD dwNetBiosError;
    WCHAR[NETBIOS_NAME_LEN + 1] szNetBiosError = 0;
    WCHAR[NETBIOS_NAME_LEN + 1] szWorkstationName = 0;
    BYTE bLana;
}
alias LPRASPPPNBFW = RASPPPNBFW*;

struct RASPPPNBFA{
    DWORD dwSize;
    DWORD dwError;
    DWORD dwNetBiosError;
    CHAR[NETBIOS_NAME_LEN + 1] szNetBiosError = 0;
    CHAR[NETBIOS_NAME_LEN + 1] szWorkstationName = 0;
    BYTE bLana;
}
alias LPRASPPPNBFA = RASPPPNBFA*;

struct RASPPPIPXW {
    DWORD dwSize;
    DWORD dwError;
    WCHAR[RAS_MaxIpxAddress + 1] szIpxAddress = 0;
}
alias LPRASPPPIPXW = RASPPPIPXW*;

struct RASPPPIPXA {
    DWORD dwSize;
    DWORD dwError;
    CHAR[RAS_MaxIpxAddress + 1] szIpxAddress = 0;
}
alias LPRASPPPIPXA = RASPPPIPXA*;

struct RASPPPIPW{
    DWORD dwSize;
    DWORD dwError;
    WCHAR[RAS_MaxIpAddress + 1] szIpAddress = 0;
    //#ifndef WINNT35COMPATIBLE
    WCHAR[RAS_MaxIpAddress + 1] szServerIpAddress = 0;
    //#endif
    //static if (_WIN32_WINNT >= 0x500) {
        DWORD dwOptions;
        DWORD dwServerOptions;
    //}
}
alias LPRASPPPIPW = RASPPPIPW*;

struct RASPPPIPA{
    DWORD dwSize;
    DWORD dwError;
    CHAR[RAS_MaxIpAddress + 1] szIpAddress = 0;
    //#ifndef WINNT35COMPATIBLE
    CHAR[RAS_MaxIpAddress + 1] szServerIpAddress = 0;
    //#endif
    //static if (_WIN32_WINNT >= 0x500) {
        DWORD dwOptions;
        DWORD dwServerOptions;
    //}
}
alias LPRASPPPIPA = RASPPPIPA*;

struct RASPPPLCPW{
    DWORD dwSize;
    BOOL fBundled;
    //static if (_WIN32_WINNT >= 0x500) {
        DWORD dwError;
        DWORD dwAuthenticationProtocol;
        DWORD dwAuthenticationData;
        DWORD dwEapTypeId;
        DWORD dwServerAuthenticationProtocol;
        DWORD dwServerAuthenticationData;
        DWORD dwServerEapTypeId;
        BOOL fMultilink;
        DWORD dwTerminateReason;
        DWORD dwServerTerminateReason;
        WCHAR[RAS_MaxReplyMessage] szReplyMessage = 0;
        DWORD dwOptions;
        DWORD dwServerOptions;
    //}
}
alias LPRASPPPLCPW = RASPPPLCPW*;

struct RASPPPLCPA{
    DWORD dwSize;
    BOOL fBundled;
    //static if (_WIN32_WINNT >= 0x500) {
        DWORD dwError;
        DWORD dwAuthenticationProtocol;
        DWORD dwAuthenticationData;
        DWORD dwEapTypeId;
        DWORD dwServerAuthenticationProtocol;
        DWORD dwServerAuthenticationData;
        DWORD dwServerEapTypeId;
        BOOL fMultilink;
        DWORD dwTerminateReason;
        DWORD dwServerTerminateReason;
        CHAR[RAS_MaxReplyMessage] szReplyMessage = 0;
        DWORD dwOptions;
        DWORD dwServerOptions;
    //}
}
alias LPRASPPPLCPA = RASPPPLCPA*;

struct RASSLIPW{
    DWORD dwSize;
    DWORD dwError;
    WCHAR[RAS_MaxIpAddress + 1] szIpAddress = 0;
}
alias LPRASSLIPW = RASSLIPW*;

struct RASSLIPA{
    DWORD dwSize;
    DWORD dwError;
    CHAR[RAS_MaxIpAddress + 1] szIpAddress = 0;
}
alias LPRASSLIPA = RASSLIPA*;

struct RASDEVINFOW{
    DWORD dwSize;
    WCHAR[RAS_MaxDeviceType + 1] szDeviceType = 0;
    WCHAR[RAS_MaxDeviceName + 1] szDeviceName = 0;
}
alias LPRASDEVINFOW = RASDEVINFOW*;

struct RASDEVINFOA{
    DWORD dwSize;
    CHAR[RAS_MaxDeviceType + 1] szDeviceType = 0;
    CHAR[RAS_MaxDeviceName + 1] szDeviceName = 0;
}
alias LPRASDEVINFOA = RASDEVINFOA*;

struct RASCTRYINFO {
    DWORD dwSize;
    DWORD dwCountryID;
    DWORD dwNextCountryID;
    DWORD dwCountryCode;
    DWORD dwCountryNameOffset;
}
alias LPRASCTRYINFO = RASCTRYINFO*;
alias RASCTRYINFOW = RASCTRYINFO, RASCTRYINFOA = RASCTRYINFO;
alias LPRASCTRYINFOW = RASCTRYINFOW*;
alias LPRASCTRYINFOA = RASCTRYINFOA*;

struct RASIPADDR {
    BYTE a;
    BYTE b;
    BYTE c;
    BYTE d;
}

struct RASENTRYW {
    DWORD dwSize;
    DWORD dwfOptions;
    DWORD dwCountryID;
    DWORD dwCountryCode;
    WCHAR[RAS_MaxAreaCode + 1] szAreaCode = 0;
    WCHAR[RAS_MaxPhoneNumber + 1] szLocalPhoneNumber = 0;
    DWORD dwAlternateOffset;
    RASIPADDR ipaddr;
    RASIPADDR ipaddrDns;
    RASIPADDR ipaddrDnsAlt;
    RASIPADDR ipaddrWins;
    RASIPADDR ipaddrWinsAlt;
    DWORD dwFrameSize;
    DWORD dwfNetProtocols;
    DWORD dwFramingProtocol;
    WCHAR[MAX_PATH] szScript = 0;
    WCHAR[MAX_PATH] szAutodialDll = 0;
    WCHAR[MAX_PATH] szAutodialFunc = 0;
    WCHAR[RAS_MaxDeviceType + 1] szDeviceType = 0;
    WCHAR[RAS_MaxDeviceName + 1] szDeviceName = 0;
    WCHAR[RAS_MaxPadType + 1] szX25PadType = 0;
    WCHAR[RAS_MaxX25Address + 1] szX25Address = 0;
    WCHAR[RAS_MaxFacilities + 1] szX25Facilities = 0;
    WCHAR[RAS_MaxUserData + 1] szX25UserData = 0;
    DWORD dwChannels;
    DWORD dwReserved1;
    DWORD dwReserved2;
    //static if (_WIN32_WINNT >= 0x401) {
        DWORD dwSubEntries;
        DWORD dwDialMode;
        DWORD dwDialExtraPercent;
        DWORD dwDialExtraSampleSeconds;
        DWORD dwHangUpExtraPercent;
        DWORD dwHangUpExtraSampleSeconds;
        DWORD dwIdleDisconnectSeconds;
    //}
    //static if (_WIN32_WINNT >= 0x500) {
        DWORD dwType;
        DWORD dwEncryptionType;
        DWORD dwCustomAuthKey;
        GUID guidId;
        WCHAR[MAX_PATH] szCustomDialDll = 0;
        DWORD dwVpnStrategy;
    //}
}
alias LPRASENTRYW = RASENTRYW*;

struct RASENTRYA {
    DWORD dwSize;
    DWORD dwfOptions;
    DWORD dwCountryID;
    DWORD dwCountryCode;
    CHAR[RAS_MaxAreaCode + 1] szAreaCode = 0;
    CHAR[RAS_MaxPhoneNumber + 1] szLocalPhoneNumber = 0;
    DWORD dwAlternateOffset;
    RASIPADDR ipaddr;
    RASIPADDR ipaddrDns;
    RASIPADDR ipaddrDnsAlt;
    RASIPADDR ipaddrWins;
    RASIPADDR ipaddrWinsAlt;
    DWORD dwFrameSize;
    DWORD dwfNetProtocols;
    DWORD dwFramingProtocol;
    CHAR[MAX_PATH] szScript = 0;
    CHAR[MAX_PATH] szAutodialDll = 0;
    CHAR[MAX_PATH] szAutodialFunc = 0;
    CHAR[RAS_MaxDeviceType + 1] szDeviceType = 0;
    CHAR[RAS_MaxDeviceName + 1] szDeviceName = 0;
    CHAR[RAS_MaxPadType + 1] szX25PadType = 0;
    CHAR[RAS_MaxX25Address + 1] szX25Address = 0;
    CHAR[RAS_MaxFacilities + 1] szX25Facilities = 0;
    CHAR[RAS_MaxUserData + 1] szX25UserData = 0;
    DWORD dwChannels;
    DWORD dwReserved1;
    DWORD dwReserved2;
    //static if (_WIN32_WINNT >= 0x401) {
        DWORD dwSubEntries;
        DWORD dwDialMode;
        DWORD dwDialExtraPercent;
        DWORD dwDialExtraSampleSeconds;
        DWORD dwHangUpExtraPercent;
        DWORD dwHangUpExtraSampleSeconds;
        DWORD dwIdleDisconnectSeconds;
    //}
    //static if (_WIN32_WINNT >= 0x500) {
        DWORD dwType;
        DWORD dwEncryptionType;
        DWORD dwCustomAuthKey;
        GUID guidId;
        CHAR[MAX_PATH] szCustomDialDll = 0;
        DWORD dwVpnStrategy;
    //}
}
alias LPRASENTRYA = RASENTRYA*;


//static if (_WIN32_WINNT >= 0x401) {
    struct RASADPARAMS {
    align(4):
        DWORD dwSize;
        HWND hwndOwner;
        DWORD dwFlags;
        LONG xDlg;
        LONG yDlg;
    }
    alias LPRASADPARAMS = RASADPARAMS*;

    struct RASSUBENTRYW{
        DWORD dwSize;
        DWORD dwfFlags;
        WCHAR[RAS_MaxDeviceType + 1] szDeviceType = 0;
        WCHAR[RAS_MaxDeviceName + 1] szDeviceName = 0;
        WCHAR[RAS_MaxPhoneNumber + 1] szLocalPhoneNumber = 0;
        DWORD dwAlternateOffset;
    }
    alias LPRASSUBENTRYW = RASSUBENTRYW*;

    struct RASSUBENTRYA{
        DWORD dwSize;
        DWORD dwfFlags;
        CHAR[RAS_MaxDeviceType + 1] szDeviceType = 0;
        CHAR[RAS_MaxDeviceName + 1] szDeviceName = 0;
        CHAR[RAS_MaxPhoneNumber + 1] szLocalPhoneNumber = 0;
        DWORD dwAlternateOffset;
    }
    alias LPRASSUBENTRYA = RASSUBENTRYA*;

    struct RASCREDENTIALSW{
        DWORD dwSize;
        DWORD dwMask;
        WCHAR[UNLEN + 1] szUserName = 0;
        WCHAR[PWLEN + 1] szPassword = 0;
        WCHAR[DNLEN + 1] szDomain = 0;
    }
    alias LPRASCREDENTIALSW = RASCREDENTIALSW*;

    struct RASCREDENTIALSA{
        DWORD dwSize;
        DWORD dwMask;
        CHAR[UNLEN + 1] szUserName = 0;
        CHAR[PWLEN + 1] szPassword = 0;
        CHAR[DNLEN + 1] szDomain = 0;
    }
    alias LPRASCREDENTIALSA = RASCREDENTIALSA*;

    struct RASAUTODIALENTRYW{
        DWORD dwSize;
        DWORD dwFlags;
        DWORD dwDialingLocation;
        WCHAR[RAS_MaxEntryName + 1] szEntry = 0;
    }
    alias LPRASAUTODIALENTRYW = RASAUTODIALENTRYW*;

    struct RASAUTODIALENTRYA{
        DWORD dwSize;
        DWORD dwFlags;
        DWORD dwDialingLocation;
        CHAR[RAS_MaxEntryName + 1] szEntry = 0;
    }
    alias LPRASAUTODIALENTRYA = RASAUTODIALENTRYA*;
//}

//static if (_WIN32_WINNT >= 0x500) {
    struct RASPPPCCP{
        DWORD dwSize;
        DWORD dwError;
        DWORD dwCompressionAlgorithm;
        DWORD dwOptions;
        DWORD dwServerCompressionAlgorithm;
        DWORD dwServerOptions;
    }
    alias LPRASPPPCCP = RASPPPCCP*;

    struct RASEAPUSERIDENTITYW{
        WCHAR[UNLEN + 1] szUserName = 0;
        DWORD dwSizeofEapInfo;
        BYTE[1] pbEapInfo;
    }
    alias LPRASEAPUSERIDENTITYW = RASEAPUSERIDENTITYW*;

    struct RASEAPUSERIDENTITYA{
        CHAR[UNLEN + 1] szUserName = 0;
        DWORD dwSizeofEapInfo;
        BYTE[1] pbEapInfo;
    }
    alias LPRASEAPUSERIDENTITYA = RASEAPUSERIDENTITYA*;

    struct RAS_STATS{
        DWORD dwSize;
        DWORD dwBytesXmited;
        DWORD dwBytesRcved;
        DWORD dwFramesXmited;
        DWORD dwFramesRcved;
        DWORD dwCrcErr;
        DWORD dwTimeoutErr;
        DWORD dwAlignmentErr;
        DWORD dwHardwareOverrunErr;
        DWORD dwFramingErr;
        DWORD dwBufferOverrunErr;
        DWORD dwCompressionRatioIn;
        DWORD dwCompressionRatioOut;
        DWORD dwBps;
        DWORD dwConnectDuration;
    }
    alias PRAS_STATS = RAS_STATS*;
//}


/* UNICODE typedefs for structures*/
version (Unicode) {
    alias RASCONN = RASCONNW;
    alias RASENTRY = RASENTRYW;
    alias RASCONNSTATUS = RASCONNSTATUSW;
    alias RASDIALPARAMS = RASDIALPARAMSW;
    alias RASAMB = RASAMBW;
    alias RASPPPNBF = RASPPPNBFW;
    alias RASPPPIPX = RASPPPIPXW;
    alias RASPPPIP = RASPPPIPW;
    alias RASPPPLCP = RASPPPLCPW;
    alias RASSLIP = RASSLIPW;
    alias RASDEVINFO = RASDEVINFOW;
    alias RASENTRYNAME = RASENTRYNAMEW;

    //static if (_WIN32_WINNT >= 0x401) {
        alias RASSUBENTRY = RASSUBENTRYW;
        alias RASCREDENTIALS = RASCREDENTIALSW;
        alias RASAUTODIALENTRY = RASAUTODIALENTRYW;
    //}

    //static if (_WIN32_WINNT >= 0x500) {
        alias RASEAPUSERIDENTITY = RASEAPUSERIDENTITYW;
    //}

} else { // ! defined UNICODE

    alias RASCONN = RASCONNA;
    alias RASENTRY = RASENTRYA;
    alias RASCONNSTATUS = RASCONNSTATUSA;
    alias RASDIALPARAMS = RASDIALPARAMSA;
    alias RASAMB = RASAMBA;
    alias RASPPPNBF = RASPPPNBFA;
    alias RASPPPIPX = RASPPPIPXA;
    alias RASPPPIP = RASPPPIPA;
    alias RASPPPLCP = RASPPPLCPA;
    alias RASSLIP = RASSLIPA;
    alias RASDEVINFO = RASDEVINFOA;
    alias RASENTRYNAME = RASENTRYNAMEA;

    //static if (_WIN32_WINNT >= 0x401) {
        alias RASSUBENTRY = RASSUBENTRYA;
        alias RASCREDENTIALS = RASCREDENTIALSA;
        alias RASAUTODIALENTRY = RASAUTODIALENTRYA;
    //}
    //static if (_WIN32_WINNT >= 0x500) {
        alias RASEAPUSERIDENTITY = RASEAPUSERIDENTITYA;
    //}
}// ! UNICODE


alias LPRASCONN = RASCONN*;
alias LPRASENTRY = RASENTRY*;
alias LPRASCONNSTATUS = RASCONNSTATUS*;
alias LPRASDIALPARAMS = RASDIALPARAMS*;
alias LPRASAM = RASAMB*;
alias LPRASPPPNBF = RASPPPNBF*;
alias LPRASPPPIPX = RASPPPIPX*;
alias LPRASPPPIP = RASPPPIP*;
alias LPRASPPPLCP = RASPPPLCP*;
alias LPRASSLIP = RASSLIP*;
alias LPRASDEVINFO = RASDEVINFO*;
alias LPRASENTRYNAME = RASENTRYNAME*;

//static if (_WIN32_WINNT >= 0x401) {
    alias LPRASSUBENTRY = RASSUBENTRY*;
    alias LPRASCREDENTIALS = RASCREDENTIALS*;
    alias LPRASAUTODIALENTRY = RASAUTODIALENTRY*;
//}
//static if (_WIN32_WINNT >= 0x500) {
    alias LPRASEAPUSERIDENTITY = RASEAPUSERIDENTITY*;
//}

/* Callback prototypes */
extern (Windows) { /* WINAPI */
    deprecated {
        alias ORASADFUNC = BOOL function (HWND, LPSTR, DWORD, LPDWORD);
    }

    alias RASDIALFUNC = void function (UINT, RASCONNSTATE, DWORD);
    alias RASDIALFUNC1 = void function(HRASCONN, UINT, RASCONNSTATE, DWORD, DWORD);
    alias RASDIALFUNC2 = DWORD function (ULONG_PTR, DWORD, HRASCONN, UINT,
    RASCONNSTATE, DWORD, DWORD);

    /* External functions */
    DWORD RasDialA(LPRASDIALEXTENSIONS, LPCSTR, LPRASDIALPARAMSA, DWORD, LPVOID, LPHRASCONN);
    DWORD RasDialW(LPRASDIALEXTENSIONS, LPCWSTR, LPRASDIALPARAMSW, DWORD, LPVOID, LPHRASCONN);
    DWORD RasEnumConnectionsA(LPRASCONNA, LPDWORD, LPDWORD);
    DWORD RasEnumConnectionsW(LPRASCONNW, LPDWORD, LPDWORD);
    DWORD RasEnumEntriesA(LPCSTR, LPCSTR, LPRASENTRYNAMEA, LPDWORD, LPDWORD);
    DWORD RasEnumEntriesW(LPCWSTR, LPCWSTR, LPRASENTRYNAMEW, LPDWORD, LPDWORD);
    DWORD RasGetConnectStatusA(HRASCONN, LPRASCONNSTATUSA);
    DWORD RasGetConnectStatusW(HRASCONN, LPRASCONNSTATUSW);
    DWORD RasGetErrorStringA(UINT, LPSTR, DWORD);
    DWORD RasGetErrorStringW(UINT, LPWSTR, DWORD);
    DWORD RasHangUpA(HRASCONN);
    DWORD RasHangUpW(HRASCONN);
    DWORD RasGetProjectionInfoA(HRASCONN, RASPROJECTION, LPVOID, LPDWORD);
    DWORD RasGetProjectionInfoW(HRASCONN, RASPROJECTION, LPVOID, LPDWORD);
    DWORD RasCreatePhonebookEntryA(HWND, LPCSTR);
    DWORD RasCreatePhonebookEntryW(HWND, LPCWSTR);
    DWORD RasEditPhonebookEntryA(HWND, LPCSTR, LPCSTR);
    DWORD RasEditPhonebookEntryW(HWND, LPCWSTR, LPCWSTR);
    DWORD RasSetEntryDialParamsA(LPCSTR, LPRASDIALPARAMSA, BOOL);
    DWORD RasSetEntryDialParamsW(LPCWSTR, LPRASDIALPARAMSW, BOOL);
    DWORD RasGetEntryDialParamsA(LPCSTR, LPRASDIALPARAMSA, LPBOOL);
    DWORD RasGetEntryDialParamsW(LPCWSTR, LPRASDIALPARAMSW, LPBOOL);
    DWORD RasEnumDevicesA(LPRASDEVINFOA, LPDWORD, LPDWORD);
    DWORD RasEnumDevicesW(LPRASDEVINFOW, LPDWORD, LPDWORD);
    DWORD RasGetCountryInfoA(LPRASCTRYINFOA, LPDWORD);
    DWORD RasGetCountryInfoW(LPRASCTRYINFOW, LPDWORD);
    DWORD RasGetEntryPropertiesA(LPCSTR, LPCSTR, LPRASENTRYA, LPDWORD, LPBYTE, LPDWORD);
    DWORD RasGetEntryPropertiesW(LPCWSTR, LPCWSTR, LPRASENTRYW, LPDWORD, LPBYTE, LPDWORD);
    DWORD RasSetEntryPropertiesA(LPCSTR, LPCSTR, LPRASENTRYA, DWORD, LPBYTE, DWORD);
    DWORD RasSetEntryPropertiesW(LPCWSTR, LPCWSTR, LPRASENTRYW, DWORD, LPBYTE, DWORD);
    DWORD RasRenameEntryA(LPCSTR, LPCSTR, LPCSTR);
    DWORD RasRenameEntryW(LPCWSTR, LPCWSTR, LPCWSTR);
    DWORD RasDeleteEntryA(LPCSTR, LPCSTR);
    DWORD RasDeleteEntryW(LPCWSTR, LPCWSTR);
    DWORD RasValidateEntryNameA(LPCSTR, LPCSTR);
    DWORD RasValidateEntryNameW(LPCWSTR, LPCWSTR);

//static if (_WIN32_WINNT >= 0x401) {
    alias RASADFUNCA = BOOL function(LPSTR, LPSTR, LPRASADPARAMS, LPDWORD);
    alias RASADFUNCW = BOOL function(LPWSTR, LPWSTR, LPRASADPARAMS, LPDWORD);

    DWORD RasGetSubEntryHandleA(HRASCONN, DWORD, LPHRASCONN);
    DWORD RasGetSubEntryHandleW(HRASCONN, DWORD, LPHRASCONN);
    DWORD RasGetCredentialsA(LPCSTR, LPCSTR, LPRASCREDENTIALSA);
    DWORD RasGetCredentialsW(LPCWSTR, LPCWSTR, LPRASCREDENTIALSW);
    DWORD RasSetCredentialsA(LPCSTR, LPCSTR, LPRASCREDENTIALSA, BOOL);
    DWORD RasSetCredentialsW(LPCWSTR, LPCWSTR, LPRASCREDENTIALSW, BOOL);
    DWORD RasConnectionNotificationA(HRASCONN, HANDLE, DWORD);
    DWORD RasConnectionNotificationW(HRASCONN, HANDLE, DWORD);
    DWORD RasGetSubEntryPropertiesA(LPCSTR, LPCSTR, DWORD, LPRASSUBENTRYA, LPDWORD, LPBYTE, LPDWORD);
    DWORD RasGetSubEntryPropertiesW(LPCWSTR, LPCWSTR, DWORD, LPRASSUBENTRYW, LPDWORD, LPBYTE, LPDWORD);
    DWORD RasSetSubEntryPropertiesA(LPCSTR, LPCSTR, DWORD, LPRASSUBENTRYA, DWORD, LPBYTE, DWORD);
    DWORD RasSetSubEntryPropertiesW(LPCWSTR, LPCWSTR, DWORD, LPRASSUBENTRYW, DWORD, LPBYTE, DWORD);
    DWORD RasGetAutodialAddressA(LPCSTR, LPDWORD, LPRASAUTODIALENTRYA, LPDWORD, LPDWORD);
    DWORD RasGetAutodialAddressW(LPCWSTR, LPDWORD, LPRASAUTODIALENTRYW, LPDWORD, LPDWORD);
    DWORD RasSetAutodialAddressA(LPCSTR, DWORD, LPRASAUTODIALENTRYA, DWORD, DWORD);
    DWORD RasSetAutodialAddressW(LPCWSTR, DWORD, LPRASAUTODIALENTRYW, DWORD, DWORD);
    DWORD RasEnumAutodialAddressesA(LPSTR*, LPDWORD, LPDWORD);
    DWORD RasEnumAutodialAddressesW(LPWSTR*, LPDWORD, LPDWORD);
    DWORD RasGetAutodialEnableA(DWORD, LPBOOL);
    DWORD RasGetAutodialEnableW(DWORD, LPBOOL);
    DWORD RasSetAutodialEnableA(DWORD, BOOL);
    DWORD RasSetAutodialEnableW(DWORD, BOOL);
    DWORD RasGetAutodialParamA(DWORD, LPVOID, LPDWORD);
    DWORD RasGetAutodialParamW(DWORD, LPVOID, LPDWORD);
    DWORD RasSetAutodialParamA(DWORD, LPVOID, DWORD);
    DWORD RasSetAutodialParamW(DWORD, LPVOID, DWORD);
//}

static if (_WIN32_WINNT >= 0x500) {
    alias RasCustomHangUpFn = DWORD function(HRASCONN);
    alias RasCustomDeleteEntryNotifyFn = DWORD function(LPCTSTR, LPCTSTR, DWORD);
    alias RasCustomDialFn = DWORD function(HINSTANCE, LPRASDIALEXTENSIONS, LPCTSTR, LPRASDIALPARAMS, DWORD, LPVOID,
                         LPHRASCONN, DWORD);

    DWORD RasInvokeEapUI(HRASCONN, DWORD, LPRASDIALEXTENSIONS, HWND);
    DWORD RasGetLinkStatistics(HRASCONN, DWORD, RAS_STATS*);
    DWORD RasGetConnectionStatistics(HRASCONN, RAS_STATS*);
    DWORD RasClearLinkStatistics(HRASCONN, DWORD);
    DWORD RasClearConnectionStatistics(HRASCONN);
    DWORD RasGetEapUserDataA(HANDLE, LPCSTR, LPCSTR, BYTE*, DWORD*);
    DWORD RasGetEapUserDataW(HANDLE, LPCWSTR, LPCWSTR, BYTE*, DWORD*);
    DWORD RasSetEapUserDataA(HANDLE, LPCSTR, LPCSTR, BYTE*, DWORD);
    DWORD RasSetEapUserDataW(HANDLE, LPCWSTR, LPCWSTR, BYTE*, DWORD);
    DWORD RasGetCustomAuthDataA(LPCSTR, LPCSTR, BYTE*, DWORD*);
    DWORD RasGetCustomAuthDataW(LPCWSTR, LPCWSTR, BYTE*, DWORD*);
    DWORD RasSetCustomAuthDataA(LPCSTR, LPCSTR, BYTE*, DWORD);
    DWORD RasSetCustomAuthDataW(LPCWSTR, LPCWSTR, BYTE*, DWORD);
    DWORD RasGetEapUserIdentityW(LPCWSTR, LPCWSTR, DWORD, HWND, LPRASEAPUSERIDENTITYW*);
    DWORD RasGetEapUserIdentityA(LPCSTR, LPCSTR, DWORD, HWND, LPRASEAPUSERIDENTITYA*);
    void RasFreeEapUserIdentityW(LPRASEAPUSERIDENTITYW);
    void RasFreeEapUserIdentityA(LPRASEAPUSERIDENTITYA);
}
} // extern (Windows)


/* UNICODE defines for functions */
version (Unicode) {
    alias RasDial = RasDialW;
    alias RasEnumConnections = RasEnumConnectionsW;
    alias RasEnumEntries = RasEnumEntriesW;
    alias RasGetConnectStatus = RasGetConnectStatusW;
    alias RasGetErrorString = RasGetErrorStringW;
    alias RasHangUp = RasHangUpW;
    alias RasGetProjectionInfo = RasGetProjectionInfoW;
    alias RasCreatePhonebookEntry = RasCreatePhonebookEntryW;
    alias RasEditPhonebookEntry = RasEditPhonebookEntryW;
    alias RasSetEntryDialParams = RasSetEntryDialParamsW;
    alias RasGetEntryDialParams = RasGetEntryDialParamsW;
    alias RasEnumDevices = RasEnumDevicesW;
    alias RasGetCountryInfo = RasGetCountryInfoW;
    alias RasGetEntryProperties = RasGetEntryPropertiesW;
    alias RasSetEntryProperties = RasSetEntryPropertiesW;
    alias RasRenameEntry = RasRenameEntryW;
    alias RasDeleteEntry = RasDeleteEntryW;
    alias RasValidateEntryName = RasValidateEntryNameW;

    //static if (_WIN32_WINNT >= 0x401) {
        alias RASADFUNC = RASADFUNCW;
        alias RasGetSubEntryHandle = RasGetSubEntryHandleW;
        alias RasConnectionNotification = RasConnectionNotificationW;
        alias RasGetSubEntryProperties = RasGetSubEntryPropertiesW;
        alias RasSetSubEntryProperties = RasSetSubEntryPropertiesW;
        alias RasGetCredentials = RasGetCredentialsW;
        alias RasSetCredentials = RasSetCredentialsW;
        alias RasGetAutodialAddress = RasGetAutodialAddressW;
        alias RasSetAutodialAddress = RasSetAutodialAddressW;
        alias RasEnumAutodialAddresses = RasEnumAutodialAddressesW;
        alias RasGetAutodialEnable = RasGetAutodialEnableW;
        alias RasSetAutodialEnable = RasSetAutodialEnableW;
        alias RasGetAutodialParam = RasGetAutodialParamW;
        alias RasSetAutodialParam = RasSetAutodialParamW;
    //}

    //static if (_WIN32_WINNT >= 0x500) {
        alias RasGetEapUserData = RasGetEapUserDataW;
        alias RasSetEapUserData = RasSetEapUserDataW;
        alias RasGetCustomAuthData = RasGetCustomAuthDataW;
        alias RasSetCustomAuthData = RasSetCustomAuthDataW;
        alias RasGetEapUserIdentity = RasGetEapUserIdentityW;
        alias RasFreeEapUserIdentity = RasFreeEapUserIdentityW;
    //}

} else { // !Unicode
    alias RasDial = RasDialA;
    alias RasEnumConnections = RasEnumConnectionsA;
    alias RasEnumEntries = RasEnumEntriesA;
    alias RasGetConnectStatus = RasGetConnectStatusA;
    alias RasGetErrorString = RasGetErrorStringA;
    alias RasHangUp = RasHangUpA;
    alias RasGetProjectionInfo = RasGetProjectionInfoA;
    alias RasCreatePhonebookEntry = RasCreatePhonebookEntryA;
    alias RasEditPhonebookEntry = RasEditPhonebookEntryA;
    alias RasSetEntryDialParams = RasSetEntryDialParamsA;
    alias RasGetEntryDialParams = RasGetEntryDialParamsA;
    alias RasEnumDevices = RasEnumDevicesA;
    alias RasGetCountryInfo = RasGetCountryInfoA;
    alias RasGetEntryProperties = RasGetEntryPropertiesA;
    alias RasSetEntryProperties = RasSetEntryPropertiesA;
    alias RasRenameEntry = RasRenameEntryA;
    alias RasDeleteEntry = RasDeleteEntryA;
    alias RasValidateEntryName = RasValidateEntryNameA;

    //static if (_WIN32_WINNT >= 0x401) {
        alias RASADFUNC = RASADFUNCA;
        alias RasGetSubEntryHandle = RasGetSubEntryHandleA;
        alias RasConnectionNotification = RasConnectionNotificationA;
        alias RasGetSubEntryProperties = RasGetSubEntryPropertiesA;
        alias RasSetSubEntryProperties = RasSetSubEntryPropertiesA;
        alias RasGetCredentials = RasGetCredentialsA;
        alias RasSetCredentials = RasSetCredentialsA;
        alias RasGetAutodialAddress = RasGetAutodialAddressA;
        alias RasSetAutodialAddress = RasSetAutodialAddressA;
        alias RasEnumAutodialAddresses = RasEnumAutodialAddressesA;
        alias RasGetAutodialEnable = RasGetAutodialEnableA;
        alias RasSetAutodialEnable = RasSetAutodialEnableA;
        alias RasGetAutodialParam = RasGetAutodialParamA;
        alias RasSetAutodialParam = RasSetAutodialParamA;
    //}

    //static if (_WIN32_WINNT >= 0x500) {
        alias RasGetEapUserData = RasGetEapUserDataA;
        alias RasSetEapUserData = RasSetEapUserDataA;
        alias RasGetCustomAuthData = RasGetCustomAuthDataA;
        alias RasSetCustomAuthData = RasSetCustomAuthDataA;
        alias RasGetEapUserIdentity = RasGetEapUserIdentityA;
        alias RasFreeEapUserIdentity = RasFreeEapUserIdentityA;
    //}
} //#endif // !Unicode
