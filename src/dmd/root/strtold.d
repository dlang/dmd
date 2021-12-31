/**
 * Provides a D implementation of the standard C function `strtold` (String to long double).
 *
 * Copyright:   Copyright (C) 1985-1998 by Symantec
 *              Copyright (C) 2000-2022 by The D Language Foundation, All Rights Reserved
 * Authors:     $(LINK2 https://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 https://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/src/dmd/backend/strtold.c, backend/strtold.c)
 */

module dmd.root.strtold;

import dmd.root.longdouble;
import core.stdc.ctype;
import core.stdc.errno;

version(CRuntime_Microsoft):
@nogc:
nothrow:

static if (false)
{
/* This is for compilers that support 80-bit floats,
 * and also makes it clearer what constants we're trying to use.
 */

static const longdouble[14]  negtab =
[
    1e-4096L, 1e-2048L, 1e-1024L, 1e-512L,
    1e-256L, 1e-128L, 1e-64L, 1e-32L, 1e-16L, 1e-8L, 1e-4L, 1e-2L, 1e-1L, 1.0L
];

static const longdouble[14]  postab =
[
    1e+4096L, 1e+2048L, 1e+1024L, 1e+512L,
    1e+256L, 1e+128L, 1e+64L, 1e+32L, 1e+16L, 1e+8L, 1e+4L, 1e+2L, 1e+1L
];
}
else
{
// Precaclulated values for the negtab/postab arrays

static const ubyte[longdouble.sizeof][14] _negtab_bytes =
[
    [ 0xDE,0x9F,0xCE,0xD2,0xC8,0x04,0xDD,0xA6,0xD8,0x0A ],
    [ 0xE4,0x2D,0x36,0x34,0x4F,0x53,0xAE,0xCE,0x6B,0x25 ],
    [ 0xBE,0xC0,0x57,0xDA,0xA5,0x82,0xA6,0xA2,0xB5,0x32 ],
    [ 0x1C,0xD2,0x23,0xDB,0x32,0xEE,0x49,0x90,0x5A,0x39 ],
    [ 0x3A,0x19,0x7A,0x63,0x25,0x43,0x31,0xC0,0xAC,0x3C ],
    [ 0xA1,0xE4,0xBC,0x64,0x7C,0x46,0xD0,0xDD,0x55,0x3E ],
    [ 0xA5,0xE9,0x39,0xA5,0x27,0xEA,0x7F,0xA8,0x2A,0x3F ],
    [ 0xBA,0x94,0x39,0x45,0xAD,0x1E,0xB1,0xCF,0x94,0x3F ],
    [ 0x5B,0xE1,0x4D,0xC4,0xBE,0x94,0x95,0xE6,0xC9,0x3F ],
    [ 0xFD,0xCE,0x61,0x84,0x11,0x77,0xCC,0xAB,0xE4,0x3F ],
    [ 0x2C,0x65,0x19,0xE2,0x58,0x17,0xB7,0xD1,0xF1,0x3F ],
    [ 0x0A,0xD7,0xA3,0x70,0x3D,0x0A,0xD7,0xA3,0xF8,0x3F ],
    [ 0xCD,0xCC,0xCC,0xCC,0xCC,0xCC,0xCC,0xCC,0xFB,0x3F ],
    [ 0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x80,0xFF,0x3F ]
];

static const ubyte[longdouble.sizeof][14] _postab_bytes =
[
    [ 0x9B,0x97,0x20,0x8A,0x02,0x52,0x60,0xC4,0x25,0x75 ],
    [ 0xE5,0x5D,0x3D,0xC5,0x5D,0x3B,0x8B,0x9E,0x92,0x5A ],
    [ 0x17,0x0C,0x75,0x81,0x86,0x75,0x76,0xC9,0x48,0x4D ],
    [ 0xC7,0x91,0x0E,0xA6,0xAE,0xA0,0x19,0xE3,0xA3,0x46 ],
    [ 0x8E,0xDE,0xF9,0x9D,0xFB,0xEB,0x7E,0xAA,0x51,0x43 ],
    [ 0xE0,0x8C,0xE9,0x80,0xC9,0x47,0xBA,0x93,0xA8,0x41 ],
    [ 0xD5,0xA6,0xCF,0xFF,0x49,0x1F,0x78,0xC2,0xD3,0x40 ],
    [ 0x9E,0xB5,0x70,0x2B,0xA8,0xAD,0xC5,0x9D,0x69,0x40 ],
    [ 0x00,0x00,0x00,0x04,0xBF,0xC9,0x1B,0x8E,0x34,0x40 ],
    [ 0x00,0x00,0x00,0x00,0x00,0x20,0xBC,0xBE,0x19,0x40 ],
    [ 0x00,0x00,0x00,0x00,0x00,0x00,0x40,0x9C,0x0C,0x40 ],
    [ 0x00,0x00,0x00,0x00,0x00,0x00,0x00,0xC8,0x05,0x40 ],
    [ 0x00,0x00,0x00,0x00,0x00,0x00,0x00,0xA0,0x02,0x40 ],
    [ 0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x80,0xFF,0x3F ]
];

auto negtab() { return cast(const longdouble *) _negtab_bytes.ptr; }
auto postab() { return cast(const longdouble *) _postab_bytes.ptr; }

}

/*************************
 * Convert string to double.
 * Terminates on first unrecognized character.
 */

longdouble_soft strtold_dm(const(char) *p, char **endp)
{
    longdouble_soft ldval;
    int  exp;
    long msdec,lsdec;
    uint msscale;
    char  dot,sign;
    int  pow;
    int  ndigits;
    const(char) *pinit = p;

    while (isspace(*p))
        p++;
    sign = 0;                       /* indicating +                 */
    switch (*p)
    {
    case '-':
        sign++;
        goto case;
    case '+':
        p++;
        break;
    default: break;
    }
    ldval = 0.0;
    dot = 0;                        /* if decimal point has been seen */
    exp = 0;
    msdec = lsdec = 0;
    msscale = 1;
    ndigits = 0;

    if (*p == '0' && (p[1] == 'x' || p[1] == 'X'))
    {
        int  guard = 0;
        int  anydigits = 0;

        p += 2;
        while (1)
        {
            int  i = *p;

            while (isxdigit(i))
            {
                anydigits = 1;
                i = isalpha(i) ? ((i & ~0x20) - ('A' - 10)) : i - '0';
                if (ndigits < 16)
                {
                    msdec = msdec * 16 + i;
                    if (msdec)
                        ndigits++;
                }
                else  if (ndigits == 16)
                {
                    while (msdec >= 0)
                    {
                        exp--;
                        msdec <<= 1;
                        i <<= 1;
                        if (i & 0x10)
                            msdec |= 1;
                    }
                    guard = i << 4;
                    ndigits++;
                    exp += 4;
                }
                else
                {
                    guard |= i;
                    exp += 4;
                }
                exp -= dot;
                i = *++p;
            }
            if (i == '.' && !dot)
            {
                p++;
                dot = 4;
            }
            else
                break;
        }

        // Round up if (guard && (sticky || odd))
        if (guard & 0x80 && (guard & 0x7F || msdec & 1))
        {
            msdec++;
            if (msdec == 0)                 // overflow
            {
                msdec = 0x8000000000000000L;
                exp++;
            }
        }

        if (anydigits == 0)         // if error (no digits seen)
            goto Lerr;
        if (*p == 'p' || *p == 'P')
        {
            char  sexp;
            int  e;

            sexp = 0;
            switch (*++p)
            {
            case '-':
                sexp++;
                goto case;
            case '+':
                p++;
                break;
            default:
                break;
            }
            ndigits = 0;
            e = 0;
            while (isdigit(*p))
            {
                if (e < 0x7FFFFFFF / 10 - 10) // prevent integer overflow
                {
                    e = e * 10 + *p - '0';
                }
                p++;
                ndigits = 1;
            }
            exp += sexp ? -e : e;
            if (!ndigits)           // if no digits in exponent
                goto Lerr;

            if (msdec)
            {
                int  e2 = 0x3FFF + 63;

                // left justify mantissa
                while (msdec >= 0)
                {
                    msdec <<= 1;
                    e2--;
                }

                // Stuff mantissa directly into long double
                union U
                {
                    longdouble_soft ld;
                    struct S
                    {
                        long mantissa;
                        ushort exp;
                    }
                    S s;
                }

                // Stuff mantissa directly into long double
                U  u;
                u.s.mantissa = msdec;
                u.s.exp = cast(short) e2;
                ldval = u.ld;

                static if (0)
                {
                    printf("msdec = x%llx, ldval = %Lg\n", msdec, ldval);
                    for (int i = 0; i < 5; i++)
                        printf("%04x ",(cast(ushort *)&ldval)[i]);
                    printf("\n");
                    printf("%llx\n",ldval);
                }

                // Exponent is power of 2, not power of 10
                ldval = ldexpl(ldval,exp);
            }
            goto L6;
        }
        else
            goto Lerr;              // exponent is required
    }
    else
    {
        while (1)
        {
            int  i = *p;

            while (isdigit(i))
            {
                ndigits = 1;        /* must have at least 1 digit   */
                if (msdec < (0x7FFFFFFFFFFFL-10)/10)
                    msdec = msdec * 10 + (i - '0');
                else  if (msscale < (0xFFFFFFFF-10)/10)
                {
                    lsdec = lsdec * 10 + (i - '0');
                    msscale *= 10;
                }
                else
                {
                    exp++;
                }
                exp -= dot;
                i = *++p;
            }
            if (i == '.' && !dot)
            {
                p++;
                dot++;
            }
            else
                break;
        }
        if (!ndigits)               // if error (no digits seen)
            goto Lerr;              // return 0.0
    }
    if (*p == 'e' || *p == 'E')
    {
        char  sexp;
        int  e;

        sexp = 0;
        switch (*++p)
        {
        case '-':
            sexp++;
            goto case;
        case '+':
            p++;
            break;
        default:
            break;
        }
        ndigits = 0;
        e = 0;
        while (isdigit(*p))
        {
            if (e < 0x7FFFFFFF / 10 - 10)   // prevent integer overflow
            {
                e = e * 10 + *p - '0';
            }
            p++;
            ndigits = 1;
        }
        exp += sexp ? -e : e;
        if (!ndigits)               // if no digits in exponent
            goto Lerr;              // return 0.0
    }

    ldval = msdec;
    if (msscale != 1)               /* if stuff was accumulated in lsdec */
        ldval = ldval * msscale + lsdec;
    if (ldval)
    {
        uint u = 0;
        pow = 4096;

        while (exp > 0)
        {
            while (exp >= pow)
            {
                ldval = ldval * postab[u];
                exp -= pow;
            }
            pow >>= 1;
            u++;
        }
        while (exp < 0)
        {
            while (exp <= -pow)
            {
                ldval = ldval * negtab[u];
                if (ldval == 0)
                    errno = ERANGE;
                exp += pow;
            }
            pow >>= 1;
            u++;
        }
        static if(0) {
            for (int i = 0; i < 5; i++)
                printf("%04x ",ldval.value[i]);
            printf("\n");
            printf("%llx\n",dval);
        }
    }
L6: // if overflow occurred
    if (ldval == longdouble_soft.infinity)
        errno = ERANGE;

L1:
    if (endp)
    {
        *endp = cast(char *) p;
    }
    return  sign ? -ldval : ldval;

Lerr:
    p = pinit;
    goto L1;
}

/************************* Test ************************************/
static if (0)
{

struct  longdouble_test
{
    ushort[5] value;
}

void  main()
{
    import core.stdc.stdio;

    longdouble_soft ld;
    longdouble_test x;
    int  i;

    errno = 0;
//  ld = strtold_dm("0x1.FFFFFFFFFFFFFFFEp16383", NULL);
    ld = strtold_dm("0x1.FFFFFFFFFFFFFFFEp-16382", null);
    x = *cast(longdouble_test *)&ld;
    for (i = 4; i >= 0; i--)
    {
        printf("%04x ", x.value[i]);
    }
    printf("\t%d\n", errno);

    ld = strtold_dm("1.0e5", null);
    x = *cast(longdouble_test *)&ld;
    for (i = 4; i >= 0; i--)
    {
        printf("%04x ", x.value[i]);
    }
    printf("\n");
}

}

/************************* Bigint ************************************/

static if (0) {

/* This program computes powers of 10 exactly.
 * Used to generate postab[].
 */

import core.stdc.stdio;
import core.stdc.string;

enum  NDIGITS = 4096;

void  times10(uint *a)
{
    int  i;

    for (i = 0; i < NDIGITS; i++)
    {
        a[i] *= 10;
        if (i)
        {
            a[i] += a[i - 1] >> 8;
            a[i - 1] &= 0xFF;
        }
    }
}

void  print(uint *a)
{
    int  i;
    int  p;
    int  j;

    for (i = NDIGITS; i; )
    {
        --i;
        if (a[i])
            break;
    }

    printf("0x%x.", a[i]);
    p = i * 8;
    i--;
    for (j = 0; j < i; j++)
        if (a[j])
            break;
    for (; i >= j; i--)
    {
        printf("%02x", a[i]);
    }
    printf("p+%d", p);
}

void  main()
{
    uint[NDIGITS] a;
    int  i;
    int  j;

    static longdouble[13] tab =
    [
        0x62.30290145104bcd64a60a9fc025254932bb0fd922271133eeae7be4a2f9151ffff868e970c234d8f51c5563f48bd2b496d868b27518ae42404964046f87cc1d213d5d0b54f74eb9281bb6c6e435fcb457200c03a5bca35f7792959da22e8d623b3e7b21e2b6100fab123cd8a1a75409f23956d4b941c759f83557de068edd2d00bcdd9d4a52ec8721ac7867f9e974996fb03d7ecd2fdc6349af06940d48741a6c2ed4684e5ab8d9c7bd7991dc03b4f63b8afd6b25ff66e42caeee333b7000a51987ec7038aec29e6ee8cac982a4ba47440496fcbe00d313d584e857fd214495bbdf373f41fd86fe49b70a5c7d2b17e0b2544f10cd4d8bfa89d0d73df29d0176cca7c234f4e6d2767113fd01c8c1a08a138c4ef80456c02d9a0ff4f1d4e3e51cb9255858325ed8d2399faddd9e9985a2df904ff6bf5c4f2ef0650ebc692c5508c2cbd6667097aced8e437b3d7fe03b2b6341a4c954108b89bc108f19ade5b533458e0dd75a53400d03119534074e89541bae9641fdd6266a3fdcbf778900fc509ba674343dd6769f3b72b882e7282566fbc6cc3f8d6b0dd9bc96119b31a96ddeff35e836b5d298f9994b8c90918e7b9a73491260806f233b7c94ab6feba2ebd6c1d9960e2d73a130d84c4a74fde9ce4724ed5bf546a03f40a8fb126ab1c32da38338eb3acc1a67778cfbe8b12acf1b23504dcd6cd995aca6a8b492ed8aa19adb95484971870239f4cea6e9cfda20c33857b32c450c3fecb534b71bd1a45b060904788f6e50fe78d6823613c8509ee3352c90ca19cfe90afb779eea37c8ab8db59a0a80627ce41d3cc425971d582dfe6d97ee63302b8e13e25feeaf19e63d326a7eb6d1c7bf2608c4cf1cc939c1307641d9b2c39497a8fcd8e0cd9e8d7c3172826ac9df13cb3d04e8d2fca26a9ff7d8b57e27ecf57bbb9373f46fee7aab86deb3f078787e2ab608b89572dac789bf627ede440b3f251f2b2322ab312bb95893d4b850be10e02d2408206e7bb8272181327ec8fa2e8a37a2d4390caea134c53c0adf9462ea75ecf9b5d0ed4d542dc19e1faf7a872e74f984d83e2dd8d92580152f18390a2b295138753d1fa8fd5d59c89f1b095edc162e2690f3cd8f62ff42923bbd87d1cde840b464a0e137d5e9a4eb8f8cde35c88baf63b71292baf1deeca19beb77fb8af6176ca776743074fa7021b97a1e0a68173c20ee69e79dadf7eb83cadbdfea5242a8329761ffe062053ccb5b92ac50b9c175a697b2b5341743c994a4503b9af26b398c6fed037d19eef4090ee8ae0725b1655fec303297cd0c2bd9cc1110c4e9968738b909454eb2a0dcfe388f15b8c898d3967a1b6dc3a5b4811a4f04f3618ac0280f4d3295a842bcfd82373a3f8ec72af2acd5071a8309cb2130504dd97d9556a1ebcad7947e0d0e30c7ae41eb659fb878f061814f6cea9c441c2d473bfe167b1a1c304e7613b22454ab9c41ff0b0905bc13176168dde6d488052f8cf8169c84cb4bf982870097012c23481161959127142e0e80cab3e6d7af6a25743dbeabcd0f237f1a016b67b2c2dfae78e341be10d6bfdf759b8ba1e81d1f4cce7c4823da7e1e7c34c0591cc245155e93b86ae5be806c0ed3f0da6146e599574efb29b172506be82913b1bb5154e05154ef084117f89a1e908efe7ae7d4724e8d2a67c001p+13600L,
        0x9.e8b3b5dc53d5de4a74d28ce329ace526a3197bbebe3034f77154ce2bcba19648b21c11eb962b1b61b93cf2ee5ca6f7e928e61d08e2d694222771e50f30278c9836230af908b40a753b7d77cd8c6be7151aab4efac5dcd83e49d6907855eeb028af623f6f7024d2c36fa9ce9d04a487fa1fb992be221ef1bd0ad5f775677ce0de08402ad3fa140eac7d56c7c9dee0bedd8a6c038f9245b2e87c348ad803ecca8f0070f8dbb57a6a445f278b3d5cf42915e818415c7f3ef82df84658ccf45cfad379433f3389a4408f43c513ef5a83fb8886fbf56d9d4bd5f860792e55ecee70beb1810d76ce39de9ec24bcf99d01953761abd9d7389c0a244de3c195355d84eeebeee6f46eadb56c6815b785ce6b7b125ac8edb0708fd8f6cae5f5715f7915b33eb417bf03c19d7917c7ba1fc6b9681428c85744695f0e866d7efc9ac375d77c1a42f40660460944545ff87a7dc62d752f7a66a57b1ab730f203c1aa9f44484d80e2e5fc5a04779c56b8a9e110c7bcbea4ca7982da4663cfe491d0dbd21feab49869733554c36685e5510c4a656654419bd438e48ff35d6c7d6ab91bac974fb1264b4f111821fa2bca416afe609c313b41e449952fbed5a151440967abbb3a8281ed6a8f16f9210c17f94e3892ee98074ff01e3cb64f32dbb6643a7a8289c8c6c54de34c101349713b44938209ce1f3861ce0fb7fedcc235552eb57a7842d71c7fd8f66912e4ad2f869c29279498719342c12866ed6f1c850dabc98342c9e51b78db2ea50d142fd8277732ed56d55a5e5a191368b8abbb6067584ee87e354ec2e472149e28dcfb27d4d3fe30968651333e001p+6800L,
        0x3.25d9d61a05d4305d9434f4a3c62d433949ae6209d4926c3f5bd2db49ef47187094c1a6970ca7e6bd2a73c5534936a8de061e8d4649f4f3235e005b80411640114a88bc491b9fc4ed520190fba035faaba6c356e38a31b5653f445975836cb0b6c975a351a28e4262ce3ce3a0b8df68368ae26a7b7e976a3310fc8f1f9031eb0f669a20288280bda5a580d98089dc1a47fe6b7595fb101a3616b6f4654b31fb6bfdf56deeecb1b896bc8fc51a16bf3fdeb3d814b505ba34c4118ad822a51abe1de3045b7a748e1042c462be695a9f9f2a07a7e89431922bbb9fc96359861c5cd134f451218b65dc60d7233e55c7231d2b9c9fce837d1e43f61f7de16cfb896634ee0ed1440ecc2cd8194c7d1e1a140ac53515c51a88991c4e871ec29f866e7c215bf55b2b722919f001p+3400L,
        0x1c.633415d4c1d238d98cab8a978a0b1f138cb07303a269974845a71d46b099bc817343afac69be5b0e9449775c1366732a93abade4b2908ee0f95f635e85a91924c3fc0695e7fc7153329c57aebfa3edac96e14f5dbc51fb2eb21a2f221e25cfea703ed321aa1da1bf28f8733b4475b579c88976c194e6574746c40513c31e1ad9b83a8a975d96976f8f9546dc77f27267fc6cf801p+1696L,
        0x5.53f75fdcefcef46eeddc80dcc7f755bc28f265f9ef17cc5573c063ff540e3c42d35a1d153624adc666b026b2716ed595d80fcf4a6e706bde50c612152f87d8d99f72bed3875b982e7c01p+848L,
        0x2.4ee91f2603a6337f19bccdb0dac404dc08d3cff5ec2374e42f0f1538fd03df99092e953e01p+424L,
        0x18.4f03e93ff9f4daa797ed6e38ed64bf6a1f01p+208L,
        0x4.ee2d6d415b85acef81p+104L,
        0x23.86f26fc1p+48L,
        0x5.f5e1p+24L,
        0x27.10p+8L,
        0x64.0p+0L,
        0xa.0p+0L,
    ];

    for (j = 1; j <= 4096; j *= 2)
    {
        printf("%4d: ", j);
        memset(a.ptr, 0, a.sizeof);
        a[0] = 1;
        for (i = 0; i < j; i++)
            times10(a.ptr);
        print(a.ptr);
        printf("L,\n");
    }

    for (i = 0; i < 13; i++)
    {
        printf("tab[%d] = %Lg\n", i, tab[i]);
    }
}

}
