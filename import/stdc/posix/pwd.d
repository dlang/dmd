/**
 * D header file for POSIX.
 *
 * Copyright: Public Domain
 * License:   Public Domain
 * Authors:   Sean Kelly
 * Standards: The Open Group Base Specifications Issue 6, IEEE Std 1003.1, 2004 Edition
 */
module stdc.posix.pwd;

private import stdc.posix.config;
public import stdc.posix.sys.types; // for gid_t, uid_t

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
else version( darwin )
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
else version( freebsd )
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

passwd* getpwnam(in char*);
passwd* getpwuid(uid_t);

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
else version( darwin )
{
    int getpwnam_r(in char*, passwd*, char*, size_t, passwd**);
    int getpwuid_r(uid_t, passwd*, char*, size_t, passwd**);
}
else version( freebsd )
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
else version ( darwin )
{
    void    endpwent();
    passwd* getpwent();
    void    setpwent();
}
else version ( freebsd )
{
    void    endpwent();
    passwd* getpwent();
    void    setpwent();
}
