// REQUIRED_ARGS: -verrors=0
/*
TEST_OUTPUT:
---
fail_compilation/reserved_version.d(2): Error: version identifier 'DigitalMars' is reserved and cannot be set
fail_compilation/reserved_version.d(3): Error: version identifier 'GNU' is reserved and cannot be set
fail_compilation/reserved_version.d(4): Error: version identifier 'LDC' is reserved and cannot be set
fail_compilation/reserved_version.d(5): Error: version identifier 'SDC' is reserved and cannot be set
fail_compilation/reserved_version.d(6): Error: version identifier 'Windows' is reserved and cannot be set
fail_compilation/reserved_version.d(7): Error: version identifier 'Win32' is reserved and cannot be set
fail_compilation/reserved_version.d(8): Error: version identifier 'Win64' is reserved and cannot be set
fail_compilation/reserved_version.d(9): Error: version identifier 'linux' is reserved and cannot be set
fail_compilation/reserved_version.d(10): Error: version identifier 'OSX' is reserved and cannot be set
fail_compilation/reserved_version.d(11): Error: version identifier 'FreeBSD' is reserved and cannot be set
fail_compilation/reserved_version.d(12): Error: version identifier 'OpenBSD' is reserved and cannot be set
fail_compilation/reserved_version.d(13): Error: version identifier 'NetBSD' is reserved and cannot be set
fail_compilation/reserved_version.d(14): Error: version identifier 'DragonFlyBSD' is reserved and cannot be set
fail_compilation/reserved_version.d(15): Error: version identifier 'BSD' is reserved and cannot be set
fail_compilation/reserved_version.d(16): Error: version identifier 'Solaris' is reserved and cannot be set
fail_compilation/reserved_version.d(17): Error: version identifier 'Posix' is reserved and cannot be set
fail_compilation/reserved_version.d(18): Error: version identifier 'AIX' is reserved and cannot be set
fail_compilation/reserved_version.d(19): Error: version identifier 'Haiku' is reserved and cannot be set
fail_compilation/reserved_version.d(20): Error: version identifier 'SkyOS' is reserved and cannot be set
fail_compilation/reserved_version.d(21): Error: version identifier 'SysV3' is reserved and cannot be set
fail_compilation/reserved_version.d(22): Error: version identifier 'SysV4' is reserved and cannot be set
fail_compilation/reserved_version.d(23): Error: version identifier 'Hurd' is reserved and cannot be set
fail_compilation/reserved_version.d(24): Error: version identifier 'Android' is reserved and cannot be set
fail_compilation/reserved_version.d(25): Error: version identifier 'Cygwin' is reserved and cannot be set
fail_compilation/reserved_version.d(26): Error: version identifier 'MinGW' is reserved and cannot be set
fail_compilation/reserved_version.d(27): Error: version identifier 'FreeStanding' is reserved and cannot be set
fail_compilation/reserved_version.d(28): Error: version identifier 'X86' is reserved and cannot be set
fail_compilation/reserved_version.d(29): Error: version identifier 'X86_64' is reserved and cannot be set
fail_compilation/reserved_version.d(30): Error: version identifier 'ARM' is reserved and cannot be set
fail_compilation/reserved_version.d(31): Error: version identifier 'ARM_Thumb' is reserved and cannot be set
fail_compilation/reserved_version.d(32): Error: version identifier 'ARM_SoftFloat' is reserved and cannot be set
fail_compilation/reserved_version.d(33): Error: version identifier 'ARM_SoftFP' is reserved and cannot be set
fail_compilation/reserved_version.d(34): Error: version identifier 'ARM_HardFloat' is reserved and cannot be set
fail_compilation/reserved_version.d(35): Error: version identifier 'AArch64' is reserved and cannot be set
fail_compilation/reserved_version.d(36): Error: version identifier 'Epiphany' is reserved and cannot be set
fail_compilation/reserved_version.d(37): Error: version identifier 'PPC' is reserved and cannot be set
fail_compilation/reserved_version.d(38): Error: version identifier 'PPC_SoftFloat' is reserved and cannot be set
fail_compilation/reserved_version.d(39): Error: version identifier 'PPC_HardFloat' is reserved and cannot be set
fail_compilation/reserved_version.d(40): Error: version identifier 'PPC64' is reserved and cannot be set
fail_compilation/reserved_version.d(41): Error: version identifier 'IA64' is reserved and cannot be set
fail_compilation/reserved_version.d(42): Error: version identifier 'MIPS32' is reserved and cannot be set
fail_compilation/reserved_version.d(43): Error: version identifier 'MIPS64' is reserved and cannot be set
fail_compilation/reserved_version.d(44): Error: version identifier 'MIPS_O32' is reserved and cannot be set
fail_compilation/reserved_version.d(45): Error: version identifier 'MIPS_N32' is reserved and cannot be set
fail_compilation/reserved_version.d(46): Error: version identifier 'MIPS_O64' is reserved and cannot be set
fail_compilation/reserved_version.d(47): Error: version identifier 'MIPS_N64' is reserved and cannot be set
fail_compilation/reserved_version.d(48): Error: version identifier 'MIPS_EABI' is reserved and cannot be set
fail_compilation/reserved_version.d(49): Error: version identifier 'MIPS_SoftFloat' is reserved and cannot be set
fail_compilation/reserved_version.d(50): Error: version identifier 'MIPS_HardFloat' is reserved and cannot be set
fail_compilation/reserved_version.d(51): Error: version identifier 'NVPTX' is reserved and cannot be set
fail_compilation/reserved_version.d(52): Error: version identifier 'NVPTX64' is reserved and cannot be set
fail_compilation/reserved_version.d(53): Error: version identifier 'SPARC' is reserved and cannot be set
fail_compilation/reserved_version.d(54): Error: version identifier 'SPARC_V8Plus' is reserved and cannot be set
fail_compilation/reserved_version.d(55): Error: version identifier 'SPARC_SoftFloat' is reserved and cannot be set
fail_compilation/reserved_version.d(56): Error: version identifier 'SPARC_HardFloat' is reserved and cannot be set
fail_compilation/reserved_version.d(57): Error: version identifier 'SPARC64' is reserved and cannot be set
fail_compilation/reserved_version.d(58): Error: version identifier 'S390' is reserved and cannot be set
fail_compilation/reserved_version.d(59): Error: version identifier 'S390X' is reserved and cannot be set
fail_compilation/reserved_version.d(60): Error: version identifier 'SystemZ' is reserved and cannot be set
fail_compilation/reserved_version.d(61): Error: version identifier 'HPPA' is reserved and cannot be set
fail_compilation/reserved_version.d(62): Error: version identifier 'HPPA64' is reserved and cannot be set
fail_compilation/reserved_version.d(63): Error: version identifier 'SH' is reserved and cannot be set
fail_compilation/reserved_version.d(64): Error: version identifier 'SH64' is reserved and cannot be set
fail_compilation/reserved_version.d(65): Error: version identifier 'Alpha' is reserved and cannot be set
fail_compilation/reserved_version.d(66): Error: version identifier 'Alpha_SoftFloat' is reserved and cannot be set
fail_compilation/reserved_version.d(67): Error: version identifier 'Alpha_HardFloat' is reserved and cannot be set
fail_compilation/reserved_version.d(68): Error: version identifier 'LittleEndian' is reserved and cannot be set
fail_compilation/reserved_version.d(69): Error: version identifier 'BigEndian' is reserved and cannot be set
fail_compilation/reserved_version.d(70): Error: version identifier 'ELFv1' is reserved and cannot be set
fail_compilation/reserved_version.d(71): Error: version identifier 'ELFv2' is reserved and cannot be set
fail_compilation/reserved_version.d(72): Error: version identifier 'CRuntime_Bionic' is reserved and cannot be set
fail_compilation/reserved_version.d(73): Error: version identifier 'CRuntime_DigitalMars' is reserved and cannot be set
fail_compilation/reserved_version.d(74): Error: version identifier 'CRuntime_Glibc' is reserved and cannot be set
fail_compilation/reserved_version.d(75): Error: version identifier 'CRuntime_Microsoft' is reserved and cannot be set
fail_compilation/reserved_version.d(76): Error: version identifier 'D_Coverage' is reserved and cannot be set
fail_compilation/reserved_version.d(77): Error: version identifier 'D_Ddoc' is reserved and cannot be set
fail_compilation/reserved_version.d(78): Error: version identifier 'D_InlineAsm_X86' is reserved and cannot be set
fail_compilation/reserved_version.d(79): Error: version identifier 'D_InlineAsm_X86_64' is reserved and cannot be set
fail_compilation/reserved_version.d(80): Error: version identifier 'D_LP64' is reserved and cannot be set
fail_compilation/reserved_version.d(81): Error: version identifier 'D_X32' is reserved and cannot be set
fail_compilation/reserved_version.d(82): Error: version identifier 'D_HardFloat' is reserved and cannot be set
fail_compilation/reserved_version.d(83): Error: version identifier 'D_SoftFloat' is reserved and cannot be set
fail_compilation/reserved_version.d(84): Error: version identifier 'D_PIC' is reserved and cannot be set
fail_compilation/reserved_version.d(85): Error: version identifier 'D_SIMD' is reserved and cannot be set
fail_compilation/reserved_version.d(86): Error: version identifier 'D_Version2' is reserved and cannot be set
fail_compilation/reserved_version.d(87): Error: version identifier 'D_NoBoundsChecks' is reserved and cannot be set
fail_compilation/reserved_version.d(90): Error: version identifier 'all' is reserved and cannot be set
fail_compilation/reserved_version.d(91): Error: version identifier 'none' is reserved and cannot be set
---
*/
#line 1

version = DigitalMars;
version = GNU;
version = LDC;
version = SDC;
version = Windows;
version = Win32;
version = Win64;
version = linux;
version = OSX;
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
version = SH64;
version = Alpha;
version = Alpha_SoftFloat;
version = Alpha_HardFloat;
version = LittleEndian;
version = BigEndian;
version = ELFv1;
version = ELFv2;
version = CRuntime_Bionic;
version = CRuntime_DigitalMars;
version = CRuntime_Glibc;
version = CRuntime_Microsoft;
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
debug = SH64;
debug = Alpha;
debug = Alpha_SoftFloat;
debug = Alpha_HardFloat;
debug = LittleEndian;
debug = BigEndian;
debug = ELFv1;
debug = ELFv2;
debug = CRuntime_Bionic;
debug = CRuntime_DigitalMars;
debug = CRuntime_Glibc;
debug = CRuntime_Microsoft;
debug = D_Coverage;
debug = D_Ddoc;
debug = D_InlineAsm_X86;
debug = D_InlineAsm_X86_64;
debug = D_LP64;
debug = D_X32;
debug = D_HardFloat;
debug = D_SoftFloat;
debug = D_PIC;
debug = D_SIMD;
debug = D_Version2;
debug = D_NoBoundsChecks;
//debug = unittest;
//debug = assert;
debug = all;
debug = none;
