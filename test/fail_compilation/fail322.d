void main() {
    digestToString2("1234567890123456");
}

void digestToString2(ref char[16] digest)
{
    assert(digest[0] == 0xc3);
    assert(digest[15] == 0x3b);
}
