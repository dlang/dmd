/**
 * Windows API header module
 *
 * Translated from MinGW Windows headers
 *
 * License: Placed into public domain
 * Source: $(DRUNTIMESRC src/core/sys/windows/_lmerrlog.d)
 */
module core.sys.windows.lmerrlog;

// COMMENT: This appears to be only for Win16. All functions are deprecated.

private import core.sys.windows.lmcons, core.sys.windows.windef;
private import core.sys.windows.lmaudit; // for LPHLOG

const ERRLOG_BASE=3100;
const ERRLOG2_BASE=5700;
const LOGFLAGS_FORWARD=0;
const LOGFLAGS_BACKWARD=1;
const LOGFLAGS_SEEK=2;
const NELOG_Internal_Error=ERRLOG_BASE;
const NELOG_Resource_Shortage=(ERRLOG_BASE+1);
const NELOG_Unable_To_Lock_Segment=(ERRLOG_BASE+2);
const NELOG_Unable_To_Unlock_Segment=(ERRLOG_BASE+3);
const NELOG_Uninstall_Service=(ERRLOG_BASE+4);
const NELOG_Init_Exec_Fail=(ERRLOG_BASE+5);
const NELOG_Ncb_Error=(ERRLOG_BASE+6);
const NELOG_Net_Not_Started=(ERRLOG_BASE+7);
const NELOG_Ioctl_Error=(ERRLOG_BASE+8);
const NELOG_System_Semaphore=(ERRLOG_BASE+9);
const NELOG_Init_OpenCreate_Err=(ERRLOG_BASE+10);
const NELOG_NetBios=(ERRLOG_BASE+11);
const NELOG_SMB_Illegal=(ERRLOG_BASE+12);
const NELOG_Service_Fail=(ERRLOG_BASE+13);
const NELOG_Entries_Lost=(ERRLOG_BASE+14);
const NELOG_Init_Seg_Overflow=(ERRLOG_BASE+20);
const NELOG_Srv_No_Mem_Grow=(ERRLOG_BASE+21);
const NELOG_Access_File_Bad=(ERRLOG_BASE+22);
const NELOG_Srvnet_Not_Started=(ERRLOG_BASE+23);
const NELOG_Init_Chardev_Err=(ERRLOG_BASE+24);
const NELOG_Remote_API=(ERRLOG_BASE+25);
const NELOG_Ncb_TooManyErr=(ERRLOG_BASE+26);
const NELOG_Mailslot_err=(ERRLOG_BASE+27);
const NELOG_ReleaseMem_Alert=(ERRLOG_BASE+28);
const NELOG_AT_cannot_write=(ERRLOG_BASE+29);
const NELOG_Cant_Make_Msg_File=(ERRLOG_BASE+30);
const NELOG_Exec_Netservr_NoMem=(ERRLOG_BASE+31);
const NELOG_Server_Lock_Failure=(ERRLOG_BASE+32);
const NELOG_Msg_Shutdown=(ERRLOG_BASE+40);
const NELOG_Msg_Sem_Shutdown=(ERRLOG_BASE+41);
const NELOG_Msg_Log_Err=(ERRLOG_BASE+50);
const NELOG_VIO_POPUP_ERR=(ERRLOG_BASE+51);
const NELOG_Msg_Unexpected_SMB_Type=(ERRLOG_BASE+52);
const NELOG_Wksta_Infoseg=(ERRLOG_BASE+60);
const NELOG_Wksta_Compname=(ERRLOG_BASE+61);
const NELOG_Wksta_BiosThreadFailure=(ERRLOG_BASE+62);
const NELOG_Wksta_IniSeg=(ERRLOG_BASE+63);
const NELOG_Wksta_HostTab_Full=(ERRLOG_BASE+64);
const NELOG_Wksta_Bad_Mailslot_SMB=(ERRLOG_BASE+65);
const NELOG_Wksta_UASInit=(ERRLOG_BASE+66);
const NELOG_Wksta_SSIRelogon=(ERRLOG_BASE+67);
const NELOG_Build_Name=(ERRLOG_BASE+70);
const NELOG_Name_Expansion=(ERRLOG_BASE+71);
const NELOG_Message_Send=(ERRLOG_BASE+72);
const NELOG_Mail_Slt_Err=(ERRLOG_BASE+73);
const NELOG_AT_cannot_read=(ERRLOG_BASE+74);
const NELOG_AT_sched_err=(ERRLOG_BASE+75);
const NELOG_AT_schedule_file_created=(ERRLOG_BASE+76);
const NELOG_Srvnet_NB_Open=(ERRLOG_BASE+77);
const NELOG_AT_Exec_Err=(ERRLOG_BASE+78);
const NELOG_Lazy_Write_Err=(ERRLOG_BASE+80);
const NELOG_HotFix=(ERRLOG_BASE+81);
const NELOG_HardErr_From_Server=(ERRLOG_BASE+82);
const NELOG_LocalSecFail1=(ERRLOG_BASE+83);
const NELOG_LocalSecFail2=(ERRLOG_BASE+84);
const NELOG_LocalSecFail3=(ERRLOG_BASE+85);
const NELOG_LocalSecGeneralFail=(ERRLOG_BASE+86);
const NELOG_NetWkSta_Internal_Error=(ERRLOG_BASE+90);
const NELOG_NetWkSta_No_Resource=(ERRLOG_BASE+91);
const NELOG_NetWkSta_SMB_Err=(ERRLOG_BASE+92);
const NELOG_NetWkSta_VC_Err=(ERRLOG_BASE+93);
const NELOG_NetWkSta_Stuck_VC_Err=(ERRLOG_BASE+94);
const NELOG_NetWkSta_NCB_Err=(ERRLOG_BASE+95);
const NELOG_NetWkSta_Write_Behind_Err=(ERRLOG_BASE+96);
const NELOG_NetWkSta_Reset_Err=(ERRLOG_BASE+97);
const NELOG_NetWkSta_Too_Many=(ERRLOG_BASE+98);
const NELOG_Srv_Thread_Failure=(ERRLOG_BASE+104);
const NELOG_Srv_Close_Failure=(ERRLOG_BASE+105);
const NELOG_ReplUserCurDir=(ERRLOG_BASE+106);
const NELOG_ReplCannotMasterDir=(ERRLOG_BASE+107);
const NELOG_ReplUpdateError=(ERRLOG_BASE+108);
const NELOG_ReplLostMaster=(ERRLOG_BASE+109);
const NELOG_NetlogonAuthDCFail=(ERRLOG_BASE+110);
const NELOG_ReplLogonFailed=(ERRLOG_BASE+111);
const NELOG_ReplNetErr=(ERRLOG_BASE+112);
const NELOG_ReplMaxFiles=(ERRLOG_BASE+113);
const NELOG_ReplMaxTreeDepth=(ERRLOG_BASE+114);
const NELOG_ReplBadMsg=(ERRLOG_BASE+115);
const NELOG_ReplSysErr=(ERRLOG_BASE+116);
const NELOG_ReplUserLoged=(ERRLOG_BASE+117);
const NELOG_ReplBadImport=(ERRLOG_BASE+118);
const NELOG_ReplBadExport=(ERRLOG_BASE+119);
const NELOG_ReplSignalFileErr=(ERRLOG_BASE+120);
const NELOG_DiskFT=(ERRLOG_BASE+121);
const NELOG_ReplAccessDenied=(ERRLOG_BASE+122);
const NELOG_NetlogonFailedPrimary=(ERRLOG_BASE+123);
const NELOG_NetlogonPasswdSetFailed=(ERRLOG_BASE+124);
const NELOG_NetlogonTrackingError=(ERRLOG_BASE+125);
const NELOG_NetlogonSyncError=(ERRLOG_BASE+126);
const NELOG_UPS_PowerOut=(ERRLOG_BASE+130);
const NELOG_UPS_Shutdown=(ERRLOG_BASE+131);
const NELOG_UPS_CmdFileError=(ERRLOG_BASE+132);
const NELOG_UPS_CannotOpenDriver=(ERRLOG_BASE+133);
const NELOG_UPS_PowerBack=(ERRLOG_BASE+134);
const NELOG_UPS_CmdFileConfig=(ERRLOG_BASE+135);
const NELOG_UPS_CmdFileExec=(ERRLOG_BASE+136);
const NELOG_Missing_Parameter=(ERRLOG_BASE+150);
const NELOG_Invalid_Config_Line=(ERRLOG_BASE+151);
const NELOG_Invalid_Config_File=(ERRLOG_BASE+152);
const NELOG_File_Changed=(ERRLOG_BASE+153);
const NELOG_Files_Dont_Fit=(ERRLOG_BASE+154);
const NELOG_Wrong_DLL_Version=(ERRLOG_BASE+155);
const NELOG_Error_in_DLL=(ERRLOG_BASE+156);
const NELOG_System_Error=(ERRLOG_BASE+157);
const NELOG_FT_ErrLog_Too_Large=(ERRLOG_BASE+158);
const NELOG_FT_Update_In_Progress=(ERRLOG_BASE+159);
const NELOG_OEM_Code=(ERRLOG_BASE+199);
const NELOG_NetlogonSSIInitError=ERRLOG2_BASE;
const NELOG_NetlogonFailedToUpdateTrustList=(ERRLOG2_BASE+1);
const NELOG_NetlogonFailedToAddRpcInterface=(ERRLOG2_BASE+2);
const NELOG_NetlogonFailedToReadMailslot=(ERRLOG2_BASE+3);
const NELOG_NetlogonFailedToRegisterSC=(ERRLOG2_BASE+4);
const NELOG_NetlogonChangeLogCorrupt=(ERRLOG2_BASE+5);
const NELOG_NetlogonFailedToCreateShare=(ERRLOG2_BASE+6);
const NELOG_NetlogonDownLevelLogonFailed=(ERRLOG2_BASE+7);
const NELOG_NetlogonDownLevelLogoffFailed=(ERRLOG2_BASE+8);
const NELOG_NetlogonNTLogonFailed=(ERRLOG2_BASE+9);
const NELOG_NetlogonNTLogoffFailed=(ERRLOG2_BASE+10);
const NELOG_NetlogonPartialSyncCallSuccess=(ERRLOG2_BASE+11);
const NELOG_NetlogonPartialSyncCallFailed=(ERRLOG2_BASE+12);
const NELOG_NetlogonFullSyncCallSuccess=(ERRLOG2_BASE+13);
const NELOG_NetlogonFullSyncCallFailed=(ERRLOG2_BASE+14);
const NELOG_NetlogonPartialSyncSuccess=(ERRLOG2_BASE+15);
const NELOG_NetlogonPartialSyncFailed=(ERRLOG2_BASE+16);
const NELOG_NetlogonFullSyncSuccess=(ERRLOG2_BASE+17);
const NELOG_NetlogonFullSyncFailed=(ERRLOG2_BASE+18);
const NELOG_NetlogonAuthNoDomainController=(ERRLOG2_BASE+19);
const NELOG_NetlogonAuthNoTrustLsaSecret=(ERRLOG2_BASE+20);
const NELOG_NetlogonAuthNoTrustSamAccount=(ERRLOG2_BASE+21);
const NELOG_NetlogonServerAuthFailed=(ERRLOG2_BASE+22);
const NELOG_NetlogonServerAuthNoTrustSamAccount=(ERRLOG2_BASE+23);
const NELOG_FailedToRegisterSC=(ERRLOG2_BASE+24);
const NELOG_FailedToSetServiceStatus=(ERRLOG2_BASE+25);
const NELOG_FailedToGetComputerName=(ERRLOG2_BASE+26);
const NELOG_DriverNotLoaded=(ERRLOG2_BASE+27);
const NELOG_NoTranportLoaded=(ERRLOG2_BASE+28);
const NELOG_NetlogonFailedDomainDelta=(ERRLOG2_BASE+29);
const NELOG_NetlogonFailedGlobalGroupDelta=(ERRLOG2_BASE+30);
const NELOG_NetlogonFailedLocalGroupDelta=(ERRLOG2_BASE+31);
const NELOG_NetlogonFailedUserDelta=(ERRLOG2_BASE+32);
const NELOG_NetlogonFailedPolicyDelta=(ERRLOG2_BASE+33);
const NELOG_NetlogonFailedTrustedDomainDelta=(ERRLOG2_BASE+34);
const NELOG_NetlogonFailedAccountDelta=(ERRLOG2_BASE+35);
const NELOG_NetlogonFailedSecretDelta=(ERRLOG2_BASE+36);
const NELOG_NetlogonSystemError=(ERRLOG2_BASE+37);
const NELOG_NetlogonDuplicateMachineAccounts=(ERRLOG2_BASE+38);
const NELOG_NetlogonTooManyGlobalGroups=(ERRLOG2_BASE+39);
const NELOG_NetlogonBrowserDriver=(ERRLOG2_BASE+40);
const NELOG_NetlogonAddNameFailure=(ERRLOG2_BASE+41);
const NELOG_RplMessages=(ERRLOG2_BASE+42);
const NELOG_RplXnsBoot=(ERRLOG2_BASE+43);
const NELOG_RplSystem=(ERRLOG2_BASE+44);
const NELOG_RplWkstaTimeout=(ERRLOG2_BASE+45);
const NELOG_RplWkstaFileOpen=(ERRLOG2_BASE+46);
const NELOG_RplWkstaFileRead=(ERRLOG2_BASE+47);
const NELOG_RplWkstaMemory=(ERRLOG2_BASE+48);
const NELOG_RplWkstaFileChecksum=(ERRLOG2_BASE+49);
const NELOG_RplWkstaFileLineCount=(ERRLOG2_BASE+50);
const NELOG_RplWkstaBbcFile=(ERRLOG2_BASE+51);
const NELOG_RplWkstaFileSize=(ERRLOG2_BASE+52);
const NELOG_RplWkstaInternal=(ERRLOG2_BASE+53);
const NELOG_RplWkstaWrongVersion=(ERRLOG2_BASE+54);
const NELOG_RplWkstaNetwork=(ERRLOG2_BASE+55);
const NELOG_RplAdapterResource=(ERRLOG2_BASE+56);
const NELOG_RplFileCopy=(ERRLOG2_BASE+57);
const NELOG_RplFileDelete=(ERRLOG2_BASE+58);
const NELOG_RplFilePerms=(ERRLOG2_BASE+59);
const NELOG_RplCheckConfigs=(ERRLOG2_BASE+60);
const NELOG_RplCreateProfiles=(ERRLOG2_BASE+61);
const NELOG_RplRegistry=(ERRLOG2_BASE+62);
const NELOG_RplReplaceRPLDISK=(ERRLOG2_BASE+63);
const NELOG_RplCheckSecurity=(ERRLOG2_BASE+64);
const NELOG_RplBackupDatabase=(ERRLOG2_BASE+65);
const NELOG_RplInitDatabase=(ERRLOG2_BASE+66);
const NELOG_RplRestoreDatabaseFailure=(ERRLOG2_BASE+67);
const NELOG_RplRestoreDatabaseSuccess=(ERRLOG2_BASE+68);
const NELOG_RplInitRestoredDatabase=(ERRLOG2_BASE+69);
const NELOG_NetlogonSessionTypeWrong=(ERRLOG2_BASE+70);

struct ERROR_LOG {
	DWORD el_len;
	DWORD el_reserved;
	DWORD el_time;
	DWORD el_error;
	LPWSTR el_name;
	LPWSTR el_text;
	LPBYTE el_data;
	DWORD el_data_size;
	DWORD el_nstrings;
}
alias ERROR_LOG* PERROR_LOG, LPERROR_LOG;

extern (Windows) {
	deprecated {
		NET_API_STATUS NetErrorLogClear(LPCWSTR, LPCWSTR, LPBYTE);
		NET_API_STATUS NetErrorLogRead(LPCWSTR, LPWSTR, LPHLOG, DWORD,
		  LPDWORD, DWORD, DWORD, LPBYTE*, DWORD, LPDWORD, LPDWORD);
		NET_API_STATUS NetErrorLogWrite(LPBYTE, DWORD, LPCWSTR, LPBYTE,
		  DWORD, LPBYTE, DWORD, LPBYTE);
	}
}
