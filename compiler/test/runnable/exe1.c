/*_ exe1.c   Mon Nov 20 1989   Modified by: Walter Bright */
/* Copyright (c) 1985-1995 by Symantec                  */
/* All Rights Reserved                                  */
/* Written by Walter Bright                             */
/* Check out integer arithmetic.                        */

#include        <stdlib.h>
#include        <assert.h>
#include        <string.h>
#include        <stdio.h>

/*******************************************/

int testcppcomment()
{
#define XYZ(a,b)        a+b
        int p;

        p = XYZ(0,      /* This is OK ... */
                                 0) ;
        p = XYZ(0,      // ... but this isn't
                                 0) ;
#undef XYZ
        return 0 ;
}

/*******************************************/

void elemi()
{
        int i;

        i = 47;
        i = i && 0;
        assert(i == 0);
        i = 47;
        i = i && 1;
        assert(i == 1);
        i = 47;
        i = 0 && i;
        assert(i == 0);
        i = 47;
        i = 1 && i;
        assert(i == 1);

        i = 0;
        i = i && 0;
        assert(i == 0);
        i = i && 1;
        assert(i == 0);
        i = 0 && i;
        assert(i == 0);
        i = 1 && i;
        assert(i == 0);

        i = 47;
        i = i || 0;
        assert(i == 1);
        i = 47;
        i = i || 1;
        assert(i == 1);
        i = 47;
        i = 0 || i;
        assert(i == 1);
        i = 47;
        i = 1 || i;
        assert(i == 1);

        i = 0;
        i = i || 0;
        assert(i == 0);
        i = 0;
        i = i || 1;
        assert(i == 1);
        i = 0;
        i = 0 || i;
        assert(i == 0);
        i = 0;
        i = 1 || i;
        assert(i == 1);
        i = ((i = 1),(!(i & 5))) && (i == 6);
        assert(i == 0);
}

void elems()
{
        short i;

        i = 47;
        i = i && 0;
        assert(i == 0);
        i = 47;
        i = i && 1;
        assert(i == 1);
        i = 47;
        i = 0 && i;
        assert(i == 0);
        i = 47;
        i = 1 && i;
        assert(i == 1);

        i = 0;
        i = i && 0;
        assert(i == 0);
        i = i && 1;
        assert(i == 0);
        i = 0 && i;
        assert(i == 0);
        i = 1 && i;
        assert(i == 0);

        i = 47;
        i = i || 0;
        assert(i == 1);
        i = 47;
        i = i || 1;
        assert(i == 1);
        i = 47;
        i = 0 || i;
        assert(i == 1);
        i = 47;
        i = 1 || i;
        assert(i == 1);

        i = 0;
        i = i || 0;
        assert(i == 0);
        i = 0;
        i = i || 1;
        assert(i == 1);
        i = 0;
        i = 0 || i;
        assert(i == 0);
        i = 0;
        i = 1 || i;
        assert(i == 1);
        i = ((i = 1),(!(i & 5))) && (i == 6);
        assert(i == 0);
}

void eleml()
{       long l;

        l = 47;
        l = l && 0;
        assert(l == 0);
        l = 47;
        l = l && 1;
        assert(l == 1);
        l = 47;
        l = 0 && l;
        assert(l == 0);
        l = 47;
        l = 1 && l;
        assert(l == 1);

        l = 0;
        l = l && 0;
        assert(l == 0);
        l = l && 1;
        assert(l == 0);
        l = 0 && l;
        assert(l == 0);
        l = 1 && l;
        assert(l == 0);

        l = 47;
        l = l || 0;
        assert(l == 1);
        l = 47;
        l = l || 1;
        assert(l == 1);
        l = 47;
        l = 0 || l;
        assert(l == 1);
        l = 47;
        l = 1 || l;
        assert(l == 1);

        l = 0;
        l = l || 0;
        assert(l == 0);
        l = 0;
        l = l || 1;
        assert(l == 1);
        l = 0;
        l = 0 || l;
        assert(l == 0);
        l = 0;
        l = 1 || l;
        assert(l == 1);
        l = ((l = 1),(!(l & 5))) && (l == 6);
        assert(l == 0);
}

void elemc()
{       char c;

        c = 47;
        c = c && 0;
        assert(c == 0);
        c = 47;
        c = c && 1;
        assert(c == 1);
        c = 47;
        c = 0 && c;
        assert(c == 0);
        c = 47;
        c = 1 && c;
        assert(c == 1);

        c = 0;
        c = c && 0;
        assert(c == 0);
        c = c && 1;
        assert(c == 0);
        c = 0 && c;
        assert(c == 0);
        c = 1 && c;
        assert(c == 0);

        c = 47;
        c = c || 0;
        assert(c == 1);
        c = 47;
        c = c || 1;
        assert(c == 1);
        c = 47;
        c = 0 || c;
        assert(c == 1);
        c = 47;
        c = 1 || c;
        assert(c == 1);

        c = 0;
        c = c || 0;
        assert(c == 0);
        c = 0;
        c = c || 1;
        assert(c == 1);
        c = 0;
        c = 0 || c;
        assert(c == 0);
        c = 0;
        c = 1 || c;
        assert(c == 1);
        c = ((c = 1),(!(c & 5))) && (c == 6);
        assert(c == 0);
}

void align()            /* test alignment       */
{       static char a[3][5] = {"1234","5678","abcd"};
        char *p;
        int i;

        i = 2;
        p = a[i];
        assert(*p == 'a');
}

void bitwise()
{       int i;
        unsigned u;
        long l;
        unsigned long ul;

        i = 0x1234;
        u = i & 0xFF;
        assert(u == 0x34);
        u = i & 0xFF00;
        assert(u == 0x1200);
        u = i | 0xFF;
        assert(u == 0x12FF);
        u = i | 0xFF00;
        assert(u == 0xFF34);
        u = i ^ 0xFF;
        assert(u == (0x1234 ^ 0xFF));
        u = i ^ 0xFF00;
        assert(u == (0x1234 ^ 0xFF00));
        u = i ^ 0xFFFF;
        assert(u == (0x1234 ^ 0xFFFF));

        u = i;
        u &= 0xFF;
        assert(u == 0x34);
        u = i;
        u &= 0xFF00;
        assert(u == 0x1200);
        u = i;
        u |= 0xFF;
        assert(u == 0x12FF);
        u = i;
        u |= 0xFF00;
        assert(u == 0xFF34);
        u = i;
        u ^= 0xFF;
        assert(u == (0x1234 ^ 0xFF));
        u = i;
        u ^= 0xFF00;
        assert(u == (0x1234 ^ 0xFF00));
        u = i;
        u ^= 0xFFFF;
        assert(u == (0x1234 ^ 0xFFFF));

        l = 0x56781234;
        ul = l & 0xFF;
        assert(ul == 0x34);
        ul = l & 0xFF00;
        assert(ul == 0x1200);
        ul = l & 0xFFFF;
        assert(ul == 0x1234);
        ul = l & 0xFFFF0000;
        assert(ul == 0x56780000);
        ul = l | 0xFF;
        assert(ul == 0x567812FF);
        ul = l | 0xFF00;
        assert(ul == 0x5678FF34);
        ul = l | 0xFFFF;
        assert(ul == 0x5678FFFF);
        ul = l | 0xFFFF0000;
        assert(ul == 0xFFFF1234);
        ul = l ^ 0xFF;
        assert(ul == (0x56781234 ^ 0xFF));
        ul = l ^ 0xFF00;
        assert(ul == (0x56781234 ^ 0xFF00));
        ul = l ^ 0xFFFF;
        assert(ul == (0x56781234 ^ 0xFFFF));
        ul = l ^ 0xFFFF0000;
        assert(ul == (0x56781234 ^ 0xFFFF0000));

        ul = l;
        ul &= 0xFF;
        assert(ul == 0x34);
        ul = l;
        ul &= 0xFF00;
        assert(ul == 0x1200);
        ul = l;
        ul &= 0xFFFF;
        assert(ul == 0x1234);
        ul = l;
        ul &= 0xFFFF0000;
        assert(ul == 0x56780000);
        ul = l;
        ul |= 0xFF;
        assert(ul == 0x567812FF);
        ul = l;
        ul |= 0xFF00;
        assert(ul == 0x5678FF34);
        ul = l;
        ul |= 0xFFFF;
        assert(ul == 0x5678FFFF);
        ul = l;
        ul |= 0xFFFF0000;
        assert(ul == 0xFFFF1234);
        ul = l;
        ul ^= 0xFF;
        assert(ul == (0x56781234 ^ 0xFF));
        ul = l;
        ul ^= 0xFF00;
        assert(ul == (0x56781234 ^ 0xFF00));
        ul = l;
        ul ^= 0xFFFF;
        assert(ul == (0x56781234 ^ 0xFFFF));
        ul = l;
        ul ^= 0xFFFF0000;
        assert(ul == (0x56781234 ^ 0xFFFF0000));
}

void bitwiseshort()
{       short i;
        unsigned short u;

        i = 0x1234;
        u = i & 0xFF;
        assert(u == 0x34);
        u = i & 0xFF00;
        assert(u == 0x1200);
        u = i | 0xFF;
        assert(u == 0x12FF);
        u = i | 0xFF00;
        assert(u == 0xFF34);
        u = i ^ 0xFF;
        assert(u == (0x1234 ^ 0xFF));
        u = i ^ 0xFF00;
        assert(u == (0x1234 ^ 0xFF00));
        u = i ^ 0xFFFF;
        assert(u == (0x1234 ^ 0xFFFF));

        u = i;
        u &= 0xFF;
        assert(u == 0x34);
        u = i;
        u &= 0xFF00;
        assert(u == 0x1200);
        u = i;
        u |= 0xFF;
        assert(u == 0x12FF);
        u = i;
        u |= 0xFF00;
        assert(u == 0xFF34);
        u = i;
        u ^= 0xFF;
        assert(u == (0x1234 ^ 0xFF));
        u = i;
        u ^= 0xFF00;
        assert(u == (0x1234 ^ 0xFF00));
        u = i;
        u ^= 0xFFFF;
        assert(u == (0x1234 ^ 0xFFFF));
}

void carith()
{       int i,*p;
        unsigned char u8;
        unsigned char u8a,u8b;
        signed char i8;
        unsigned u;

        u8 = 0x87;
        if ((i = u8 & 0xFF) == 0)
            assert(0);
        assert(i == 0x87);
        i = u8 & 7;
        assert(i == 7);

        i8 = 0x87;
        if ((i = i8 & 0xFF) == 0)
            assert(0);
        assert(i == 0x87);
        i = i8 & 7;
        assert(i == 7);

        u8 = i8 = 0x80;
        i = i8 & 0x101;
        assert(i == 0x100);
        i = u8 & 0x101;
        assert(i == 0);
        i8 = 0x85;
        i = i8 & (~0x7F | 1);
        assert(i == 0xFFFFFF81);

        i *= 47;                /* set AH != 0 */
        u8 = 0x58;
        assert((u8 & 0x53) == 0x50);

        u8 = 0;
        assert(u8 >= 0);
        assert(u8 <= 0);
        if (u8 < 0 || u8 > 0)
                assert(0);
        assert(u8 == 0);
        if (u8 != 0)
                assert(0);
        u8 = 1;
        assert(u8 > 0);
        assert(u8 >= 0);
        if (u8 < 0 || u8 <= 0)
                assert(0);
        assert(u8 != 0);
        if (u8 == 0)
                assert(0);

        u8 = -1;
        assert(u8 > 0);
        assert(u8 == 255);

        i8 = -1;
        assert(i8 < 0);
        assert(i8 == -1);
        assert(i8 != u8);

        i8 = 10;
        i8 = (0 > i8/2) ? 0 : i8/2;
        assert(i8 == 5);
        i8 = 47;
        i8 %= 15;
        assert(i8 == 2);
        i8 *= 15;
        assert(i8 == 30);
        i8 += 2;
        assert(i8 == 32);
        i8 -= 7;
        assert(i8 == 25);
        i8 /= 6;
        assert(i8 == 4);
        i8 |= 3;
        assert(i8 == 7);
        i8 ^= 2;
        assert(i8 == 5);
        i8 &= 6;
        assert(i8 == 4);
        i8 <<= 3;
        assert(i8 == 32);
        i8 >>= 2;
        assert(i8 == 8);
        i8 = 17;
        i8 %= -3;
        assert(i8 == 2);
        i8 = -17;
        i8 %= -3;
        assert(i8 == -2);
        i8 = -17;
        i8 %= -3;
        assert(i8 == -2);

        i8 = 43;
        i8 = -i8;
        assert(i8 == -43);
        i8 = ~i8;
        assert(i8 == 42);
        i8 = !!i8;
        assert(i8 == 1);
        i8 = !i8;
        assert(i8 == 0);
        assert(~i8);
        i8 = ~i8;
        assert(!~i8);

        u8a = 0x81;
        u8b = 0xF0;
        i = (unsigned) u8a < (unsigned) u8b;
        assert(i == 1);

        assert(sizeof(i8 << 2L) == sizeof(int));
}

void sarith()
{       short i,*p;
        char c;
        unsigned short u;

        c = 47;
        i = 63;
        assert(c - i == -16);
        assert(c * i == 2961);
        i = 4;
        assert((c << i) == 752);
        u = 0;
        assert(u >= 0);
        assert(u <= 0);
        if (u < 0 || u > 0)
                assert(0);
        assert(u == 0);
        if (u != 0)
                assert(0);
        u = 1;
        assert(u > 0);
        assert(u >= 0);
        if (u < 0 || u <= 0)
                assert(0);
        assert(u != 0);
        if (u == 0)
                assert(0);

        i = 10;
        i = (0 > i/2) ? 0 : i/2;
        assert(i == 5);
        p = &i;
        p += 1;
        assert((unsigned char *)p - (unsigned char *)&i == sizeof(i));
        i = 47;
        i %= 15;
        assert(i == 2);
        i *= 15;
        assert(i == 30);
        i += 2;
        assert(i == 32);
        i -= 7;
        assert(i == 25);
        i /= 6;
        assert(i == 4);
        i |= 3;
        assert(i == 7);
        i ^= 2;
        assert(i == 5);
        i &= 6;
        assert(i == 4);
        i <<= 3;
        assert(i == 32);
        i >>= 2;
        assert(i == 8);
        i = 17;
        i %= -3;
        assert(i == 2);
        i = -17;
        i %= -3;
        assert(i == -2);
        i = -17;
        i %= -3;
        assert(i == -2);

        if (i == 0) strlen("");         /* break up basic blocks        */

        /* special code is generated for (int % 2)      */
        i = i % 2;
        assert(i == 0);
        i = -3;
        i = i % 2;
        assert(i == -1);
        i = 3;
        i = i % 2;
        assert(i == 1);
        i = 2;
        i = i % 2;
        assert(i == 0);

        i = 43;
        i = -i;
        assert(i == -43);
        i = ~i;
        assert(i == 42);
        i = !!i;
        assert(i == 1);
        i = !i;
        assert(i == 0);
}

void iarith()
{       int i,*p;
        char c;
        unsigned u;

        c = 47;
        i = 63;
        assert(c - i == -16);
        assert(c * i == 2961);
        i = 4;
        assert((c << i) == 752);
        u = 0;
        assert(u >= 0);
        assert(u <= 0);
        if (u < 0 || u > 0)
                assert(0);
        assert(u == 0);
        if (u != 0)
                assert(0);
        u = 1;
        assert(u > 0);
        assert(u >= 0);
        if (u < 0 || u <= 0)
                assert(0);
        assert(u != 0);
        if (u == 0)
                assert(0);

        i = 10;
        i = (0 > i/2) ? 0 : i/2;
        assert(i == 5);
        p = &i;
        p += 1;
        assert((unsigned char *)p - (unsigned char *)&i == sizeof(i));
        i = 47;
        i %= 15;
        assert(i == 2);
        i *= 15;
        assert(i == 30);
        i += 2;
        assert(i == 32);
        i -= 7;
        assert(i == 25);
        i /= 6;
        assert(i == 4);
        i |= 3;
        assert(i == 7);
        i ^= 2;
        assert(i == 5);
        i &= 6;
        assert(i == 4);
        i <<= 3;
        assert(i == 32);
        i >>= 2;
        assert(i == 8);
        i = 17;
        i %= -3;
        assert(i == 2);
        i = -17;
        i %= -3;
        assert(i == -2);
        i = -17;
        i %= -3;
        assert(i == -2);

        if (i == 0) strlen("");         /* break up basic blocks        */

        /* special code is generated for (int % 2)      */
        i = i % 2;
        assert(i == 0);
        i = -3;
        i = i % 2;
        assert(i == -1);
        i = 3;
        i = i % 2;
        assert(i == 1);
        i = 2;
        i = i % 2;
        assert(i == 0);

        i = 43;
        i = -i;
        assert(i == -43);
        i = ~i;
        assert(i == 42);
        i = !!i;
        assert(i == 1);
        i = !i;
        assert(i == 0);
}

void larith()
{       long i,b,*p;
        unsigned long u;
        int j;

        (int) i;        /* this was a bug in 1.11       */
        u = 0;
        assert(u >= 0);
        assert(u <= 0);
        if (u < 0 || u > 0)
                assert(0);
        assert(u == 0);
        if (u != 0)
                assert(0);
        u = 1;
        assert(u > 0);
        assert(u >= 0);
        if (u < 0 || u <= 0)
                assert(0);
        assert(u != 0);
        if (u == 0)
                assert(0);

        i = 10;
        i = (0 > i/2) ? 0 : i/2;
        assert(i == 5);
        p = &i;
        p += 1;
        assert((unsigned char *)p - (unsigned char *)&i == sizeof(i));
        i = 47;
        i %= 15;
        assert(i == 2);
        i *= 15;
        assert(i == 30);
        i += 2;
        assert(i == 32);
        i -= 7;
        assert(i == 25);
        i /= 6;
        assert(i == 4);
        i |= 3;
        assert(i == 7);
        i ^= 2;
        assert(i == 5);
        i &= 6;
        assert(i == 4);
        i <<= 3;
        assert(i == 32);
        i >>= 2;
        assert(i == 8);
        i = 17;
        i %= -3;
        assert(i == 2);
        i = -17;
        i %= -3;
        assert(i == -2);
        i = -17;
        i %= -3;
        assert(i == -2);
        i = 1;
        b = 2;
        i <<= 4;
        b <<= 4;
        assert(i == 0x10);
        assert(b == 0x20);

        i = 43;
        i = -i;
        assert(i == -43);
        i = ~i;
        assert(i == 42);
        i = !!i;
        assert(i == 1);
        i = !i;
        assert(i == 0);

        i = 4;
        i <<= 8;
        assert(i == 1024);
        j = 8;
        i <<= j;
        assert(i == 262144);
        i = 4;
        i = i << 7;
        assert(i == 512);
        j = 7;
        i = i << j;
        assert(i == 65536);

        i = 40000L;
        i *= 20000;
        assert(i == 800000000);

        u = 0x12348756;
        j = (u & 0x0000FF00) >> 8L;
        assert(j == 0x87);

        u = 4294967295u;
        assert(u == 0xFFFFFFFF);
}

/****************************************************/

void cdnot()
{       int a,b,c,d;
        int testbool(int,int);

        if (!strlen)
                assert(0);
        assert(strlen);
        a = 5;
        // !a && assert(0);     // gcc errors on this and the next one
        // !!a || assert(0);
        b = !a;
        assert(b == 0);
        b =  !!a;
        assert(b == 1);
        assert((b = !a) + 1 == 1);
        assert((b = !!a) == 1);
        c = 7;
        d = 8;
        a = c * d + 3;
        if ((b = !!a) != 0)
                assert(c * d + 3 == 59);
        else
                assert(0);

        testbool(-1,0);
        testbool(0,1);
        testbool(5,1);
        testbool(10,1);
        testbool(11,0);
}

#define inrange(a,x,b)   ((a <= x) && (x <= b))

void testbool(int val, int expect)
{
    int x, y;
    int dec;

    /*printf("val = %d, expect = %d\n",val,expect);*/

    /* combination */
    dec = (x = (!(y = inrange(0, val, 10))) | !(inrange(0, val, 10))) ? 0 : 1;
    /*printf("\nx = %d, y = %d, dec = %d\n", x, y, dec);*/
    assert(x == (expect^1) && y == expect && dec == expect);

    /* NOT operator and logical | */
    dec = (x = (!(y = inrange(0, val, 10))) || !(inrange(0, val, 10))) ? 0 : 1;
    /*printf("\nx = %d, y = %d, dec = %d\n", x, y, dec);*/
    assert(x == (expect^1) && y == expect && dec == expect);

    /* bitwise | -- no NOT operator */
    dec = (x = ((y = inrange(0, val, 10))) | (inrange(0, val, 10))) ? 1 : 0;
    /*printf("\nx = %d, y = %d, dec = %d\n", x, y, dec);*/
    assert(x == expect && y == expect && dec == expect);
}

/************************************************************/

int E1() { return 2; }
int E0() { return 0; }
int EN() { assert(0); }
#define e1 E1()
#define e0 E0()
#define en EN()

void testelloglog()
{
        int e;
        int x;

        /* This doesn't optimize as well as it should   */

        /* e1 || 1  => e1 , 1           */
        x = 0;
        e = e1 || (++x,1);
        assert(e == 1 && x == 0);
        e = e0 || (++x,1);
        assert(e == 1 && x == 1);

        /* e1 || 0  =>  bool e1         */
        x = 0;
        e = e1 || (++x,0);
        assert(e == 1 && x == 0);
        e = e0 || (++x,0);
        assert(e == 0 && x == 1);

        /* (x,1) || e2  =>  (x,1),1     */
        x = 0;
        e = (++x,1) || en;
        assert(e == 1 && x == 1);

        /* (x,0) || e2  =>  (x,0),(bool e2) */
        x = 0;
        e = (++x,0) || e1;
        assert(e == 1 && x == 1);
        e = (++x,0) || e0;
        assert(e == 0 && x == 2);

        /* e1 && (x,1)  =>  e1 ? ((x,1),1) : 0  */
        x = 0;
        e = e1 && (++x,5);
        assert(e == 1 && x == 1);
        e = e0 && (++x,1);
        assert(e == 0 && x == 1);

        /* e1 && (x,0)  =>  e1 , (x,0)  */
        x = 0;
        e = e1 && (++x,0);
        assert(e == 0 && x == 1);
        e = e0 && (++x,1);
        assert(e == 0 && x == 1);

        /* (x,1) && e2  =>  (x,1),bool e2 */
        x = 0;
        e = (++x,5) && e1;
        assert(e == 1 && x == 1);
        e = (++x,4) && e0;
        assert(e == 0 && x == 2);

        /* (x,0) && e2  =>  (x,0),0     */
        x = 0;
        e = (++x,0) && en;
        assert(e == 0 && x == 1);
}

#undef e1
#undef e0
#undef en

/*************************************/

void ptrarith()
{
    char *pc;
    typedef char odd[3];
    odd a[10],*p,*q;
    typedef char even[4];
    even b[10],*r,*s;
    static int cc[10] = {1,2,3,4,5,6,7,8,9,10};
    static int (*bb)[] = &cc;   /* should generate <ptr to><array> */

    pc = (char *) -1U;
    pc = (char *) -1;

    p = a + 5;
    q = a;
    assert(q - p == -5);
    assert(p - q == 5);
    r = b + 7;
    s = b;
    assert(s - r == -7);
    assert(r - s == 7);

    assert((*bb)[5] == 6);
}

/* strange results with D and P models */

char thing[] = "abcdefg";

void ptrs2a(p,n)
char *p;
int n;
{
    assert(n == 4);
    assert(p == thing);
}

void ptrs2()
{
    char *p;
    long x;

    p = thing+4;
    ptrs2a(thing,p-thing);
    x = (long) thing;
    p = thing;
    assert(x == (long) p);
}

void cdeq()
{       unsigned char c;                /* unsigned 8 bits      */
        signed char s;                  /* signed 8 bits        */
        short i;                        /* signed 16            */
        unsigned short u;               /* unsigned 16          */
        long l;
        unsigned long ul;

        c = -1;
        i = c;                  /* c should not become signed           */
        assert(i == 255);
        assert((c = (unsigned char)0x100) == 0);
        assert((c = (unsigned char)0x100) + 1 == 1);
        c = (unsigned char)0x100;
        assert(c == 0);
        assert((s = (signed char)0x200) == 0);
        s = (signed char)0x200;
        assert(s == 0);
        assert((c = (signed char)0x280) == 0x80);
        c = (unsigned char)0x280;
        assert(c == 0x80);
        assert((s = (signed char)0x280) == ~0x7F);
        s = (signed char)0x280;
        assert(s == ~0x7F);
        assert(c == 0x80);
        assert(s == ~0x7F);

        assert((u = (unsigned short)0x10000L) == 0L);
        assert((u = (unsigned short)0x10000L) + 1L == 1);
        u = (unsigned short)0x10000;
        assert(u == 0);
        assert((i = (short)0x20000) == 0L);
        i = (short)0x20000;
        assert(i == 0);
        assert((u = (unsigned short)0x28000) == 0x8000L);
        u = (unsigned short)0x28000;
        assert(u == 0x8000L);
        assert((i = (short)0x28000) == 0xFFFF8000);
        i = (short)0x28000;
        assert(i == 0xFFFF8000);
        assert(u == 0x8000);
        assert(i == (short) 0x8000);
}

void cdopeq()
{       unsigned char c;                /* unsigned 8 bits      */
        signed char s;                  /* signed 8 bits        */
        short i,*pi;                    /* signed 16            */
        unsigned short u;               /* unsigned 16          */
        long l;
        unsigned long ul;

        l = 500;
        i = (l /= 50) != 0;
        assert(l == 10 && i == 1);
        l = 0x10000;
        i = 10;
        i /= l;
        assert(i == 0);
        l += 15;
        i = 30;
        i /= l;
        assert(i == 0);
        pi = &i;
        i = 30;
        *pi++ /= 0x10000 + 15;
        assert(i == 0);
        assert(pi == &i + 1);

        s = 0x83;
        s >>= 1;
        assert(s == (0xC1 | ~0xFF));
        i = (*(unsigned char*)&s >>= 9);
        assert(s == 0);
        assert(i == s);
        c = 5;
        if (!(c >>= 1))
                assert(0);
        i = 0x8300;
        i >>= 1;
        assert(i == (0xC180 | ~0xFFFF));
        l = (i >>= (int) 17L);
        assert(i == -1);
        assert(l == i);
        u = 5;
        if (!(u >>= 1L))
                assert(0);
        u = 3;
        i = 7;
        i <<= u;
        assert(i == 56);

        {       char a[5],*p;

                l = 543647;
                strcpy(a,"wxyz");
                p = a;
                p[1] = 's';
                l /= 10;
                i = strcmp(p,"wsyz");
                assert(i == 0);
                p[0] = 'a'; p[1] = 'b'; p[2] = 'c';
                i = strcmp(p,"abcz");
                assert(i == 0);
                assert(l == 54364);
        }
}

char buffer[10] = {0,1,2,3};
char *flags = (char *)(buffer);
char fname[] = "abc.c";
char abc[] = "abc";

void cdcmp()
{       int i,level;
        unsigned short u;
        long long l;
        unsigned long long ul;
        char c,*p;

        l = 0xFFFFFFFFFFFF8002;
        u = 0x8001;
        assert(l < u);
        assert(l > (short) u);
        ul = l - 2;
        assert(ul > u);
        assert(ul < (short) u);

        i = 5;
        level = i - 4;
        c = 7;
        i = c < i;
        assert(i == 0);
        i = 1;
        if (level != 1)
                assert(0);
        for (i = strlen(fname); i;)
        {       --i;
                if (fname[i] == '.')
                        fname[i] = 0;
        }
        assert(strcmp(fname,abc) == 0);
        p = "\0\1\2\3";
        assert(memcmp(flags,p,4) == 0);
}

/***********************/

static int cdpost_f1(char *);

void cdpost()
{
    {
        long l = 10;

        for ( ; l--; )
                ;
        assert(l == -1);
    }
    {
        struct test { char *ptr; } *t,s;

        t = &s;
        t->ptr++;
        cdpost_f1(t->ptr);
    }
}

static int cdpost_f1(p)
char *p;
{
    return 0;
}

/***********************/

void question()
{
        int d,x,y;

        y = -3;
        d = atoi("-25");
        x = y > 0 ? ((d > 0) ? d : 0) : 0;
        assert(x == 0);

    {   static char array1[4] = "abcd";
        static int array2[2];
        char c;

        c = array1[array2 ? 3 : 1];
        assert(c == 'd');
        c = array1["hello" ? 1 : 3];
        assert(c == 'b');
    }
}

typedef struct BLCB { int a; int nextfree; } BLCBtype;

void scodelem()
{       BLCBtype *b;
        int putblb(int,BLCBtype *);

        /* make sure b is in another segment    */
        b = (BLCBtype *) malloc(sizeof(BLCBtype));
        b->nextfree = 5;
        putblb((unsigned char)'c',b);
        assert(b->nextfree == (5 + 1 + 0x1234));
        free(b);
}

void putblb(byt, cbptr)
int byt;
register BLCBtype *cbptr;
{
   register char *cp;

   char str[9] = "12345678";
   cp = str;
   *(cp + cbptr->nextfree++) = byt;
   cbptr->nextfree += 0x1234;
   assert(cp[5] == 'c');
}

void cdind()
{       int i;
        char c,*p;
        /* make sure pindex and abc are in different segments in D model */
        struct ABC
        {       short pnum;
                char *fptr;
                char pfname[10];
                char title[12];
        } *pindex[5];
        static struct ABC abc = {1,0,"abc","def"};

        i = 3;
        pindex[3] = &abc;
        c = *(pindex[i]->pfname);
        assert(c == 'a');
        p = pindex[i]->pfname;
        assert(p[1] == 'b');

        {       char byt;
                struct { int a; char *readblock; int nextread; } cb,*cbptr;

                cbptr = &cb;
                cb.readblock = "0123456";
                cb.nextread = 3;
                byt = *(cbptr->readblock + cbptr->nextread++);
                assert(byt == '3');
                assert(cbptr->nextread == 4);
        }

#if 0 // TODO ImportC
        {       struct ABC { char a,b,*l_text; } abc;
                static struct { int w_doto; struct ABC *w_dotp; } curw,*curwp;

                abc.l_text = "012345";
                curwp = &curw;
                curw.w_dotp = &abc;
                curw.w_doto = 2;
                c = curwp->w_dotp->l_text[curwp->w_doto]&0xFF;
                assert(c == '2');
        }
#endif
}

void logexp()
{
#define t1(a,b,c)       ((b<=a) ? ((c<b) || (a<=c)) : (c>=a))
        int x,y,z,i;
        static int cases[6][4] =
        {       1,2,3,  0,
                1,3,2,  0,
                2,1,3,  0,
                2,3,1,  1,
                3,1,2,  1,
                3,2,1,  0
        };

        for (i = 0; i < sizeof(cases)/sizeof(cases[0]); i++)
        {       if (!t1(cases[i][0],cases[i][1],cases[i][2]))
                        assert(cases[i][3] == 1);
                else
                        assert(cases[i][3] == 0);
        }
}

/*****************************
 * Test parameter passing.
 */

int arrayparam[10];
int *ptrparam;

void param()
{       void paramtest(int,int,double,double);
        int paramtest2(int *);
        char c1,c2,c3,*pc;
        int i,*pi;
        float f,*pf;
        double d,*pd;
        for (i = 0; i < 10; i++)
                arrayparam[i] = i;
        ptrparam = arrayparam;
        paramtest2(arrayparam);

        paramtest(47,10000,32,64);
        c1 = 1;
        c2 = 47;
        c3 = 48;
        i = 10000;
        f = 32;
        d = 64;
        paramtest(c2,i,f,d);
        pc = &c2;
        pi = &i;
        pf = &f;
        pd = &d;
        paramtest(*pc++,*pi++,*pf++,*pd++);
        paramtest(*--pc,*--pi,*--pf,*--pd);
}

void paramtest2(pa)
int *pa;
{       int i;

        assert(pa == ptrparam);
        assert(pa == arrayparam);
        for (i = 0; i < 10; i++)
        {       assert(pa[i] == i);
                assert(ptrparam[i] == i);
        }
}

void paramtest(c,i,f,d)
char c;
int i;
float f;
double d;
{
        assert(c == 47);
        assert(i == 10000);
#if 0 // TODO ImportC
        assert(f == 32);
        assert(d == 64);
#endif
}

/* This used to give dlc2 bugs  */
int *function (p, t)
int *p, t;
{
  return (p - (t? 0: 1));
}

/* So did this  */
void dlc2bugs()
{
    typedef struct { unsigned x; } THING;
    THING *p;
    long l;

    l /= (long) p->x;
    l = (long) p->x;
    l /= (long) (p->x + 1);
}

/* And this */
void dlc2bugs_2(w)
char *w;
{
    int i,k,t;

    t = w[i];
    k = t/10;
    w[i] = t - k*10;
}

/* And this */
void lidata_size( hFrom )
char** hFrom;
{   unsigned uSize;

    (*hFrom) += 4;
    uSize = *(*hFrom);
    (*hFrom) += 1;
}


/***** Test math in register variables *****/

void regmath()
{
        short int j,k;
        long i;

/*      time_0();*/

        for(i=0; i<4L; ++i){
                j = 240; k = 15;

/*      test byte-byte combinations     */
                j = (k * ( j/k) );
                j = (k * ( j/k) );
                j = ( k+k+k+k+ k+k+k+k+ k+k+k+k+ k+k+k+k );
                k = ( j -k-k-k-k -k-k-k-k -k-k-k-k -k-k-k);

/*      test byte_word combinations */
                j = ( k << 4); k = ( k << 4);
                j = ( k * (j / k) );
                j = ( k+k+k+k+ k+k+k+k+ k+k+k+k+ k+k+k+k );
                k = ( j -k-k-k-k -k-k-k-k -k-k-k-k -k-k-k);


/*      test word - word combinations */
                j = ( k << 4); k = ( k << 4);
                j = (k * ( j/k) );
                j = (k * ( j/k) );
                j = ( k+k+k+k+ k+k+k+k+ k+k+k+k+ k+k+k+k );
                k = ( j -k-k-k-k -k-k-k-k -k-k-k-k -k-k-k);
        }
/*      time_n();*/
        assert(j == -4096 && k == 3840);
}

void regmath_386()
{
        long long int j,k;
        long long i;

/*      time_0();*/

        for(i=0; i<4L; ++i){
                j = 240; k = 15;

/*      test byte-byte combinations     */
                j = (k * ( j/k) );
                j = (k * ( j/k) );
                j = ( k+k+k+k+ k+k+k+k+ k+k+k+k+ k+k+k+k );
                k = ( j -k-k-k-k -k-k-k-k -k-k-k-k -k-k-k);

/*      test byte_word combinations */
                j = ( k << 4); k = ( k << 4);
                j = ( k * (j / k) );
                j = ( k+k+k+k+ k+k+k+k+ k+k+k+k+ k+k+k+k );
                k = ( j -k-k-k-k -k-k-k-k -k-k-k-k -k-k-k);


/*      test word - word combinations */
                j = ( k << 4); k = ( k << 4);
                j = (k * ( j/k) );
                j = (k * ( j/k) );
                j = ( k+k+k+k+ k+k+k+k+ k+k+k+k+ k+k+k+k );
                k = ( j -k-k-k-k -k-k-k-k -k-k-k-k -k-k-k);
        }
/*      time_n();*/
        assert(j == 61440 && k == 3840);
}

/******************************
 * Test for fixed bug in getlvalue().
 */

struct {
                int start;
                int end;
                double *value;
                int fstart, fend;
                unsigned forms;
        } getls[5];

double getlfunc(c, r) int c, r;
{
        return getls[c].value[r+1-getls[c].start];
}

void getlvalue()
{
        double value[3];

        value[2] = 7.6;
        getls[3].value = value;
        getls[3].start = 16;
        assert(getlfunc(3,17) == 7.6);
}

/* Test fixups  */

extern int fix1;
int *pfix1 = &fix1;
int fix1 = 57;

extern int fix2;
int fix2 = 23;
int *pfix2 = &fix2;

extern int fix3;
int *pfix3 = &fix3;
int fix3;

void testfixups()
{
        assert(pfix1 == &fix1);
        assert(*pfix1 == 57);
        assert(pfix2 == &fix2);
        assert(*pfix2 == 23);
        assert(pfix3 == &fix3);
        assert(*pfix3 == 0);
}

/*****************************************************/
/* Compile with -o+space -ml get "ZTC bug 9542" */
int cc;

void seed_player_in_list(int *a,int *b) { }

int seed6() { return 0; }

void seed_user_interface (int **list1, int **list3)
{
  int index1, index2, index3, *index;
  int double_flag;

  double_flag = seed6 ();
  index1 = index2 = index3 = 0;
  index = &index1;
  do
  {
    if (index == &index1)
    {
      seed_player_in_list (list1 [index1],
        double_flag? list1 [index1 + 1]: 0);
    } else
    if (index == &index2)
    {
      seed_player_in_list (list3 [index3],
        double_flag? list3 [index3 + 1]: 0);
    }
  } while (cc != 27);
}

/***********************************************/

void testdiv1()
{
    static int y;
    int i;
    int rem, quo;

    y = 10;

    for (i = -10000; i < (int)0x7FFF; i++)
    {
        assert(i / 10 == i / y);
    }

    for (i = -10000; i < (int)0x7FFF; i++)
    {
        assert(i % 10 == i % y);
    }

    for (i = -10000; i < (int)0x7FFF; i++)
    {
        rem = i % 10;
        quo = i / 10;
        assert(rem == i % y);
        assert(quo == i / y);
    }

    for (i = -10000; i < (int)0x7FFF; i++)
    {
        rem = i % y;
        quo = i / y;
        assert(rem == i % 10);
        assert(quo == i / 10);
    }
}

void testdiv2()
{
    static int y;
    int i;
    int rem, quo;

    y = 8;

    for (i = -10000; i < (int)0x7FFF; i++)
    {
        assert(i / 8 == i / y);
    }

    for (i = -10000; i < (int)0x7FFF; i++)
    {
        assert(i % 8 == i % y);
    }

    for (i = -10000; i < (int)0x7FFF; i++)
    {
        rem = i % 8;
        quo = i / 8;
        assert(rem == i % y);
        assert(quo == i / y);
    }

    for (i = -10000; i < (int)0x7FFF; i++)
    {
        rem = i % y;
        quo = i / y;
        assert(rem == i % 8);
        assert(quo == i / 8);
    }
}

/***********************************************/

void test1()
{
    int res = 2;
    int vl = 0;
    double vr = 2.0;
    int i = 0;

    if( res == (vl += vr))
    {
        i |= 1;
    }
    assert(i == 1);
    vl = 0;
    if( res == (vl += 2.f))
    {
        i |= 2;
    }
    assert(i == 3);
}


void test2()
{
#if 0 // TODO ImportC
#ifdef __cplusplus
    bool res = 2;
    bool vl = 0;
#else
    _Bool res = 2;
    _Bool vl = 0;
#endif
    double vr = 2.0;

    int i = 0;

    if( res == (vl += vr))
    {
        i |= 1;
    }
    assert(i == 1);
    i = 0;
    vl = 0;
    if( res == (vl += 2.f))
    {
        i |= 2;
    }
    assert(i == 2);
#endif
}


/***********************************************/


struct HH
{
    long h;
    int mode;
};


double foohh(struct HH *h, unsigned long ul)
{
    if (!h->h)
    {
        h->mode = -1;
        return 0.0;
    }
    h->mode = 2;
    return ul;
}

/***********************************************/

void test3()
{
#if !__cplusplus
#if 0
  int res = 2;
  int vl;
  double vr = 2.0;
#elif 1
  _Bool res = 1;
  struct mixed {
    unsigned char : 5;
    unsigned char b : 3;
  } mixed;
#define vl mixed.b
  double vr = 2.0;
#else
  _Bool res = 1;
  _Bool vl;
  double vr = 2.0;
#endif

  vl = 0;
  if( res == (vl += vr) ){  }
  if( res == (vl += 2.f) ){  }
  if( res == (vl += 2.0) ){  }
  printf("vl = %d\n", vl);
#if 0 // TODO ImportC
  assert(vl == 6);
#endif
#undef vl
#endif
}


/***********************************************/

struct Foo4 { int quot; int rem; };

struct Foo4 foo4 = { .quot = 2, .rem  = -1 };
struct Foo4 bar4 = { .rem  = 3, .quot =  7 };
struct Foo4 abc4 = { .rem  = 3, .quot = 9 };
struct Foo4 def4 = { .quot = 2, 6 };

void test4()
{
    assert(foo4.quot == 2);
    assert(foo4.rem == -1);

    assert(bar4.quot == 7);
    assert(bar4.rem == 3);

    assert(abc4.quot == 9);
    assert(abc4.rem == 3);

    assert(def4.quot == 2);
    assert(def4.rem == 6);
}

/***********************************************/

union Jack5 { char c; double d; } jack = { .d = 53.42 };

int a5[100] = {1,3,5,7,9, [100-5] = 8, 6,5,2,4};
int b5[8] = {1,3,5,7,9, [3] = 8, 6,5,2,4};
int c5[8] = {1,3,5,7,9, [3] = 8, 6,5,2,};
int d5[8] = {1,3,5,7,9, [3] = 8, 6,5,2};
int e5[] = {1,3,5,7,9, [3] = 8, 6,5,2};

//struct Bar5 { int a[3], b; } w5[2] = { [0].a = {1}, [1].a[0] = 2 }; // TODO ImportC

void test5()
{
#if 0 // TODO ImportC
    int i;

    assert(jack.d == 53.42);

    assert(a5[0] == 1);
    assert(a5[1] == 3);
    assert(a5[2] == 5);
    assert(a5[3] == 7);
    assert(a5[4] == 9);

    for (i = 5; i < 95; i++)
        assert(a5[i] == 0);

    assert(a5[95] == 8);
    assert(a5[96] == 6);
    assert(a5[97] == 5);
    assert(a5[98] == 2);
    assert(a5[99] == 4);

    assert(b5[0] == 1);
    assert(b5[1] == 3);
    assert(b5[2] == 5);
    assert(b5[3] == 8);
    assert(b5[4] == 6);
    assert(b5[5] == 5);
    assert(b5[6] == 2);
    assert(b5[7] == 4);

    assert(c5[0] == 1);
    assert(c5[1] == 3);
    assert(c5[2] == 5);
    assert(c5[3] == 8);
    assert(c5[4] == 6);
    assert(c5[5] == 5);
    assert(c5[6] == 2);
    assert(c5[7] == 0);

    assert(d5[0] == 1);
    assert(d5[1] == 3);
    assert(d5[2] == 5);
    assert(d5[3] == 8);
    assert(d5[4] == 6);
    assert(d5[5] == 5);
    assert(d5[6] == 2);
    assert(d5[7] == 0);

    printf("e dim = %d\n", (int)(sizeof(e5) / sizeof(e5[0])));
    assert(sizeof(e5) / sizeof(e5[0]) == 7);
    assert(e5[0] == 1);
    assert(e5[1] == 3);
    assert(e5[2] == 5);
    assert(e5[3] == 8);
    assert(e5[4] == 6);
    assert(e5[5] == 5);
    assert(e5[6] == 2);

    assert(w5[0].a[0] == 1);
    assert(w5[1].a[0] == 2);
#endif
}

/***********************************************/

int foo6a(int a)
{
    return (a > 5) && (a < 100);
}

int foo6b(int a)
{
    return (a >= 5) && (a <= 100);
}

void test6()
{
    assert(foo6a(5) == 0);
    assert(foo6a(6) == 1);
    assert(foo6a(99) == 1);
    assert(foo6a(100) == 0);

    assert(foo6b(4) == 0);
    assert(foo6b(5) == 1);
    assert(foo6b(100) == 1);
    assert(foo6b(101) == 0);
}

/***********************************************/

int foo7(long c, long d)
{
    return ((c & 0x80000000) ^ (d & 0x80000000)) == 0;
}

void test7()
{
    int i = foo7(0x80000000, 0x7FFFFFFF);
    assert(i == 0);
    i = foo7(0x80000000, 0x8FFFFFFF);
    assert(i == 1);
}

/***********************************************/

#ifdef __cplusplus
    typedef bool bool_t;
#else
    typedef _Bool bool_t;
#endif

bool_t foo8a(signed char a) { return a % 2; }
bool_t foo8b(signed char a) { return a & 1; }
bool_t foo8c(signed char a, signed char b) { return a % b; }

bool_t foo8d(short a) { return a % 2; }
bool_t foo8e(short a) { return a & 1; }
bool_t foo8f(short a, short b) { return a % b; }

bool_t foo8g(long a) { return a % 2; }
bool_t foo8h(long a) { return a & 1; }
bool_t foo8i(long a, long b) { return a % b; }

#if __INTSIZE__ == 4
bool_t foo8j(long long a) { return a % 2; }
bool_t foo8k(long long a) { return a & 1; }
bool_t foo8l(long long a, long long b) { return a % b; }
#endif

void test8()
{
    int i;
    for (i = -5; i <= 5; i++)
    {
        printf("%d %d %d\n", foo8a(i), foo8b(i), foo8c(i,2));
        assert(foo8a(i) == foo8b(i));
        assert(foo8b(i) == foo8c(i, 2));

        assert(foo8d(i) == foo8e(i));
        assert(foo8e(i) == foo8f(i, 2));

        assert(foo8g(i) == foo8h(i));
        assert(foo8h(i) == foo8i(i, 2));

#if __INTSIZE__ == 4
        assert(foo8j(i) == foo8k(i));
        assert(foo8k(i) == foo8l(i, 2));
#endif
    }
}

/***********************************************/

unsigned long foo1(unsigned char *data)
{
    return
        ((unsigned long)data[0]<<  0) |
        ((unsigned long)data[1]<<  8) |
        ((unsigned long)data[2]<< 16) |
        ((unsigned long)data[3]<< 24);
}


unsigned long foo2(unsigned char *data)
{
    return
        ((unsigned long)data[0]<< 24) |
        ((unsigned long)data[1]<< 16) |
        ((unsigned long)data[2]<< 8 ) |
        ((unsigned long)data[3]<< 0 );
}

void test9()
{
    unsigned long x1 = 0x01234567;
    x1 = (unsigned long)foo1((unsigned char *)&x1);
    assert(x1 == 0x01234567);
    x1 = (unsigned long)foo2((unsigned char *)&x1);
    assert(x1 == 0x67452301);
}

/***********************************************/

int noreturnx() { assert(0); }
#pragma noreturn(noreturnx)

void returnx() { }

int test10a(unsigned i)
{
    assert(i < 10);
    return i < 10;
}

int test10b(unsigned i)
{
    (i < 10) && noreturnx();
    return i < 10;
}

int test10c(unsigned i)
{
    (i < 10) ? returnx() : noreturnx();
    return i < 10;
}

int test10d(unsigned i)
{
    (i < 10) ? noreturnx() : returnx();
    return i < 10;
}

void test10()
{
    int i = test10a(8);
    assert(i);
    i = test10b(10);
    assert(!i);
    i = test10c(8);
    assert(i);
    i = test10d(10);
    assert(!i);
}

/***********************************************/

int test11a(int i)
{
    return i < 3 ? noreturnx() : 1;
}

int test11b(int i)
{
    return i < 3 ? 1 : noreturnx();
}

void test11()
{
    int i = test11a(8);
    assert(i);
    i = test11b(2);
    assert(i);
}

/***********************************************/

/* No divide-by-zero constant folding errors
 * https://issues.dlang.org/show_bug.cgi?id=20906
 */

int test12()
{
    int x = 0;
    int a = x && 1 / x;
    int b = !x || 1 / x;
    int c = x ? 1 / x : 1;
    int d = !x ? 1 : 1 / x;
    return a | b | c;
}

/***********************************************/


int main()
{
        register unsigned char rc0;
        register signed char rs0;
        register int ri0;
        register long rl0;
        register unsigned char rC0;
        register unsigned int rI0;
        register unsigned long rL0,rL1;
        register float rf0;
        register double rd0;

        printf("Test file %s\n",__FILE__);
        align();
        rL0 = 4294967295UL;
        rc0 = 127;
        rL0 = rL0 / rc0++;
        assert(rL0 == 33818640L);
        testcppcomment();
        cdind();
        elemi();
        elems();
        eleml();
        elemc();
        bitwise();
        bitwiseshort();
        carith();
        sarith();
        iarith();
        larith();
        ptrarith();
        ptrs2();
        cdnot();
        testelloglog();
        cdeq();
        cdopeq();
        cdcmp();
        cdpost();
        question();
        scodelem();
        logexp();
        param();
        regmath();
        regmath_386();
        getlvalue();
        testfixups();
        testdiv2();
        test1();
        test2();
        test3();
        test4();
        test5();
        test6();
        test7();
        test8();
        test9();
        test10();
        test11();
        test12();

        printf("SUCCESS\n");
        return 0;
}
