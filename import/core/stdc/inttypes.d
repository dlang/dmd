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
    enum char* PRId8            = "hhd";
    enum char* PRId16           = "hd";
    enum char* PRId32           = "ld";
    enum char* PRId64           = "lld";

    enum char* PRIdLEAST8       = "hhd";
    enum char* PRIdLEAST16      = "hd";
    enum char* PRIdLEAST32      = "ld";
    enum char* PRIdLEAST64      = "lld";

    enum char* PRIdFAST8        = "hhd";
    enum char* PRIdFAST16       = "d";
    enum char* PRIdFAST32       = "ld";
    enum char* PRIdFAST64       = "lld";

    enum char* PRIi8            = "hhi";
    enum char* PRIi16           = "hi";
    enum char* PRIi32           = "li";
    enum char* PRIi64           = "lli";

    enum char* PRIiLEAST8       = "hhi";
    enum char* PRIiLEAST16      = "hi";
    enum char* PRIiLEAST32      = "li";
    enum char* PRIiLEAST64      = "lli";

    enum char* PRIiFAST8        = "hhi";
    enum char* PRIiFAST16       = "i";
    enum char* PRIiFAST32       = "li";
    enum char* PRIiFAST64       = "lli";

    enum char* PRIo8            = "hho";
    enum char* PRIo16           = "ho";
    enum char* PRIo32           = "lo";
    enum char* PRIo64           = "llo";

    enum char* PRIoLEAST8       = "hho";
    enum char* PRIoLEAST16      = "ho";
    enum char* PRIoLEAST32      = "lo";
    enum char* PRIoLEAST64      = "llo";

    enum char* PRIoFAST8        = "hho";
    enum char* PRIoFAST16       = "o";
    enum char* PRIoFAST32       = "lo";
    enum char* PRIoFAST64       = "llo";

    enum char* PRIu8            = "hhu";
    enum char* PRIu16           = "hu";
    enum char* PRIu32           = "lu";
    enum char* PRIu64           = "llu";

    enum char* PRIuLEAST8       = "hhu";
    enum char* PRIuLEAST16      = "hu";
    enum char* PRIuLEAST32      = "lu";
    enum char* PRIuLEAST64      = "llu";

    enum char* PRIuFAST8        = "hhu";
    enum char* PRIuFAST16       = "u";
    enum char* PRIuFAST32       = "lu";
    enum char* PRIuFAST64       = "llu";

    enum char* PRIx8            = "hhx";
    enum char* PRIx16           = "hx";
    enum char* PRIx32           = "lx";
    enum char* PRIx64           = "llx";

    enum char* PRIxLEAST8       = "hhx";
    enum char* PRIxLEAST16      = "hx";
    enum char* PRIxLEAST32      = "lx";
    enum char* PRIxLEAST64      = "llx";

    enum char* PRIxFAST8        = "hhx";
    enum char* PRIxFAST16       = "x";
    enum char* PRIxFAST32       = "lx";
    enum char* PRIxFAST64       = "llx";

    enum char* PRIX8            = "hhX";
    enum char* PRIX16           = "hX";
    enum char* PRIX32           = "lX";
    enum char* PRIX64           = "llX";

    enum char* PRIXLEAST8       = "hhX";
    enum char* PRIXLEAST16      = "hX";
    enum char* PRIXLEAST32      = "lX";
    enum char* PRIXLEAST64      = "llX";

    enum char* PRIXFAST8        = "hhX";
    enum char* PRIXFAST16       = "X";
    enum char* PRIXFAST32       = "lX";
    enum char* PRIXFAST64       = "llX";

    enum char* SCNd8            = "hhd";
    enum char* SCNd16           = "hd";
    enum char* SCNd32           = "ld";
    enum char* SCNd64           = "lld";

    enum char* SCNdLEAST8       = "hhd";
    enum char* SCNdLEAST16      = "hd";
    enum char* SCNdLEAST32      = "ld";
    enum char* SCNdLEAST64      = "lld";

    enum char* SCNdFAST8        = "hhd";
    enum char* SCNdFAST16       = "d";
    enum char* SCNdFAST32       = "ld";
    enum char* SCNdFAST64       = "lld";

    enum char* SCNi8            = "hhd";
    enum char* SCNi16           = "hi";
    enum char* SCNi32           = "li";
    enum char* SCNi64           = "lli";

    enum char* SCNiLEAST8       = "hhd";
    enum char* SCNiLEAST16      = "hi";
    enum char* SCNiLEAST32      = "li";
    enum char* SCNiLEAST64      = "lli";

    enum char* SCNiFAST8        = "hhd";
    enum char* SCNiFAST16       = "i";
    enum char* SCNiFAST32       = "li";
    enum char* SCNiFAST64       = "lli";

    enum char* SCNo8            = "hhd";
    enum char* SCNo16           = "ho";
    enum char* SCNo32           = "lo";
    enum char* SCNo64           = "llo";

    enum char* SCNoLEAST8       = "hhd";
    enum char* SCNoLEAST16      = "ho";
    enum char* SCNoLEAST32      = "lo";
    enum char* SCNoLEAST64      = "llo";

    enum char* SCNoFAST8        = "hhd";
    enum char* SCNoFAST16       = "o";
    enum char* SCNoFAST32       = "lo";
    enum char* SCNoFAST64       = "llo";

    enum char* SCNu8            = "hhd";
    enum char* SCNu16           = "hu";
    enum char* SCNu32           = "lu";
    enum char* SCNu64           = "llu";

    enum char* SCNuLEAST8       = "hhd";
    enum char* SCNuLEAST16      = "hu";
    enum char* SCNuLEAST32      = "lu";
    enum char* SCNuLEAST64      = "llu";

    enum char* SCNuFAST8        = "hhd";
    enum char* SCNuFAST16       = "u";
    enum char* SCNuFAST32       = "lu";
    enum char* SCNuFAST64       = "llu";

    enum char* SCNx8            = "hhd";
    enum char* SCNx16           = "hx";
    enum char* SCNx32           = "lx";
    enum char* SCNx64           = "llx";

    enum char* SCNxLEAST8       = "hhd";
    enum char* SCNxLEAST16      = "hx";
    enum char* SCNxLEAST32      = "lx";
    enum char* SCNxLEAST64      = "llx";

    enum char* SCNxFAST8        = "hhd";
    enum char* SCNxFAST16       = "x";
    enum char* SCNxFAST32       = "lx";
    enum char* SCNxFAST64       = "llx";

  version( X86_64 )
  {
    enum char* PRIdMAX          = PRId64;
    enum char* PRIiMAX          = PRIi64;
    enum char* PRIoMAX          = PRIo64;
    enum char* PRIuMAX          = PRIu64;
    enum char* PRIxMAX          = PRIx64;
    enum char* PRIXMAX          = PRIX64;

    enum char* SCNdMAX          = SCNd64;
    enum char* SCNiMAX          = SCNi64;
    enum char* SCNoMAX          = SCNo64;
    enum char* SCNuMAX          = SCNu64;
    enum char* SCNxMAX          = SCNx64;

    enum char* PRIdPTR          = PRId64;
    enum char* PRIiPTR          = PRIi64;
    enum char* PRIoPTR          = PRIo64;
    enum char* PRIuPTR          = PRIu64;
    enum char* PRIxPTR          = PRIx64;
    enum char* PRIXPTR          = PRIX64;

    enum char* SCNdPTR          = SCNd64;
    enum char* SCNiPTR          = SCNi64;
    enum char* SCNoPTR          = SCNo64;
    enum char* SCNuPTR          = SCNu64;
    enum char* SCNxPTR          = SCNx64;
  }
  else
  {
    enum char* PRIdMAX          = PRId32;
    enum char* PRIiMAX          = PRIi32;
    enum char* PRIoMAX          = PRIo32;
    enum char* PRIuMAX          = PRIu32;
    enum char* PRIxMAX          = PRIx32;
    enum char* PRIXMAX          = PRIX32;

    enum char* SCNdMAX          = SCNd32;
    enum char* SCNiMAX          = SCNi32;
    enum char* SCNoMAX          = SCNo32;
    enum char* SCNuMAX          = SCNu32;
    enum char* SCNxMAX          = SCNx32;

    enum char* PRIdPTR          = PRId32;
    enum char* PRIiPTR          = PRIi32;
    enum char* PRIoPTR          = PRIo32;
    enum char* PRIuPTR          = PRIu32;
    enum char* PRIxPTR          = PRIx32;
    enum char* PRIXPTR          = PRIX32;

    enum char* SCNdPTR          = SCNd32;
    enum char* SCNiPTR          = SCNi32;
    enum char* SCNoPTR          = SCNo32;
    enum char* SCNuPTR          = SCNu32;
    enum char* SCNxPTR          = SCNx32;
  }
}

intmax_t  imaxabs(intmax_t j);
imaxdiv_t imaxdiv(intmax_t numer, intmax_t denom);
intmax_t  strtoimax(in char* nptr, char** endptr, int base);
uintmax_t strtoumax(in char* nptr, char** endptr, int base);
intmax_t  wcstoimax(in wchar_t* nptr, wchar_t** endptr, int base);
uintmax_t wcstoumax(in wchar_t* nptr, wchar_t** endptr, int base);
