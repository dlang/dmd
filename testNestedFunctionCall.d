import ddmd.backend.iasm : CONSTRUCT_FLAGS, ASM_GET_uRegmask;
/+
static assert(CONSTRUCT_FLAGS(1, 0, 0, 0) == 1);
static assert(CONSTRUCT_FLAGS(2, 0, 0, 0) == 2);
static assert(CONSTRUCT_FLAGS(4, 0, 0, 0) == 4);
static assert(CONSTRUCT_FLAGS(16, 0, 0, 0) == 16);
static assert(CONSTRUCT_FLAGS(1, 1, 0, 0) == 33);
static assert(CONSTRUCT_FLAGS(2, 1, 0, 0) == 34);
static assert(CONSTRUCT_FLAGS(4, 1, 0, 0) == 36);
static assert(CONSTRUCT_FLAGS(8, 1, 0, 0) == 40);
static assert(CONSTRUCT_FLAGS(16, 1, 0, 0) == 48);
static assert(CONSTRUCT_FLAGS(31, 1, 0, 0) == 63);
static assert(CONSTRUCT_FLAGS(31, 1, 0, 0) == 63);
static assert(CONSTRUCT_FLAGS(1, 6, 0, 0) == 193);
static assert(CONSTRUCT_FLAGS(2, 6, 0, 0) == 194);
static assert(CONSTRUCT_FLAGS(4, 6, 0, 0) == 196);
static assert(CONSTRUCT_FLAGS(16, 6, 0, 0) == 208);
static assert(CONSTRUCT_FLAGS(5, 6, 0, 0) == 197);
static assert(CONSTRUCT_FLAGS(6, 6, 0, 0) == 198);
static assert(CONSTRUCT_FLAGS(21, 6, 0, 0) == 213);
static assert(CONSTRUCT_FLAGS(1, 2, 0, 0) == 65);
static assert(CONSTRUCT_FLAGS(2, 2, 0, 0) == 66);
static assert(CONSTRUCT_FLAGS(4, 2, 0, 0) == 68);
static assert(CONSTRUCT_FLAGS(16, 2, 0, 0) == 80);
static assert(CONSTRUCT_FLAGS(1, 3, 0, 0) == 97);
static assert(CONSTRUCT_FLAGS(2, 3, 0, 0) == 98);
static assert(CONSTRUCT_FLAGS(4, 3, 0, 0) == 100);
static assert(CONSTRUCT_FLAGS(4, 5, 0, 0) == 164);
static assert(CONSTRUCT_FLAGS(4, 4, 0, 0) == 132);
static assert(CONSTRUCT_FLAGS(8, 5, 0, 0) == 168);
static assert(CONSTRUCT_FLAGS(8, 4, 0, 0) == 136);
static assert(CONSTRUCT_FLAGS(0, 0, 2, 0) == 512);
static assert(CONSTRUCT_FLAGS(0, 0, 1, 0) == 256);
static assert(CONSTRUCT_FLAGS(0, 0, 3, 0) == 768);
static assert(CONSTRUCT_FLAGS(0, 0, 4, 0) == 1024);
static assert(CONSTRUCT_FLAGS(0, 0, 5, 0) == 1280);
static assert(CONSTRUCT_FLAGS(0, 0, 6, 0) == 1536);
static assert(CONSTRUCT_FLAGS(0, 0, 7, 0) == 1792);
static assert(CONSTRUCT_FLAGS(0, 1, 0, 4) == 8224);
static assert(CONSTRUCT_FLAGS(16, 1, 0, 4) == 8240);
static assert(CONSTRUCT_FLAGS(0, 1, 0, 32) == 65568);
static assert(CONSTRUCT_FLAGS(0, 0, 2, 1) == 2560);
static assert(CONSTRUCT_FLAGS(0, 0, 2, 2) == 4608);
static assert(CONSTRUCT_FLAGS(0, 0, 2, 4) == 8704);
static assert(CONSTRUCT_FLAGS(0, 0, 2, 8) == 16896);
static assert(CONSTRUCT_FLAGS(0, 0, 2, 16) == 33280);
static assert(CONSTRUCT_FLAGS(0, 0, 2, 32) == 66048);
static assert(CONSTRUCT_FLAGS(0, 0, 2, 64) == 131584);

+/
static assert(CONSTRUCT_FLAGS(2, 1, 2, ASM_GET_uRegmask(33260)) == 33314);
/+

uint CONSTRUCT_FLAGS_(uint p1, uint p2 ,uint p3, uint p4)
{
    p4 = ASM_GET_uRegmask(p4);
    return CONSTRUCT_FLAGS(p1, p2, p3, p4);
}

static assert(CONSTRUCT_FLAGS_(4, 1, 2, (33280)) == 33316);
static assert(CONSTRUCT_FLAGS_(31, 1, 2, (33280)) == 33343);
static assert(CONSTRUCT_FLAGS_(31, 1, 2, (33280)) == 33343);
static assert(CONSTRUCT_FLAGS_(31, 1, 2, (131584)) == 131647);
+/
/+
static assert(CONSTRUCT_FLAGS(0, 1, 0, 8) == 16416);
static assert(CONSTRUCT_FLAGS(0, 1, 0, 4) == 8224);
static assert(CONSTRUCT_FLAGS(0, 1, 0, 32) == 65568);
static assert(CONSTRUCT_FLAGS(31, 7, 0, 28) == 57599);
static assert(CONSTRUCT_FLAGS(0, 7, 0, 1) == 2272);
static assert(CONSTRUCT_FLAGS(0, 1, 0, 16) == 32800);
static assert(CONSTRUCT_FLAGS(0, 7, 0, 2) == 4320);
static assert(CONSTRUCT_FLAGS(0, 0, 1, 1) == 2304);
static assert(CONSTRUCT_FLAGS(0, 0, 1, 2) == 4352);
static assert(CONSTRUCT_FLAGS(0, 0, 1, 4) == 8448);
static assert(CONSTRUCT_FLAGS(0, 0, 1, 8) == 16640);
static assert(CONSTRUCT_FLAGS(0, 0, 1, 16) == 33024);
static assert(CONSTRUCT_FLAGS(0, 0, 1, 32) == 65792);
static assert(CONSTRUCT_FLAGS(0, 0, 0, 1) == 2048);
static assert(CONSTRUCT_FLAGS(0, 0, 0, 2) == 4096);
static assert(CONSTRUCT_FLAGS(0, 0, 0, 4) == 8192);
static assert(CONSTRUCT_FLAGS(0, 0, 0, 8) == 16384);
static assert(CONSTRUCT_FLAGS(0, 0, 0, 16) == 32768);
static assert(CONSTRUCT_FLAGS(0, 0, 0, 64) == 131072);
+/
