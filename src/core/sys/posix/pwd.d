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
module core.sys.posix.pwd;

private import core.sys.posix.config;
public import core.sys.posix.sys.types; // for gid_t, uid_t

extern (C):

//
// Required
//
/*
struct passwd
{
    char*   pw_name;
    uid_t   pw_uid;
    gid_t   pw_gid;
    char*   pw_dir;
    char*   pw_shell;
}

passwd* getpwnam(in char*);
passwd* getpwuid(uid_t);
*/

version( linux )
{
    struct passwd
    {
        char*   pw_name;
        char*   pw_passwd;
        uid_t   pw_uid;
        gid_t   pw_gid;
        char*   pw_gecos;
        char*   pw_dir;
        char*   pw_shell;
    }
}
else version( OSX )
{
    struct passwd
    {
        char*   pw_name;
        char*   pw_passwd;
        uid_t   pw_uid;
        gid_t   pw_gid;
        time_t  pw_change;
        char*   pw_class;
        char*   pw_gecos;
        char*   pw_dir;
        char*   pw_shell;
        time_t  pw_expire;
    }
}
else version( FreeBSD )
{
    struct passwd
    {
        char*   pw_name;        /* user name */
        char*   pw_passwd;      /* encrypted password */
        uid_t   pw_uid;         /* user uid */
        gid_t   pw_gid;         /* user gid */
        time_t  pw_change;      /* password change time */
        char*   pw_class;       /* user access class */
        char*   pw_gecos;       /* Honeywell login info */
        char*   pw_dir;     /* home directory */
        char*   pw_shell;       /* default shell */
        time_t  pw_expire;      /* account expiration */
        int pw_fields;      /* internal: fields filled in */
    }
}

version( Posix )
{
    passwd* getpwnam(in char*);
    passwd* getpwuid(uid_t);
}

//
// Thread-Safe Functions (TSF)
//
/*
int getpwnam_r(in char*, passwd*, char*, size_t, passwd**);
int getpwuid_r(uid_t, passwd*, char*, size_t, passwd**);
*/

version( linux )
{
    int getpwnam_r(in char*, passwd*, char*, size_t, passwd**);
    int getpwuid_r(uid_t, passwd*, char*, size_t, passwd**);
}
else version( OSX )
{
    int getpwnam_r(in char*, passwd*, char*, size_t, passwd**);
    int getpwuid_r(uid_t, passwd*, char*, size_t, passwd**);
}
else version( FreeBSD )
{
    int getpwnam_r(in char*, passwd*, char*, size_t, passwd**);
    int getpwuid_r(uid_t, passwd*, char*, size_t, passwd**);
}
//
// XOpen (XSI)
//
/*
void    endpwent();
passwd* getpwent();
void    setpwent();
*/

version( linux )
{
    void    endpwent();
    passwd* getpwent();
    void    setpwent();
}
else version ( OSX )
{
    void    endpwent();
    passwd* getpwent();
    void    setpwent();
}
else version ( FreeBSD )
{
    void    endpwent();
    passwd* getpwent();
    void    setpwent();
}
