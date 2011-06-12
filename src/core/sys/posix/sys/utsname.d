module core.sys.posix.sys.utsname;

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
}
