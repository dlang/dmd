// REQUIRED_ARGS: -O -fPIC
// PERMUTE_ARGS: -mcpu=avx -mcpu=avx2
// only testing on SYSV-ABI, but backend code is identical across platforms
// DISABLED: win32 win64 osx linux32 freebsd32
debug = PRINTF;
debug (PRINTF) import core.stdc.stdio;

// Run this after codegen changes:
// env DMD=generated/linux/release/64/dmd rdmd -fPIC -version=update test/runnable/test_cdvecfill.d
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
        baseline,
        avx,
        avx2,
    }

    size_t[] sizes(Arch arch)
    {
        final switch (arch)
        {
        case Arch.baseline:
            return [16];
        case Arch.avx:
        case Arch.avx2:
            return [16, 32];
        }
    }

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
            // Just add empty Code!(newtype, count)(null) elements when adding a new type
            foreach (type; AliasSeq!(ubyte, byte, ushort, short, uint, int,
                    ulong, long, float, double))
            {
                foreach (sz; sizes(arch))
                {
                    foreach (suffix; [tuple("", ""), tuple("_ptr", "*")])
                    {
                        args = ["objdump", "--disassemble", "--disassembler-options=intel-mnemonic",
                            "--section=.text.testee_" ~ type.stringof ~ suffix[0] ~ "_" ~ (sz / type.sizeof)
                                .to!string, __FILE__.baseName.setExtension(".o")];
                        auto p = pipeProcess(args);
                        formattedWrite(sink, "    Code!(%s%s, %s / %s.sizeof)([\n",
                                type.stringof, suffix[1], sz, type.stringof);
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
else:

template testee(T, int N)
{
    pragma(mangle, "testee_" ~ T.stringof ~ "_" ~ N.stringof)
    __vector(T[N]) testee(T val)
    {
        return val;
    }
}

template testee(T : T*, int N)
{
    pragma(mangle, "testee_" ~ T.stringof ~ "_ptr_" ~ N.stringof)
    __vector(T[N]) testee(T* val)
    {
        return *val;
    }
}

struct Code(T_, int N_)
{
    alias T = T_;
    alias N = N_;
    ubyte[] code;
}

alias AliasSeq(Args...) = Args;

// dfmt off
alias baselineCases = AliasSeq!(
    Code!(ubyte, 16 / ubyte.sizeof)([
        /* push   rbp                     */ 0x55,
        /* mov    rbp,rsp                 */ 0x48, 0x8b, 0xec,
        /* movd   xmm0,edi                */ 0x66, 0x0f, 0x6e, 0xc7,
        /* punpcklbw xmm0,xmm0            */ 0x66, 0x0f, 0x60, 0xc0,
        /* punpcklwd xmm0,xmm0            */ 0x66, 0x0f, 0x61, 0xc0,
        /* pshufd xmm0,xmm0,0x0           */ 0x66, 0x0f, 0x70, 0xc0, 0x00,
        /* pop    rbp                     */ 0x5d,
        /* ret                            */ 0xc3,
    ]),
    Code!(ubyte*, 16 / ubyte.sizeof)([
        /* push   rbp                     */ 0x55,
        /* mov    rbp,rsp                 */ 0x48, 0x8b, 0xec,
        /* movzx  eax,BYTE PTR [rdi]      */ 0x0f, 0xb6, 0x07,
        /* movd   xmm0,eax                */ 0x66, 0x0f, 0x6e, 0xc0,
        /* punpcklbw xmm0,xmm0            */ 0x66, 0x0f, 0x60, 0xc0,
        /* punpcklwd xmm0,xmm0            */ 0x66, 0x0f, 0x61, 0xc0,
        /* pshufd xmm0,xmm0,0x0           */ 0x66, 0x0f, 0x70, 0xc0, 0x00,
        /* pop    rbp                     */ 0x5d,
        /* ret                            */ 0xc3,
    ]),
    Code!(byte, 16 / byte.sizeof)([
        /* push   rbp                     */ 0x55,
        /* mov    rbp,rsp                 */ 0x48, 0x8b, 0xec,
        /* movd   xmm0,edi                */ 0x66, 0x0f, 0x6e, 0xc7,
        /* punpcklbw xmm0,xmm0            */ 0x66, 0x0f, 0x60, 0xc0,
        /* punpcklwd xmm0,xmm0            */ 0x66, 0x0f, 0x61, 0xc0,
        /* pshufd xmm0,xmm0,0x0           */ 0x66, 0x0f, 0x70, 0xc0, 0x00,
        /* pop    rbp                     */ 0x5d,
        /* ret                            */ 0xc3,
    ]),
    Code!(byte*, 16 / byte.sizeof)([
        /* push   rbp                     */ 0x55,
        /* mov    rbp,rsp                 */ 0x48, 0x8b, 0xec,
        /* movsx  eax,BYTE PTR [rdi]      */ 0x0f, 0xbe, 0x07,
        /* movd   xmm0,eax                */ 0x66, 0x0f, 0x6e, 0xc0,
        /* punpcklbw xmm0,xmm0            */ 0x66, 0x0f, 0x60, 0xc0,
        /* punpcklwd xmm0,xmm0            */ 0x66, 0x0f, 0x61, 0xc0,
        /* pshufd xmm0,xmm0,0x0           */ 0x66, 0x0f, 0x70, 0xc0, 0x00,
        /* pop    rbp                     */ 0x5d,
        /* ret                            */ 0xc3,
    ]),
    Code!(ushort, 16 / ushort.sizeof)([
        /* push   rbp                     */ 0x55,
        /* mov    rbp,rsp                 */ 0x48, 0x8b, 0xec,
        /* movd   xmm0,edi                */ 0x66, 0x0f, 0x6e, 0xc7,
        /* punpcklwd xmm0,xmm0            */ 0x66, 0x0f, 0x61, 0xc0,
        /* pshufd xmm0,xmm0,0x0           */ 0x66, 0x0f, 0x70, 0xc0, 0x00,
        /* pop    rbp                     */ 0x5d,
        /* ret                            */ 0xc3,
    ]),
    Code!(ushort*, 16 / ushort.sizeof)([
        /* push   rbp                     */ 0x55,
        /* mov    rbp,rsp                 */ 0x48, 0x8b, 0xec,
        /* movzx  eax,WORD PTR [rdi]      */ 0x0f, 0xb7, 0x07,
        /* movd   xmm0,eax                */ 0x66, 0x0f, 0x6e, 0xc0,
        /* punpcklwd xmm0,xmm0            */ 0x66, 0x0f, 0x61, 0xc0,
        /* pshufd xmm0,xmm0,0x0           */ 0x66, 0x0f, 0x70, 0xc0, 0x00,
        /* pop    rbp                     */ 0x5d,
        /* ret                            */ 0xc3,
    ]),
    Code!(short, 16 / short.sizeof)([
        /* push   rbp                     */ 0x55,
        /* mov    rbp,rsp                 */ 0x48, 0x8b, 0xec,
        /* movd   xmm0,edi                */ 0x66, 0x0f, 0x6e, 0xc7,
        /* punpcklwd xmm0,xmm0            */ 0x66, 0x0f, 0x61, 0xc0,
        /* pshufd xmm0,xmm0,0x0           */ 0x66, 0x0f, 0x70, 0xc0, 0x00,
        /* pop    rbp                     */ 0x5d,
        /* ret                            */ 0xc3,
    ]),
    Code!(short*, 16 / short.sizeof)([
        /* push   rbp                     */ 0x55,
        /* mov    rbp,rsp                 */ 0x48, 0x8b, 0xec,
        /* movsx  eax,WORD PTR [rdi]      */ 0x0f, 0xbf, 0x07,
        /* movd   xmm0,eax                */ 0x66, 0x0f, 0x6e, 0xc0,
        /* punpcklwd xmm0,xmm0            */ 0x66, 0x0f, 0x61, 0xc0,
        /* pshufd xmm0,xmm0,0x0           */ 0x66, 0x0f, 0x70, 0xc0, 0x00,
        /* pop    rbp                     */ 0x5d,
        /* ret                            */ 0xc3,
    ]),
    Code!(uint, 16 / uint.sizeof)([
        /* push   rbp                     */ 0x55,
        /* mov    rbp,rsp                 */ 0x48, 0x8b, 0xec,
        /* movd   xmm0,edi                */ 0x66, 0x0f, 0x6e, 0xc7,
        /* pshufd xmm0,xmm0,0x0           */ 0x66, 0x0f, 0x70, 0xc0, 0x00,
        /* pop    rbp                     */ 0x5d,
        /* ret                            */ 0xc3,
    ]),
    Code!(uint*, 16 / uint.sizeof)([
        /* push   rbp                     */ 0x55,
        /* mov    rbp,rsp                 */ 0x48, 0x8b, 0xec,
        /* movd   xmm0,DWORD PTR [rdi]    */ 0x66, 0x0f, 0x6e, 0x07,
        /* pshufd xmm0,xmm0,0x0           */ 0x66, 0x0f, 0x70, 0xc0, 0x00,
        /* pop    rbp                     */ 0x5d,
        /* ret                            */ 0xc3,
    ]),
    Code!(int, 16 / int.sizeof)([
        /* push   rbp                     */ 0x55,
        /* mov    rbp,rsp                 */ 0x48, 0x8b, 0xec,
        /* movd   xmm0,edi                */ 0x66, 0x0f, 0x6e, 0xc7,
        /* pshufd xmm0,xmm0,0x0           */ 0x66, 0x0f, 0x70, 0xc0, 0x00,
        /* pop    rbp                     */ 0x5d,
        /* ret                            */ 0xc3,
    ]),
    Code!(int*, 16 / int.sizeof)([
        /* push   rbp                     */ 0x55,
        /* mov    rbp,rsp                 */ 0x48, 0x8b, 0xec,
        /* movd   xmm0,DWORD PTR [rdi]    */ 0x66, 0x0f, 0x6e, 0x07,
        /* pshufd xmm0,xmm0,0x0           */ 0x66, 0x0f, 0x70, 0xc0, 0x00,
        /* pop    rbp                     */ 0x5d,
        /* ret                            */ 0xc3,
    ]),
    Code!(ulong, 16 / ulong.sizeof)([
        /* push   rbp                     */ 0x55,
        /* mov    rbp,rsp                 */ 0x48, 0x8b, 0xec,
        /* movq   xmm0,rdi                */ 0x66, 0x48, 0x0f, 0x6e, 0xc7,
        /* punpcklqdq xmm0,xmm0           */ 0x66, 0x0f, 0x6c, 0xc0,
        /* pop    rbp                     */ 0x5d,
        /* ret                            */ 0xc3,
    ]),
    Code!(ulong*, 16 / ulong.sizeof)([
        /* push   rbp                     */ 0x55,
        /* mov    rbp,rsp                 */ 0x48, 0x8b, 0xec,
        /* punpcklqdq xmm0,XMMWORD PTR [rdi] */ 0x66, 0x0f, 0x6c, 0x07,
        /* pop    rbp                     */ 0x5d,
        /* ret                            */ 0xc3,
    ]),
    Code!(long, 16 / long.sizeof)([
        /* push   rbp                     */ 0x55,
        /* mov    rbp,rsp                 */ 0x48, 0x8b, 0xec,
        /* movq   xmm0,rdi                */ 0x66, 0x48, 0x0f, 0x6e, 0xc7,
        /* punpcklqdq xmm0,xmm0           */ 0x66, 0x0f, 0x6c, 0xc0,
        /* pop    rbp                     */ 0x5d,
        /* ret                            */ 0xc3,
    ]),
    Code!(long*, 16 / long.sizeof)([
        /* push   rbp                     */ 0x55,
        /* mov    rbp,rsp                 */ 0x48, 0x8b, 0xec,
        /* punpcklqdq xmm0,XMMWORD PTR [rdi] */ 0x66, 0x0f, 0x6c, 0x07,
        /* pop    rbp                     */ 0x5d,
        /* ret                            */ 0xc3,
    ]),
    Code!(float, 16 / float.sizeof)([
        /* push   rbp                     */ 0x55,
        /* mov    rbp,rsp                 */ 0x48, 0x8b, 0xec,
        /* shufps xmm0,xmm0,0x0           */ 0x0f, 0xc6, 0xc0, 0x00,
        /* pop    rbp                     */ 0x5d,
        /* ret                            */ 0xc3,
    ]),
    Code!(float*, 16 / float.sizeof)([
        /* push   rbp                     */ 0x55,
        /* mov    rbp,rsp                 */ 0x48, 0x8b, 0xec,
        /* movss  xmm0,DWORD PTR [rdi]    */ 0xf3, 0x0f, 0x10, 0x07,
        /* shufps xmm0,xmm0,0x0           */ 0x0f, 0xc6, 0xc0, 0x00,
        /* pop    rbp                     */ 0x5d,
        /* ret                            */ 0xc3,
    ]),
    Code!(double, 16 / double.sizeof)([
        /* push   rbp                     */ 0x55,
        /* mov    rbp,rsp                 */ 0x48, 0x8b, 0xec,
        /* unpcklpd xmm0,xmm0             */ 0x66, 0x0f, 0x14, 0xc0,
        /* pop    rbp                     */ 0x5d,
        /* ret                            */ 0xc3,
    ]),
    Code!(double*, 16 / double.sizeof)([
        /* push   rbp                     */ 0x55,
        /* mov    rbp,rsp                 */ 0x48, 0x8b, 0xec,
        /* movsd  xmm0,QWORD PTR [rdi]    */ 0xf2, 0x0f, 0x10, 0x07,
        /* unpcklpd xmm0,xmm0             */ 0x66, 0x0f, 0x14, 0xc0,
        /* pop    rbp                     */ 0x5d,
        /* ret                            */ 0xc3,
    ]),
);

alias avxCases = AliasSeq!(
    Code!(ubyte, 16 / ubyte.sizeof)([
        /* push   rbp                     */ 0x55,
        /* mov    rbp,rsp                 */ 0x48, 0x8b, 0xec,
        /* vmovd  xmm0,edi                */ 0xc5, 0xf9, 0x6e, 0xc7,
        /* vpxor  xmm1,xmm1,xmm1          */ 0xc5, 0xf1, 0xef, 0xc9,
        /* vpshufb xmm0,xmm0,xmm1         */ 0xc4, 0xe2, 0x79, 0x00, 0xc1,
        /* pop    rbp                     */ 0x5d,
        /* ret                            */ 0xc3,
    ]),
    Code!(ubyte*, 16 / ubyte.sizeof)([
        /* push   rbp                     */ 0x55,
        /* mov    rbp,rsp                 */ 0x48, 0x8b, 0xec,
        /* movzx  eax,BYTE PTR [rdi]      */ 0x0f, 0xb6, 0x07,
        /* vmovd  xmm0,eax                */ 0xc5, 0xf9, 0x6e, 0xc0,
        /* vpxor  xmm1,xmm1,xmm1          */ 0xc5, 0xf1, 0xef, 0xc9,
        /* vpshufb xmm0,xmm0,xmm1         */ 0xc4, 0xe2, 0x79, 0x00, 0xc1,
        /* pop    rbp                     */ 0x5d,
        /* ret                            */ 0xc3,
    ]),
    Code!(ubyte, 32 / ubyte.sizeof)([
        /* push   rbp                     */ 0x55,
        /* mov    rbp,rsp                 */ 0x48, 0x8b, 0xec,
        /* vmovd  xmm0,edi                */ 0xc5, 0xf9, 0x6e, 0xc7,
        /* vpxor  xmm1,xmm1,xmm1          */ 0xc5, 0xf1, 0xef, 0xc9,
        /* vpshufb xmm0,xmm0,xmm1         */ 0xc4, 0xe2, 0x79, 0x00, 0xc1,
        /* vinsertf128 ymm0,ymm0,xmm0,0x1 */ 0xc4, 0xe3, 0x7d, 0x18, 0xc0, 0x01,
        /* pop    rbp                     */ 0x5d,
        /* ret                            */ 0xc3,
        /* add    BYTE PTR [rax],al       */ 0x00, 0x00,
    ]),
    Code!(ubyte*, 32 / ubyte.sizeof)([
        /* push   rbp                     */ 0x55,
        /* mov    rbp,rsp                 */ 0x48, 0x8b, 0xec,
        /* movzx  eax,BYTE PTR [rdi]      */ 0x0f, 0xb6, 0x07,
        /* vmovd  xmm0,eax                */ 0xc5, 0xf9, 0x6e, 0xc0,
        /* vpxor  xmm1,xmm1,xmm1          */ 0xc5, 0xf1, 0xef, 0xc9,
        /* vpshufb xmm0,xmm0,xmm1         */ 0xc4, 0xe2, 0x79, 0x00, 0xc1,
        /* vinsertf128 ymm0,ymm0,xmm0,0x1 */ 0xc4, 0xe3, 0x7d, 0x18, 0xc0, 0x01,
        /* pop    rbp                     */ 0x5d,
        /* ret                            */ 0xc3,
    ]),
    Code!(byte, 16 / byte.sizeof)([
        /* push   rbp                     */ 0x55,
        /* mov    rbp,rsp                 */ 0x48, 0x8b, 0xec,
        /* vmovd  xmm0,edi                */ 0xc5, 0xf9, 0x6e, 0xc7,
        /* vpxor  xmm1,xmm1,xmm1          */ 0xc5, 0xf1, 0xef, 0xc9,
        /* vpshufb xmm0,xmm0,xmm1         */ 0xc4, 0xe2, 0x79, 0x00, 0xc1,
        /* pop    rbp                     */ 0x5d,
        /* ret                            */ 0xc3,
    ]),
    Code!(byte*, 16 / byte.sizeof)([
        /* push   rbp                     */ 0x55,
        /* mov    rbp,rsp                 */ 0x48, 0x8b, 0xec,
        /* movsx  eax,BYTE PTR [rdi]      */ 0x0f, 0xbe, 0x07,
        /* vmovd  xmm0,eax                */ 0xc5, 0xf9, 0x6e, 0xc0,
        /* vpxor  xmm1,xmm1,xmm1          */ 0xc5, 0xf1, 0xef, 0xc9,
        /* vpshufb xmm0,xmm0,xmm1         */ 0xc4, 0xe2, 0x79, 0x00, 0xc1,
        /* pop    rbp                     */ 0x5d,
        /* ret                            */ 0xc3,
    ]),
    Code!(byte, 32 / byte.sizeof)([
        /* push   rbp                     */ 0x55,
        /* mov    rbp,rsp                 */ 0x48, 0x8b, 0xec,
        /* vmovd  xmm0,edi                */ 0xc5, 0xf9, 0x6e, 0xc7,
        /* vpxor  xmm1,xmm1,xmm1          */ 0xc5, 0xf1, 0xef, 0xc9,
        /* vpshufb xmm0,xmm0,xmm1         */ 0xc4, 0xe2, 0x79, 0x00, 0xc1,
        /* vinsertf128 ymm0,ymm0,xmm0,0x1 */ 0xc4, 0xe3, 0x7d, 0x18, 0xc0, 0x01,
        /* pop    rbp                     */ 0x5d,
        /* ret                            */ 0xc3,
        /* add    BYTE PTR [rax],al       */ 0x00, 0x00,
    ]),
    Code!(byte*, 32 / byte.sizeof)([
        /* push   rbp                     */ 0x55,
        /* mov    rbp,rsp                 */ 0x48, 0x8b, 0xec,
        /* movsx  eax,BYTE PTR [rdi]      */ 0x0f, 0xbe, 0x07,
        /* vmovd  xmm0,eax                */ 0xc5, 0xf9, 0x6e, 0xc0,
        /* vpxor  xmm1,xmm1,xmm1          */ 0xc5, 0xf1, 0xef, 0xc9,
        /* vpshufb xmm0,xmm0,xmm1         */ 0xc4, 0xe2, 0x79, 0x00, 0xc1,
        /* vinsertf128 ymm0,ymm0,xmm0,0x1 */ 0xc4, 0xe3, 0x7d, 0x18, 0xc0, 0x01,
        /* pop    rbp                     */ 0x5d,
        /* ret                            */ 0xc3,
    ]),
    Code!(ushort, 16 / ushort.sizeof)([
        /* push   rbp                     */ 0x55,
        /* mov    rbp,rsp                 */ 0x48, 0x8b, 0xec,
        /* vmovd  xmm0,edi                */ 0xc5, 0xf9, 0x6e, 0xc7,
        /* vpunpcklwd xmm0,xmm0,xmm0      */ 0xc5, 0xf9, 0x61, 0xc0,
        /* vpshufd xmm0,xmm0,0x0          */ 0xc5, 0xf9, 0x70, 0xc0, 0x00,
        /* pop    rbp                     */ 0x5d,
        /* ret                            */ 0xc3,
    ]),
    Code!(ushort*, 16 / ushort.sizeof)([
        /* push   rbp                     */ 0x55,
        /* mov    rbp,rsp                 */ 0x48, 0x8b, 0xec,
        /* movzx  eax,WORD PTR [rdi]      */ 0x0f, 0xb7, 0x07,
        /* vmovd  xmm0,eax                */ 0xc5, 0xf9, 0x6e, 0xc0,
        /* vpunpcklwd xmm0,xmm0,xmm0      */ 0xc5, 0xf9, 0x61, 0xc0,
        /* vpshufd xmm0,xmm0,0x0          */ 0xc5, 0xf9, 0x70, 0xc0, 0x00,
        /* pop    rbp                     */ 0x5d,
        /* ret                            */ 0xc3,
    ]),
    Code!(ushort, 32 / ushort.sizeof)([
        /* push   rbp                     */ 0x55,
        /* mov    rbp,rsp                 */ 0x48, 0x8b, 0xec,
        /* vmovd  xmm0,edi                */ 0xc5, 0xf9, 0x6e, 0xc7,
        /* vpunpcklwd xmm0,xmm0,xmm0      */ 0xc5, 0xf9, 0x61, 0xc0,
        /* vpshufd xmm0,xmm0,0x0          */ 0xc5, 0xf9, 0x70, 0xc0, 0x00,
        /* vinsertf128 ymm0,ymm0,xmm0,0x1 */ 0xc4, 0xe3, 0x7d, 0x18, 0xc0, 0x01,
        /* pop    rbp                     */ 0x5d,
        /* ret                            */ 0xc3,
        /* add    BYTE PTR [rax],al       */ 0x00, 0x00,
    ]),
    Code!(ushort*, 32 / ushort.sizeof)([
        /* push   rbp                     */ 0x55,
        /* mov    rbp,rsp                 */ 0x48, 0x8b, 0xec,
        /* movzx  eax,WORD PTR [rdi]      */ 0x0f, 0xb7, 0x07,
        /* vmovd  xmm0,eax                */ 0xc5, 0xf9, 0x6e, 0xc0,
        /* vpunpcklwd xmm0,xmm0,xmm0      */ 0xc5, 0xf9, 0x61, 0xc0,
        /* vpshufd xmm0,xmm0,0x0          */ 0xc5, 0xf9, 0x70, 0xc0, 0x00,
        /* vinsertf128 ymm0,ymm0,xmm0,0x1 */ 0xc4, 0xe3, 0x7d, 0x18, 0xc0, 0x01,
        /* pop    rbp                     */ 0x5d,
        /* ret                            */ 0xc3,
    ]),
    Code!(short, 16 / short.sizeof)([
        /* push   rbp                     */ 0x55,
        /* mov    rbp,rsp                 */ 0x48, 0x8b, 0xec,
        /* vmovd  xmm0,edi                */ 0xc5, 0xf9, 0x6e, 0xc7,
        /* vpunpcklwd xmm0,xmm0,xmm0      */ 0xc5, 0xf9, 0x61, 0xc0,
        /* vpshufd xmm0,xmm0,0x0          */ 0xc5, 0xf9, 0x70, 0xc0, 0x00,
        /* pop    rbp                     */ 0x5d,
        /* ret                            */ 0xc3,
    ]),
    Code!(short*, 16 / short.sizeof)([
        /* push   rbp                     */ 0x55,
        /* mov    rbp,rsp                 */ 0x48, 0x8b, 0xec,
        /* movsx  eax,WORD PTR [rdi]      */ 0x0f, 0xbf, 0x07,
        /* vmovd  xmm0,eax                */ 0xc5, 0xf9, 0x6e, 0xc0,
        /* vpunpcklwd xmm0,xmm0,xmm0      */ 0xc5, 0xf9, 0x61, 0xc0,
        /* vpshufd xmm0,xmm0,0x0          */ 0xc5, 0xf9, 0x70, 0xc0, 0x00,
        /* pop    rbp                     */ 0x5d,
        /* ret                            */ 0xc3,
    ]),
    Code!(short, 32 / short.sizeof)([
        /* push   rbp                     */ 0x55,
        /* mov    rbp,rsp                 */ 0x48, 0x8b, 0xec,
        /* vmovd  xmm0,edi                */ 0xc5, 0xf9, 0x6e, 0xc7,
        /* vpunpcklwd xmm0,xmm0,xmm0      */ 0xc5, 0xf9, 0x61, 0xc0,
        /* vpshufd xmm0,xmm0,0x0          */ 0xc5, 0xf9, 0x70, 0xc0, 0x00,
        /* vinsertf128 ymm0,ymm0,xmm0,0x1 */ 0xc4, 0xe3, 0x7d, 0x18, 0xc0, 0x01,
        /* pop    rbp                     */ 0x5d,
        /* ret                            */ 0xc3,
        /* add    BYTE PTR [rax],al       */ 0x00, 0x00,
    ]),
    Code!(short*, 32 / short.sizeof)([
        /* push   rbp                     */ 0x55,
        /* mov    rbp,rsp                 */ 0x48, 0x8b, 0xec,
        /* movsx  eax,WORD PTR [rdi]      */ 0x0f, 0xbf, 0x07,
        /* vmovd  xmm0,eax                */ 0xc5, 0xf9, 0x6e, 0xc0,
        /* vpunpcklwd xmm0,xmm0,xmm0      */ 0xc5, 0xf9, 0x61, 0xc0,
        /* vpshufd xmm0,xmm0,0x0          */ 0xc5, 0xf9, 0x70, 0xc0, 0x00,
        /* vinsertf128 ymm0,ymm0,xmm0,0x1 */ 0xc4, 0xe3, 0x7d, 0x18, 0xc0, 0x01,
        /* pop    rbp                     */ 0x5d,
        /* ret                            */ 0xc3,
    ]),
    Code!(uint, 16 / uint.sizeof)([
        /* push   rbp                     */ 0x55,
        /* mov    rbp,rsp                 */ 0x48, 0x8b, 0xec,
        /* vmovd  xmm0,edi                */ 0xc5, 0xf9, 0x6e, 0xc7,
        /* vpshufd xmm0,xmm0,0x0          */ 0xc5, 0xf9, 0x70, 0xc0, 0x00,
        /* pop    rbp                     */ 0x5d,
        /* ret                            */ 0xc3,
    ]),
    Code!(uint*, 16 / uint.sizeof)([
        /* push   rbp                     */ 0x55,
        /* mov    rbp,rsp                 */ 0x48, 0x8b, 0xec,
        /* vbroadcastss xmm0,DWORD PTR [rdi] */ 0xc4, 0xe2, 0x79, 0x18, 0x07,
        /* pop    rbp                     */ 0x5d,
        /* ret                            */ 0xc3,
    ]),
    Code!(uint, 32 / uint.sizeof)([
        /* push   rbp                     */ 0x55,
        /* mov    rbp,rsp                 */ 0x48, 0x8b, 0xec,
        /* vmovd  xmm0,edi                */ 0xc5, 0xf9, 0x6e, 0xc7,
        /* vpshufd xmm0,xmm0,0x0          */ 0xc5, 0xf9, 0x70, 0xc0, 0x00,
        /* vinsertf128 ymm0,ymm0,xmm0,0x1 */ 0xc4, 0xe3, 0x7d, 0x18, 0xc0, 0x01,
        /* pop    rbp                     */ 0x5d,
        /* ret                            */ 0xc3,
        /* add    BYTE PTR [rax],al       */ 0x00, 0x00,
    ]),
    Code!(uint*, 32 / uint.sizeof)([
        /* push   rbp                     */ 0x55,
        /* mov    rbp,rsp                 */ 0x48, 0x8b, 0xec,
        /* vbroadcastss ymm0,DWORD PTR [rdi] */ 0xc4, 0xe2, 0x7d, 0x18, 0x07,
        /* pop    rbp                     */ 0x5d,
        /* ret                            */ 0xc3,
    ]),
    Code!(int, 16 / int.sizeof)([
        /* push   rbp                     */ 0x55,
        /* mov    rbp,rsp                 */ 0x48, 0x8b, 0xec,
        /* vmovd  xmm0,edi                */ 0xc5, 0xf9, 0x6e, 0xc7,
        /* vpshufd xmm0,xmm0,0x0          */ 0xc5, 0xf9, 0x70, 0xc0, 0x00,
        /* pop    rbp                     */ 0x5d,
        /* ret                            */ 0xc3,
    ]),
    Code!(int*, 16 / int.sizeof)([
        /* push   rbp                     */ 0x55,
        /* mov    rbp,rsp                 */ 0x48, 0x8b, 0xec,
        /* vbroadcastss xmm0,DWORD PTR [rdi] */ 0xc4, 0xe2, 0x79, 0x18, 0x07,
        /* pop    rbp                     */ 0x5d,
        /* ret                            */ 0xc3,
    ]),
    Code!(int, 32 / int.sizeof)([
        /* push   rbp                     */ 0x55,
        /* mov    rbp,rsp                 */ 0x48, 0x8b, 0xec,
        /* vmovd  xmm0,edi                */ 0xc5, 0xf9, 0x6e, 0xc7,
        /* vpshufd xmm0,xmm0,0x0          */ 0xc5, 0xf9, 0x70, 0xc0, 0x00,
        /* vinsertf128 ymm0,ymm0,xmm0,0x1 */ 0xc4, 0xe3, 0x7d, 0x18, 0xc0, 0x01,
        /* pop    rbp                     */ 0x5d,
        /* ret                            */ 0xc3,
        /* add    BYTE PTR [rax],al       */ 0x00, 0x00,
    ]),
    Code!(int*, 32 / int.sizeof)([
        /* push   rbp                     */ 0x55,
        /* mov    rbp,rsp                 */ 0x48, 0x8b, 0xec,
        /* vbroadcastss ymm0,DWORD PTR [rdi] */ 0xc4, 0xe2, 0x7d, 0x18, 0x07,
        /* pop    rbp                     */ 0x5d,
        /* ret                            */ 0xc3,
    ]),
    Code!(ulong, 16 / ulong.sizeof)([
        /* push   rbp                     */ 0x55,
        /* mov    rbp,rsp                 */ 0x48, 0x8b, 0xec,
        /* vmovq  xmm0,rdi                */ 0xc4, 0xe1, 0xf9, 0x6e, 0xc7,
        /* vpunpcklqdq xmm0,xmm0,xmm0     */ 0xc5, 0xf9, 0x6c, 0xc0,
        /* pop    rbp                     */ 0x5d,
        /* ret                            */ 0xc3,
    ]),
    Code!(ulong*, 16 / ulong.sizeof)([
        /* push   rbp                     */ 0x55,
        /* mov    rbp,rsp                 */ 0x48, 0x8b, 0xec,
        /* vpunpcklqdq xmm0,xmm0,XMMWORD PTR [rdi] */ 0xc5, 0xf9, 0x6c, 0x07,
        /* pop    rbp                     */ 0x5d,
        /* ret                            */ 0xc3,
    ]),
    Code!(ulong, 32 / ulong.sizeof)([
        /* push   rbp                     */ 0x55,
        /* mov    rbp,rsp                 */ 0x48, 0x8b, 0xec,
        /* vmovq  xmm0,rdi                */ 0xc4, 0xe1, 0xf9, 0x6e, 0xc7,
        /* vpunpcklqdq xmm0,xmm0,xmm0     */ 0xc5, 0xf9, 0x6c, 0xc0,
        /* vinsertf128 ymm0,ymm0,xmm0,0x1 */ 0xc4, 0xe3, 0x7d, 0x18, 0xc0, 0x01,
        /* pop    rbp                     */ 0x5d,
        /* ret                            */ 0xc3,
        /* add    BYTE PTR [rax],al       */ 0x00, 0x00,
    ]),
    Code!(ulong*, 32 / ulong.sizeof)([
        /* push   rbp                     */ 0x55,
        /* mov    rbp,rsp                 */ 0x48, 0x8b, 0xec,
        /* vbroadcastsd ymm0,QWORD PTR [rdi] */ 0xc4, 0xe2, 0x7d, 0x19, 0x07,
        /* pop    rbp                     */ 0x5d,
        /* ret                            */ 0xc3,
    ]),
    Code!(long, 16 / long.sizeof)([
        /* push   rbp                     */ 0x55,
        /* mov    rbp,rsp                 */ 0x48, 0x8b, 0xec,
        /* vmovq  xmm0,rdi                */ 0xc4, 0xe1, 0xf9, 0x6e, 0xc7,
        /* vpunpcklqdq xmm0,xmm0,xmm0     */ 0xc5, 0xf9, 0x6c, 0xc0,
        /* pop    rbp                     */ 0x5d,
        /* ret                            */ 0xc3,
    ]),
    Code!(long*, 16 / long.sizeof)([
        /* push   rbp                     */ 0x55,
        /* mov    rbp,rsp                 */ 0x48, 0x8b, 0xec,
        /* vpunpcklqdq xmm0,xmm0,XMMWORD PTR [rdi] */ 0xc5, 0xf9, 0x6c, 0x07,
        /* pop    rbp                     */ 0x5d,
        /* ret                            */ 0xc3,
    ]),
    Code!(long, 32 / long.sizeof)([
        /* push   rbp                     */ 0x55,
        /* mov    rbp,rsp                 */ 0x48, 0x8b, 0xec,
        /* vmovq  xmm0,rdi                */ 0xc4, 0xe1, 0xf9, 0x6e, 0xc7,
        /* vpunpcklqdq xmm0,xmm0,xmm0     */ 0xc5, 0xf9, 0x6c, 0xc0,
        /* vinsertf128 ymm0,ymm0,xmm0,0x1 */ 0xc4, 0xe3, 0x7d, 0x18, 0xc0, 0x01,
        /* pop    rbp                     */ 0x5d,
        /* ret                            */ 0xc3,
        /* add    BYTE PTR [rax],al       */ 0x00, 0x00,
    ]),
    Code!(long*, 32 / long.sizeof)([
        /* push   rbp                     */ 0x55,
        /* mov    rbp,rsp                 */ 0x48, 0x8b, 0xec,
        /* vbroadcastsd ymm0,QWORD PTR [rdi] */ 0xc4, 0xe2, 0x7d, 0x19, 0x07,
        /* pop    rbp                     */ 0x5d,
        /* ret                            */ 0xc3,
    ]),
    Code!(float, 16 / float.sizeof)([
        /* push   rbp                     */ 0x55,
        /* mov    rbp,rsp                 */ 0x48, 0x8b, 0xec,
        /* vshufps xmm0,xmm0,xmm0,0x0     */ 0xc5, 0xf8, 0xc6, 0xc0, 0x00,
        /* pop    rbp                     */ 0x5d,
        /* ret                            */ 0xc3,
    ]),
    Code!(float*, 16 / float.sizeof)([
        /* push   rbp                     */ 0x55,
        /* mov    rbp,rsp                 */ 0x48, 0x8b, 0xec,
        /* vbroadcastss xmm0,DWORD PTR [rdi] */ 0xc4, 0xe2, 0x79, 0x18, 0x07,
        /* pop    rbp                     */ 0x5d,
        /* ret                            */ 0xc3,
    ]),
    Code!(float, 32 / float.sizeof)([
        /* push   rbp                     */ 0x55,
        /* mov    rbp,rsp                 */ 0x48, 0x8b, 0xec,
        /* vshufps ymm0,ymm0,ymm0,0x0     */ 0xc5, 0xfc, 0xc6, 0xc0, 0x00,
        /* vinsertf128 ymm0,ymm0,xmm0,0x1 */ 0xc4, 0xe3, 0x7d, 0x18, 0xc0, 0x01,
        /* pop    rbp                     */ 0x5d,
        /* ret                            */ 0xc3,
        /* add    BYTE PTR [rax],al       */ 0x00, 0x00,
    ]),
    Code!(float*, 32 / float.sizeof)([
        /* push   rbp                     */ 0x55,
        /* mov    rbp,rsp                 */ 0x48, 0x8b, 0xec,
        /* vbroadcastss ymm0,DWORD PTR [rdi] */ 0xc4, 0xe2, 0x7d, 0x18, 0x07,
        /* pop    rbp                     */ 0x5d,
        /* ret                            */ 0xc3,
    ]),
    Code!(double, 16 / double.sizeof)([
        /* push   rbp                     */ 0x55,
        /* mov    rbp,rsp                 */ 0x48, 0x8b, 0xec,
        /* vunpcklpd xmm0,xmm0,xmm0       */ 0xc5, 0xf9, 0x14, 0xc0,
        /* pop    rbp                     */ 0x5d,
        /* ret                            */ 0xc3,
    ]),
    Code!(double*, 16 / double.sizeof)([
        /* push   rbp                     */ 0x55,
        /* mov    rbp,rsp                 */ 0x48, 0x8b, 0xec,
        /* vmovsd xmm0,QWORD PTR [rdi]    */ 0xc5, 0xfb, 0x10, 0x07,
        /* vunpcklpd xmm0,xmm0,xmm0       */ 0xc5, 0xf9, 0x14, 0xc0,
        /* pop    rbp                     */ 0x5d,
        /* ret                            */ 0xc3,
    ]),
    Code!(double, 32 / double.sizeof)([
        /* push   rbp                     */ 0x55,
        /* mov    rbp,rsp                 */ 0x48, 0x8b, 0xec,
        /* vunpcklpd xmm0,xmm0,xmm0       */ 0xc5, 0xf9, 0x14, 0xc0,
        /* vinsertf128 ymm0,ymm0,xmm0,0x1 */ 0xc4, 0xe3, 0x7d, 0x18, 0xc0, 0x01,
        /* pop    rbp                     */ 0x5d,
        /* ret                            */ 0xc3,
    ]),
    Code!(double*, 32 / double.sizeof)([
        /* push   rbp                     */ 0x55,
        /* mov    rbp,rsp                 */ 0x48, 0x8b, 0xec,
        /* vbroadcastsd ymm0,QWORD PTR [rdi] */ 0xc4, 0xe2, 0x7d, 0x19, 0x07,
        /* pop    rbp                     */ 0x5d,
        /* ret                            */ 0xc3,
    ]),
);

alias avx2Cases = AliasSeq!(
    Code!(ubyte, 16 / ubyte.sizeof)([
        /* push   rbp                     */ 0x55,
        /* mov    rbp,rsp                 */ 0x48, 0x8b, 0xec,
        /* vmovd  xmm0,edi                */ 0xc5, 0xf9, 0x6e, 0xc7,
        /* vpbroadcastb xmm0,xmm0         */ 0xc4, 0xe2, 0x79, 0x78, 0xc0,
        /* pop    rbp                     */ 0x5d,
        /* ret                            */ 0xc3,
    ]),
    Code!(ubyte*, 16 / ubyte.sizeof)([
        /* push   rbp                     */ 0x55,
        /* mov    rbp,rsp                 */ 0x48, 0x8b, 0xec,
        /* vpbroadcastb xmm0,BYTE PTR [rdi] */ 0xc4, 0xe2, 0x79, 0x78, 0x07,
        /* pop    rbp                     */ 0x5d,
        /* ret                            */ 0xc3,
    ]),
    Code!(ubyte, 32 / ubyte.sizeof)([
        /* push   rbp                     */ 0x55,
        /* mov    rbp,rsp                 */ 0x48, 0x8b, 0xec,
        /* vmovd  xmm0,edi                */ 0xc5, 0xf9, 0x6e, 0xc7,
        /* vpbroadcastb ymm0,xmm0         */ 0xc4, 0xe2, 0x7d, 0x78, 0xc0,
        /* pop    rbp                     */ 0x5d,
        /* ret                            */ 0xc3,
    ]),
    Code!(ubyte*, 32 / ubyte.sizeof)([
        /* push   rbp                     */ 0x55,
        /* mov    rbp,rsp                 */ 0x48, 0x8b, 0xec,
        /* vpbroadcastb ymm0,BYTE PTR [rdi] */ 0xc4, 0xe2, 0x7d, 0x78, 0x07,
        /* pop    rbp                     */ 0x5d,
        /* ret                            */ 0xc3,
    ]),
    Code!(byte, 16 / byte.sizeof)([
        /* push   rbp                     */ 0x55,
        /* mov    rbp,rsp                 */ 0x48, 0x8b, 0xec,
        /* vmovd  xmm0,edi                */ 0xc5, 0xf9, 0x6e, 0xc7,
        /* vpbroadcastb xmm0,xmm0         */ 0xc4, 0xe2, 0x79, 0x78, 0xc0,
        /* pop    rbp                     */ 0x5d,
        /* ret                            */ 0xc3,
    ]),
    Code!(byte*, 16 / byte.sizeof)([
        /* push   rbp                     */ 0x55,
        /* mov    rbp,rsp                 */ 0x48, 0x8b, 0xec,
        /* vpbroadcastb xmm0,BYTE PTR [rdi] */ 0xc4, 0xe2, 0x79, 0x78, 0x07,
        /* pop    rbp                     */ 0x5d,
        /* ret                            */ 0xc3,
    ]),
    Code!(byte, 32 / byte.sizeof)([
        /* push   rbp                     */ 0x55,
        /* mov    rbp,rsp                 */ 0x48, 0x8b, 0xec,
        /* vmovd  xmm0,edi                */ 0xc5, 0xf9, 0x6e, 0xc7,
        /* vpbroadcastb ymm0,xmm0         */ 0xc4, 0xe2, 0x7d, 0x78, 0xc0,
        /* pop    rbp                     */ 0x5d,
        /* ret                            */ 0xc3,
    ]),
    Code!(byte*, 32 / byte.sizeof)([
        /* push   rbp                     */ 0x55,
        /* mov    rbp,rsp                 */ 0x48, 0x8b, 0xec,
        /* vpbroadcastb ymm0,BYTE PTR [rdi] */ 0xc4, 0xe2, 0x7d, 0x78, 0x07,
        /* pop    rbp                     */ 0x5d,
        /* ret                            */ 0xc3,
    ]),
    Code!(ushort, 16 / ushort.sizeof)([
        /* push   rbp                     */ 0x55,
        /* mov    rbp,rsp                 */ 0x48, 0x8b, 0xec,
        /* vmovd  xmm0,edi                */ 0xc5, 0xf9, 0x6e, 0xc7,
        /* vpbroadcastw xmm0,xmm0         */ 0xc4, 0xe2, 0x79, 0x79, 0xc0,
        /* pop    rbp                     */ 0x5d,
        /* ret                            */ 0xc3,
    ]),
    Code!(ushort*, 16 / ushort.sizeof)([
        /* push   rbp                     */ 0x55,
        /* mov    rbp,rsp                 */ 0x48, 0x8b, 0xec,
        /* vpbroadcastw xmm0,WORD PTR [rdi] */ 0xc4, 0xe2, 0x79, 0x79, 0x07,
        /* pop    rbp                     */ 0x5d,
        /* ret                            */ 0xc3,
    ]),
    Code!(ushort, 32 / ushort.sizeof)([
        /* push   rbp                     */ 0x55,
        /* mov    rbp,rsp                 */ 0x48, 0x8b, 0xec,
        /* vmovd  xmm0,edi                */ 0xc5, 0xf9, 0x6e, 0xc7,
        /* vpbroadcastw ymm0,xmm0         */ 0xc4, 0xe2, 0x7d, 0x79, 0xc0,
        /* pop    rbp                     */ 0x5d,
        /* ret                            */ 0xc3,
    ]),
    Code!(ushort*, 32 / ushort.sizeof)([
        /* push   rbp                     */ 0x55,
        /* mov    rbp,rsp                 */ 0x48, 0x8b, 0xec,
        /* vpbroadcastw ymm0,WORD PTR [rdi] */ 0xc4, 0xe2, 0x7d, 0x79, 0x07,
        /* pop    rbp                     */ 0x5d,
        /* ret                            */ 0xc3,
    ]),
    Code!(short, 16 / short.sizeof)([
        /* push   rbp                     */ 0x55,
        /* mov    rbp,rsp                 */ 0x48, 0x8b, 0xec,
        /* vmovd  xmm0,edi                */ 0xc5, 0xf9, 0x6e, 0xc7,
        /* vpbroadcastw xmm0,xmm0         */ 0xc4, 0xe2, 0x79, 0x79, 0xc0,
        /* pop    rbp                     */ 0x5d,
        /* ret                            */ 0xc3,
    ]),
    Code!(short*, 16 / short.sizeof)([
        /* push   rbp                     */ 0x55,
        /* mov    rbp,rsp                 */ 0x48, 0x8b, 0xec,
        /* vpbroadcastw xmm0,WORD PTR [rdi] */ 0xc4, 0xe2, 0x79, 0x79, 0x07,
        /* pop    rbp                     */ 0x5d,
        /* ret                            */ 0xc3,
    ]),
    Code!(short, 32 / short.sizeof)([
        /* push   rbp                     */ 0x55,
        /* mov    rbp,rsp                 */ 0x48, 0x8b, 0xec,
        /* vmovd  xmm0,edi                */ 0xc5, 0xf9, 0x6e, 0xc7,
        /* vpbroadcastw ymm0,xmm0         */ 0xc4, 0xe2, 0x7d, 0x79, 0xc0,
        /* pop    rbp                     */ 0x5d,
        /* ret                            */ 0xc3,
    ]),
    Code!(short*, 32 / short.sizeof)([
        /* push   rbp                     */ 0x55,
        /* mov    rbp,rsp                 */ 0x48, 0x8b, 0xec,
        /* vpbroadcastw ymm0,WORD PTR [rdi] */ 0xc4, 0xe2, 0x7d, 0x79, 0x07,
        /* pop    rbp                     */ 0x5d,
        /* ret                            */ 0xc3,
    ]),
    Code!(uint, 16 / uint.sizeof)([
        /* push   rbp                     */ 0x55,
        /* mov    rbp,rsp                 */ 0x48, 0x8b, 0xec,
        /* vmovd  xmm0,edi                */ 0xc5, 0xf9, 0x6e, 0xc7,
        /* vpbroadcastd xmm0,xmm0         */ 0xc4, 0xe2, 0x79, 0x58, 0xc0,
        /* pop    rbp                     */ 0x5d,
        /* ret                            */ 0xc3,
    ]),
    Code!(uint*, 16 / uint.sizeof)([
        /* push   rbp                     */ 0x55,
        /* mov    rbp,rsp                 */ 0x48, 0x8b, 0xec,
        /* vpbroadcastd xmm0,DWORD PTR [rdi] */ 0xc4, 0xe2, 0x79, 0x58, 0x07,
        /* pop    rbp                     */ 0x5d,
        /* ret                            */ 0xc3,
    ]),
    Code!(uint, 32 / uint.sizeof)([
        /* push   rbp                     */ 0x55,
        /* mov    rbp,rsp                 */ 0x48, 0x8b, 0xec,
        /* vmovd  xmm0,edi                */ 0xc5, 0xf9, 0x6e, 0xc7,
        /* vpbroadcastd ymm0,xmm0         */ 0xc4, 0xe2, 0x7d, 0x58, 0xc0,
        /* pop    rbp                     */ 0x5d,
        /* ret                            */ 0xc3,
    ]),
    Code!(uint*, 32 / uint.sizeof)([
        /* push   rbp                     */ 0x55,
        /* mov    rbp,rsp                 */ 0x48, 0x8b, 0xec,
        /* vpbroadcastd ymm0,DWORD PTR [rdi] */ 0xc4, 0xe2, 0x7d, 0x58, 0x07,
        /* pop    rbp                     */ 0x5d,
        /* ret                            */ 0xc3,
    ]),
    Code!(int, 16 / int.sizeof)([
        /* push   rbp                     */ 0x55,
        /* mov    rbp,rsp                 */ 0x48, 0x8b, 0xec,
        /* vmovd  xmm0,edi                */ 0xc5, 0xf9, 0x6e, 0xc7,
        /* vpbroadcastd xmm0,xmm0         */ 0xc4, 0xe2, 0x79, 0x58, 0xc0,
        /* pop    rbp                     */ 0x5d,
        /* ret                            */ 0xc3,
    ]),
    Code!(int*, 16 / int.sizeof)([
        /* push   rbp                     */ 0x55,
        /* mov    rbp,rsp                 */ 0x48, 0x8b, 0xec,
        /* vpbroadcastd xmm0,DWORD PTR [rdi] */ 0xc4, 0xe2, 0x79, 0x58, 0x07,
        /* pop    rbp                     */ 0x5d,
        /* ret                            */ 0xc3,
    ]),
    Code!(int, 32 / int.sizeof)([
        /* push   rbp                     */ 0x55,
        /* mov    rbp,rsp                 */ 0x48, 0x8b, 0xec,
        /* vmovd  xmm0,edi                */ 0xc5, 0xf9, 0x6e, 0xc7,
        /* vpbroadcastd ymm0,xmm0         */ 0xc4, 0xe2, 0x7d, 0x58, 0xc0,
        /* pop    rbp                     */ 0x5d,
        /* ret                            */ 0xc3,
    ]),
    Code!(int*, 32 / int.sizeof)([
        /* push   rbp                     */ 0x55,
        /* mov    rbp,rsp                 */ 0x48, 0x8b, 0xec,
        /* vpbroadcastd ymm0,DWORD PTR [rdi] */ 0xc4, 0xe2, 0x7d, 0x58, 0x07,
        /* pop    rbp                     */ 0x5d,
        /* ret                            */ 0xc3,
    ]),
    Code!(ulong, 16 / ulong.sizeof)([
        /* push   rbp                     */ 0x55,
        /* mov    rbp,rsp                 */ 0x48, 0x8b, 0xec,
        /* vmovq  xmm0,rdi                */ 0xc4, 0xe1, 0xf9, 0x6e, 0xc7,
        /* vpbroadcastq xmm0,xmm0         */ 0xc4, 0xe2, 0x79, 0x59, 0xc0,
        /* pop    rbp                     */ 0x5d,
        /* ret                            */ 0xc3,
    ]),
    Code!(ulong*, 16 / ulong.sizeof)([
        /* push   rbp                     */ 0x55,
        /* mov    rbp,rsp                 */ 0x48, 0x8b, 0xec,
        /* vpbroadcastq xmm0,QWORD PTR [rdi] */ 0xc4, 0xe2, 0x79, 0x59, 0x07,
        /* pop    rbp                     */ 0x5d,
        /* ret                            */ 0xc3,
    ]),
    Code!(ulong, 32 / ulong.sizeof)([
        /* push   rbp                     */ 0x55,
        /* mov    rbp,rsp                 */ 0x48, 0x8b, 0xec,
        /* vmovq  xmm0,rdi                */ 0xc4, 0xe1, 0xf9, 0x6e, 0xc7,
        /* vpbroadcastq ymm0,xmm0         */ 0xc4, 0xe2, 0x7d, 0x59, 0xc0,
        /* pop    rbp                     */ 0x5d,
        /* ret                            */ 0xc3,
    ]),
    Code!(ulong*, 32 / ulong.sizeof)([
        /* push   rbp                     */ 0x55,
        /* mov    rbp,rsp                 */ 0x48, 0x8b, 0xec,
        /* vpbroadcastq ymm0,QWORD PTR [rdi] */ 0xc4, 0xe2, 0x7d, 0x59, 0x07,
        /* pop    rbp                     */ 0x5d,
        /* ret                            */ 0xc3,
    ]),
    Code!(long, 16 / long.sizeof)([
        /* push   rbp                     */ 0x55,
        /* mov    rbp,rsp                 */ 0x48, 0x8b, 0xec,
        /* vmovq  xmm0,rdi                */ 0xc4, 0xe1, 0xf9, 0x6e, 0xc7,
        /* vpbroadcastq xmm0,xmm0         */ 0xc4, 0xe2, 0x79, 0x59, 0xc0,
        /* pop    rbp                     */ 0x5d,
        /* ret                            */ 0xc3,
    ]),
    Code!(long*, 16 / long.sizeof)([
        /* push   rbp                     */ 0x55,
        /* mov    rbp,rsp                 */ 0x48, 0x8b, 0xec,
        /* vpbroadcastq xmm0,QWORD PTR [rdi] */ 0xc4, 0xe2, 0x79, 0x59, 0x07,
        /* pop    rbp                     */ 0x5d,
        /* ret                            */ 0xc3,
    ]),
    Code!(long, 32 / long.sizeof)([
        /* push   rbp                     */ 0x55,
        /* mov    rbp,rsp                 */ 0x48, 0x8b, 0xec,
        /* vmovq  xmm0,rdi                */ 0xc4, 0xe1, 0xf9, 0x6e, 0xc7,
        /* vpbroadcastq ymm0,xmm0         */ 0xc4, 0xe2, 0x7d, 0x59, 0xc0,
        /* pop    rbp                     */ 0x5d,
        /* ret                            */ 0xc3,
    ]),
    Code!(long*, 32 / long.sizeof)([
        /* push   rbp                     */ 0x55,
        /* mov    rbp,rsp                 */ 0x48, 0x8b, 0xec,
        /* vpbroadcastq ymm0,QWORD PTR [rdi] */ 0xc4, 0xe2, 0x7d, 0x59, 0x07,
        /* pop    rbp                     */ 0x5d,
        /* ret                            */ 0xc3,
    ]),
    Code!(float, 16 / float.sizeof)([
        /* push   rbp                     */ 0x55,
        /* mov    rbp,rsp                 */ 0x48, 0x8b, 0xec,
        /* vbroadcastss xmm0,xmm0         */ 0xc4, 0xe2, 0x79, 0x18, 0xc0,
        /* pop    rbp                     */ 0x5d,
        /* ret                            */ 0xc3,
    ]),
    Code!(float*, 16 / float.sizeof)([
        /* push   rbp                     */ 0x55,
        /* mov    rbp,rsp                 */ 0x48, 0x8b, 0xec,
        /* vbroadcastss xmm0,DWORD PTR [rdi] */ 0xc4, 0xe2, 0x79, 0x18, 0x07,
        /* pop    rbp                     */ 0x5d,
        /* ret                            */ 0xc3,
    ]),
    Code!(float, 32 / float.sizeof)([
        /* push   rbp                     */ 0x55,
        /* mov    rbp,rsp                 */ 0x48, 0x8b, 0xec,
        /* vbroadcastss ymm0,xmm0         */ 0xc4, 0xe2, 0x7d, 0x18, 0xc0,
        /* pop    rbp                     */ 0x5d,
        /* ret                            */ 0xc3,
    ]),
    Code!(float*, 32 / float.sizeof)([
        /* push   rbp                     */ 0x55,
        /* mov    rbp,rsp                 */ 0x48, 0x8b, 0xec,
        /* vbroadcastss ymm0,DWORD PTR [rdi] */ 0xc4, 0xe2, 0x7d, 0x18, 0x07,
        /* pop    rbp                     */ 0x5d,
        /* ret                            */ 0xc3,
    ]),
    Code!(double, 16 / double.sizeof)([
        /* push   rbp                     */ 0x55,
        /* mov    rbp,rsp                 */ 0x48, 0x8b, 0xec,
        /* vunpcklpd xmm0,xmm0,xmm0       */ 0xc5, 0xf9, 0x14, 0xc0,
        /* pop    rbp                     */ 0x5d,
        /* ret                            */ 0xc3,
    ]),
    Code!(double*, 16 / double.sizeof)([
        /* push   rbp                     */ 0x55,
        /* mov    rbp,rsp                 */ 0x48, 0x8b, 0xec,
        /* vmovsd xmm0,QWORD PTR [rdi]    */ 0xc5, 0xfb, 0x10, 0x07,
        /* vunpcklpd xmm0,xmm0,xmm0       */ 0xc5, 0xf9, 0x14, 0xc0,
        /* pop    rbp                     */ 0x5d,
        /* ret                            */ 0xc3,
    ]),
    Code!(double, 32 / double.sizeof)([
        /* push   rbp                     */ 0x55,
        /* mov    rbp,rsp                 */ 0x48, 0x8b, 0xec,
        /* vbroadcastsd ymm0,xmm0         */ 0xc4, 0xe2, 0x7d, 0x19, 0xc0,
        /* pop    rbp                     */ 0x5d,
        /* ret                            */ 0xc3,
    ]),
    Code!(double*, 32 / double.sizeof)([
        /* push   rbp                     */ 0x55,
        /* mov    rbp,rsp                 */ 0x48, 0x8b, 0xec,
        /* vbroadcastsd ymm0,QWORD PTR [rdi] */ 0xc4, 0xe2, 0x7d, 0x19, 0x07,
        /* pop    rbp                     */ 0x5d,
        /* ret                            */ 0xc3,
    ]),
);

// dfmt on

version (D_AVX2)
    alias testCases = AliasSeq!(avx2Cases);
else version (D_AVX)
    alias testCases = AliasSeq!(avxCases);
else version (D_SIMD)
    alias testCases = AliasSeq!(baselineCases);
else
    alias testCases = AliasSeq!();

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

void main()
{
    foreach (tc; testCases)
    (){ // workaround Issue 7157
        auto code = (cast(ubyte*)&testee!(tc.T, tc.N))[0 .. tc.code.length];
        bool failure;
        if (!code.matches(tc.code))
        {
            fprintf(stderr, "Expected code sequence for testee!(%s, %u) not found.",
                    tc.T.stringof.ptr, tc.N);
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
