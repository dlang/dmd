// https://issues.dlang.org/show_bug.cgi?id=23877

unsigned short __bswap_16 (unsigned short __bsx)
{
  return __builtin_bswap16 (__bsx);
}

unsigned __bswap_32 (unsigned __bsx)
{
  return __builtin_bswap32 (__bsx);
}

unsigned long long __bswap_64 (unsigned long long __bsx)
{
  return __builtin_bswap64 (__bsx);
}

int main()
{
    unsigned short y = 0x1234;
    unsigned short x = __bswap_16(y);
    return x - 0x3412;
}
