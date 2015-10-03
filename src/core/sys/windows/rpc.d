/***********************************************************************\
*                                 rpc.d                                 *
*                                                                       *
*                       Windows API header module                       *
*                                                                       *
*                 Translated from MinGW Windows headers                 *
*                                                                       *
*                       Placed into public domain                       *
\***********************************************************************/
module win32.rpc;

/* Moved to rpcdecp (duplicate definition).
	typedef void *I_RPC_HANDLE;
	alias long RPC_STATUS;
	// Moved to rpcdce:
	RpcImpersonateClient
	RpcRevertToSelf
*/

public import win32.unknwn;
public import win32.rpcdce;  // also pulls in rpcdcep
public import win32.rpcnsi;
public import win32.rpcnterr;
public import win32.winerror;

alias MIDL_user_allocate midl_user_allocate;
alias MIDL_user_free midl_user_free;

extern (Windows) {
	int I_RpcMapWin32Status(RPC_STATUS);
}
