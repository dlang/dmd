// REQUIRED_ARGS: -O
// PERMUTE_ARGS: -mcpu=avx -mcpu=avx2
// only testing on SYSV-ABI, but backend code is identical across platforms
// DISABLED: win32 win64 osx linux32 freebsd32
debug = PRINTF;
debug (PRINTF) import core.stdc.stdio;

// Run `env DMD=generated/linux/release/64/dmd rdmd -version=update test/runnable/test_cdvecfill.d` after codegen changes.
version (update)
{
    import std.algorithm : canFind, find, splitter, until;
    import std.array : appender, join;
    import std.conv : to;
    import std.exception : enforce;
    import std.file : readText;
    import std.format : formattedWrite;
    import std.meta : AliasSeq;
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
        enum src = "test/runnable/test_cdvecfill.d";
        auto dmd = environment.get("DMD", "dmd");
        auto sink = appender!string();
        foreach (arch; [EnumMembers!Arch])
        {
            auto args = [dmd, "-c", "-O", "-mcpu=" ~ arch.to!string, "test/runnable/test_cdvecfill.d"];
            auto rc = execute(args);
            enforce(rc.status == 0, rc.output);
            formattedWrite(sink, "alias %sCases = AliasSeq!(\n", arch);
            // Just add empty Code!(newtype, count)(null) elements when adding a new type
            foreach (type; AliasSeq!(ubyte, byte, ushort, short, uint, int, ulong, long, float, double))
            {
                foreach (sz; sizes(arch))
                {
                    foreach (suffix; [tuple("", ""), tuple("_ptr", "*")])
                    {
                        args = ["objdump", "--disassemble", "--disassembler-options=intel-mnemonic",
                                "--section=.text.load_" ~ type.stringof ~ suffix[0] ~ "_" ~ (sz / type.sizeof)
                                .to!string, "test_cdvecfill.o"];
                        auto p = pipeProcess(args);
                        formattedWrite(sink, "    Code!(%s%s, %s / %s.sizeof)([\n", type.stringof, suffix[1], sz, type.stringof);
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
            replaceFirstInto!((_, orng) => formattedWrite(orng, "// dfmt off\n%s// dfmt on", sink.data))(orng, content, ctRegex!(`^// dfmt off[^$]*// dfmt on$`, "m"));
        }
    }
}
else:

template load(T, int N)
{
    pragma(mangle, "load_"~T.stringof~"_"~N.stringof)
    __vector(T[N]) load(T val)
    {
        return val;
    }
}

template load(T : T*, int N)
{
    pragma(mangle, "load_"~T.stringof~"_ptr_"~N.stringof)
    __vector(T[N]) load(T* val)
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
        /* push   rax                     */ 0x50,
        /* movd   xmm0,edi                */ 0x66, 0x0f, 0x6e, 0xc7,
        /* punpcklbw xmm0,xmm0            */ 0x66, 0x0f, 0x60, 0xc0,
        /* punpcklwd xmm0,xmm0            */ 0x66, 0x0f, 0x61, 0xc0,
        /* pshufd xmm0,xmm0,0x0           */ 0x66, 0x0f, 0x70, 0xc0, 0x00,
        /* pop    rcx                     */ 0x59,
        /* ret                            */ 0xc3,
    ]),
    Code!(ubyte*, 16 / ubyte.sizeof)([
        /* push   rax                     */ 0x50,
        /* movzx  eax,BYTE PTR [rdi]      */ 0x0f, 0xb6, 0x07,
        /* movd   xmm0,eax                */ 0x66, 0x0f, 0x6e, 0xc0,
        /* punpcklbw xmm0,xmm0            */ 0x66, 0x0f, 0x60, 0xc0,
        /* punpcklwd xmm0,xmm0            */ 0x66, 0x0f, 0x61, 0xc0,
        /* pshufd xmm0,xmm0,0x0           */ 0x66, 0x0f, 0x70, 0xc0, 0x00,
        /* pop    rcx                     */ 0x59,
        /* ret                            */ 0xc3,
    ]),
    Code!(byte, 16 / byte.sizeof)([
        /* push   rax                     */ 0x50,
        /* movd   xmm0,edi                */ 0x66, 0x0f, 0x6e, 0xc7,
        /* punpcklbw xmm0,xmm0            */ 0x66, 0x0f, 0x60, 0xc0,
        /* punpcklwd xmm0,xmm0            */ 0x66, 0x0f, 0x61, 0xc0,
        /* pshufd xmm0,xmm0,0x0           */ 0x66, 0x0f, 0x70, 0xc0, 0x00,
        /* pop    rcx                     */ 0x59,
        /* ret                            */ 0xc3,
    ]),
    Code!(byte*, 16 / byte.sizeof)([
        /* push   rax                     */ 0x50,
        /* movsx  eax,BYTE PTR [rdi]      */ 0x0f, 0xbe, 0x07,
        /* movd   xmm0,eax                */ 0x66, 0x0f, 0x6e, 0xc0,
        /* punpcklbw xmm0,xmm0            */ 0x66, 0x0f, 0x60, 0xc0,
        /* punpcklwd xmm0,xmm0            */ 0x66, 0x0f, 0x61, 0xc0,
        /* pshufd xmm0,xmm0,0x0           */ 0x66, 0x0f, 0x70, 0xc0, 0x00,
        /* pop    rcx                     */ 0x59,
        /* ret                            */ 0xc3,
    ]),
    Code!(ushort, 16 / ushort.sizeof)([
        /* push   rax                     */ 0x50,
        /* movd   xmm0,edi                */ 0x66, 0x0f, 0x6e, 0xc7,
        /* punpcklwd xmm0,xmm0            */ 0x66, 0x0f, 0x61, 0xc0,
        /* pshufd xmm0,xmm0,0x0           */ 0x66, 0x0f, 0x70, 0xc0, 0x00,
        /* pop    rcx                     */ 0x59,
        /* ret                            */ 0xc3,
    ]),
    Code!(ushort*, 16 / ushort.sizeof)([
        /* push   rax                     */ 0x50,
        /* movzx  eax,WORD PTR [rdi]      */ 0x0f, 0xb7, 0x07,
        /* movd   xmm0,eax                */ 0x66, 0x0f, 0x6e, 0xc0,
        /* punpcklwd xmm0,xmm0            */ 0x66, 0x0f, 0x61, 0xc0,
        /* pshufd xmm0,xmm0,0x0           */ 0x66, 0x0f, 0x70, 0xc0, 0x00,
        /* pop    rcx                     */ 0x59,
        /* ret                            */ 0xc3,
    ]),
    Code!(short, 16 / short.sizeof)([
        /* push   rax                     */ 0x50,
        /* movd   xmm0,edi                */ 0x66, 0x0f, 0x6e, 0xc7,
        /* punpcklwd xmm0,xmm0            */ 0x66, 0x0f, 0x61, 0xc0,
        /* pshufd xmm0,xmm0,0x0           */ 0x66, 0x0f, 0x70, 0xc0, 0x00,
        /* pop    rcx                     */ 0x59,
        /* ret                            */ 0xc3,
    ]),
    Code!(short*, 16 / short.sizeof)([
        /* push   rax                     */ 0x50,
        /* movsx  eax,WORD PTR [rdi]      */ 0x0f, 0xbf, 0x07,
        /* movd   xmm0,eax                */ 0x66, 0x0f, 0x6e, 0xc0,
        /* punpcklwd xmm0,xmm0            */ 0x66, 0x0f, 0x61, 0xc0,
        /* pshufd xmm0,xmm0,0x0           */ 0x66, 0x0f, 0x70, 0xc0, 0x00,
        /* pop    rcx                     */ 0x59,
        /* ret                            */ 0xc3,
    ]),
    Code!(uint, 16 / uint.sizeof)([
        /* push   rax                     */ 0x50,
        /* movd   xmm0,edi                */ 0x66, 0x0f, 0x6e, 0xc7,
        /* pshufd xmm0,xmm0,0x0           */ 0x66, 0x0f, 0x70, 0xc0, 0x00,
        /* pop    rcx                     */ 0x59,
        /* ret                            */ 0xc3,
    ]),
    Code!(uint*, 16 / uint.sizeof)([
        /* push   rax                     */ 0x50,
        /* mov    eax,DWORD PTR [rdi]     */ 0x8b, 0x07,
        /* movd   xmm0,eax                */ 0x66, 0x0f, 0x6e, 0xc0,
        /* pshufd xmm0,xmm0,0x0           */ 0x66, 0x0f, 0x70, 0xc0, 0x00,
        /* pop    rcx                     */ 0x59,
        /* ret                            */ 0xc3,
    ]),
    Code!(int, 16 / int.sizeof)([
        /* push   rax                     */ 0x50,
        /* movd   xmm0,edi                */ 0x66, 0x0f, 0x6e, 0xc7,
        /* pshufd xmm0,xmm0,0x0           */ 0x66, 0x0f, 0x70, 0xc0, 0x00,
        /* pop    rcx                     */ 0x59,
        /* ret                            */ 0xc3,
    ]),
    Code!(int*, 16 / int.sizeof)([
        /* push   rax                     */ 0x50,
        /* mov    eax,DWORD PTR [rdi]     */ 0x8b, 0x07,
        /* movd   xmm0,eax                */ 0x66, 0x0f, 0x6e, 0xc0,
        /* pshufd xmm0,xmm0,0x0           */ 0x66, 0x0f, 0x70, 0xc0, 0x00,
        /* pop    rcx                     */ 0x59,
        /* ret                            */ 0xc3,
    ]),
    Code!(ulong, 16 / ulong.sizeof)([
        /* push   rax                     */ 0x50,
        /* movq   xmm0,rdi                */ 0x66, 0x48, 0x0f, 0x6e, 0xc7,
        /* punpcklqdq xmm0,xmm0           */ 0x66, 0x0f, 0x6c, 0xc0,
        /* pop    rcx                     */ 0x59,
        /* ret                            */ 0xc3,
    ]),
    Code!(ulong*, 16 / ulong.sizeof)([
        /* push   rax                     */ 0x50,
        /* punpcklqdq xmm0,XMMWORD PTR [rdi] */ 0x66, 0x0f, 0x6c, 0x07,
        /* pop    rcx                     */ 0x59,
        /* ret                            */ 0xc3,
    ]),
    Code!(long, 16 / long.sizeof)([
        /* push   rax                     */ 0x50,
        /* movq   xmm0,rdi                */ 0x66, 0x48, 0x0f, 0x6e, 0xc7,
        /* punpcklqdq xmm0,xmm0           */ 0x66, 0x0f, 0x6c, 0xc0,
        /* pop    rcx                     */ 0x59,
        /* ret                            */ 0xc3,
    ]),
    Code!(long*, 16 / long.sizeof)([
        /* push   rax                     */ 0x50,
        /* punpcklqdq xmm0,XMMWORD PTR [rdi] */ 0x66, 0x0f, 0x6c, 0x07,
        /* pop    rcx                     */ 0x59,
        /* ret                            */ 0xc3,
    ]),
    Code!(float, 16 / float.sizeof)([
        /* push   rax                     */ 0x50,
        /* shufps xmm0,xmm0,0x0           */ 0x0f, 0xc6, 0xc0, 0x00,
        /* pop    rcx                     */ 0x59,
        /* ret                            */ 0xc3,
    ]),
    Code!(float*, 16 / float.sizeof)([
        /* push   rax                     */ 0x50,
        /* movss  xmm0,DWORD PTR [rdi]    */ 0xf3, 0x0f, 0x10, 0x07,
        /* shufps xmm0,xmm0,0x0           */ 0x0f, 0xc6, 0xc0, 0x00,
        /* pop    rcx                     */ 0x59,
        /* ret                            */ 0xc3,
    ]),
    Code!(double, 16 / double.sizeof)([
        /* push   rax                     */ 0x50,
        /* unpcklpd xmm0,xmm0             */ 0x66, 0x0f, 0x14, 0xc0,
        /* pop    rcx                     */ 0x59,
        /* ret                            */ 0xc3,
    ]),
    Code!(double*, 16 / double.sizeof)([
        /* push   rax                     */ 0x50,
        /* movsd  xmm0,QWORD PTR [rdi]    */ 0xf2, 0x0f, 0x10, 0x07,
        /* unpcklpd xmm0,xmm0             */ 0x66, 0x0f, 0x14, 0xc0,
        /* pop    rcx                     */ 0x59,
        /* ret                            */ 0xc3,
    ]),
);

alias avxCases = AliasSeq!(
    Code!(ubyte, 16 / ubyte.sizeof)([
        /* push   rax                     */ 0x50,
        /* vmovd  xmm0,edi                */ 0xc5, 0xf9, 0x6e, 0xc7,
        /* punpcklbw xmm0,xmm0            */ 0x66, 0x0f, 0x60, 0xc0,
        /* punpcklwd xmm0,xmm0            */ 0x66, 0x0f, 0x61, 0xc0,
        /* vpshufd xmm0,xmm0,0x0          */ 0xc5, 0xf9, 0x70, 0xc0, 0x00,
        /* pop    rcx                     */ 0x59,
        /* ret                            */ 0xc3,
    ]),
    Code!(ubyte*, 16 / ubyte.sizeof)([
        /* push   rax                     */ 0x50,
        /* movzx  eax,BYTE PTR [rdi]      */ 0x0f, 0xb6, 0x07,
        /* vmovd  xmm0,eax                */ 0xc5, 0xf9, 0x6e, 0xc0,
        /* punpcklbw xmm0,xmm0            */ 0x66, 0x0f, 0x60, 0xc0,
        /* punpcklwd xmm0,xmm0            */ 0x66, 0x0f, 0x61, 0xc0,
        /* vpshufd xmm0,xmm0,0x0          */ 0xc5, 0xf9, 0x70, 0xc0, 0x00,
        /* pop    rcx                     */ 0x59,
        /* ret                            */ 0xc3,
    ]),
    Code!(ubyte, 32 / ubyte.sizeof)([
        /* push   rax                     */ 0x50,
        /* vmovd  xmm0,edi                */ 0xc5, 0xf9, 0x6e, 0xc7,
        /* punpcklbw xmm0,xmm0            */ 0x66, 0x0f, 0x60, 0xc0,
        /* punpcklwd xmm0,xmm0            */ 0x66, 0x0f, 0x61, 0xc0,
        /* vpshufd xmm0,xmm0,0x0          */ 0xc5, 0xf9, 0x70, 0xc0, 0x00,
        /* vinsertf128 ymm0,ymm0,xmm0,0x1 */ 0xc4, 0xe3, 0x7d, 0x18, 0xc0, 0x01,
        /* pop    rcx                     */ 0x59,
        /* ret                            */ 0xc3,
    ]),
    Code!(ubyte*, 32 / ubyte.sizeof)([
        /* push   rax                     */ 0x50,
        /* movzx  eax,BYTE PTR [rdi]      */ 0x0f, 0xb6, 0x07,
        /* vmovd  xmm0,eax                */ 0xc5, 0xf9, 0x6e, 0xc0,
        /* punpcklbw xmm0,xmm0            */ 0x66, 0x0f, 0x60, 0xc0,
        /* punpcklwd xmm0,xmm0            */ 0x66, 0x0f, 0x61, 0xc0,
        /* vpshufd xmm0,xmm0,0x0          */ 0xc5, 0xf9, 0x70, 0xc0, 0x00,
        /* vinsertf128 ymm0,ymm0,xmm0,0x1 */ 0xc4, 0xe3, 0x7d, 0x18, 0xc0, 0x01,
        /* pop    rcx                     */ 0x59,
        /* ret                            */ 0xc3,
        /* add    BYTE PTR [rax],al       */ 0x00, 0x00,
    ]),
    Code!(byte, 16 / byte.sizeof)([
        /* push   rax                     */ 0x50,
        /* vmovd  xmm0,edi                */ 0xc5, 0xf9, 0x6e, 0xc7,
        /* punpcklbw xmm0,xmm0            */ 0x66, 0x0f, 0x60, 0xc0,
        /* punpcklwd xmm0,xmm0            */ 0x66, 0x0f, 0x61, 0xc0,
        /* vpshufd xmm0,xmm0,0x0          */ 0xc5, 0xf9, 0x70, 0xc0, 0x00,
        /* pop    rcx                     */ 0x59,
        /* ret                            */ 0xc3,
    ]),
    Code!(byte*, 16 / byte.sizeof)([
        /* push   rax                     */ 0x50,
        /* movsx  eax,BYTE PTR [rdi]      */ 0x0f, 0xbe, 0x07,
        /* vmovd  xmm0,eax                */ 0xc5, 0xf9, 0x6e, 0xc0,
        /* punpcklbw xmm0,xmm0            */ 0x66, 0x0f, 0x60, 0xc0,
        /* punpcklwd xmm0,xmm0            */ 0x66, 0x0f, 0x61, 0xc0,
        /* vpshufd xmm0,xmm0,0x0          */ 0xc5, 0xf9, 0x70, 0xc0, 0x00,
        /* pop    rcx                     */ 0x59,
        /* ret                            */ 0xc3,
    ]),
    Code!(byte, 32 / byte.sizeof)([
        /* push   rax                     */ 0x50,
        /* vmovd  xmm0,edi                */ 0xc5, 0xf9, 0x6e, 0xc7,
        /* punpcklbw xmm0,xmm0            */ 0x66, 0x0f, 0x60, 0xc0,
        /* punpcklwd xmm0,xmm0            */ 0x66, 0x0f, 0x61, 0xc0,
        /* vpshufd xmm0,xmm0,0x0          */ 0xc5, 0xf9, 0x70, 0xc0, 0x00,
        /* vinsertf128 ymm0,ymm0,xmm0,0x1 */ 0xc4, 0xe3, 0x7d, 0x18, 0xc0, 0x01,
        /* pop    rcx                     */ 0x59,
        /* ret                            */ 0xc3,
    ]),
    Code!(byte*, 32 / byte.sizeof)([
        /* push   rax                     */ 0x50,
        /* movsx  eax,BYTE PTR [rdi]      */ 0x0f, 0xbe, 0x07,
        /* vmovd  xmm0,eax                */ 0xc5, 0xf9, 0x6e, 0xc0,
        /* punpcklbw xmm0,xmm0            */ 0x66, 0x0f, 0x60, 0xc0,
        /* punpcklwd xmm0,xmm0            */ 0x66, 0x0f, 0x61, 0xc0,
        /* vpshufd xmm0,xmm0,0x0          */ 0xc5, 0xf9, 0x70, 0xc0, 0x00,
        /* vinsertf128 ymm0,ymm0,xmm0,0x1 */ 0xc4, 0xe3, 0x7d, 0x18, 0xc0, 0x01,
        /* pop    rcx                     */ 0x59,
        /* ret                            */ 0xc3,
        /* add    BYTE PTR [rax],al       */ 0x00, 0x00,
    ]),
    Code!(ushort, 16 / ushort.sizeof)([
        /* push   rax                     */ 0x50,
        /* vpxor  xmm0,xmm0,xmm0          */ 0xc5, 0xf9, 0xef, 0xc0,
        /* vpinsrw xmm0,xmm0,edi,0x0      */ 0xc5, 0xf9, 0xc4, 0xc7, 0x00,
        /* vpinsrw xmm0,xmm0,edi,0x1      */ 0xc5, 0xf9, 0xc4, 0xc7, 0x01,
        /* vpinsrw xmm0,xmm0,edi,0x2      */ 0xc5, 0xf9, 0xc4, 0xc7, 0x02,
        /* vpinsrw xmm0,xmm0,edi,0x3      */ 0xc5, 0xf9, 0xc4, 0xc7, 0x03,
        /* vpshufd xmm0,xmm0,0x0          */ 0xc5, 0xf9, 0x70, 0xc0, 0x00,
        /* pop    rcx                     */ 0x59,
        /* ret                            */ 0xc3,
    ]),
    Code!(ushort*, 16 / ushort.sizeof)([
        /* push   rax                     */ 0x50,
        /* movzx  eax,WORD PTR [rdi]      */ 0x0f, 0xb7, 0x07,
        /* vpxor  xmm0,xmm0,xmm0          */ 0xc5, 0xf9, 0xef, 0xc0,
        /* vpinsrw xmm0,xmm0,eax,0x0      */ 0xc5, 0xf9, 0xc4, 0xc0, 0x00,
        /* vpinsrw xmm0,xmm0,eax,0x1      */ 0xc5, 0xf9, 0xc4, 0xc0, 0x01,
        /* vpinsrw xmm0,xmm0,eax,0x2      */ 0xc5, 0xf9, 0xc4, 0xc0, 0x02,
        /* vpinsrw xmm0,xmm0,eax,0x3      */ 0xc5, 0xf9, 0xc4, 0xc0, 0x03,
        /* vpshufd xmm0,xmm0,0x0          */ 0xc5, 0xf9, 0x70, 0xc0, 0x00,
        /* pop    rcx                     */ 0x59,
        /* ret                            */ 0xc3,
    ]),
    Code!(ushort, 32 / ushort.sizeof)([
        /* push   rax                     */ 0x50,
        /* vpxor  xmm0,xmm0,xmm0          */ 0xc5, 0xf9, 0xef, 0xc0,
        /* vpinsrw xmm0,xmm0,edi,0x0      */ 0xc5, 0xf9, 0xc4, 0xc7, 0x00,
        /* vpinsrw xmm0,xmm0,edi,0x1      */ 0xc5, 0xf9, 0xc4, 0xc7, 0x01,
        /* vpinsrw xmm0,xmm0,edi,0x2      */ 0xc5, 0xf9, 0xc4, 0xc7, 0x02,
        /* vpinsrw xmm0,xmm0,edi,0x3      */ 0xc5, 0xf9, 0xc4, 0xc7, 0x03,
        /* vpinsrw xmm0,xmm0,edi,0x4      */ 0xc5, 0xf9, 0xc4, 0xc7, 0x04,
        /* vpinsrw xmm0,xmm0,edi,0x5      */ 0xc5, 0xf9, 0xc4, 0xc7, 0x05,
        /* vpinsrw xmm0,xmm0,edi,0x6      */ 0xc5, 0xf9, 0xc4, 0xc7, 0x06,
        /* vpinsrw xmm0,xmm0,edi,0x7      */ 0xc5, 0xf9, 0xc4, 0xc7, 0x07,
        /* vinsertf128 ymm0,ymm0,xmm0,0x1 */ 0xc4, 0xe3, 0x7d, 0x18, 0xc0, 0x01,
        /* pop    rcx                     */ 0x59,
        /* ret                            */ 0xc3,
        /* add    BYTE PTR [rax],al       */ 0x00, 0x00,
    ]),
    Code!(ushort*, 32 / ushort.sizeof)([
        /* push   rax                     */ 0x50,
        /* movzx  eax,WORD PTR [rdi]      */ 0x0f, 0xb7, 0x07,
        /* vpxor  xmm0,xmm0,xmm0          */ 0xc5, 0xf9, 0xef, 0xc0,
        /* vpinsrw xmm0,xmm0,eax,0x0      */ 0xc5, 0xf9, 0xc4, 0xc0, 0x00,
        /* vpinsrw xmm0,xmm0,eax,0x1      */ 0xc5, 0xf9, 0xc4, 0xc0, 0x01,
        /* vpinsrw xmm0,xmm0,eax,0x2      */ 0xc5, 0xf9, 0xc4, 0xc0, 0x02,
        /* vpinsrw xmm0,xmm0,eax,0x3      */ 0xc5, 0xf9, 0xc4, 0xc0, 0x03,
        /* vpinsrw xmm0,xmm0,eax,0x4      */ 0xc5, 0xf9, 0xc4, 0xc0, 0x04,
        /* vpinsrw xmm0,xmm0,eax,0x5      */ 0xc5, 0xf9, 0xc4, 0xc0, 0x05,
        /* vpinsrw xmm0,xmm0,eax,0x6      */ 0xc5, 0xf9, 0xc4, 0xc0, 0x06,
        /* vpinsrw xmm0,xmm0,eax,0x7      */ 0xc5, 0xf9, 0xc4, 0xc0, 0x07,
        /* vinsertf128 ymm0,ymm0,xmm0,0x1 */ 0xc4, 0xe3, 0x7d, 0x18, 0xc0, 0x01,
        /* pop    rcx                     */ 0x59,
        /* ret                            */ 0xc3,
    ]),
    Code!(short, 16 / short.sizeof)([
        /* push   rax                     */ 0x50,
        /* vpxor  xmm0,xmm0,xmm0          */ 0xc5, 0xf9, 0xef, 0xc0,
        /* vpinsrw xmm0,xmm0,edi,0x0      */ 0xc5, 0xf9, 0xc4, 0xc7, 0x00,
        /* vpinsrw xmm0,xmm0,edi,0x1      */ 0xc5, 0xf9, 0xc4, 0xc7, 0x01,
        /* vpinsrw xmm0,xmm0,edi,0x2      */ 0xc5, 0xf9, 0xc4, 0xc7, 0x02,
        /* vpinsrw xmm0,xmm0,edi,0x3      */ 0xc5, 0xf9, 0xc4, 0xc7, 0x03,
        /* vpshufd xmm0,xmm0,0x0          */ 0xc5, 0xf9, 0x70, 0xc0, 0x00,
        /* pop    rcx                     */ 0x59,
        /* ret                            */ 0xc3,
    ]),
    Code!(short*, 16 / short.sizeof)([
        /* push   rax                     */ 0x50,
        /* movsx  eax,WORD PTR [rdi]      */ 0x0f, 0xbf, 0x07,
        /* vpxor  xmm0,xmm0,xmm0          */ 0xc5, 0xf9, 0xef, 0xc0,
        /* vpinsrw xmm0,xmm0,eax,0x0      */ 0xc5, 0xf9, 0xc4, 0xc0, 0x00,
        /* vpinsrw xmm0,xmm0,eax,0x1      */ 0xc5, 0xf9, 0xc4, 0xc0, 0x01,
        /* vpinsrw xmm0,xmm0,eax,0x2      */ 0xc5, 0xf9, 0xc4, 0xc0, 0x02,
        /* vpinsrw xmm0,xmm0,eax,0x3      */ 0xc5, 0xf9, 0xc4, 0xc0, 0x03,
        /* vpshufd xmm0,xmm0,0x0          */ 0xc5, 0xf9, 0x70, 0xc0, 0x00,
        /* pop    rcx                     */ 0x59,
        /* ret                            */ 0xc3,
    ]),
    Code!(short, 32 / short.sizeof)([
        /* push   rax                     */ 0x50,
        /* vpxor  xmm0,xmm0,xmm0          */ 0xc5, 0xf9, 0xef, 0xc0,
        /* vpinsrw xmm0,xmm0,edi,0x0      */ 0xc5, 0xf9, 0xc4, 0xc7, 0x00,
        /* vpinsrw xmm0,xmm0,edi,0x1      */ 0xc5, 0xf9, 0xc4, 0xc7, 0x01,
        /* vpinsrw xmm0,xmm0,edi,0x2      */ 0xc5, 0xf9, 0xc4, 0xc7, 0x02,
        /* vpinsrw xmm0,xmm0,edi,0x3      */ 0xc5, 0xf9, 0xc4, 0xc7, 0x03,
        /* vpinsrw xmm0,xmm0,edi,0x4      */ 0xc5, 0xf9, 0xc4, 0xc7, 0x04,
        /* vpinsrw xmm0,xmm0,edi,0x5      */ 0xc5, 0xf9, 0xc4, 0xc7, 0x05,
        /* vpinsrw xmm0,xmm0,edi,0x6      */ 0xc5, 0xf9, 0xc4, 0xc7, 0x06,
        /* vpinsrw xmm0,xmm0,edi,0x7      */ 0xc5, 0xf9, 0xc4, 0xc7, 0x07,
        /* vinsertf128 ymm0,ymm0,xmm0,0x1 */ 0xc4, 0xe3, 0x7d, 0x18, 0xc0, 0x01,
        /* pop    rcx                     */ 0x59,
        /* ret                            */ 0xc3,
        /* add    BYTE PTR [rax],al       */ 0x00, 0x00,
    ]),
    Code!(short*, 32 / short.sizeof)([
        /* push   rax                     */ 0x50,
        /* movsx  eax,WORD PTR [rdi]      */ 0x0f, 0xbf, 0x07,
        /* vpxor  xmm0,xmm0,xmm0          */ 0xc5, 0xf9, 0xef, 0xc0,
        /* vpinsrw xmm0,xmm0,eax,0x0      */ 0xc5, 0xf9, 0xc4, 0xc0, 0x00,
        /* vpinsrw xmm0,xmm0,eax,0x1      */ 0xc5, 0xf9, 0xc4, 0xc0, 0x01,
        /* vpinsrw xmm0,xmm0,eax,0x2      */ 0xc5, 0xf9, 0xc4, 0xc0, 0x02,
        /* vpinsrw xmm0,xmm0,eax,0x3      */ 0xc5, 0xf9, 0xc4, 0xc0, 0x03,
        /* vpinsrw xmm0,xmm0,eax,0x4      */ 0xc5, 0xf9, 0xc4, 0xc0, 0x04,
        /* vpinsrw xmm0,xmm0,eax,0x5      */ 0xc5, 0xf9, 0xc4, 0xc0, 0x05,
        /* vpinsrw xmm0,xmm0,eax,0x6      */ 0xc5, 0xf9, 0xc4, 0xc0, 0x06,
        /* vpinsrw xmm0,xmm0,eax,0x7      */ 0xc5, 0xf9, 0xc4, 0xc0, 0x07,
        /* vinsertf128 ymm0,ymm0,xmm0,0x1 */ 0xc4, 0xe3, 0x7d, 0x18, 0xc0, 0x01,
        /* pop    rcx                     */ 0x59,
        /* ret                            */ 0xc3,
    ]),
    Code!(uint, 16 / uint.sizeof)([
        /* push   rax                     */ 0x50,
        /* movd   xmm0,edi                */ 0x66, 0x0f, 0x6e, 0xc7,
        /* pshufd xmm0,xmm0,0x0           */ 0x66, 0x0f, 0x70, 0xc0, 0x00,
        /* pop    rcx                     */ 0x59,
        /* ret                            */ 0xc3,
    ]),
    Code!(uint*, 16 / uint.sizeof)([
        /* push   rax                     */ 0x50,
        /* vbroadcastss xmm0,DWORD PTR [rdi] */ 0xc4, 0xe2, 0x79, 0x18, 0x07,
        /* pop    rcx                     */ 0x59,
        /* ret                            */ 0xc3,
    ]),
    Code!(uint, 32 / uint.sizeof)([
        /* push   rax                     */ 0x50,
        /* movd   xmm0,edi                */ 0x66, 0x0f, 0x6e, 0xc7,
        /* vbroadcastss ymm0,xmm0         */ 0xc4, 0xe2, 0x7d, 0x18, 0xc0,
        /* pop    rcx                     */ 0x59,
        /* ret                            */ 0xc3,
    ]),
    Code!(uint*, 32 / uint.sizeof)([
        /* push   rax                     */ 0x50,
        /* vbroadcastss ymm0,DWORD PTR [rdi] */ 0xc4, 0xe2, 0x7d, 0x18, 0x07,
        /* pop    rcx                     */ 0x59,
        /* ret                            */ 0xc3,
    ]),
    Code!(int, 16 / int.sizeof)([
        /* push   rax                     */ 0x50,
        /* movd   xmm0,edi                */ 0x66, 0x0f, 0x6e, 0xc7,
        /* pshufd xmm0,xmm0,0x0           */ 0x66, 0x0f, 0x70, 0xc0, 0x00,
        /* pop    rcx                     */ 0x59,
        /* ret                            */ 0xc3,
    ]),
    Code!(int*, 16 / int.sizeof)([
        /* push   rax                     */ 0x50,
        /* vbroadcastss xmm0,DWORD PTR [rdi] */ 0xc4, 0xe2, 0x79, 0x18, 0x07,
        /* pop    rcx                     */ 0x59,
        /* ret                            */ 0xc3,
    ]),
    Code!(int, 32 / int.sizeof)([
        /* push   rax                     */ 0x50,
        /* movd   xmm0,edi                */ 0x66, 0x0f, 0x6e, 0xc7,
        /* vbroadcastss ymm0,xmm0         */ 0xc4, 0xe2, 0x7d, 0x18, 0xc0,
        /* pop    rcx                     */ 0x59,
        /* ret                            */ 0xc3,
    ]),
    Code!(int*, 32 / int.sizeof)([
        /* push   rax                     */ 0x50,
        /* vbroadcastss ymm0,DWORD PTR [rdi] */ 0xc4, 0xe2, 0x7d, 0x18, 0x07,
        /* pop    rcx                     */ 0x59,
        /* ret                            */ 0xc3,
    ]),
    Code!(ulong, 16 / ulong.sizeof)([
        /* push   rax                     */ 0x50,
        /* vmovq  xmm0,rdi                */ 0xc4, 0xe1, 0xf9, 0x6e, 0xc7,
        /* vpunpcklqdq xmm0,xmm0,xmm0     */ 0xc5, 0xf9, 0x6c, 0xc0,
        /* pop    rcx                     */ 0x59,
        /* ret                            */ 0xc3,
    ]),
    Code!(ulong*, 16 / ulong.sizeof)([
        /* push   rax                     */ 0x50,
        /* vpunpcklqdq xmm0,xmm0,XMMWORD PTR [rdi] */ 0xc5, 0xf9, 0x6c, 0x07,
        /* pop    rcx                     */ 0x59,
        /* ret                            */ 0xc3,
    ]),
    Code!(ulong, 32 / ulong.sizeof)([
        /* push   rax                     */ 0x50,
        /* vmovq  xmm0,rdi                */ 0xc4, 0xe1, 0xf9, 0x6e, 0xc7,
        /* vpunpcklqdq xmm0,xmm0,xmm0     */ 0xc5, 0xf9, 0x6c, 0xc0,
        /* vinsertf128 ymm0,ymm0,xmm0,0x1 */ 0xc4, 0xe3, 0x7d, 0x18, 0xc0, 0x01,
        /* pop    rcx                     */ 0x59,
        /* ret                            */ 0xc3,
    ]),
    Code!(ulong*, 32 / ulong.sizeof)([
        /* push   rax                     */ 0x50,
        /* vbroadcastsd ymm0,QWORD PTR [rdi] */ 0xc4, 0xe2, 0x7d, 0x19, 0x07,
        /* pop    rcx                     */ 0x59,
        /* ret                            */ 0xc3,
    ]),
    Code!(long, 16 / long.sizeof)([
        /* push   rax                     */ 0x50,
        /* vmovq  xmm0,rdi                */ 0xc4, 0xe1, 0xf9, 0x6e, 0xc7,
        /* vpunpcklqdq xmm0,xmm0,xmm0     */ 0xc5, 0xf9, 0x6c, 0xc0,
        /* pop    rcx                     */ 0x59,
        /* ret                            */ 0xc3,
    ]),
    Code!(long*, 16 / long.sizeof)([
        /* push   rax                     */ 0x50,
        /* vpunpcklqdq xmm0,xmm0,XMMWORD PTR [rdi] */ 0xc5, 0xf9, 0x6c, 0x07,
        /* pop    rcx                     */ 0x59,
        /* ret                            */ 0xc3,
    ]),
    Code!(long, 32 / long.sizeof)([
        /* push   rax                     */ 0x50,
        /* vmovq  xmm0,rdi                */ 0xc4, 0xe1, 0xf9, 0x6e, 0xc7,
        /* vpunpcklqdq xmm0,xmm0,xmm0     */ 0xc5, 0xf9, 0x6c, 0xc0,
        /* vinsertf128 ymm0,ymm0,xmm0,0x1 */ 0xc4, 0xe3, 0x7d, 0x18, 0xc0, 0x01,
        /* pop    rcx                     */ 0x59,
        /* ret                            */ 0xc3,
    ]),
    Code!(long*, 32 / long.sizeof)([
        /* push   rax                     */ 0x50,
        /* vbroadcastsd ymm0,QWORD PTR [rdi] */ 0xc4, 0xe2, 0x7d, 0x19, 0x07,
        /* pop    rcx                     */ 0x59,
        /* ret                            */ 0xc3,
    ]),
    Code!(float, 16 / float.sizeof)([
        /* push   rax                     */ 0x50,
        /* vshufps xmm0,xmm0,xmm0,0x0     */ 0xc5, 0xf8, 0xc6, 0xc0, 0x00,
        /* pop    rcx                     */ 0x59,
        /* ret                            */ 0xc3,
    ]),
    Code!(float*, 16 / float.sizeof)([
        /* push   rax                     */ 0x50,
        /* vbroadcastss xmm0,DWORD PTR [rdi] */ 0xc4, 0xe2, 0x79, 0x18, 0x07,
        /* pop    rcx                     */ 0x59,
        /* ret                            */ 0xc3,
    ]),
    Code!(float, 32 / float.sizeof)([
        /* push   rax                     */ 0x50,
        /* vshufps ymm0,ymm0,ymm0,0x0     */ 0xc5, 0xfc, 0xc6, 0xc0, 0x00,
        /* vinsertf128 ymm0,ymm0,xmm0,0x1 */ 0xc4, 0xe3, 0x7d, 0x18, 0xc0, 0x01,
        /* pop    rcx                     */ 0x59,
        /* ret                            */ 0xc3,
    ]),
    Code!(float*, 32 / float.sizeof)([
        /* push   rax                     */ 0x50,
        /* vbroadcastss ymm0,DWORD PTR [rdi] */ 0xc4, 0xe2, 0x7d, 0x18, 0x07,
        /* pop    rcx                     */ 0x59,
        /* ret                            */ 0xc3,
    ]),
    Code!(double, 16 / double.sizeof)([
        /* push   rax                     */ 0x50,
        /* vunpcklpd xmm0,xmm0,xmm0       */ 0xc5, 0xf9, 0x14, 0xc0,
        /* pop    rcx                     */ 0x59,
        /* ret                            */ 0xc3,
    ]),
    Code!(double*, 16 / double.sizeof)([
        /* push   rax                     */ 0x50,
        /* vmovsd xmm0,QWORD PTR [rdi]    */ 0xc5, 0xfb, 0x10, 0x07,
        /* vunpcklpd xmm0,xmm0,xmm0       */ 0xc5, 0xf9, 0x14, 0xc0,
        /* pop    rcx                     */ 0x59,
        /* ret                            */ 0xc3,
    ]),
    Code!(double, 32 / double.sizeof)([
        /* push   rax                     */ 0x50,
        /* vunpcklpd xmm0,xmm0,xmm0       */ 0xc5, 0xf9, 0x14, 0xc0,
        /* vinsertf128 ymm0,ymm0,xmm0,0x1 */ 0xc4, 0xe3, 0x7d, 0x18, 0xc0, 0x01,
        /* pop    rcx                     */ 0x59,
        /* ret                            */ 0xc3,
        /* add    BYTE PTR [rax],al       */ 0x00, 0x00,
    ]),
    Code!(double*, 32 / double.sizeof)([
        /* push   rax                     */ 0x50,
        /* vbroadcastsd ymm0,QWORD PTR [rdi] */ 0xc4, 0xe2, 0x7d, 0x19, 0x07,
        /* pop    rcx                     */ 0x59,
        /* ret                            */ 0xc3,
    ]),
);

alias avx2Cases = AliasSeq!(
    Code!(ubyte, 16 / ubyte.sizeof)([
        /* push   rax                     */ 0x50,
        /* vmovd  xmm0,edi                */ 0xc5, 0xf9, 0x6e, 0xc7,
        /* punpcklbw xmm0,xmm0            */ 0x66, 0x0f, 0x60, 0xc0,
        /* punpcklwd xmm0,xmm0            */ 0x66, 0x0f, 0x61, 0xc0,
        /* vpshufd xmm0,xmm0,0x0          */ 0xc5, 0xf9, 0x70, 0xc0, 0x00,
        /* pop    rcx                     */ 0x59,
        /* ret                            */ 0xc3,
    ]),
    Code!(ubyte*, 16 / ubyte.sizeof)([
        /* push   rax                     */ 0x50,
        /* movzx  eax,BYTE PTR [rdi]      */ 0x0f, 0xb6, 0x07,
        /* vmovd  xmm0,eax                */ 0xc5, 0xf9, 0x6e, 0xc0,
        /* punpcklbw xmm0,xmm0            */ 0x66, 0x0f, 0x60, 0xc0,
        /* punpcklwd xmm0,xmm0            */ 0x66, 0x0f, 0x61, 0xc0,
        /* vpshufd xmm0,xmm0,0x0          */ 0xc5, 0xf9, 0x70, 0xc0, 0x00,
        /* pop    rcx                     */ 0x59,
        /* ret                            */ 0xc3,
    ]),
    Code!(ubyte, 32 / ubyte.sizeof)([
        /* push   rax                     */ 0x50,
        /* vmovd  xmm0,edi                */ 0xc5, 0xf9, 0x6e, 0xc7,
        /* punpcklbw xmm0,xmm0            */ 0x66, 0x0f, 0x60, 0xc0,
        /* punpcklwd xmm0,xmm0            */ 0x66, 0x0f, 0x61, 0xc0,
        /* vpshufd xmm0,xmm0,0x0          */ 0xc5, 0xf9, 0x70, 0xc0, 0x00,
        /* vinsertf128 ymm0,ymm0,xmm0,0x1 */ 0xc4, 0xe3, 0x7d, 0x18, 0xc0, 0x01,
        /* pop    rcx                     */ 0x59,
        /* ret                            */ 0xc3,
    ]),
    Code!(ubyte*, 32 / ubyte.sizeof)([
        /* push   rax                     */ 0x50,
        /* movzx  eax,BYTE PTR [rdi]      */ 0x0f, 0xb6, 0x07,
        /* vmovd  xmm0,eax                */ 0xc5, 0xf9, 0x6e, 0xc0,
        /* punpcklbw xmm0,xmm0            */ 0x66, 0x0f, 0x60, 0xc0,
        /* punpcklwd xmm0,xmm0            */ 0x66, 0x0f, 0x61, 0xc0,
        /* vpshufd xmm0,xmm0,0x0          */ 0xc5, 0xf9, 0x70, 0xc0, 0x00,
        /* vinsertf128 ymm0,ymm0,xmm0,0x1 */ 0xc4, 0xe3, 0x7d, 0x18, 0xc0, 0x01,
        /* pop    rcx                     */ 0x59,
        /* ret                            */ 0xc3,
        /* add    BYTE PTR [rax],al       */ 0x00, 0x00,
    ]),
    Code!(byte, 16 / byte.sizeof)([
        /* push   rax                     */ 0x50,
        /* vmovd  xmm0,edi                */ 0xc5, 0xf9, 0x6e, 0xc7,
        /* punpcklbw xmm0,xmm0            */ 0x66, 0x0f, 0x60, 0xc0,
        /* punpcklwd xmm0,xmm0            */ 0x66, 0x0f, 0x61, 0xc0,
        /* vpshufd xmm0,xmm0,0x0          */ 0xc5, 0xf9, 0x70, 0xc0, 0x00,
        /* pop    rcx                     */ 0x59,
        /* ret                            */ 0xc3,
    ]),
    Code!(byte*, 16 / byte.sizeof)([
        /* push   rax                     */ 0x50,
        /* movsx  eax,BYTE PTR [rdi]      */ 0x0f, 0xbe, 0x07,
        /* vmovd  xmm0,eax                */ 0xc5, 0xf9, 0x6e, 0xc0,
        /* punpcklbw xmm0,xmm0            */ 0x66, 0x0f, 0x60, 0xc0,
        /* punpcklwd xmm0,xmm0            */ 0x66, 0x0f, 0x61, 0xc0,
        /* vpshufd xmm0,xmm0,0x0          */ 0xc5, 0xf9, 0x70, 0xc0, 0x00,
        /* pop    rcx                     */ 0x59,
        /* ret                            */ 0xc3,
    ]),
    Code!(byte, 32 / byte.sizeof)([
        /* push   rax                     */ 0x50,
        /* vmovd  xmm0,edi                */ 0xc5, 0xf9, 0x6e, 0xc7,
        /* punpcklbw xmm0,xmm0            */ 0x66, 0x0f, 0x60, 0xc0,
        /* punpcklwd xmm0,xmm0            */ 0x66, 0x0f, 0x61, 0xc0,
        /* vpshufd xmm0,xmm0,0x0          */ 0xc5, 0xf9, 0x70, 0xc0, 0x00,
        /* vinsertf128 ymm0,ymm0,xmm0,0x1 */ 0xc4, 0xe3, 0x7d, 0x18, 0xc0, 0x01,
        /* pop    rcx                     */ 0x59,
        /* ret                            */ 0xc3,
    ]),
    Code!(byte*, 32 / byte.sizeof)([
        /* push   rax                     */ 0x50,
        /* movsx  eax,BYTE PTR [rdi]      */ 0x0f, 0xbe, 0x07,
        /* vmovd  xmm0,eax                */ 0xc5, 0xf9, 0x6e, 0xc0,
        /* punpcklbw xmm0,xmm0            */ 0x66, 0x0f, 0x60, 0xc0,
        /* punpcklwd xmm0,xmm0            */ 0x66, 0x0f, 0x61, 0xc0,
        /* vpshufd xmm0,xmm0,0x0          */ 0xc5, 0xf9, 0x70, 0xc0, 0x00,
        /* vinsertf128 ymm0,ymm0,xmm0,0x1 */ 0xc4, 0xe3, 0x7d, 0x18, 0xc0, 0x01,
        /* pop    rcx                     */ 0x59,
        /* ret                            */ 0xc3,
        /* add    BYTE PTR [rax],al       */ 0x00, 0x00,
    ]),
    Code!(ushort, 16 / ushort.sizeof)([
        /* push   rax                     */ 0x50,
        /* vpxor  xmm0,xmm0,xmm0          */ 0xc5, 0xf9, 0xef, 0xc0,
        /* vpinsrw xmm0,xmm0,edi,0x0      */ 0xc5, 0xf9, 0xc4, 0xc7, 0x00,
        /* vpinsrw xmm0,xmm0,edi,0x1      */ 0xc5, 0xf9, 0xc4, 0xc7, 0x01,
        /* vpinsrw xmm0,xmm0,edi,0x2      */ 0xc5, 0xf9, 0xc4, 0xc7, 0x02,
        /* vpinsrw xmm0,xmm0,edi,0x3      */ 0xc5, 0xf9, 0xc4, 0xc7, 0x03,
        /* vpshufd xmm0,xmm0,0x0          */ 0xc5, 0xf9, 0x70, 0xc0, 0x00,
        /* pop    rcx                     */ 0x59,
        /* ret                            */ 0xc3,
    ]),
    Code!(ushort*, 16 / ushort.sizeof)([
        /* push   rax                     */ 0x50,
        /* movzx  eax,WORD PTR [rdi]      */ 0x0f, 0xb7, 0x07,
        /* vpxor  xmm0,xmm0,xmm0          */ 0xc5, 0xf9, 0xef, 0xc0,
        /* vpinsrw xmm0,xmm0,eax,0x0      */ 0xc5, 0xf9, 0xc4, 0xc0, 0x00,
        /* vpinsrw xmm0,xmm0,eax,0x1      */ 0xc5, 0xf9, 0xc4, 0xc0, 0x01,
        /* vpinsrw xmm0,xmm0,eax,0x2      */ 0xc5, 0xf9, 0xc4, 0xc0, 0x02,
        /* vpinsrw xmm0,xmm0,eax,0x3      */ 0xc5, 0xf9, 0xc4, 0xc0, 0x03,
        /* vpshufd xmm0,xmm0,0x0          */ 0xc5, 0xf9, 0x70, 0xc0, 0x00,
        /* pop    rcx                     */ 0x59,
        /* ret                            */ 0xc3,
    ]),
    Code!(ushort, 32 / ushort.sizeof)([
        /* push   rax                     */ 0x50,
        /* vpxor  xmm0,xmm0,xmm0          */ 0xc5, 0xf9, 0xef, 0xc0,
        /* vpinsrw xmm0,xmm0,edi,0x0      */ 0xc5, 0xf9, 0xc4, 0xc7, 0x00,
        /* vpinsrw xmm0,xmm0,edi,0x1      */ 0xc5, 0xf9, 0xc4, 0xc7, 0x01,
        /* vpinsrw xmm0,xmm0,edi,0x2      */ 0xc5, 0xf9, 0xc4, 0xc7, 0x02,
        /* vpinsrw xmm0,xmm0,edi,0x3      */ 0xc5, 0xf9, 0xc4, 0xc7, 0x03,
        /* vpinsrw xmm0,xmm0,edi,0x4      */ 0xc5, 0xf9, 0xc4, 0xc7, 0x04,
        /* vpinsrw xmm0,xmm0,edi,0x5      */ 0xc5, 0xf9, 0xc4, 0xc7, 0x05,
        /* vpinsrw xmm0,xmm0,edi,0x6      */ 0xc5, 0xf9, 0xc4, 0xc7, 0x06,
        /* vpinsrw xmm0,xmm0,edi,0x7      */ 0xc5, 0xf9, 0xc4, 0xc7, 0x07,
        /* vinsertf128 ymm0,ymm0,xmm0,0x1 */ 0xc4, 0xe3, 0x7d, 0x18, 0xc0, 0x01,
        /* pop    rcx                     */ 0x59,
        /* ret                            */ 0xc3,
        /* add    BYTE PTR [rax],al       */ 0x00, 0x00,
    ]),
    Code!(ushort*, 32 / ushort.sizeof)([
        /* push   rax                     */ 0x50,
        /* movzx  eax,WORD PTR [rdi]      */ 0x0f, 0xb7, 0x07,
        /* vpxor  xmm0,xmm0,xmm0          */ 0xc5, 0xf9, 0xef, 0xc0,
        /* vpinsrw xmm0,xmm0,eax,0x0      */ 0xc5, 0xf9, 0xc4, 0xc0, 0x00,
        /* vpinsrw xmm0,xmm0,eax,0x1      */ 0xc5, 0xf9, 0xc4, 0xc0, 0x01,
        /* vpinsrw xmm0,xmm0,eax,0x2      */ 0xc5, 0xf9, 0xc4, 0xc0, 0x02,
        /* vpinsrw xmm0,xmm0,eax,0x3      */ 0xc5, 0xf9, 0xc4, 0xc0, 0x03,
        /* vpinsrw xmm0,xmm0,eax,0x4      */ 0xc5, 0xf9, 0xc4, 0xc0, 0x04,
        /* vpinsrw xmm0,xmm0,eax,0x5      */ 0xc5, 0xf9, 0xc4, 0xc0, 0x05,
        /* vpinsrw xmm0,xmm0,eax,0x6      */ 0xc5, 0xf9, 0xc4, 0xc0, 0x06,
        /* vpinsrw xmm0,xmm0,eax,0x7      */ 0xc5, 0xf9, 0xc4, 0xc0, 0x07,
        /* vinsertf128 ymm0,ymm0,xmm0,0x1 */ 0xc4, 0xe3, 0x7d, 0x18, 0xc0, 0x01,
        /* pop    rcx                     */ 0x59,
        /* ret                            */ 0xc3,
    ]),
    Code!(short, 16 / short.sizeof)([
        /* push   rax                     */ 0x50,
        /* vpxor  xmm0,xmm0,xmm0          */ 0xc5, 0xf9, 0xef, 0xc0,
        /* vpinsrw xmm0,xmm0,edi,0x0      */ 0xc5, 0xf9, 0xc4, 0xc7, 0x00,
        /* vpinsrw xmm0,xmm0,edi,0x1      */ 0xc5, 0xf9, 0xc4, 0xc7, 0x01,
        /* vpinsrw xmm0,xmm0,edi,0x2      */ 0xc5, 0xf9, 0xc4, 0xc7, 0x02,
        /* vpinsrw xmm0,xmm0,edi,0x3      */ 0xc5, 0xf9, 0xc4, 0xc7, 0x03,
        /* vpshufd xmm0,xmm0,0x0          */ 0xc5, 0xf9, 0x70, 0xc0, 0x00,
        /* pop    rcx                     */ 0x59,
        /* ret                            */ 0xc3,
    ]),
    Code!(short*, 16 / short.sizeof)([
        /* push   rax                     */ 0x50,
        /* movsx  eax,WORD PTR [rdi]      */ 0x0f, 0xbf, 0x07,
        /* vpxor  xmm0,xmm0,xmm0          */ 0xc5, 0xf9, 0xef, 0xc0,
        /* vpinsrw xmm0,xmm0,eax,0x0      */ 0xc5, 0xf9, 0xc4, 0xc0, 0x00,
        /* vpinsrw xmm0,xmm0,eax,0x1      */ 0xc5, 0xf9, 0xc4, 0xc0, 0x01,
        /* vpinsrw xmm0,xmm0,eax,0x2      */ 0xc5, 0xf9, 0xc4, 0xc0, 0x02,
        /* vpinsrw xmm0,xmm0,eax,0x3      */ 0xc5, 0xf9, 0xc4, 0xc0, 0x03,
        /* vpshufd xmm0,xmm0,0x0          */ 0xc5, 0xf9, 0x70, 0xc0, 0x00,
        /* pop    rcx                     */ 0x59,
        /* ret                            */ 0xc3,
    ]),
    Code!(short, 32 / short.sizeof)([
        /* push   rax                     */ 0x50,
        /* vpxor  xmm0,xmm0,xmm0          */ 0xc5, 0xf9, 0xef, 0xc0,
        /* vpinsrw xmm0,xmm0,edi,0x0      */ 0xc5, 0xf9, 0xc4, 0xc7, 0x00,
        /* vpinsrw xmm0,xmm0,edi,0x1      */ 0xc5, 0xf9, 0xc4, 0xc7, 0x01,
        /* vpinsrw xmm0,xmm0,edi,0x2      */ 0xc5, 0xf9, 0xc4, 0xc7, 0x02,
        /* vpinsrw xmm0,xmm0,edi,0x3      */ 0xc5, 0xf9, 0xc4, 0xc7, 0x03,
        /* vpinsrw xmm0,xmm0,edi,0x4      */ 0xc5, 0xf9, 0xc4, 0xc7, 0x04,
        /* vpinsrw xmm0,xmm0,edi,0x5      */ 0xc5, 0xf9, 0xc4, 0xc7, 0x05,
        /* vpinsrw xmm0,xmm0,edi,0x6      */ 0xc5, 0xf9, 0xc4, 0xc7, 0x06,
        /* vpinsrw xmm0,xmm0,edi,0x7      */ 0xc5, 0xf9, 0xc4, 0xc7, 0x07,
        /* vinsertf128 ymm0,ymm0,xmm0,0x1 */ 0xc4, 0xe3, 0x7d, 0x18, 0xc0, 0x01,
        /* pop    rcx                     */ 0x59,
        /* ret                            */ 0xc3,
        /* add    BYTE PTR [rax],al       */ 0x00, 0x00,
    ]),
    Code!(short*, 32 / short.sizeof)([
        /* push   rax                     */ 0x50,
        /* movsx  eax,WORD PTR [rdi]      */ 0x0f, 0xbf, 0x07,
        /* vpxor  xmm0,xmm0,xmm0          */ 0xc5, 0xf9, 0xef, 0xc0,
        /* vpinsrw xmm0,xmm0,eax,0x0      */ 0xc5, 0xf9, 0xc4, 0xc0, 0x00,
        /* vpinsrw xmm0,xmm0,eax,0x1      */ 0xc5, 0xf9, 0xc4, 0xc0, 0x01,
        /* vpinsrw xmm0,xmm0,eax,0x2      */ 0xc5, 0xf9, 0xc4, 0xc0, 0x02,
        /* vpinsrw xmm0,xmm0,eax,0x3      */ 0xc5, 0xf9, 0xc4, 0xc0, 0x03,
        /* vpinsrw xmm0,xmm0,eax,0x4      */ 0xc5, 0xf9, 0xc4, 0xc0, 0x04,
        /* vpinsrw xmm0,xmm0,eax,0x5      */ 0xc5, 0xf9, 0xc4, 0xc0, 0x05,
        /* vpinsrw xmm0,xmm0,eax,0x6      */ 0xc5, 0xf9, 0xc4, 0xc0, 0x06,
        /* vpinsrw xmm0,xmm0,eax,0x7      */ 0xc5, 0xf9, 0xc4, 0xc0, 0x07,
        /* vinsertf128 ymm0,ymm0,xmm0,0x1 */ 0xc4, 0xe3, 0x7d, 0x18, 0xc0, 0x01,
        /* pop    rcx                     */ 0x59,
        /* ret                            */ 0xc3,
    ]),
    Code!(uint, 16 / uint.sizeof)([
        /* push   rax                     */ 0x50,
        /* movd   xmm0,edi                */ 0x66, 0x0f, 0x6e, 0xc7,
        /* vbroadcastss xmm0,xmm0         */ 0xc4, 0xe2, 0x79, 0x18, 0xc0,
        /* pop    rcx                     */ 0x59,
        /* ret                            */ 0xc3,
    ]),
    Code!(uint*, 16 / uint.sizeof)([
        /* push   rax                     */ 0x50,
        /* vbroadcastss xmm0,DWORD PTR [rdi] */ 0xc4, 0xe2, 0x79, 0x18, 0x07,
        /* pop    rcx                     */ 0x59,
        /* ret                            */ 0xc3,
    ]),
    Code!(uint, 32 / uint.sizeof)([
        /* push   rax                     */ 0x50,
        /* movd   xmm0,edi                */ 0x66, 0x0f, 0x6e, 0xc7,
        /* vbroadcastss ymm0,xmm0         */ 0xc4, 0xe2, 0x7d, 0x18, 0xc0,
        /* pop    rcx                     */ 0x59,
        /* ret                            */ 0xc3,
    ]),
    Code!(uint*, 32 / uint.sizeof)([
        /* push   rax                     */ 0x50,
        /* vbroadcastss ymm0,DWORD PTR [rdi] */ 0xc4, 0xe2, 0x7d, 0x18, 0x07,
        /* pop    rcx                     */ 0x59,
        /* ret                            */ 0xc3,
    ]),
    Code!(int, 16 / int.sizeof)([
        /* push   rax                     */ 0x50,
        /* movd   xmm0,edi                */ 0x66, 0x0f, 0x6e, 0xc7,
        /* vbroadcastss xmm0,xmm0         */ 0xc4, 0xe2, 0x79, 0x18, 0xc0,
        /* pop    rcx                     */ 0x59,
        /* ret                            */ 0xc3,
    ]),
    Code!(int*, 16 / int.sizeof)([
        /* push   rax                     */ 0x50,
        /* vbroadcastss xmm0,DWORD PTR [rdi] */ 0xc4, 0xe2, 0x79, 0x18, 0x07,
        /* pop    rcx                     */ 0x59,
        /* ret                            */ 0xc3,
    ]),
    Code!(int, 32 / int.sizeof)([
        /* push   rax                     */ 0x50,
        /* movd   xmm0,edi                */ 0x66, 0x0f, 0x6e, 0xc7,
        /* vbroadcastss ymm0,xmm0         */ 0xc4, 0xe2, 0x7d, 0x18, 0xc0,
        /* pop    rcx                     */ 0x59,
        /* ret                            */ 0xc3,
    ]),
    Code!(int*, 32 / int.sizeof)([
        /* push   rax                     */ 0x50,
        /* vbroadcastss ymm0,DWORD PTR [rdi] */ 0xc4, 0xe2, 0x7d, 0x18, 0x07,
        /* pop    rcx                     */ 0x59,
        /* ret                            */ 0xc3,
    ]),
    Code!(ulong, 16 / ulong.sizeof)([
        /* push   rax                     */ 0x50,
        /* vmovq  xmm0,rdi                */ 0xc4, 0xe1, 0xf9, 0x6e, 0xc7,
        /* vpbroadcastq xmm0,xmm0         */ 0xc4, 0xe2, 0x79, 0x59, 0xc0,
        /* pop    rcx                     */ 0x59,
        /* ret                            */ 0xc3,
        /* add    BYTE PTR [rax],al       */ 0x00, 0x00,
    ]),
    Code!(ulong*, 16 / ulong.sizeof)([
        /* push   rax                     */ 0x50,
        /* vpbroadcastq xmm0,QWORD PTR [rdi] */ 0xc4, 0xe2, 0x79, 0x59, 0x07,
        /* pop    rcx                     */ 0x59,
        /* ret                            */ 0xc3,
    ]),
    Code!(ulong, 32 / ulong.sizeof)([
        /* push   rax                     */ 0x50,
        /* vmovq  xmm0,rdi                */ 0xc4, 0xe1, 0xf9, 0x6e, 0xc7,
        /* vpbroadcastq ymm0,xmm0         */ 0xc4, 0xe2, 0x7d, 0x59, 0xc0,
        /* pop    rcx                     */ 0x59,
        /* ret                            */ 0xc3,
        /* add    BYTE PTR [rax],al       */ 0x00, 0x00,
    ]),
    Code!(ulong*, 32 / ulong.sizeof)([
        /* push   rax                     */ 0x50,
        /* vpbroadcastq ymm0,QWORD PTR [rdi] */ 0xc4, 0xe2, 0x7d, 0x59, 0x07,
        /* pop    rcx                     */ 0x59,
        /* ret                            */ 0xc3,
    ]),
    Code!(long, 16 / long.sizeof)([
        /* push   rax                     */ 0x50,
        /* vmovq  xmm0,rdi                */ 0xc4, 0xe1, 0xf9, 0x6e, 0xc7,
        /* vpbroadcastq xmm0,xmm0         */ 0xc4, 0xe2, 0x79, 0x59, 0xc0,
        /* pop    rcx                     */ 0x59,
        /* ret                            */ 0xc3,
        /* add    BYTE PTR [rax],al       */ 0x00, 0x00,
    ]),
    Code!(long*, 16 / long.sizeof)([
        /* push   rax                     */ 0x50,
        /* vpbroadcastq xmm0,QWORD PTR [rdi] */ 0xc4, 0xe2, 0x79, 0x59, 0x07,
        /* pop    rcx                     */ 0x59,
        /* ret                            */ 0xc3,
    ]),
    Code!(long, 32 / long.sizeof)([
        /* push   rax                     */ 0x50,
        /* vmovq  xmm0,rdi                */ 0xc4, 0xe1, 0xf9, 0x6e, 0xc7,
        /* vpbroadcastq ymm0,xmm0         */ 0xc4, 0xe2, 0x7d, 0x59, 0xc0,
        /* pop    rcx                     */ 0x59,
        /* ret                            */ 0xc3,
        /* add    BYTE PTR [rax],al       */ 0x00, 0x00,
    ]),
    Code!(long*, 32 / long.sizeof)([
        /* push   rax                     */ 0x50,
        /* vpbroadcastq ymm0,QWORD PTR [rdi] */ 0xc4, 0xe2, 0x7d, 0x59, 0x07,
        /* pop    rcx                     */ 0x59,
        /* ret                            */ 0xc3,
    ]),
    Code!(float, 16 / float.sizeof)([
        /* push   rax                     */ 0x50,
        /* vbroadcastss xmm0,xmm0         */ 0xc4, 0xe2, 0x79, 0x18, 0xc0,
        /* pop    rcx                     */ 0x59,
        /* ret                            */ 0xc3,
    ]),
    Code!(float*, 16 / float.sizeof)([
        /* push   rax                     */ 0x50,
        /* vbroadcastss xmm0,DWORD PTR [rdi] */ 0xc4, 0xe2, 0x79, 0x18, 0x07,
        /* pop    rcx                     */ 0x59,
        /* ret                            */ 0xc3,
    ]),
    Code!(float, 32 / float.sizeof)([
        /* push   rax                     */ 0x50,
        /* vbroadcastss ymm0,xmm0         */ 0xc4, 0xe2, 0x7d, 0x18, 0xc0,
        /* pop    rcx                     */ 0x59,
        /* ret                            */ 0xc3,
    ]),
    Code!(float*, 32 / float.sizeof)([
        /* push   rax                     */ 0x50,
        /* vbroadcastss ymm0,DWORD PTR [rdi] */ 0xc4, 0xe2, 0x7d, 0x18, 0x07,
        /* pop    rcx                     */ 0x59,
        /* ret                            */ 0xc3,
    ]),
    Code!(double, 16 / double.sizeof)([
        /* push   rax                     */ 0x50,
        /* vunpcklpd xmm0,xmm0,xmm0       */ 0xc5, 0xf9, 0x14, 0xc0,
        /* pop    rcx                     */ 0x59,
        /* ret                            */ 0xc3,
    ]),
    Code!(double*, 16 / double.sizeof)([
        /* push   rax                     */ 0x50,
        /* vmovsd xmm0,QWORD PTR [rdi]    */ 0xc5, 0xfb, 0x10, 0x07,
        /* vunpcklpd xmm0,xmm0,xmm0       */ 0xc5, 0xf9, 0x14, 0xc0,
        /* pop    rcx                     */ 0x59,
        /* ret                            */ 0xc3,
    ]),
    Code!(double, 32 / double.sizeof)([
        /* push   rax                     */ 0x50,
        /* vbroadcastsd ymm0,xmm0         */ 0xc4, 0xe2, 0x7d, 0x19, 0xc0,
        /* pop    rcx                     */ 0x59,
        /* ret                            */ 0xc3,
    ]),
    Code!(double*, 32 / double.sizeof)([
        /* push   rax                     */ 0x50,
        /* vbroadcastsd ymm0,QWORD PTR [rdi] */ 0xc4, 0xe2, 0x7d, 0x19, 0x07,
        /* pop    rcx                     */ 0x59,
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

bool canFind(const(ubyte)[] haystack, const(ubyte)[] needle)
{
    while (haystack.length >= needle.length)
    {
        if (haystack[0 .. needle.length] == needle)
            return true;
        haystack = haystack[1 .. $];
    }
    return false;
}

void main()
{
    foreach (tc; testCases)
    {
        enum maxLen = 0x40; // should be sufficient and unlikely to crash
        auto code = (cast(ubyte*)&load!(tc.T, tc.N))[0 .. maxLen];
        bool failure;
        if (!code.canFind(tc.code))
        {
            fprintf(stderr, "Expected code sequence for load!(%s, %u) not found.", tc.T.stringof.ptr, tc.N);
            fprintf(stderr, "\n  Expected:");
            foreach (d; tc.code)
                fprintf(stderr, " 0x%02x", d);
            fprintf(stderr, "\n  Actual:");
            foreach (d; code)
                fprintf(stderr, " 0x%02x", d);
            fprintf(stderr, "\n");
            failure = true;
        }
        assert(!failure);
    }
}
