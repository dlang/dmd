// REQUIRED_ARGS: -verrors=0
/*
TEST_OUTPUT:
---
fail_compilation/reserved_version.d(377): Error: version identifier `MSP430` is reserved and cannot be set
version = MSP430;
          ^
fail_compilation/reserved_version.d(378): Error: version identifier `D_P16` is reserved and cannot be set
version = D_P16;
          ^
fail_compilation/reserved_version.d(379): Error: version identifier `DigitalMars` is reserved and cannot be set
version = DigitalMars;
          ^
fail_compilation/reserved_version.d(380): Error: version identifier `GNU` is reserved and cannot be set
version = GNU;
          ^
fail_compilation/reserved_version.d(381): Error: version identifier `LDC` is reserved and cannot be set
version = LDC;
          ^
fail_compilation/reserved_version.d(382): Error: version identifier `SDC` is reserved and cannot be set
version = SDC;
          ^
fail_compilation/reserved_version.d(383): Error: version identifier `Windows` is reserved and cannot be set
version = Windows;
          ^
fail_compilation/reserved_version.d(384): Error: version identifier `Win32` is reserved and cannot be set
version = Win32;
          ^
fail_compilation/reserved_version.d(385): Error: version identifier `Win64` is reserved and cannot be set
version = Win64;
          ^
fail_compilation/reserved_version.d(386): Error: version identifier `linux` is reserved and cannot be set
version = linux;
          ^
fail_compilation/reserved_version.d(387): Error: version identifier `OSX` is reserved and cannot be set
version = OSX;
          ^
fail_compilation/reserved_version.d(388): Error: version identifier `iOS` is reserved and cannot be set
version = iOS;
          ^
fail_compilation/reserved_version.d(389): Error: version identifier `TVOS` is reserved and cannot be set
version = TVOS;
          ^
fail_compilation/reserved_version.d(390): Error: version identifier `WatchOS` is reserved and cannot be set
version = WatchOS;
          ^
fail_compilation/reserved_version.d(391): Error: version identifier `FreeBSD` is reserved and cannot be set
version = FreeBSD;
          ^
fail_compilation/reserved_version.d(392): Error: version identifier `OpenBSD` is reserved and cannot be set
version = OpenBSD;
          ^
fail_compilation/reserved_version.d(393): Error: version identifier `NetBSD` is reserved and cannot be set
version = NetBSD;
          ^
fail_compilation/reserved_version.d(394): Error: version identifier `DragonFlyBSD` is reserved and cannot be set
version = DragonFlyBSD;
          ^
fail_compilation/reserved_version.d(395): Error: version identifier `BSD` is reserved and cannot be set
version = BSD;
          ^
fail_compilation/reserved_version.d(396): Error: version identifier `Solaris` is reserved and cannot be set
version = Solaris;
          ^
fail_compilation/reserved_version.d(397): Error: version identifier `Posix` is reserved and cannot be set
version = Posix;
          ^
fail_compilation/reserved_version.d(398): Error: version identifier `AIX` is reserved and cannot be set
version = AIX;
          ^
fail_compilation/reserved_version.d(399): Error: version identifier `Haiku` is reserved and cannot be set
version = Haiku;
          ^
fail_compilation/reserved_version.d(400): Error: version identifier `SkyOS` is reserved and cannot be set
version = SkyOS;
          ^
fail_compilation/reserved_version.d(401): Error: version identifier `SysV3` is reserved and cannot be set
version = SysV3;
          ^
fail_compilation/reserved_version.d(402): Error: version identifier `SysV4` is reserved and cannot be set
version = SysV4;
          ^
fail_compilation/reserved_version.d(403): Error: version identifier `Hurd` is reserved and cannot be set
version = Hurd;
          ^
fail_compilation/reserved_version.d(404): Error: version identifier `Android` is reserved and cannot be set
version = Android;
          ^
fail_compilation/reserved_version.d(405): Error: version identifier `PlayStation` is reserved and cannot be set
version = PlayStation;
          ^
fail_compilation/reserved_version.d(406): Error: version identifier `PlayStation4` is reserved and cannot be set
version = PlayStation4;
          ^
fail_compilation/reserved_version.d(407): Error: version identifier `Cygwin` is reserved and cannot be set
version = Cygwin;
          ^
fail_compilation/reserved_version.d(408): Error: version identifier `MinGW` is reserved and cannot be set
version = MinGW;
          ^
fail_compilation/reserved_version.d(409): Error: version identifier `FreeStanding` is reserved and cannot be set
version = FreeStanding;
          ^
fail_compilation/reserved_version.d(410): Error: version identifier `X86` is reserved and cannot be set
version = X86;
          ^
fail_compilation/reserved_version.d(411): Error: version identifier `X86_64` is reserved and cannot be set
version = X86_64;
          ^
fail_compilation/reserved_version.d(412): Error: version identifier `ARM` is reserved and cannot be set
version = ARM;
          ^
fail_compilation/reserved_version.d(413): Error: version identifier `ARM_Thumb` is reserved and cannot be set
version = ARM_Thumb;
          ^
fail_compilation/reserved_version.d(414): Error: version identifier `ARM_SoftFloat` is reserved and cannot be set
version = ARM_SoftFloat;
          ^
fail_compilation/reserved_version.d(415): Error: version identifier `ARM_SoftFP` is reserved and cannot be set
version = ARM_SoftFP;
          ^
fail_compilation/reserved_version.d(416): Error: version identifier `ARM_HardFloat` is reserved and cannot be set
version = ARM_HardFloat;
          ^
fail_compilation/reserved_version.d(417): Error: version identifier `AArch64` is reserved and cannot be set
version = AArch64;
          ^
fail_compilation/reserved_version.d(418): Error: version identifier `Epiphany` is reserved and cannot be set
version = Epiphany;
          ^
fail_compilation/reserved_version.d(419): Error: version identifier `PPC` is reserved and cannot be set
version = PPC;
          ^
fail_compilation/reserved_version.d(420): Error: version identifier `PPC_SoftFloat` is reserved and cannot be set
version = PPC_SoftFloat;
          ^
fail_compilation/reserved_version.d(421): Error: version identifier `PPC_HardFloat` is reserved and cannot be set
version = PPC_HardFloat;
          ^
fail_compilation/reserved_version.d(422): Error: version identifier `PPC64` is reserved and cannot be set
version = PPC64;
          ^
fail_compilation/reserved_version.d(423): Error: version identifier `IA64` is reserved and cannot be set
version = IA64;
          ^
fail_compilation/reserved_version.d(424): Error: version identifier `MIPS32` is reserved and cannot be set
version = MIPS32;
          ^
fail_compilation/reserved_version.d(425): Error: version identifier `MIPS64` is reserved and cannot be set
version = MIPS64;
          ^
fail_compilation/reserved_version.d(426): Error: version identifier `MIPS_O32` is reserved and cannot be set
version = MIPS_O32;
          ^
fail_compilation/reserved_version.d(427): Error: version identifier `MIPS_N32` is reserved and cannot be set
version = MIPS_N32;
          ^
fail_compilation/reserved_version.d(428): Error: version identifier `MIPS_O64` is reserved and cannot be set
version = MIPS_O64;
          ^
fail_compilation/reserved_version.d(429): Error: version identifier `MIPS_N64` is reserved and cannot be set
version = MIPS_N64;
          ^
fail_compilation/reserved_version.d(430): Error: version identifier `MIPS_EABI` is reserved and cannot be set
version = MIPS_EABI;
          ^
fail_compilation/reserved_version.d(431): Error: version identifier `MIPS_SoftFloat` is reserved and cannot be set
version = MIPS_SoftFloat;
          ^
fail_compilation/reserved_version.d(432): Error: version identifier `MIPS_HardFloat` is reserved and cannot be set
version = MIPS_HardFloat;
          ^
fail_compilation/reserved_version.d(433): Error: version identifier `NVPTX` is reserved and cannot be set
version = NVPTX;
          ^
fail_compilation/reserved_version.d(434): Error: version identifier `NVPTX64` is reserved and cannot be set
version = NVPTX64;
          ^
fail_compilation/reserved_version.d(435): Error: version identifier `RISCV32` is reserved and cannot be set
version = RISCV32;
          ^
fail_compilation/reserved_version.d(436): Error: version identifier `RISCV64` is reserved and cannot be set
version = RISCV64;
          ^
fail_compilation/reserved_version.d(437): Error: version identifier `SPARC` is reserved and cannot be set
version = SPARC;
          ^
fail_compilation/reserved_version.d(438): Error: version identifier `SPARC_V8Plus` is reserved and cannot be set
version = SPARC_V8Plus;
          ^
fail_compilation/reserved_version.d(439): Error: version identifier `SPARC_SoftFloat` is reserved and cannot be set
version = SPARC_SoftFloat;
          ^
fail_compilation/reserved_version.d(440): Error: version identifier `SPARC_HardFloat` is reserved and cannot be set
version = SPARC_HardFloat;
          ^
fail_compilation/reserved_version.d(441): Error: version identifier `SPARC64` is reserved and cannot be set
version = SPARC64;
          ^
fail_compilation/reserved_version.d(442): Error: version identifier `S390` is reserved and cannot be set
version = S390;
          ^
fail_compilation/reserved_version.d(443): Error: version identifier `S390X` is reserved and cannot be set
version = S390X;
          ^
fail_compilation/reserved_version.d(444): Error: version identifier `SystemZ` is reserved and cannot be set
version = SystemZ;
          ^
fail_compilation/reserved_version.d(445): Error: version identifier `HPPA` is reserved and cannot be set
version = HPPA;
          ^
fail_compilation/reserved_version.d(446): Error: version identifier `HPPA64` is reserved and cannot be set
version = HPPA64;
          ^
fail_compilation/reserved_version.d(447): Error: version identifier `SH` is reserved and cannot be set
version = SH;
          ^
fail_compilation/reserved_version.d(448): Error: version identifier `Alpha` is reserved and cannot be set
version = Alpha;
          ^
fail_compilation/reserved_version.d(449): Error: version identifier `Alpha_SoftFloat` is reserved and cannot be set
version = Alpha_SoftFloat;
          ^
fail_compilation/reserved_version.d(450): Error: version identifier `Alpha_HardFloat` is reserved and cannot be set
version = Alpha_HardFloat;
          ^
fail_compilation/reserved_version.d(451): Error: version identifier `LoongArch32` is reserved and cannot be set
version = LoongArch32;
          ^
fail_compilation/reserved_version.d(452): Error: version identifier `LoongArch64` is reserved and cannot be set
version = LoongArch64;
          ^
fail_compilation/reserved_version.d(453): Error: version identifier `LoongArch_HardFloat` is reserved and cannot be set
version = LoongArch_HardFloat;
          ^
fail_compilation/reserved_version.d(454): Error: version identifier `LoongArch_SoftFloat` is reserved and cannot be set
version = LoongArch_SoftFloat;
          ^
fail_compilation/reserved_version.d(455): Error: version identifier `Xtensa` is reserved and cannot be set
version = Xtensa;
          ^
fail_compilation/reserved_version.d(456): Error: version identifier `LittleEndian` is reserved and cannot be set
version = LittleEndian;
          ^
fail_compilation/reserved_version.d(457): Error: version identifier `BigEndian` is reserved and cannot be set
version = BigEndian;
          ^
fail_compilation/reserved_version.d(458): Error: version identifier `ELFv1` is reserved and cannot be set
version = ELFv1;
          ^
fail_compilation/reserved_version.d(459): Error: version identifier `ELFv2` is reserved and cannot be set
version = ELFv2;
          ^
fail_compilation/reserved_version.d(460): Error: version identifier `CRuntime_Bionic` is reserved and cannot be set
version = CRuntime_Bionic;
          ^
fail_compilation/reserved_version.d(461): Error: version identifier `CRuntime_DigitalMars` is reserved and cannot be set
version = CRuntime_DigitalMars;
          ^
fail_compilation/reserved_version.d(462): Error: version identifier `CRuntime_Glibc` is reserved and cannot be set
version = CRuntime_Glibc;
          ^
fail_compilation/reserved_version.d(463): Error: version identifier `CRuntime_Microsoft` is reserved and cannot be set
version = CRuntime_Microsoft;
          ^
fail_compilation/reserved_version.d(464): Error: version identifier `CRuntime_Musl` is reserved and cannot be set
version = CRuntime_Musl;
          ^
fail_compilation/reserved_version.d(465): Error: version identifier `CRuntime_Newlib` is reserved and cannot be set
version = CRuntime_Newlib;
          ^
fail_compilation/reserved_version.d(466): Error: version identifier `CRuntime_UClibc` is reserved and cannot be set
version = CRuntime_UClibc;
          ^
fail_compilation/reserved_version.d(467): Error: version identifier `CRuntime_WASI` is reserved and cannot be set
version = CRuntime_WASI;
          ^
fail_compilation/reserved_version.d(468): Error: version identifier `D_Coverage` is reserved and cannot be set
version = D_Coverage;
          ^
fail_compilation/reserved_version.d(469): Error: version identifier `D_Ddoc` is reserved and cannot be set
version = D_Ddoc;
          ^
fail_compilation/reserved_version.d(470): Error: version identifier `D_InlineAsm_X86` is reserved and cannot be set
version = D_InlineAsm_X86;
          ^
fail_compilation/reserved_version.d(471): Error: version identifier `D_InlineAsm_X86_64` is reserved and cannot be set
version = D_InlineAsm_X86_64;
          ^
fail_compilation/reserved_version.d(472): Error: version identifier `D_LP64` is reserved and cannot be set
version = D_LP64;
          ^
fail_compilation/reserved_version.d(473): Error: version identifier `D_X32` is reserved and cannot be set
version = D_X32;
          ^
fail_compilation/reserved_version.d(474): Error: version identifier `D_HardFloat` is reserved and cannot be set
version = D_HardFloat;
          ^
fail_compilation/reserved_version.d(475): Error: version identifier `D_SoftFloat` is reserved and cannot be set
version = D_SoftFloat;
          ^
fail_compilation/reserved_version.d(476): Error: version identifier `D_PIC` is reserved and cannot be set
version = D_PIC;
          ^
fail_compilation/reserved_version.d(477): Error: version identifier `D_SIMD` is reserved and cannot be set
version = D_SIMD;
          ^
fail_compilation/reserved_version.d(478): Error: version identifier `D_Version2` is reserved and cannot be set
version = D_Version2;
          ^
fail_compilation/reserved_version.d(479): Error: version identifier `D_NoBoundsChecks` is reserved and cannot be set
version = D_NoBoundsChecks;
          ^
fail_compilation/reserved_version.d(482): Error: version identifier `all` is reserved and cannot be set
version = all;
          ^
fail_compilation/reserved_version.d(483): Error: version identifier `none` is reserved and cannot be set
version = none;
          ^
fail_compilation/reserved_version.d(484): Error: version identifier `AsmJS` is reserved and cannot be set
version = AsmJS;
          ^
fail_compilation/reserved_version.d(485): Error: version identifier `Emscripten` is reserved and cannot be set
version = Emscripten;
          ^
fail_compilation/reserved_version.d(486): Error: version identifier `WebAssembly` is reserved and cannot be set
version = WebAssembly;
          ^
fail_compilation/reserved_version.d(487): Error: version identifier `WASI` is reserved and cannot be set
version = WASI;
          ^
fail_compilation/reserved_version.d(488): Error: version identifier `CppRuntime_LLVM` is reserved and cannot be set
version = CppRuntime_LLVM;
          ^
fail_compilation/reserved_version.d(489): Error: version identifier `CppRuntime_DigitalMars` is reserved and cannot be set
version = CppRuntime_DigitalMars;
          ^
fail_compilation/reserved_version.d(490): Error: version identifier `CppRuntime_GNU` is reserved and cannot be set
version = CppRuntime_GNU;
          ^
fail_compilation/reserved_version.d(491): Error: version identifier `CppRuntime_Microsoft` is reserved and cannot be set
version = CppRuntime_Microsoft;
          ^
fail_compilation/reserved_version.d(492): Error: version identifier `CppRuntime_Sun` is reserved and cannot be set
version = CppRuntime_Sun;
          ^
fail_compilation/reserved_version.d(493): Error: version identifier `D_PIE` is reserved and cannot be set
version = D_PIE;
          ^
fail_compilation/reserved_version.d(494): Error: version identifier `AVR` is reserved and cannot be set
version = AVR;
          ^
fail_compilation/reserved_version.d(495): Error: version identifier `D_PreConditions` is reserved and cannot be set
version = D_PreConditions;
          ^
fail_compilation/reserved_version.d(496): Error: version identifier `D_PostConditions` is reserved and cannot be set
version = D_PostConditions;
          ^
fail_compilation/reserved_version.d(497): Error: version identifier `D_ProfileGC` is reserved and cannot be set
version = D_ProfileGC;
          ^
fail_compilation/reserved_version.d(498): Error: version identifier `D_Invariants` is reserved and cannot be set
version = D_Invariants;
          ^
fail_compilation/reserved_version.d(499): Error: version identifier `D_Optimized` is reserved and cannot be set
version = D_Optimized;
          ^
fail_compilation/reserved_version.d(500): Error: version identifier `VisionOS` is reserved and cannot be set
version = VisionOS;
          ^
---
*/

// Some extra empty lines to help fixup the manual line numbering after adding new version identifiers

// Line 105 starts here
version = MSP430;
version = D_P16;
version = DigitalMars;
version = GNU;
version = LDC;
version = SDC;
version = Windows;
version = Win32;
version = Win64;
version = linux;
version = OSX;
version = iOS;
version = TVOS;
version = WatchOS;
version = FreeBSD;
version = OpenBSD;
version = NetBSD;
version = DragonFlyBSD;
version = BSD;
version = Solaris;
version = Posix;
version = AIX;
version = Haiku;
version = SkyOS;
version = SysV3;
version = SysV4;
version = Hurd;
version = Android;
version = PlayStation;
version = PlayStation4;
version = Cygwin;
version = MinGW;
version = FreeStanding;
version = X86;
version = X86_64;
version = ARM;
version = ARM_Thumb;
version = ARM_SoftFloat;
version = ARM_SoftFP;
version = ARM_HardFloat;
version = AArch64;
version = Epiphany;
version = PPC;
version = PPC_SoftFloat;
version = PPC_HardFloat;
version = PPC64;
version = IA64;
version = MIPS32;
version = MIPS64;
version = MIPS_O32;
version = MIPS_N32;
version = MIPS_O64;
version = MIPS_N64;
version = MIPS_EABI;
version = MIPS_SoftFloat;
version = MIPS_HardFloat;
version = NVPTX;
version = NVPTX64;
version = RISCV32;
version = RISCV64;
version = SPARC;
version = SPARC_V8Plus;
version = SPARC_SoftFloat;
version = SPARC_HardFloat;
version = SPARC64;
version = S390;
version = S390X;
version = SystemZ;
version = HPPA;
version = HPPA64;
version = SH;
version = Alpha;
version = Alpha_SoftFloat;
version = Alpha_HardFloat;
version = LoongArch32;
version = LoongArch64;
version = LoongArch_HardFloat;
version = LoongArch_SoftFloat;
version = Xtensa;
version = LittleEndian;
version = BigEndian;
version = ELFv1;
version = ELFv2;
version = CRuntime_Bionic;
version = CRuntime_DigitalMars;
version = CRuntime_Glibc;
version = CRuntime_Microsoft;
version = CRuntime_Musl;
version = CRuntime_Newlib;
version = CRuntime_UClibc;
version = CRuntime_WASI;
version = D_Coverage;
version = D_Ddoc;
version = D_InlineAsm_X86;
version = D_InlineAsm_X86_64;
version = D_LP64;
version = D_X32;
version = D_HardFloat;
version = D_SoftFloat;
version = D_PIC;
version = D_SIMD;
version = D_Version2;
version = D_NoBoundsChecks;
//version = unittest;
//version = assert;
version = all;
version = none;
version = AsmJS;
version = Emscripten;
version = WebAssembly;
version = WASI;
version = CppRuntime_LLVM;
version = CppRuntime_DigitalMars;
version = CppRuntime_GNU;
version = CppRuntime_Microsoft;
version = CppRuntime_Sun;
version = D_PIE;
version = AVR;
version = D_PreConditions;
version = D_PostConditions;
version = D_ProfileGC;
version = D_Invariants;
version = D_Optimized;
version = VisionOS;

// This should work though
debug = DigitalMars;
debug = GNU;
debug = LDC;
debug = SDC;
debug = Windows;
debug = Win32;
debug = Win64;
debug = linux;
debug = OSX;
debug = FreeBSD;
debug = OpenBSD;
debug = NetBSD;
debug = DragonFlyBSD;
debug = BSD;
debug = Solaris;
debug = Posix;
debug = AIX;
debug = Haiku;
debug = SkyOS;
debug = SysV3;
debug = SysV4;
debug = Hurd;
debug = Android;
debug = Cygwin;
debug = MinGW;
debug = FreeStanding;
debug = X86;
debug = X86_64;
debug = ARM;
debug = ARM_Thumb;
debug = ARM_SoftFloat;
debug = ARM_SoftFP;
debug = ARM_HardFloat;
debug = AArch64;
debug = Epiphany;
debug = PPC;
debug = PPC_SoftFloat;
debug = PPC_HardFloat;
debug = PPC64;
debug = IA64;
debug = MIPS32;
debug = MIPS64;
debug = MIPS_O32;
debug = MIPS_N32;
debug = MIPS_O64;
debug = MIPS_N64;
debug = MIPS_EABI;
debug = MIPS_SoftFloat;
debug = MIPS_HardFloat;
debug = NVPTX;
debug = NVPTX64;
debug = RISCV32;
debug = RISCV64;
debug = SPARC;
debug = SPARC_V8Plus;
debug = SPARC_SoftFloat;
debug = SPARC_HardFloat;
debug = SPARC64;
debug = S390;
debug = S390X;
debug = SystemZ;
debug = HPPA;
debug = HPPA64;
debug = SH;
debug = WebAssembly;
debug = WASI;
debug = Alpha;
debug = Alpha_SoftFloat;
debug = Alpha_HardFloat;
debug = LoongArch32;
debug = LoongArch64;
debug = LoongArch_HardFloat;
debug = LoongArch_SoftFloat;
debug = Xtensa;
debug = LittleEndian;
debug = BigEndian;
debug = ELFv1;
debug = ELFv2;
debug = CRuntime_Bionic;
debug = CRuntime_DigitalMars;
debug = CRuntime_Glibc;
debug = CRuntime_Microsoft;
debug = CRuntime_Musl;
debug = CRuntime_Newlib;
debug = CRuntime_UClibc;
debug = CRuntime_WASI;
debug = CppRuntime_LLVM;
debug = CppRuntime_DigitalMars;
debug = CppRuntime_GNU;
debug = CppRuntime_Microsoft;
debug = CppRuntime_Sun;
debug = D_Coverage;
debug = D_Ddoc;
debug = D_InlineAsm_X86;
debug = D_InlineAsm_X86_64;
debug = D_LP64;
debug = D_X32;
debug = D_HardFloat;
debug = D_SoftFloat;
debug = D_PIC;
debug = D_PIE;
debug = D_SIMD;
debug = D_Version2;
debug = D_NoBoundsChecks;
//debug = unittest;
//debug = assert;
debug = all;
debug = none;
debug = D_P16;
debug = MSP430;
debug = AVR;
debug = D_PreConditions;
debug = D_PostConditions;
debug = D_ProfileGC;
debug = D_Optimized;
