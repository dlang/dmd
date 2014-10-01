/**
 * Identify the characteristics of the host CPU, providing information
 * about cache sizes and assembly optimisation hints. This module is
 * provided primarily for assembly language programmers.
 *
 * References:
 * Some of this information was extremely difficult to track down. Some of the
 * documents below were found only in cached versions stored by search engines!
 * This code relies on information found in:
 *
 * $(UL
 * $(LI "Intel(R) 64 and IA-32 Architectures Software Developers Manual,
 *    Volume 2A: Instruction Set Reference, A-M" (2007).
 * )
 * $(LI "AMD CPUID Specification", Advanced Micro Devices, Rev 2.28 (2008).
 * )
 * $(LI "AMD Processor Recognition Application Note For Processors Prior to AMD
 *    Family 0Fh Processors", Advanced Micro Devices, Rev 3.13 (2005).
 * )
 * $(LI "AMD Geode(TM) GX Processors Data Book",
 *    Advanced Micro Devices, Publication ID 31505E, (2005).
 * )
 * $(LI "AMD K6 Processor Code Optimisation", Advanced Micro Devices, Rev D (2000).
 * )
 * $(LI "Application note 106: Software Customization for the 6x86 Family",
 *    Cyrix Corporation, Rev 1.5 (1998)
 * )
 * $(LI $(LINK http://www.datasheetcatalog.org/datasheet/nationalsemiconductor/GX1.pdf))
 * $(LI "Geode(TM) GX1 Processor Series Low Power Integrated X86 Solution",
 *   National Semiconductor, (2002)
 * )
 * $(LI "The VIA Isaiah Architecture", G. Glenn Henry, Centaur Technology, Inc (2008).
 * )
 * $(LI $(LINK http://www.sandpile.org/ia32/cpuid.htm))
 * $(LI $(LINK http://www.akkadia.org/drepper/cpumemory.pdf))
 * $(LI "What every programmer should know about memory",
 *    Ulrich Depper, Red Hat, Inc., (2007).
 * )
 * $(LI "CPU Identification by the Windows Kernel", G. Chappell (2009).
 *   $(LINK http://www.geoffchappell.com/viewer.htm?doc=studies/windows/km/cpu/cx8.htm)
 * )
 * $(LI "Intel(R) Processor Identification and the CPUID Instruction, Application
 *    Note 485" (2009).
 * )
 * )
 *
 * Bugs: Currently only works on x86 and Itanium CPUs.
 *      Many processors have bugs in their microcode for the CPUID instruction,
 *      so sometimes the cache information may be incorrect.
 *
 * Copyright: Copyright Don Clugston 2007 - 2009.
 * License:   $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Authors:   Don Clugston, Tomas Lindquist Olsen &lt;tomas@famolsen.dk&gt;
 * Source:    $(DRUNTIMESRC core/_cpuid.d)
 */

/*          Copyright Don Clugston 2007 - 2009.
 * Distributed under the Boost Software License, Version 1.0.
 *    (See accompanying file LICENSE or copy at
 *          http://www.boost.org/LICENSE_1_0.txt)
 */
module core.cpuid;

@trusted:
nothrow:
@nogc:

// If optimizing for a particular processor, it is generally better
// to identify based on features rather than model. NOTE: Normally
// it's only worthwhile to optimise for the latest Intel and AMD CPU,
// with a backup for other CPUs.
// Pentium    -- preferPentium1()
// PMMX       --   + mmx()
// PPro       -- default
// PII        --   + mmx()
// PIII       --   + mmx() + sse()
// PentiumM   --   + mmx() + sse() + sse2()
// Pentium4   -- preferPentium4()
// PentiumD   --   + isX86_64()
// Core2      -- default + isX86_64()
// AMD K5     -- preferPentium1()
// AMD K6     --   + mmx()
// AMD K6-II  --   + mmx() + 3dnow()
// AMD K7     -- preferAthlon()
// AMD K8     --   + sse2()
// AMD K10    --   + isX86_64()
// Cyrix 6x86 -- preferPentium1()
//    6x86MX  --   + mmx()
version(D_InlineAsm_X86)
{
    version = InlineAsm_X86_Any;
}
else version(D_InlineAsm_X86_64)
{
    version = InlineAsm_X86_Any;
}

public:

/// Cache size and behaviour
struct CacheInfo
{
    /// Size of the cache, in kilobytes, per CPU.
    /// For L1 unified (data + code) caches, this size is half the physical size.
    /// (we don't halve it for larger sizes, since normally
    /// data size is much greater than code size for critical loops).
    size_t size;
    /// Number of ways of associativity, eg:
    /// 1 = direct mapped
    /// 2 = 2-way set associative
    /// 3 = 3-way set associative
    /// ubyte.max = fully associative
    ubyte associativity;
    /// Number of bytes read into the cache when a cache miss occurs.
    uint lineSize;
}

public:
    /// $(RED Scheduled for deprecation. Please use $(D dataCaches) instead.)
    // Note: When we deprecate it, we simply make it private.
    __gshared CacheInfo[5] datacache;

    @property {
    /// The data caches. If there are fewer than 5 physical caches levels,
    /// the remaining levels are set to size_t.max (== entire memory space)
    const(CacheInfo)[5] dataCaches() { return datacache; }

    /// Returns vendor string, for display purposes only.
    /// Do NOT use this to determine features!
    /// Note that some CPUs have programmable vendorIDs.
    string vendor()     {return cast(string)vendorID;}
    /// Returns processor string, for display purposes only
    string processor()  {return processorName;}

    /// Does it have an x87 FPU on-chip?
    bool x87onChip()    {return (features&FPU_BIT)!=0;}
    /// Is MMX supported?
    bool mmx()          {return (features&MMX_BIT)!=0;}
    /// Is SSE supported?
    bool sse()          {return (features&SSE_BIT)!=0;}
    /// Is SSE2 supported?
    bool sse2()         {return (features&SSE2_BIT)!=0;}
    /// Is SSE3 supported?
    bool sse3()         {return (miscfeatures&SSE3_BIT)!=0;}
    /// Is SSSE3 supported?
    bool ssse3()        {return (miscfeatures&SSSE3_BIT)!=0;}
    /// Is SSE4.1 supported?
    bool sse41()        {return (miscfeatures&SSE41_BIT)!=0;}
    /// Is SSE4.2 supported?
    bool sse42()        {return (miscfeatures&SSE42_BIT)!=0;}
    /// Is SSE4a supported?
    bool sse4a()        {return (amdmiscfeatures&SSE4A_BIT)!=0;}
    /// Is AES supported
    bool aes()          {return (miscfeatures&AES_BIT)!=0;}
    /// Is pclmulqdq supported
    bool hasPclmulqdq() {return (miscfeatures&PCLMULQDQ_BIT)!=0;}
    /// Is rdrand supported
    bool hasRdrand()    {return (miscfeatures&RDRAND_BIT)!=0;}
    /// Is AVX supported
    bool avx()
    {
        enum mask = XF_SSE_BIT|XF_YMM_BIT;
        return (xfeatures & mask) == mask && (miscfeatures&AVX_BIT)!=0;
    }
    /// Is VEX-Encoded AES supported
    bool vaes()         {return avx && aes;}
    /// Is vpclmulqdq supported
    bool hasVpclmulqdq(){return avx && hasPclmulqdq; }
    /// Is FMA supported
    bool fma()          {return avx && (miscfeatures&FMA_BIT)!=0;}
    /// Is FP16C supported
    bool fp16c()        {return avx && (miscfeatures&FP16C_BIT)!=0;}
    /// Is AVX2 supported
    bool avx2()         {return avx && (extfeatures & AVX2_BIT) != 0;}
    /// Is HLE (hardware lock elision) supported
    bool hle()          {return (extfeatures & HLE_BIT) != 0;}
    /// Is RTM (restricted transactional memory) supported
    bool rtm()          {return (extfeatures & RTM_BIT) != 0;}
    /// Is rdseed supported
    bool hasRdseed()    {return (extfeatures&RDSEED_BIT)!=0;}
    /// Is SHA supported
    bool hasSha()       {return (extfeatures&SHA_BIT)!=0;}
    /// Is AMD 3DNOW supported?
    bool amd3dnow()     {return (amdfeatures&AMD_3DNOW_BIT)!=0;}
    /// Is AMD 3DNOW Ext supported?
    bool amd3dnowExt()  {return (amdfeatures&AMD_3DNOW_EXT_BIT)!=0;}
    /// Are AMD extensions to MMX supported?
    bool amdMmx()       {return (amdfeatures&AMD_MMX_BIT)!=0;}
    /// Is fxsave/fxrstor supported?
    bool hasFxsr()          {return (features&FXSR_BIT)!=0;}
    /// Is cmov supported?
    bool hasCmov()          {return (features&CMOV_BIT)!=0;}
    /// Is rdtsc supported?
    bool hasRdtsc()         {return (features&TIMESTAMP_BIT)!=0;}
    /// Is cmpxchg8b supported?
    bool hasCmpxchg8b()     {return (features&CMPXCHG8B_BIT)!=0;}
    /// Is cmpxchg8b supported?
    bool hasCmpxchg16b()    {return (miscfeatures&CMPXCHG16B_BIT)!=0;}
    /// Is SYSENTER/SYSEXIT supported?
    bool hasSysEnterSysExit()     {
        // The SYSENTER/SYSEXIT features were buggy on Pentium Pro and early PentiumII.
        // (REF: www.geoffchappell.com).
        if (probablyIntel && (family < 6 || (family==6 && (model< 3 || (model==3 && stepping<3)))))
            return false;
        return (features & SYSENTERSYSEXIT_BIT)!=0;
    }


    /// Is 3DNow prefetch supported?
    bool has3dnowPrefetch()
        {return (amdmiscfeatures&AMD_3DNOW_PREFETCH_BIT)!=0;}
    /// Are LAHF and SAHF supported in 64-bit mode?
    bool hasLahfSahf()          {return (amdmiscfeatures&LAHFSAHF_BIT)!=0;}
    /// Is POPCNT supported?
    bool hasPopcnt()        {return (miscfeatures&POPCNT_BIT)!=0;}
    /// Is LZCNT supported?
    bool hasLzcnt()         {return (amdmiscfeatures&LZCNT_BIT)!=0;}
    /// Is this an Intel64 or AMD 64?
    bool isX86_64()         {return (amdfeatures&AMD64_BIT)!=0;}

    /// Is this an IA64 (Itanium) processor?
    bool isItanium()        { return (features&IA64_BIT)!=0; }

    /// Is hyperthreading supported?
    bool hyperThreading()   { return maxThreads>maxCores; }
    /// Returns number of threads per CPU
    uint threadsPerCPU()    {return maxThreads;}
    /// Returns number of cores in CPU
    uint coresPerCPU()      {return maxCores;}

    /// Optimisation hints for assembly code.
    ///
    /// For forward compatibility, the CPU is compared against different
    /// microarchitectures. For 32-bit x86, comparisons are made against
    /// the Intel PPro/PII/PIII/PM family.
    ///
    /// The major 32-bit x86 microarchitecture 'dynasties' have been:
    ///
    /// * Intel P6 (PentiumPro, PII, PIII, PM, Core, Core2).
    /// * AMD Athlon (K7, K8, K10).
    /// * Intel NetBurst (Pentium 4, Pentium D).
    /// * In-order Pentium (Pentium1, PMMX, Atom)
    ///
    /// Other early CPUs (Nx586, AMD K5, K6, Centaur C3, Transmeta,
    /// Cyrix, Rise) were mostly in-order.
    ///
    /// Some new processors do not fit into the existing categories:
    ///
    /// * Intel Atom 230/330 (family 6, model 0x1C) is an in-order core.
    /// * Centaur Isiah = VIA Nano (family 6, model F) is an out-of-order core.
    ///
    /// Within each dynasty, the optimisation techniques are largely
    /// identical (eg, use instruction pairing for group 4). Major
    /// instruction set improvements occur within each dynasty.

    /// Does this CPU perform better on AMD K7 code than PentiumPro..Core2 code?
    bool preferAthlon() { return probablyAMD && family >=6; }
    /// Does this CPU perform better on Pentium4 code than PentiumPro..Core2 code?
    bool preferPentium4() { return probablyIntel && family == 0xF; }
    /// Does this CPU perform better on Pentium I code than Pentium Pro code?
    bool preferPentium1() { return family < 6 || (family==6 && model < 0xF && !probablyIntel); }
    }

__gshared:
    // All these values are set only once, and never subsequently modified.
public:
    /// $(RED Warning: This field will be turned into a property in a future release.)
    ///
    /// Processor type (vendor-dependent).
    /// This should be visible ONLY for display purposes.
    uint stepping, model, family;
    /// $(RED This field has been deprecated. Please use $(D cacheLevels) instead.)
    uint numCacheLevels = 1;
    /// The number of cache levels in the CPU.
    @property uint cacheLevels() { return numCacheLevels; }
private:
    bool probablyIntel; // true = _probably_ an Intel processor, might be faking
    bool probablyAMD; // true = _probably_ an AMD processor
    string processorName;
    char [12] vendorID;
    char [48] processorNameBuffer;
    uint features = 0;     // mmx, sse, sse2, hyperthreading, etc
    uint miscfeatures = 0; // sse3, etc.
    uint extfeatures = 0;  // HLE, AVX2, RTM, etc.
    uint amdfeatures = 0;  // 3DNow!, mmxext, etc
    uint amdmiscfeatures = 0; // sse4a, sse5, svm, etc
    ulong xfeatures = 0;   // XFEATURES_ENABLED_MASK
    uint maxCores = 1;
    uint maxThreads = 1;
    // Note that this may indicate multi-core rather than hyperthreading.
    @property bool hyperThreadingBit()    { return (features&HTT_BIT)!=0;}

    // feature flags CPUID1_EDX
    enum : uint
    {
        FPU_BIT = 1,
        TIMESTAMP_BIT = 1<<4, // rdtsc
        MDSR_BIT = 1<<5,      // RDMSR/WRMSR
        CMPXCHG8B_BIT = 1<<8,
        SYSENTERSYSEXIT_BIT = 1<<11,
        CMOV_BIT = 1<<15,
        MMX_BIT = 1<<23,
        FXSR_BIT = 1<<24,
        SSE_BIT = 1<<25,
        SSE2_BIT = 1<<26,
        HTT_BIT = 1<<28,
        IA64_BIT = 1<<30
    }
    // feature flags misc CPUID1_ECX
    enum : uint
    {
        SSE3_BIT = 1,
        PCLMULQDQ_BIT = 1<<1, // from AVX
        MWAIT_BIT = 1<<3,
        SSSE3_BIT = 1<<9,
        FMA_BIT = 1<<12,     // from AVX
        CMPXCHG16B_BIT = 1<<13,
        SSE41_BIT = 1<<19,
        SSE42_BIT = 1<<20,
        POPCNT_BIT = 1<<23,
        AES_BIT = 1<<25, // AES instructions from AVX
        OSXSAVE_BIT = 1<<27, // Used for AVX
        AVX_BIT = 1<<28,
        FP16C_BIT = 1<<29,
        RDRAND_BIT = 1<<30,
    }
    // Feature flags for cpuid.{EAX = 7, ECX = 0}.EBX.
    enum : uint
    {
        FSGSBASE_BIT = 1 << 0,
        BMI1_BIT = 1 << 3,
        HLE_BIT = 1 << 4,
        AVX2_BIT = 1 << 5,
        SMEP_BIT = 1 << 7,
        BMI2_BIT = 1 << 8,
        ERMS_BIT = 1 << 9,
        INVPCID_BIT = 1 << 10,
        RTM_BIT = 1 << 11,
        RDSEED_BIT = 1 << 18,
        SHA_BIT = 1 << 29,
    }
    // feature flags XFEATURES_ENABLED_MASK
    enum : ulong
    {
        XF_FP_BIT  = 0x1,
        XF_SSE_BIT = 0x2,
        XF_YMM_BIT = 0x4,
    }
    // AMD feature flags CPUID80000001_EDX
    enum : uint
    {
        AMD_MMX_BIT = 1<<22,
//      FXR_OR_CYRIXMMX_BIT = 1<<24, // Cyrix/NS: 6x86MMX instructions.
        FFXSR_BIT = 1<<25,
        PAGE1GB_BIT = 1<<26, // support for 1GB pages
        RDTSCP_BIT = 1<<27,
        AMD64_BIT = 1<<29,
        AMD_3DNOW_EXT_BIT = 1<<30,
        AMD_3DNOW_BIT = 1<<31
    }
    // AMD misc feature flags CPUID80000001_ECX
    enum : uint
    {
        LAHFSAHF_BIT = 1,
        LZCNT_BIT = 1<<5,
        SSE4A_BIT = 1<<6,
        AMD_3DNOW_PREFETCH_BIT = 1<<8,
    }


version(InlineAsm_X86_Any) {
// Note that this code will also work for Itanium in x86 mode.

__gshared uint max_cpuid, max_extended_cpuid;

// CPUID2: "cache and tlb information"
void getcacheinfoCPUID2()
{
    // We are only interested in the data caches
    void decipherCpuid2(ubyte x) @nogc nothrow {
        if (x==0) return;
        // Values from http://www.sandpile.org/ia32/cpuid.htm.
        // Includes Itanium and non-Intel CPUs.
        //
        static immutable ubyte [63] ids = [
            0x0A, 0x0C, 0x0D, 0x2C, 0x60, 0x0E, 0x66, 0x67, 0x68,
            // level 2 cache
            0x41, 0x42, 0x43, 0x44, 0x45, 0x78, 0x79, 0x7A, 0x7B, 0x7C, 0x7D, 0x7F,
            0x82, 0x83, 0x84, 0x85, 0x86, 0x87, 0x49, 0x4E,
            0x39, 0x3A, 0x3B, 0x3C, 0x3D, 0x3E, 0x48, 0x80, 0x81,
            // level 3 cache
            0x22, 0x23, 0x25, 0x29, 0x46, 0x47, 0x4A, 0x4B, 0x4C, 0x4D,

            0xD0, 0xD1, 0xD2, 0xD6, 0xD7, 0xD8, 0xDC, 0xDD, 0xDE,
            0xE2, 0xE3, 0xE4, 0xEA, 0xEB, 0xEC
        ];
        static immutable uint [63] sizes = [
            8, 16, 16, 64, 16, 24, 8, 16, 32,
            128, 256, 512, 1024, 2048, 1024, 128, 256, 512, 1024, 2048, 512,
            256, 512, 1024, 2048, 512, 1024, 4096, 6*1024,
            128, 192, 128, 256, 384, 512, 3072, 512, 128,
            512, 1024, 2048, 4096, 4096, 8192, 6*1024, 8192, 12*1024, 16*1024,

            512, 1024, 2048, 1024, 2048, 4096, 1024+512, 3*1024, 6*1024,
            2*1024, 4*1024, 8*1024, 12*1024, 28*1024, 24*1024
        ];
    // CPUBUG: Pentium M reports 0x2C but tests show it is only 4-way associative
        static immutable ubyte [63] ways = [
            2, 4, 4, 8, 8, 6, 4, 4, 4,
            4, 4, 4, 4, 4, 4, 8, 8, 8, 8, 8, 2,
            8, 8, 8, 8, 4, 8, 16, 24,
            4, 6, 2, 4, 6, 4, 12, 8, 8,
            4, 8, 8, 8, 4, 8, 12, 16, 12, 16,
            4, 4, 4, 8, 8, 8, 12, 12, 12,
            16, 16, 16, 24, 24, 24
        ];
        enum { FIRSTDATA2 = 8, FIRSTDATA3 = 28+9 }
        for (size_t i=0; i< ids.length; ++i) {
            if (x==ids[i]) {
                int level = i< FIRSTDATA2 ? 0: i<FIRSTDATA3 ? 1 : 2;
                if (x==0x49 && family==0xF && model==0x6) level=2;
                datacache[level].size=sizes[i];
                datacache[level].associativity=ways[i];
                if (level == 3 || x==0x2C || x==0x0D || (x>=0x48 && x<=0x80)
                                   || x==0x86 || x==0x87
                                   || (x>=0x66 && x<=0x68) || (x>=0x39 && x<=0x3E)){
                    datacache[level].lineSize = 64;
                } else datacache[level].lineSize = 32;
            }
        }
    }

    uint[4] a;
    bool firstTime = true;
    // On a multi-core system, this could theoretically fail, but it's only used
    // for old single-core CPUs.
    uint numinfos = 1;
    do {
        asm {
            mov EAX, 2;
            cpuid;
            mov a, EAX;
            mov a+4, EBX;
            mov a+8, ECX;
            mov a+12, EDX;
        }
        if (firstTime) {
            if (a[0]==0x0000_7001 && a[3]==0x80 && a[1]==0 && a[2]==0) {
        // Cyrix MediaGX MMXEnhanced returns: EAX= 00007001, EDX=00000080.
        // These are NOT standard Intel values
        // (TLB = 32 entry, 4 way associative, 4K pages)
        // (L1 cache = 16K, 4way, linesize16)
                datacache[0].size=8;
                datacache[0].associativity=4;
                datacache[0].lineSize=16;
                return;
            }
            // lsb of a is how many times to loop.
            numinfos = a[0] & 0xFF;
            // and otherwise it should be ignored
            a[0] &= 0xFFFF_FF00;
            firstTime = false;
        }
        for (int c=0; c<4;++c) {
            // high bit set == no info.
            if (a[c] & 0x8000_0000) continue;
            decipherCpuid2(cast(ubyte)(a[c] & 0xFF));
            decipherCpuid2(cast(ubyte)((a[c]>>8) & 0xFF));
            decipherCpuid2(cast(ubyte)((a[c]>>16) & 0xFF));
            decipherCpuid2(cast(ubyte)((a[c]>>24) & 0xFF));
        }
    } while (--numinfos);
}

// CPUID4: "Deterministic cache parameters" leaf
void getcacheinfoCPUID4()
{
    int cachenum = 0;
    for(;;) {
        uint a, b, number_of_sets;
        asm {
            mov EAX, 4;
            mov ECX, cachenum;
            cpuid;
            mov a, EAX;
            mov b, EBX;
            mov number_of_sets, ECX;
        }
        ++cachenum;
        if ((a&0x1F)==0) break; // no more caches
        uint numthreads = ((a>>14) & 0xFFF)  + 1;
        uint numcores = ((a>>26) & 0x3F) + 1;
        if (numcores > maxCores) maxCores = numcores;
        if ((a&0x1F)!=1 && ((a&0x1F)!=3)) continue; // we only want data & unified caches

        ++number_of_sets;
        ubyte level = cast(ubyte)(((a>>5)&7)-1);
        if (level > datacache.length) continue; // ignore deep caches
        datacache[level].associativity = a & 0x200 ? ubyte.max :cast(ubyte)((b>>22)+1);
        datacache[level].lineSize = (b & 0xFFF)+ 1; // system coherency line size
        uint line_partitions = ((b >> 12)& 0x3FF) + 1;
        // Size = number of sets * associativity * cachelinesize * linepartitions
        // and must convert to Kb, also dividing by the number of hyperthreads using this cache.
        ulong sz = (datacache[level].associativity< ubyte.max)? number_of_sets *
            datacache[level].associativity : number_of_sets;
        datacache[level].size = cast(uint)(
                (sz * datacache[level].lineSize * line_partitions ) / (numthreads *1024));
        if (level == 0 && (a&0xF)==3) {
            // Halve the size for unified L1 caches
            datacache[level].size/=2;
        }
    }
}

// CPUID8000_0005 & 6
void getAMDcacheinfo()
{
    uint c5, c6, d6;
    asm {
        mov EAX, 0x8000_0005; // L1 cache
        cpuid;
        // EAX has L1_TLB_4M.
        // EBX has L1_TLB_4K
        // EDX has L1 instruction cache
        mov c5, ECX;
    }

    datacache[0].size = ( (c5>>24) & 0xFF);
    datacache[0].associativity = cast(ubyte)( (c5 >> 16) & 0xFF);
    datacache[0].lineSize = c5 & 0xFF;

    if (max_extended_cpuid >= 0x8000_0006) {
        // AMD K6-III or K6-2+ or later.
        ubyte numcores = 1;
        if (max_extended_cpuid >=0x8000_0008) {
            asm {
                mov EAX, 0x8000_0008;
                cpuid;
                mov numcores, CL;
            }
            ++numcores;
            if (numcores>maxCores) maxCores = numcores;
        }
        asm {
            mov EAX, 0x8000_0006; // L2/L3 cache
            cpuid;
            mov c6, ECX; // L2 cache info
            mov d6, EDX; // L3 cache info
        }

        static immutable ubyte [] assocmap = [ 0, 1, 2, 0, 4, 0, 8, 0, 16, 0, 32, 48, 64, 96, 128, 0xFF ];
        datacache[1].size = (c6>>16) & 0xFFFF;
        datacache[1].associativity = assocmap[(c6>>12)&0xF];
        datacache[1].lineSize = c6 & 0xFF;

        // The L3 cache value is TOTAL, not per core.
        datacache[2].size = ((d6>>18)*512)/numcores; // could be up to 2 * this, -1.
        datacache[2].associativity = assocmap[(d6>>12)&0xF];
        datacache[2].lineSize = d6 & 0xFF;
    }
}

// For Intel CoreI7 and later, use function 0x0B
// to determine number of processors.
void getCpuInfo0B()
{
    int level=0;
    int threadsPerCore;
    uint a, b, c, d;
    do {
        asm {
            mov EAX, 0x0B;
            mov ECX, level;
            cpuid;
            mov a, EAX;
            mov b, EBX;
            mov c, ECX;
            mov d, EDX;
        }
        if (b!=0) {
           // I'm not sure about this. The docs state that there
           // are 2 hyperthreads per core if HT is factory enabled.
            if (level==0)
                threadsPerCore = b & 0xFFFF;
            else if (level==1) {
                maxThreads = b & 0xFFFF;
                maxCores = maxThreads / threadsPerCore;
            }

        }
        ++level;
    } while (a!=0 || b!=0);

}

void cpuidX86()
{
    char * venptr = vendorID.ptr;
    uint a, b, c, d, a2;
    version(D_InlineAsm_X86)
    {
        asm {
            mov EAX, 0;
            cpuid;
            mov a, EAX;
            mov EAX, venptr;
            mov [EAX], EBX;
            mov [EAX + 4], EDX;
            mov [EAX + 8], ECX;
        }
    }
    else version(D_InlineAsm_X86_64)
    {
        asm {
            mov EAX, 0;
            cpuid;
            mov a, EAX;
            mov RAX, venptr;
            mov [RAX], EBX;
            mov [RAX + 4], EDX;
            mov [RAX + 8], ECX;
        }
    }
    asm {
        mov EAX, 0x8000_0000;
        cpuid;
        mov a2, EAX;
    }
    max_cpuid = a;
    max_extended_cpuid = a2;


    probablyIntel = vendorID == "GenuineIntel";
    probablyAMD = vendorID == "AuthenticAMD";
    uint apic = 0; // brand index, apic id
    asm {
        mov EAX, 1; // model, stepping
        cpuid;
        mov a, EAX;
        mov apic, EBX;
        mov c, ECX;
        mov d, EDX;
    }
    features = d;
    miscfeatures = c;

    if (max_cpuid >= 7)
    {
        uint ext;

        asm
        {
            mov EAX, 7; // Structured extended feature leaf.
            mov ECX, 0; // Main leaf.
            cpuid;
            mov ext, EBX; // HLE, AVX2, RTM, etc.
        }

        extfeatures = ext;
    }

    if (miscfeatures & OSXSAVE_BIT)
    {
        asm {
            mov ECX, 0;
            xgetbv;
            mov d, EDX;
            mov a, EAX;
        }
        xfeatures = cast(ulong)d << 32 | a;
    }
    amdfeatures = 0;
    amdmiscfeatures = 0;
    if (max_extended_cpuid >= 0x8000_0001) {
        asm {
            mov EAX, 0x8000_0001;
            cpuid;
            mov c, ECX;
            mov d, EDX;
        }
        amdmiscfeatures = c;
        amdfeatures = d;
    }
    // Try to detect fraudulent vendorIDs
    if (amd3dnow) probablyIntel = false;

    stepping = a & 0xF;
    uint fbase = (a >> 8) & 0xF;
    uint mbase = (a >> 4) & 0xF;
    family = ((fbase == 0xF) || (fbase == 0)) ? fbase + (a >> 20) & 0xFF : fbase;
    model = ((fbase == 0xF) || (fbase == 6 && probablyIntel) ) ?
         mbase + ((a >> 12) & 0xF0) : mbase;

    if (!probablyIntel && max_extended_cpuid >= 0x8000_0008) {
        // determine max number of cores for AMD
        asm {
            mov EAX, 0x8000_0008;
            cpuid;
            mov c, ECX;
        }
        uint apicsize = (c>>12) & 0xF;
        if (apicsize == 0) {
            // use legacy method
            if (hyperThreadingBit)  maxCores = c & 0xFF;
            else maxCores = 1;
        } else {
            // maxcores = 2^ apicsize
            maxCores = 1;
            while (apicsize) { maxCores<<=1; --apicsize; }
        }
    }

    if (max_extended_cpuid >= 0x8000_0004) {
        char *procptr = processorNameBuffer.ptr;
        version(D_InlineAsm_X86)
        {
            asm {
                push ESI;
                mov ESI, procptr;
                mov EAX, 0x8000_0002;
                cpuid;
                mov [ESI], EAX;
                mov [ESI+4], EBX;
                mov [ESI+8], ECX;
                mov [ESI+12], EDX;
                mov EAX, 0x8000_0003;
                cpuid;
                mov [ESI+16], EAX;
                mov [ESI+20], EBX;
                mov [ESI+24], ECX;
                mov [ESI+28], EDX;
                mov EAX, 0x8000_0004;
                cpuid;
                mov [ESI+32], EAX;
                mov [ESI+36], EBX;
                mov [ESI+40], ECX;
                mov [ESI+44], EDX;
                pop ESI;
            }
        }
        else version(D_InlineAsm_X86_64)
        {
            asm {
                push RSI;
                mov RSI, procptr;
                mov EAX, 0x8000_0002;
                cpuid;
                mov [RSI], EAX;
                mov [RSI+4], EBX;
                mov [RSI+8], ECX;
                mov [RSI+12], EDX;
                mov EAX, 0x8000_0003;
                cpuid;
                mov [RSI+16], EAX;
                mov [RSI+20], EBX;
                mov [RSI+24], ECX;
                mov [RSI+28], EDX;
                mov EAX, 0x8000_0004;
                cpuid;
                mov [RSI+32], EAX;
                mov [RSI+36], EBX;
                mov [RSI+40], ECX;
                mov [RSI+44], EDX;
                pop RSI;
            }
        }
        // Intel P4 and PM pad at front with spaces.
        // Other CPUs pad at end with nulls.
        int start = 0, end = 0;
        while (processorNameBuffer[start] == ' ') { ++start; }
        while (processorNameBuffer[processorNameBuffer.length-end-1] == 0) { ++end; }
        processorName = cast(string)(processorNameBuffer[start..$-end]);
    } else {
        processorName = "Unknown CPU";
    }
    // Determine cache sizes

    // Intel docs specify that they return 0 for 0x8000_0005.
    // AMD docs do not specify the behaviour for 0004 and 0002.
    // Centaur/VIA and most other manufacturers use the AMD method,
    // except Cyrix MediaGX MMX Enhanced uses their OWN form of CPUID2!
    // NS Geode GX1 provides CyrixCPUID2 _and_ does the same wrong behaviour
    // for CPUID80000005. But Geode GX uses the AMD method

    // Deal with Geode GX1 - make it same as MediaGX MMX.
    if (max_extended_cpuid==0x8000_0005 && max_cpuid==2) {
        max_extended_cpuid = 0x8000_0004;
    }
    // Therefore, we try the AMD method unless it's an Intel chip.
    // If we still have no info, try the Intel methods.
    datacache[0].size = 0;
    if (max_cpuid<2 || !probablyIntel) {
        if (max_extended_cpuid >= 0x8000_0005) {
            getAMDcacheinfo();
        } else if (probablyAMD) {
            // According to AMDProcRecognitionAppNote, this means CPU
            // K5 model 0, or Am5x86 (model 4), or Am4x86DX4 (model 4)
            // Am5x86 has 16Kb 4-way unified data & code cache.
            datacache[0].size = 8;
            datacache[0].associativity = 4;
            datacache[0].lineSize = 32;
        } else {
            // Some obscure CPU.
            // Values for Cyrix 6x86MX (family 6, model 0)
            datacache[0].size = 64;
            datacache[0].associativity = 4;
            datacache[0].lineSize = 32;
        }
    }
    if ((datacache[0].size == 0) && max_cpuid>=4) {
        getcacheinfoCPUID4();
    }
    if ((datacache[0].size == 0) && max_cpuid>=2) {
        getcacheinfoCPUID2();
    }
    if (datacache[0].size == 0) {
        // Pentium, PMMX, late model 486, or an obscure CPU
        if (mmx) { // Pentium MMX. Also has 8kB code cache.
            datacache[0].size = 16;
            datacache[0].associativity = 4;
            datacache[0].lineSize = 32;
        } else { // Pentium 1 (which also has 8kB code cache)
                 // or 486.
            // Cyrix 6x86: 16, 4way, 32 linesize
            datacache[0].size = 8;
            datacache[0].associativity = 2;
            datacache[0].lineSize = 32;
        }
    }
    if (max_cpuid >=0x0B) {
        // For Intel i7 and later, use function 0x0B to determine
        // cores and hyperthreads.
        getCpuInfo0B();
    } else {
        if (hyperThreadingBit) maxThreads = (apic>>>16) & 0xFF;
        else maxThreads = maxCores;
    }
}

// Return true if the cpuid instruction is supported.
// BUG(WONTFIX): Returns false for Cyrix 6x86 and 6x86L. They will be treated as 486 machines.
bool hasCPUID()
{
    version(D_InlineAsm_X86_64)
        return true;
    else
    {
        uint flags;
        asm {
            pushfd;
            pop EAX;
            mov flags, EAX;
            xor EAX, 0x0020_0000;
            push EAX;
            popfd;
            pushfd;
            pop EAX;
            xor flags, EAX;
        }
        return (flags & 0x0020_0000) !=0;
    }
}

} else { // inline asm X86

    bool hasCPUID() { return false; }

    void cpuidX86()
    {
            datacache[0].size = 8;
            datacache[0].associativity = 2;
            datacache[0].lineSize = 32;
    }
}

/*
// TODO: Implement this function with OS support
void cpuidPPC()
{
    enum :int  { PPC601, PPC603, PPC603E, PPC604,
                 PPC604E, PPC620, PPCG3, PPCG4, PPCG5 }

    // TODO:
    // asm { mfpvr; } returns the CPU version but unfortunately it can
    // only be used in kernel mode. So OS support is required.
    int cputype = PPC603;

    // 601 has a 8KB combined data & code L1 cache.
    uint sizes[] = [4, 8, 16, 16, 32, 32, 32, 32, 64];
    ubyte ways[] = [8, 2,  4,  4,  4,  8,  8,  8,  8];
    uint L2size[]= [0, 0,  0,  0,  0,  0,  0,  256,  512];
    uint L3size[]= [0, 0,  0,  0,  0,  0,  0,  2048,  0];

    datacache[0].size = sizes[cputype];
    datacache[0].associativity = ways[cputype];
    datacache[0].lineSize = (cputype==PPCG5)? 128 :
        (cputype == PPC620 || cputype == PPCG3)? 64 : 32;
    datacache[1].size = L2size[cputype];
    datacache[2].size = L3size[cputype];
    datacache[1].lineSize = datacache[0].lineSize;
    datacache[2].lineSize = datacache[0].lineSize;
}

// TODO: Implement this function with OS support
void cpuidSparc()
{
    // UltaSparcIIi  : L1 = 16,  2way. L2 = 512, 4 way.
    // UltraSparcIII : L1 = 64,  4way. L2= 4096 or 8192.
    // UltraSparcIIIi: L1 = 64,  4way. L2= 1024, 4 way
    // UltraSparcIV  : L1 = 64,  4way. L2 = 16*1024.
    // UltraSparcIV+ : L1 = 64,  4way. L2 = 2048, L3=32*1024.
    // Sparc64V      : L1 = 128, 2way. L2 = 4096 4way.
}
*/

shared static this()
{
    if (hasCPUID()) {
        cpuidX86();
    } else {
        // it's a 386 or 486, or a Cyrix 6x86.
        //Probably still has an external cache.
    }
    if (datacache[0].size==0) {
            // Guess same as Pentium 1.
            datacache[0].size = 8;
            datacache[0].associativity = 2;
            datacache[0].lineSize = 32;
    }
    numCacheLevels = 1;
    // And now fill up all the unused levels with full memory space.
    for (size_t i=1; i< datacache.length; ++i) {
        if (datacache[i].size==0) {
            // Set all remaining levels of cache equal to full address space.
            datacache[i].size = size_t.max/1024;
            datacache[i].associativity = 1;
            datacache[i].lineSize = datacache[i-1].lineSize;
        }
        else
            ++numCacheLevels;
    }
}
