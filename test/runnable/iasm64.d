// Copyright (c) 1999-2011 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// http://www.digitalmars.com

import std.c.stdio;

version (D_PIC)
{
    int main() { return 0; }
}
else version (D_InlineAsm_X86_64)
{

struct M128 { int a,b,c,d; };
struct M64 { int a,b; };

/+
__gshared byte b;
__gshared short w;
__gshared int i;
__gshared long l;
+/

/****************************************************/

void test1()
{
    int foo;
    int bar;
    static const int x = 4;

    asm
    {
	align x;		;
	mov EAX, __LOCAL_SIZE	;
	mov foo[RBP], EAX	;
    }
    assert(foo == 16); // stack must be 16 byte aligned
}

/****************************************************/

void test2()
{
    int foo;
    int bar;

    asm
    {
	even			;
	mov EAX,0		;
	inc EAX			;
	mov foo[RBP], EAX	;
    }
    assert(foo == 1);
}

/****************************************************/

void test3()
{
    int foo;
    int bar;

    asm
    {
	mov	EAX,5		;
	jmp	$ + 2		;
	dw	0xC0FF,0xC8FF	;	// inc EAX, dec EAX
	mov	foo[RBP],EAX	;
    }
    assert(foo == 4);
}

/****************************************************/

void test4()
{
    int foo;
    int bar;

    asm
    {
	xor	EAX,EAX		;
	add	EAX,5		;
	jne	L1		;
	dw	0xC0FF,0xC8FF	;	// inc EAX, dec EAX
L1:
	dw	0xC8FF		;
	mov	foo[RBP],EAX	;
    }
    assert(foo == 4);
}

/****************************************************/

void test5()
{
    int foo;
    ubyte *p;
    ushort *w;
    uint *u;
    ulong *ul;
    float *f;
    double *d;
    real *e;

    static float fs = 1.1;
    static double ds = 1.2;
    static real es = 1.3;

    asm
    {
	call	L1		;
	db	0xFF,0xC0;	;	// inc EAX
	db	"abc"		;
	ds	"def"		;
	di	"ghi"		;
	dl	0x12345678ABCDEF;
	df	1.1		;
	dd	1.2		;
	de	1.3		;
L1:
	pop	RBX		;
	mov	p[RBP],RBX	;
    }
    assert(p[0] == 0xFF);
    assert(p[1] == 0xC0);
    assert(p[2] == 'a');
    assert(p[3] == 'b');
    assert(p[4] == 'c');
    w = cast(ushort *)(p + 5);
    assert(w[0] == 'd');
    assert(w[1] == 'e');
    assert(w[2] == 'f');
    u = cast(uint *)(w + 3);
    assert(u[0] == 'g');
    assert(u[1] == 'h');
    assert(u[2] == 'i');
    ul = cast(ulong *)(u + 3);
    assert(ul[0] == 0x12345678ABCDEF);
    f = cast(float *)(ul + 1);
    assert(*f == fs);
    d = cast(double *)(f + 1);
    assert(*d == ds);
    e = cast(real *)(d + 1);
    assert(*e == es);
}

/****************************************************/

void test6()
{
    ubyte *p;
    static ubyte data[] =
    [
	0x8B, 0x01,       	// mov	EAX,[RCX]
	0x8B, 0x04, 0x19,    	// mov	EAX,[RBX][RCX]
	0x8B, 0x04, 0x4B,    	// mov	EAX,[RCX*2][RBX]
	0x8B, 0x04, 0x5A,    	// mov	EAX,[RBX*2][RDX]
	0x8B, 0x04, 0x8E,    	// mov	EAX,[RCX*4][RSI]
	0x8B, 0x04, 0xF9,    	// mov	EAX,[RDI*8][RCX]

	0x2B, 0x1C, 0x19,	// sub	EBX,[RBX][RCX]
	0x3B, 0x0C, 0x4B,	// cmp	ECX,[RCX*2][RBX]
	0x03, 0x14, 0x5A,	// add	EDX,[RBX*2][RDX]
	0x33, 0x34, 0x8E,	// xor	ESI,[RCX*4][RSI]

	0x29, 0x1C, 0x19,    	// sub	[RBX][RCX],EBX
	0x39, 0x0C, 0x4B,    	// cmp	[RCX*2][RBX],ECX
	0x01, 0x24, 0x5A,    	// add	[RBX*2][RDX],ESP
	0x31, 0x2C, 0x8E,    	// xor	[RCX*4][RSI],EBP

	0xA8, 0x03,       		// test	AL,3
	0x66, 0xA9, 0x04, 0x00,    	// test	AX,4
	0xA9, 0x05, 0x00, 0x00, 0x00, 	// test	EAX,5
	0x85, 0x3C, 0xF9,    		// test	[RDI*8][RCX],EDI
    ];
    int i;

    asm
    {
	call	L1			;

	mov	EAX,[RCX]		;
	mov	EAX,[RCX][RBX]		;
	mov	EAX,[RCX*2][RBX]	;
	mov	EAX,[RDX][RBX*2]	;
	mov	EAX,[RCX*4][RSI]	;
	mov	EAX,[RCX][RDI*8]	;

	sub	EBX,[RCX][RBX]		;
	cmp	ECX,[RCX*2][RBX]	;
	add	EDX,[RDX][RBX*2]	;
	xor	ESI,[RCX*4][RSI]	;

	sub	[RCX][RBX],EBX		;
	cmp	[RCX*2][RBX],ECX	;
	add	[RDX][RBX*2],ESP	;
	xor	[RCX*4][RSI],EBP	;

	test	AL,3			;
	test	AX,4			;
	test	EAX,5			;
	test	[RCX][RDI*8],EDI	;
L1:
	pop	RBX			;
	mov	p[RBP],RBX		;
    }
    for (i = 0; i < data.length; i++)
    {
	assert(p[i] == data[i]);
    }
}

/****************************************************/
/+
void test7()
{
    ubyte *p;
    static ubyte data[] =
    [
	0x26,0xA1,0x24,0x13,0x00,0x00,		// mov	EAX,ES:[01324h]
	0x36,0x66,0xA1,0x78,0x56,0x00,0x00, 	// mov	AX,SS:[05678h]
	0xA0,0x78,0x56,0x00,0x00, 		// mov	AL,[05678h]
	0x2E,0x8A,0x25,0x78,0x56,0x00,0x00, 	// mov	AH,CS:[05678h]
	0x64,0x8A,0x1D,0x78,0x56,0x00,0x00, 	// mov	BL,FS:[05678h]
	0x65,0x8A,0x3D,0x78,0x56,0x00,0x00, 	// mov	BH,GS:[05678h]
    ];
    int i;

    asm
    {
	call	L1			;

	mov	EAX,ES:[0x1324]		;
	mov	AX,SS:[0x5678]		;
	mov	AL,DS:[0x5678]		;
	mov	AH,CS:[0x5678]		;
	mov	BL,FS:[0x5678]		;
	mov	BH,GS:[0x5678]		;

L1:					;
	pop	RBX			;
	mov	p[RBP],RBX		;
    }
    for (i = 0; i < data.length; i++)
    {
	assert(p[i] == data[i]);
    }
}
+/
/****************************************************/

void test8()
{
    ubyte *p;
    static ubyte data[] =
    [
	0x8C,0xD0,       	// mov	AX,SS
	0x8C,0xDB,       	// mov	BX,DS
	0x8C,0xC1,       	// mov	CX,ES
	0x8C,0xCA,       	// mov	DX,CS
	0x8C,0xE6,       	// mov	SI,FS
	0x8C,0xEF,       	// mov	DI,GS
	0x8E,0xD0,       	// mov	SS,AX
	0x8E,0xDB,       	// mov	DS,BX
	0x8E,0xC1,       	// mov	ES,CX
	0x8E,0xCA,       	// mov	CS,DX
	0x8E,0xE6,       	// mov	FS,SI
	0x8E,0xEF,       	// mov	GS,DI
	0x0F,0x22,0xC0,    	// mov	CR0,EAX
	0x0F,0x22,0xD3,    	// mov	CR2,EBX
	0x0F,0x22,0xD9,    	// mov	CR3,ECX
	0x0F,0x22,0xE2,    	// mov	CR4,EDX
	0x0F,0x20,0xC0,    	// mov	EAX,CR0
	0x0F,0x20,0xD3,    	// mov	EBX,CR2
	0x0F,0x20,0xD9,    	// mov	ECX,CR3
	0x0F,0x20,0xE2,    	// mov	EDX,CR4
	0x0F,0x23,0xC0,    	// mov	DR0,EAX
	0x0F,0x23,0xCE,    	// mov	DR1,ESI
	0x0F,0x23,0xD3,    	// mov	DR2,EBX
	0x0F,0x23,0xD9,    	// mov	DR3,ECX
	0x0F,0x23,0xE2,    	// mov	DR4,EDX
	0x0F,0x23,0xEF,    	// mov	DR5,EDI
	0x0F,0x23,0xF4,    	// mov	DR6,ESP
	0x0F,0x23,0xFD,    	// mov	DR7,EBP
	0x0F,0x21,0xC4,    	// mov	ESP,DR0
	0x0F,0x21,0xCD,    	// mov	EBP,DR1
	0x0F,0x21,0xD0,    	// mov	EAX,DR2
	0x0F,0x21,0xDB,    	// mov	EBX,DR3
	0x0F,0x21,0xE1,    	// mov	ECX,DR4
	0x0F,0x21,0xEA,    	// mov	EDX,DR5
	0x0F,0x21,0xF6,    	// mov	ESI,DR6
	0x0F,0x21,0xFF,    	// mov	EDI,DR7
	0xA4,     		// movsb
	0x66,0xA5,		// movsw
	0xA5,			// movsd
    ];
    int i;

    asm
    {
	call	L1			;

	mov	AX,SS			;
	mov	BX,DS			;
	mov	CX,ES			;
	mov	DX,CS			;
	mov	SI,FS			;
	mov	DI,GS			;

	mov	SS,AX			;
	mov	DS,BX			;
	mov	ES,CX			;
	mov	CS,DX			;
	mov	FS,SI			;
	mov	GS,DI			;

	mov	CR0,EAX			;
	mov	CR2,EBX			;
	mov	CR3,ECX			;
	mov	CR4,EDX			;

	mov	EAX,CR0			;
	mov	EBX,CR2			;
	mov	ECX,CR3			;
	mov	EDX,CR4			;

	mov	DR0,EAX			;
	mov	DR1,ESI			;
	mov	DR2,EBX			;
	mov	DR3,ECX			;
	mov	DR4,EDX			;
	mov	DR5,EDI			;
	mov	DR6,ESP			;
	mov	DR7,EBP			;

	mov	ESP,DR0			;
	mov	EBP,DR1			;
	mov	EAX,DR2			;
	mov	EBX,DR3			;
	mov	ECX,DR4			;
	mov	EDX,DR5			;
	mov	ESI,DR6			;
	mov	EDI,DR7			;

	movsb				;
	movsw				;
	movsd				;
L1:					;
	pop	RBX			;
	mov	p[RBP],RBX		;
    }
    for (i = 0; i < data.length; i++)
    {
	assert(p[i] == data[i]);
    }
}

/****************************************************/

void test9()
{
    ubyte *p;
    static ubyte data[] =
    [
	0x67,0x66,0x8B,0x00,       	// mov	AX,[BX+SI]
	0x67,0x66,0x8B,0x01,       	// mov	AX,[BX+DI]
	0x67,0x66,0x8B,0x02,       	// mov	AX,[BP+SI]
	0x67,0x66,0x8B,0x03,       	// mov	AX,[BP+DI]
	0x67,0x66,0x8B,0x04,       	// mov	AX,[SI]
	0x67,0x66,0x8B,0x05,       	// mov	AX,[DI]
	0x66,0xB8,0xD2,0x04,    	// mov	AX,04D2h
	0x67,0x66,0x8B,0x07,       	// mov	AX,[BX]
	0x67,0x66,0x8B,0x40,0x01,    	// mov	AX,1[BX+SI]
	0x67,0x66,0x8B,0x41,0x02,    	// mov	AX,2[BX+DI]
	0x67,0x66,0x8B,0x42,0x03,    	// mov	AX,3[BP+SI]
	0x67,0x66,0x8B,0x43,0x04,    	// mov	AX,4[BP+DI]
	0x67,0x66,0x8B,0x44,0x05,    	// mov	AX,5[SI]
	0x67,0x66,0x8B,0x45,0x06,    	// mov	AX,6[DI]
	0x67,0x66,0x8B,0x43,0x07,    	// mov	AX,7[BP+DI]
	0x67,0x66,0x8B,0x47,0x08,    	// mov	AX,8[BX]
	0x67,0x8B,0x80,0x21,0x01, 	// mov	EAX,0121h[BX+SI]
	0x67,0x66,0x8B,0x81,0x22,0x01, 	// mov	AX,0122h[BX+DI]
	0x67,0x66,0x8B,0x82,0x43,0x23, 	// mov	AX,02343h[BP+SI]
	0x67,0x66,0x8B,0x83,0x54,0x45, 	// mov	AX,04554h[BP+DI]
	0x67,0x66,0x8B,0x84,0x45,0x66,	// mov	AX,06645h[SI]
	0x67,0x66,0x8B,0x85,0x36,0x12, 	// mov	AX,01236h[DI]
	0x67,0x66,0x8B,0x86,0x67,0x45, 	// mov	AX,04567h[BP]
	0x67,0x8A,0x87,0x08,0x01, 	// mov	AL,0108h[BX]
    ];
    int i;

    asm
    {
	call	L1			;

	mov	AX,[BX+SI]		;
	mov	AX,[BX+DI]		;
	mov	AX,[BP+SI]		;
	mov	AX,[BP+DI]		;
	mov	AX,[SI]			;
//	mov	AX,[DI]			; Internal error: backend/cod3.c 4652
	mov	AX,[1234]		;
	mov	AX,[BX]			;

	mov	AX,1[BX+SI]		;
	mov	AX,2[BX+DI]		;
	mov	AX,3[BP+SI]		;
	mov	AX,4[BP+DI]		;
	mov	AX,5[SI]		;
	mov	AX,6[DI]		;
	mov	AX,7[DI+BP]		;
	mov	AX,8[BX]		;

	mov	EAX,0x121[BX+SI]	;
	mov	AX,0x122[BX+DI]		;
	mov	AX,0x2343[BP+SI]	;
	mov	AX,0x4554[BP+DI]	;
	mov	AX,0x6645[SI]		;
	mov	AX,0x1236[DI]		;
	mov	AX,0x4567[BP]		;
	mov	AL,0x108[BX]		;

L1:					;
	pop	RBX			;
	mov	p[RBP],RBX		;
    }
    for (i = 0; i < data.length; i++)
    {
	assert(p[i] == data[i]);
    }
}

/****************************************************/

shared int bar10 = 78;
shared int baz10[2];

void test10()
{
    ubyte *p;
    int foo;
    static ubyte data[] =
    [
    ];
    int i;

    asm
    {
	mov	bar10,0x12		;
//	mov	baz10,0x13		;// does not compile, ( should it? )
	mov	int ptr baz10,0x13	;// but this does
	mov	ESI,1			;
	mov	baz10[RSI*4],0x14	;
    }
    assert(bar10 == 0x12);
    assert(baz10[0] == 0x13);
    assert(baz10[1] == 0x14);
}

/****************************************************/

struct Foo11
{
    int c;
    int a;
    int b;
}

void test11()
{
    ubyte *p;
    int x1;
    int x2;
    int x3;
    int x4;

    asm
    {
	mov	x1,Foo11.a.sizeof	;
	mov	x2,Foo11.b.offsetof	;
	mov	x3,Foo11.sizeof		;
	mov	x4,Foo11.sizeof + 7	;
    }
    assert(x1 == int.sizeof);
    assert(x2 == 8);
    assert(x3 == 12);
    assert(x4 == 19);
}

/****************************************************/

void test12()
{
    ubyte *p;
    static ubyte data[] =
    [
	0x14,0x05,      		// adc	AL,5
	0x83,0xD0,0x14,   		// adc	EAX,014h
	0x80,0x55,0xF8,0x17,		// adc	byte ptr -8[RBP],017h
	0x83,0x55,0xFC,0x17,		// adc	dword ptr -4[RBP],017h
	0x81,0x55,0xFC,0x34,0x12,0x00,0x00,	// adc	dword ptr -4[RBP],01234h
	0x10,0x7D,0xF8,   		// adc	-8[RBP],BH
	0x11,0x5D,0xFC,   		// adc	-4[RBP],EBX
	0x12,0x5D,0xF8,   		// adc	BL,-8[RBP]
	0x13,0x55,0xFC,   		// adc	EDX,-4[RBP]
	0x04,0x05,      		// add	AL,5
	0x83,0xC0,0x14,   		// add	EAX,014h
	0x80,0x45,0xF8,0x17,		// add	byte ptr -8[RBP],017h
	0x83,0x45,0xFC,0x17,		// add	dword ptr -4[RBP],017h
	0x81,0x45,0xFC,0x34,0x12,0x00,0x00,	// add	dword ptr -4[RBP],01234h
	0x00,0x7D,0xF8,   		// add	-8[RBP],BH
	0x01,0x5D,0xFC,   		// add	-4[RBP],EBX
	0x02,0x5D,0xF8,   		// add	BL,-8[RBP]
	0x03,0x55,0xFC,   		// add	EDX,-4[RBP]
	0x24,0x05,      		// and	AL,5
	0x83,0xE0,0x14,   		// and	EAX,014h
	0x80,0x65,0xF8,0x17,		// and	byte ptr -8[RBP],017h
	0x83,0x65,0xFC,0x17,		// and	dword ptr -4[RBP],017h
	0x81,0x65,0xFC,0x34,0x12,0x00,0x00,	// and	dword ptr -4[RBP],01234h
	0x20,0x7D,0xF8,   		// and	-8[RBP],BH
	0x21,0x5D,0xFC,   		// and	-4[RBP],EBX
	0x22,0x5D,0xF8,   		// and	BL,-8[RBP]
	0x23,0x55,0xFC,   		// and	EDX,-4[RBP]
	0x3C,0x05,      		// cmp	AL,5
	0x83,0xF8,0x14,   		// cmp	EAX,014h
	0x80,0x7D,0xF8,0x17,		// cmp	byte ptr -8[RBP],017h
	0x83,0x7D,0xFC,0x17,		// cmp	dword ptr -4[RBP],017h
	0x81,0x7D,0xFC,0x34,0x12,0x00,0x00,	// cmp	dword ptr -4[RBP],01234h
	0x38,0x7D,0xF8,   		// cmp	-8[RBP],BH
	0x39,0x5D,0xFC,   		// cmp	-4[RBP],EBX
	0x3A,0x5D,0xF8,   		// cmp	BL,-8[RBP]
	0x3B,0x55,0xFC,   		// cmp	EDX,-4[RBP]
	0x0C,0x05,     			// or	AL,5
	0x83,0xC8,0x14,			// or	EAX,014h
	0x80,0x4D,0xF8,0x17,		// or	byte ptr -8[RBP],017h
	0x83,0x4D,0xFC,0x17,		// or	dword ptr -4[RBP],017h
	0x81,0x4D,0xFC,0x34,0x12,0x00,0x00,	// or	dword ptr -4[RBP],01234h
	0x08,0x7D,0xF8,   		// or	-8[RBP],BH
	0x09,0x5D,0xFC,   		// or	-4[RBP],EBX
	0x0A,0x5D,0xF8,   		// or	BL,-8[RBP]
	0x0B,0x55,0xFC,   		// or	EDX,-4[RBP]
	0x1C,0x05,      		// sbb	AL,5
	0x83,0xD8,0x14,   		// sbb	EAX,014h
	0x80,0x5D,0xF8,0x17,		// sbb	byte ptr -8[RBP],017h
	0x83,0x5D,0xFC,0x17,		// sbb	dword ptr -4[RBP],017h
	0x81,0x5D,0xFC,0x34,0x12,0x00,0x00,	// sbb	dword ptr -4[RBP],01234h
	0x18,0x7D,0xF8,   		// sbb	-8[RBP],BH
	0x19,0x5D,0xFC,   		// sbb	-4[RBP],EBX
	0x1A,0x5D,0xF8,   		// sbb	BL,-8[RBP]
	0x1B,0x55,0xFC,   		// sbb	EDX,-4[RBP]
	0x2C,0x05,      		// sub	AL,5
	0x83,0xE8,0x14,   		// sub	EAX,014h
	0x80,0x6D,0xF8,0x17,		// sub	byte ptr -8[RBP],017h
	0x83,0x6D,0xFC,0x17,		// sub	dword ptr -4[RBP],017h
	0x81,0x6D,0xFC,0x34,0x12,0x00,0x00,	// sub	dword ptr -4[RBP],01234h
	0x28,0x7D,0xF8,   		// sub	-8[RBP],BH
	0x29,0x5D,0xFC,   		// sub	-4[RBP],EBX
	0x2A,0x5D,0xF8,   		// sub	BL,-8[RBP]
	0x2B,0x55,0xFC,   		// sub	EDX,-4[RBP]
	0xA8,0x05,      		// test	AL,5
	0xA9,0x14,0x00,0x00,0x00,	// test	EAX,014h
	0xF6,0x45,0xF8,0x17,		// test	byte ptr -8[RBP],017h
	0xF7,0x45,0xFC,0x17,0x00,0x00,0x00,	// test	dword ptr -4[RBP],017h
	0xF7,0x45,0xFC,0x34,0x12,0x00,0x00,	// test	dword ptr -4[RBP],01234h
	0x84,0x7D,0xF8,   		// test	-8[RBP],BH
	0x85,0x5D,0xFC,   		// test	-4[RBP],EBX
	0x34,0x05,      		// xor	AL,5
	0x83,0xF0,0x14,   		// xor	EAX,014h
	0x80,0x75,0xF8,0x17,		// xor	byte ptr -8[RBP],017h
	0x83,0x75,0xFC,0x17,		// xor	dword ptr -4[RBP],017h
	0x81,0x75,0xFC,0x34,0x12,0x00,0x00,	// xor	dword ptr -4[RBP],01234h
	0x30,0x7D,0xF8,   		// xor	-8[RBP],BH
	0x31,0x5D,0xFC,   		// xor	-4[RBP],EBX
	0x32,0x5D,0xF8,   		// xor	BL,-8[RBP]
	0x33,0x55,0xFC,   		// xor	EDX,-4[RBP]
    ];
    int i;
    int padding;
    byte rm8;
    int rm32;
    static int m32;

    asm
    {
	call	L1			;
	/*
	aaa				;
	aad				;
	aam				;
	aas				;
	arpl	[SI],DI			;
	*/

	adc	AL,5			;
	adc	EAX,20			;
	adc	rm8[RBP],23		;
	adc	rm32[RBP],23		;
	adc	rm32[RBP],0x1234	;
	adc	rm8[RBP],BH		;
	adc	rm32[RBP],EBX		;
	adc	BL,rm8[RBP]		;
	adc	EDX,rm32[RBP]		;

	add	AL,5			;
	add	EAX,20			;
	add	rm8[RBP],23		;
	add	rm32[RBP],23		;
	add	rm32[RBP],0x1234	;
	add	rm8[RBP],BH		;
	add	rm32[RBP],EBX		;
	add	BL,rm8[RBP]		;
	add	EDX,rm32[RBP]		;

	and	AL,5			;
	and	EAX,20			;
	and	rm8[RBP],23		;
	and	rm32[RBP],23		;
	and	rm32[RBP],0x1234	;
	and	rm8[RBP],BH		;
	and	rm32[RBP],EBX		;
	and	BL,rm8[RBP]		;
	and	EDX,rm32[RBP]		;

	cmp	AL,5			;
	cmp	EAX,20			;
	cmp	rm8[RBP],23		;
	cmp	rm32[RBP],23		;
	cmp	rm32[RBP],0x1234	;
	cmp	rm8[RBP],BH		;
	cmp	rm32[RBP],EBX		;
	cmp	BL,rm8[RBP]		;
	cmp	EDX,rm32[RBP]		;

	or	AL,5			;
	or	EAX,20			;
	or	rm8[RBP],23		;
	or	rm32[RBP],23		;
	or	rm32[RBP],0x1234	;
	or	rm8[RBP],BH		;
	or	rm32[RBP],EBX		;
	or	BL,rm8[RBP]		;
	or	EDX,rm32[RBP]		;

	sbb	AL,5			;
	sbb	EAX,20			;
	sbb	rm8[RBP],23		;
	sbb	rm32[RBP],23		;
	sbb	rm32[RBP],0x1234	;
	sbb	rm8[RBP],BH		;
	sbb	rm32[RBP],EBX		;
	sbb	BL,rm8[RBP]		;
	sbb	EDX,rm32[RBP]		;

	sub	AL,5			;
	sub	EAX,20			;
	sub	rm8[RBP],23		;
	sub	rm32[RBP],23		;
	sub	rm32[RBP],0x1234	;
	sub	rm8[RBP],BH		;
	sub	rm32[RBP],EBX		;
	sub	BL,rm8[RBP]		;
	sub	EDX,rm32[RBP]		;

	test	AL,5			;
	test	EAX,20			;
	test	rm8[RBP],23		;
	test	rm32[RBP],23		;
	test	rm32[RBP],0x1234	;
	test	rm8[RBP],BH		;
	test	rm32[RBP],EBX		;

	xor	AL,5			;
	xor	EAX,20			;
	xor	rm8[RBP],23		;
	xor	rm32[RBP],23		;
	xor	rm32[RBP],0x1234	;
	xor	rm8[RBP],BH		;
	xor	rm32[RBP],EBX		;
	xor	BL,rm8[RBP]		;
	xor	EDX,rm32[RBP]		;
L1:					;
	pop	RBX			;
	mov	p[RBP],RBX		;
    }
    for (i = 0; i < data.length; i++)
    {
	//printf("p[%d] = x%02x, data = x%02x\n", i, p[i], data[i]);
	assert(p[i] == data[i]);
    }
}

/****************************************************/

void test13()
{
    int m32;
    long m64;
    M128 m128;
    ubyte *p;
    static ubyte data[] =
    [
	0x0F,0x0B,			// ud2
	0x0F,0x05,			// syscall
	0x0F,0x34,			// sysenter
	0x0F,0x35,			// sysexit
	0x0F,0x07,			// sysret
	0x0F,0xAE,0xE8,			// lfence
	0x0F,0xAE,0xF0,			// mfence
	0x0F,0xAE,0xF8,			// sfence
	0x0F,0xAE,0x00,			// fxsave	[RAX]
	0x0F,0xAE,0x08,			// fxrstor	[RAX]
	0x0F,0xAE,0x10,			// ldmxcsr	[RAX]
	0x0F,0xAE,0x18,			// stmxcsr	[RAX]
	0x0F,0xAE,0x38,			// clflush	[RAX]

	0x0F,0x58,0x08,			// addps	XMM1,[RAX]
	0x0F,0x58,0xCA,			// addps	XMM1,XMM2
0x66,	0x0F,0x58,0x03,			// addpd	XMM0,[RBX]
0x66,	0x0F,0x58,0xD1,			// addpd	XMM2,XMM1
	0xF2,0x0F,0x58,0x08,		// addsd	XMM1,[RAX]
	0xF2,0x0F,0x58,0xCA,		// addsd	XMM1,XMM2
	0xF3,0x0F,0x58,0x2E,		// addss	XMM5,[RSI]
	0xF3,0x0F,0x58,0xF7,		// addss	XMM6,XMM7
	0x0F,0x54,0x08,			// andps	XMM1,[RAX]
	0x0F,0x54,0xCA,			// andps	XMM1,XMM2
0x66,	0x0F,0x54,0x03,			// andpd	XMM0,[RBX]
0x66,	0x0F,0x54,0xD1,			// andpd	XMM2,XMM1
	0x0F,0x55,0x08,			// andnps	XMM1,[RAX]
	0x0F,0x55,0xCA,			// andnps	XMM1,XMM2
0x66,	0x0F,0x55,0x03,			// andnpd	XMM0,[RBX]
0x66,	0x0F,0x55,0xD1,			// andnpd	XMM2,XMM1
	0xA7,				// cmpsd
	0x0F,0xC2,0x08,0x01,		// cmpps	XMM1,[RAX],1
	0x0F,0xC2,0xCA,0x02,		// cmpps	XMM1,XMM2,2
0x66,	0x0F,0xC2,0x03,0x03,		// cmppd	XMM0,[RBX],3
0x66,	0x0F,0xC2,0xD1,0x04,		// cmppd	XMM2,XMM1,4
	0xF2,0x0F,0xC2,0x08,0x05,	// cmpsd	XMM1,[RAX],5
	0xF2,0x0F,0xC2,0xCA,0x06,	// cmpsd	XMM1,XMM2,6
	0xF3,0x0F,0xC2,0x2E,0x07,	// cmpss	XMM5,[RSI],7
	0xF3,0x0F,0xC2,0xF7,0x00,	// cmpss	XMM6,XMM7,0
0x66,	0x0F,0x2F,0x08,			// comisd	XMM1,[RAX]
0x66,	0x0F,0x2F,0x4D,0xD8,		// comisd	XMM1,-028h[RBP]
0x66,	0x0F,0x2F,0xCA,			// comisd	XMM1,XMM2
	0x0F,0x2F,0x2E,			// comiss	XMM5,[RSI]
	0x0F,0x2F,0xF7,			// comiss	XMM6,XMM7
	0xF3,0x0F,0xE6,0xDC,		// cvtdq2pd	XMM3,XMM4
	0xF3,0x0F,0xE6,0x5D,0xD8,	// cvtdq2pd	XMM3,-028h[RBP]
	0x0F,0x5B,0xDC,			// cvtdq2ps	XMM3,XMM4
	0x0F,0x5B,0x5D,0xE0,		// cvtdq2ps	XMM3,-020h[RBP]
	0xF2,0x0F,0xE6,0xDC,		// cvtpd2dq	XMM3,XMM4
	0xF2,0x0F,0xE6,0x5D,0xE0,	// cvtpd2dq	XMM3,-020h[RBP]
0x66,	0x0F,0x2D,0xDC,			// cvtpd2pi	MM3,XMM4
0x66,	0x0F,0x2D,0x5D,0xE0,		// cvtpd2pi	MM3,-020h[RBP]
0x66,	0x0F,0x5A,0xDC,			// cvtpd2ps	XMM3,XMM4
0x66,	0x0F,0x5A,0x5D,0xE0,		// cvtpd2ps	XMM3,-020h[RBP]
0x66,	0x0F,0x2A,0xDC,			// cvtpi2pd	XMM3,MM4
0x66,	0x0F,0x2A,0x5D,0xD8,		// cvtpi2pd	XMM3,-028h[RBP]
	0x0F,0x2A,0xDC,			// cvtpi2ps	XMM3,MM4
	0x0F,0x2A,0x5D,0xD8,		// cvtpi2ps	XMM3,-028h[RBP]
0x66,	0x0F,0x5B,0xDC,			// cvtps2dq	XMM3,XMM4
0x66,	0x0F,0x5B,0x5D,0xE0,		// cvtps2dq	XMM3,-020h[RBP]
	0x0F,0x5A,0xDC,			// cvtps2pd	XMM3,XMM4
	0x0F,0x5A,0x5D,0xD8,		// cvtps2pd	XMM3,-028h[RBP]
	0x0F,0x2D,0xDC,			// cvtps2pi	MM3,XMM4
	0x0F,0x2D,0x5D,0xD8,		// cvtps2pi	MM3,-030h[RBP]
	0xF2,0x0F,0x2D,0xCC,		// cvtsd2si	XMM1,XMM4
	0xF2,0x0F,0x2D,0x55,0xD8,	// cvtsd2si	XMM2,-028h[RBP]
	0xF2,0x0F,0x5A,0xDC,		// cvtsd2ss	XMM3,XMM4
	0xF2,0x0F,0x5A,0x5D,0xD8,	// cvtsd2ss	XMM3,-028h[RBP]
	0xF2,0x0F,0x2A,0xDA,		// cvtsi2sd	XMM3,EDX
	0xF2,0x0F,0x2A,0x5D,0xD0,	// cvtsi2sd	XMM3,-030h[RBP]
	0xF3,0x0F,0x2A,0xDA,		// cvtsi2ss	XMM3,EDX
	0xF3,0x0F,0x2A,0x5D,0xD0,	// cvtsi2ss	XMM3,-030h[RBP]
	0xF3,0x0F,0x5A,0xDC,		// cvtss2sd	XMM3,XMM4
	0xF3,0x0F,0x5A,0x5D,0xD0,	// cvtss2sd	XMM3,-030h[RBP]
	0xF3,0x0F,0x2D,0xFC,		// cvtss2si	XMM7,XMM4
	0xF3,0x0F,0x2D,0x7D,0xD0,	// cvtss2si	XMM7,-030h[RBP]
0x66,	0x0F,0x2C,0xDC,			// cvttpd2pi	MM3,XMM4
0x66,	0x0F,0x2C,0x7D,0xE0,		// cvttpd2pi	MM7,-020h[RBP]
0x66,	0x0F,0xE6,0xDC,			// cvttpd2dq	XMM3,XMM4
0x66,	0x0F,0xE6,0x7D,0xE0,		// cvttpd2dq	XMM7,-020h[RBP]
	0xF3,0x0F,0x5B,0xDC,		// cvttps2dq	XMM3,XMM4
	0xF3,0x0F,0x5B,0x7D,0xE0,	// cvttps2dq	XMM7,-020h[RBP]
	0x0F,0x2C,0xDC,			// cvttps2pi	MM3,XMM4
	0x0F,0x2C,0x7D,0xD8,		// cvttps2pi	MM7,-028h[RBP]
	0xF2,0x0F,0x2C,0xC4,		// cvttsd2si	EAX,XMM4
	0xF2,0x0F,0x2C,0x4D,0xE0,	// cvttsd2si	ECX,-020h[RBP]
	0xF3,0x0F,0x2C,0xC4,		// cvttss2si	EAX,XMM4
	0xF3,0x0F,0x2C,0x4D,0xD0,	// cvttss2si	ECX,-030h[RBP]
0x66,	0x0F,0x5E,0xE8,			// divpd	XMM5,XMM0
0x66,	0x0F,0x5E,0x6D,0xE0,		// divpd	XMM5,-020h[RBP]
	0x0F,0x5E,0xE8,			// divps	XMM5,XMM0
	0x0F,0x5E,0x6D,0xE0,		// divps	XMM5,-020h[RBP]
	0xF2,0x0F,0x5E,0xE8,		// divsd	XMM5,XMM0
	0xF2,0x0F,0x5E,0x6D,0xD8,	// divsd	XMM5,-028h[RBP]
	0xF3,0x0F,0x5E,0xE8,		// divss	XMM5,XMM0
	0xF3,0x0F,0x5E,0x6D,0xD0,	// divss	XMM5,-030h[RBP]
0x66,	0x0F,0xF7,0xD1,			// maskmovdqu	XMM2,XMM1
	0x0F,0xF7,0xE3,			// maskmovq	MM4,MM3
0x66,	0x0F,0x5F,0xC0,			// maxpd	XMM0,XMM0
0x66,	0x0F,0x5F,0x4D,0xE0,		// maxpd	XMM1,-020h[RBP]
	0x0F,0x5F,0xD1,			// maxps	XMM2,XMM1
	0x0F,0x5F,0x5D,0xE0,		// maxps	XMM3,-020h[RBP]
	0xF2,0x0F,0x5F,0xE2,		// maxsd	XMM4,XMM2
	0xF2,0x0F,0x5F,0x6D,0xD8,	// maxsd	XMM5,-028h[RBP]
	0xF3,0x0F,0x5F,0xF3,		// maxss	XMM6,XMM3
	0xF3,0x0F,0x5F,0x7D,0xD0,	// maxss	XMM7,-030h[RBP]
0x66,	0x0F,0x5D,0xC0,			// minpd	XMM0,XMM0
0x66,	0x0F,0x5D,0x4D,0xE0,		// minpd	XMM1,-020h[RBP]
	0x0F,0x5D,0xD1,			// minps	XMM2,XMM1
	0x0F,0x5D,0x5D,0xE0,		// minps	XMM3,-020h[RBP]
	0xF2,0x0F,0x5D,0xE2,		// minsd	XMM4,XMM2
	0xF2,0x0F,0x5D,0x6D,0xD8,	// minsd	XMM5,-028h[RBP]
	0xF3,0x0F,0x5D,0xF3,		// minss	XMM6,XMM3
	0xF3,0x0F,0x5D,0x7D,0xD0,	// minss	XMM7,-030h[RBP]
0x66,	0x0F,0x28,0xCA,			// movapd	XMM1,XMM2
0x66,	0x0F,0x28,0x5D,0xE0,		// movapd	XMM3,-020h[RBP]
0x66,	0x0F,0x29,0x65,0xE0,		// movapd	-020h[RBP],XMM4
	0x0F,0x28,0xCA,			// movaps	XMM1,XMM2
	0x0F,0x28,0x5D,0xE0,		// movaps	XMM3,-020h[RBP]
	0x0F,0x29,0x65,0xE0,		// movaps	-020h[RBP],XMM4
	0x0F,0x6E,0xCB,			// movd		MM1,EBX
	0x0F,0x6E,0x55,0xD0,		// movd		MM2,-030h[RBP]
	0x0F,0x7E,0xDB,			// movd		EBX,MM3
	0x0F,0x7E,0x65,0xD0,		// movd		-030h[RBP],MM4
0x66,	0x0F,0x6E,0xCB,			// movd		XMM1,EBX
0x66,	0x0F,0x6E,0x55,0xD0,		// movd		XMM2,-030h[RBP]
0x66,	0x0F,0x7E,0xDB,			// movd		EBX,XMM3
0x66,	0x0F,0x7E,0x65,0xD0,		// movd		-030h[RBP],XMM4
0x66,	0x0F,0x6F,0xCA,			// movdqa	XMM1,XMM2
0x66,	0x0F,0x6F,0x55,0xE0,		// movdqa	XMM2,-020h[RBP]
0x66,	0x0F,0x7F,0x65,0xE0,		// movdqa	-020h[RBP],XMM4
	0xF3,0x0F,0x6F,0xCA,		// movdqu	XMM1,XMM2
	0xF3,0x0F,0x6F,0x55,0xE0,	// movdqu	XMM2,-020h[RBP]
	0xF3,0x0F,0x7F,0x65,0xE0,	// movdqu	-020h[RBP],XMM4
	0xF2,0x0F,0xD6,0xE3,		// movdq2q	MM4,XMM3
	0x0F,0x12,0xDC,			// movhlps	XMM4,XMM3
0x66,	0x0F,0x16,0x55,0xD8,		// movhpd	XMM2,-028h[RBP]
0x66,	0x0F,0x17,0x7D,0xD8,		// movhpd	-028h[RBP],XMM7
	0x0F,0x16,0x55,0xD8,		// movhps	XMM2,-028h[RBP]
	0x0F,0x17,0x7D,0xD8,		// movhps	-028h[RBP],XMM7
	0x0F,0x16,0xDC,			// movlhps	XMM4,XMM3
0x66,	0x0F,0x12,0x55,0xD8,		// movlpd	XMM2,-028h[RBP]
0x66,	0x0F,0x13,0x7D,0xD8,		// movlpd	-028h[RBP],XMM7
	0x0F,0x12,0x55,0xD8,		// movlps	XMM2,-028h[RBP]
	0x0F,0x13,0x7D,0xD8,		// movlps	-028h[RBP],XMM7
0x66,	0x0F,0x50,0xF3,			// movmskpd	ESI,XMM3
	0x0F,0x50,0xF3,			// movmskps	ESI,XMM3
0x66,	0x0F,0x59,0xC0,			// mulpd	XMM0,XMM0
0x66,	0x0F,0x59,0x4D,0xE0,		// mulpd	XMM1,-020h[RBP]
	0x0F,0x59,0xD1,			// mulps	XMM2,XMM1
	0x0F,0x59,0x5D,0xE0,		// mulps	XMM3,-020h[RBP]
	0xF2,0x0F,0x59,0xE2,		// mulsd	XMM4,XMM2
	0xF2,0x0F,0x59,0x6D,0xD8,	// mulsd	XMM5,-028h[RBP]
	0xF3,0x0F,0x59,0xF3,		// mulss	XMM6,XMM3
	0xF3,0x0F,0x59,0x7D,0xD0,	// mulss	XMM7,-030h[RBP]
0x66, 	0x0F,0x51,0xC4,			// sqrtpd	XMM0,XMM4
0x66, 	0x0F,0x51,0x4D,0xE0,		// sqrtpd	XMM1,-020h[RBP]
	0x0F,0x51,0xD5,			// sqrtps	XMM2,XMM5
	0x0F,0x51,0x5D,0xE0,		// sqrtps	XMM3,-020h[RBP]
	0xF2,0x0F,0x51,0xE6,		// sqrtsd	XMM4,XMM6
	0xF2,0x0F,0x51,0x6D,0xD8,	// sqrtsd	XMM5,-028h[RBP]
	0xF3,0x0F,0x51,0xF7,		// sqrtss	XMM6,XMM7
	0xF3,0x0F,0x51,0x7D,0xD0,	// sqrtss	XMM7,-030h[RBP]
0x66,	0x0F,0x5C,0xC4,			// subpd	XMM0,XMM4
0x66,	0x0F,0x5C,0x4D,0xE0,		// subpd	XMM1,-020h[RBP]
	0x0F,0x5C,0xD5,			// subps	XMM2,XMM5
	0x0F,0x5C,0x5D,0xE0,		// subps	XMM3,-020h[RBP]
	0xF2,0x0F,0x5C,0xE6,		// subsd	XMM4,XMM6
	0xF2,0x0F,0x5C,0x6D,0xD8,	// subsd	XMM5,-028h[RBP]
	0xF3,0x0F,0x5C,0xF7,		// subss	XMM6,XMM7
	0xF3,0x0F,0x5C,0x7D,0xD0,	// subss	XMM7,-030h[RBP]
	0x0F,0x01,0xE0,			// smsw EAX
    ];
    int i;

    asm
    {
	call	L1			;
	ud2				;
	syscall				;
	sysenter			;
	sysexit				;
	sysret				;
	lfence				;
	mfence				;
	sfence				;
	fxsave	[RAX]			;
	fxrstor	[RAX]			;
	ldmxcsr	[RAX]			;
	stmxcsr	[RAX]			;
	clflush	[RAX]			;

	addps XMM1,[RAX]		;
	addps XMM1,XMM2			;
	addpd XMM0,[RBX]		;
	addpd XMM2,XMM1			;
	addsd XMM1,[RAX]		;
	addsd XMM1,XMM2			;
	addss XMM5,[RSI]		;
	addss XMM6,XMM7			;

	andps XMM1,[RAX]		;
	andps XMM1,XMM2			;
	andpd XMM0,[RBX]		;
	andpd XMM2,XMM1			;

	andnps XMM1,[RAX]		;
	andnps XMM1,XMM2		;
	andnpd XMM0,[RBX]		;
	andnpd XMM2,XMM1		;

	cmpsd				;
	cmpps XMM1,[RAX],1		;
	cmpps XMM1,XMM2,2		;
	cmppd XMM0,[RBX],3		;
	cmppd XMM2,XMM1,4		;
	cmpsd XMM1,[RAX],5		;
	cmpsd XMM1,XMM2,6		;
	cmpss XMM5,[RSI],7		;
	cmpss XMM6,XMM7,0		;

	comisd XMM1,[RAX]		;
	comisd XMM1,m64[RBP]		;
	comisd XMM1,XMM2		;
	comiss XMM5,[RSI]		;
	comiss XMM6,XMM7		;

	cvtdq2pd XMM3,XMM4		;
	cvtdq2pd XMM3,m64[RBP]		;

	cvtdq2ps XMM3,XMM4		;
	cvtdq2ps XMM3,m128[RBP]		;

	cvtpd2dq XMM3,XMM4		;
	cvtpd2dq XMM3,m128[RBP]		;

	cvtpd2pi MM3,XMM4		;
	cvtpd2pi MM3,m128[RBP]		;

	cvtpd2ps XMM3,XMM4		;
	cvtpd2ps XMM3,m128[RBP]		;

	cvtpi2pd XMM3,MM4		;
	cvtpi2pd XMM3,m64[RBP]		;

	cvtpi2ps XMM3,MM4		;
	cvtpi2ps XMM3,m64[RBP]		;

	cvtps2dq XMM3,XMM4		;
	cvtps2dq XMM3,m128[RBP]		;

	cvtps2pd XMM3,XMM4		;
	cvtps2pd XMM3,m64[RBP]		;

	cvtps2pi MM3,XMM4		;
	cvtps2pi MM3,m64[RBP]		;

	cvtsd2si ECX,XMM4		;
	cvtsd2si EDX,m64[RBP]		;

	cvtsd2ss XMM3,XMM4		;
	cvtsd2ss XMM3,m64[RBP]		;

	cvtsi2sd XMM3,EDX		;
	cvtsi2sd XMM3,m32[RBP]		;

	cvtsi2ss XMM3,EDX		;
	cvtsi2ss XMM3,m32[RBP]		;

	cvtss2sd XMM3,XMM4		;
	cvtss2sd XMM3,m32[RBP]		;

	cvtss2si EDI,XMM4		;
	cvtss2si EDI,m32[RBP]		;

	cvttpd2pi MM3,XMM4		;
	cvttpd2pi MM7,m128[RBP]		;

	cvttpd2dq XMM3,XMM4		;
	cvttpd2dq XMM7,m128[RBP]	;

	cvttps2dq XMM3,XMM4		;
	cvttps2dq XMM7,m128[RBP]	;

	cvttps2pi MM3,XMM4		;
	cvttps2pi MM7,m64[RBP]		;

	cvttsd2si EAX,XMM4		;
	cvttsd2si ECX,m128[RBP]		;

	cvttss2si EAX,XMM4		;
	cvttss2si ECX,m32[RBP]		;

	divpd	XMM5,XMM0		;
	divpd	XMM5,m128[RBP]		;
	divps	XMM5,XMM0		;
	divps	XMM5,m128[RBP]		;
	divsd	XMM5,XMM0		;
	divsd	XMM5,m64[RBP]		;
	divss	XMM5,XMM0		;
	divss	XMM5,m32[RBP]		;

	maskmovdqu XMM1,XMM2		;
	maskmovq   MM3,MM4		;

	maxpd	XMM0,XMM0		;
	maxpd	XMM1,m128[RBP]		;
	maxps	XMM2,XMM1		;
	maxps	XMM3,m128[RBP]		;
	maxsd	XMM4,XMM2		;
	maxsd	XMM5,m64[RBP]		;
	maxss	XMM6,XMM3		;
	maxss	XMM7,m32[RBP]		;

	minpd	XMM0,XMM0		;
	minpd	XMM1,m128[RBP]		;
	minps	XMM2,XMM1		;
	minps	XMM3,m128[RBP]		;
	minsd	XMM4,XMM2		;
	minsd	XMM5,m64[RBP]		;
	minss	XMM6,XMM3		;
	minss	XMM7,m32[RBP]		;

	movapd	XMM1,XMM2		;
	movapd	XMM3,m128[RBP]		;
	movapd	m128[RBP],XMM4		;

	movaps	XMM1,XMM2		;
	movaps	XMM3,m128[RBP]		;
	movaps	m128[RBP],XMM4		;

	movd	MM1,EBX			;
	movd	MM2,m32[RBP]		;
	movd	EBX,MM3			;
	movd	m32[RBP],MM4		;

	movd	XMM1,EBX		;
	movd	XMM2,m32[RBP]		;
	movd	EBX,XMM3		;
	movd	m32[RBP],XMM4		;

	movdqa	XMM1,XMM2		;
	movdqa	XMM2,m128[RBP]		;
	movdqa	m128[RBP],XMM4		;

	movdqu	XMM1,XMM2		;
	movdqu	XMM2,m128[RBP]		;
	movdqu	m128[RBP],XMM4		;

	movdq2q	MM3,XMM4		;
	movhlps	XMM3,XMM4		;
	movhpd	XMM2,m64[RBP]		;
	movhpd	m64[RBP],XMM7		;
	movhps	XMM2,m64[RBP]		;
	movhps	m64[RBP],XMM7		;
	movlhps	XMM3,XMM4		;
	movlpd	XMM2,m64[RBP]		;
	movlpd	m64[RBP],XMM7		;
	movlps	XMM2,m64[RBP]		;
	movlps	m64[RBP],XMM7		;

	movmskpd ESI,XMM3		;
	movmskps ESI,XMM3		;

	mulpd	XMM0,XMM0		;
	mulpd	XMM1,m128[RBP]		;
	mulps	XMM2,XMM1		;
	mulps	XMM3,m128[RBP]		;
	mulsd	XMM4,XMM2		;
	mulsd	XMM5,m64[RBP]		;
	mulss	XMM6,XMM3		;
	mulss	XMM7,m32[RBP]		;

	sqrtpd	XMM0,XMM4		;
	sqrtpd	XMM1,m128[RBP]		;
	sqrtps	XMM2,XMM5		;
	sqrtps	XMM3,m128[RBP]		;
	sqrtsd	XMM4,XMM6		;
	sqrtsd	XMM5,m64[RBP]		;
	sqrtss	XMM6,XMM7		;
	sqrtss	XMM7,m32[RBP]		;

	subpd	XMM0,XMM4		;
	subpd	XMM1,m128[RBP]		;
	subps	XMM2,XMM5		;
	subps	XMM3,m128[RBP]		;
	subsd	XMM4,XMM6		;
	subsd	XMM5,m64[RBP]		;
	subss	XMM6,XMM7		;
	subss	XMM7,m32[RBP]		;

	smsw	EAX			;

L1:					;
	pop	RBX			;
	mov	p[RBP],RBX		;
    }
    for (i = 0; i < data.length; i++)
    {
	//printf("[%d] = %02x %02x\n", i, p[i], data[i]);
	assert(p[i] == data[i]);
    }
}

/****************************************************/

void test14()
{
    byte m8;
    short m16;
    int m32;
    long m64;
    M128 m128;
    ubyte *p;
    static ubyte data[] =
    [
0x66,	0x0F,0x50,0xF3,			// movmskpd	ESI,XMM3
	0x0F,0x50,0xF3,			// movmskps	ESI,XMM3
0x66,	0x0F,0xE7,0x55,0xE0,		// movntdq	-020h[RBP],XMM2
	0x0F,0xC3,0x4D,0xD4,		// movnti	-02Ch[RBP],ECX
0x66,	0x0F,0x2B,0x5D,0xE0,		// movntpd	-020h[RBP],XMM3
	0x0F,0x2B,0x65,0xE0,		// movntps	-020h[RBP],XMM4
	0x0F,0xE7,0x6D,0xD8,		// movntq	-028h[RBP],MM5
	0x0F,0x6F,0xCA,			// movq		MM1,MM2
	0x0F,0x6F,0x55,0xD8,		// movq		MM2,-028h[RBP]
	0x0F,0x7F,0x5D,0xD8,		// movq		-028h[RBP],MM3
	0xF3,0x0F,0x7E,0xCA,		// movq		XMM1,XMM2
	0xF3,0x0F,0x7E,0x55,0xD8,	// movq		XMM2,-028h[RBP]
0x66,	0x0F,0xD6,0x5D,0xD8,		// movq		-028h[RBP],XMM3
	0xF3,0x0F,0xD6,0xDA,		// movq2dq	XMM3,MM2
	0xA5,				// movsd
	0xF2,0x0F,0x10,0xCA,		// movsd	XMM1,XMM2
	0xF2,0x0F,0x10,0x5D,0xD8,	// movsd	XMM3,-028h[RBP]
	0xF2,0x0F,0x11,0x65,0xD8,	// movsd	-028h[RBP],XMM4
	0xF3,0x0F,0x10,0xCA,		// movss	XMM1,XMM2
	0xF3,0x0F,0x10,0x5D,0xD4,	// movss	XMM3,-02Ch[RBP]
	0xF3,0x0F,0x11,0x65,0xD4,	// movss	-02Ch[RBP],XMM4
0x66,	0x0F,0x10,0xCA,			// movupd	XMM1,XMM2
0x66,	0x0F,0x10,0x5D,0xE0,		// movupd	XMM3,-020h[RBP]
0x66,	0x0F,0x11,0x65,0xE0,		// movupd	-020h[RBP],XMM4
	0x0F,0x10,0xCA,			// movups	XMM1,XMM2
	0x0F,0x10,0x5D,0xE0,		// movups	XMM3,-020h[RBP]
	0x0F,0x11,0x65,0xE0,		// movups	-020h[RBP],XMM4
0x66,	0x0F,0x56,0xCA,			// orpd		XMM1,XMM2
0x66,	0x0F,0x56,0x5D,0xE0,		// orpd		XMM3,-020h[RBP]
	0x0F,0x56,0xCA,			// orps		XMM1,XMM2
	0x0F,0x56,0x5D,0xE0,		// orps		XMM3,-020h[RBP]
	0x0F,0x63,0xCA,			// packsswb	MM1,MM2
	0x0F,0x63,0x5D,0xD8,		// packsswb	MM3,-028h[RBP]
0x66,	0x0F,0x63,0xCA,			// packsswb	XMM1,XMM2
0x66,	0x0F,0x63,0x5D,0xE0,		// packsswb	XMM3,-020h[RBP]
	0x0F,0x6B,0xCA,			// packssdw	MM1,MM2
	0x0F,0x6B,0x5D,0xD8,		// packssdw	MM3,-028h[RBP]
0x66,	0x0F,0x6B,0xCA,			// packssdw	XMM1,XMM2
0x66,	0x0F,0x6B,0x5D,0xE0,		// packssdw	XMM3,-020h[RBP]
	0x0F,0x67,0xCA,			// packuswb	MM1,MM2
	0x0F,0x67,0x5D,0xD8,		// packuswb	MM3,-028h[RBP]
0x66,	0x0F,0x67,0xCA,			// packuswb	XMM1,XMM2
0x66,	0x0F,0x67,0x5D,0xE0,		// packuswb	XMM3,-020h[RBP]
	0x0F,0xFC,0xCA,			// paddb	MM1,MM2
	0x0F,0xFC,0x5D,0xD8,		// paddb	MM3,-028h[RBP]
0x66,	0x0F,0xFC,0xCA,			// paddb	XMM1,XMM2
0x66,	0x0F,0xFC,0x5D,0xE0,		// paddb	XMM3,-020h[RBP]
	0x0F,0xFD,0xCA,			// paddw	MM1,MM2
	0x0F,0xFD,0x5D,0xD8,		// paddw	MM3,-028h[RBP]
0x66,	0x0F,0xFD,0xCA,			// paddw	XMM1,XMM2
0x66,	0x0F,0xFD,0x5D,0xE0,		// paddw	XMM3,-020h[RBP]
	0x0F,0xFE,0xCA,			// paddd	MM1,MM2
	0x0F,0xFE,0x5D,0xD8,		// paddd	MM3,-028h[RBP]
0x66,	0x0F,0xFE,0xCA,			// paddd	XMM1,XMM2
0x66,	0x0F,0xFE,0x5D,0xE0,		// paddd	XMM3,-020h[RBP]
	0x0F,0xD4,0xCA,			// paddq	MM1,MM2
	0x0F,0xD4,0x5D,0xD8,		// paddq	MM3,-028h[RBP]
0x66,	0x0F,0xD4,0xCA,			// paddq	XMM1,XMM2
0x66,	0x0F,0xD4,0x5D,0xE0,		// paddq	XMM3,-020h[RBP]
	0x0F,0xEC,0xCA,			// paddsb	MM1,MM2
	0x0F,0xEC,0x5D,0xD8,		// paddsb	MM3,-028h[RBP]
0x66,	0x0F,0xEC,0xCA,			// paddsb	XMM1,XMM2
0x66,	0x0F,0xEC,0x5D,0xE0,		// paddsb	XMM3,-020h[RBP]
	0x0F,0xED,0xCA,			// paddsw	MM1,MM2
	0x0F,0xED,0x5D,0xD8,		// paddsw	MM3,-028h[RBP]
0x66,	0x0F,0xED,0xCA,			// paddsw	XMM1,XMM2
0x66,	0x0F,0xED,0x5D,0xE0,		// paddsw	XMM3,-020h[RBP]
	0x0F,0xDC,0xCA,			// paddusb	MM1,MM2
	0x0F,0xDC,0x5D,0xD8,		// paddusb	MM3,-028h[RBP]
0x66,	0x0F,0xDC,0xCA,			// paddusb	XMM1,XMM2
0x66,	0x0F,0xDC,0x5D,0xE0,		// paddusb	XMM3,-020h[RBP]
	0x0F,0xDD,0xCA,			// paddusw	MM1,MM2
	0x0F,0xDD,0x5D,0xD8,		// paddusw	MM3,-028h[RBP]
0x66,	0x0F,0xDD,0xCA,			// paddusw	XMM1,XMM2
0x66,	0x0F,0xDD,0x5D,0xE0,		// paddusw	XMM3,-020h[RBP]
	0x0F,0xDB,0xCA,			// pand		MM1,MM2
	0x0F,0xDB,0x5D,0xD8,		// pand		MM3,-028h[RBP]
0x66,	0x0F,0xDB,0xCA,			// pand		XMM1,XMM2
0x66,	0x0F,0xDB,0x5D,0xE0,		// pand		XMM3,-020h[RBP]
	0x0F,0xDF,0xCA,			// pandn	MM1,MM2
	0x0F,0xDF,0x5D,0xD8,		// pandn	MM3,-028h[RBP]
0x66,	0x0F,0xDF,0xCA,			// pandn	XMM1,XMM2
0x66,	0x0F,0xDF,0x5D,0xE0,		// pandn	XMM3,-020h[RBP]
	0x0F,0xE0,0xCA,			// pavgb	MM1,MM2
	0x0F,0xE0,0x5D,0xD8,		// pavgb	MM3,-028h[RBP]
0x66,	0x0F,0xE0,0xCA,			// pavgb	XMM1,XMM2
0x66,	0x0F,0xE0,0x5D,0xE0,		// pavgb	XMM3,-020h[RBP]
	0x0F,0xE3,0xCA,			// pavgw	MM1,MM2
	0x0F,0xE3,0x5D,0xD8,		// pavgw	MM3,-028h[RBP]
0x66,	0x0F,0xE3,0xCA,			// pavgw	XMM1,XMM2
0x66,	0x0F,0xE3,0x5D,0xE0,		// pavgw	XMM3,-020h[RBP]
	0x0F,0x74,0xCA,			// pcmpeqb	MM1,MM2
	0x0F,0x74,0x5D,0xD8,		// pcmpeqb	MM3,-028h[RBP]
0x66,	0x0F,0x74,0xCA,			// pcmpeqb	XMM1,XMM2
0x66,	0x0F,0x74,0x5D,0xE0,		// pcmpeqb	XMM3,-020h[RBP]
	0x0F,0x75,0xCA,			// pcmpeqw	MM1,MM2
	0x0F,0x75,0x5D,0xD8,		// pcmpeqw	MM3,-028h[RBP]
0x66,	0x0F,0x75,0xCA,			// pcmpeqw	XMM1,XMM2
0x66,	0x0F,0x75,0x5D,0xE0,		// pcmpeqw	XMM3,-020h[RBP]
	0x0F,0x76,0xCA,			// pcmpeqd	MM1,MM2
	0x0F,0x76,0x5D,0xD8,		// pcmpeqd	MM3,-028h[RBP]
0x66,	0x0F,0x76,0xCA,			// pcmpeqd	XMM1,XMM2
0x66,	0x0F,0x76,0x5D,0xE0,		// pcmpeqd	XMM3,-020h[RBP]
	0x0F,0x64,0xCA,			// pcmpgtb	MM1,MM2
	0x0F,0x64,0x5D,0xD8,		// pcmpgtb	MM3,-028h[RBP]
0x66,	0x0F,0x64,0xCA,			// pcmpgtb	XMM1,XMM2
0x66,	0x0F,0x64,0x5D,0xE0,		// pcmpgtb	XMM3,-020h[RBP]
	0x0F,0x65,0xCA,			// pcmpgtw	MM1,MM2
	0x0F,0x65,0x5D,0xD8,		// pcmpgtw	MM3,-028h[RBP]
0x66,	0x0F,0x65,0xCA,			// pcmpgtw	XMM1,XMM2
0x66,	0x0F,0x65,0x5D,0xE0,		// pcmpgtw	XMM3,-020h[RBP]
	0x0F,0x66,0xCA,			// pcmpgtd	MM1,MM2
	0x0F,0x66,0x5D,0xD8,		// pcmpgtd	MM3,-028h[RBP]
0x66,	0x0F,0x66,0xCA,			// pcmpgtd	XMM1,XMM2
0x66,	0x0F,0x66,0x5D,0xE0,		// pcmpgtd	XMM3,-020h[RBP]
	0x0F,0xC5,0xD6,0x07,		// pextrw	EDX,MM6,7
0x66,	0x0F,0xC5,0xD6,0x07,		// pextrw	EDX,XMM6,7
	0x0F,0xC4,0xF2,0x07,		// pinsrw	MM6,EDX,7
	0x0F,0xC4,0x75,0xD2,0x07,	// pinsrw	MM6,-02Eh[RBP],7
0x66,	0x0F,0xC4,0xF2,0x07,		// pinsrw	XMM6,EDX,7
0x66,	0x0F,0xC4,0x75,0xD2,0x07,	// pinsrw	XMM6,-02Eh[RBP],7
	0x0F,0xF5,0xCA,			// pmaddwd	MM1,MM2
	0x0F,0xF5,0x5D,0xD8,		// pmaddwd	MM3,-028h[RBP]
0x66,	0x0F,0xF5,0xCA,			// pmaddwd	XMM1,XMM2
0x66,	0x0F,0xF5,0x5D,0xE0,		// pmaddwd	XMM3,-020h[RBP]
	0x0F,0xEE,0xCA,			// pmaxsw	MM1,XMM2
	0x0F,0xEE,0x5D,0xD8,		// pmaxsw	MM3,-028h[RBP]
0x66,	0x0F,0xEE,0xCA,			// pmaxsw	XMM1,XMM2
0x66,	0x0F,0xEE,0x5D,0xE0,		// pmaxsw	XMM3,-020h[RBP]
	0x0F,0xDE,0xCA,			// pmaxub	MM1,XMM2
	0x0F,0xDE,0x5D,0xD8,		// pmaxub	MM3,-028h[RBP]
0x66,	0x0F,0xDE,0xCA,			// pmaxub	XMM1,XMM2
0x66,	0x0F,0xDE,0x5D,0xE0,		// pmaxub	XMM3,-020h[RBP]
	0x0F,0xEA,0xCA,			// pminsw	MM1,MM2
	0x0F,0xEA,0x5D,0xD8,		// pminsw	MM3,-028h[RBP]
0x66,	0x0F,0xEA,0xCA,			// pminsw	XMM1,XMM2
0x66,	0x0F,0xEA,0x5D,0xE0,		// pminsw	XMM3,-020h[RBP]
	0x0F,0xDA,0xCA,			// pminub	MM1,MM2
	0x0F,0xDA,0x5D,0xD8,		// pminub	MM3,-028h[RBP]
0x66,	0x0F,0xDA,0xCA,			// pminub	XMM1,XMM2
0x66,	0x0F,0xDA,0x5D,0xE0,		// pminub	XMM3,-020h[RBP]
	0x0F,0xD7,0xC8,			// pmovmskb	ECX,MM0
0x66,	0x0F,0xD7,0xCE,			// pmovmskb	ECX,XMM6
	0x0F,0xE4,0xCA,			// pmulhuw	MM1,MM2
	0x0F,0xE4,0x5D,0xD8,		// pmulhuw	MM3,-028h[RBP]
0x66,	0x0F,0xE4,0xCA,			// pmulhuw	XMM1,XMM2
0x66,	0x0F,0xE4,0x5D,0xE0,		// pmulhuw	XMM3,-020h[RBP]
	0x0F,0xE5,0xCA,			// pmulhw	MM1,MM2
	0x0F,0xE5,0x5D,0xD8,		// pmulhw	MM3,-028h[RBP]
0x66,	0x0F,0xE5,0xCA,			// pmulhw	XMM1,XMM2
0x66,	0x0F,0xE5,0x5D,0xE0,		// pmulhw	XMM3,-020h[RBP]
	0x0F,0xD5,0xCA,			// pmullw	MM1,MM2
	0x0F,0xD5,0x5D,0xD8,		// pmullw	MM3,-028h[RBP]
0x66,	0x0F,0xD5,0xCA,			// pmullw	XMM1,XMM2
0x66,	0x0F,0xD5,0x5D,0xE0,		// pmullw	XMM3,-020h[RBP]
	0x0F,0xF4,0xCA,			// pmuludq	MM1,MM2
	0x0F,0xF4,0x5D,0xD8,		// pmuludq	MM3,-028h[RBP]
0x66,	0x0F,0xF4,0xCA,			// pmuludq	XMM1,XMM2
0x66,	0x0F,0xF4,0x5D,0xE0,		// pmuludq	XMM3,-020h[RBP]
	0x0F,0xEB,0xCA,			// por		MM1,MM2
	0x0F,0xEB,0x5D,0xD8,		// por		MM3,-028h[RBP]
0x66,	0x0F,0xEB,0xCA,			// por		XMM1,XMM2
0x66,	0x0F,0xEB,0x5D,0xE0,		// por		XMM3,-020h[RBP]
	0x0F,0x18,0x4D,0xD0,		// prefetcht0	-030h[RBP]
	0x0F,0x18,0x55,0xD0,		// prefetcht1	-030h[RBP]
	0x0F,0x18,0x5D,0xD0,		// prefetcht2	-030h[RBP]
	0x0F,0x18,0x45,0xD0,		// prefetchnta	-030h[RBP]
	0x0F,0xF6,0xCA,			// psadbw	MM1,MM2
	0x0F,0xF6,0x5D,0xD8,		// psadbw	MM3,-028h[RBP]
0x66,	0x0F,0xF6,0xCA,			// psadbw	XMM1,XMM2
0x66,	0x0F,0xF6,0x5D,0xE0,		// psadbw	XMM3,-020h[RBP]
0x66,	0x0F,0x70,0xCA,0x03,		// pshufd	XMM1,XMM2,3
0x66,	0x0F,0x70,0x5D,0xE0,0x03,	// pshufd	XMM3,-020h[RBP],3
	0xF3,0x0F,0x70,0xCA,0x03,	// pshufhw	XMM1,XMM2,3
	0xF3,0x0F,0x70,0x5D,0xE0,0x03,	// pshufhw	XMM3,-020h[RBP],3
	0xF2,0x0F,0x70,0xCA,0x03,	// pshuflw	XMM1,XMM2,3
	0xF2,0x0F,0x70,0x5D,0xE0,0x03,	// pshuflw	XMM3,-020h[RBP],3
	0x0F,0x70,0xCA,0x03,		// pshufw	MM1,MM2,3
	0x0F,0x70,0x5D,0xD8,0x03,	// pshufw	MM3,-028h[RBP],3
0x66,	0x0F,0x73,0xF9,0x18,		// pslldq	XMM1,020h
	0x0F,0xF1,0xCA,			// psllw	MM1,MM2
	0x0F,0xF1,0x4D,0xD8,		// psllw	MM1,-028h[RBP]
0x66,	0x0F,0xF1,0xCA,			// psllw	XMM1,XMM2
0x66,	0x0F,0xF1,0x4D,0xE0,		// psllw	XMM1,-020h[RBP]
	0x0F,0x71,0xF1,0x15,		// psraw	MM1,015h
0x66,	0x0F,0x71,0xF1,0x15,		// psraw	XMM1,015h
	0x0F,0xF2,0xCA,			// pslld	MM1,MM2
	0x0F,0xF2,0x4D,0xD8,		// pslld	MM1,-028h[RBP]
0x66,	0x0F,0xF2,0xCA,			// pslld	XMM1,XMM2
0x66,	0x0F,0xF2,0x4D,0xE0,		// pslld	XMM1,-020h[RBP]
	0x0F,0x72,0xF1,0x15,		// psrad	MM1,015h
0x66,	0x0F,0x72,0xF1,0x15,		// psrad	XMM1,015h
	0x0F,0xF3,0xCA,			// psllq	MM1,MM2
	0x0F,0xF3,0x4D,0xD8,		// psllq	MM1,-028h[RBP]
0x66,	0x0F,0xF3,0xCA,			// psllq	XMM1,XMM2
0x66,	0x0F,0xF3,0x4D,0xE0,		// psllq	XMM1,-020h[RBP]
	0x0F,0x73,0xF1,0x15,		// psllq	MM1,015h
0x66,	0x0F,0x73,0xF1,0x15,		// psllq	XMM1,015h
	0x0F,0xE1,0xCA,			// psraw	MM1,MM2
	0x0F,0xE1,0x4D,0xD8,		// psraw	MM1,-028h[RBP]
0x66,	0x0F,0xE1,0xCA,			// psraw	XMM1,XMM2
0x66,	0x0F,0xE1,0x4D,0xE0,		// psraw	XMM1,-020h[RBP]
	0x0F,0x71,0xE1,0x15,		// psraw	MM1,015h
0x66,	0x0F,0x71,0xE1,0x15,		// psraw	XMM1,015h
	0x0F,0xE2,0xCA,			// psrad	MM1,MM2
	0x0F,0xE2,0x4D,0xD8,		// psrad	MM1,-028h[RBP]
0x66,	0x0F,0xE2,0xCA,			// psrad	XMM1,XMM2
0x66,	0x0F,0xE2,0x4D,0xE0,		// psrad	XMM1,-020h[RBP]
	0x0F,0x72,0xE1,0x15,		// psrad	MM1,015h
0x66,	0x0F,0x72,0xE1,0x15,		// psrad	XMM1,015h
0x66,	0x0F,0x73,0xD9,0x18,		// psrldq	XMM1,020h
	0x0F,0xD1,0xCA,			// psrlw	MM1,MM2
	0x0F,0xD1,0x4D,0xD8,		// psrlw	MM1,-028h[RBP]
0x66,	0x0F,0xD1,0xCA,			// psrlw	XMM1,XMM2
0x66,	0x0F,0xD1,0x4D,0xE0,		// psrlw	XMM1,-020h[RBP]
	0x0F,0x71,0xD1,0x15,		// psrlw	MM1,015h
0x66,	0x0F,0x71,0xD1,0x15,		// psrlw	XMM1,015h
	0x0F,0xD2,0xCA,			// psrld	MM1,MM2
	0x0F,0xD2,0x4D,0xD8,		// psrld	MM1,-028h[RBP]
0x66,	0x0F,0xD2,0xCA,			// psrld	XMM1,XMM2
0x66,	0x0F,0xD2,0x4D,0xE0,		// psrld	XMM1,-020h[RBP]
	0x0F,0x72,0xD1,0x15,		// psrld	MM1,015h
0x66,	0x0F,0x72,0xD1,0x15,		// psrld	XMM1,015h
	0x0F,0xD3,0xCA,			// psrlq	MM1,MM2
	0x0F,0xD3,0x4D,0xD8,		// psrlq	MM1,-028h[RBP]
0x66,	0x0F,0xD3,0xCA,			// psrlq	XMM1,XMM2
0x66,	0x0F,0xD3,0x4D,0xE0,		// psrlq	XMM1,-020h[RBP]
	0x0F,0x73,0xD1,0x15,		// psrlq	MM1,015h
0x66,	0x0F,0x73,0xD1,0x15,		// psrlq	XMM1,015h
	0x0F,0xF8,0xCA,			// psubb	MM1,MM2
	0x0F,0xF8,0x4D,0xD8,		// psubb	MM1,-028h[RBP]
0x66,	0x0F,0xF8,0xCA,			// psubb	XMM1,XMM2
0x66,	0x0F,0xF8,0x4D,0xE0,		// psubb	XMM1,-020h[RBP]
	0x0F,0xF9,0xCA,			// psubw	MM1,MM2
	0x0F,0xF9,0x4D,0xD8,		// psubw	MM1,-028h[RBP]
0x66,	0x0F,0xF9,0xCA,			// psubw	XMM1,XMM2
0x66,	0x0F,0xF9,0x4D,0xE0,		// psubw	XMM1,-020h[RBP]
	0x0F,0xFA,0xCA,			// psubd	MM1,MM2
	0x0F,0xFA,0x4D,0xD8,		// psubd	MM1,-028h[RBP]
0x66,	0x0F,0xFA,0xCA,			// psubd	XMM1,XMM2
0x66,	0x0F,0xFA,0x4D,0xE0,		// psubd	XMM1,-020h[RBP]
	0x0F,0xFB,0xCA,			// psubq	MM1,MM2
	0x0F,0xFB,0x4D,0xD8,		// psubq	MM1,-028h[RBP]
0x66,	0x0F,0xFB,0xCA,			// psubq	XMM1,XMM2
0x66,	0x0F,0xFB,0x4D,0xE0,		// psubq	XMM1,-020h[RBP]
	0x0F,0xE8,0xCA,			// psubsb	MM1,MM2
	0x0F,0xE8,0x4D,0xD8,		// psubsb	MM1,-028h[RBP]
0x66,	0x0F,0xE8,0xCA,			// psubsb	XMM1,XMM2
0x66,	0x0F,0xE8,0x4D,0xE0,		// psubsb	XMM1,-020h[RBP]
	0x0F,0xE9,0xCA,			// psubsw	MM1,MM2
	0x0F,0xE9,0x4D,0xD8,		// psubsw	MM1,-028h[RBP]
0x66,	0x0F,0xE9,0xCA,			// psubsw	XMM1,XMM2
0x66,	0x0F,0xE9,0x4D,0xE0,		// psubsw	XMM1,-020h[RBP]
	0x0F,0xD8,0xCA,			// psubusb	MM1,MM2
	0x0F,0xD8,0x4D,0xD8,		// psubusb	MM1,-028h[RBP]
0x66,	0x0F,0xD8,0xCA,			// psubusb	XMM1,XMM2
0x66,	0x0F,0xD8,0x4D,0xE0,		// psubusb	XMM1,-020h[RBP]
	0x0F,0xD9,0xCA,			// psubusw	MM1,MM2
	0x0F,0xD9,0x4D,0xD8,		// psubusw	MM1,-028h[RBP]
0x66,	0x0F,0xD9,0xCA,			// psubusw	XMM1,XMM2
0x66,	0x0F,0xD9,0x4D,0xE0,		// psubusw	XMM1,-020h[RBP]
	0x0F,0x68,0xCA,			// punpckhbw	MM1,MM2
	0x0F,0x68,0x4D,0xD8,		// punpckhbw	MM1,-028h[RBP]
0x66,	0x0F,0x68,0xCA,			// punpckhbw	XMM1,XMM2
0x66,	0x0F,0x68,0x4D,0xE0,		// punpckhbw	XMM1,-020h[RBP]
	0x0F,0x69,0xCA,			// punpckhwd	MM1,MM2
	0x0F,0x69,0x4D,0xD8,		// punpckhwd	MM1,-028h[RBP]
0x66,	0x0F,0x69,0xCA,			// punpckhwd	XMM1,XMM2
0x66,	0x0F,0x69,0x4D,0xE0,		// punpckhwd	XMM1,-020h[RBP]
	0x0F,0x6A,0xCA,			// punpckhdq	MM1,MM2
	0x0F,0x6A,0x4D,0xD8,		// punpckhdq	MM1,-028h[RBP]
0x66,	0x0F,0x6A,0xCA,			// punpckhdq	XMM1,XMM2
0x66,	0x0F,0x6A,0x4D,0xE0,		// punpckhdq	XMM1,-020h[RBP]
0x66,	0x0F,0x6D,0xCA,			// punpckhqdq	XMM1,XMM2
0x66,	0x0F,0x6D,0x4D,0xE0,		// punpckhqdq	XMM1,-020h[RBP]
	0x0F,0x60,0xCA,			// punpcklbw	MM1,MM2
	0x0F,0x60,0x4D,0xD8,		// punpcklbw	MM1,-028h[RBP]
0x66,	0x0F,0x60,0xCA,			// punpcklbw	XMM1,XMM2
0x66,	0x0F,0x60,0x4D,0xE0,		// punpcklbw	XMM1,-020h[RBP]
	0x0F,0x61,0xCA,			// punpcklwd	MM1,MM2
	0x0F,0x61,0x4D,0xD8,		// punpcklwd	MM1,-028h[RBP]
0x66,	0x0F,0x61,0xCA,			// punpcklwd	XMM1,XMM2
0x66,	0x0F,0x61,0x4D,0xE0,		// punpcklwd	XMM1,-020h[RBP]
	0x0F,0x62,0xCA,			// punpckldq	MM1,MM2
	0x0F,0x62,0x4D,0xD8,		// punpckldq	MM1,-028h[RBP]
0x66,	0x0F,0x62,0xCA,			// punpckldq	XMM1,XMM2
0x66,	0x0F,0x62,0x4D,0xE0,		// punpckldq	XMM1,-020h[RBP]
0x66,	0x0F,0x6C,0xCA,			// punpcklqdq	XMM1,XMM2
0x66,	0x0F,0x6C,0x4D,0xE0,		// punpcklqdq	XMM1,-020h[RBP]
	0x0F,0xEF,0xCA,			// pxor		MM1,MM2
	0x0F,0xEF,0x4D,0xD8,		// pxor		MM1,-028h[RBP]
0x66,	0x0F,0xEF,0xCA,			// pxor		XMM1,XMM2
0x66,	0x0F,0xEF,0x4D,0xE0,		// pxor		XMM1,-020h[RBP]
	0x0F,0x53,0xCA,			// rcpps	XMM1,XMM2
	0x0F,0x53,0x4D,0xE0,		// rcpps	XMM1,-020h[RBP]
	0xF3,0x0F,0x53,0xCA,		// rcpss	XMM1,XMM2
	0xF3,0x0F,0x53,0x4D,0xD4,	// rcpss	XMM1,-02Ch[RBP]
	0x0F,0x52,0xCA,			// rsqrtps	XMM1,XMM2
	0x0F,0x52,0x4D,0xE0,		// rsqrtps	XMM1,-020h[RBP]
	0xF3,0x0F,0x52,0xCA,		// rsqrtss	XMM1,XMM2
	0xF3,0x0F,0x52,0x4D,0xD4,	// rsqrtss	XMM1,-02Ch[RBP]
0x66,	0x0F,0xC6,0xCA,0x03,		// shufpd	XMM1,XMM2,3
0x66,	0x0F,0xC6,0x4D,0xE0,0x04,	// shufpd	XMM1,-020h[RBP],4
	0x0F,0xC6,0xCA,0x03,		// shufps	XMM1,XMM2,3
	0x0F,0xC6,0x4D,0xE0,0x04,	// shufps	XMM1,-020h[RBP],4
0x66,	0x0F,0x2E,0xE6,			// ucimisd	XMM4,XMM6
0x66,	0x0F,0x2E,0x6D,0xD8,		// ucimisd	XMM5,-028h[RBP]
	0x0F,0x2E,0xF7,			// ucomiss	XMM6,XMM7
	0x0F,0x2E,0x7D,0xD4,		// ucomiss	XMM7,-02Ch[RBP]
0x66,	0x0F,0x15,0xE6,			// uppckhpd	XMM4,XMM6
0x66,	0x0F,0x15,0x6D,0xE0,		// uppckhpd	XMM5,-020h[RBP]
	0x0F,0x15,0xE6,			// unpckhps	XMM4,XMM6
	0x0F,0x15,0x6D,0xE0,		// unpckhps	XMM5,-020h[RBP]
0x66,	0x0F,0x14,0xE6,			// uppcklpd	XMM4,XMM6
0x66,	0x0F,0x14,0x6D,0xE0,		// uppcklpd	XMM5,-020h[RBP]
	0x0F,0x14,0xE6,			// unpcklps	XMM4,XMM6
	0x0F,0x14,0x6D,0xE0,		// unpcklps	XMM5,-020h[RBP]
0x66,	0x0F,0x57,0xCA,			// xorpd	XMM1,XMM2
0x66,	0x0F,0x57,0x4D,0xE0,		// xorpd	XMM1,-020h[RBP]
	0x0F,0x57,0xCA,			// xorps	XMM1,XMM2
	0x0F,0x57,0x4D,0xE0,		// xorps	XMM1,-020h[RBP]
    ];
    int i;

    asm
    {
	call	L1			;

	movmskpd ESI,XMM3		;
	movmskps ESI,XMM3		;

	movntdq	m128[RBP],XMM2		;
	movnti	m32[RBP],ECX		;
	movntpd	m128[RBP],XMM3		;
	movntps	m128[RBP],XMM4		;
	movntq	m64[RBP],MM5		;

	movq	MM1,MM2			;
	movq	MM2,m64[RBP]		;
	movq	m64[RBP],MM3		;
	movq	XMM1,XMM2		;
	movq	XMM2,m64[RBP]		;
	movq	m64[RBP],XMM3		;

	movq2dq	XMM3,MM2		;

	movsd				;
	movsd	XMM1,XMM2		;
	movsd	XMM3,m64[RBP]		;
	movsd	m64[RBP],XMM4		;

	movss	XMM1,XMM2		;
	movss	XMM3,m32[RBP]		;
	movss	m32[RBP],XMM4		;

	movupd	XMM1,XMM2		;
	movupd	XMM3,m128[RBP]		;
	movupd	m128[RBP],XMM4		;

	movups	XMM1,XMM2		;
	movups	XMM3,m128[RBP]		;
	movups	m128[RBP],XMM4		;

	orpd	XMM1,XMM2		;
	orpd	XMM3,m128[RBP]		;
	orps	XMM1,XMM2		;
	orps	XMM3,m128[RBP]		;

	packsswb MM1,MM2		;
	packsswb MM3,m64[RBP]		;
	packsswb XMM1,XMM2		;
	packsswb XMM3,m128[RBP]		;

	packssdw MM1,MM2		;
	packssdw MM3,m64[RBP]		;
	packssdw XMM1,XMM2		;
	packssdw XMM3,m128[RBP]		;

	packuswb MM1,MM2		;
	packuswb MM3,m64[RBP]		;
	packuswb XMM1,XMM2		;
	packuswb XMM3,m128[RBP]		;

	paddb	MM1,MM2			;
	paddb	MM3,m64[RBP]		;
	paddb	XMM1,XMM2		;
	paddb	XMM3,m128[RBP]		;

	paddw	MM1,MM2			;
	paddw	MM3,m64[RBP]		;
	paddw	XMM1,XMM2		;
	paddw	XMM3,m128[RBP]		;

	paddd	MM1,MM2			;
	paddd	MM3,m64[RBP]		;
	paddd	XMM1,XMM2		;
	paddd	XMM3,m128[RBP]		;

	paddq	MM1,MM2			;
	paddq	MM3,m64[RBP]		;
	paddq	XMM1,XMM2		;
	paddq	XMM3,m128[RBP]		;

	paddsb	MM1,MM2			;
	paddsb	MM3,m64[RBP]		;
	paddsb	XMM1,XMM2		;
	paddsb	XMM3,m128[RBP]		;

	paddsw	MM1,MM2			;
	paddsw	MM3,m64[RBP]		;
	paddsw	XMM1,XMM2		;
	paddsw	XMM3,m128[RBP]		;

	paddusb	MM1,MM2			;
	paddusb	MM3,m64[RBP]		;
	paddusb	XMM1,XMM2		;
	paddusb	XMM3,m128[RBP]		;

	paddusw	MM1,MM2			;
	paddusw	MM3,m64[RBP]		;
	paddusw	XMM1,XMM2		;
	paddusw	XMM3,m128[RBP]		;

	pand	MM1,MM2			;
	pand	MM3,m64[RBP]		;
	pand	XMM1,XMM2		;
	pand	XMM3,m128[RBP]		;

	pandn	MM1,MM2			;
	pandn	MM3,m64[RBP]		;
	pandn	XMM1,XMM2		;
	pandn	XMM3,m128[RBP]		;

	pavgb	MM1,MM2			;
	pavgb	MM3,m64[RBP]		;
	pavgb	XMM1,XMM2		;
	pavgb	XMM3,m128[RBP]		;

	pavgw	MM1,MM2			;
	pavgw	MM3,m64[RBP]		;
	pavgw	XMM1,XMM2		;
	pavgw	XMM3,m128[RBP]		;

	pcmpeqb	MM1,MM2			;
	pcmpeqb	MM3,m64[RBP]		;
	pcmpeqb	XMM1,XMM2		;
	pcmpeqb	XMM3,m128[RBP]		;

	pcmpeqw	MM1,MM2			;
	pcmpeqw	MM3,m64[RBP]		;
	pcmpeqw	XMM1,XMM2		;
	pcmpeqw	XMM3,m128[RBP]		;

	pcmpeqd	MM1,MM2			;
	pcmpeqd	MM3,m64[RBP]		;
	pcmpeqd	XMM1,XMM2		;
	pcmpeqd	XMM3,m128[RBP]		;

	pcmpgtb	MM1,MM2			;
	pcmpgtb	MM3,m64[RBP]		;
	pcmpgtb	XMM1,XMM2		;
	pcmpgtb	XMM3,m128[RBP]		;

	pcmpgtw	MM1,MM2			;
	pcmpgtw	MM3,m64[RBP]		;
	pcmpgtw	XMM1,XMM2		;
	pcmpgtw	XMM3,m128[RBP]		;

	pcmpgtd	MM1,MM2			;
	pcmpgtd	MM3,m64[RBP]		;
	pcmpgtd	XMM1,XMM2		;
	pcmpgtd	XMM3,m128[RBP]		;

	pextrw	EDX,MM6,7		;
	pextrw	EDX,XMM6,7		;

	pinsrw	MM6,EDX,7		;
	pinsrw	MM6,m16[RBP],7		;
	pinsrw	XMM6,EDX,7		;
	pinsrw	XMM6,m16[RBP],7		;

	pmaddwd	MM1,MM2			;
	pmaddwd	MM3,m64[RBP]		;
	pmaddwd	XMM1,XMM2		;
	pmaddwd	XMM3,m128[RBP]		;

	pmaxsw	MM1,MM2			;
	pmaxsw	MM3,m64[RBP]		;
	pmaxsw	XMM1,XMM2		;
	pmaxsw	XMM3,m128[RBP]		;

	pmaxub	MM1,MM2			;
	pmaxub	MM3,m64[RBP]		;
	pmaxub	XMM1,XMM2		;
	pmaxub	XMM3,m128[RBP]		;

	pminsw	MM1,MM2			;
	pminsw	MM3,m64[RBP]		;
	pminsw	XMM1,XMM2		;
	pminsw	XMM3,m128[RBP]		;

	pminub	MM1,MM2			;
	pminub	MM3,m64[RBP]		;
	pminub	XMM1,XMM2		;
	pminub	XMM3,m128[RBP]		;

	pmovmskb ECX,MM0		;
	pmovmskb ECX,XMM6		;

	pmulhuw	MM1,MM2			;
	pmulhuw	MM3,m64[RBP]		;
	pmulhuw	XMM1,XMM2		;
	pmulhuw	XMM3,m128[RBP]		;

	pmulhw	MM1,MM2			;
	pmulhw	MM3,m64[RBP]		;
	pmulhw	XMM1,XMM2		;
	pmulhw	XMM3,m128[RBP]		;

	pmullw	MM1,MM2			;
	pmullw	MM3,m64[RBP]		;
	pmullw	XMM1,XMM2		;
	pmullw	XMM3,m128[RBP]		;

	pmuludq	MM1,MM2			;
	pmuludq	MM3,m64[RBP]		;
	pmuludq	XMM1,XMM2		;
	pmuludq	XMM3,m128[RBP]		;

	por	MM1,MM2			;
	por	MM3,m64[RBP]		;
	por	XMM1,XMM2		;
	por	XMM3,m128[RBP]		;

	prefetcht0  m8[RBP]		;
	prefetcht1  m8[RBP]		;
	prefetcht2  m8[RBP]		;
	prefetchnta m8[RBP]		;

	psadbw	MM1,MM2			;
	psadbw	MM3,m64[RBP]		;
	psadbw	XMM1,XMM2		;
	psadbw	XMM3,m128[RBP]		;

	pshufd	XMM1,XMM2,3		;
	pshufd	XMM3,m128[RBP],3	;
	pshufhw	XMM1,XMM2,3		;
	pshufhw	XMM3,m128[RBP],3	;
	pshuflw	XMM1,XMM2,3		;
	pshuflw	XMM3,m128[RBP],3	;
	pshufw	MM1,MM2,3		;
	pshufw	MM3,m64[RBP],3		;

	pslldq	XMM1,0x18		;

	psllw	MM1,MM2			;
	psllw	MM1,m64[RBP]		;
	psllw	XMM1,XMM2		;
	psllw	XMM1,m128[RBP]		;
	psllw	MM1,0x15		;
	psllw	XMM1,0x15		;

	pslld	MM1,MM2			;
	pslld	MM1,m64[RBP]		;
	pslld	XMM1,XMM2		;
	pslld	XMM1,m128[RBP]		;
	pslld	MM1,0x15		;
	pslld	XMM1,0x15		;

	psllq	MM1,MM2			;
	psllq	MM1,m64[RBP]		;
	psllq	XMM1,XMM2		;
	psllq	XMM1,m128[RBP]		;
	psllq	MM1,0x15		;
	psllq	XMM1,0x15		;

	psraw	MM1,MM2			;
	psraw	MM1,m64[RBP]		;
	psraw	XMM1,XMM2		;
	psraw	XMM1,m128[RBP]		;
	psraw	MM1,0x15		;
	psraw	XMM1,0x15		;

	psrad	MM1,MM2			;
	psrad	MM1,m64[RBP]		;
	psrad	XMM1,XMM2		;
	psrad	XMM1,m128[RBP]		;
	psrad	MM1,0x15		;
	psrad	XMM1,0x15		;

	psrldq	XMM1,0x18		;

	psrlw	MM1,MM2			;
	psrlw	MM1,m64[RBP]		;
	psrlw	XMM1,XMM2		;
	psrlw	XMM1,m128[RBP]		;
	psrlw	MM1,0x15		;
	psrlw	XMM1,0x15		;

	psrld	MM1,MM2			;
	psrld	MM1,m64[RBP]		;
	psrld	XMM1,XMM2		;
	psrld	XMM1,m128[RBP]		;
	psrld	MM1,0x15		;
	psrld	XMM1,0x15		;

	psrlq	MM1,MM2			;
	psrlq	MM1,m64[RBP]		;
	psrlq	XMM1,XMM2		;
	psrlq	XMM1,m128[RBP]		;
	psrlq	MM1,0x15		;
	psrlq	XMM1,0x15		;

	psubb	MM1,MM2			;
	psubb	MM1,m64[RBP]		;
	psubb	XMM1,XMM2		;
	psubb	XMM1,m128[RBP]		;

	psubw	MM1,MM2			;
	psubw	MM1,m64[RBP]		;
	psubw	XMM1,XMM2		;
	psubw	XMM1,m128[RBP]		;

	psubd	MM1,MM2			;
	psubd	MM1,m64[RBP]		;
	psubd	XMM1,XMM2		;
	psubd	XMM1,m128[RBP]		;

	psubq	MM1,MM2			;
	psubq	MM1,m64[RBP]		;
	psubq	XMM1,XMM2		;
	psubq	XMM1,m128[RBP]		;

	psubsb	MM1,MM2			;
	psubsb	MM1,m64[RBP]		;
	psubsb	XMM1,XMM2		;
	psubsb	XMM1,m128[RBP]		;

	psubsw	MM1,MM2			;
	psubsw	MM1,m64[RBP]		;
	psubsw	XMM1,XMM2		;
	psubsw	XMM1,m128[RBP]		;

	psubusb	MM1,MM2			;
	psubusb	MM1,m64[RBP]		;
	psubusb	XMM1,XMM2		;
	psubusb	XMM1,m128[RBP]		;

	psubusw	MM1,MM2			;
	psubusw	MM1,m64[RBP]		;
	psubusw	XMM1,XMM2		;
	psubusw	XMM1,m128[RBP]		;

	punpckhbw MM1,MM2		;
	punpckhbw MM1,m64[RBP]		;
	punpckhbw XMM1,XMM2		;
	punpckhbw XMM1,m128[RBP]	;

	punpckhwd MM1,MM2		;
	punpckhwd MM1,m64[RBP]		;
	punpckhwd XMM1,XMM2		;
	punpckhwd XMM1,m128[RBP]	;

	punpckhdq MM1,MM2		;
	punpckhdq MM1,m64[RBP]		;
	punpckhdq XMM1,XMM2		;
	punpckhdq XMM1,m128[RBP]	;

	punpckhqdq XMM1,XMM2		;
	punpckhqdq XMM1,m128[RBP]	;

	punpcklbw MM1,MM2		;
	punpcklbw MM1,m64[RBP]		;
	punpcklbw XMM1,XMM2		;
	punpcklbw XMM1,m128[RBP]	;

	punpcklwd MM1,MM2		;
	punpcklwd MM1,m64[RBP]		;
	punpcklwd XMM1,XMM2		;
	punpcklwd XMM1,m128[RBP]	;

	punpckldq MM1,MM2		;
	punpckldq MM1,m64[RBP]		;
	punpckldq XMM1,XMM2		;
	punpckldq XMM1,m128[RBP]	;

	punpcklqdq XMM1,XMM2		;
	punpcklqdq XMM1,m128[RBP]	;

 	pxor	MM1,MM2			;
	pxor	MM1,m64[RBP]		;
	pxor	XMM1,XMM2		;
	pxor	XMM1,m128[RBP]		;

	rcpps	XMM1,XMM2		;
	rcpps	XMM1,m128[RBP]		;
	rcpss	XMM1,XMM2		;
	rcpss	XMM1,m32[RBP]		;

	rsqrtps	XMM1,XMM2		;
	rsqrtps	XMM1,m128[RBP]		;
	rsqrtss	XMM1,XMM2		;
	rsqrtss	XMM1,m32[RBP]		;

	shufpd	XMM1,XMM2,3		;
	shufpd	XMM1,m128[RBP],4	;
	shufps	XMM1,XMM2,3		;
	shufps	XMM1,m128[RBP],4	;

	ucomisd	XMM4,XMM6		;
	ucomisd	XMM5,m64[RBP]		;
	ucomiss	XMM6,XMM7		;
	ucomiss	XMM7,m32[RBP]		;

	unpckhpd XMM4,XMM6		;
	unpckhpd XMM5,m128[RBP]		;
	unpckhps XMM4,XMM6		;
	unpckhps XMM5,m128[RBP]		;
	unpcklpd XMM4,XMM6		;
	unpcklpd XMM5,m128[RBP]		;
	unpcklps XMM4,XMM6		;
	unpcklps XMM5,m128[RBP]		;

	xorpd	XMM1,XMM2		;
	xorpd	XMM1,m128[RBP]		;
	xorps	XMM1,XMM2		;
	xorps	XMM1,m128[RBP]		;
L1:					;
	pop	RBX			;
	mov	p[RBP],RBX		;
    }
    for (i = 0; i < data.length; i++)
    {
	//printf("data[%d] = 0x%02x, should be 0x%02x\n", i, p[i], data[i]);
	assert(p[i] == data[i]);
    }
}

/****************************************************/

void test15()
{
    int m32;
    long m64;
    M128 m128;
    ubyte *p;
    static ubyte data[] =
    [
	0x0F,0x0F,0xDC,0xBF, 		// pavgusb	MM3,MM4
	0x0F,0x0F,0x5D,0xD8,0xBF,	// pavgusb	MM3,-028h[RBP]
	0x0F,0x0F,0xDC,0x1D, 		// pf2id	MM3,MM4
	0x0F,0x0F,0x5D,0xD8,0x1D, 	// pf2id	MM3,-028h[RBP]
	0x0F,0x0F,0xDC,0xAE, 		// pfacc	MM3,MM4
	0x0F,0x0F,0x5D,0xD8,0xAE, 	// pfacc	MM3,-028h[RBP]
	0x0F,0x0F,0xDC,0x9E, 		// pfadd	MM3,MM4
	0x0F,0x0F,0x5D,0xD8,0x9E, 	// pfadd	MM3,-028h[RBP]
	0x0F,0x0F,0xDC,0xB0, 		// pfcmpeq	MM3,MM4
	0x0F,0x0F,0x5D,0xD8,0xB0, 	// pfcmpeq	MM3,-028h[RBP]
	0x0F,0x0F,0xDC,0x90, 		// pfcmpge	MM3,MM4
	0x0F,0x0F,0x5D,0xD8,0x90, 	// pfcmpge	MM3,-028h[RBP]
	0x0F,0x0F,0xDC,0xA0, 		// pfcmpgt	MM3,MM4
	0x0F,0x0F,0x5D,0xD8,0xA0, 	// pfcmpgt	MM3,-028h[RBP]
	0x0F,0x0F,0xDC,0xA4, 		// pfmax	MM3,MM4
	0x0F,0x0F,0x5D,0xD8,0x94, 	// pfmin	MM3,-028h[RBP]
	0x0F,0x0F,0xDC,0xB4, 		// pfmul	MM3,MM4
	0x0F,0x0F,0x5D,0xD8,0xB4, 	// pfmul	MM3,-028h[RBP]
	0x0F,0x0F,0xDC,0x8A, 		// pfnacc	MM3,MM4
	0x0F,0x0F,0x5D,0xD8,0x8E, 	// pfpnacc	MM3,-028h[RBP]
	0x0F,0x0F,0xDC,0x96, 		// pfrcp	MM3,MM4
	0x0F,0x0F,0x5D,0xD8,0x96, 	// pfrcp	MM3,-028h[RBP]
	0x0F,0x0F,0xDC,0xA6, 		// pfrcpit1	MM3,MM4
	0x0F,0x0F,0x5D,0xD8,0xA6, 	// pfrcpit1	MM3,-028h[RBP]
	0x0F,0x0F,0xDC,0xB6, 		// pfrcpit2	MM3,MM4
	0x0F,0x0F,0x5D,0xD8,0xB6, 	// pfrcpit2	MM3,-028h[RBP]
	0x0F,0x0F,0xDC,0x97, 		// pfrsqrt	MM3,MM4
	0x0F,0x0F,0x5D,0xD8,0xA7, 	// pfrsqit1	MM3,-028h[RBP]
	0x0F,0x0F,0xDC,0x9A, 		// pfsub	MM3,MM4
	0x0F,0x0F,0x5D,0xD8,0x9A, 	// pfsub	MM3,-028h[RBP]
	0x0F,0x0F,0xDC,0xAA, 		// pfsubr	MM3,MM4
	0x0F,0x0F,0x5D,0xD8,0xAA, 	// pfsubr	MM3,-028h[RBP]
	0x0F,0x0F,0xDC,0x0D, 		// pi2fd	MM3,MM4
	0x0F,0x0F,0x5D,0xD8,0x0D, 	// pi2fd	MM3,-028h[RBP]
	0x0F,0x0F,0xDC,0xB7, 		// pmulhrw	MM3,MM4
	0x0F,0x0F,0x5D,0xD8,0xB7, 	// pmulhrw	MM3,-028h[RBP]
	0x0F,0x0F,0xDC,0xBB, 		// pswapd	MM3,MM4
	0x0F,0x0F,0x5D,0xD8,0xBB, 	// pswapd	MM3,-028h[RBP]
    ];
    int i;

    asm
    {
	call	L1			;

	pavgusb	MM3,MM4			;
	pavgusb	MM3,m64[RBP]		;

	pf2id	MM3,MM4			;
	pf2id	MM3,m64[RBP]		;

	pfacc	MM3,MM4			;
	pfacc	MM3,m64[RBP]		;

	pfadd	MM3,MM4			;
	pfadd	MM3,m64[RBP]		;

	pfcmpeq	MM3,MM4			;
	pfcmpeq	MM3,m64[RBP]		;

	pfcmpge	MM3,MM4			;
	pfcmpge	MM3,m64[RBP]		;

	pfcmpgt	MM3,MM4			;
	pfcmpgt	MM3,m64[RBP]		;

	pfmax	MM3,MM4			;
	pfmin	MM3,m64[RBP]		;

	pfmul	MM3,MM4			;
	pfmul	MM3,m64[RBP]		;

	pfnacc	MM3,MM4			;
	pfpnacc	MM3,m64[RBP]		;

	pfrcp	MM3,MM4			;
	pfrcp	MM3,m64[RBP]		;

	pfrcpit1 MM3,MM4		;
	pfrcpit1 MM3,m64[RBP]		;

	pfrcpit2 MM3,MM4		;
	pfrcpit2 MM3,m64[RBP]		;

	pfrsqrt	 MM3,MM4		;
	pfrsqit1 MM3,m64[RBP]		;

	pfsub	MM3,MM4			;
	pfsub	MM3,m64[RBP]		;

	pfsubr	MM3,MM4			;
	pfsubr	MM3,m64[RBP]		;

	pi2fd	MM3,MM4			;
	pi2fd	MM3,m64[RBP]		;

	pmulhrw	MM3,MM4			;
	pmulhrw	MM3,m64[RBP]		;

	pswapd	MM3,MM4			;
	pswapd	MM3,m64[RBP]		;
L1:					;
	pop	RBX			;
	mov	p[RBP],RBX		;
    }
    for (i = 0; i < data.length; i++)
    {
	assert(p[i] == data[i]);
    }
}

/****************************************************/

struct S17 { char x[6]; }
__gshared S17 xx17;

void test17()
{
    ubyte *p;
    static ubyte data[] =
    [
	0x0F, 0x01, 0x10,    	// lgdt	[EAX]
	0x0F, 0x01, 0x18,   	// lidt	[EAX]
	0x0F, 0x01, 0x00,    	// sgdt	[EAX]
	0x0F, 0x01, 0x08,    	// sidt	[EAX]
    ];
    int i;

    asm
    {
	call	L1			;

	lgdt [RAX]			;
	lidt [RAX]			;
	sgdt [RAX]			;
	sidt [RAX]			;

	lgdt xx17			;
	lidt xx17			;
	sgdt xx17			;
	sidt xx17			;

L1:
	pop	RBX			;
	mov	p[RBP],RBX		;
    }
    for (i = 0; i < data.length; i++)
    {
	assert(p[i] == data[i]);
    }
}

/****************************************************/

void test18()
{
    ubyte *p;
    static ubyte data[] =
    [
	0xDB, 0xF1,		// fcomi ST,ST(1)
	0xDB, 0xF0,		// fcomi ST,ST(0)
	0xDB, 0xF2,		// fcomi ST,ST(2)

	0xDF, 0xF1,		// fcomip ST,ST(1)
	0xDF, 0xF0,		// fcomip ST,ST(0)
	0xDF, 0xF2,		// fcomip ST,ST(2)

	0xDB, 0xE9,		// fucomi ST,ST(1)
	0xDB, 0xE8,		// fucomi ST,ST(0)
	0xDB, 0xEB,		// fucomi ST,ST(3)

	0xDF, 0xE9,		// fucomip ST,ST(1)
	0xDF, 0xED,		// fucomip ST,ST(5)
	0xDF, 0xEC,		// fucomip ST,ST(4)
    ];
    int i;

    asm
    {
	call	L1			;

	fcomi				;
	fcomi   ST(0)			;
	fcomi   ST,ST(2)		;

	fcomip				;
	fcomip  ST(0)			;
	fcomip  ST,ST(2)		;

	fucomi				;
	fucomi  ST(0)			;
	fucomi  ST,ST(3)		;

	fucomip				;
	fucomip ST(5)			;
	fucomip ST,ST(4)		;

L1:
	pop	RBX			;
	mov	p[RBP],RBX		;
    }
    for (i = 0; i < data.length; i++)
    {
	assert(p[i] == data[i]);
    }
}

/****************************************************/

extern (C) {
   void foo19() { }
}

void test19()
{   void function() fp;
    ulong  x;
    ulong *p;

    asm
    {
	lea	RAX, qword ptr [foo19];
	mov	fp, RAX;
	mov	x, RAX;
	mov	p, RAX;
	call	fp;
    }
    (*fp)();
}

/****************************************************/
/+
void test20()
{
    ubyte *p;
    static ubyte data[] =
    [
	0x9B, 0xDB, 0xE0,	// feni
	0xDB, 0xE0,		// fneni

	0x9B, 0xDB, 0xE1,	// fdisi
	0xDB, 0xE1,		// fndisi

	0x9B, 0xDB, 0xE2,	// fclex
	0xDB, 0xE2,		// fnclex

	0x9B, 0xDB, 0xE3,	// finit
	0xDB, 0xE3,		// fninit

	0xDB, 0xE4,		// fsetpm
    ];
    int i;

    asm
    {
	call	L1			;

	feni				;
	fneni				;
	fdisi				;
	fndisi				;
	finit				;
	fninit				;
	fclex				;
	fnclex				;
	finit				;
	fninit				;
	fsetpm				;
L1:
	pop	RBX			;
	mov	p[RBP],RBX		;
    }
    for (i = 0; i < data.length; i++)
    {
	assert(p[i] == data[i]);
    }
}
+/
/****************************************************/

void test21()
{
    ubyte *p;
    static ubyte data[] =
    [
	0xE4, 0x06,       	// in	AL,6
	0x66, 0xE5, 0x07,       // in	AX,7
	0xE5, 0x08,       	// in	EAX,8
	0xEC,          		// in	AL,DX
	0x66, 0xED,          	// in	AX,DX
	0xED,          		// in	EAX,DX
	0xE6, 0x06,       	// out	6,AL
	0x66, 0xE7, 0x07,       // out	7,AX
	0xE7, 0x08,       	// out	8,EAX
	0xEE,          		// out	DX,AL
	0x66, 0xEF,          	// out	DX,AX
	0xEF,          		// out	DX,EAX
    ];
    int i;

    asm
    {
	call	L1	;

	in AL,6		;
	in AX,7		;
	in EAX,8	;
	in AL,DX	;
	in AX,DX	;
	in EAX,DX	;

	out 6,AL	;
	out 7,AX	;
	out 8,EAX	;
	out DX,AL	;
	out DX,AX	;
	out DX,EAX	;
L1:
	pop	RBX		;
	mov	p[RBP],RBX	;
    }
    for (i = 0; i < data.length; i++)
    {
	assert(p[i] == data[i]);
    }
}

/****************************************************/

void test22()
{
    ubyte *p;
    static ubyte data[] =
    [
	0x0F, 0xC7, 0x4D, 0xE0,	// cmpxchg8b
0x48,	0x0F, 0xC7, 0x4D, 0xF0 	// cmpxchg16b
    ];
    int i;
    M64  m64;
    M128 m128;

    asm
    {
	call	L1			;

	cmpxchg8b  m64			;
	cmpxchg16b m128			;
L1:
	pop	RBX			;
	mov	p[RBP],RBX		;
    }
    for (i = 0; i < data.length; i++)
    {
	assert(p[i] == data[i]);
    }
}

/****************************************************/

void test23()
{
    short m16;
    int m32;
    long m64;
    M128 m128;
    ubyte *p;
    static ubyte data[] =
    [
	0xD9, 0xC9,		// fxch		ST(1), ST(0)

	0xDF, 0x5D, 0xD0,    	// fistp	word ptr -030h[RBP]
	0xDB, 0x5D, 0xD4,    	// fistp	dword ptr -02Ch[RBP]
	0xDF, 0x7D, 0xD8,    	// fistp	long64 ptr -028h[RBP]
	0xDF, 0x4D, 0xD0,    	// fisttp	short ptr -030h[RBP]
	0xDB, 0x4D, 0xD4,    	// fisttp	word ptr -02Ch[RBP]
	0xDD, 0x4D, 0xD8,    	// fisttp	long64 ptr -028h[RBP]
	0x0F, 0x01, 0xC8,    	// monitor
	0x0F, 0x01, 0xC9,    	// mwait

	0x66, 0x0F, 0xD0, 0xCA,    	// addsubpd	XMM1,XMM2
	0x66, 0x0F, 0xD0, 0x4D, 0xE0, 	// addsubpd	XMM1,-020h[RBP]
	0xF2, 0x0F, 0xD0, 0xCA, 	// addsubps	XMM1,XMM2
	0xF2, 0x0F, 0xD0, 0x4D, 0xE0, 	// addsubps	XMM1,-020h[RBP]
	0x66, 0x0F, 0x7C, 0xCA,    	// haddpd	XMM1,XMM2
	0x66, 0x0F, 0x7C, 0x4D, 0xE0, 	// haddpd	XMM1,-020h[RBP]
	0xF2, 0x0F, 0x7C, 0xCA, 	// haddps	XMM1,XMM2
	0xF2, 0x0F, 0x7C, 0x4D, 0xE0, 	// haddps	XMM1,-020h[RBP]
	0x66, 0x0F, 0x7D, 0xCA,    	// hsubpd	XMM1,XMM2
	0x66, 0x0F, 0x7D, 0x4D, 0xE0, 	// hsubpd	XMM1,-020h[RBP]
	0xF2, 0x0F, 0x7D, 0xCA, 	// hsubps	XMM1,XMM2
	0xF2, 0x0F, 0x7D, 0x4D, 0xE0, 	// hsubps	XMM1,-020h[RBP]
	0xF2, 0x0F, 0xF0, 0x4D, 0xE0, 	// lddqu	XMM1,-020h[RBP]
	0xF2, 0x0F, 0x12, 0xCA, 	// movddup	XMM1,XMM2
	0xF2, 0x0F, 0x12, 0x4D, 0xD8, 	// movddup	XMM1,-028h[RBP]
	0xF3, 0x0F, 0x16, 0xCA, 	// movshdup	XMM1,XMM2
	0xF3, 0x0F, 0x16, 0x4D, 0xE0, 	// movshdup	XMM1,-020h[RBP]
	0xF3, 0x0F, 0x12, 0xCA, 	// movsldup	XMM1,XMM2
	0xF3, 0x0F, 0x12, 0x4D, 0xE0, 	// movsldup	XMM1,-020h[RBP]
    ];
    int i;

    asm
    {
	call	L1			;

	fxch	ST(1), ST(0)		;

	fistp	m16[RBP]		;
	fistp	m32[RBP]		;
	fistp	m64[RBP]		;

	fisttp	m16[RBP]		;
	fisttp	m32[RBP]		;
	fisttp	m64[RBP]		;

	monitor				;
	mwait				;

	addsubpd	XMM1,XMM2	;
	addsubpd	XMM1,m128[RBP]	;

	addsubps	XMM1,XMM2	;
	addsubps	XMM1,m128[RBP]	;

	haddpd		XMM1,XMM2	;
	haddpd		XMM1,m128[RBP]	;

	haddps		XMM1,XMM2	;
	haddps		XMM1,m128[RBP]	;

	hsubpd		XMM1,XMM2	;
	hsubpd		XMM1,m128[RBP]	;

	hsubps		XMM1,XMM2	;
	hsubps		XMM1,m128[RBP]	;

	lddqu		XMM1,m128[RBP]	;

	movddup		XMM1,XMM2	;
	movddup		XMM1,m64[RBP]	;

	movshdup	XMM1,XMM2	;
	movshdup	XMM1,m128[RBP]	;

	movsldup	XMM1,XMM2	;
	movsldup	XMM1,m128[RBP]	;

L1:					;
	pop	RBX			;
	mov	p[RBP],RBX		;
    }
    for (i = 0; i < data.length; i++)
    {
	assert(p[i] == data[i]);
    }
}

/****************************************************/

void test24()
{
	ushort i;

	asm
	{
	    lea AX, i;
	    mov i, AX;
	}
	assert(cast(ushort)&i == i);
}

/****************************************************/

void test25()
{
    short m16;
    int m32;
    long m64;
    M128 m128;
    ubyte *p;
    static ubyte data[] =
    [
	0x66, 0x0F, 0x7E, 0xC1,    	// movd	ECX,XMM0
	0x66, 0x0F, 0x7E, 0xC9,    	// movd	ECX,XMM1
	0x66, 0x0F, 0x7E, 0xD1,    	// movd	ECX,XMM2
	0x66, 0x0F, 0x7E, 0xD9,    	// movd	ECX,XMM3
	0x66, 0x0F, 0x7E, 0xE1,    	// movd	ECX,XMM4
	0x66, 0x0F, 0x7E, 0xE9,    	// movd	ECX,XMM5
	0x66, 0x0F, 0x7E, 0xF1,    	// movd	ECX,XMM6
	0x66, 0x0F, 0x7E, 0xF9,    	// movd	ECX,XMM7
	0x0F, 0x7E, 0xC1,	    	// movd	ECX,MM0
	0x0F, 0x7E, 0xC9,	    	// movd	ECX,MM1
	0x0F, 0x7E, 0xD1,	    	// movd	ECX,MM2
	0x0F, 0x7E, 0xD9,	    	// movd	ECX,MM3
	0x0F, 0x7E, 0xE1,	    	// movd	ECX,MM4
	0x0F, 0x7E, 0xE9,	    	// movd	ECX,MM5
	0x0F, 0x7E, 0xF1,	    	// movd	ECX,MM6
	0x0F, 0x7E, 0xF9,	    	// movd	ECX,MM7
	0x66, 0x0F, 0x6E, 0xC1,    	// movd	XMM0,ECX
	0x66, 0x0F, 0x6E, 0xC9,    	// movd	XMM1,ECX
	0x66, 0x0F, 0x6E, 0xD1,    	// movd	XMM2,ECX
	0x66, 0x0F, 0x6E, 0xD9,    	// movd	XMM3,ECX
	0x66, 0x0F, 0x6E, 0xE1,    	// movd	XMM4,ECX
	0x66, 0x0F, 0x6E, 0xE9,    	// movd	XMM5,ECX
	0x66, 0x0F, 0x6E, 0xF1,    	// movd	XMM6,ECX
	0x66, 0x0F, 0x6E, 0xF9,    	// movd	XMM7,ECX
	0x0F, 0x6E, 0xC1,	    	// movd	MM0,ECX
	0x0F, 0x6E, 0xC9,	    	// movd	MM1,ECX
	0x0F, 0x6E, 0xD1,	    	// movd	MM2,ECX
	0x0F, 0x6E, 0xD9,	    	// movd	MM3,ECX
	0x0F, 0x6E, 0xE1,	    	// movd	MM4,ECX
	0x0F, 0x6E, 0xE9,	    	// movd	MM5,ECX
	0x0F, 0x6E, 0xF1,	    	// movd	MM6,ECX
	0x0F, 0x6E, 0xF9,	    	// movd	MM7,ECX
	0x66, 0x0F, 0x7E, 0xC8,    	// movd	EAX,XMM1
	0x66, 0x0F, 0x7E, 0xCB,    	// movd	EBX,XMM1
	0x66, 0x0F, 0x7E, 0xC9,    	// movd	ECX,XMM1
	0x66, 0x0F, 0x7E, 0xCA,    	// movd	EDX,XMM1
	0x66, 0x0F, 0x7E, 0xCE,    	// movd	ESI,XMM1
	0x66, 0x0F, 0x7E, 0xCF,    	// movd	EDI,XMM1
	0x66, 0x0F, 0x7E, 0xCD,    	// movd	EBP,XMM1
	0x66, 0x0F, 0x7E, 0xCC,    	// movd	ESP,XMM1
	0x0F, 0x7E, 0xC8,	    	// movd	EAX,MM1
	0x0F, 0x7E, 0xCB,	    	// movd	EBX,MM1
	0x0F, 0x7E, 0xC9,	    	// movd	ECX,MM1
	0x0F, 0x7E, 0xCA,	    	// movd	EDX,MM1
	0x0F, 0x7E, 0xCE,	    	// movd	ESI,MM1
	0x0F, 0x7E, 0xCF,	    	// movd	EDI,MM1
	0x0F, 0x7E, 0xCD,	    	// movd	EBP,MM1
	0x0F, 0x7E, 0xCC,	    	// movd	ESP,MM1
	0x66, 0x0F, 0x6E, 0xC8,    	// movd	XMM1,EAX
	0x66, 0x0F, 0x6E, 0xCB,    	// movd	XMM1,EBX
	0x66, 0x0F, 0x6E, 0xC9,    	// movd	XMM1,ECX
	0x66, 0x0F, 0x6E, 0xCA,    	// movd	XMM1,EDX
	0x66, 0x0F, 0x6E, 0xCE,    	// movd	XMM1,ESI
	0x66, 0x0F, 0x6E, 0xCF,    	// movd	XMM1,EDI
	0x66, 0x0F, 0x6E, 0xCD,    	// movd	XMM1,EBP
	0x66, 0x0F, 0x6E, 0xCC,    	// movd	XMM1,ESP
	0x0F, 0x6E, 0xC8,	    	// movd	MM1,EAX
	0x0F, 0x6E, 0xCB,	    	// movd	MM1,EBX
	0x0F, 0x6E, 0xC9,	    	// movd	MM1,ECX
	0x0F, 0x6E, 0xCA,	    	// movd	MM1,EDX
	0x0F, 0x6E, 0xCE,	    	// movd	MM1,ESI
	0x0F, 0x6E, 0xCF,	    	// movd	MM1,EDI
	0x0F, 0x6E, 0xCD,	    	// movd	MM1,EBP
	0x0F, 0x6E, 0xCC,	    	// movd	MM1,ESP
    ];
    int i;

    asm
    {
	call	L1			;

	movd ECX, XMM0;
	movd ECX, XMM1;
	movd ECX, XMM2;
	movd ECX, XMM3;
	movd ECX, XMM4;
	movd ECX, XMM5;
	movd ECX, XMM6;
	movd ECX, XMM7;

	movd ECX, MM0;
	movd ECX, MM1;
	movd ECX, MM2;
	movd ECX, MM3;
	movd ECX, MM4;
	movd ECX, MM5;
	movd ECX, MM6;
	movd ECX, MM7;

	movd XMM0, ECX;
	movd XMM1, ECX;
	movd XMM2, ECX;
	movd XMM3, ECX;
	movd XMM4, ECX;
	movd XMM5, ECX;
	movd XMM6, ECX;
	movd XMM7, ECX;

	movd MM0, ECX;
	movd MM1, ECX;
	movd MM2, ECX;
	movd MM3, ECX;
	movd MM4, ECX;
	movd MM5, ECX;
	movd MM6, ECX;
	movd MM7, ECX;

	movd EAX, XMM1;
	movd EBX, XMM1;
	movd ECX, XMM1;
	movd EDX, XMM1;
	movd ESI, XMM1;
	movd EDI, XMM1;
	movd EBP, XMM1;
	movd ESP, XMM1;

	movd EAX, MM1;
	movd EBX, MM1;
	movd ECX, MM1;
	movd EDX, MM1;
	movd ESI, MM1;
	movd EDI, MM1;
	movd EBP, MM1;
	movd ESP, MM1;

	movd XMM1, EAX;
	movd XMM1, EBX;
	movd XMM1, ECX;
	movd XMM1, EDX;
	movd XMM1, ESI;
	movd XMM1, EDI;
	movd XMM1, EBP;
	movd XMM1, ESP;

	movd MM1, EAX;
	movd MM1, EBX;
	movd MM1, ECX;
	movd MM1, EDX;
	movd MM1, ESI;
	movd MM1, EDI;
	movd MM1, EBP;
	movd MM1, ESP;

L1:					;
	pop	RBX			;
	mov	p[RBP],RBX		;
    }
    for (i = 0; i < data.length; i++)
    {
	assert(p[i] == data[i]);
    }
}

/****************************************************/

void fn26(ref byte val)
{
    asm
    {
        mov RAX, val;
        inc byte ptr [RAX];
    }
}

void test26()
{
    byte b;
    //printf( "%i\n", b );
    assert(b == 0);
    fn26(b);
    //printf( "%i\n", b );
    assert(b == 1);
}

/****************************************************/

void test27()
{
    static const ubyte[16] a =
    [0, 1, 2, 3, 4, 5, 6, 7, 8 ,9, 0xA, 0xB, 0xC, 0xD, 0xE, 0xF];

    version (Windows)
    {
    asm
    {
	    movdqu XMM0, a;
	    pslldq XMM0, 2;
    }
    }
}

/****************************************************/

/*
PASS:
        cfloat z;
        cfloat[1] z;
        double z;
        double[1] b;
        long z;
        long[1] z;

FAIL: (bad type/size of operands 'movq')
        byte[8] z;
        char[8] z;
        dchar[2] z;
        float[2] z;
        int[2] z;
        short[4] z;
        wchar[4] z;

XPASS: (too small, but accecpted by DMD)
        cfloat[0] z;
        double[0] z;
        long[0] z;
 */

void test28()
{
//    version (Windows)
//    {
	cfloat[4] z = void;
	static const ubyte[8] A = [3, 4, 9, 0, 1, 3, 7, 2];
	ubyte[8] b;

	asm{
		movq MM0, z;
		movq MM0, A;
		movq b, MM0;
	}
	
	for(size_t i = 0; i < A.length; i++)
	{
		if(A[i] != b[i])
		{
			assert(0);
		}
	}
//    }
}

/****************************************************/
/+
shared int[5] bar29 = [3, 4, 5, 6, 7];

void test29()
{
    int* x;
    asm
    {
	push offsetof bar29;
	pop EAX;
	mov x, EAX;
    }
    assert(*x == 3);

    asm
    {
	mov EAX, offsetof bar29;
	mov x, EAX;
    }
    assert(*x == 3);
}
+/
/****************************************************/

const int CONST_OFFSET30 = 10;

void foo30()
{
	asm
	{
		mov EDX, 10;
		mov EAX, [RDX + CONST_OFFSET30];
	}
}

void test30()
{
}

/****************************************************/

void test31()
{
    ubyte *p;
    static ubyte data[] =
    [
	0xF7, 0xD8,       	// neg	EAX
	0x74, 0x04,       	// je	L8
	0xF7, 0xD8,       	// neg	EAX
	0x75, 0xFC,       	// jne	L4
	0xFF, 0xC0,       	// inc	EAX
    ];
    int i;

    asm
    {
	call	L1			;

	neg     EAX;
	je      L2;
    L3:
	neg     EAX;
	jne     L3;
    L2:
	inc     EAX;

L1:					;
	pop	RBX			;
	mov	p[RBP],RBX		;
    }
    for (i = 0; i < data.length; i++)
    {
	assert(p[i] == data[i]);
    }
}

/****************************************************/

void infiniteAsmLoops()
{

    /* This crashes DMD 0.162: */
    for (;;) asm { inc EAX; }

    /* It doesn't seem to matter what you use. These all crash: */
    //for (;;) asm { mov EAX, EBX; }
    //for (;;) asm { xor EAX, EAX; }
    //for (;;) asm { push 0; pop RAX; }
    //for (;;) asm { jmp infiniteAsmLoops; }

    /* This is a workaround: */
    for (bool a = true; a;) asm { hlt; }                    // compiles
    /* But this isn't: */
    //for (const bool a = true; a;) asm{ hlt; }             // crashes DMD

    /* It's not restricted to for-statements: */
    //while(1) asm { hlt; }                                 // crashes DMD
    /* This compiles: */
    {
        bool a = true;
        while(a) asm { hlt; }
    }
    /* But again, this doesn't: */
    /*
    {
        const bool a = true;    // note the const
        while(a) asm { hlt; }
    }
    //*/

    //do { asm { hlt; } } while (1);                          // crashes DMD
    /* This, of course, compiles: */
    {
        bool a = true;
        do asm { hlt; } while (a);
    }
    /* But predicably, this doesn't: */
    /*
    {
        const bool a = true;
        do asm { hlt; } while (a);
    }
    //**/

    /* Not even hand-coding the loop works: */
    /*
    {
label:
        asm { hlt; }   // commenting out this line to make it compile
        goto label;
    }
    //*/
    /* Unless you go all the way: (i.e. this compiles) */
    asm
    {
L1:
        hlt;
        jmp L1;
    }

    /* or like this (also compiles): */
    static void test()
    {
        asm { naked; hlt; jmp test; }
    }
    test();


    /* Wait... it gets weirder: */

    /* This also doesn't compile: */
    /*
    for (;;)
    {
        printf("\n");
        asm { hlt; }
    }
    //*/
    /* But this does: */
    //*
    for (;;)
    {
        asm { hlt; }
        printf("\n");
    }
    //*/
    /* The same loop that doesn't compile above
     * /does/ compile after previous one:
     */
    //*
    for (;;)
    {
        printf("\n");
        asm { hlt; }
    }
    //*/


    /* Note: this one is at the end because it seems to also trigger the
     * "now it works" event of the loop above.
     */
    /* There has to be /something/ in that asm block: */
    for (;;) asm {}                                         // compiles
}

void test32()
{
}

/****************************************************/

void test33()
{
    int x = 1;

    alias x y;

    asm
    {
	mov EAX, x;
	mov EAX, y;
    }
}

/****************************************************/

int test34()
{
    asm{
       jmp label;
    }

    return 0;
 label:
    return 1;
}

/****************************************************/
/+
void foo35() { printf("hello\n"); }

void test35()
{
    void function() p;
    ulong q;

    asm
    {
	mov ECX, foo35		;
	mov q, ECX		;
	lea EDX, foo35		;
	mov p, EDX		;
    }
    assert(p == &foo35);
    assert(q == *cast(ulong *)p);
}

/****************************************************/

void func36()
{
}

int test36()
{
  void*  a = &func36;
  ulong* b = cast(ulong*) a;
  ulong  f = *b;
  ulong  g;

  asm{
     mov RAX, func36;
     mov g, RAX;
  }

  if(f != g){
     assert(0);
  }
}
+/
/****************************************************/

void a37(X...)(X expr)
{
    alias expr[0] var1;
    asm {
        fld double ptr expr[0];
        fstp double ptr var1;
    }
}

void test37()
{
   a37(3.6);
}

/****************************************************/

int f38(X...)(X x)
{
    asm {
        mov EAX, int ptr x[1];
    }
}

int g38(X...)(X x)
{
    asm {
        mov EAX, x[1];
    }
}

void test38()
{
    assert(456 == f38(123, 456));
    assert(456 == g38(123, 456));
}

/****************************************************/

void test39()
{
    goto end;
    const byte z = 35;
    asm { db z; }
    end: ;
}

/****************************************************/

void test40()
{
    printf("");
    const string s = "abcdefghi";
    asm
    {	jmp L1;
	ds s;
    L1:;
    }
    end: ;
}

/****************************************************/

void test41()
{
    ubyte *p;
    static ubyte data[] =
    [
	0x66,0x0F,0x28,0x0C,0x06, 	// movapd	XMM1,[RAX][RSI]
	0x66,0x0F,0x28,0x0C,0x06, 	// movapd	XMM1,[RAX][RSI]
	0x66,0x0F,0x28,0x0C,0x46, 	// movapd	XMM1,[RAX*2][RSI]
	0x66,0x0F,0x28,0x0C,0x86, 	// movapd	XMM1,[RAX*4][RSI]
	0x66,0x0F,0x28,0x0C,0xC6, 	// movapd	XMM1,[RAX*8][RSI]
    ];
    int i;

    asm
    {
	call	L1			;

        movapd XMM1, [RSI+RAX];
        movapd XMM1, [RSI+1*RAX];
        movapd XMM1, [RSI+2*RAX];
        movapd XMM1, [RSI+4*RAX];
        movapd XMM1, [RSI+8*RAX];

L1:					;
	pop	RBX			;
	mov	p[RBP],RBX		;
    }
    for (i = 0; i < data.length; i++)
    {
	assert(p[i] == data[i]);
    }
}


/****************************************************/

enum
{
    enumeration42 = 1,
}

void test42()
{
    asm
    {
	mov EAX, enumeration42;
    }
}

/****************************************************/

void foo43()
{
    asm {lea EAX, [0*4+EAX]; }
    asm {lea EAX, [4*0+EAX]; }
    asm {lea EAX, [EAX+4*0]; }
    asm {lea EAX, [0+EAX]; }
    asm {lea EAX, [7*7+EAX]; }
}

void test43()
{
}

/****************************************************/

enum n1 = 42;
enum { n2 = 42 }

uint retN1() {
    asm {
        mov EAX,n1; // No! - mov EAX,-4[EBP]
    }
}

uint retN2() {
    asm {
        mov EAX,n2; // OK - mov EAX,02Ah
    }
}

void test44()
{
    assert(retN1() == 42);
    assert(retN2() == 42);
}

/****************************************************/

void test45()
{
    ubyte *p;
    static ubyte data[] =
    [
	0xDA, 0xC0,       // fcmovb	ST(0)
	0xDA, 0xC1,       // fcmovb
	0xDA, 0xCA,       // fcmove	ST(2)
	0xDA, 0xD3,       // fcmovbe	ST(3)
	0xDA, 0xDC,       // fcmovu	ST(4)
	0xDB, 0xC5,       // fcmovnb	ST(5)
	0xDB, 0xCE,       // fcmovne	ST(6)
	0xDB, 0xD7,       // fcmovnbe	ST(7)
	0xDB, 0xD9,       // fcmovnu
    ];
    int i;

    asm
    {
	call	L1			;

	fcmovb   ST, ST(0);
	fcmovb   ST, ST(1);
	fcmove   ST, ST(2);
	fcmovbe  ST, ST(3);
	fcmovu   ST, ST(4);
	fcmovnb  ST, ST(5);
	fcmovne  ST, ST(6);
	fcmovnbe ST, ST(7);
	fcmovnu  ST, ST(1);

L1:					;
	pop	RBX			;
	mov	p[RBP],RBX		;
    }
    for (i = 0; i < data.length; i++)
    {
	assert(p[i] == data[i]);
    }
}

/****************************************************/

void test46()
{
    ubyte *p;
    static ubyte data[] =
    [
	0x66, 0x0F, 0x3A, 0x41, 0xCA, 0x08,	// dppd XMM1,XMM2,8
	0x66, 0x0F, 0x3A, 0x40, 0xDC, 0x07,	// dpps XMM3,XMM4,7
	0x66, 0x0F, 0x50, 0xF3,			// movmskpd ESI,XMM3
	0x66, 0x0F, 0x50, 0xC7,			// movmskpd EAX,XMM7
	0x0F, 0x50, 0xC7,			// movmskps EAX,XMM7
	0x0F, 0xD7, 0xC7,			// pmovmskb EAX,MM7
	0x66, 0x0F, 0xD7, 0xC7,			// pmovmskb EAX,XMM7
    ];
    int i;

    asm
    {
	call	L1			;

	dppd	XMM1,XMM2,8		;
	dpps	XMM3,XMM4,7		;
	movmskpd ESI,XMM3		;
	movmskpd EAX,XMM7		;
	movmskps EAX,XMM7		;
	pmovmskb EAX,MM7		;
	pmovmskb EAX,XMM7		;

L1:					;
	pop	RBX			;
	mov	p[RBP],RBX		;
    }
    for (i = 0; i < data.length; i++)
    {
	assert(p[i] == data[i]);
    }
}

/****************************************************/
/+
struct Foo47
{
    float x,y;
}

void bar47(Foo47 f)
{
  int i;
  asm
  {
    mov EAX, offsetof f;
    mov i, EAX;
  }
  printf("%d\n",i);
  assert(i == 8);
}

void test47()
{
    Foo47 f;
    bar47(f);
}
+/
/****************************************************/

void func48(void delegate () callback)
{
    callback();
}

void test48()
{
    func48(() { asm{ mov EAX,EAX; }; });
}

/****************************************************/

void test49()
{
    ubyte *p;
    static ubyte data[] =
    [
	0x00, 0xC0,       	// add	AL,AL
	0x00, 0xD8,       	// add	AL,BL
	0x00, 0xC8,       	// add	AL,CL
	0x00, 0xD0,       	// add	AL,DL
	0x00, 0xE0,       	// add	AL,AH
	0x00, 0xF8,       	// add	AL,BH
	0x00, 0xE8,       	// add	AL,CH
	0x00, 0xF0,       	// add	AL,DH
	0x00, 0xC4,       	// add	AH,AL
	0x00, 0xDC,       	// add	AH,BL
	0x00, 0xCC,       	// add	AH,CL
	0x00, 0xD4,       	// add	AH,DL
	0x00, 0xE4,       	// add	AH,AH
	0x00, 0xFC,       	// add	AH,BH
	0x00, 0xEC,       	// add	AH,CH
	0x00, 0xF4,       	// add	AH,DH
	0x00, 0xC3,       	// add	BL,AL
	0x00, 0xDB,       	// add	BL,BL
	0x00, 0xCB,       	// add	BL,CL
	0x00, 0xD3,       	// add	BL,DL
	0x00, 0xE3,       	// add	BL,AH
	0x00, 0xFB,       	// add	BL,BH
	0x00, 0xEB,       	// add	BL,CH
	0x00, 0xF3,       	// add	BL,DH
	0x00, 0xC7,       	// add	BH,AL
	0x00, 0xDF,       	// add	BH,BL
	0x00, 0xCF,       	// add	BH,CL
	0x00, 0xD7,       	// add	BH,DL
	0x00, 0xE7,       	// add	BH,AH
	0x00, 0xFF,       	// add	BH,BH
	0x00, 0xEF,       	// add	BH,CH
	0x00, 0xF7,       	// add	BH,DH
	0x00, 0xC1,       	// add	CL,AL
	0x00, 0xD9,       	// add	CL,BL
	0x00, 0xC9,       	// add	CL,CL
	0x00, 0xD1,       	// add	CL,DL
	0x00, 0xE1,       	// add	CL,AH
	0x00, 0xF9,       	// add	CL,BH
	0x00, 0xE9,       	// add	CL,CH
	0x00, 0xF1,       	// add	CL,DH
	0x00, 0xC5,       	// add	CH,AL
	0x00, 0xDD,       	// add	CH,BL
	0x00, 0xCD,       	// add	CH,CL
	0x00, 0xD5,       	// add	CH,DL
	0x00, 0xE5,       	// add	CH,AH
	0x00, 0xFD,       	// add	CH,BH
	0x00, 0xED,       	// add	CH,CH
	0x00, 0xF5,       	// add	CH,DH
	0x00, 0xC2,       	// add	DL,AL
	0x00, 0xDA,       	// add	DL,BL
	0x00, 0xCA,       	// add	DL,CL
	0x00, 0xD2,       	// add	DL,DL
	0x00, 0xE2,       	// add	DL,AH
	0x00, 0xFA,       	// add	DL,BH
	0x00, 0xEA,       	// add	DL,CH
	0x00, 0xF2,       	// add	DL,DH
	0x00, 0xC6,       	// add	DH,AL
	0x00, 0xDE,       	// add	DH,BL
	0x00, 0xCE,       	// add	DH,CL
	0x00, 0xD6,       	// add	DH,DL
	0x00, 0xE6,       	// add	DH,AH
	0x00, 0xFE,       	// add	DH,BH
	0x00, 0xEE,       	// add	DH,CH
	0x00, 0xF6,       	// add	DH,DH
	0x66, 0x01, 0xC0,      	// add	AX,AX
	0x66, 0x01, 0xD8,      	// add	AX,BX
	0x66, 0x01, 0xC8,      	// add	AX,CX
	0x66, 0x01, 0xD0,      	// add	AX,DX
	0x66, 0x01, 0xF0,      	// add	AX,SI
	0x66, 0x01, 0xF8,      	// add	AX,DI
	0x66, 0x01, 0xE8,      	// add	AX,BP
	0x66, 0x01, 0xE0,      	// add	AX,SP
	0x66, 0x01, 0xC3,      	// add	BX,AX
	0x66, 0x01, 0xDB,      	// add	BX,BX
	0x66, 0x01, 0xCB,      	// add	BX,CX
	0x66, 0x01, 0xD3,      	// add	BX,DX
	0x66, 0x01, 0xF3,      	// add	BX,SI
	0x66, 0x01, 0xFB,      	// add	BX,DI
	0x66, 0x01, 0xEB,      	// add	BX,BP
	0x66, 0x01, 0xE3,      	// add	BX,SP
	0x66, 0x01, 0xC1,      	// add	CX,AX
	0x66, 0x01, 0xD9,      	// add	CX,BX
	0x66, 0x01, 0xC9,      	// add	CX,CX
	0x66, 0x01, 0xD1,      	// add	CX,DX
	0x66, 0x01, 0xF1,      	// add	CX,SI
	0x66, 0x01, 0xF9,      	// add	CX,DI
	0x66, 0x01, 0xE9,      	// add	CX,BP
	0x66, 0x01, 0xE1,      	// add	CX,SP
	0x66, 0x01, 0xC2,      	// add	DX,AX
	0x66, 0x01, 0xDA,      	// add	DX,BX
	0x66, 0x01, 0xCA,      	// add	DX,CX
	0x66, 0x01, 0xD2,      	// add	DX,DX
	0x66, 0x01, 0xF2,      	// add	DX,SI
	0x66, 0x01, 0xFA,      	// add	DX,DI
	0x66, 0x01, 0xEA,      	// add	DX,BP
	0x66, 0x01, 0xE2,      	// add	DX,SP
	0x66, 0x01, 0xC6,      	// add	SI,AX
	0x66, 0x01, 0xDE,      	// add	SI,BX
	0x66, 0x01, 0xCE,      	// add	SI,CX
	0x66, 0x01, 0xD6,      	// add	SI,DX
	0x66, 0x01, 0xF6,      	// add	SI,SI
	0x66, 0x01, 0xFE,      	// add	SI,DI
	0x66, 0x01, 0xEE,      	// add	SI,BP
	0x66, 0x01, 0xE6,      	// add	SI,SP
	0x66, 0x01, 0xC7,      	// add	DI,AX
	0x66, 0x01, 0xDF,      	// add	DI,BX
	0x66, 0x01, 0xCF,      	// add	DI,CX
	0x66, 0x01, 0xD7,      	// add	DI,DX
	0x66, 0x01, 0xF7,      	// add	DI,SI
	0x66, 0x01, 0xFF,      	// add	DI,DI
	0x66, 0x01, 0xEF,      	// add	DI,BP
	0x66, 0x01, 0xE7,      	// add	DI,SP
	0x66, 0x01, 0xC5,      	// add	BP,AX
	0x66, 0x01, 0xDD,      	// add	BP,BX
	0x66, 0x01, 0xCD,      	// add	BP,CX
	0x66, 0x01, 0xD5,      	// add	BP,DX
	0x66, 0x01, 0xF5,      	// add	BP,SI
	0x66, 0x01, 0xFD,      	// add	BP,DI
	0x66, 0x01, 0xED,      	// add	BP,BP
	0x66, 0x01, 0xE5,      	// add	BP,SP
	0x66, 0x01, 0xC4,      	// add	SP,AX
	0x66, 0x01, 0xDC,      	// add	SP,BX
	0x66, 0x01, 0xCC,      	// add	SP,CX
	0x66, 0x01, 0xD4,      	// add	SP,DX
	0x66, 0x01, 0xF4,      	// add	SP,SI
	0x66, 0x01, 0xFC,      	// add	SP,DI
	0x66, 0x01, 0xEC,      	// add	SP,BP
	0x66, 0x01, 0xE4,      	// add	SP,SP
	0x01, 0xC0,       	// add	EAX,EAX
	0x01, 0xD8,       	// add	EAX,EBX
	0x01, 0xC8,       	// add	EAX,ECX
	0x01, 0xD0,       	// add	EAX,EDX
	0x01, 0xF0,       	// add	EAX,ESI
	0x01, 0xF8,       	// add	EAX,EDI
	0x01, 0xE8,       	// add	EAX,EBP
	0x01, 0xE0,       	// add	EAX,ESP
	0x01, 0xC3,       	// add	EBX,EAX
	0x01, 0xDB,       	// add	EBX,EBX
	0x01, 0xCB,       	// add	EBX,ECX
	0x01, 0xD3,       	// add	EBX,EDX
	0x01, 0xF3,       	// add	EBX,ESI
	0x01, 0xFB,       	// add	EBX,EDI
	0x01, 0xEB,       	// add	EBX,EBP
	0x01, 0xE3,       	// add	EBX,ESP
	0x01, 0xC1,       	// add	ECX,EAX
	0x01, 0xD9,       	// add	ECX,EBX
	0x01, 0xC9,       	// add	ECX,ECX
	0x01, 0xD1,       	// add	ECX,EDX
	0x01, 0xF1,       	// add	ECX,ESI
	0x01, 0xF9,       	// add	ECX,EDI
	0x01, 0xE9,       	// add	ECX,EBP
	0x01, 0xE1,       	// add	ECX,ESP
	0x01, 0xC2,       	// add	EDX,EAX
	0x01, 0xDA,       	// add	EDX,EBX
	0x01, 0xCA,       	// add	EDX,ECX
	0x01, 0xD2,       	// add	EDX,EDX
	0x01, 0xF2,       	// add	EDX,ESI
	0x01, 0xFA,       	// add	EDX,EDI
	0x01, 0xEA,       	// add	EDX,EBP
	0x01, 0xE2,       	// add	EDX,ESP
	0x01, 0xC6,       	// add	ESI,EAX
	0x01, 0xDE,       	// add	ESI,EBX
	0x01, 0xCE,       	// add	ESI,ECX
	0x01, 0xD6,       	// add	ESI,EDX
	0x01, 0xF6,       	// add	ESI,ESI
	0x01, 0xFE,       	// add	ESI,EDI
	0x01, 0xEE,       	// add	ESI,EBP
	0x01, 0xE6,       	// add	ESI,ESP
	0x01, 0xC7,       	// add	EDI,EAX
	0x01, 0xDF,       	// add	EDI,EBX
	0x01, 0xCF,       	// add	EDI,ECX
	0x01, 0xD7,       	// add	EDI,EDX
	0x01, 0xF7,       	// add	EDI,ESI
	0x01, 0xFF,       	// add	EDI,EDI
	0x01, 0xEF,       	// add	EDI,EBP
	0x01, 0xE7,       	// add	EDI,ESP
	0x01, 0xC5,       	// add	EBP,EAX
	0x01, 0xDD,       	// add	EBP,EBX
	0x01, 0xCD,       	// add	EBP,ECX
	0x01, 0xD5,       	// add	EBP,EDX
	0x01, 0xF5,       	// add	EBP,ESI
	0x01, 0xFD,       	// add	EBP,EDI
	0x01, 0xED,       	// add	EBP,EBP
	0x01, 0xE5,       	// add	EBP,ESP
	0x01, 0xC4,       	// add	ESP,EAX
	0x01, 0xDC,       	// add	ESP,EBX
	0x01, 0xCC,       	// add	ESP,ECX
	0x01, 0xD4,       	// add	ESP,EDX
	0x01, 0xF4,       	// add	ESP,ESI
	0x01, 0xFC,       	// add	ESP,EDI
	0x01, 0xEC,       	// add	ESP,EBP
	0x01, 0xE4,       	// add	ESP,ESP
    ];
    int i;

    asm
    {
	call	L1			;

	add	AL,AL	;
	add	AL,BL	;
	add	AL,CL	;
	add	AL,DL	;

	add	AL,AH	;
	add	AL,BH	;
	add	AL,CH	;
	add	AL,DH	;

	add	AH,AL	;
	add	AH,BL	;
	add	AH,CL	;
	add	AH,DL	;

	add	AH,AH	;
	add	AH,BH	;
	add	AH,CH	;
	add	AH,DH	;

	add	BL,AL	;
	add	BL,BL	;
	add	BL,CL	;
	add	BL,DL	;

	add	BL,AH	;
	add	BL,BH	;
	add	BL,CH	;
	add	BL,DH	;

	add	BH,AL	;
	add	BH,BL	;
	add	BH,CL	;
	add	BH,DL	;

	add	BH,AH	;
	add	BH,BH	;
	add	BH,CH	;
	add	BH,DH	;

	add	CL,AL	;
	add	CL,BL	;
	add	CL,CL	;
	add	CL,DL	;

	add	CL,AH	;
	add	CL,BH	;
	add	CL,CH	;
	add	CL,DH	;

	add	CH,AL	;
	add	CH,BL	;
	add	CH,CL	;
	add	CH,DL	;

	add	CH,AH	;
	add	CH,BH	;
	add	CH,CH	;
	add	CH,DH	;

	add	DL,AL	;
	add	DL,BL	;
	add	DL,CL	;
	add	DL,DL	;

	add	DL,AH	;
	add	DL,BH	;
	add	DL,CH	;
	add	DL,DH	;

	add	DH,AL	;
	add	DH,BL	;
	add	DH,CL	;
	add	DH,DL	;

	add	DH,AH	;
	add	DH,BH	;
	add	DH,CH	;
	add	DH,DH	;

	add	AX,AX	;
	add	AX,BX	;
	add	AX,CX	;
	add	AX,DX	;
	add	AX,SI	;
	add	AX,DI	;
	add	AX,BP	;
	add	AX,SP	;

	add	BX,AX	;
	add	BX,BX	;
	add	BX,CX	;
	add	BX,DX	;
	add	BX,SI	;
	add	BX,DI	;
	add	BX,BP	;
	add	BX,SP	;

	add	CX,AX	;
	add	CX,BX	;
	add	CX,CX	;
	add	CX,DX	;
	add	CX,SI	;
	add	CX,DI	;
	add	CX,BP	;
	add	CX,SP	;

	add	DX,AX	;
	add	DX,BX	;
	add	DX,CX	;
	add	DX,DX	;
	add	DX,SI	;
	add	DX,DI	;
	add	DX,BP	;
	add	DX,SP	;

	add	SI,AX	;
	add	SI,BX	;
	add	SI,CX	;
	add	SI,DX	;
	add	SI,SI	;
	add	SI,DI	;
	add	SI,BP	;
	add	SI,SP	;

	add	DI,AX	;
	add	DI,BX	;
	add	DI,CX	;
	add	DI,DX	;
	add	DI,SI	;
	add	DI,DI	;
	add	DI,BP	;
	add	DI,SP	;

	add	BP,AX	;
	add	BP,BX	;
	add	BP,CX	;
	add	BP,DX	;
	add	BP,SI	;
	add	BP,DI	;
	add	BP,BP	;
	add	BP,SP	;

	add	SP,AX	;
	add	SP,BX	;
	add	SP,CX	;
	add	SP,DX	;
	add	SP,SI	;
	add	SP,DI	;
	add	SP,BP	;
	add	SP,SP	;

	add	EAX,EAX	;
	add	EAX,EBX	;
	add	EAX,ECX	;
	add	EAX,EDX	;
	add	EAX,ESI	;
	add	EAX,EDI	;
	add	EAX,EBP	;
	add	EAX,ESP	;

	add	EBX,EAX	;
	add	EBX,EBX	;
	add	EBX,ECX	;
	add	EBX,EDX	;
	add	EBX,ESI	;
	add	EBX,EDI	;
	add	EBX,EBP	;
	add	EBX,ESP	;

	add	ECX,EAX	;
	add	ECX,EBX	;
	add	ECX,ECX	;
	add	ECX,EDX	;
	add	ECX,ESI	;
	add	ECX,EDI	;
	add	ECX,EBP	;
	add	ECX,ESP	;

	add	EDX,EAX	;
	add	EDX,EBX	;
	add	EDX,ECX	;
	add	EDX,EDX	;
	add	EDX,ESI	;
	add	EDX,EDI	;
	add	EDX,EBP	;
	add	EDX,ESP	;

	add	ESI,EAX	;
	add	ESI,EBX	;
	add	ESI,ECX	;
	add	ESI,EDX	;
	add	ESI,ESI	;
	add	ESI,EDI	;
	add	ESI,EBP	;
	add	ESI,ESP	;

	add	EDI,EAX	;
	add	EDI,EBX	;
	add	EDI,ECX	;
	add	EDI,EDX	;
	add	EDI,ESI	;
	add	EDI,EDI	;
	add	EDI,EBP	;
	add	EDI,ESP	;

	add	EBP,EAX	;
	add	EBP,EBX	;
	add	EBP,ECX	;
	add	EBP,EDX	;
	add	EBP,ESI	;
	add	EBP,EDI	;
	add	EBP,EBP	;
	add	EBP,ESP	;

	add	ESP,EAX	;
	add	ESP,EBX	;
	add	ESP,ECX	;
	add	ESP,EDX	;
	add	ESP,ESI	;
	add	ESP,EDI	;
	add	ESP,EBP	;
	add	ESP,ESP	;

L1:					;
	pop	RBX			;
	mov	p[RBP],RBX		;
    }
    for (i = 0; i < data.length; i++)
    {
	assert(p[i] == data[i]);
    }
}


/****************************************************/

void test50()
{
    ubyte *p;
    static ubyte data[] =
    [
	0x66, 0x98,     // cbw
	0xF8,          	// clc
	0xFC,          	// cld
	0xFA,          	// cli
	0xF5,          	// cmc
	0xA6,          	// cmpsb
	0x66, 0xA7,     // cmpsw
	0xA7,          	// cmpsd
	0x66, 0x99,     // cwd
//	0x27,          	// daa
//	0x2F,          	// das
	0xFF, 0xC8,    	// dec	EAX
	0xF6, 0xF1,     // div	CL
	0x66, 0xF7, 0xF3,  // div	BX
	0xF7, 0xF2,     // div	EDX
	0xF4,          	// hlt
	0xF6, 0xFB,     // idiv	BL
	0x66, 0xF7, 0xFA,  // idiv	DX
	0xF7, 0xFE,     // idiv	ESI
	0xF6, 0xEB,     // imul	BL
	0x66, 0xF7, 0xEA,  // imul	DX
	0xF7, 0xEE,     // imul	ESI
	0xEC,          	// in	AL,DX
	0x66, 0xED,     // in	AX,DX
	0xFF, 0xC3,    	// inc	EBX
	0xCC,          	// int	3
	0xCD, 0x67,     // int	067h
//	0xCE,          	// into
	0x66, 0xCF,     // iret
	0x77, 0xFC,     // ja	L30
	0x77, 0xFA,     // ja	L30
	0x73, 0xF8,     // jae	L30
	0x73, 0xF6,     // jae	L30
	0x73, 0xF4,     // jae	L30
	0x72, 0xF2,     // jb	L30
	0x72, 0xF0,     // jb	L30
	0x76, 0xEE,     // jbe	L30
	0x76, 0xEC,     // jbe	L30
	0x72, 0xEA,     // jb	L30
//	0x67, 0xE3, 0xE7,  // jcxz	L30
	0x90, 0x90, 0x90,  // nop;nop;nop
	0x74, 0xE5,     // je	L30
	0x74, 0xE3,     // je	L30
	0x7F, 0xE1,     // jg	L30
	0x7F, 0xDF,     // jg	L30
	0x7D, 0xDD,     // jge	L30
	0x7D, 0xDB,     // jge	L30
	0x7C, 0xD9,     // jl	L30
	0x7C, 0xD7,     // jl	L30
	0x7E, 0xD5,     // jle	L30
	0x7E, 0xD3,     // jle	L30
	0xEB, 0xD1,     // jmp short	L30
	0x75, 0xCF,     // jne	L30
	0x75, 0xCD,     // jne	L30
	0x71, 0xCB,     // jno	L30
	0x79, 0xC9,     // jns	L30
	0x7B, 0xC7,     // jnp	L30
	0x7B, 0xC5,     // jnp	L30
	0x70, 0xC3,     // jo	L30
	0x7A, 0xC1,     // jp	L30
	0x7A, 0xBF,     // jp	L30
	0x78, 0xBD,     // js	L30
	0x9F,          	// lahf
//	0xC5, 0x30,     // lds	ESI,[EAX]
	0x90, 0x90,     // nop;nop
	0x8B, 0xFB,     // mov	EDI,EBX
//	0xC4, 0x29,     // les	EBP,[ECX]
	0x90, 0x90,     // nop;nop
	0xF0,          	// lock
	0xAC,          	// lodsb
	0x66, 0xAD,     // lodsw
	0xAD,          	// lodsd
	0xE2, 0xAF,     // loop	L30
	0xE1, 0xAD,     // loope	L30
	0xE1, 0xAB,     // loope	L30
	0xE0, 0xA9,     // loopne	L30
	0xE0, 0xA7,     // loopne	L30
	0xA4,          	// movsb
	0x66, 0xA5,     // movsw
	0xA5,          	// movsd
	0xF6, 0xE4,     // mul	AH
	0x66, 0xF7, 0xE1,  // mul	CX
	0xF7, 0xE5,     // mul	EBP
	0x90,          	// nop
	0xF7, 0xD7,     // not	EDI
	0x66, 0xE7, 0x44,  // out	044h,AX
	0xEE,          	// out	DX,AL
	0x66, 0x9D,     // popf
	0x66, 0x9C,     // pushf
	0xD1, 0xDB,     // rcr	EBX,1
	0xF3,          	// rep
	0xF3,          	// rep
	0xF2,          	// repne
	0xF3,          	// rep
	0xF2,          	// repne
	0xC3,          	// ret
	0xC2, 0x04, 0x00,  // ret  4
	0xD1, 0xC1,     // rol	ECX,1
	0xD1, 0xCA,     // ror	EDX,1
	0x9E,          	// sahf
	0xD1, 0xE5,     // shl	EBP,1
	0xD1, 0xE4,     // shl	ESP,1
	0xD1, 0xFF,     // sar	EDI,1
	0xAE,          	// scasb
	0x66, 0xAF,     // scasw
	0xAF,          	// scasd
	0xD1, 0xEE,     // shr	ESI,1
	0xFD,          	// std
	0xF9,          	// stc
	0xFB,          	// sti
	0xAA,          	// stosb
	0x66, 0xAB,     // stosw
	0xAB,          	// stosd
	0x9B,          	// wait
	0x91,          	// xchg	EAX,ECX
	0xD7,          	// xlat
    ];
    int i;

    asm
    {
	call	L1			;

	cbw	;
	clc	;
	cld	;
	cli	;
	cmc	;
	cmpsb	;
	cmpsw	;
	cmpsd	;
	cwd	;
	//daa	;
	//das	;
	dec	EAX	;
	div	CL	;
	div	BX	;
	div	EDX	;
	hlt		;
	idiv	BL	;
	idiv	DX	;
	idiv	ESI	;
	imul	BL	;
	imul	DX	;
	imul	ESI	;
	in	AL,DX	;
	in	AX,DX	;
	inc	EBX	;
	int	3	;
	int	0x67	;
	//into		;
L10:	iret		;
	ja	L10	;
	jnbe	L10	;
	jae	L10	;
	jnb	L10	;
	jnc	L10	;
	jb	L10	;
	jnae	L10	;
	jbe	L10	;
	jna	L10	;
	jc	L10	;
	nop;nop;nop;	// jcxz	L10;
	je	L10	;
	jz	L10	;
	jg	L10	;
	jnle	L10	;
	jge	L10	;
	jnl	L10	;
	jl	L10	;
	jnge	L10	;
	jle	L10	;
	jng	L10	;
	jmp	short L10	;
	jne	L10	;
	jnz	L10	;
	jno	L10	;
	jns	L10	;
	jnp	L10	;
	jpo	L10	;
	jo	L10	;
	jp	L10	;
	jpe	L10	;
	js	L10	;
	lahf		;
	nop;nop;	//lds	ESI,[EAX];
	lea	EDI,[EBX];
	nop;nop;	//les	EBP,[ECX];
	lock	;
	lodsb	;
	lodsw	;
	lodsd	;
	loop	L10	;
	loope	L10	;
	loopz	L10	;
	loopnz	L10	;
	loopne	L10	;
	movsb	;
	movsw	;
	movsd	;
	mul	AH	;
	mul	CX	;
	mul	EBP	;
	nop	;
	not	EDI	;
	out	0x44,AX	;
	out	DX,AL	;
	popf	;
	pushf	;
	rcr	EBX,1	;
	rep	;
	repe	;
	repne	;
	repz	;
	repnz	;
	ret	;
	ret	4	;
	rol	ECX,1	;
	ror	EDX,1	;
	sahf	;
	sal	EBP,1	;
	shl	ESP,1	;
	sar	EDI,1	;
	scasb	;
	scasw	;
	scasd	;
	shr	ESI,1	;
	std	;
	stc	;
	sti	;
	stosb	;
	stosw	;
	stosd	;
	wait	;
	xchg	EAX,ECX	;
	xlat	;

L1:					;
	pop	RBX			;
	mov	p[RBP],RBX		;
    }
    for (i = 0; i < data.length; i++)
    {
	assert(p[i] == data[i]);
    }
}


/****************************************************/

class Test51
{
    void test(int n)
    { asm {
        mov RAX, this;
        }
    }
}

/****************************************************/

void test52()
{   int x;
    ubyte* p;
    static ubyte data[] =
    [
	0xF6, 0xD8,             	// neg	AL
0x66, 	0xF7, 0xD8,             	// neg	AX
	0xF7, 0xD8,             	// neg	EAX
	0x48, 0xF7, 0xD8,          	// neg	RAX
	0xF6, 0xDC,             	// neg	AH
	0x41, 0xF6, 0xDC,          	// neg	R12B
0x66, 	0x41, 0xF7, 0xDC,          	// neg	12D
	0x41, 0xF7, 0xDC,          	// neg	R12D
	0x49, 0xF7, 0xDB,          	// neg	R11
//	0xF6, 0x1D, 0x00, 0x00, 0x00, 0x00, 	// neg	byte ptr _D6iasm641bg@PC32[RIP]
//0x66, 	0xF7, 0x1D, 0x00, 0x00, 0x00, 0x00, 	// neg	word ptr _D6iasm641ws@PC32[RIP]
//	0xF7, 0x1D, 0x00, 0x00, 0x00, 0x00, 	// neg	dword ptr _D6iasm641ii@PC32[RIP]
//	0x48, 0xF7, 0x1D, 0x00, 0x00, 0x00, 0x00, 	// neg	qword ptr _D6iasm641ll@PC32[RIP]
	0xF7, 0x5D, 0xD0,          	// neg	dword ptr -8[RBP]
	0xF6, 0x1B,             	// neg	byte ptr [RBX]
	0xF6, 0x1B,             	// neg	byte ptr [RBX]
	0x49, 0xF7, 0xD8,          	// neg	R8
    ];

    asm
    {
	call	L1	;

	neg	AL	;
	neg	AX	;
	neg	EAX	;
	neg	RAX	;
	neg	AH	;
	neg	R12B	;
	neg	R12W	;
	neg	R12D	;
	neg	R11	;
//	neg	b	;
//	neg	w	;
//	neg	i	;
//	neg	l	;
	neg	x	;
	neg	[EBX]	;
	neg	[RBX]	;
	neg	R8	;

L1:	pop	RAX	;
	mov	p[RBP],RAX ;
    }

    foreach (i,b; data)
    {
	//printf("data[%d] = 0x%02x, should be 0x%02x\n", i, p[i], b);
	assert(p[i] == b);
    }
}

/****************************************************/

void test53()
{   int x;
    ubyte* p;
    static ubyte data[] =
    [
	0x48, 0x8D, 0x04, 0x00,       	// lea	RAX,[RAX][RAX]
	0x48, 0x8D, 0x04, 0x08,       	// lea	RAX,[RCX][RAX]
	0x48, 0x8D, 0x04, 0x10,       	// lea	RAX,[RDX][RAX]
	0x48, 0x8D, 0x04, 0x18,       	// lea	RAX,[RBX][RAX]
	0x48, 0x8D, 0x04, 0x28,       	// lea	RAX,[RBP][RAX]
	0x48, 0x8D, 0x04, 0x30,       	// lea	RAX,[RSI][RAX]
	0x48, 0x8D, 0x04, 0x38,       	// lea	RAX,[RDI][RAX]
	0x4A, 0x8D, 0x04, 0x00,       	// lea	RAX,[R8][RAX]
	0x4A, 0x8D, 0x04, 0x08,       	// lea	RAX,[R9][RAX]
	0x4A, 0x8D, 0x04, 0x10,       	// lea	RAX,[R10][RAX]
	0x4A, 0x8D, 0x04, 0x18,       	// lea	RAX,[R11][RAX]
	0x4A, 0x8D, 0x04, 0x20,       	// lea	RAX,[R12][RAX]
	0x4A, 0x8D, 0x04, 0x28,       	// lea	RAX,[R13][RAX]
	0x4A, 0x8D, 0x04, 0x30,       	// lea	RAX,[R14][RAX]
	0x4A, 0x8D, 0x04, 0x38,       	// lea	RAX,[R15][RAX]
	0x48, 0x8D, 0x04, 0x00,       	// lea	RAX,[RAX][RAX]
	0x48, 0x8D, 0x04, 0x01,       	// lea	RAX,[RAX][RCX]
	0x48, 0x8D, 0x04, 0x02,       	// lea	RAX,[RAX][RDX]
	0x48, 0x8D, 0x04, 0x03,       	// lea	RAX,[RAX][RBX]
	0x48, 0x8D, 0x04, 0x04,       	// lea	RAX,[RAX][RSP]
	0x48, 0x8D, 0x44, 0x05, 0x00,   // lea	RAX,0[RAX][RBP]
	0x48, 0x8D, 0x04, 0x06,       	// lea	RAX,[RAX][RSI]
	0x48, 0x8D, 0x04, 0x07,       	// lea	RAX,[RAX][RDI]
	0x49, 0x8D, 0x04, 0x00,       	// lea	RAX,[RAX][R8]
	0x49, 0x8D, 0x04, 0x01,       	// lea	RAX,[RAX][R9]
	0x49, 0x8D, 0x04, 0x02,       	// lea	RAX,[RAX][R10]
	0x49, 0x8D, 0x04, 0x03,       	// lea	RAX,[RAX][R11]
	0x49, 0x8D, 0x04, 0x04,       	// lea	RAX,[RAX][R12]
	0x49, 0x8D, 0x44, 0x05, 0x00,   // lea	RAX,0[RAX][R13]
	0x49, 0x8D, 0x04, 0x06,       	// lea	RAX,[RAX][R14]
	0x49, 0x8D, 0x04, 0x07,       	// lea	RAX,[RAX][R15]
	0x4B, 0x8D, 0x04, 0x24,       	// lea	RAX,[R12][R12]
	0x4B, 0x8D, 0x44, 0x25, 0x00,   // lea	RAX,0[R12][R13]
	0x4B, 0x8D, 0x04, 0x26,       	// lea	RAX,[R12][R14]
	0x4B, 0x8D, 0x04, 0x2C,       	// lea	RAX,[R13][R12]
	0x4B, 0x8D, 0x44, 0x2D, 0x00,   // lea	RAX,0[R13][R13]
	0x4B, 0x8D, 0x04, 0x2E,       	// lea	RAX,[R13][R14]
	0x4B, 0x8D, 0x04, 0x34,       	// lea	RAX,[R14][R12]
	0x4B, 0x8D, 0x44, 0x35, 0x00,   // lea	RAX,0[R14][R13]
	0x4B, 0x8D, 0x04, 0x36,       	// lea	RAX,[R14][R14]
	0x48, 0x8D, 0x44, 0x01, 0x12,    			// lea	RAX,012h[RAX][RCX]
	0x48, 0x8D, 0x84, 0x01, 0x34, 0x12, 0x00, 0x00, 	// lea	RAX,01234h[RAX][RCX]
	0x48, 0x8D, 0x84, 0x01, 0x78, 0x56, 0x34, 0x12, 	// lea	RAX,012345678h[RAX][RCX]
	0x48, 0x8D, 0x44, 0x05, 0x12,    			// lea	RAX,012h[RAX][RBP]
	0x48, 0x8D, 0x84, 0x05, 0x34, 0x12, 0x00, 0x00, 	// lea	RAX,01234h[RAX][RBP]
	0x48, 0x8D, 0x84, 0x05, 0x78, 0x56, 0x34, 0x12, 	// lea	RAX,012345678h[RAX][RBP]
	0x49, 0x8D, 0x44, 0x05, 0x12,    			// lea	RAX,012h[RAX][R13]
	0x49, 0x8D, 0x84, 0x05, 0x34, 0x12, 0x00, 0x00, 	// lea	RAX,01234h[RAX][R13]
	0x49, 0x8D, 0x84, 0x05, 0x78, 0x56, 0x34, 0x12, 	// lea	RAX,012345678h[RAX][R13]
    ];

    asm
    {
	call	L1	;

	// Right
	lea RAX, [RAX+RAX];
	lea RAX, [RAX+RCX];
	lea RAX, [RAX+RDX];
	lea RAX, [RAX+RBX];
	//lea RAX, [RAX+RSP]; RSP can't be on the right
	lea RAX, [RAX+RBP];
	lea RAX, [RAX+RSI];
	lea RAX, [RAX+RDI];
	lea RAX, [RAX+R8];
	lea RAX, [RAX+R9];
	lea RAX, [RAX+R10];
	lea RAX, [RAX+R11];
	lea RAX, [RAX+R12];
	lea RAX, [RAX+R13];
	lea RAX, [RAX+R14];
	lea RAX, [RAX+R15];
	// Left
	lea RAX, [RAX+RAX];
	lea RAX, [RCX+RAX];
	lea RAX, [RDX+RAX];
	lea RAX, [RBX+RAX];
	lea RAX, [RSP+RAX];
	lea RAX, [RBP+RAX]; // Good gets disp+8 correctly
	lea RAX, [RSI+RAX];
	lea RAX, [RDI+RAX];
	lea RAX, [R8+RAX];
	lea RAX, [R9+RAX];
	lea RAX, [R10+RAX];
	lea RAX, [R11+RAX];
	lea RAX, [R12+RAX];
	lea RAX, [R13+RAX]; // Good disp+8
	lea RAX, [R14+RAX];
	lea RAX, [R15+RAX];
	// Right and Left
	lea RAX, [R12+R12];
	lea RAX, [R13+R12];
	lea RAX, [R14+R12];
	lea RAX, [R12+R13];
	lea RAX, [R13+R13];
	lea RAX, [R14+R13];
	lea RAX, [R12+R14];
	lea RAX, [R13+R14];
	lea RAX, [R14+R14];

	// Disp8/32 checks
	lea RAX, [RCX+RAX+0x12];
	lea RAX, [RCX+RAX+0x1234];
	lea RAX, [RCX+RAX+0x1234_5678];
	lea RAX, [RBP+RAX+0x12];
	lea RAX, [RBP+RAX+0x1234];
	lea RAX, [RBP+RAX+0x1234_5678];
	lea RAX, [R13+RAX+0x12];
	lea RAX, [R13+RAX+0x1234];
	lea RAX, [R13+RAX+0x1234_5678];

L1:	pop	RAX	;
	mov	p[RBP],RAX ;
    }

    foreach (i,b; data)
    {
	//printf("data[%d] = 0x%02x, should be 0x%02x\n", i, p[i], b);
	assert(p[i] == b);
    }
}

/****************************************************/

void test54()
{   int x;
    ubyte* p;
    static ubyte data[] =
    [
              0xFE, 0xC8,                // dec    AL
              0xFE, 0xCC,                // dec    AH
        0x66, 0xFF, 0xC8,                // dec    AX
              0xFF, 0xC8,                // dec    EAX
        0x48, 0xFF, 0xC8,                // dec    RAX
        0x49, 0xFF, 0xCA,                // dec    R10

              0xFE, 0xC0,                // inc    AL
              0xFE, 0xC4,                // inc    AH
        0x66, 0xFF, 0xC0,                // inc    AX
              0xFF, 0xC0,                // inc    EAX
        0x48, 0xFF, 0xC0,                // inc    RAX
        0x49, 0xFF, 0xC2,                // inc    R10

  0x66, 0x44, 0x0F, 0xA4, 0xC0, 0x04,    // shld    AX, R8W, 4
  0x66, 0x44, 0x0F, 0xA5, 0xC0,          // shld    AX, R8W, CL
        0x44, 0x0F, 0xA4, 0xC0, 0x04,    // shld   EAX, R8D, 4
        0x44, 0x0F, 0xA5, 0xC0,          // shld   EAX, R8D, CL
        0x4C, 0x0F, 0xA4, 0xC0, 0x04,    // shld   RAX, R8 , 4
        0x4C, 0x0F, 0xA5, 0xC0,          // shld   RAX, R8 , CL

  0x66, 0x44, 0x0F, 0xAC, 0xC0, 0x04,    // shrd    AX, R8W, 4
  0x66, 0x44, 0x0F, 0xAD, 0xC0,          // shrd    AX, R8W, CL
        0x44, 0x0F, 0xAC, 0xC0, 0x04,    // shrd   EAX, R8D, 4
        0x44, 0x0F, 0xAD, 0xC0,          // shrd   EAX, R8D, CL
        0x4C, 0x0F, 0xAC, 0xC0, 0x04,    // shrd   RAX, R8 , 4
        0x4C, 0x0F, 0xAD, 0xC0           // shrd   RAX, R8 , CL
    ];

    asm
    {
        call  L1;

        dec   AL;
        dec   AH;
        dec   AX;
        dec   EAX;
        dec   RAX;
        dec   R10;

        inc   AL;
        inc   AH;
        inc   AX;
        inc   EAX;
        inc   RAX;
        inc   R10;

        shld   AX, R8W, 4;
        shld   AX, R8W, CL;
        shld  EAX, R8D, 4;
        shld  EAX, R8D, CL;
        shld  RAX, R8 , 4;
        shld  RAX, R8 , CL;

        shrd   AX, R8W, 4;
        shrd   AX, R8W, CL;
        shrd  EAX, R8D, 4;
        shrd  EAX, R8D, CL;
        shrd  RAX, R8 , 4;
        shrd  RAX, R8 , CL;

L1:     pop     RAX;
        mov     p[RBP],RAX;
    }

    foreach (i,b; data)
    {
        //printf("data[%d] = 0x%02x, should be 0x%02x\n", i, p[i], b);
        assert(p[i] == b);
    }
}

/****************************************************/

void test55()
{   int x;
    ubyte* p;
    enum NOP = 0x9090_9090_9090_9090;
    static ubyte data[] =
    [
        0x0F, 0x87, 0xFF, 0xFF, 0, 0,    //    ja    $ + 0xFFFF
        0x72, 0x18,                      //    jb    Lb
        0x0F, 0x82, 0x92, 0x00, 0, 0,    //    jc    Lc
        0x0F, 0x84, 0x0C, 0x01, 0, 0,    //    je    Le
        0xEB, 0x0A,                      //    jmp   Lb
        0xE9, 0x85, 0x00, 0x00, 0,       //    jmp   Lc
        0xE9, 0x00, 0x01, 0x00, 0,       //    jmp   Le
    ];

    asm
    {
        call  L1;

        ja  $+0x0_FFFF;
        jb  Lb;
        jc  Lc;
        je  Le;
        jmp Lb;
        jmp Lc;
        jmp Le;

    Lb: dq NOP,NOP,NOP,NOP;    //  32
        dq NOP,NOP,NOP,NOP;    //  64
        dq NOP,NOP,NOP,NOP;    //  96
        dq NOP,NOP,NOP,NOP;    // 128
    Lc: dq NOP,NOP,NOP,NOP;    // 160
        dq NOP,NOP,NOP,NOP;    // 192
        dq NOP,NOP,NOP,NOP;    // 224
        dq NOP,NOP,NOP,NOP;    // 256
    Le: nop;

L1:     pop     RAX;
        mov     p[RBP],RAX;
    }

    foreach (i,b; data)
    {
        //printf("data[%d] = 0x%02x, should be 0x%02x\n", i, p[i], b);
        assert(p[i] == b);
    }
}

/****************************************************/

void test56()
{   int x;

    x = foo56();

    assert(x == 42);
}

int foo56()
{
    asm
    {   naked;
        xor  EAX,EAX;
        jz   bar56;
        ret;
    }
}
void bar56()
{
    asm
    {   naked;
        mov EAX, 42;
        ret;
    }
}

/****************************************************/

/* ======================= SSSE3 ======================= */

void test57()
{
    ubyte* p;
    M64  m64;
    M128 m128;
    static ubyte data[] =
    [
        0x0F, 0x3A, 0x0F, 0xCA,       0x03,    // palignr   MM1,  MM2, 3
  0x66, 0x0F, 0x3A, 0x0F, 0xCA,       0x03,    // palignr  XMM1, XMM2, 3
        0x0F, 0x3A, 0x0F, 0x5D, 0xC8, 0x03,    // palignr   MM3, -0x38[RBP], 3
  0x66, 0x0F, 0x3A, 0x0F, 0x5D, 0xD0, 0x03,    // palignr  XMM3, -0x30[RBP], 3
        0x0F, 0x38, 0x02, 0xCA,                // phaddd    MM1,  MM2
  0x66, 0x0F, 0x38, 0x02, 0xCA,                // phaddd   XMM1, XMM2
        0x0F, 0x38, 0x02, 0x5D, 0xC8,          // phaddd    MM3, -0x38[RBP]
  0x66, 0x0F, 0x38, 0x02, 0x5D, 0xD0,          // phaddd   XMM3, -0x30[RBP]
        0x0F, 0x38, 0x01, 0xCA,                // phaddw    MM1,  MM2
  0x66, 0x0F, 0x38, 0x01, 0xCA,                // phaddw   XMM1, XMM2
        0x0F, 0x38, 0x01, 0x5D, 0xC8,          // phaddw    MM3, -0x38[RBP]
  0x66, 0x0F, 0x38, 0x01, 0x5D, 0xD0,          // phaddw   XMM3, -0x30[RBP]
        0x0F, 0x38, 0x03, 0xCA,                // phaddsw   MM1,  MM2
  0x66, 0x0F, 0x38, 0x03, 0xCA,                // phaddsw  XMM1, XMM2
        0x0F, 0x38, 0x03, 0x5D, 0xC8,          // phaddsw   MM3, -0x38[RBP]
  0x66, 0x0F, 0x38, 0x03, 0x5D, 0xD0,          // phaddsw  XMM3, -0x30[RBP]
        0x0F, 0x38, 0x06, 0xCA,                // phsubd    MM1,  MM2
  0x66, 0x0F, 0x38, 0x06, 0xCA,                // phsubd   XMM1, XMM2
        0x0F, 0x38, 0x06, 0x5D, 0xC8,          // phsubd    MM3, -0x38[RBP]
  0x66, 0x0F, 0x38, 0x06, 0x5D, 0xD0,          // phsubd   XMM3, -0x30[RBP]
        0x0F, 0x38, 0x05, 0xCA,                // phsubw    MM1,  MM2
  0x66, 0x0F, 0x38, 0x05, 0xCA,                // phsubw   XMM1, XMM2
        0x0F, 0x38, 0x05, 0x5D, 0xC8,          // phsubw    MM3, -0x38[RBP]
  0x66, 0x0F, 0x38, 0x05, 0x5D, 0xD0,          // phsubw   XMM3, -0x30[RBP]
        0x0F, 0x38, 0x07, 0xCA,                // phsubsw   MM1,  MM2
  0x66, 0x0F, 0x38, 0x07, 0xCA,                // phsubsw  XMM1, XMM2
        0x0F, 0x38, 0x07, 0x5D, 0xC8,          // phsubsw   MM3, -0x38[RBP]
  0x66, 0x0F, 0x38, 0x07, 0x5D, 0xD0,          // phsubsw  XMM3, -0x30[RBP]
        0x0F, 0x38, 0x04, 0xCA,                // pmaddubsw  MM1,  MM2
  0x66, 0x0F, 0x38, 0x04, 0xCA,                // pmaddubsw XMM1, XMM2
        0x0F, 0x38, 0x04, 0x5D, 0xC8,          // pmaddubsw  MM3, -0x38[RBP]
  0x66, 0x0F, 0x38, 0x04, 0x5D, 0xD0,          // pmaddubsw XMM3, -0x30[RBP]
        0x0F, 0x38, 0x0B, 0xCA,                // pmulhrsw  MM1,  MM2
  0x66, 0x0F, 0x38, 0x0B, 0xCA,                // pmulhrsw XMM1, XMM2
        0x0F, 0x38, 0x0B, 0x5D, 0xC8,          // pmulhrsw  MM3, -0x38[RBP]
  0x66, 0x0F, 0x38, 0x0B, 0x5D, 0xD0,          // pmulhrsw XMM3, -0x30[RBP]
        0x0F, 0x38, 0x00, 0xCA,                // pshufb    MM1,  MM2
  0x66, 0x0F, 0x38, 0x00, 0xCA,                // pshufb   XMM1, XMM2
        0x0F, 0x38, 0x00, 0x5D, 0xC8,          // pshufb    MM3, -0x38[RBP]
  0x66, 0x0F, 0x38, 0x00, 0x5D, 0xD0,          // pshufb   XMM3, -0x30[RBP]
        0x0F, 0x38, 0x1C, 0xCA,                // pabsb     MM1,  MM2
  0x66, 0x0F, 0x38, 0x1C, 0xCA,                // pabsb    XMM1, XMM2
        0x0F, 0x38, 0x1C, 0x5D, 0xC8,          // pabsb     MM3, -0x38[RBP]
  0x66, 0x0F, 0x38, 0x1C, 0x5D, 0xD0,          // pabsb    XMM3, -0x30[RBP]
        0x0F, 0x38, 0x1E, 0xCA,                // pabsd     MM1,  MM2
  0x66, 0x0F, 0x38, 0x1E, 0xCA,                // pabsd    XMM1, XMM2
        0x0F, 0x38, 0x1E, 0x5D, 0xC8,          // pabsd     MM3, -0x38[RBP]
  0x66, 0x0F, 0x38, 0x1E, 0x5D, 0xD0,          // pabsd    XMM3, -0x30[RBP]
        0x0F, 0x38, 0x1D, 0xCA,                // pabsw     MM1,  MM2
  0x66, 0x0F, 0x38, 0x1D, 0xCA,                // pabsw    XMM1, XMM2
        0x0F, 0x38, 0x1D, 0x5D, 0xC8,          // pabsw     MM3, -0x38[RBP]
  0x66, 0x0F, 0x38, 0x1D, 0x5D, 0xD0,          // pabsw    XMM3, -0x30[RBP]
        0x0F, 0x38, 0x08, 0xCA,                // psignb    MM1,  MM2
  0x66, 0x0F, 0x38, 0x08, 0xCA,                // psignb   XMM1, XMM2
        0x0F, 0x38, 0x08, 0x5D, 0xC8,          // psignb    MM3, -0x38[RBP]
  0x66, 0x0F, 0x38, 0x08, 0x5D, 0xD0,          // psignb   XMM3, -0x30[RBP]
        0x0F, 0x38, 0x0A, 0xCA,                // psignd    MM1,  MM2
  0x66, 0x0F, 0x38, 0x0A, 0xCA,                // psignd   XMM1, XMM2
        0x0F, 0x38, 0x0A, 0x5D, 0xC8,          // psignd    MM3, -0x38[RBP]
  0x66, 0x0F, 0x38, 0x0A, 0x5D, 0xD0,          // psignd   XMM3, -0x30[RBP]
        0x0F, 0x38, 0x09, 0xCA,                // psignw    MM1,  MM2
  0x66, 0x0F, 0x38, 0x09, 0xCA,                // psignw   XMM1, XMM2
        0x0F, 0x38, 0x09, 0x5D, 0xC8,          // psignw    MM3, -0x38[RBP]
  0x66, 0x0F, 0x38, 0x09, 0x5D, 0xD0,          // psignw   XMM3, -0x30[RBP]
    ];

    asm
    {
        call  L1;

        palignr     MM1,  MM2, 3;
        palignr    XMM1, XMM2, 3;
        palignr     MM3, m64 , 3;
        palignr    XMM3, m128, 3;

        phaddd      MM1,  MM2;
        phaddd     XMM1, XMM2;
        phaddd      MM3,  m64;
        phaddd     XMM3, m128;

        phaddw      MM1,  MM2;
        phaddw     XMM1, XMM2;
        phaddw      MM3,  m64;
        phaddw     XMM3, m128;

        phaddsw     MM1,  MM2;
        phaddsw    XMM1, XMM2;
        phaddsw     MM3,  m64;
        phaddsw    XMM3, m128;

        phsubd      MM1,  MM2;
        phsubd     XMM1, XMM2;
        phsubd      MM3,  m64;
        phsubd     XMM3, m128;

        phsubw      MM1,  MM2;
        phsubw     XMM1, XMM2;
        phsubw      MM3,  m64;
        phsubw     XMM3, m128;

        phsubsw     MM1,  MM2;
        phsubsw    XMM1, XMM2;
        phsubsw     MM3,  m64;
        phsubsw    XMM3, m128;

        pmaddubsw   MM1,  MM2;
        pmaddubsw  XMM1, XMM2;
        pmaddubsw   MM3,  m64;
        pmaddubsw  XMM3, m128;

        pmulhrsw    MM1,  MM2;
        pmulhrsw   XMM1, XMM2;
        pmulhrsw    MM3,  m64;
        pmulhrsw   XMM3, m128;

        pshufb      MM1,  MM2;
        pshufb     XMM1, XMM2;
        pshufb      MM3,  m64;
        pshufb     XMM3, m128;

        pabsb       MM1,  MM2;
        pabsb      XMM1, XMM2;
        pabsb       MM3,  m64;
        pabsb      XMM3, m128;

        pabsd       MM1,  MM2;
        pabsd      XMM1, XMM2;
        pabsd       MM3,  m64;
        pabsd      XMM3, m128;

        pabsw       MM1,  MM2;
        pabsw      XMM1, XMM2;
        pabsw       MM3,  m64;
        pabsw      XMM3, m128;

        psignb      MM1,  MM2;
        psignb     XMM1, XMM2;
        psignb      MM3,  m64;
        psignb     XMM3, m128;

        psignd      MM1,  MM2;
        psignd     XMM1, XMM2;
        psignd      MM3,  m64;
        psignd     XMM3, m128;

        psignw      MM1,  MM2;
        psignw     XMM1, XMM2;
        psignw      MM3,  m64;
        psignw     XMM3, m128;

L1:     pop     RAX;
        mov     p[RBP],RAX;
    }

    foreach (i,b; data)
    {
        //printf("data[%d] = 0x%02x, should be 0x%02x\n", i, p[i], b);
        assert(p[i] == b);
    }
}

/****************************************************/

/* ======================= SSE4.1 ======================= */

void test58()
{
    ubyte* p;
    byte   m8;
    short m16;
    int   m32;
    M64   m64;
    M128 m128;
    static ubyte data[] =
    [
  0x66,       0x0F, 0x3A, 0x0D, 0xCA,        3,// blendpd  XMM1,XMM2,0x3
  0x66,       0x0F, 0x3A, 0x0D, 0x5D, 0xD0,  3,// blendpd  XMM3,XMMWORD PTR [RBP-0x30],0x3
  0x66,       0x0F, 0x3A, 0x0C, 0xCA,        3,// blendps  XMM1,XMM2,0x3
  0x66,       0x0F, 0x3A, 0x0C, 0x5D, 0xD0,  3,// blendps  XMM3,XMMWORD PTR [RBP-0x30],0x3
  0x66,       0x0F, 0x38, 0x15, 0xCA,          // blendvpd XMM1,XMM2,XMM0
  0x66,       0x0F, 0x38, 0x15, 0x5D, 0xD0,    // blendvpd XMM3,XMMWORD PTR [RBP-0x30],XMM0
  0x66,       0x0F, 0x38, 0x14, 0xCA,          // blendvps XMM1,XMM2,XMM0
  0x66,       0x0F, 0x38, 0x14, 0x5D, 0xD0,    // blendvps XMM3,XMMWORD PTR [RBP-0x30],XMM0
  0x66,       0x0F, 0x3A, 0x41, 0xCA,        3,// dppd     XMM1,XMM2,0x3
  0x66,       0x0F, 0x3A, 0x41, 0x5D, 0xD0,  3,// dppd     XMM3,XMMWORD PTR [RBP-0x30],0x3
  0x66,       0x0F, 0x3A, 0x40, 0xCA,        3,// dpps     XMM1,XMM2,0x3
  0x66,       0x0F, 0x3A, 0x40, 0x5D, 0xD0,  3,// dpps     XMM3,XMMWORD PTR [RBP-0x30],0x3
  0x66,       0x0F, 0x3A, 0x17, 0xD2,        3,// extractps EDX,XMM2,0x3
  0x66,       0x0F, 0x3A, 0x17, 0x55, 0xBC,  3,// extractps DWORD PTR [RBP-0x44],XMM2,0x3
  0x66,       0x0F, 0x3A, 0x21, 0xCA,        3,// insertps XMM1,XMM2,0x3
  0x66,       0x0F, 0x3A, 0x21, 0x5D, 0xBC,  3,// insertps XMM3,DWORD PTR [RBP-0x44],0x3
  0x66,       0x0F, 0x38, 0x2A, 0x4D, 0xD0,    // movntdqa XMM1,XMMWORD PTR [RBP-0x30]
  0x66,       0x0F, 0x3A, 0x42, 0xCA,        3,// mpsadbw  XMM1,XMM2,0x3
  0x66,       0x0F, 0x3A, 0x42, 0x5D, 0xD0,  3,// mpsadbw  XMM3,XMMWORD PTR [RBP-0x30],0x3
  0x66,       0x0F, 0x38, 0x2B, 0xCA,          // packusdw XMM1,XMM2
  0x66,       0x0F, 0x38, 0x2B, 0x5D, 0xD0,    // packusdw XMM3,XMMWORD PTR [RBP-0x30]
  0x66,       0x0F, 0x38, 0x10, 0xCA,          // pblendvb XMM1,XMM2,XMM0
  0x66,       0x0F, 0x38, 0x10, 0x5D, 0xD0,    // pblendvb XMM3,XMMWORD PTR [RBP-0x30],XMM0
  0x66,       0x0F, 0x3A, 0x0E, 0xCA,        3,// pblendw  XMM1,XMM2,0x3
  0x66,       0x0F, 0x3A, 0x0E, 0x5D, 0xD0,  3,// pblendw  XMM3,XMMWORD PTR [RBP-0x30],0x3
  0x66,       0x0F, 0x38, 0x29, 0xCA,          // pcmpeqq  XMM1,XMM2
  0x66,       0x0F, 0x38, 0x29, 0x5D, 0xD0,    // pcmpeqq  XMM3,XMMWORD PTR [RBP-0x30]
  0x66,       0x0F, 0x3A, 0x14, 0xD0,        3,// pextrb EAX,XMM2,0x3
  0x66,       0x0F, 0x3A, 0x14, 0xD3,        3,// pextrb EBX,XMM2,0x3
  0x66,       0x0F, 0x3A, 0x14, 0xD1,        3,// pextrb ECX,XMM2,0x3
  0x66,       0x0F, 0x3A, 0x14, 0xD2,        3,// pextrb EDX,XMM2,0x3
  0x66,       0x0F, 0x3A, 0x14, 0xD0,        3,// pextrb EAX,XMM2,0x3
  0x66,       0x0F, 0x3A, 0x14, 0xD3,        3,// pextrb EBX,XMM2,0x3
  0x66, 0x41, 0x0F, 0x3A, 0x14, 0xD0,        3,// pextrb R8D,XMM2,0x3
  0x66, 0x41, 0x0F, 0x3A, 0x14, 0xD2,        3,// pextrb R10D,XMM2,0x3
  0x66,       0x0F, 0x3A, 0x14, 0x5D, 0xB8,  3,// pextrb BYTE PTR [RBP-0x48],XMM3,0x3
  0x66,       0x0F, 0x3A, 0x16, 0xD0,        3,// pextrd EAX,XMM2,0x3
  0x66,       0x0F, 0x3A, 0x16, 0xD3,        3,// pextrd EBX,XMM2,0x3
  0x66,       0x0F, 0x3A, 0x16, 0xD1,        3,// pextrd ECX,XMM2,0x3
  0x66,       0x0F, 0x3A, 0x16, 0xD2,        3,// pextrd EDX,XMM2,0x3
  0x66,       0x0F, 0x3A, 0x16, 0x5D, 0xBC,  3,// pextrd DWORD PTR [RBP-0x44],XMM3,0x3
  0x66, 0x48, 0x0F, 0x3A, 0x16, 0xD0,        3,// pextrq RAX,XMM2,0x3
  0x66, 0x48, 0x0F, 0x3A, 0x16, 0xD3,        3,// pextrq RBX,XMM2,0x3
  0x66, 0x48, 0x0F, 0x3A, 0x16, 0xD1,        3,// pextrq RCX,XMM2,0x3
  0x66, 0x48, 0x0F, 0x3A, 0x16, 0xD2,        3,// pextrq RDX,XMM2,0x3
  0x66, 0x48, 0x0F, 0x3A, 0x16, 0x5D, 0xC0,  3,// pextrq QWORD PTR [RBP-0x40],XMM3,0x3
  0x66,       0x0F, 0xC5, 0xC2,              3,// pextrw EAX,XMM2,0x3
  0x66,       0x0F, 0xC5, 0xDA,              3,// pextrw EBX,XMM2,0x3
  0x66,       0x0F, 0xC5, 0xCA,              3,// pextrw ECX,XMM2,0x3
  0x66,       0x0F, 0xC5, 0xD2,              3,// pextrw EDX,XMM2,0x3
  0x66,       0x0F, 0xC5, 0xC2,              3,// pextrw EAX,XMM2,0x3
  0x66,       0x0F, 0xC5, 0xDA,              3,// pextrw EBX,XMM2,0x3
  0x66, 0x44, 0x0F, 0xC5, 0xC2,              3,// pextrw R8D,XMM2,0x3
  0x66, 0x44, 0x0F, 0xC5, 0xD2,              3,// pextrw R10D,XMM2,0x3
  0x66,       0x0F, 0x3A, 0x15, 0x5D, 0xBA,  3,// pextrw WORD PTR [RBP-0x46],XMM3,0x3
  0x66,       0x0F, 0x38, 0x41, 0xCA,          // phminposuw XMM1,XMM2
  0x66,       0x0F, 0x38, 0x41, 0x5D, 0xD0,    // phminposuw XMM3,XMMWORD PTR [RBP-0x30]
  0x66,       0x0F, 0x3A, 0x20, 0xC8,        3,// pinsrb  XMM1,EAX,0x3
  0x66,       0x0F, 0x3A, 0x20, 0xCB,        3,// pinsrb  XMM1,EBX,0x3
  0x66,       0x0F, 0x3A, 0x20, 0xC9,        3,// pinsrb  XMM1,ECX,0x3
  0x66,       0x0F, 0x3A, 0x20, 0xCA,        3,// pinsrb  XMM1,EDX,0x3
  0x66,       0x0F, 0x3A, 0x20, 0x5D, 0xB8,  3,// pinsrb  XMM3,BYTE PTR [RBP-0x48],0x3
  0x66,       0x0F, 0x3A, 0x22, 0xC8,        3,// pinsrd  XMM1,EAX,0x3
  0x66,       0x0F, 0x3A, 0x22, 0xCB,        3,// pinsrd  XMM1,EBX,0x3
  0x66,       0x0F, 0x3A, 0x22, 0xC9,        3,// pinsrd  XMM1,ECX,0x3
  0x66,       0x0F, 0x3A, 0x22, 0xCA,        3,// pinsrd  XMM1,EDX,0x3
  0x66,       0x0F, 0x3A, 0x22, 0x5D, 0xBC,  3,// pinsrd  XMM3,DWORD PTR [RBP-0x44],0x3
  0x66, 0x48, 0x0F, 0x3A, 0x22, 0xC8,        3,// pinsrq  XMM1,RAX,0x3
  0x66, 0x48, 0x0F, 0x3A, 0x22, 0xCB,        3,// pinsrq  XMM1,RBX,0x3
  0x66, 0x48, 0x0F, 0x3A, 0x22, 0xC9,        3,// pinsrq  XMM1,RCX,0x3
  0x66, 0x48, 0x0F, 0x3A, 0x22, 0xCA,        3,// pinsrq  XMM1,RDX,0x3
  0x66, 0x48, 0x0F, 0x3A, 0x22, 0x5D, 0xC0,  3,// pinsrq  XMM3,QWORD PTR [RBP-0x40],0x3
  0x66,       0x0F, 0x38, 0x3C, 0xCA,          // pmaxsb  XMM1,XMM2
  0x66,       0x0F, 0x38, 0x3C, 0x5D, 0xD0,    // pmaxsb  XMM3,XMMWORD PTR [RBP-0x30]
  0x66,       0x0F, 0x38, 0x3D, 0xCA,          // pmaxsd  XMM1,XMM2
  0x66,       0x0F, 0x38, 0x3D, 0x5D, 0xD0,    // pmaxsd  XMM3,XMMWORD PTR [RBP-0x30]
  0x66,       0x0F, 0x38, 0x3F, 0xCA,          // pmaxud  XMM1,XMM2
  0x66,       0x0F, 0x38, 0x3F, 0x5D, 0xD0,    // pmaxud  XMM3,XMMWORD PTR [RBP-0x30]
  0x66,       0x0F, 0x38, 0x3E, 0xCA,          // pmaxuw  XMM1,XMM2
  0x66,       0x0F, 0x38, 0x3E, 0x5D, 0xD0,    // pmaxuw  XMM3,XMMWORD PTR [RBP-0x30]
  0x66,       0x0F, 0x38, 0x38, 0xCA,          // pminsb  XMM1,XMM2
  0x66,       0x0F, 0x38, 0x38, 0x5D, 0xD0,    // pminsb  XMM3,XMMWORD PTR [RBP-0x30]
  0x66,       0x0F, 0x38, 0x39, 0xCA,          // pminsd  XMM1,XMM2
  0x66,       0x0F, 0x38, 0x39, 0x5D, 0xD0,    // pminsd  XMM3,XMMWORD PTR [RBP-0x30]
  0x66,       0x0F, 0x38, 0x3B, 0xCA,          // pminud  XMM1,XMM2
  0x66,       0x0F, 0x38, 0x3B, 0x5D, 0xD0,    // pminud  XMM3,XMMWORD PTR [RBP-0x30]
  0x66,       0x0F, 0x38, 0x3A, 0xCA,          // pminuw  XMM1,XMM2
  0x66,       0x0F, 0x38, 0x3A, 0x5D, 0xD0,    // pminuw  XMM3,XMMWORD PTR [RBP-0x30]
  0x66,       0x0F, 0x38, 0x20, 0xCA,          // pmovsxbw XMM1,XMM2
  0x66,       0x0F, 0x38, 0x20, 0x5D, 0xC0,    // pmovsxbw XMM3,QWORD PTR [RBP-0x40]
  0x66,       0x0F, 0x38, 0x21, 0xCA,          // pmovsxbd XMM1,XMM2
  0x66,       0x0F, 0x38, 0x21, 0x5D, 0xBC,    // pmovsxbd XMM3,DWORD PTR [RBP-0x44]
  0x66,       0x0F, 0x38, 0x22, 0xCA,          // pmovsxbq XMM1,XMM2
  0x66,       0x0F, 0x38, 0x22, 0x5D, 0xBA,    // pmovsxbq XMM3,WORD PTR [RBP-0x46]
  0x66,       0x0F, 0x38, 0x23, 0xCA,          // pmovsxwd XMM1,XMM2
  0x66,       0x0F, 0x38, 0x23, 0x5D, 0xC0,    // pmovsxwd XMM3,QWORD PTR [RBP-0x40]
  0x66,       0x0F, 0x38, 0x24, 0xCA,          // pmovsxwq XMM1,XMM2
  0x66,       0x0F, 0x38, 0x24, 0x5D, 0xBC,    // pmovsxwq XMM3,DWORD PTR [RBP-0x44]
  0x66,       0x0F, 0x38, 0x25, 0xCA,          // pmovsxdq XMM1,XMM2
  0x66,       0x0F, 0x38, 0x25, 0x5D, 0xC0,    // pmovsxdq XMM3,QWORD PTR [RBP-0x40]
  0x66,       0x0F, 0x38, 0x30, 0xCA,          // pmovzxbw XMM1,XMM2
  0x66,       0x0F, 0x38, 0x30, 0x5D, 0xC0,    // pmovzxbw XMM3,QWORD PTR [RBP-0x40]
  0x66,       0x0F, 0x38, 0x31, 0xCA,          // pmovzxbd XMM1,XMM2
  0x66,       0x0F, 0x38, 0x31, 0x5D, 0xBC,    // pmovzxbd XMM3,DWORD PTR [RBP-0x44]
  0x66,       0x0F, 0x38, 0x32, 0xCA,          // pmovzxbq XMM1,XMM2
  0x66,       0x0F, 0x38, 0x32, 0x5D, 0xBA,    // pmovzxbq XMM3,WORD PTR [RBP-0x46]
  0x66,       0x0F, 0x38, 0x33, 0xCA,          // pmovzxwd XMM1,XMM2
  0x66,       0x0F, 0x38, 0x33, 0x5D, 0xC0,    // pmovzxwd XMM3,QWORD PTR [RBP-0x40]
  0x66,       0x0F, 0x38, 0x34, 0xCA,          // pmovzxwq XMM1,XMM2
  0x66,       0x0F, 0x38, 0x34, 0x5D, 0xBC,    // pmovzxwq XMM3,DWORD PTR [RBP-0x44]
  0x66,       0x0F, 0x38, 0x35, 0xCA,          // pmovzxdq XMM1,XMM2
  0x66,       0x0F, 0x38, 0x35, 0x5D, 0xC0,    // pmovzxdq XMM3,QWORD PTR [RBP-0x40]
  0x66,       0x0F, 0x38, 0x28, 0xCA,          // pmuldq  XMM1,XMM2
  0x66,       0x0F, 0x38, 0x28, 0x5D, 0xD0,    // pmuldq  XMM3,XMMWORD PTR [RBP-0x30]
  0x66,       0x0F, 0x38, 0x40, 0xCA,          // pmulld  XMM1,XMM2
  0x66,       0x0F, 0x38, 0x40, 0x5D, 0xD0,    // pmulld  XMM3,XMMWORD PTR [RBP-0x30]
  0x66,       0x0F, 0x38, 0x17, 0xCA,          // ptest   XMM1,XMM2
  0x66,       0x0F, 0x38, 0x17, 0x5D, 0xD0,    // ptest   XMM3,XMMWORD PTR [RBP-0x30]
  0x66,       0x0F, 0x3A, 0x09, 0xCA,        3,// roundpd XMM1,XMM2,0x3
  0x66,       0x0F, 0x3A, 0x09, 0x5D, 0xD0,  3,// roundpd XMM3,XMMWORD PTR [RBP-0x30],0x3
  0x66,       0x0F, 0x3A, 0x08, 0xCA,        3,// roundps XMM1,XMM2,0x3
  0x66,       0x0F, 0x3A, 0x08, 0x5D, 0xD0,  3,// roundps XMM3,XMMWORD PTR [RBP-0x30],0x3
  0x66,       0x0F, 0x3A, 0x0B, 0xCA,        3,// roundsd XMM1,XMM2,0x3
  0x66,       0x0F, 0x3A, 0x0B, 0x5D, 0xC0,  3,// roundsd XMM3,QWORD PTR [RBP-0x40],0x3
  0x66,       0x0F, 0x3A, 0x0A, 0xCA,        3,// roundss XMM1,XMM2,0x3
  0x66,       0x0F, 0x3A, 0x0A, 0x4D, 0xBC,  3,// roundss xmm1,dword ptr [rbp-0x44],0x3
    ];

    asm
    {
        call  L1;

        blendpd      XMM1, XMM2, 3;
        blendpd      XMM3, m128, 3;

        blendps      XMM1, XMM2, 3;
        blendps      XMM3, m128, 3;

        blendvpd     XMM1, XMM2, XMM0;
        blendvpd     XMM3, m128, XMM0;

        blendvps     XMM1, XMM2, XMM0;
        blendvps     XMM3, m128, XMM0;

        dppd         XMM1, XMM2, 3;
        dppd         XMM3, m128, 3;

        dpps         XMM1, XMM2, 3;
        dpps         XMM3, m128, 3;

        extractps     EDX, XMM2, 3;
        extractps     m32, XMM2, 3;

        insertps     XMM1, XMM2, 3;
        insertps     XMM3,  m32, 3;

        movntdqa     XMM1, m128;

        mpsadbw      XMM1, XMM2, 3;
        mpsadbw      XMM3, m128, 3;

        packusdw     XMM1, XMM2;
        packusdw     XMM3, m128;

        pblendvb     XMM1, XMM2, XMM0;
        pblendvb     XMM3, m128, XMM0;

        pblendw      XMM1, XMM2, 3;
        pblendw      XMM3, m128, 3;

        pcmpeqq      XMM1, XMM2;
        pcmpeqq      XMM3, m128;

        pextrb        EAX, XMM2, 3;
        pextrb        EBX, XMM2, 3;
        pextrb        ECX, XMM2, 3;
        pextrb        EDX, XMM2, 3;
        pextrb        RAX, XMM2, 3;
        pextrb        RBX, XMM2, 3;
        pextrb        R8 , XMM2, 3;
        pextrb        R10, XMM2, 3;
        pextrb         m8, XMM3, 3;

        pextrd        EAX, XMM2, 3;
        pextrd        EBX, XMM2, 3;
        pextrd        ECX, XMM2, 3;
        pextrd        EDX, XMM2, 3;
        pextrd        m32, XMM3, 3;

        pextrq        RAX, XMM2, 3;
        pextrq        RBX, XMM2, 3;
        pextrq        RCX, XMM2, 3;
        pextrq        RDX, XMM2, 3;
        pextrq        m64, XMM3, 3;

        pextrw        EAX, XMM2, 3;
        pextrw        EBX, XMM2, 3;
        pextrw        ECX, XMM2, 3;
        pextrw        EDX, XMM2, 3;
        pextrw        RAX, XMM2, 3;
        pextrw        RBX, XMM2, 3;
        pextrw        R8 , XMM2, 3;
        pextrw        R10, XMM2, 3;
        pextrw        m16, XMM3, 3;

        phminposuw   XMM1, XMM2;
        phminposuw   XMM3, m128;

        pinsrb       XMM1,  EAX, 3;
        pinsrb       XMM1,  EBX, 3;
        pinsrb       XMM1,  ECX, 3;
        pinsrb       XMM1,  EDX, 3;
        pinsrb       XMM3,   m8, 3;

        pinsrd       XMM1,  EAX, 3;
        pinsrd       XMM1,  EBX, 3;
        pinsrd       XMM1,  ECX, 3;
        pinsrd       XMM1,  EDX, 3;
        pinsrd       XMM3,  m32, 3;

        pinsrq       XMM1,  RAX, 3;
        pinsrq       XMM1,  RBX, 3;
        pinsrq       XMM1,  RCX, 3;
        pinsrq       XMM1,  RDX, 3;
        pinsrq       XMM3,  m64, 3;

        pmaxsb       XMM1, XMM2;
        pmaxsb       XMM3, m128;

        pmaxsd       XMM1, XMM2;
        pmaxsd       XMM3, m128;

        pmaxud       XMM1, XMM2;
        pmaxud       XMM3, m128;

        pmaxuw       XMM1, XMM2;
        pmaxuw       XMM3, m128;

        pminsb       XMM1, XMM2;
        pminsb       XMM3, m128;

        pminsd       XMM1, XMM2;
        pminsd       XMM3, m128;

        pminud       XMM1, XMM2;
        pminud       XMM3, m128;

        pminuw       XMM1, XMM2;
        pminuw       XMM3, m128;

        pmovsxbw     XMM1, XMM2;
        pmovsxbw     XMM3,  m64;

        pmovsxbd     XMM1, XMM2;
        pmovsxbd     XMM3,  m32;

        pmovsxbq     XMM1, XMM2;
        pmovsxbq     XMM3,  m16;

        pmovsxwd     XMM1, XMM2;
        pmovsxwd     XMM3,  m64;

        pmovsxwq     XMM1, XMM2;
        pmovsxwq     XMM3,  m32;

        pmovsxdq     XMM1, XMM2;
        pmovsxdq     XMM3,  m64;

        pmovzxbw     XMM1, XMM2;
        pmovzxbw     XMM3,  m64;

        pmovzxbd     XMM1, XMM2;
        pmovzxbd     XMM3,  m32;

        pmovzxbq     XMM1, XMM2;
        pmovzxbq     XMM3,  m16;

        pmovzxwd     XMM1, XMM2;
        pmovzxwd     XMM3,  m64;

        pmovzxwq     XMM1, XMM2;
        pmovzxwq     XMM3,  m32;

        pmovzxdq     XMM1, XMM2;
        pmovzxdq     XMM3,  m64;

        pmuldq       XMM1, XMM2;
        pmuldq       XMM3, m128;

        pmulld       XMM1, XMM2;
        pmulld       XMM3, m128;

        ptest        XMM1, XMM2;
        ptest        XMM3, m128;

        roundpd      XMM1, XMM2, 3;
        roundpd      XMM3, m128, 3;

        roundps      XMM1, XMM2, 3;
        roundps      XMM3, m128, 3;

        roundsd      XMM1, XMM2, 3;
        roundsd      XMM3,  m64, 3;

        roundss      XMM1, XMM2, 3;
        roundss      XMM1,  m32, 3;

L1:     pop     RAX;
        mov     p[RBP],RAX;
    }

    foreach (i,b; data)
    {
        //printf("data[%d] = 0x%02x, should be 0x%02x\n", i, p[i], b);
        assert(p[i] == b);
    }
}

/****************************************************/

/* ======================= SSE4.2 ======================= */

void test59()
{
    ubyte* p;
    byte   m8;
    short m16;
    int   m32;
    M64   m64;
    M128 m128;
    static ubyte data[] =
    [
0xF2,       0x0F, 0x38, 0xF0, 0xC1,           // crc32   EAX,  CL
0x66, 0xF2, 0x0F, 0x38, 0xF1, 0xC1,           // crc32   EAX,  CX
0xF2,       0x0F, 0x38, 0xF1, 0xC1,           // crc32   EAX, ECX
0xF2, 0x48, 0x0F, 0x38, 0xF0, 0xC1,           // crc32   RAX,  CL
0xF2, 0x48, 0x0F, 0x38, 0xF1, 0xC1,           // crc32   RAX, RCX
0xF2,       0x0F, 0x38, 0xF0, 0x55, 0xB8,     // crc32   EDX, byte ptr [RBP-0x48]
0x66, 0xF2, 0x0F, 0x38, 0xF1, 0x55, 0xBA,     // crc32   EDX, word ptr [RBP-0x46]
0xF2,       0x0F, 0x38, 0xF1, 0x55, 0xBC,     // crc32   EDX,dword ptr [RBP-0x44]
0xF2, 0x48, 0x0F, 0x38, 0xF0, 0x55, 0xB8,     // crc32   RDX, byte ptr [RBP-0x48]
0xF2, 0x48, 0x0F, 0x38, 0xF1, 0x55, 0xC0,     // crc32   RDX,qword ptr [RBP-0x40]
0x66,       0x0F, 0x3A, 0x61, 0xCA,        2, // pcmpestri XMM1,XMM2, 2
0x66,       0x0F, 0x3A, 0x61, 0x5D, 0xD0,  2, // pcmpestri XMM3,xmmword ptr [RBP-0x30], 2
0x66,       0x0F, 0x3A, 0x60, 0xCA,        2, // pcmpestrm XMM1,XMM2, 2
0x66,       0x0F, 0x3A, 0x60, 0x5D, 0xD0,  2, // pcmpestrm XMM3,xmmword ptr [RBP-0x30], 2
0x66,       0x0F, 0x3A, 0x63, 0xCA,        2, // pcmpistri XMM1,XMM2, 2
0x66,       0x0F, 0x3A, 0x63, 0x5D, 0xD0,  2, // pcmpistri XMM3,xmmword ptr [RBP-0x30], 2
0x66,       0x0F, 0x3A, 0x62, 0xCA,        2, // pcmpistrm XMM1,XMM2, 2
0x66,       0x0F, 0x3A, 0x62, 0x5D, 0xD0,  2, // pcmpistrm XMM3,xmmword ptr [RBP-0x30], 2
0x66,       0x0F, 0x38, 0x37, 0xCA,           // pcmpgtq   XMM1,XMM2
0x66,       0x0F, 0x38, 0x37, 0x5D, 0xD0,     // pcmpgtq   XMM3,xmmword ptr [RBP-0x30]
0x66, 0xF3, 0x0F, 0xB8, 0xC1,                 // popcnt   AX, CX
0xF3,       0x0F, 0xB8, 0xC1,                 // popcnt  EAX, ECX
0xF3, 0x48, 0x0F, 0xB8, 0xC1,                 // popcnt  RAX, RCX
0x66, 0xF3, 0x0F, 0xB8, 0x55, 0xBA,           // popcnt   DX, word ptr [RBP-0x46]
0xF3,       0x0F, 0xB8, 0x55, 0xBC,           // popcnt  EDX,dword ptr [RBP-0x44]
0xF3, 0x48, 0x0F, 0xB8, 0x55, 0xC0            // popcnt  RDX,qword ptr [RBP-0x40]
    ];

    asm
    {
        call  L1;

        crc32    EAX,  CL;
        crc32    EAX,  CX;
        crc32    EAX, ECX;
        crc32    RAX,  CL;
        crc32    RAX, RCX;
        crc32    EDX,  m8;
        crc32    EDX, m16;
        crc32    EDX, m32;
        crc32    RDX,  m8;
        crc32    RDX, m64;

        pcmpestri  XMM1, XMM2, 2;
        pcmpestri  XMM3, m128, 2;

        pcmpestrm  XMM1, XMM2, 2;
        pcmpestrm  XMM3, m128, 2;

        pcmpistri  XMM1, XMM2, 2;
        pcmpistri  XMM3, m128, 2;

        pcmpistrm  XMM1, XMM2, 2;
        pcmpistrm  XMM3, m128, 2;

        pcmpgtq  XMM1, XMM2;
        pcmpgtq  XMM3, m128;

        popcnt  AX,  CX;
        popcnt EAX, ECX;
        popcnt RAX, RCX;
        popcnt  DX, m16;
        popcnt EDX, m32;
        popcnt RDX, m64;

L1:     pop     RAX;
        mov     p[RBP],RAX;
    }

    foreach (i,b; data)
    {
        //printf("data[%d] = 0x%02x, should be 0x%02x\n", i, p[i], b);
        assert(p[i] == b);
    }
}

void test60()
{
    ubyte *p;
    static ubyte data[] =
    [
        0x49, 0x8B, 0x00, // mov RAX, [R8]
        0x4D, 0x8B, 0x00, // mov R8, [R8]
        0x49, 0x89, 0x00, // mov [R8], RAX
        0x4D, 0x89, 0x00, // mov [R8], R8
        0x41, 0x0F, 0x10, 0x00, // movups XMM0, [R8]
        0x45, 0x0F, 0x10, 0x00, // movups XMM8, [R8]
    ];

    asm
    {
        call	L1;

        mov RAX, [R8];
        mov R8, [R8];
        mov [R8], RAX;
        mov [R8], R8;
        movups XMM0, [R8];
        movups XMM8, [R8];

L1:
        pop RAX;
        mov p[RBP], RAX;
    }

    foreach (i, b; data)
    {
        assert(p[i] == b);
    }
}

void test2941()
{
    ubyte *p;
    static ubyte data[] =
    [
        0x9B, 0xDF, 0xE0,	// fstsw AX;
    ];
    int i;

    asm
    {
        call	L1			;

        fstsw AX;

L1:
        pop	RBX			;
        mov	p[RBP],RBX		;
    }
    for (i = 0; i < data.length; i++)
    {
        assert(p[i] == data[i]);
    }
}

/****************************************************/
/****************************************************/

int main()
{
    printf("Testing iasm64.d\n");
    test1();
    test2();
    test3();
    test4();
    test5();
    test6();
    //test7(); TODO 16bit seg
    test8();
    //test9();  Fails
    //test10(); Fails
    test11();
    test12();
    test13();
    test14();
    test15();
    //test16();		// add this one from \cbx\test\iasm.c ?
    test17();
    test18();
    test19();
    //test20(); 8087
    test21();
    test22();
    test23();
    test24();
    test25();
    test26();
    test27();
    test28();
    //test29(); offsetof?
    test30();
    test31();
    test32();
    test33();
    test34();
    //test35(); RIP addressing?
    //test36(); RIP addressing?
    test37();
    test38();
    test39();
    test40();
    test41();
    test42();
    test43();
    test44();
    test45();
    test46();
    //test47(); RIP addressing?
    test48();
    test49();
    test50();
    //Test51
    test52();
    test53();
    test54();
    test55();
    test56();
    test57();
    test58();
    test59();
    test60();
    test2941();

    printf("Success\n");
    return 0;
}

}
else
{
    int main() { return 0; }
}

