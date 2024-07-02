import core.stdc.stdio;

version (OSX)
    version = Apple;
version (iOS)
    version = Apple;
version (TVOS)
    version = Apple;
version (WatchOS)
    version = Apple;

struct MemberInfo
{
    string name;
    size_t offset;
    size_t size;
    size_t bitoffset;
    size_t bitsize;
}
struct RecordInfo
{
    string kind;
    string name;
    string modulename;
    size_t size;
    immutable(MemberInfo)[] members;
}

template collectTypes(string modulename)
{
    immutable RecordInfo[] collectTypes = () {
        RecordInfo[] r;
        mixin("import M = " ~ modulename ~ ";");
        static foreach (member; __traits(allMembers, M))
        {
            static if (__traits(compiles, {__traits(getMember, M, member) x;})
                && __traits(compiles, __traits(getMember, M, member).sizeof))
            {{
                alias T = __traits(getMember, M, member);
                string kind;
                if (is(T == struct))
                    kind = "struct";
                else if (is(T == union))
                    kind = "union";
                else if (is(T == enum))
                    kind = "enum";
                r ~= RecordInfo(kind, member, modulename, T.sizeof);
                static if (is(T == struct) || is(T == union))
                {
                    static foreach (member2; T.tupleof)
                    {{
                        MemberInfo memberInfo = MemberInfo(__traits(identifier, member2), member2.offsetof, member2.sizeof);
                        static if (__traits(compiles, __traits(isBitfield, member2)))
                        {
                            static if (__traits(isBitfield, member2))
                            {
                                memberInfo.bitoffset = member2.bitoffsetof;
                                memberInfo.bitsize = member2.bitwidth;
                            }
                        }
                        r[$ - 1].members ~= memberInfo;
                    }}
                }
            }}
        }
        return r;
    }();
}

// Some helper functions, so this druntime test does not depend on phobos.
const(char)* toStringz(string s)
{
    return (s ~ "\0").ptr;
}
bool startsWith(string a, string b)
{
    return a.length >= b.length && a[0 .. b.length] == b;
}
bool canFind(string a, string b)
{
    foreach (i; 0 .. a.length)
    {
        if (a[i .. $].startsWith(b))
            return true;
    }
    return false;
}

int main()
{
    RecordInfo[string] importcInfos;
    foreach (info; collectTypes!"importc_includes")
    {
        if (info.name.startsWith("___realtype_"))
            importcInfos[info.name[12 .. $]] = info;
        else
            importcInfos[info.name] = info;
    }

    bool anyFailure;

    void checkInfos(immutable RecordInfo[] infosD)
    {
        foreach (infoD; infosD)
        {
            auto infoC = infoD.name in importcInfos;
            if (!infoC)
            {
                //printf("Warning: Type %s.%s not found in C\n", infoD.modulename.toStringz, infoD.name.toStringz);
                continue;
            }
            if (infoC.kind.length && infoD.kind != "enum" && infoD.kind != infoC.kind)
            {
                printf("Error: Type %s.%s is %s in C (ImportC), but %s in D\n", infoD.modulename.toStringz, infoD.name.toStringz, infoC.kind.toStringz, infoD.kind.toStringz);
                anyFailure = true;
            }
            bool printLayout;
            if (infoD.size != infoC.size)
            {
                printf("Error: Type %s %s.%s has size %zd in C (ImportC), but size %zd in D\n", infoC.kind.toStringz, infoD.modulename.toStringz, infoD.name.toStringz, infoC.size, infoD.size);
                printLayout = true;
                anyFailure = true;
            }
            MemberInfo[string] memberByNameC;
            foreach (memberC; infoC.members)
                memberByNameC[memberC.name] = memberC;
            foreach (memberD; infoD.members)
            {
                if (memberD.name.canFind("reserved"))
                    continue;
                if (memberD.name.canFind("spare"))
                    continue;
                if (memberD.name.canFind("pad"))
                    continue;
                auto memberC = memberD.name in memberByNameC;
                if (memberC)
                {
                    if (memberC.offset != memberD.offset)
                    {
                        printf("Error: Member %s for type %s %s.%s has offset %zd in C (ImportC), but offset %zd in D\n", memberD.name.toStringz, infoC.kind.toStringz, infoD.modulename.toStringz, infoD.name.toStringz, memberC.offset, memberD.offset);
                        printLayout = true;
                        anyFailure = true;
                    }
                    if (memberC.size != memberD.size)
                    {
                        printf("Error: Member %s for type %s %s.%s has size %zd in C (ImportC), but size %zd in D", memberD.name.toStringz, infoC.kind.toStringz, infoD.modulename.toStringz, infoD.name.toStringz, memberC.size, memberD.size);
                        printLayout = true;
                        anyFailure = true;
                    }
                }
            }
            if (printLayout && (infoC.members.length || infoD.members.length))
            {
                printf("    offset  size  bitoffset bitsize  %20s %20s\n", "ImportC layout".ptr, "D layout".ptr);
                void printInfos(MemberInfo m1, MemberInfo m2)
                {
                    MemberInfo m3 = m1.name.length ? m1 : m2;
                    if (m3.bitsize)
                        printf("     %5zd %5zd      %5zd   %5zd  %20s %20s\n", m3.offset, m3.size, m3.bitoffset, m3.bitsize, m1.name.toStringz, m2.name.toStringz);
                    else
                        printf("     %5zd %5zd      %5s   %5s  %20s %20s\n", m3.offset, m3.size, "".ptr, "".ptr, m1.name.toStringz, m2.name.toStringz);
                }
                immutable(MemberInfo)[] membersC = infoC.members;
                immutable(MemberInfo)[] membersD = infoD.members;
                while (membersC.length || membersD.length)
                {
                    if (membersC.length == 0)
                    {
                        printInfos(MemberInfo.init, membersD[0]);
                        membersD = membersD[1 .. $];
                    }
                    else if (membersD.length == 0)
                    {
                        printInfos(membersC[0], MemberInfo.init);
                        membersC = membersC[1 .. $];
                    }
                    else if (membersC[0].offset == membersD[0].offset
                        && membersC[0].size == membersD[0].size
                        && membersC[0].bitoffset == membersD[0].bitoffset
                        && membersC[0].bitsize == membersD[0].bitsize)
                    {
                        printInfos(membersC[0], membersD[0]);
                        membersC = membersC[1 .. $];
                        membersD = membersD[1 .. $];
                    }
                    else if (membersD[0].offset < membersC[0].offset)
                    {
                        printInfos(MemberInfo.init, membersD[0]);
                        membersD = membersD[1 .. $];
                    }
                    else
                    {
                        printInfos(membersC[0], MemberInfo.init);
                        membersC = membersC[1 .. $];
                    }
                }
            }
        }
    }

    static foreach (modulename; [
        "core.stdc.complex",
        "core.stdc.stdint",
        "core.stdc.stdio",
        "core.stdc.signal",
        "core.stdc.stdlib",
        "core.stdc.limits",
        "core.stdc.locale",
        "core.stdc.fenv",
        "core.stdc.inttypes",
        "core.stdc.string",
        "core.stdc.wctype",
        "core.stdc.config",
        "core.stdc.math",
        "core.stdc.ctype",
        "core.stdc.stddef",
        "core.stdc.stdarg",
        "core.stdc.tgmath",
        "core.stdc.time",
        "core.stdc.wchar_",
        "core.stdc.errno",
        "core.stdc.stdatomic",
        "core.stdc.assert_",
        "core.stdc.float_",
        "core.sys.posix.iconv",
        "core.sys.posix.dlfcn",
        "core.sys.posix.stdio",
        "core.sys.posix.poll",
        "core.sys.posix.strings",
        "core.sys.posix.utime",
        "core.sys.posix.netinet.tcp",
        "core.sys.posix.netinet.in_",
        "core.sys.posix.arpa.inet",
        "core.sys.posix.netdb",
        "core.sys.posix.spawn",
        "core.sys.posix.setjmp",
        "core.sys.posix.ucontext",
        "core.sys.posix.pthread",
        "core.sys.posix.signal",
        "core.sys.posix.stdlib",
        "core.sys.posix.syslog",
        "core.sys.posix.unistd",
        "core.sys.posix.stdc.time",
        "core.sys.posix.fcntl",
        "core.sys.posix.dirent",
        "core.sys.posix.locale",
        "core.sys.posix.sys.ioctl",
        "core.sys.posix.sys.shm",
        "core.sys.posix.sys.resource",
        "core.sys.posix.sys.ttycom",
        "core.sys.posix.sys.ipc",
        "core.sys.posix.sys.un",
        "core.sys.posix.sys.utsname",
        "core.sys.posix.sys.statvfs",
        "core.sys.posix.sys.socket",
        "core.sys.posix.sys.mman",
        "core.sys.posix.sys.stat",
        "core.sys.posix.sys.wait",
        "core.sys.posix.sys.filio",
        "core.sys.posix.sys.msg",
        "core.sys.posix.sys.select",
        "core.sys.posix.sys.time",
        "core.sys.posix.sys.uio",
        "core.sys.posix.sys.ioccom",
        "core.sys.posix.sys.types",
        "core.sys.posix.net.if_",
        "core.sys.posix.inttypes",
        "core.sys.posix.libgen",
        "core.sys.posix.string",
        "core.sys.posix.termios",
        "core.sys.posix.aio",
        "core.sys.posix.config",
        "core.sys.posix.mqueue",
        "core.sys.posix.sched",
        "core.sys.posix.semaphore",
        "core.sys.posix.time",
        "core.sys.posix.pwd",
        "core.sys.posix.grp",
        "core.sys.linux.dlfcn",
        "core.sys.linux.stdio",
        "core.sys.linux.fs",
        "core.sys.linux.netinet.tcp",
        "core.sys.linux.netinet.in_",
        "core.sys.linux.epoll",
        "core.sys.linux.link",
        "core.sys.linux.err",
        "core.sys.linux.io_uring",
        "core.sys.linux.timerfd",
        "core.sys.linux.unistd",
        "core.sys.linux.fcntl",
        "core.sys.linux.sys.file",
        "core.sys.linux.sys.auxv",
        "core.sys.linux.sys.prctl",
        "core.sys.linux.sys.eventfd",
        "core.sys.linux.sys.sysinfo",
        "core.sys.linux.sys.socket",
        "core.sys.linux.sys.mman",
        "core.sys.linux.sys.xattr",
        "core.sys.linux.sys.signalfd",
        "core.sys.linux.sys.time",
        "core.sys.linux.sys.inotify",
        "core.sys.linux.perf_event",
        "core.sys.linux.string",
        "core.sys.linux.termios",
        "core.sys.linux.config",
        "core.sys.linux.tipc",
        "core.sys.linux.sched",
        "core.sys.linux.elf",
        "core.sys.linux.linux.if_packet",
        "core.sys.linux.linux.if_arp",
        "core.sys.linux.time",
        "core.sys.linux.execinfo",
        "core.sys.linux.ifaddrs",
        "core.sys.linux.errno",
        ])
    {
        checkInfos(collectTypes!modulename);
    }
    return anyFailure;
}
