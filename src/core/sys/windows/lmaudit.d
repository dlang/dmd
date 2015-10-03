/***********************************************************************\
*                               lmaudit.d                               *
*                                                                       *
*                       Windows API header module                       *
*                                                                       *
*                 Translated from MinGW Windows headers                 *
*                                                                       *
*                       Placed into public domain                       *
\***********************************************************************/
// COMMENT: This file may be deprecated.
module core.sys.windows.lmaudit;

private import core.sys.windows.lmcons, core.sys.windows.windef;

const LOGFLAGS_FORWARD  = 0;
const LOGFLAGS_BACKWARD = 1;
const LOGFLAGS_SEEK     = 2;

const ACTION_LOCKOUT     = 0;
const ACTION_ADMINUNLOCK = 1;

const AE_GUEST=0;
const AE_USER=1;
const AE_ADMIN=2;
const AE_NORMAL=0;
const AE_USERLIMIT=0;
const AE_GENERAL=0;
const AE_ERROR=1;
const AE_SESSDIS=1;
const AE_BADPW=1;
const AE_AUTODIS=2;
const AE_UNSHARE=2;
const AE_ADMINPRIVREQD=2;
const AE_ADMINDIS=3;
const AE_NOACCESSPERM=3;
const AE_ACCRESTRICT=4;
const AE_NORMAL_CLOSE=0;
const AE_SES_CLOSE=1;
const AE_ADMIN_CLOSE=2;
const AE_LIM_UNKNOWN=0;
const AE_LIM_LOGONHOURS=1;
const AE_LIM_EXPIRED=2;
const AE_LIM_INVAL_WKSTA=3;
const AE_LIM_DISABLED=4;
const AE_LIM_DELETED=5;
const AE_MOD=0;
const AE_DELETE=1;
const AE_ADD=2;

const AE_UAS_USER   = 0;
const AE_UAS_GROUP  = 1;
const AE_UAS_MODALS = 2;

const SVAUD_SERVICE       = 1;
const SVAUD_GOODSESSLOGON = 6;
const SVAUD_BADSESSLOGON  = 24;
const SVAUD_SESSLOGON     = SVAUD_GOODSESSLOGON|SVAUD_BADSESSLOGON;
const SVAUD_GOODNETLOGON  = 96;
const SVAUD_BADNETLOGON   = 384;
const SVAUD_NETLOGON      = SVAUD_GOODNETLOGON|SVAUD_BADNETLOGON;
const SVAUD_LOGON         = SVAUD_NETLOGON|SVAUD_SESSLOGON;
const SVAUD_GOODUSE       = 0x600;
const SVAUD_BADUSE        = 0x1800;
const SVAUD_USE           = SVAUD_GOODUSE|SVAUD_BADUSE;
const SVAUD_USERLIST      = 8192;
const SVAUD_PERMISSIONS   = 16384;
const SVAUD_RESOURCE      = 32768;
const SVAUD_LOGONLIM      = 65536;

const AA_AUDIT_ALL=1;
const AA_A_OWNER=4;
const AA_CLOSE=8;
const AA_S_OPEN=16;
const AA_S_WRITE=32;
const AA_S_CREATE=32;
const AA_S_DELETE=64;
const AA_S_ACL=128;
const AA_S_ALL=253;
const AA_F_OPEN=256;
const AA_F_WRITE=512;
const AA_F_CREATE=512;
const AA_F_DELETE=1024;
const AA_F_ACL=2048;
const AA_F_ALL = AA_F_OPEN|AA_F_WRITE|AA_F_DELETE|AA_F_ACL;
const AA_A_OPEN=2048;
const AA_A_WRITE=4096;
const AA_A_CREATE=8192;
const AA_A_DELETE=16384;
const AA_A_ACL=32768;
const AA_A_ALL = AA_F_OPEN|AA_F_WRITE|AA_F_DELETE|AA_F_ACL;

struct AUDIT_ENTRY{
	DWORD ae_len;
	DWORD ae_reserved;
	DWORD ae_time;
	DWORD ae_type;
	DWORD ae_data_offset;
	DWORD ae_data_size;
}
alias AUDIT_ENTRY* PAUDIT_ENTRY, LPAUDIT_ENTRY;

struct HLOG{
	DWORD time;
	DWORD last_flags;
	DWORD offset;
	DWORD rec_offset;
}
alias HLOG* PHLOG, LPHLOG;

struct AE_SRVSTATUS{
	DWORD ae_sv_status;
}
alias AE_SRVSTATUS* PAE_SRVSTATUS, LPAE_SRVSTATUS;

struct AE_SESSLOGON{
	DWORD ae_so_compname;
	DWORD ae_so_username;
	DWORD ae_so_privilege;
}
alias AE_SESSLOGON* PAE_SESSLOGON, LPAE_SESSLOGON;

struct AE_SESSLOGOFF{
	DWORD ae_sf_compname;
	DWORD ae_sf_username;
	DWORD ae_sf_reason;
}
alias AE_SESSLOGOFF* PAE_SESSLOGOFF, LPAE_SESSLOGOFF;

struct AE_SESSPWERR{
	DWORD ae_sp_compname;
	DWORD ae_sp_username;
}
alias AE_SESSPWERR* PAE_SESSPWERR, LPAE_SESSPWERR;

struct AE_CONNSTART{
	DWORD ae_ct_compname;
	DWORD ae_ct_username;
	DWORD ae_ct_netname;
	DWORD ae_ct_connid;
}
alias AE_CONNSTART* PAE_CONNSTART, LPAE_CONNSTART;

struct AE_CONNSTOP{
	DWORD ae_cp_compname;
	DWORD ae_cp_username;
	DWORD ae_cp_netname;
	DWORD ae_cp_connid;
	DWORD ae_cp_reason;
}
alias AE_CONNSTOP* PAE_CONNSTOP, LPAE_CONNSTOP;

struct AE_CONNREJ{
	DWORD ae_cr_compname;
	DWORD ae_cr_username;
	DWORD ae_cr_netname;
	DWORD ae_cr_reason;
}
alias AE_CONNREJ* PAE_CONNREJ, LPAE_CONNREJ;

struct AE_RESACCESS{
	DWORD ae_ra_compname;
	DWORD ae_ra_username;
	DWORD ae_ra_resname;
	DWORD ae_ra_operation;
	DWORD ae_ra_returncode;
	DWORD ae_ra_restype;
	DWORD ae_ra_fileid;
}
alias AE_RESACCESS* PAE_RESACCESS, LPAE_RESACCESS;

struct AE_RESACCESSREJ{
	DWORD ae_rr_compname;
	DWORD ae_rr_username;
	DWORD ae_rr_resname;
	DWORD ae_rr_operation;
}
alias AE_RESACCESSREJ* PAE_RESACCESSREJ, LPAE_RESACCESSREJ;

struct AE_CLOSEFILE{
	DWORD ae_cf_compname;
	DWORD ae_cf_username;
	DWORD ae_cf_resname;
	DWORD ae_cf_fileid;
	DWORD ae_cf_duration;
	DWORD ae_cf_reason;
}
alias AE_CLOSEFILE* PAE_CLOSEFILE, LPAE_CLOSEFILE;

struct AE_SERVICESTAT{
	DWORD ae_ss_compname;
	DWORD ae_ss_username;
	DWORD ae_ss_svcname;
	DWORD ae_ss_status;
	DWORD ae_ss_code;
	DWORD ae_ss_text;
	DWORD ae_ss_returnval;
}
alias AE_SERVICESTAT* PAE_SERVICESTAT, LPAE_SERVICESTAT;

struct AE_ACLMOD{
	DWORD ae_am_compname;
	DWORD ae_am_username;
	DWORD ae_am_resname;
	DWORD ae_am_action;
	DWORD ae_am_datalen;
}
alias AE_ACLMOD* PAE_ACLMOD, LPAE_ACLMOD;

struct AE_UASMOD{
	DWORD ae_um_compname;
	DWORD ae_um_username;
	DWORD ae_um_resname;
	DWORD ae_um_rectype;
	DWORD ae_um_action;
	DWORD ae_um_datalen;
}
alias AE_UASMOD* PAE_UASMOD, LPAE_UASMOD;

struct AE_NETLOGON{
	DWORD ae_no_compname;
	DWORD ae_no_username;
	DWORD ae_no_privilege;
	DWORD ae_no_authflags;
}
alias AE_NETLOGON* PAE_NETLOGON, LPAE_NETLOGON;

struct AE_NETLOGOFF{
	DWORD ae_nf_compname;
	DWORD ae_nf_username;
	DWORD ae_nf_reserved1;
	DWORD ae_nf_reserved2;
}
alias AE_NETLOGOFF* PAE_NETLOGOFF, LPAE_NETLOGOFF;

struct AE_ACCLIM{
	DWORD ae_al_compname;
	DWORD ae_al_username;
	DWORD ae_al_resname;
	DWORD ae_al_limit;
}
alias AE_ACCLIM* PAE_ACCLIM, LPAE_ACCLIM;

struct AE_LOCKOUT{
	DWORD ae_lk_compname;
	DWORD ae_lk_username;
	DWORD ae_lk_action;
	DWORD ae_lk_bad_pw_count;
}
alias AE_LOCKOUT* PAE_LOCKOUT, LPAE_LOCKOUT;

struct AE_GENERIC{
	DWORD ae_ge_msgfile;
	DWORD ae_ge_msgnum;
	DWORD ae_ge_params;
	DWORD ae_ge_param1;
	DWORD ae_ge_param2;
	DWORD ae_ge_param3;
	DWORD ae_ge_param4;
	DWORD ae_ge_param5;
	DWORD ae_ge_param6;
	DWORD ae_ge_param7;
	DWORD ae_ge_param8;
	DWORD ae_ge_param9;
}
alias AE_GENERIC* PAE_GENERIC, LPAE_GENERIC;

extern (Windows) {
deprecated {
NET_API_STATUS NetAuditClear(LPCWSTR,LPCWSTR,LPCWSTR);
NET_API_STATUS NetAuditRead(LPTSTR,LPTSTR,LPHLOG,DWORD,PDWORD,DWORD,DWORD,PBYTE*,DWORD,PDWORD,PDWORD);
NET_API_STATUS NetAuditWrite(DWORD,PBYTE,DWORD,LPTSTR,PBYTE);
}
}

/+
/* MinGW: These conflict with struct typedefs, why? */
const AE_SRVSTATUS=0;
const AE_SESSLOGON=1;
const AE_SESSLOGOFF=2;
const AE_SESSPWERR=3;
const AE_CONNSTART=4;
const AE_CONNSTOP=5;
const AE_CONNREJ=6;
const AE_RESACCESS=7;
const AE_RESACCESSREJ=8;
const AE_CLOSEFILE=9;
const AE_SERVICESTAT=11;
const AE_ACLMOD=12;
const AE_UASMOD=13;
const AE_NETLOGON=14;
const AE_NETLOGOFF=15;
const AE_NETLOGDENIED=16;
const AE_ACCLIMITEXCD=17;
const AE_RESACCESS2=18;
const AE_ACLMODFAIL=19;
const AE_LOCKOUT=20;
const AE_GENERIC_TYPE=21;
const AE_SRVSTART=0;
const AE_SRVPAUSED=1;
const AE_SRVCONT=2;
const AE_SRVSTOP=3;
+/