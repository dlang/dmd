// REQUIRED_ARGS: -O -fPIC
// PERMUTE_ARGS:
// only testing on SYSV-ABI, but backend code is identical across platforms
// DISABLED: win32 win64 osx linux32 freebsd32
debug = PRINTF;
debug (PRINTF) import core.stdc.stdio;

// Run `env DMD=generated/linux/release/64/dmd rdmd -version=update test/runnable/test_cdcmp.d` after codegen changes.

// common code
string opName(string op)
{
    switch (op)
    {
    case "<": return "lt";
    case "<=": return "le";
    case "==": return "eq";
    case "!=": return "ne";
    case ">=": return "ge";
    case ">": return "gt";
    default: assert(0);
    }
}

// update code
version (update)
{
    import std.algorithm : canFind, find, splitter, until;
    import std.array : appender, join;
    import std.conv : to;
    import std.exception : enforce;
    import std.file : readText;
    import std.format : formattedWrite;
    import std.meta : AliasSeq;
    import std.path : baseName, setExtension;
    import std.process : environment, execute, pipeProcess, wait;
    import std.range : dropOne;
    import std.regex : ctRegex, matchFirst, replaceFirstInto;
    import std.stdio : File, stdout, writeln;
    import std.string : strip;
    import std.typecons : tuple, EnumMembers;

    enum Arch
    {
        baseline, // doesn't affect argument passing
        // avx,
        // avx2,
    }

    enum ops = ["<", "<=", "==", "!=", ">=", ">"];

    enum asmRE = ctRegex!`^\s+[\da-z]+:((\s[\da-z]{2})*)(.*)$`;

    void formatASM(Captures, Sink)(Captures cap, Sink sink)
    {
        formattedWrite(sink, "        /* %-30s */ %-(0x%s,%| %)\n", cap[3].strip, cap[1].splitter);
    }

    void main()
    {
        enum src = __FILE__;
        auto dmd = environment.get("DMD", "dmd");
        auto sink = appender!string();
        foreach (arch; [EnumMembers!Arch])
        {
            auto args = [dmd, "-c", "-O", "-fPIC", "-mcpu=" ~ arch.to!string, __FILE__];
            auto rc = execute(args);
            enforce(rc.status == 0, rc.output);
            formattedWrite(sink, "alias %sCases = AliasSeq!(\n", arch);
            // Just add empty Code!(newtype, op)(null) elements when adding a new type
            foreach (type; AliasSeq!(ubyte, byte, ushort, short, uint, int, ulong, long, float, double))
            {
                foreach (op; ops)
                {
                    foreach (suffix; [tuple("zero", "Zero!"~type.stringof), tuple(type.stringof, type.stringof)])
                    {
                        args = ["objdump", "--disassemble", "--disassembler-options=intel-mnemonic",
                            "--section=.text.testee_" ~ type.stringof ~ "_" ~ opName(op) ~ "_" ~ suffix[0],
                            __FILE__.baseName.setExtension(".o")];
                        auto p = pipeProcess(args);
                        formattedWrite(sink, "    Code!(%s, \"%s\", %s)([\n", type.stringof, op, suffix[1]);
                        foreach (line; p.stdout.byLine.find!(ln => ln.matchFirst(ctRegex!">:$"))
                            .dropOne.until!(ln => ln.canFind("...")))
                        {
                            replaceFirstInto!formatASM(sink, line, asmRE);
                        }
                        formattedWrite(sink, "    ]),\n");
                        enforce(wait(p.pid) == 0, p.stderr.byLine.join("\n"));
                    }
                }
            }
            formattedWrite(sink, ");\n\n");
        }
        {
            auto content = src.readText;
            auto f = File(src, "w");
            auto orng = f.lockingTextWriter;
            immutable string start = "// dfmt off";
            immutable string end = "// dfmt on";
            replaceFirstInto!((_, orng) => formattedWrite(orng, start ~ "\n%s" ~ end, sink.data))(orng,
                    content, ctRegex!(`^` ~ start ~ `[^$]*` ~ end ~ `$`, "m"));
        }
    }
}
// test code
else:

template testee(T, string op, T2)
{
    static if (is(T2 == Zero!U, U))
        enum mangling = "testee_" ~ T.stringof ~ "_" ~ opName(op) ~ "_" ~ "zero";
    else
        enum mangling = "testee_" ~ T.stringof ~ "_" ~ opName(op) ~ "_" ~ T2.stringof;
    pragma(mangle, mangling)
    bool testee(T a, T2 b)
    {
        return mixin("a " ~ op ~ " b");
    }
}

struct Zero(T)
{
    enum T zero = 0;
    static alias zero this;
}

// holding the expected byte sequence
struct Code(T_, string op_, T2_)
{
    alias T = T_;
    alias op = op_;
    alias T2 = T2_;
    ubyte[] code;
}

alias AliasSeq(Args...) = Args;

// dfmt off
alias baselineCases = AliasSeq!(
    Code!(ubyte, "<", Zero!ubyte)([
        /* push   rbp                     */ 0x55,
        /* mov    rbp,rsp                 */ 0x48, 0x8b, 0xec,
        /* xor    eax,eax                 */ 0x31, 0xc0,
        /* pop    rbp                     */ 0x5d,
        /* ret                            */ 0xc3,
    ]),
    Code!(ubyte, "<", ubyte)([
        /* push   rbp                     */ 0x55,
        /* mov    rbp,rsp                 */ 0x48, 0x8b, 0xec,
        0x40, 0x3A, 0xF7,               // cmp  SIL,DIL
        /* setb   al                      */ 0x0f, 0x92, 0xc0,
        /* pop    rbp                     */ 0x5d,
        /* ret                            */ 0xc3,
    ]),
    Code!(ubyte, "<=", Zero!ubyte)([
        /* push   rbp                     */ 0x55,
        /* mov    rbp,rsp                 */ 0x48, 0x8b, 0xec,
        /* sub    rsp,0x10                */ 0x48, 0x83, 0xec, 0x10,
        /* mov    DWORD PTR [rbp-0x8],edi */ 0x89, 0x7d, 0xf8,
        /* rex cmp BYTE PTR [rbp-0x8],0x0 */ 0x40, 0x80, 0x7d, 0xf8, 0x00,
        /* sete   al                      */ 0x0f, 0x94, 0xc0,
        /* mov    rsp,rbp                 */ 0x48, 0x8b, 0xe5,
        /* pop    rbp                     */ 0x5d,
        /* ret                            */ 0xc3,
    ]),
    Code!(ubyte, "<=", ubyte)([
        /* push   rbp                     */ 0x55,
        /* mov    rbp,rsp                 */ 0x48, 0x8b, 0xec,
        0x40, 0x38, 0xF7,               // cmp  DIL,SIL
        /* setae  al                      */ 0x0f, 0x93, 0xc0,
        /* pop    rbp                     */ 0x5d,
        /* ret                            */ 0xc3,
    ]),
    Code!(ubyte, "==", Zero!ubyte)([
        /* push   rbp                     */ 0x55,
        /* mov    rbp,rsp                 */ 0x48, 0x8b, 0xec,
        /* sub    rsp,0x10                */ 0x48, 0x83, 0xec, 0x10,
        /* mov    DWORD PTR [rbp-0x8],edi */ 0x89, 0x7d, 0xf8,
        /* rex cmp BYTE PTR [rbp-0x8],0x0 */ 0x40, 0x80, 0x7d, 0xf8, 0x00,
        /* sete   al                      */ 0x0f, 0x94, 0xc0,
        /* mov    rsp,rbp                 */ 0x48, 0x8b, 0xe5,
        /* pop    rbp                     */ 0x5d,
        /* ret                            */ 0xc3,
    ]),
    Code!(ubyte, "==", ubyte)([
        /* push   rbp                     */ 0x55,
        /* mov    rbp,rsp                 */ 0x48, 0x8b, 0xec,
        0x40, 0x3A, 0xF7,               // cmp  SIL,DIL
        /* sete   al                      */ 0x0f, 0x94, 0xc0,
        /* pop    rbp                     */ 0x5d,
        /* ret                            */ 0xc3,
    ]),
    Code!(ubyte, "!=", Zero!ubyte)([
        /* push   rbp                     */ 0x55,
        /* mov    rbp,rsp                 */ 0x48, 0x8b, 0xec,
        /* sub    rsp,0x10                */ 0x48, 0x83, 0xec, 0x10,
        /* mov    DWORD PTR [rbp-0x8],edi */ 0x89, 0x7d, 0xf8,
        /* rex cmp BYTE PTR [rbp-0x8],0x0 */ 0x40, 0x80, 0x7d, 0xf8, 0x00,
        /* setne  al                      */ 0x0f, 0x95, 0xc0,
        /* mov    rsp,rbp                 */ 0x48, 0x8b, 0xe5,
        /* pop    rbp                     */ 0x5d,
        /* ret                            */ 0xc3,
    ]),
    Code!(ubyte, "!=", ubyte)([
        /* push   rbp                     */ 0x55,
        /* mov    rbp,rsp                 */ 0x48, 0x8b, 0xec,
        0x40, 0x3A, 0xF7,               // cmp  SIL,DIL
        /* setne  al                      */ 0x0f, 0x95, 0xc0,
        /* pop    rbp                     */ 0x5d,
        /* ret                            */ 0xc3,
    ]),
    Code!(ubyte, ">=", Zero!ubyte)([
        /* push   rbp                     */ 0x55,
        /* mov    rbp,rsp                 */ 0x48, 0x8b, 0xec,
        /* mov    eax,0x1                 */ 0xb8, 0x01, 0x00, 0x00, 0x00,
        /* pop    rbp                     */ 0x5d,
        /* ret                            */ 0xc3,
    ]),
    Code!(ubyte, ">=", ubyte)([
        /* push   rbp                     */ 0x55,
        /* mov    rbp,rsp                 */ 0x48, 0x8b, 0xec,
        0x40, 0x3A, 0xF7,               // cmp  SIL,DIL
        /* setae  al                      */ 0x0f, 0x93, 0xc0,
        /* pop    rbp                     */ 0x5d,
        /* ret                            */ 0xc3,
    ]),
    Code!(ubyte, ">", Zero!ubyte)([
        /* push   rbp                     */ 0x55,
        /* mov    rbp,rsp                 */ 0x48, 0x8b, 0xec,
        /* sub    rsp,0x10                */ 0x48, 0x83, 0xec, 0x10,
        /* mov    DWORD PTR [rbp-0x8],edi */ 0x89, 0x7d, 0xf8,
        /* rex cmp BYTE PTR [rbp-0x8],0x0 */ 0x40, 0x80, 0x7d, 0xf8, 0x00,
        /* setne  al                      */ 0x0f, 0x95, 0xc0,
        /* mov    rsp,rbp                 */ 0x48, 0x8b, 0xe5,
        /* pop    rbp                     */ 0x5d,
        /* ret                            */ 0xc3,
    ]),
    Code!(ubyte, ">", ubyte)([
        /* push   rbp                     */ 0x55,
        /* mov    rbp,rsp                 */ 0x48, 0x8b, 0xec,
        0x40, 0x38, 0xF7,               // cmp  DIL,SIL
        /* setb   al                      */ 0x0f, 0x92, 0xc0,
        /* pop    rbp                     */ 0x5d,
        /* ret                            */ 0xc3,
    ]),

    Code!(byte, "<", Zero!byte)([
        /* push   rbp                     */ 0x55,
        /* mov    rbp,rsp                 */ 0x48, 0x8b, 0xec,
        0x40, 0x84, 0xFF,               // test DIL,DIL
        /* sets   al                      */ 0x0f, 0x98, 0xc0,
        /* pop    rbp                     */ 0x5d,
        /* ret                            */ 0xc3,
    ]),
    Code!(byte, "<", byte)([
        /* push   rbp                     */ 0x55,
        /* mov    rbp,rsp                 */ 0x48, 0x8b, 0xec,
        0x40, 0x3A, 0xF7,               // cmp  SIL,DIL
        /* setl   al                      */ 0x0f, 0x9c, 0xc0,
        /* pop    rbp                     */ 0x5d,
        /* ret                            */ 0xc3,
    ]),
    Code!(byte, "<=", Zero!byte)([
        /* push   rbp                     */ 0x55,
        /* mov    rbp,rsp                 */ 0x48, 0x8b, 0xec,
        0x40, 0x84, 0xFF,               // test DIL,DIL
        /* setle  al                      */ 0x0f, 0x9e, 0xc0,
        /* pop    rbp                     */ 0x5d,
        /* ret                            */ 0xc3,
    ]),
    Code!(byte, "<=", byte)([
        /* push   rbp                     */ 0x55,
        /* mov    rbp,rsp                 */ 0x48, 0x8b, 0xec,
        0x40, 0x3A, 0xF7,               // cmp  SIL,DIL
        /* setle  al                      */ 0x0f, 0x9e, 0xc0,
        /* pop    rbp                     */ 0x5d,
        /* ret                            */ 0xc3,
    ]),
    Code!(byte, "==", Zero!byte)([
        /* push   rbp                     */ 0x55,
        /* mov    rbp,rsp                 */ 0x48, 0x8b, 0xec,
        /* sub    rsp,0x10                */ 0x48, 0x83, 0xec, 0x10,
        /* mov    DWORD PTR [rbp-0x8],edi */ 0x89, 0x7d, 0xf8,
        /* rex cmp BYTE PTR [rbp-0x8],0x0 */ 0x40, 0x80, 0x7d, 0xf8, 0x00,
        /* sete   al                      */ 0x0f, 0x94, 0xc0,
        /* mov    rsp,rbp                 */ 0x48, 0x8b, 0xe5,
        /* pop    rbp                     */ 0x5d,
        /* ret                            */ 0xc3,
    ]),
    Code!(byte, "==", byte)([
        /* push   rbp                     */ 0x55,
        /* mov    rbp,rsp                 */ 0x48, 0x8b, 0xec,
        0x40, 0x3A, 0xF7,               // cmp  SIL,DIL
        /* sete   al                      */ 0x0f, 0x94, 0xc0,
        /* pop    rbp                     */ 0x5d,
        /* ret                            */ 0xc3,
    ]),
    Code!(byte, "!=", Zero!byte)([
        /* push   rbp                     */ 0x55,
        /* mov    rbp,rsp                 */ 0x48, 0x8b, 0xec,
        /* sub    rsp,0x10                */ 0x48, 0x83, 0xec, 0x10,
        /* mov    DWORD PTR [rbp-0x8],edi */ 0x89, 0x7d, 0xf8,
        /* rex cmp BYTE PTR [rbp-0x8],0x0 */ 0x40, 0x80, 0x7d, 0xf8, 0x00,
        /* setne  al                      */ 0x0f, 0x95, 0xc0,
        /* mov    rsp,rbp                 */ 0x48, 0x8b, 0xe5,
        /* pop    rbp                     */ 0x5d,
        /* ret                            */ 0xc3,
    ]),
    Code!(byte, "!=", byte)([
        /* push   rbp                     */ 0x55,
        /* mov    rbp,rsp                 */ 0x48, 0x8b, 0xec,
        0x40, 0x3A, 0xF7,               // cmp  SIL,DIL
        /* setne  al                      */ 0x0f, 0x95, 0xc0,
        /* pop    rbp                     */ 0x5d,
        /* ret                            */ 0xc3,
    ]),
    Code!(byte, ">=", Zero!byte)([
        /* push   rbp                     */ 0x55,
        /* mov    rbp,rsp                 */ 0x48, 0x8b, 0xec,
        0x40, 0x84, 0xFF,               // test DIL,DIL
        /* setns  al                      */ 0x0f, 0x99, 0xc0,
        /* pop    rbp                     */ 0x5d,
        /* ret                            */ 0xc3,
    ]),
    Code!(byte, ">=", byte)([
        /* push   rbp                     */ 0x55,
        /* mov    rbp,rsp                 */ 0x48, 0x8b, 0xec,
        0x40, 0x3A, 0xF7,               // cmp  SIL,DIL
        /* setge  al                      */ 0x0f, 0x9d, 0xc0,
        /* pop    rbp                     */ 0x5d,
        /* ret                            */ 0xc3,
    ]),
    Code!(byte, ">", Zero!byte)([
        /* push   rbp                     */ 0x55,
        /* mov    rbp,rsp                 */ 0x48, 0x8b, 0xec,
        0x40, 0x84, 0xFF,               // test DIL,DIL
        /* setg   al                      */ 0x0f, 0x9f, 0xc0,
        /* pop    rbp                     */ 0x5d,
        /* ret                            */ 0xc3,
    ]),
    Code!(byte, ">", byte)([
        /* push   rbp                     */ 0x55,
        /* mov    rbp,rsp                 */ 0x48, 0x8b, 0xec,
        0x40, 0x3A, 0xF7,               // cmp  SIL,DIL
        /* setg   al                      */ 0x0f, 0x9f, 0xc0,
        /* pop    rbp                     */ 0x5d,
        /* ret                            */ 0xc3,
    ]),


    Code!(ushort, "<", Zero!ushort)([
        /* push   rbp                     */ 0x55,
        /* mov    rbp,rsp                 */ 0x48, 0x8b, 0xec,
        /* xor    eax,eax                 */ 0x31, 0xc0,
        /* pop    rbp                     */ 0x5d,
        /* ret                            */ 0xc3,
    ]),
    Code!(ushort, "<", ushort)([
        /* push   rbp                     */ 0x55,
        /* mov    rbp,rsp                 */ 0x48, 0x8b, 0xec,
0x66,   0x3B, 0xF7,                   // cmp     SI,DI
        /* setb   al                      */ 0x0f, 0x92, 0xc0,
        /* pop    rbp                     */ 0x5d,
        /* ret                            */ 0xc3,
    ]),
    Code!(ushort, "<=", Zero!ushort)([
        /* push   rbp                     */ 0x55,
        /* mov    rbp,rsp                 */ 0x48, 0x8b, 0xec,
        /* sub    rsp,0x10                */ 0x48, 0x83, 0xec, 0x10,
        /* mov    DWORD PTR [rbp-0x8],edi */ 0x89, 0x7d, 0xf8,
        /* cmp    WORD PTR [rbp-0x8],0x0  */ 0x66, 0x83, 0x7d, 0xf8, 0x00,
        /* sete   al                      */ 0x0f, 0x94, 0xc0,
        /* mov    rsp,rbp                 */ 0x48, 0x8b, 0xe5,
        /* pop    rbp                     */ 0x5d,
        /* ret                            */ 0xc3,
    ]),
    Code!(ushort, "<=", ushort)([
        /* push   rbp                     */ 0x55,
        /* mov    rbp,rsp                 */ 0x48, 0x8b, 0xec,
0x66,   0x39, 0xF7,                   // cmp     DI,SI
        /* setae  al                      */ 0x0f, 0x93, 0xc0,
        /* pop    rbp                     */ 0x5d,
        /* ret                            */ 0xc3,
    ]),
    Code!(ushort, "==", Zero!ushort)([
        /* push   rbp                     */ 0x55,
        /* mov    rbp,rsp                 */ 0x48, 0x8b, 0xec,
        /* sub    rsp,0x10                */ 0x48, 0x83, 0xec, 0x10,
        /* mov    DWORD PTR [rbp-0x8],edi */ 0x89, 0x7d, 0xf8,
        /* cmp    WORD PTR [rbp-0x8],0x0  */ 0x66, 0x83, 0x7d, 0xf8, 0x00,
        /* sete   al                      */ 0x0f, 0x94, 0xc0,
        /* mov    rsp,rbp                 */ 0x48, 0x8b, 0xe5,
        /* pop    rbp                     */ 0x5d,
        /* ret                            */ 0xc3,
    ]),
    Code!(ushort, "==", ushort)([
        /* push   rbp                     */ 0x55,
        /* mov    rbp,rsp                 */ 0x48, 0x8b, 0xec,
0x66,   0x3B, 0xF7,                   // cmp     SI,DI
        /* sete   al                      */ 0x0f, 0x94, 0xc0,
        /* pop    rbp                     */ 0x5d,
        /* ret                            */ 0xc3,
    ]),
    Code!(ushort, "!=", Zero!ushort)([
        /* push   rbp                     */ 0x55,
        /* mov    rbp,rsp                 */ 0x48, 0x8b, 0xec,
        /* sub    rsp,0x10                */ 0x48, 0x83, 0xec, 0x10,
        /* mov    DWORD PTR [rbp-0x8],edi */ 0x89, 0x7d, 0xf8,
        /* cmp    WORD PTR [rbp-0x8],0x0  */ 0x66, 0x83, 0x7d, 0xf8, 0x00,
        /* setne  al                      */ 0x0f, 0x95, 0xc0,
        /* mov    rsp,rbp                 */ 0x48, 0x8b, 0xe5,
        /* pop    rbp                     */ 0x5d,
        /* ret                            */ 0xc3,
    ]),
    Code!(ushort, "!=", ushort)([
        /* push   rbp                     */ 0x55,
        /* mov    rbp,rsp                 */ 0x48, 0x8b, 0xec,
0x66,   0x3B, 0xF7,                   // cmp     SI,DI
        /* setne  al                      */ 0x0f, 0x95, 0xc0,
        /* pop    rbp                     */ 0x5d,
        /* ret                            */ 0xc3,
    ]),
    Code!(ushort, ">=", Zero!ushort)([
        /* push   rbp                     */ 0x55,
        /* mov    rbp,rsp                 */ 0x48, 0x8b, 0xec,
        /* mov    eax,0x1                 */ 0xb8, 0x01, 0x00, 0x00, 0x00,
        /* pop    rbp                     */ 0x5d,
        /* ret                            */ 0xc3,
    ]),
    Code!(ushort, ">=", ushort)([
        /* push   rbp                     */ 0x55,
        /* mov    rbp,rsp                 */ 0x48, 0x8b, 0xec,
0x66,   0x3B, 0xF7,                   // cmp     SI,DI
        /* setae  al                      */ 0x0f, 0x93, 0xc0,
        /* pop    rbp                     */ 0x5d,
        /* ret                            */ 0xc3,
    ]),
    Code!(ushort, ">", Zero!ushort)([
        /* push   rbp                     */ 0x55,
        /* mov    rbp,rsp                 */ 0x48, 0x8b, 0xec,
        /* sub    rsp,0x10                */ 0x48, 0x83, 0xec, 0x10,
        /* mov    DWORD PTR [rbp-0x8],edi */ 0x89, 0x7d, 0xf8,
        /* cmp    WORD PTR [rbp-0x8],0x0  */ 0x66, 0x83, 0x7d, 0xf8, 0x00,
        /* setne  al                      */ 0x0f, 0x95, 0xc0,
        /* mov    rsp,rbp                 */ 0x48, 0x8b, 0xe5,
        /* pop    rbp                     */ 0x5d,
        /* ret                            */ 0xc3,
    ]),
    Code!(ushort, ">", ushort)([
        /* push   rbp                     */ 0x55,
        /* mov    rbp,rsp                 */ 0x48, 0x8b, 0xec,
0x66,   0x39, 0xF7,                   // cmp     DI,SI
        /* setb   al                      */ 0x0f, 0x92, 0xc0,
        /* pop    rbp                     */ 0x5d,
        /* ret                            */ 0xc3,
    ]),

    Code!(short, "<", Zero!short)([
        /* push   rbp                     */ 0x55,
        /* mov    rbp,rsp                 */ 0x48, 0x8b, 0xec,
0x66,   0x85, 0xFF,                   // test    DI,DI
        /* sets   al                      */ 0x0f, 0x98, 0xc0,
        /* pop    rbp                     */ 0x5d,
        /* ret                            */ 0xc3,
    ]),
    Code!(short, "<", short)([
        /* push   rbp                     */ 0x55,
        /* mov    rbp,rsp                 */ 0x48, 0x8b, 0xec,
0x66,   0x3B, 0xF7,                   // cmp     SI,DI
        /* setl   al                      */ 0x0f, 0x9c, 0xc0,
        /* pop    rbp                     */ 0x5d,
        /* ret                            */ 0xc3,
    ]),
    Code!(short, "<=", Zero!short)([
        /* push   rbp                     */ 0x55,
        /* mov    rbp,rsp                 */ 0x48, 0x8b, 0xec,
0x66,   0x85, 0xFF,                   // test    DI,DI
        /* setle  al                      */ 0x0f, 0x9e, 0xc0,
        /* pop    rbp                     */ 0x5d,
        /* ret                            */ 0xc3,
    ]),
    Code!(short, "<=", short)([
        /* push   rbp                     */ 0x55,
        /* mov    rbp,rsp                 */ 0x48, 0x8b, 0xec,
0x66,   0x3B, 0xF7,                   // cmp     SI,DI
        /* setle  al                      */ 0x0f, 0x9e, 0xc0,
        /* pop    rbp                     */ 0x5d,
        /* ret                            */ 0xc3,
    ]),
    Code!(short, "==", Zero!short)([
        /* push   rbp                     */ 0x55,
        /* mov    rbp,rsp                 */ 0x48, 0x8b, 0xec,
        /* sub    rsp,0x10                */ 0x48, 0x83, 0xec, 0x10,
        /* mov    DWORD PTR [rbp-0x8],edi */ 0x89, 0x7d, 0xf8,
        /* cmp    WORD PTR [rbp-0x8],0x0  */ 0x66, 0x83, 0x7d, 0xf8, 0x00,
        /* sete   al                      */ 0x0f, 0x94, 0xc0,
        /* mov    rsp,rbp                 */ 0x48, 0x8b, 0xe5,
        /* pop    rbp                     */ 0x5d,
        /* ret                            */ 0xc3,
    ]),
    Code!(short, "==", short)([
        /* push   rbp                     */ 0x55,
        /* mov    rbp,rsp                 */ 0x48, 0x8b, 0xec,
0x66,   0x3B, 0xF7,                   // cmp     SI,DI
        /* sete   al                      */ 0x0f, 0x94, 0xc0,
        /* pop    rbp                     */ 0x5d,
        /* ret                            */ 0xc3,
    ]),
    Code!(short, "!=", Zero!short)([
        /* push   rbp                     */ 0x55,
        /* mov    rbp,rsp                 */ 0x48, 0x8b, 0xec,
        /* sub    rsp,0x10                */ 0x48, 0x83, 0xec, 0x10,
        /* mov    DWORD PTR [rbp-0x8],edi */ 0x89, 0x7d, 0xf8,
        /* cmp    WORD PTR [rbp-0x8],0x0  */ 0x66, 0x83, 0x7d, 0xf8, 0x00,
        /* setne  al                      */ 0x0f, 0x95, 0xc0,
        /* mov    rsp,rbp                 */ 0x48, 0x8b, 0xe5,
        /* pop    rbp                     */ 0x5d,
        /* ret                            */ 0xc3,
    ]),
    Code!(short, "!=", short)([
        /* push   rbp                     */ 0x55,
        /* mov    rbp,rsp                 */ 0x48, 0x8b, 0xec,
0x66,   0x3B, 0xF7,                   // cmp     SI,DI
        /* setne  al                      */ 0x0f, 0x95, 0xc0,
        /* pop    rbp                     */ 0x5d,
        /* ret                            */ 0xc3,
    ]),
    Code!(short, ">=", Zero!short)([
        /* push   rbp                     */ 0x55,
        /* mov    rbp,rsp                 */ 0x48, 0x8b, 0xec,
0x66,   0x85, 0xFF,                   // test    DI,DI
        /* setns  al                      */ 0x0f, 0x99, 0xc0,
        /* pop    rbp                     */ 0x5d,
        /* ret                            */ 0xc3,
    ]),
    Code!(short, ">=", short)([
        /* push   rbp                     */ 0x55,
        /* mov    rbp,rsp                 */ 0x48, 0x8b, 0xec,
0x66,   0x3B, 0xF7,                   // cmp     SI,DI
        /* setge  al                      */ 0x0f, 0x9d, 0xc0,
        /* pop    rbp                     */ 0x5d,
        /* ret                            */ 0xc3,
    ]),
    Code!(short, ">", Zero!short)([
        /* push   rbp                     */ 0x55,
        /* mov    rbp,rsp                 */ 0x48, 0x8b, 0xec,
0x66,   0x85, 0xFF,                   // test    DI,DI
        /* setg   al                      */ 0x0f, 0x9f, 0xc0,
        /* pop    rbp                     */ 0x5d,
        /* ret                            */ 0xc3,
    ]),
    Code!(short, ">", short)([
        /* push   rbp                     */ 0x55,
        /* mov    rbp,rsp                 */ 0x48, 0x8b, 0xec,
0x66,   0x3B, 0xF7,                   // cmp     SI,DI
        /* setg   al                      */ 0x0f, 0x9f, 0xc0,
        /* pop    rbp                     */ 0x5d,
        /* ret                            */ 0xc3,
    ]),

    Code!(uint, "<", Zero!uint)([
        /* push   rbp                     */ 0x55,
        /* mov    rbp,rsp                 */ 0x48, 0x8b, 0xec,
        /* xor    eax,eax                 */ 0x31, 0xc0,
        /* pop    rbp                     */ 0x5d,
        /* ret                            */ 0xc3,
    ]),
    Code!(uint, "<", uint)([
        /* push   rbp                     */ 0x55,
        /* mov    rbp,rsp                 */ 0x48, 0x8b, 0xec,
        0x3B, 0xF7,                   // cmp     ESI,EDI
        /* setb   al                      */ 0x0f, 0x92, 0xc0,
        /* pop    rbp                     */ 0x5d,
        /* ret                            */ 0xc3,
    ]),
    Code!(uint, "<=", Zero!uint)([
        /* push   rbp                     */ 0x55,
        /* mov    rbp,rsp                 */ 0x48, 0x8b, 0xec,
        /* sub    rsp,0x10                */ 0x48, 0x83, 0xec, 0x10,
        /* mov    DWORD PTR [rbp-0x8],edi */ 0x89, 0x7d, 0xf8,
        /* cmp    DWORD PTR [rbp-0x8],0x0 */ 0x83, 0x7d, 0xf8, 0x00,
        /* sete   al                      */ 0x0f, 0x94, 0xc0,
        /* mov    rsp,rbp                 */ 0x48, 0x8b, 0xe5,
        /* pop    rbp                     */ 0x5d,
        /* ret                            */ 0xc3,
    ]),
    Code!(uint, "<=", uint)([
        /* push   rbp                     */ 0x55,
        /* mov    rbp,rsp                 */ 0x48, 0x8b, 0xec,
        0x39, 0xF7,                   // cmp     EDI,ESI
        /* setae  al                      */ 0x0f, 0x93, 0xc0,
        /* pop    rbp                     */ 0x5d,
        /* ret                            */ 0xc3,
    ]),
    Code!(uint, "==", Zero!uint)([
        /* push   rbp                     */ 0x55,
        /* mov    rbp,rsp                 */ 0x48, 0x8b, 0xec,
        /* sub    rsp,0x10                */ 0x48, 0x83, 0xec, 0x10,
        /* mov    DWORD PTR [rbp-0x8],edi */ 0x89, 0x7d, 0xf8,
        /* cmp    DWORD PTR [rbp-0x8],0x0 */ 0x83, 0x7d, 0xf8, 0x00,
        /* sete   al                      */ 0x0f, 0x94, 0xc0,
        /* mov    rsp,rbp                 */ 0x48, 0x8b, 0xe5,
        /* pop    rbp                     */ 0x5d,
        /* ret                            */ 0xc3,
    ]),
    Code!(uint, "==", uint)([
        /* push   rbp                     */ 0x55,
        /* mov    rbp,rsp                 */ 0x48, 0x8b, 0xec,
        0x3B, 0xF7,                   // cmp     ESI,EDI
        /* sete   al                      */ 0x0f, 0x94, 0xc0,
        /* pop    rbp                     */ 0x5d,
        /* ret                            */ 0xc3,
    ]),
    Code!(uint, "!=", Zero!uint)([
        /* push   rbp                     */ 0x55,
        /* mov    rbp,rsp                 */ 0x48, 0x8b, 0xec,
        /* sub    rsp,0x10                */ 0x48, 0x83, 0xec, 0x10,
        /* mov    DWORD PTR [rbp-0x8],edi */ 0x89, 0x7d, 0xf8,
        /* cmp    DWORD PTR [rbp-0x8],0x0 */ 0x83, 0x7d, 0xf8, 0x00,
        /* setne  al                      */ 0x0f, 0x95, 0xc0,
        /* mov    rsp,rbp                 */ 0x48, 0x8b, 0xe5,
        /* pop    rbp                     */ 0x5d,
        /* ret                            */ 0xc3,
    ]),
    Code!(uint, "!=", uint)([
        /* push   rbp                     */ 0x55,
        /* mov    rbp,rsp                 */ 0x48, 0x8b, 0xec,
        0x3B, 0xF7,                   // cmp     ESI,EDI
        /* setne  al                      */ 0x0f, 0x95, 0xc0,
        /* pop    rbp                     */ 0x5d,
        /* ret                            */ 0xc3,
    ]),
    Code!(uint, ">=", Zero!uint)([
        /* push   rbp                     */ 0x55,
        /* mov    rbp,rsp                 */ 0x48, 0x8b, 0xec,
        /* mov    eax,0x1                 */ 0xb8, 0x01, 0x00, 0x00, 0x00,
        /* pop    rbp                     */ 0x5d,
        /* ret                            */ 0xc3,
    ]),
    Code!(uint, ">=", uint)([
        /* push   rbp                     */ 0x55,
        /* mov    rbp,rsp                 */ 0x48, 0x8b, 0xec,
        0x3B, 0xF7,                   // cmp     ESI,EDI
        /* setae  al                      */ 0x0f, 0x93, 0xc0,
        /* pop    rbp                     */ 0x5d,
        /* ret                            */ 0xc3,
    ]),
    Code!(uint, ">", Zero!uint)([
        /* push   rbp                     */ 0x55,
        /* mov    rbp,rsp                 */ 0x48, 0x8b, 0xec,
        /* sub    rsp,0x10                */ 0x48, 0x83, 0xec, 0x10,
        /* mov    DWORD PTR [rbp-0x8],edi */ 0x89, 0x7d, 0xf8,
        /* cmp    DWORD PTR [rbp-0x8],0x0 */ 0x83, 0x7d, 0xf8, 0x00,
        /* setne  al                      */ 0x0f, 0x95, 0xc0,
        /* mov    rsp,rbp                 */ 0x48, 0x8b, 0xe5,
        /* pop    rbp                     */ 0x5d,
        /* ret                            */ 0xc3,
    ]),
    Code!(uint, ">", uint)([
        /* push   rbp                     */ 0x55,
        /* mov    rbp,rsp                 */ 0x48, 0x8b, 0xec,
        0x39, 0xF7,                   // cmp     EDI,ESI
        /* setb   al                      */ 0x0f, 0x92, 0xc0,
        /* pop    rbp                     */ 0x5d,
        /* ret                            */ 0xc3,
    ]),


    Code!(int, "<", Zero!int)([
        /* push   rbp                     */ 0x55,
        /* mov    rbp,rsp                 */ 0x48, 0x8b, 0xec,
        /* mov    rax,rdi                 */ 0x48, 0x89, 0xf8,
        /* shr    eax,0x1f                */ 0xc1, 0xe8, 0x1f,
        /* pop    rbp                     */ 0x5d,
        /* ret                            */ 0xc3,
    ]),
    Code!(int, "<", int)([
        /* push   rbp                     */ 0x55,
        /* mov    rbp,rsp                 */ 0x48, 0x8b, 0xec,
        0x3B, 0xF7,                     // cmp     ESI,EDI
        /* setl   al                      */ 0x0f, 0x9c, 0xc0,
        /* pop    rbp                     */ 0x5d,
        /* ret                            */ 0xc3,
    ]),
    Code!(int, "<=", Zero!int)([
        /* push   rbp                     */ 0x55,
        /* mov    rbp,rsp                 */ 0x48, 0x8b, 0xec,
        /* mov    rax,rdi                 */ 0x48, 0x89, 0xf8,
        /* add    eax,0xffffffff          */ 0x83, 0xc0, 0xff,
        /* adc    eax,0x0                 */ 0x83, 0xd0, 0x00,
        /* shr    eax,0x1f                */ 0xc1, 0xe8, 0x1f,
        /* pop    rbp                     */ 0x5d,
        /* ret                            */ 0xc3,
    ]),
    Code!(int, "<=", int)([
        /* push   rbp                     */ 0x55,
        /* mov    rbp,rsp                 */ 0x48, 0x8b, 0xec,
        0x3B, 0xF7,                     // cmp     ESI,EDI
        /* setle  al                      */ 0x0f, 0x9e, 0xc0,
        /* pop    rbp                     */ 0x5d,
        /* ret                            */ 0xc3,
    ]),
    Code!(int, "==", Zero!int)([
        /* push   rbp                     */ 0x55,
        /* mov    rbp,rsp                 */ 0x48, 0x8b, 0xec,
        /* sub    rsp,0x10                */ 0x48, 0x83, 0xec, 0x10,
        /* mov    DWORD PTR [rbp-0x8],edi */ 0x89, 0x7d, 0xf8,
        /* cmp    DWORD PTR [rbp-0x8],0x0 */ 0x83, 0x7d, 0xf8, 0x00,
        /* sete   al                      */ 0x0f, 0x94, 0xc0,
        /* mov    rsp,rbp                 */ 0x48, 0x8b, 0xe5,
        /* pop    rbp                     */ 0x5d,
        /* ret                            */ 0xc3,
    ]),
    Code!(int, "==", int)([
        /* push   rbp                     */ 0x55,
        /* mov    rbp,rsp                 */ 0x48, 0x8b, 0xec,
        0x3B, 0xF7,                     // cmp     ESI,EDI
        /* sete   al                      */ 0x0f, 0x94, 0xc0,
        /* pop    rbp                     */ 0x5d,
        /* ret                            */ 0xc3,
    ]),
    Code!(int, "!=", Zero!int)([
        /* push   rbp                     */ 0x55,
        /* mov    rbp,rsp                 */ 0x48, 0x8b, 0xec,
        /* sub    rsp,0x10                */ 0x48, 0x83, 0xec, 0x10,
        /* mov    DWORD PTR [rbp-0x8],edi */ 0x89, 0x7d, 0xf8,
        /* cmp    DWORD PTR [rbp-0x8],0x0 */ 0x83, 0x7d, 0xf8, 0x00,
        /* setne  al                      */ 0x0f, 0x95, 0xc0,
        /* mov    rsp,rbp                 */ 0x48, 0x8b, 0xe5,
        /* pop    rbp                     */ 0x5d,
        /* ret                            */ 0xc3,
    ]),
    Code!(int, "!=", int)([
        /* push   rbp                     */ 0x55,
        /* mov    rbp,rsp                 */ 0x48, 0x8b, 0xec,
        0x3B, 0xF7,                     // cmp     ESI,EDI
        /* setne  al                      */ 0x0f, 0x95, 0xc0,
        /* pop    rbp                     */ 0x5d,
        /* ret                            */ 0xc3,
    ]),
    Code!(int, ">=", Zero!int)([
        /* push   rbp                     */ 0x55,
        /* mov    rbp,rsp                 */ 0x48, 0x8b, 0xec,
        /* mov    rax,rdi                 */ 0x48, 0x89, 0xf8,
        /* add    eax,eax                 */ 0x01, 0xc0,
        /* sbb    eax,eax                 */ 0x19, 0xc0,
        /* inc    eax                     */ 0xff, 0xc0,
        /* pop    rbp                     */ 0x5d,
        /* ret                            */ 0xc3,
    ]),
    Code!(int, ">=", int)([
        /* push   rbp                     */ 0x55,
        /* mov    rbp,rsp                 */ 0x48, 0x8b, 0xec,
        0x3B, 0xF7,                     // cmp     ESI,EDI
        /* setge  al                      */ 0x0f, 0x9d, 0xc0,
        /* pop    rbp                     */ 0x5d,
        /* ret                            */ 0xc3,
    ]),
    Code!(int, ">", Zero!int)([
        /* push   rbp                     */ 0x55,
        /* mov    rbp,rsp                 */ 0x48, 0x8b, 0xec,
        /* mov    rax,rdi                 */ 0x48, 0x89, 0xf8,
        /* neg    eax                     */ 0xf7, 0xd8,
        /* sbb    eax,0x0                 */ 0x83, 0xd8, 0x00,
        /* shr    eax,0x1f                */ 0xc1, 0xe8, 0x1f,
        /* pop    rbp                     */ 0x5d,
        /* ret                            */ 0xc3,
        /* add    BYTE PTR [rax],al       */ 0x00, 0x00,
    ]),
    Code!(int, ">", int)([
        /* push   rbp                     */ 0x55,
        /* mov    rbp,rsp                 */ 0x48, 0x8b, 0xec,
        0x3B, 0xF7,                     // cmp     ESI,EDI
        /* setg   al                      */ 0x0f, 0x9f, 0xc0,
        /* pop    rbp                     */ 0x5d,
        /* ret                            */ 0xc3,
    ]),

    Code!(ulong, "<", Zero!ulong)([
        /* push   rbp                     */ 0x55,
        /* mov    rbp,rsp                 */ 0x48, 0x8b, 0xec,
        /* xor    eax,eax                 */ 0x31, 0xc0,
        /* pop    rbp                     */ 0x5d,
        /* ret                            */ 0xc3,
    ]),
    Code!(ulong, "<", ulong)([
        /* push   rbp                     */ 0x55,
        /* mov    rbp,rsp                 */ 0x48, 0x8b, 0xec,
        /* cmp    rsi,rdi                 */ 0x48, 0x3b, 0xf7,
        /* setb   al                      */ 0x0f, 0x92, 0xc0,
        /* pop    rbp                     */ 0x5d,
        /* ret                            */ 0xc3,
    ]),
    Code!(ulong, "<=", Zero!ulong)([
        /* push   rbp                     */ 0x55,
        /* mov    rbp,rsp                 */ 0x48, 0x8b, 0xec,
        /* sub    rsp,0x10                */ 0x48, 0x83, 0xec, 0x10,
        /* mov    QWORD PTR [rbp-0x8],rdi */ 0x48, 0x89, 0x7d, 0xf8,
        /* cmp    QWORD PTR [rbp-0x8],0x0 */ 0x48, 0x83, 0x7d, 0xf8, 0x00,
        /* rex.W sete al                  */ 0x48, 0x0f, 0x94, 0xc0,
        /* mov    rsp,rbp                 */ 0x48, 0x8b, 0xe5,
        /* pop    rbp                     */ 0x5d,
        /* ret                            */ 0xc3,
    ]),
    Code!(ulong, "<=", ulong)([
        /* push   rbp                     */ 0x55,
        /* mov    rbp,rsp                 */ 0x48, 0x8b, 0xec,
        /* cmp    rdi,rsi                 */ 0x48, 0x39, 0xf7,
        /* setae  al                      */ 0x0f, 0x93, 0xc0,
        /* pop    rbp                     */ 0x5d,
        /* ret                            */ 0xc3,
    ]),
    Code!(ulong, "==", Zero!ulong)([
        /* push   rbp                     */ 0x55,
        /* mov    rbp,rsp                 */ 0x48, 0x8b, 0xec,
        /* sub    rsp,0x10                */ 0x48, 0x83, 0xec, 0x10,
        /* mov    QWORD PTR [rbp-0x8],rdi */ 0x48, 0x89, 0x7d, 0xf8,
        /* cmp    QWORD PTR [rbp-0x8],0x0 */ 0x48, 0x83, 0x7d, 0xf8, 0x00,
        /* rex.W sete al                  */ 0x48, 0x0f, 0x94, 0xc0,
        /* mov    rsp,rbp                 */ 0x48, 0x8b, 0xe5,
        /* pop    rbp                     */ 0x5d,
        /* ret                            */ 0xc3,
    ]),
    Code!(ulong, "==", ulong)([
        /* push   rbp                     */ 0x55,
        /* mov    rbp,rsp                 */ 0x48, 0x8b, 0xec,
        /* cmp    rsi,rdi                 */ 0x48, 0x3b, 0xf7,
        /* sete   al                      */ 0x0f, 0x94, 0xc0,
        /* pop    rbp                     */ 0x5d,
        /* ret                            */ 0xc3,
    ]),
    Code!(ulong, "!=", Zero!ulong)([
        /* push   rbp                     */ 0x55,
        /* mov    rbp,rsp                 */ 0x48, 0x8b, 0xec,
        /* sub    rsp,0x10                */ 0x48, 0x83, 0xec, 0x10,
        /* mov    QWORD PTR [rbp-0x8],rdi */ 0x48, 0x89, 0x7d, 0xf8,
        /* cmp    QWORD PTR [rbp-0x8],0x0 */ 0x48, 0x83, 0x7d, 0xf8, 0x00,
        /* rex.W setne al                 */ 0x48, 0x0f, 0x95, 0xc0,
        /* mov    rsp,rbp                 */ 0x48, 0x8b, 0xe5,
        /* pop    rbp                     */ 0x5d,
        /* ret                            */ 0xc3,
    ]),
    Code!(ulong, "!=", ulong)([
        /* push   rbp                     */ 0x55,
        /* mov    rbp,rsp                 */ 0x48, 0x8b, 0xec,
        /* cmp    rsi,rdi                 */ 0x48, 0x3b, 0xf7,
        /* setne  al                      */ 0x0f, 0x95, 0xc0,
        /* pop    rbp                     */ 0x5d,
        /* ret                            */ 0xc3,
    ]),
    Code!(ulong, ">=", Zero!ulong)([
        /* push   rbp                     */ 0x55,
        /* mov    rbp,rsp                 */ 0x48, 0x8b, 0xec,
        /* mov    eax,0x1                 */ 0xb8, 0x01, 0x00, 0x00, 0x00,
        /* pop    rbp                     */ 0x5d,
        /* ret                            */ 0xc3,
    ]),
    Code!(ulong, ">=", ulong)([
        /* push   rbp                     */ 0x55,
        /* mov    rbp,rsp                 */ 0x48, 0x8b, 0xec,
        /* cmp    rsi,rdi                 */ 0x48, 0x3b, 0xf7,
        /* setae  al                      */ 0x0f, 0x93, 0xc0,
        /* pop    rbp                     */ 0x5d,
        /* ret                            */ 0xc3,
    ]),
    Code!(ulong, ">", Zero!ulong)([
        /* push   rbp                     */ 0x55,
        /* mov    rbp,rsp                 */ 0x48, 0x8b, 0xec,
        /* sub    rsp,0x10                */ 0x48, 0x83, 0xec, 0x10,
        /* mov    QWORD PTR [rbp-0x8],rdi */ 0x48, 0x89, 0x7d, 0xf8,
        /* cmp    QWORD PTR [rbp-0x8],0x0 */ 0x48, 0x83, 0x7d, 0xf8, 0x00,
        /* rex.W setne al                 */ 0x48, 0x0f, 0x95, 0xc0,
        /* mov    rsp,rbp                 */ 0x48, 0x8b, 0xe5,
        /* pop    rbp                     */ 0x5d,
        /* ret                            */ 0xc3,
    ]),
    Code!(ulong, ">", ulong)([
        /* push   rbp                     */ 0x55,
        /* mov    rbp,rsp                 */ 0x48, 0x8b, 0xec,
        /* cmp    rdi,rsi                 */ 0x48, 0x39, 0xf7,
        /* setb   al                      */ 0x0f, 0x92, 0xc0,
        /* pop    rbp                     */ 0x5d,
        /* ret                            */ 0xc3,
    ]),
    Code!(long, "<", Zero!long)([
        /* push   rbp                     */ 0x55,
        /* mov    rbp,rsp                 */ 0x48, 0x8b, 0xec,
        /* mov    rax,rdi                 */ 0x48, 0x89, 0xf8,
        /* shr    rax,0x3f                */ 0x48, 0xc1, 0xe8, 0x3f,
        /* pop    rbp                     */ 0x5d,
        /* ret                            */ 0xc3,
        /* add    BYTE PTR [rax],al       */ 0x00, 0x00,
    ]),
    Code!(long, "<", long)([
        /* push   rbp                     */ 0x55,
        /* mov    rbp,rsp                 */ 0x48, 0x8b, 0xec,
        /* cmp    rsi,rdi                 */ 0x48, 0x3b, 0xf7,
        /* setl   al                      */ 0x0f, 0x9c, 0xc0,
        /* pop    rbp                     */ 0x5d,
        /* ret                            */ 0xc3,
    ]),
    Code!(long, "<=", Zero!long)([
        /* push   rbp                     */ 0x55,
        /* mov    rbp,rsp                 */ 0x48, 0x8b, 0xec,
        /* mov    rax,rdi                 */ 0x48, 0x89, 0xf8,
        /* add    rax,0xffffffffffffffff  */ 0x48, 0x83, 0xc0, 0xff,
        /* adc    rax,0x0                 */ 0x48, 0x83, 0xd0, 0x00,
        /* shr    rax,0x3f                */ 0x48, 0xc1, 0xe8, 0x3f,
        /* pop    rbp                     */ 0x5d,
        /* ret                            */ 0xc3,
        /* add    BYTE PTR [rax],al       */ 0x00, 0x00,
    ]),
    Code!(long, "<=", long)([
        /* push   rbp                     */ 0x55,
        /* mov    rbp,rsp                 */ 0x48, 0x8b, 0xec,
        /* cmp    rsi,rdi                 */ 0x48, 0x3b, 0xf7,
        /* setle  al                      */ 0x0f, 0x9e, 0xc0,
        /* pop    rbp                     */ 0x5d,
        /* ret                            */ 0xc3,
    ]),
    Code!(long, "==", Zero!long)([
        /* push   rbp                     */ 0x55,
        /* mov    rbp,rsp                 */ 0x48, 0x8b, 0xec,
        /* sub    rsp,0x10                */ 0x48, 0x83, 0xec, 0x10,
        /* mov    QWORD PTR [rbp-0x8],rdi */ 0x48, 0x89, 0x7d, 0xf8,
        /* cmp    QWORD PTR [rbp-0x8],0x0 */ 0x48, 0x83, 0x7d, 0xf8, 0x00,
        /* rex.W sete al                  */ 0x48, 0x0f, 0x94, 0xc0,
        /* mov    rsp,rbp                 */ 0x48, 0x8b, 0xe5,
        /* pop    rbp                     */ 0x5d,
        /* ret                            */ 0xc3,
    ]),
    Code!(long, "==", long)([
        /* push   rbp                     */ 0x55,
        /* mov    rbp,rsp                 */ 0x48, 0x8b, 0xec,
        /* cmp    rsi,rdi                 */ 0x48, 0x3b, 0xf7,
        /* sete   al                      */ 0x0f, 0x94, 0xc0,
        /* pop    rbp                     */ 0x5d,
        /* ret                            */ 0xc3,
    ]),
    Code!(long, "!=", Zero!long)([
        /* push   rbp                     */ 0x55,
        /* mov    rbp,rsp                 */ 0x48, 0x8b, 0xec,
        /* sub    rsp,0x10                */ 0x48, 0x83, 0xec, 0x10,
        /* mov    QWORD PTR [rbp-0x8],rdi */ 0x48, 0x89, 0x7d, 0xf8,
        /* cmp    QWORD PTR [rbp-0x8],0x0 */ 0x48, 0x83, 0x7d, 0xf8, 0x00,
        /* rex.W setne al                 */ 0x48, 0x0f, 0x95, 0xc0,
        /* mov    rsp,rbp                 */ 0x48, 0x8b, 0xe5,
        /* pop    rbp                     */ 0x5d,
        /* ret                            */ 0xc3,
    ]),
    Code!(long, "!=", long)([
        /* push   rbp                     */ 0x55,
        /* mov    rbp,rsp                 */ 0x48, 0x8b, 0xec,
        /* cmp    rsi,rdi                 */ 0x48, 0x3b, 0xf7,
        /* setne  al                      */ 0x0f, 0x95, 0xc0,
        /* pop    rbp                     */ 0x5d,
        /* ret                            */ 0xc3,
    ]),
    Code!(long, ">=", Zero!long)([
        /* push   rbp                     */ 0x55,
        /* mov    rbp,rsp                 */ 0x48, 0x8b, 0xec,
        /* mov    rax,rdi                 */ 0x48, 0x89, 0xf8,
        /* add    rax,rax                 */ 0x48, 0x01, 0xc0,
        /* sbb    rax,rax                 */ 0x48, 0x19, 0xc0,
        /* inc    rax                     */ 0x48, 0xff, 0xc0,
        /* pop    rbp                     */ 0x5d,
        /* ret                            */ 0xc3,
    ]),
    Code!(long, ">=", long)([
        /* push   rbp                     */ 0x55,
        /* mov    rbp,rsp                 */ 0x48, 0x8b, 0xec,
        /* cmp    rsi,rdi                 */ 0x48, 0x3b, 0xf7,
        /* setge  al                      */ 0x0f, 0x9d, 0xc0,
        /* pop    rbp                     */ 0x5d,
        /* ret                            */ 0xc3,
    ]),
    Code!(long, ">", Zero!long)([
        /* push   rbp                     */ 0x55,
        /* mov    rbp,rsp                 */ 0x48, 0x8b, 0xec,
        /* mov    rax,rdi                 */ 0x48, 0x89, 0xf8,
        /* neg    rax                     */ 0x48, 0xf7, 0xd8,
        /* sbb    rax,0x0                 */ 0x48, 0x83, 0xd8, 0x00,
        /* shr    rax,0x3f                */ 0x48, 0xc1, 0xe8, 0x3f,
        /* pop    rbp                     */ 0x5d,
        /* ret                            */ 0xc3,
    ]),
    Code!(long, ">", long)([
        /* push   rbp                     */ 0x55,
        /* mov    rbp,rsp                 */ 0x48, 0x8b, 0xec,
        /* cmp    rsi,rdi                 */ 0x48, 0x3b, 0xf7,
        /* setg   al                      */ 0x0f, 0x9f, 0xc0,
        /* pop    rbp                     */ 0x5d,
        /* ret                            */ 0xc3,
    ]),
    Code!(float, "<", Zero!float)([
        /* push   rbp                     */ 0x55,
        /* mov    rbp,rsp                 */ 0x48, 0x8b, 0xec,
        /* sub    rsp,0x10                */ 0x48, 0x83, 0xec, 0x10,
        /* xor    eax,eax                 */ 0x31, 0xc0,
        /* mov    DWORD PTR [rbp-0x10],eax */ 0x89, 0x45, 0xf0,
        /* movss  xmm1,DWORD PTR [rbp-0x10] */ 0xf3, 0x0f, 0x10, 0x4d, 0xf0,
        /* ucomiss xmm1,xmm0              */ 0x0f, 0x2e, 0xc8,
        /* seta   al                      */ 0x0f, 0x97, 0xc0,
        /* mov    rsp,rbp                 */ 0x48, 0x8b, 0xe5,
        /* pop    rbp                     */ 0x5d,
        /* ret                            */ 0xc3,
        /* add    BYTE PTR [rax],al       */ 0x00, 0x00,
    ]),
    Code!(float, "<", float)([
        /* push   rbp                     */ 0x55,
        /* mov    rbp,rsp                 */ 0x48, 0x8b, 0xec,
        /* ucomiss xmm0,xmm1              */ 0x0f, 0x2e, 0xc1,
        /* seta   al                      */ 0x0f, 0x97, 0xc0,
        /* pop    rbp                     */ 0x5d,
        /* ret                            */ 0xc3,
    ]),
    Code!(float, "<=", Zero!float)([
        /* push   rbp                     */ 0x55,
        /* mov    rbp,rsp                 */ 0x48, 0x8b, 0xec,
        /* sub    rsp,0x10                */ 0x48, 0x83, 0xec, 0x10,
        /* xor    eax,eax                 */ 0x31, 0xc0,
        /* mov    DWORD PTR [rbp-0x10],eax */ 0x89, 0x45, 0xf0,
        /* movss  xmm1,DWORD PTR [rbp-0x10] */ 0xf3, 0x0f, 0x10, 0x4d, 0xf0,
        /* ucomiss xmm1,xmm0              */ 0x0f, 0x2e, 0xc8,
        /* setae  al                      */ 0x0f, 0x93, 0xc0,
        /* mov    rsp,rbp                 */ 0x48, 0x8b, 0xe5,
        /* pop    rbp                     */ 0x5d,
        /* ret                            */ 0xc3,
        /* add    BYTE PTR [rax],al       */ 0x00, 0x00,
    ]),
    Code!(float, "<=", float)([
        /* push   rbp                     */ 0x55,
        /* mov    rbp,rsp                 */ 0x48, 0x8b, 0xec,
        /* ucomiss xmm0,xmm1              */ 0x0f, 0x2e, 0xc1,
        /* setae  al                      */ 0x0f, 0x93, 0xc0,
        /* pop    rbp                     */ 0x5d,
        /* ret                            */ 0xc3,
    ]),
    Code!(float, "==", Zero!float)([
        /* push   rbp                     */ 0x55,
        /* mov    rbp,rsp                 */ 0x48, 0x8b, 0xec,
        /* sub    rsp,0x10                */ 0x48, 0x83, 0xec, 0x10,
        /* movss  DWORD PTR [rbp-0x8],xmm0 */ 0xf3, 0x0f, 0x11, 0x45, 0xf8,
        /* mov    eax,DWORD PTR [rbp-0x8] */ 0x8b, 0x45, 0xf8,
        /* add    eax,eax                 */ 0x01, 0xc0,
        /* je     18 <testee_float_eq_zero+0x18> */ 0x74, 0x04,
        /* xor    eax,eax                 */ 0x31, 0xc0,
        /* jmp    1d <testee_float_eq_zero+0x1d> */ 0xeb, 0x05,
        /* mov    eax,0x1                 */ 0xb8, 0x01, 0x00, 0x00, 0x00,
        /* mov    rsp,rbp                 */ 0x48, 0x8b, 0xe5,
        /* pop    rbp                     */ 0x5d,
        /* ret                            */ 0xc3,
    ]),
    Code!(float, "==", float)([
        /* push   rbp                     */ 0x55,
        /* mov    rbp,rsp                 */ 0x48, 0x8b, 0xec,
        /* ucomiss xmm0,xmm1              */ 0x0f, 0x2e, 0xc1,
        /* mov    eax,0x1                 */ 0xb8, 0x01, 0x00, 0x00, 0x00,
        /* jp     10 <testee_float_eq_float+0x10> */ 0x7a, 0x02,
        /* je     12 <testee_float_eq_float+0x12> */ 0x74, 0x02,
        /* xor    eax,eax                 */ 0x31, 0xc0,
        /* pop    rbp                     */ 0x5d,
        /* ret                            */ 0xc3,
    ]),
    Code!(float, "!=", Zero!float)([
        /* push   rbp                     */ 0x55,
        /* mov    rbp,rsp                 */ 0x48, 0x8b, 0xec,
        /* sub    rsp,0x10                */ 0x48, 0x83, 0xec, 0x10,
        /* movss  DWORD PTR [rbp-0x8],xmm0 */ 0xf3, 0x0f, 0x11, 0x45, 0xf8,
        /* mov    eax,DWORD PTR [rbp-0x8] */ 0x8b, 0x45, 0xf8,
        /* add    eax,eax                 */ 0x01, 0xc0,
        /* jne    18 <testee_float_ne_zero+0x18> */ 0x75, 0x04,
        /* xor    eax,eax                 */ 0x31, 0xc0,
        /* jmp    1d <testee_float_ne_zero+0x1d> */ 0xeb, 0x05,
        /* mov    eax,0x1                 */ 0xb8, 0x01, 0x00, 0x00, 0x00,
        /* mov    rsp,rbp                 */ 0x48, 0x8b, 0xe5,
        /* pop    rbp                     */ 0x5d,
        /* ret                            */ 0xc3,
    ]),
    Code!(float, "!=", float)([
        /* push   rbp                     */ 0x55,
        /* mov    rbp,rsp                 */ 0x48, 0x8b, 0xec,
        /* ucomiss xmm0,xmm1              */ 0x0f, 0x2e, 0xc1,
        /* mov    eax,0x1                 */ 0xb8, 0x01, 0x00, 0x00, 0x00,
        /* jne    12 <testee_float_ne_float+0x12> */ 0x75, 0x04,
        /* jp     12 <testee_float_ne_float+0x12> */ 0x7a, 0x02,
        /* xor    eax,eax                 */ 0x31, 0xc0,
        /* pop    rbp                     */ 0x5d,
        /* ret                            */ 0xc3,
    ]),
    Code!(float, ">=", Zero!float)([
        /* push   rbp                     */ 0x55,
        /* mov    rbp,rsp                 */ 0x48, 0x8b, 0xec,
        /* sub    rsp,0x10                */ 0x48, 0x83, 0xec, 0x10,
        /* xor    eax,eax                 */ 0x31, 0xc0,
        /* mov    DWORD PTR [rbp-0x10],eax */ 0x89, 0x45, 0xf0,
        /* movss  xmm1,DWORD PTR [rbp-0x10] */ 0xf3, 0x0f, 0x10, 0x4d, 0xf0,
        /* ucomiss xmm1,xmm0              */ 0x0f, 0x2e, 0xc8,
        /* mov    eax,0x1                 */ 0xb8, 0x01, 0x00, 0x00, 0x00,
        /* jp     1e <testee_float_ge_zero+0x1e> */ 0x7a, 0x02,
        /* jbe    20 <testee_float_ge_zero+0x20> */ 0x76, 0x02,
        /* xor    eax,eax                 */ 0x31, 0xc0,
        /* mov    rsp,rbp                 */ 0x48, 0x8b, 0xe5,
        /* pop    rbp                     */ 0x5d,
        /* ret                            */ 0xc3,
        /* add    BYTE PTR [rax],al       */ 0x00, 0x00,
    ]),
    Code!(float, ">=", float)([
        /* push   rbp                     */ 0x55,
        /* mov    rbp,rsp                 */ 0x48, 0x8b, 0xec,
        /* ucomiss xmm0,xmm1              */ 0x0f, 0x2e, 0xc1,
        /* mov    eax,0x1                 */ 0xb8, 0x01, 0x00, 0x00, 0x00,
        /* jp     10 <testee_float_ge_float+0x10> */ 0x7a, 0x02,
        /* jbe    12 <testee_float_ge_float+0x12> */ 0x76, 0x02,
        /* xor    eax,eax                 */ 0x31, 0xc0,
        /* pop    rbp                     */ 0x5d,
        /* ret                            */ 0xc3,
    ]),
    Code!(float, ">", Zero!float)([
        /* push   rbp                     */ 0x55,
        /* mov    rbp,rsp                 */ 0x48, 0x8b, 0xec,
        /* sub    rsp,0x10                */ 0x48, 0x83, 0xec, 0x10,
        /* xor    eax,eax                 */ 0x31, 0xc0,
        /* mov    DWORD PTR [rbp-0x10],eax */ 0x89, 0x45, 0xf0,
        /* movss  xmm1,DWORD PTR [rbp-0x10] */ 0xf3, 0x0f, 0x10, 0x4d, 0xf0,
        /* ucomiss xmm1,xmm0              */ 0x0f, 0x2e, 0xc8,
        /* mov    eax,0x1                 */ 0xb8, 0x01, 0x00, 0x00, 0x00,
        /* jp     1e <testee_float_gt_zero+0x1e> */ 0x7a, 0x02,
        /* jb     20 <testee_float_gt_zero+0x20> */ 0x72, 0x02,
        /* xor    eax,eax                 */ 0x31, 0xc0,
        /* mov    rsp,rbp                 */ 0x48, 0x8b, 0xe5,
        /* pop    rbp                     */ 0x5d,
        /* ret                            */ 0xc3,
        /* add    BYTE PTR [rax],al       */ 0x00, 0x00,
    ]),
    Code!(float, ">", float)([
        /* push   rbp                     */ 0x55,
        /* mov    rbp,rsp                 */ 0x48, 0x8b, 0xec,
        /* ucomiss xmm0,xmm1              */ 0x0f, 0x2e, 0xc1,
        /* mov    eax,0x1                 */ 0xb8, 0x01, 0x00, 0x00, 0x00,
        /* jp     10 <testee_float_gt_float+0x10> */ 0x7a, 0x02,
        /* jb     12 <testee_float_gt_float+0x12> */ 0x72, 0x02,
        /* xor    eax,eax                 */ 0x31, 0xc0,
        /* pop    rbp                     */ 0x5d,
        /* ret                            */ 0xc3,
    ]),
    Code!(double, "<", Zero!double)([
        /* push   rbp                     */ 0x55,
        /* mov    rbp,rsp                 */ 0x48, 0x8b, 0xec,
        /* sub    rsp,0x10                */ 0x48, 0x83, 0xec, 0x10,
        /* xor    eax,eax                 */ 0x31, 0xc0,
        /* mov    QWORD PTR [rbp-0x10],rax */ 0x48, 0x89, 0x45, 0xf0,
        /* movsd  xmm1,QWORD PTR [rbp-0x10] */ 0xf2, 0x0f, 0x10, 0x4d, 0xf0,
        /* ucomisd xmm1,xmm0              */ 0x66, 0x0f, 0x2e, 0xc8,
        /* seta   al                      */ 0x0f, 0x97, 0xc0,
        /* mov    rsp,rbp                 */ 0x48, 0x8b, 0xe5,
        /* pop    rbp                     */ 0x5d,
        /* ret                            */ 0xc3,
    ]),
    Code!(double, "<", double)([
        /* push   rbp                     */ 0x55,
        /* mov    rbp,rsp                 */ 0x48, 0x8b, 0xec,
        /* ucomisd xmm0,xmm1              */ 0x66, 0x0f, 0x2e, 0xc1,
        /* seta   al                      */ 0x0f, 0x97, 0xc0,
        /* pop    rbp                     */ 0x5d,
        /* ret                            */ 0xc3,
        /* add    BYTE PTR [rax],al       */ 0x00, 0x00,
    ]),
    Code!(double, "<=", Zero!double)([
        /* push   rbp                     */ 0x55,
        /* mov    rbp,rsp                 */ 0x48, 0x8b, 0xec,
        /* sub    rsp,0x10                */ 0x48, 0x83, 0xec, 0x10,
        /* xor    eax,eax                 */ 0x31, 0xc0,
        /* mov    QWORD PTR [rbp-0x10],rax */ 0x48, 0x89, 0x45, 0xf0,
        /* movsd  xmm1,QWORD PTR [rbp-0x10] */ 0xf2, 0x0f, 0x10, 0x4d, 0xf0,
        /* ucomisd xmm1,xmm0              */ 0x66, 0x0f, 0x2e, 0xc8,
        /* setae  al                      */ 0x0f, 0x93, 0xc0,
        /* mov    rsp,rbp                 */ 0x48, 0x8b, 0xe5,
        /* pop    rbp                     */ 0x5d,
        /* ret                            */ 0xc3,
    ]),
    Code!(double, "<=", double)([
        /* push   rbp                     */ 0x55,
        /* mov    rbp,rsp                 */ 0x48, 0x8b, 0xec,
        /* ucomisd xmm0,xmm1              */ 0x66, 0x0f, 0x2e, 0xc1,
        /* setae  al                      */ 0x0f, 0x93, 0xc0,
        /* pop    rbp                     */ 0x5d,
        /* ret                            */ 0xc3,
        /* add    BYTE PTR [rax],al       */ 0x00, 0x00,
    ]),
    Code!(double, "==", Zero!double)([
        /* push   rbp                     */ 0x55,
        /* mov    rbp,rsp                 */ 0x48, 0x8b, 0xec,
        /* sub    rsp,0x10                */ 0x48, 0x83, 0xec, 0x10,
        /* movsd  QWORD PTR [rbp-0x8],xmm0 */ 0xf2, 0x0f, 0x11, 0x45, 0xf8,
        /* mov    rax,QWORD PTR [rbp-0x8] */ 0x48, 0x8b, 0x45, 0xf8,
        /* add    rax,rax                 */ 0x48, 0x01, 0xc0,
        /* je     1a <testee_double_eq_zero+0x1a> */ 0x74, 0x04,
        /* xor    eax,eax                 */ 0x31, 0xc0,
        /* jmp    1f <testee_double_eq_zero+0x1f> */ 0xeb, 0x05,
        /* mov    eax,0x1                 */ 0xb8, 0x01, 0x00, 0x00, 0x00,
        /* mov    rsp,rbp                 */ 0x48, 0x8b, 0xe5,
        /* pop    rbp                     */ 0x5d,
        /* ret                            */ 0xc3,
    ]),
    Code!(double, "==", double)([
        /* push   rbp                     */ 0x55,
        /* mov    rbp,rsp                 */ 0x48, 0x8b, 0xec,
        /* ucomisd xmm0,xmm1              */ 0x66, 0x0f, 0x2e, 0xc1,
        /* mov    eax,0x1                 */ 0xb8, 0x01, 0x00, 0x00, 0x00,
        /* jp     11 <testee_double_eq_double+0x11> */ 0x7a, 0x02,
        /* je     13 <testee_double_eq_double+0x13> */ 0x74, 0x02,
        /* xor    eax,eax                 */ 0x31, 0xc0,
        /* pop    rbp                     */ 0x5d,
        /* ret                            */ 0xc3,
        /* add    BYTE PTR [rax],al       */ 0x00, 0x00,
    ]),
    Code!(double, "!=", Zero!double)([
        /* push   rbp                     */ 0x55,
        /* mov    rbp,rsp                 */ 0x48, 0x8b, 0xec,
        /* sub    rsp,0x10                */ 0x48, 0x83, 0xec, 0x10,
        /* movsd  QWORD PTR [rbp-0x8],xmm0 */ 0xf2, 0x0f, 0x11, 0x45, 0xf8,
        /* mov    rax,QWORD PTR [rbp-0x8] */ 0x48, 0x8b, 0x45, 0xf8,
        /* add    rax,rax                 */ 0x48, 0x01, 0xc0,
        /* jne    1a <testee_double_ne_zero+0x1a> */ 0x75, 0x04,
        /* xor    eax,eax                 */ 0x31, 0xc0,
        /* jmp    1f <testee_double_ne_zero+0x1f> */ 0xeb, 0x05,
        /* mov    eax,0x1                 */ 0xb8, 0x01, 0x00, 0x00, 0x00,
        /* mov    rsp,rbp                 */ 0x48, 0x8b, 0xe5,
        /* pop    rbp                     */ 0x5d,
        /* ret                            */ 0xc3,
    ]),
    Code!(double, "!=", double)([
        /* push   rbp                     */ 0x55,
        /* mov    rbp,rsp                 */ 0x48, 0x8b, 0xec,
        /* ucomisd xmm0,xmm1              */ 0x66, 0x0f, 0x2e, 0xc1,
        /* mov    eax,0x1                 */ 0xb8, 0x01, 0x00, 0x00, 0x00,
        /* jne    13 <testee_double_ne_double+0x13> */ 0x75, 0x04,
        /* jp     13 <testee_double_ne_double+0x13> */ 0x7a, 0x02,
        /* xor    eax,eax                 */ 0x31, 0xc0,
        /* pop    rbp                     */ 0x5d,
        /* ret                            */ 0xc3,
        /* add    BYTE PTR [rax],al       */ 0x00, 0x00,
    ]),
    Code!(double, ">=", Zero!double)([
        /* push   rbp                     */ 0x55,
        /* mov    rbp,rsp                 */ 0x48, 0x8b, 0xec,
        /* sub    rsp,0x10                */ 0x48, 0x83, 0xec, 0x10,
        /* xor    eax,eax                 */ 0x31, 0xc0,
        /* mov    QWORD PTR [rbp-0x10],rax */ 0x48, 0x89, 0x45, 0xf0,
        /* movsd  xmm1,QWORD PTR [rbp-0x10] */ 0xf2, 0x0f, 0x10, 0x4d, 0xf0,
        /* ucomisd xmm1,xmm0              */ 0x66, 0x0f, 0x2e, 0xc8,
        /* mov    eax,0x1                 */ 0xb8, 0x01, 0x00, 0x00, 0x00,
        /* jp     20 <testee_double_ge_zero+0x20> */ 0x7a, 0x02,
        /* jbe    22 <testee_double_ge_zero+0x22> */ 0x76, 0x02,
        /* xor    eax,eax                 */ 0x31, 0xc0,
        /* mov    rsp,rbp                 */ 0x48, 0x8b, 0xe5,
        /* pop    rbp                     */ 0x5d,
        /* ret                            */ 0xc3,
    ]),
    Code!(double, ">=", double)([
        /* push   rbp                     */ 0x55,
        /* mov    rbp,rsp                 */ 0x48, 0x8b, 0xec,
        /* ucomisd xmm0,xmm1              */ 0x66, 0x0f, 0x2e, 0xc1,
        /* mov    eax,0x1                 */ 0xb8, 0x01, 0x00, 0x00, 0x00,
        /* jp     11 <testee_double_ge_double+0x11> */ 0x7a, 0x02,
        /* jbe    13 <testee_double_ge_double+0x13> */ 0x76, 0x02,
        /* xor    eax,eax                 */ 0x31, 0xc0,
        /* pop    rbp                     */ 0x5d,
        /* ret                            */ 0xc3,
        /* add    BYTE PTR [rax],al       */ 0x00, 0x00,
    ]),
    Code!(double, ">", Zero!double)([
        /* push   rbp                     */ 0x55,
        /* mov    rbp,rsp                 */ 0x48, 0x8b, 0xec,
        /* sub    rsp,0x10                */ 0x48, 0x83, 0xec, 0x10,
        /* xor    eax,eax                 */ 0x31, 0xc0,
        /* mov    QWORD PTR [rbp-0x10],rax */ 0x48, 0x89, 0x45, 0xf0,
        /* movsd  xmm1,QWORD PTR [rbp-0x10] */ 0xf2, 0x0f, 0x10, 0x4d, 0xf0,
        /* ucomisd xmm1,xmm0              */ 0x66, 0x0f, 0x2e, 0xc8,
        /* mov    eax,0x1                 */ 0xb8, 0x01, 0x00, 0x00, 0x00,
        /* jp     20 <testee_double_gt_zero+0x20> */ 0x7a, 0x02,
        /* jb     22 <testee_double_gt_zero+0x22> */ 0x72, 0x02,
        /* xor    eax,eax                 */ 0x31, 0xc0,
        /* mov    rsp,rbp                 */ 0x48, 0x8b, 0xe5,
        /* pop    rbp                     */ 0x5d,
        /* ret                            */ 0xc3,
    ]),
    Code!(double, ">", double)([
        /* push   rbp                     */ 0x55,
        /* mov    rbp,rsp                 */ 0x48, 0x8b, 0xec,
        /* ucomisd xmm0,xmm1              */ 0x66, 0x0f, 0x2e, 0xc1,
        /* mov    eax,0x1                 */ 0xb8, 0x01, 0x00, 0x00, 0x00,
        /* jp     11 <testee_double_gt_double+0x11> */ 0x7a, 0x02,
        /* jb     13 <testee_double_gt_double+0x13> */ 0x72, 0x02,
        /* xor    eax,eax                 */ 0x31, 0xc0,
        /* pop    rbp                     */ 0x5d,
        /* ret                            */ 0xc3,
        /* add    BYTE PTR [rax],al       */ 0x00, 0x00,
    ]),
);

// dfmt on

bool matches(const(ubyte)[] code, const(ubyte)[] exp)
{
    assert(code.length == exp.length);
    foreach (ref i; 0 .. code.length)
    {
        if (code[i] == exp[i])
            continue;
        // wildcard match for relative call displacement
        if (i && exp.length - (i - 1) >= 5 && exp[i - 1 .. i + 4] == [0xe8, 0x00, 0x00, 0x00, 0x00])
        {
            i += 3;
            continue;
        }
        return false;
    }
    return true;
}

alias testCases = AliasSeq!(baselineCases);

void main()
{
    foreach (tc; testCases)
    (){ // workaround Issue 7157
        auto code = (cast(ubyte*)&testee!(tc.T, tc.op, tc.T2))[0 .. tc.code.length];
        bool failure;
        if (!code.matches(tc.code))
        {
            fprintf(stderr, "Expected code sequence for testee!(%s, \"%s\", %s) not found.",
                tc.T.stringof.ptr, tc.op.ptr, tc.T2.stringof.ptr);
            fprintf(stderr, "\n  Expected:");
            foreach (i, d; tc.code)
            {
                if (tc.code[i] != code[i])
                    fprintf(stderr, " \033[32m0x%02x\033[0m", d);
                else
                    fprintf(stderr, " 0x%02x", d);
            }
            fprintf(stderr, "\n    Actual:");
            foreach (i, d; code)
            {
                if (tc.code[i] != code[i])
                    fprintf(stderr, " \033[31m0x%02x\033[0m", d);
                else
                    fprintf(stderr, " 0x%02x", d);
            }
            fprintf(stderr, "\n");
            failure = true;
        }
        assert(!failure);
    }();
}
