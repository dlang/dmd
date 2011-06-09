// Copyright (c) 1999-2010 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// http://www.digitalmars.com

import std.c.stdio;

struct M128 { int a,b,c,d; };
struct M64 { int a,b; };

__gshared byte b;
__gshared short w;
__gshared int i;
__gshared long l;

/****************************************************/

void test1()
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

void test2()
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

void test3()
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

        0x44, 0x0F, 0xA4, 0xC0, 0x04,    // shld   EAX, R8D, 4
        0x44, 0x0F, 0xA5, 0xC0,          // shld   EAX, R8D, CL
        0x4C, 0x0F, 0xA4, 0xC0, 0x04,    // shld   RAX, R8,  4
        0x4C, 0x0F, 0xA5, 0xC0,          // shld   RAX, R8 , CL

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

        shld  EAX, R8D, 4;
        shld  EAX, R8D, CL;
        shld  RAX, R8 , 4;
        shld  RAX, R8 , CL;

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

int main()
{
    printf("Testing iasm64.d\n");
    test1();
    test2();
    test3();

    printf("Success\n");
    return 0;
}

