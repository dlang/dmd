/*
 **********************************************************************
 ** md5.c                                                            **
 ** RSA Data Security, Inc. MD5 Message Digest Algorithm             **
 ** Created: 2/17/90 RLR                                             **
 ** Revised: 1/91 SRD,AJ,BSK,JT Reference C Version                  **
 **********************************************************************
 */

module dmd.backend.md5;

/*
 **********************************************************************
 ** Copyright (C) 1990, RSA Data Security, Inc. All rights reserved. **
 **                                                                  **
 ** License to copy and use this software is granted provided that   **
 ** it is identified as the "RSA Data Security, Inc. MD5 Message     **
 ** Digest Algorithm" in all material mentioning or referencing this **
 ** software or this function.                                       **
 **                                                                  **
 ** License is also granted to make and use derivative works         **
 ** provided that such works are identified as "derived from the RSA **
 ** Data Security, Inc. MD5 Message Digest Algorithm" in all         **
 ** material mentioning or referencing the derived work.             **
 **                                                                  **
 ** RSA Data Security, Inc. makes no representations concerning      **
 ** either the merchantability of this software or the suitability   **
 ** of this software for any particular purpose.  It is provided "as **
 ** is" without express or implied warranty of any kind.             **
 **                                                                  **
 ** These notices must be retained in any copies of any part of this **
 ** documentation and/or software.                                   **
 **********************************************************************
 */

/* -- include the following line if the md5.h header file is separate -- */

extern (C++):
nothrow:
@nogc:
@safe:
private:

/* typedef a 32 bit type */
alias UINT4 = uint;

/* Data structure for MD5 (Message Digest) computation */
public struct MD5_CTX {
  UINT4[2] i;                   /* number of _bits_ handled mod 2^64 */
  UINT4[4] buf;                                    /* scratch buffer */
  ubyte[64] in_;                                     /* input buffer */
  ubyte[16] digest;             /* actual digest after MD5Final call */
}


__gshared ubyte[64] PADDING = [
  0x80, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
];

/* F, G and H are basic MD5 functions: selection, majority, parity */
UINT4 F(UINT4 x, UINT4 y, UINT4 z) { return (x & y) | (~x & z); }
UINT4 G(UINT4 x, UINT4 y, UINT4 z) { return (x & z) | (y & ~z); }
UINT4 H(UINT4 x, UINT4 y, UINT4 z) { return x ^ y ^ z; }
UINT4 I(UINT4 x, UINT4 y, UINT4 z) { return y ^ (x | ~z); }

/* ROTATE_LEFT rotates x left n bits */
UINT4 ROTATE_LEFT(UINT4 x, UINT4 n) { return (x << n) | (x >> (32-n)); }

/* FF, GG, HH, and II transformations for rounds 1, 2, 3, and 4 */
/* Rotation is separate from addition to prevent recomputation */
void FF(ref UINT4 a, UINT4 b, UINT4 c, UINT4 d, UINT4 x, UINT4 s, UINT4 ac)
  {a += F (b, c, d) + x + cast(UINT4)ac;
   a = ROTATE_LEFT (a, s);
   a += b;
  }
void GG(ref UINT4 a, UINT4 b, UINT4 c, UINT4 d, UINT4 x, UINT4 s, UINT4 ac)
  {a += G (b, c, d) + x + cast(UINT4)ac;
   a = ROTATE_LEFT (a, s);
   a += b;
  }
void HH(ref UINT4 a, UINT4 b, UINT4 c, UINT4 d, UINT4 x, UINT4 s, UINT4 ac)
  {a += H (b, c, d) + x + cast(UINT4)ac;
   a = ROTATE_LEFT (a, s);
   a += b;
  }
void II(ref UINT4 a, UINT4 b, UINT4 c, UINT4 d, UINT4 x, UINT4 s, UINT4 ac)
  {a += I (b, c, d) + x + cast(UINT4)ac;
   a = ROTATE_LEFT (a, s);
   a += b;
  }

public void MD5Init (MD5_CTX *mdContext)
{
  mdContext.i[0] = mdContext.i[1] = cast(UINT4)0;

  /* Load magic initialization constants.
   */
  mdContext.buf[0] = cast(UINT4)0x67452301;
  mdContext.buf[1] = cast(UINT4)0xefcdab89;
  mdContext.buf[2] = cast(UINT4)0x98badcfe;
  mdContext.buf[3] = cast(UINT4)0x10325476;
}

@trusted
public void MD5Update (MD5_CTX *mdContext, ubyte *inBuf, uint inLen)
{
  UINT4[16] in_;
  int mdi;
  uint i, ii;

  /* compute number of bytes mod 64 */
  mdi = cast(int)((mdContext.i[0] >> 3) & 0x3F);

  /* update number of bits */
  if ((mdContext.i[0] + (cast(UINT4)inLen << 3)) < mdContext.i[0])
    mdContext.i[1]++;
  mdContext.i[0] += (cast(UINT4)inLen << 3);
  mdContext.i[1] += (cast(UINT4)inLen >> 29);

  while (inLen--) {
    /* add new character to buffer, increment mdi */
    mdContext.in_[mdi++] = *inBuf++;

    /* transform if necessary */
    if (mdi == 0x40) {
      for (i = 0, ii = 0; i < 16; i++, ii += 4)
        in_[i] = ((cast(UINT4)mdContext.in_[ii+3]) << 24) |
                 ((cast(UINT4)mdContext.in_[ii+2]) << 16) |
                 ((cast(UINT4)mdContext.in_[ii+1]) << 8) |
                  (cast(UINT4)mdContext.in_[ii]);
      Transform (&mdContext.buf[0], &in_[0]);
      mdi = 0;
    }
  }
}

@trusted
public void MD5Final (MD5_CTX *mdContext)
{
  UINT4[16] in_;
  int mdi;
  uint i, ii;
  uint padLen;

  /* save number of bits */
  in_[14] = mdContext.i[0];
  in_[15] = mdContext.i[1];

  /* compute number of bytes mod 64 */
  mdi = cast(int)((mdContext.i[0] >> 3) & 0x3F);

  /* pad out to 56 mod 64 */
  padLen = (mdi < 56) ? (56 - mdi) : (120 - mdi);
  MD5Update (mdContext, &PADDING[0], padLen);

  /* append length in bits and transform */
  for (i = 0, ii = 0; i < 14; i++, ii += 4)
    in_[i] = ((cast(UINT4)mdContext.in_[ii+3]) << 24) |
             ((cast(UINT4)mdContext.in_[ii+2]) << 16) |
             ((cast(UINT4)mdContext.in_[ii+1]) << 8) |
              (cast(UINT4)mdContext.in_[ii]);
  Transform (&mdContext.buf[0], &in_[0]);

  /* store buffer in digest */
  for (i = 0, ii = 0; i < 4; i++, ii += 4) {
    mdContext.digest[ii] = cast(ubyte)(mdContext.buf[i] & 0xFF);
    mdContext.digest[ii+1] =
      cast(ubyte)((mdContext.buf[i] >> 8) & 0xFF);
    mdContext.digest[ii+2] =
      cast(ubyte)((mdContext.buf[i] >> 16) & 0xFF);
    mdContext.digest[ii+3] =
      cast(ubyte)((mdContext.buf[i] >> 24) & 0xFF);
  }
}

/* Basic MD5 step. Transform buf based on in.
 */
@trusted
void Transform (UINT4 *buf, UINT4 *in_)
{
  UINT4 a = buf[0], b = buf[1], c = buf[2], d = buf[3];

  /* Round 1 */
  enum S11 = 7;
  enum S12 = 12;
  enum S13 = 17;
  enum S14 = 22;
  FF ( a, b, c, d, in_[ 0], S11, 3614090360U); /* 1 */
  FF ( d, a, b, c, in_[ 1], S12, 3905402710U); /* 2 */
  FF ( c, d, a, b, in_[ 2], S13,  606105819U); /* 3 */
  FF ( b, c, d, a, in_[ 3], S14, 3250441966U); /* 4 */
  FF ( a, b, c, d, in_[ 4], S11, 4118548399U); /* 5 */
  FF ( d, a, b, c, in_[ 5], S12, 1200080426U); /* 6 */
  FF ( c, d, a, b, in_[ 6], S13, 2821735955U); /* 7 */
  FF ( b, c, d, a, in_[ 7], S14, 4249261313U); /* 8 */
  FF ( a, b, c, d, in_[ 8], S11, 1770035416U); /* 9 */
  FF ( d, a, b, c, in_[ 9], S12, 2336552879U); /* 10 */
  FF ( c, d, a, b, in_[10], S13, 4294925233U); /* 11 */
  FF ( b, c, d, a, in_[11], S14, 2304563134U); /* 12 */
  FF ( a, b, c, d, in_[12], S11, 1804603682U); /* 13 */
  FF ( d, a, b, c, in_[13], S12, 4254626195U); /* 14 */
  FF ( c, d, a, b, in_[14], S13, 2792965006U); /* 15 */
  FF ( b, c, d, a, in_[15], S14, 1236535329U); /* 16 */

  /* Round 2 */
  enum S21 = 5;
  enum S22 = 9;
  enum S23 = 14;
  enum S24 = 20;
  GG ( a, b, c, d, in_[ 1], S21, 4129170786U); /* 17 */
  GG ( d, a, b, c, in_[ 6], S22, 3225465664U); /* 18 */
  GG ( c, d, a, b, in_[11], S23,  643717713U); /* 19 */
  GG ( b, c, d, a, in_[ 0], S24, 3921069994U); /* 20 */
  GG ( a, b, c, d, in_[ 5], S21, 3593408605U); /* 21 */
  GG ( d, a, b, c, in_[10], S22,   38016083U); /* 22 */
  GG ( c, d, a, b, in_[15], S23, 3634488961U); /* 23 */
  GG ( b, c, d, a, in_[ 4], S24, 3889429448U); /* 24 */
  GG ( a, b, c, d, in_[ 9], S21,  568446438U); /* 25 */
  GG ( d, a, b, c, in_[14], S22, 3275163606U); /* 26 */
  GG ( c, d, a, b, in_[ 3], S23, 4107603335U); /* 27 */
  GG ( b, c, d, a, in_[ 8], S24, 1163531501U); /* 28 */
  GG ( a, b, c, d, in_[13], S21, 2850285829U); /* 29 */
  GG ( d, a, b, c, in_[ 2], S22, 4243563512U); /* 30 */
  GG ( c, d, a, b, in_[ 7], S23, 1735328473U); /* 31 */
  GG ( b, c, d, a, in_[12], S24, 2368359562U); /* 32 */

  /* Round 3 */
  enum S31 = 4;
  enum S32 = 11;
  enum S33 = 16;
  enum S34 = 23;
  HH ( a, b, c, d, in_[ 5], S31, 4294588738U); /* 33 */
  HH ( d, a, b, c, in_[ 8], S32, 2272392833U); /* 34 */
  HH ( c, d, a, b, in_[11], S33, 1839030562U); /* 35 */
  HH ( b, c, d, a, in_[14], S34, 4259657740U); /* 36 */
  HH ( a, b, c, d, in_[ 1], S31, 2763975236U); /* 37 */
  HH ( d, a, b, c, in_[ 4], S32, 1272893353U); /* 38 */
  HH ( c, d, a, b, in_[ 7], S33, 4139469664U); /* 39 */
  HH ( b, c, d, a, in_[10], S34, 3200236656U); /* 40 */
  HH ( a, b, c, d, in_[13], S31,  681279174U); /* 41 */
  HH ( d, a, b, c, in_[ 0], S32, 3936430074U); /* 42 */
  HH ( c, d, a, b, in_[ 3], S33, 3572445317U); /* 43 */
  HH ( b, c, d, a, in_[ 6], S34,   76029189U); /* 44 */
  HH ( a, b, c, d, in_[ 9], S31, 3654602809U); /* 45 */
  HH ( d, a, b, c, in_[12], S32, 3873151461U); /* 46 */
  HH ( c, d, a, b, in_[15], S33,  530742520U); /* 47 */
  HH ( b, c, d, a, in_[ 2], S34, 3299628645U); /* 48 */

  /* Round 4 */
  enum S41 = 6;
  enum S42 = 10;
  enum S43 = 15;
  enum S44 = 21;
  II ( a, b, c, d, in_[ 0], S41, 4096336452U); /* 49 */
  II ( d, a, b, c, in_[ 7], S42, 1126891415U); /* 50 */
  II ( c, d, a, b, in_[14], S43, 2878612391U); /* 51 */
  II ( b, c, d, a, in_[ 5], S44, 4237533241U); /* 52 */
  II ( a, b, c, d, in_[12], S41, 1700485571U); /* 53 */
  II ( d, a, b, c, in_[ 3], S42, 2399980690U); /* 54 */
  II ( c, d, a, b, in_[10], S43, 4293915773U); /* 55 */
  II ( b, c, d, a, in_[ 1], S44, 2240044497U); /* 56 */
  II ( a, b, c, d, in_[ 8], S41, 1873313359U); /* 57 */
  II ( d, a, b, c, in_[15], S42, 4264355552U); /* 58 */
  II ( c, d, a, b, in_[ 6], S43, 2734768916U); /* 59 */
  II ( b, c, d, a, in_[13], S44, 1309151649U); /* 60 */
  II ( a, b, c, d, in_[ 4], S41, 4149444226U); /* 61 */
  II ( d, a, b, c, in_[11], S42, 3174756917U); /* 62 */
  II ( c, d, a, b, in_[ 2], S43,  718787259U); /* 63 */
  II ( b, c, d, a, in_[ 9], S44, 3951481745U); /* 64 */

  buf[0] += a;
  buf[1] += b;
  buf[2] += c;
  buf[3] += d;
}

/*
 **********************************************************************
 ** End of md5.c                                                     **
 ******************************* (cut) ********************************
 */

