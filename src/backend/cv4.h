//_ cv4.h
// Codeview 4 stuff
// See "Microsoft Symbol and Type OMF" document

#define OEM 0x42        // Digital Mars OEM number (picked at random)

// Symbol Indices
#define S_COMPILE       1
#define S_REGISTER      2
#define S_CONST         3
#define S_UDT           4
#define S_SSEARCH       5
#define S_END           6
#define S_SKIP          7
#define S_CVRESERVE     8
#define S_OBJNAME       9
#define S_ENDARG        0x0A
#define S_COBOLUDT      0x0B
#define S_MANYREG       0x0C
#define S_RETURN        0x0D
#define S_ENTRYTHIS     0x0E
#define S_TDBNAME       0x0F

#define S_BPREL16       0x100
#define S_LDATA16       0x101
#define S_GDATA16       0x102
#define S_PUB16         0x103
#define S_LPROC16       0x104
#define S_GPROC16       0x105
#define S_THUNK16       0x106
#define S_BLOCK16       0x107
#define S_WITH16        0x108
#define S_LABEL16       0x109
#define S_CEXMODEL16    0x10A
#define S_VFTPATH16     0x10B

#define S_BPREL32       0x200
#define S_LDATA32       0x201
#define S_GDATA32       0x202
#define S_PUB32         0x203
#define S_LPROC32       0x204
#define S_GPROC32       0x205
#define S_THUNK32       0x206
#define S_BLOCK32       0x207
#define S_WITH32        0x208
#define S_LABEL32       0x209
#define S_CEXMODEL32    0x20A
#define S_VFTPATH32     0x20B

// Leaf Indices
#define LF_MODIFIER     1
#define LF_POINTER      2
#define LF_ARRAY        3
#define LF_CLASS        4
#define LF_STRUCTURE    5
#define LF_UNION        6
#define LF_ENUM         7
#define LF_PROCEDURE    8
#define LF_MFUNCTION    9
#define LF_VTSHAPE      0x0A
#define LF_COBOL0       0x0B
#define LF_COBOL1       0x0C
#define LF_BARRAY       0x0D
#define LF_LABEL        0x0E
#define LF_NULL         0x0F
#define LF_NOTTRAN      0x10
#define LF_DIMARRAY     0x11
#define LF_VFTPATH      0x12
#define LF_PRECOMP      0x13
#define LF_ENDPRECOMP   0x14
#define LF_OEM          0x15
#define LF_TYPESERVER   0x16

// D extensions (not used, causes linker to fail)
#define LF_DYN_ARRAY    0x17
#define LF_ASSOC_ARRAY  0x18
#define LF_DELEGATE     0x19

#define LF_SKIP         0x200
#define LF_ARGLIST      0x201
#define LF_DEFARG       0x202
#define LF_LIST         0x203
#define LF_FIELDLIST    0x204
#define LF_DERIVED      0x205
#define LF_BITFIELD     0x206
#define LF_METHODLIST   0x207
#define LF_DIMCONU      0x208
#define LF_DIMCONLU     0x209
#define LF_DIMVARU      0x20A
#define LF_DIMVARLU     0x20B
#define LF_REFSYM       0x20C

#define LF_BCLASS       0x400
#define LF_VBCLASS      0x401
#define LF_IVBCLASS     0x402
#define LF_ENUMERATE    0x403
#define LF_FRIENDFCN    0x404
#define LF_INDEX        0x405
#define LF_MEMBER       0x406
#define LF_STMEMBER     0x407
#define LF_METHOD       0x408
#define LF_NESTTYPE     0x409
#define LF_VFUNCTAB     0x40A
#define LF_FRIENDCLS    0x40B

#define LF_NUMERIC      0x8000
#define LF_CHAR         0x8000
#define LF_SHORT        0x8001
#define LF_USHORT       0x8002
#define LF_LONG         0x8003
#define LF_ULONG        0x8004
#define LF_REAL32       0x8005
#define LF_REAL64       0x8006
#define LF_REAL80       0x8007
#define LF_REAL128      0x8008
#define LF_QUADWORD     0x8009
#define LF_UQUADWORD    0x800A
#define LF_REAL48       0x800B

#define LF_COMPLEX32    0x800C
#define LF_COMPLEX64    0x800D
#define LF_COMPLEX80    0x800E
#define LF_COMPLEX128   0x800F

#define LF_VARSTRING    0x8010

