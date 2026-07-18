/* Preprocessed C (.i) so the host C preprocessor cannot mangle C23 `'` digit separators. */

// https://github.com/dlang/dmd/issues/23225

// C23 6.4.4.2 — integer digit separators
_Static_assert(1'000'000 == 1000000, "decimal");
_Static_assert(0x1'2'3'4 == 0x1234, "hex");
_Static_assert(0XAB'CD == 0xABCD, "hex upper");
_Static_assert(0b1010'0001 == 0xa1, "binary");
_Static_assert(0B1010'0001 == 0xa1, "binary upper");
_Static_assert(0'123 == 0123, "octal");
_Static_assert(0'7 == 07, "octal single");

// C23 6.4.4.2 — binary literals (confirming 0b/0B with separators)
_Static_assert(0b11'10'11'01 == 0xED, "binary grouped");

// C23 6.4.4.3 — floating digit separators
_Static_assert(3.141'592 == 3.141592, "decimal float");
_Static_assert(1'2.3'4 == 12.34, "decimal float both sides");
_Static_assert(1.0e1'2 == 1.0e12, "decimal exponent");
_Static_assert(0x1.8p3 == 12.0, "hex float baseline");
_Static_assert(0x1.8'0p3 == 0x1.80p3, "hex float fraction");
_Static_assert(0x1'2.3'4p5 == 0x12.34p5, "hex float both sides");
