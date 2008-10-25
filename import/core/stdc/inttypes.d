/**
 * D header file for C99.
 *
 * Copyright: Public Domain
 * License:   Public Domain
 * Authors:   Sean Kelly
 * Standards: ISO/IEC 9899:1999 (E)
 */
module core.stdc.inttypes;

public import core.stdc.stddef;
public import core.stdc.stdint;

extern (C):

struct imaxdiv_t
{
    intmax_t    quot,
                rem;
}

version( VerboseC )
{
    const char* PRId8           = "hhd";
    const char* PRId16          = "hd";
    const char* PRId32          = "ld";
    const char* PRId64          = "lld";

    const char* PRIdLEAST8      = "hhd";
    const char* PRIdLEAST16     = "hd";
    const char* PRIdLEAST32     = "ld";
    const char* PRIdLEAST64     = "lld";

    const char* PRIdFAST8       = "hhd";
    const char* PRIdFAST16      = "d";
    const char* PRIdFAST32      = "ld";
    const char* PRIdFAST64      = "lld";

    const char* PRIi8           = "hhi";
    const char* PRIi16          = "hi";
    const char* PRIi32          = "li";
    const char* PRIi64          = "lli";

    const char* PRIiLEAST8      = "hhi";
    const char* PRIiLEAST16     = "hi";
    const char* PRIiLEAST32     = "li";
    const char* PRIiLEAST64     = "lli";

    const char* PRIiFAST8       = "hhi";
    const char* PRIiFAST16      = "i";
    const char* PRIiFAST32      = "li";
    const char* PRIiFAST64      = "lli";

    const char* PRIo8           = "hho";
    const char* PRIo16          = "ho";
    const char* PRIo32          = "lo";
    const char* PRIo64          = "llo";

    const char* PRIoLEAST8      = "hho";
    const char* PRIoLEAST16     = "ho";
    const char* PRIoLEAST32     = "lo";
    const char* PRIoLEAST64     = "llo";

    const char* PRIoFAST8       = "hho";
    const char* PRIoFAST16      = "o";
    const char* PRIoFAST32      = "lo";
    const char* PRIoFAST64      = "llo";

    const char* PRIu8           = "hhu";
    const char* PRIu16          = "hu";
    const char* PRIu32          = "lu";
    const char* PRIu64          = "llu";

    const char* PRIuLEAST8      = "hhu";
    const char* PRIuLEAST16     = "hu";
    const char* PRIuLEAST32     = "lu";
    const char* PRIuLEAST64     = "llu";

    const char* PRIuFAST8       = "hhu";
    const char* PRIuFAST16      = "u";
    const char* PRIuFAST32      = "lu";
    const char* PRIuFAST64      = "llu";

    const char* PRIx8           = "hhx";
    const char* PRIx16          = "hx";
    const char* PRIx32          = "lx";
    const char* PRIx64          = "llx";

    const char* PRIxLEAST8      = "hhx";
    const char* PRIxLEAST16     = "hx";
    const char* PRIxLEAST32     = "lx";
    const char* PRIxLEAST64     = "llx";

    const char* PRIxFAST8       = "hhx";
    const char* PRIxFAST16      = "x";
    const char* PRIxFAST32      = "lx";
    const char* PRIxFAST64      = "llx";

    const char* PRIX8           = "hhX";
    const char* PRIX16          = "hX";
    const char* PRIX32          = "lX";
    const char* PRIX64          = "llX";

    const char* PRIXLEAST8      = "hhX";
    const char* PRIXLEAST16     = "hX";
    const char* PRIXLEAST32     = "lX";
    const char* PRIXLEAST64     = "llX";

    const char* PRIXFAST8       = "hhX";
    const char* PRIXFAST16      = "X";
    const char* PRIXFAST32      = "lX";
    const char* PRIXFAST64      = "llX";

    const char* SCNd8           = "hhd";
    const char* SCNd16          = "hd";
    const char* SCNd32          = "ld";
    const char* SCNd64          = "lld";

    const char* SCNdLEAST8      = "hhd";
    const char* SCNdLEAST16     = "hd";
    const char* SCNdLEAST32     = "ld";
    const char* SCNdLEAST64     = "lld";

    const char* SCNdFAST8       = "hhd";
    const char* SCNdFAST16      = "d";
    const char* SCNdFAST32      = "ld";
    const char* SCNdFAST64      = "lld";

    const char* SCNi8           = "hhd";
    const char* SCNi16          = "hi";
    const char* SCNi32          = "li";
    const char* SCNi64          = "lli";

    const char* SCNiLEAST8      = "hhd";
    const char* SCNiLEAST16     = "hi";
    const char* SCNiLEAST32     = "li";
    const char* SCNiLEAST64     = "lli";

    const char* SCNiFAST8       = "hhd";
    const char* SCNiFAST16      = "i";
    const char* SCNiFAST32      = "li";
    const char* SCNiFAST64      = "lli";

    const char* SCNo8           = "hhd";
    const char* SCNo16          = "ho";
    const char* SCNo32          = "lo";
    const char* SCNo64          = "llo";

    const char* SCNoLEAST8      = "hhd";
    const char* SCNoLEAST16     = "ho";
    const char* SCNoLEAST32     = "lo";
    const char* SCNoLEAST64     = "llo";

    const char* SCNoFAST8       = "hhd";
    const char* SCNoFAST16      = "o";
    const char* SCNoFAST32      = "lo";
    const char* SCNoFAST64      = "llo";

    const char* SCNu8           = "hhd";
    const char* SCNu16          = "hu";
    const char* SCNu32          = "lu";
    const char* SCNu64          = "llu";

    const char* SCNuLEAST8      = "hhd";
    const char* SCNuLEAST16     = "hu";
    const char* SCNuLEAST32     = "lu";
    const char* SCNuLEAST64     = "llu";

    const char* SCNuFAST8       = "hhd";
    const char* SCNuFAST16      = "u";
    const char* SCNuFAST32      = "lu";
    const char* SCNuFAST64      = "llu";

    const char* SCNx8           = "hhd";
    const char* SCNx16          = "hx";
    const char* SCNx32          = "lx";
    const char* SCNx64          = "llx";

    const char* SCNxLEAST8      = "hhd";
    const char* SCNxLEAST16     = "hx";
    const char* SCNxLEAST32     = "lx";
    const char* SCNxLEAST64     = "llx";

    const char* SCNxFAST8       = "hhd";
    const char* SCNxFAST16      = "x";
    const char* SCNxFAST32      = "lx";
    const char* SCNxFAST64      = "llx";

  version( X86_64 )
  {
    const char* PRIdMAX         = PRId64;
    const char* PRIiMAX         = PRIi64;
    const char* PRIoMAX         = PRIo64;
    const char* PRIuMAX         = PRIu64;
    const char* PRIxMAX         = PRIx64;
    const char* PRIXMAX         = PRIX64;

    const char* SCNdMAX         = SCNd64;
    const char* SCNiMAX         = SCNi64;
    const char* SCNoMAX         = SCNo64;
    const char* SCNuMAX         = SCNu64;
    const char* SCNxMAX         = SCNx64;

    const char* PRIdPTR         = PRId64;
    const char* PRIiPTR         = PRIi64;
    const char* PRIoPTR         = PRIo64;
    const char* PRIuPTR         = PRIu64;
    const char* PRIxPTR         = PRIx64;
    const char* PRIXPTR         = PRIX64;

    const char* SCNdPTR         = SCNd64;
    const char* SCNiPTR         = SCNi64;
    const char* SCNoPTR         = SCNo64;
    const char* SCNuPTR         = SCNu64;
    const char* SCNxPTR         = SCNx64;
  }
  else
  {
    const char* PRIdMAX         = PRId32;
    const char* PRIiMAX         = PRIi32;
    const char* PRIoMAX         = PRIo32;
    const char* PRIuMAX         = PRIu32;
    const char* PRIxMAX         = PRIx32;
    const char* PRIXMAX         = PRIX32;

    const char* SCNdMAX         = SCNd32;
    const char* SCNiMAX         = SCNi32;
    const char* SCNoMAX         = SCNo32;
    const char* SCNuMAX         = SCNu32;
    const char* SCNxMAX         = SCNx32;

    const char* PRIdPTR         = PRId32;
    const char* PRIiPTR         = PRIi32;
    const char* PRIoPTR         = PRIo32;
    const char* PRIuPTR         = PRIu32;
    const char* PRIxPTR         = PRIx32;
    const char* PRIXPTR         = PRIX32;

    const char* SCNdPTR         = SCNd32;
    const char* SCNiPTR         = SCNi32;
    const char* SCNoPTR         = SCNo32;
    const char* SCNuPTR         = SCNu32;
    const char* SCNxPTR         = SCNx32;
  }
}

intmax_t  imaxabs(intmax_t j);
imaxdiv_t imaxdiv(intmax_t numer, intmax_t denom);
intmax_t  strtoimax(in char* nptr, char** endptr, int base);
uintmax_t strtoumax(in char* nptr, char** endptr, int base);
intmax_t  wcstoimax(in wchar_t* nptr, wchar_t** endptr, int base);
uintmax_t wcstoumax(in wchar_t* nptr, wchar_t** endptr, int base);
