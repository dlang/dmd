import core.stdc.stdio : printf;

version (OSX)
    version = Apple;
version (iOS)
    version = Apple;
version (TVOS)
    version = Apple;
version (WatchOS)
    version = Apple;

/*
This test tries to automatically find types with a wrong size in
druntime C bindings. This is done by also getting type sizes from
C headers using ImportC and comparing them. Differences between the
sizes can have different reasons:

* Bugs in ImportC (e.g. for bitfields) can result in a wrong size
* Type definitions in druntime can be wrong
* Different preprocessor options could be used, like _FILE_OFFSET_BITS
* Size differences can be fine, because some structs contain a member
  for the size or a version, see list growingTypes below

Members of structs and unions with the same name are also compared.
For types with potential problems a comparison of the layout is printed.

It is possible, that ImportC and druntime contain the same bug. Those
bugs would not be found by this test.
*/

// Types, which can be bigger in newer headers, because they have a size
// or version field.
immutable string[] growingTypes = [
    "core.sys.linux.perf_event.perf_event_attr",
];

// List of problems, which are known and should only be treated as
// warnings for now.
immutable ErrorFilter[] knownProblems = [
    ErrorFilter("core.stdc.config.c_long_double", "", "Windows", 32, ""),
    ErrorFilter("core.stdc.fenv.fenv_t", "", "FreeBSD", 0, ""),
    ErrorFilter("core.stdc.locale.lconv", "", "Apple", 0, "https://issues.dlang.org/show_bug.cgi?id=24652"),
    ErrorFilter("core.stdc.locale.lconv", "", "FreeBSD", 0, "https://issues.dlang.org/show_bug.cgi?id=24652"),
    ErrorFilter("core.stdc.locale.lconv", "", "Windows", 0, "https://issues.dlang.org/show_bug.cgi?id=24652"),
    ErrorFilter("core.stdc.math.double_t", "", "linux", 0, ""),
    ErrorFilter("core.stdc.math.float_t", "", "linux", 0, ""),
    ErrorFilter("core.stdc.signal.sig_atomic_t", "", "FreeBSD", 0, ""),
    ErrorFilter("core.stdc.stdio.FILE", "", "FreeBSD", 0, ""),
    ErrorFilter("core.stdc.stdio.FILE", "", "linux", 0, ""),
    ErrorFilter("core.stdc.stdio._IO_FILE", "", "linux", 0, ""),
    ErrorFilter("core.stdc.stdio.__sFILE", "", "FreeBSD", 0, ""),
    ErrorFilter("core.stdc.wchar_.mbstate_t", "", "Apple", 0, ""),
    ErrorFilter("core.stdc.wchar_.mbstate_t", "", "Windows", 0, ""),
    ErrorFilter("core.sys.linux.perf_event.perf_event_sample_format", "", "linux", 0, ""),
    ErrorFilter("core.sys.posix.fcntl.flock", "", "linux", 32, ""),
    ErrorFilter("core.sys.posix.sched.sched_param", "", "Apple", 0, ""),
    ErrorFilter("core.sys.posix.semaphore.sem_t", "", "FreeBSD", 0, ""),
    ErrorFilter("core.sys.posix.semaphore.sem_t", "", "linux", 0, ""),
    ErrorFilter("core.sys.posix.signal.siginfo_t", "", "Apple", 0, ""),
    ErrorFilter("core.sys.posix.sys.ipc.ipc_perm", "mode", "linux", 0, ""),
    ErrorFilter("core.sys.posix.sys.shm.shmatt_t", "", "FreeBSD", 0, ""),
    ErrorFilter("core.sys.posix.sys.shm.shmid_ds", "", "FreeBSD", 0, ""),
    ErrorFilter("core.sys.posix.sys.types.clock_t", "", "FreeBSD", 0, ""),
    ErrorFilter("core.sys.posix.sys.types.pthread_barrierattr_t", "", "linux", 0, "See https://issues.dlang.org/show_bug.cgi?id=24593"),
    ErrorFilter("core.sys.posix.sys.types.pthread_barrier_t", "", "linux", 0, "See https://issues.dlang.org/show_bug.cgi?id=24593"),
    ErrorFilter("core.sys.posix.sys.types.pthread_key_t", "", "FreeBSD", 0, ""),
    ErrorFilter("core.sys.posix.sys.types.pthread_once_t", "", "FreeBSD", 0, ""),
    ErrorFilter("core.sys.posix.sys.types.pthread_once_t", "", "FreeBSD", 0, ""),
    ErrorFilter("core.sys.posix.sys.types.pthread_rwlockattr_t", "", "linux", 0, "See https://issues.dlang.org/show_bug.cgi?id=24593"),
    ErrorFilter("core.sys.posix.sys.types.pthread_rwlock_t", "", "linux", 0, "See https://issues.dlang.org/show_bug.cgi?id=24593"),
    ErrorFilter("core.sys.posix.time.timer_t", "", "FreeBSD", 0, ""),
    ErrorFilter("core.sys.posix.ucontext.ucontext_t", "", "Apple", 0, ""),
    ErrorFilter("core.sys.posix.ucontext.ucontext_t", "", "FreeBSD", 0, ""),
];

struct ErrorFilter
{
    string name;
    string member;
    string version_;
    size_t pointerSize;
    string description;
}

immutable ErrorFilter[] knownProblemsFiltered = () {
    immutable(ErrorFilter)[] r;
    static foreach (errorFilter; knownProblems)
    {{
        bool include = true;
        static if (errorFilter.version_.length)
            mixin("version(" ~ errorFilter.version_ ~ ") {} else include = false;");
        if (errorFilter.pointerSize && errorFilter.pointerSize != (void*).sizeof * 8)
            include = false;
        if (include)
            r ~= errorFilter;
    }}
    return r;
}();

bool isKnownProblem(string name, string member, ref string description)
{
    foreach (errorFilter; knownProblemsFiltered)
    {
        if (errorFilter.name == name && errorFilter.member == member)
        {
            description = errorFilter.description;
            return true;
        }
    }
    return false;
}

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

bool isGrowingTypes(string name)
{
    foreach (name2; growingTypes)
        if (name2 == name)
            return true;
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

            string problemDescription;
            bool typeHasKnownProblem = isKnownProblem(infoD.modulename ~ "." ~ infoD.name, "", problemDescription);
            const(char)* errorOrWarning = typeHasKnownProblem ? "Warning".ptr : "Error".ptr;
            bool typeHasFailure;

            if (infoC.kind.length && infoD.kind != "enum" && infoD.kind != infoC.kind)
            {
                printf("%s: Type %s.%s is %s in C (ImportC), but %s in D\n", errorOrWarning, infoD.modulename.toStringz, infoD.name.toStringz, infoC.kind.toStringz, infoD.kind.toStringz);
                typeHasFailure = true;
            }
            bool printLayout;
            if (infoD.size > infoC.size || (infoD.size > 0 && infoD.size != infoC.size && !isGrowingTypes(infoD.modulename ~ "." ~ infoD.name)))
            {
                printf("%s: Type %s %s.%s has size %zd in C (ImportC), but size %zd in D\n", errorOrWarning, infoC.kind.toStringz, infoD.modulename.toStringz, infoD.name.toStringz, infoC.size, infoD.size);
                printLayout = true;
                typeHasFailure = true;
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
                string memberProblemDescription;
                bool memberHasKnownProblem = isKnownProblem(infoD.modulename ~ "." ~ infoD.name, memberD.name, memberProblemDescription);
                errorOrWarning = (memberHasKnownProblem || typeHasKnownProblem) ? "Warning".ptr : "Error".ptr;
                bool memberHasFailure;
                auto memberC = memberD.name in memberByNameC;
                if (memberC)
                {
                    if (memberC.offset != memberD.offset)
                    {
                        printf("%s: Member %s for type %s %s.%s has offset %zd in C (ImportC), but offset %zd in D\n", errorOrWarning, memberD.name.toStringz, infoC.kind.toStringz, infoD.modulename.toStringz, infoD.name.toStringz, memberC.offset, memberD.offset);
                        memberHasFailure = true;
                    }
                    if (memberC.size != memberD.size && (!memberC.bitsize || memberD.bitsize))
                    {
                        printf("%s: Member %s for type %s %s.%s has size %zd in C (ImportC), but size %zd in D\n", errorOrWarning, memberD.name.toStringz, infoC.kind.toStringz, infoD.modulename.toStringz, infoD.name.toStringz, memberC.size, memberD.size);
                        memberHasFailure = true;
                    }
                }
                if (memberHasFailure)
                {
                    printLayout = true;
                    if (!memberHasKnownProblem)
                        typeHasFailure = true;
                    if (memberProblemDescription.length)
                        printf("Known problem: %.*s\n", cast(int) memberProblemDescription.length, memberProblemDescription.ptr);
                }
            }
            if (typeHasFailure)
            {
                if (!typeHasKnownProblem)
                    anyFailure = true;
                if (problemDescription.length)
                    printf("Known problem: %.*s\n", cast(int) problemDescription.length, problemDescription.ptr);
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
