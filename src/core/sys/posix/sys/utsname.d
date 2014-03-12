module core.sys.posix.sys.utsname;

version (Posix):

extern (C)
{
    version(linux)
    {
        private enum utsNameLength = 65;

        struct utsname
        {
            char sysname[utsNameLength];
            char nodename[utsNameLength];
            char release[utsNameLength];
            // The field name is version but version is a keyword in D.
            char update[utsNameLength];
            char machine[utsNameLength];

            char __domainname[utsNameLength];
        }

        int uname(utsname* __name);
    }
    else version(OSX)
    {
        private enum utsNameLength = 256;

        struct utsname
        {
            char sysname[utsNameLength];
            char nodename[utsNameLength];
            char release[utsNameLength];
            // The field name is version but version is a keyword in D.
            char update[utsNameLength];
            char machine[utsNameLength];
        }

        int uname(utsname* __name);
    }
    else version(FreeBSD)
    {
        private enum utsNameLength = 32;

        struct utsname
        {
            char sysname[utsNameLength];
            char nodename[utsNameLength];
            char release[utsNameLength];
            // The field name is version but version is a keyword in D.
            char update[utsNameLength];
            char machine[utsNameLength];
        }

        int uname(utsname* __name);
    }
    else version(Android)
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
}
