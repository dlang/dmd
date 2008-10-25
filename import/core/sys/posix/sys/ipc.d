/**
 * D header file for POSIX.
 *
 * Copyright: Public Domain
 * License:   Public Domain
 * Authors:   Sean Kelly
 * Standards: The Open Group Base Specifications Issue 6, IEEE Std 1003.1, 2004 Edition
 */
module core.sys.posix.sys.ipc;

private import core.sys.posix.config;
public import core.sys.posix.sys.types; // for uid_t, gid_t, mode_t, key_t

extern (C):

//
// XOpen (XSI)
//
/*
struct ipc_perm
{
    uid_t    uid;
    gid_t    gid;
    uid_t    cuid;
    gid_t    cgid;
    mode_t   mode;
}

IPC_CREAT
IPC_EXCL
IPC_NOWAIT

IPC_PRIVATE

IPC_RMID
IPC_SET
IPC_STAT

key_t ftok(in char*, int);
*/

version( linux )
{
    struct ipc_perm
    {
        key_t   __key;
        uid_t   uid;
        gid_t   gid;
        uid_t   cuid;
        gid_t   cgid;
        ushort  mode;
        ushort  __pad1;
        ushort  __seq;
        ushort  __pad2;
        c_ulong __unused1;
        c_ulong __unused2;
    }

    const IPC_CREAT     = 01000;
    const IPC_EXCL      = 02000;
    const IPC_NOWAIT    = 04000;

    const key_t IPC_PRIVATE = 0;

    const IPC_RMID      = 0;
    const IPC_SET       = 1;
    const IPC_STAT      = 2;

    key_t ftok(in char*, int);
}
else version( darwin )
{

}
else version( freebsd )
{
    struct ipc_perm
    {
        ushort cuid;
        ushort cguid;
        ushort uid;
        ushort gid;
        ushort mode;
        ushort seq;
        key_t key;
    }

    const IPC_CREAT     = 01000;
    const IPC_EXCL      = 02000;
    const IPC_NOWAIT    = 04000;

    const key_t IPC_PRIVATE = 0;

    const IPC_RMID      = 0;
    const IPC_SET       = 1;
    const IPC_STAT      = 2;

    key_t ftok(in char*, int);
}
