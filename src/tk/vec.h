/*_ vec.h   Mon Oct 31 1994 */

#ifndef VEC_H
#define VEC_H

#if __SC__
#pragma once
#endif

typedef unsigned vec_base_t;                    /* base type of vector  */
typedef vec_base_t *vec_t;

#define vec_numbits(v)  ((v)[-1])
#define vec_dim(v)      ((v)[-2])

#define VECBITS (sizeof(vec_base_t)*8)          /* # of bits per entry  */
#define VECMASK (VECBITS - 1)                   /* mask for bit position */
#define VECSHIFT ((VECBITS == 16) ? 4 : 5)      /* # of bits in VECMASK */

void vec_init (void);
void vec_term (void);
vec_t vec_calloc (unsigned numbits);
vec_t vec_clone (vec_t v);
void vec_free (vec_t v);
vec_t vec_realloc (vec_t v , unsigned numbits);
#if _M_I86 && __INTSIZE == 4 && __SC__
void __pascal vec_setbit (unsigned b , vec_t v);
void __pascal vec_clearbit (unsigned b , vec_t v);
int  __pascal vec_testbit (unsigned b , vec_t v);
#else
void vec_setbit (unsigned b , vec_t v);
void vec_clearbit (unsigned b , vec_t v);
int  vec_testbit (unsigned b , vec_t v);
#endif
unsigned vec_index (unsigned b , vec_t vec);
void vec_andass (vec_t v1 , vec_t v2);
void vec_and (vec_t v1 , vec_t v2 , vec_t v3);
void vec_xorass (vec_t v1 , vec_t v2);
void vec_xor (vec_t v1 , vec_t v2 , vec_t v3);
void vec_orass (vec_t v1 , vec_t v2);
void vec_or (vec_t v1 , vec_t v2 , vec_t v3);
void vec_subass (vec_t v1 , vec_t v2);
void vec_sub (vec_t v1 , vec_t v2 , vec_t v3);
void vec_clear (vec_t v);
void vec_set (vec_t v);
void vec_copy (vec_t to , vec_t from);
int vec_equal (vec_t v1 , vec_t v2);
int vec_disjoint (vec_t v1 , vec_t v2);
void vec_clearextrabits (vec_t v);
void vec_print (vec_t v);
void vec_println (vec_t v);

#if _M_I86 && __INTSIZE == 4
#define vec_setclear(b,vs,vc)   {       \
        __asm   mov     EAX,b           \
        __asm   mov     ECX,vs          \
        __asm   bts     [ECX],EAX       \
        __asm   mov     ECX,vc          \
        __asm   btr     [ECX],EAX       \
        }
#else
#define vec_setclear(b,vs,vc)   (vec_setbit((b),(vs)),vec_clearbit((b),(vc)))
#endif

// Loop through all the bits that are set in vector v of size t:
#define foreach(i,t,v)  for((i)=0;((i)=vec_index((i),(v))), (i) < (t); (i)++)

#if __DMC__
// Digital Mars inlines some bit operations
#include        <bitops.h>

#define vec_setbit(b, v)        _inline_bts(v, b)
#define vec_clearbit(b, v)      _inline_btr(v, b)
#define vec_testbit(b, v)       (v && _inline_bt(v, b))
#endif

#endif /* VEC_H */

