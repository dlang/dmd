/**
* D header file for POSIX.
*
* Authors: Neven Miculinić
*/

module core.sys.posix.sys.msg;

private import core.sys.posix.sys.ipc;
public import core.sys.posix.sys.types;
public import core.stdc.config;
private import std.conv;

version (linux):
extern (C):

public enum MSG_STAT = 11;
public enum MSG_INFO = 12;

public enum MSG_NOERROR =    octal!10000;
public enum  MSG_EXCEPT =    octal!20000;
public enum    MSG_COPY =    octal!40000;

struct msgbuf {
	c_long mtype;    
	char mtext[1];
};

struct msginfo {
	int msgpool;
	int msgmap; 
	int msgmax; 
	int msgmnb; 
	int msgmni; 
	int msgssz; 
	int msgtql; 
	ushort msgseg; 
};

/** 
TODO: fix this in next commit.
*/
alias ushort msgqnum_t;	
alias ushort msglen_t;

struct msqid_ds {
	ipc_perm msg_perm;
	time_t          msg_stime;
	time_t          msg_rtime;
	time_t          msg_ctime;
	c_ulong         __msg_cbytes;
	msgqnum_t       msg_qnum;
        msglen_t        msg_qbytes;
        pid_t           msg_lspid;
	pid_t           msg_lrpid;
};

public enum MSG_MEM_SCALE =  32;
public enum MSGMNI =     16;
public enum MSGMAX =   8192;
public enum MSGMNB =  16384;

int msgctl (int msqid, int cmd, msqid_ds *__buf);
int msgget ( key_t key, int msgflg );
ssize_t msgrcv(int msqid, void *msgp, size_t msgsz, c_long msgtyp, int msgflg);
int msgsnd ( int msqid, msgbuf *msgp, int msgsz, int msgflg );
