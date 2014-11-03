/**
 * D header file for POSIX.
 *
 * Copyright: Copyright Sean Kelly 2005 - 2009.
 * License:   $(WEB www.boost.org/LICENSE_1_0.txt, Boost License 1.0).
 * Authors:   Sean Kelly, Alex Rønne Petersen
 * Standards: The Open Group Base Specifications Issue 6, IEEE Std 1003.1, 2004 Edition
 */

/*          Copyright Sean Kelly 2005 - 2009.
 * Distributed under the Boost Software License, Version 1.0.
 *    (See accompanying file LICENSE or copy at
 *          http://www.boost.org/LICENSE_1_0.txt)
 */
module core.sys.posix.pwd;

private import core.sys.posix.config;
public import core.sys.posix.sys.types; // for gid_t, uid_t

version (Posix):
extern (C):
nothrow:
@nogc:

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

version( CRuntime_Glibc )
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
else version (Solaris)
{
    struct passwd
    {
        char* pw_name;
        char* pw_passwd;
        uid_t pw_uid;
        gid_t pw_gid;
        char* pw_age;
        char* pw_comment;
        char* pw_gecos;
        char* pw_dir;
        char* pw_shell;
    }
}
else version( CRuntime_Bionic )
{
    struct passwd
    {
        char*   pw_name;
        char*   pw_passwd;
        uid_t   pw_uid;
        gid_t   pw_gid;
        char*   pw_dir;
        char*   pw_shell;
    }
}
else
{
    static assert(false, "Unsupported platform");
}

passwd* getpwnam(in char*);
passwd* getpwuid(uid_t);

//
// Thread-Safe Functions (TSF)
//
/*
int getpwnam_r(in char*, passwd*, char*, size_t, passwd**);
int getpwuid_r(uid_t, passwd*, char*, size_t, passwd**);
*/

version( CRuntime_Glibc )
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
else version (Solaris)
{
    int getpwnam_r(in char*, passwd*, char*, size_t, passwd**);
    int getpwuid_r(uid_t, passwd*, char*, size_t, passwd**);
}
else version( CRuntime_Bionic )
{
}
else
{
    static assert(false, "Unsupported platform");
}

//
// XOpen (XSI)
//
/*
void    endpwent();
passwd* getpwent();
void    setpwent();
*/

version( CRuntime_Glibc )
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
else version (Solaris)
{
    void endpwent();
    passwd* getpwent();
    void setpwent();
}
else version ( CRuntime_Bionic )
{
    void    endpwent();
}
else
{
    static assert(false, "Unsupported platform");
}
