/**
* D header file for POSIX.
*
* Copyright: Copyright Neven Miculinić.
* License: $(WEB www.boost.org/LICENSE_1_0.txt, Boost License 1.0).
* Authors: Neven Miculinić
* Standards: The Open Group Base Specifications Issue 6, IEEE Std 1003.1, 2004 Edition
*/

/* Copyright Neven Miculnić 2014.
* Distributed under the Boost Software License, Version 1.0.
* (See accompanying file LICENSE or copy at
* http://www.boost.org/LICENSE_1_0.txt)
*/

/*
* Mostly copied/adapted from 
* /usr/include/linux/msg.h
* /usr/include/x86_64-linux-gnu/sys/msg.h
* constants from headers on Linux Mint x86-64
* manuals
*/

module core.sys.posix.sys.msg;

private import core.sys.posix.sys.ipc;
public import core.sys.posix.sys.types;
public import core.stdc.config;
private import std.conv;

version (Posix):
extern (C):



/* Accorind to manual for msgctl this constants these two constants are linux specific.
/* ipcs ctl commands */
version(Linux) {	
	public enum MSG_STAT = 11;
	public enum MSG_INFO = 12;
}

/* msgrcv options */
public enum MSG_NOERROR =    octal!10000;  /* no error if message is too big */
public enum  MSG_EXCEPT =    octal!20000;  /* recv any msg except of specified type.*/
public enum    MSG_COPY =    octal!40000;  /* copy (not remove) all queue messages */

/* message buffer for msgsnd and msgrcv calls */
struct msgbuf {
	c_long mtype;         /* type of message */
	char mtext[1];      /* message text */
};

/* buffer for msgctl calls IPC_INFO, MSG_INFO */
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
* I have no idea whether this part is correct . 
* See http://pubs.opengroup.org/onlinepubs/7908799/xsh/sysmsg.h.html
*/
alias ushort msgqnum_t;	
alias ushort msglen_t;

struct msqid_ds {
	ipc_perm msg_perm;            /* Ownership and permissions */
	time_t          msg_stime;    /* Time of last msgsnd(2) */
	time_t          msg_rtime;    /* Time of last msgrcv(2) */
	time_t          msg_ctime;    /* Time of last change */
	c_ulong         __msg_cbytes; /* Current number of bytes in queue (nonstandard) */
	msgqnum_t       msg_qnum;     /* Current number of messages in queue */
        msglen_t        msg_qbytes;   /* Maximum number of bytes allowed in queue */
        pid_t           msg_lspid;    /* PID of last msgsnd(2) */
	pid_t           msg_lrpid;    /* PID of last msgrcv(2) */
};

/*
* Scaling factor to compute msgmni:
* the memory dedicated to msg queues (msgmni * msgmnb) should occupy
* at most 1/MSG_MEM_SCALE of the lowmem (see the formula in ipc/msg.c):
* up to 8MB       : msgmni = 16 (MSGMNI)
* 4 GB            : msgmni = 8K
* more than 16 GB : msgmni = 32K (IPCMNI)
*/
public enum MSG_MEM_SCALE =  32;
public enum MSGMNI =     16;   /* <= IPCMNI */     /* max # of msg queue identifiers */
public enum MSGMAX =   8192;   /* <= INT_MAX */   /* max size of message (bytes) */
public enum MSGMNB =  16384;   /* <= INT_MAX */   /* default max size of a message queue */

/* Message queue control operation.  */  
int msgctl (int msqid, int cmd, msqid_ds *__buf);

/* Get messages queue.  */
int msgget ( key_t key, int msgflg );

/* Receive message from message queue. */
ssize_t msgrcv(int msqid, void *msgp, size_t msgsz, c_long msgtyp, int msgflg);

/* Send message to message queue. */
int msgsnd ( int msqid, msgbuf *msgp, int msgsz, int msgflg );
