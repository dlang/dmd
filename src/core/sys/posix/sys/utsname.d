module core.sys.posix.sys.utsname;

version (Posix):
extern(C):

version(CRuntime_Glibc)
{
    private enum utsNameLength = 65;

    struct utsname
    {
        char[utsNameLength] sysname;
        char[utsNameLength] nodename;
        char[utsNameLength] release;
        // The field name is version but version is a keyword in D.
        char[utsNameLength] update;
        char[utsNameLength] machine;

        char[utsNameLength] __domainname;
    }

    int uname(utsname* __name);
}
else version(OSX)
{
    private enum utsNameLength = 256;

    struct utsname
    {
        char[utsNameLength] sysname;
        char[utsNameLength] nodename;
        char[utsNameLength] release;
        // The field name is version but version is a keyword in D.
        char[utsNameLength] update;
        char[utsNameLength] machine;
    }

    int uname(utsname* __name);
}
else version(FreeBSD)
{
    private enum utsNameLength = 32;

    struct utsname
    {
        char[utsNameLength] sysname;
        char[utsNameLength] nodename;
        char[utsNameLength] release;
        // The field name is version but version is a keyword in D.
        char[utsNameLength] update;
        char[utsNameLength] machine;
    }

    int uname(utsname* __name);
}
else version(CRuntime_Bionic)
{
    private enum SYS_NMLN = 65;

    struct utsname
    {
        char[SYS_NMLN] sysname;
        char[SYS_NMLN] nodename;
        char[SYS_NMLN] release;
        // The field name is version but version is a keyword in D.
        char[SYS_NMLN] _version;
        char[SYS_NMLN] machine;
        char[SYS_NMLN] domainname;
    }

    int uname(utsname*);
}
