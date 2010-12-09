/**
 * D header file for POSIX.
 *
 * Copyright: Copyright Sean Kelly 2005 - 2009.
 * License:   <a href="http://www.boost.org/LICENSE_1_0.txt">Boost License 1.0</a>.
 * Authors:   Sean Kelly
 * Standards: The Open Group Base Specifications Issue 6, IEEE Std 1003.1, 2004 Edition
 */

/*          Copyright Sean Kelly 2005 - 2009.
 * Distributed under the Boost Software License, Version 1.0.
 *    (See accompanying file LICENSE_1_0.txt or copy at
 *          http://www.boost.org/LICENSE_1_0.txt)
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

    enum IPC_CREAT      = 01000;
    enum IPC_EXCL       = 02000;
    enum IPC_NOWAIT     = 04000;

    enum key_t IPC_PRIVATE = 0;

    enum IPC_RMID       = 0;
    enum IPC_SET        = 1;
    enum IPC_STAT       = 2;

    key_t ftok(in char*, int);
}
else version( OSX )
{

}
else version( FreeBSD )
{
    struct ipc_perm_old // <= FreeBSD7
    {
        ushort cuid;
        ushort cguid;
        ushort uid;
        ushort gid;
        ushort mode;
        ushort seq;
        key_t key;
    }

    struct ipc_perm
    {
        uid_t   cuid;
        gid_t   cgid;
        uid_t   uid;
        gid_t   gid;
        mode_t  mode;
        ushort  seq;
        key_t   key;
    }

    enum IPC_CREAT      = 01000;
    enum IPC_EXCL       = 02000;
    enum IPC_NOWAIT     = 04000;

    enum key_t IPC_PRIVATE = 0;

    enum IPC_RMID       = 0;
    enum IPC_SET        = 1;
    enum IPC_STAT       = 2;

    key_t ftok(in char*, int);
}
