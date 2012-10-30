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

/************** Added Since CV4 *********************/

#define LF_MODIFIER_V2          0x1001
#define LF_POINTER_V2           0x1002
#define LF_ARRAY_V2             0x1003
#define LF_CLASS_V2             0x1004
#define LF_STRUCTURE_V2         0x1005
#define LF_UNION_V2             0x1006
#define LF_ENUM_V2              0x1007
#define LF_PROCEDURE_V2         0x1008
#define LF_MFUNCTION_V2         0x1009
#define LF_COBOL0_V2            0x100A
#define LF_BARRAY_V2            0x100B
#define LF_DIMARRAY_V2          0x100C
#define LF_VFTPATH_V2           0x100D
#define LF_PRECOMP_V2           0x100E
#define LF_OEM_V2               0x100F

#define LF_SKIP_V2              0x1200
#define LF_ARGLIST_V2           0x1201
#define LF_DEFARG_V2            0x1202
#define LF_FIELDLIST_V2         0x1203
#define LF_DERIVED_V2           0x1204
#define LF_BITFIELD_V2          0x1205
#define LF_METHODLIST_V2        0x1206
#define LF_DIMCONU_V2           0x1207
#define LF_DIMCONLU_V2          0x1208
#define LF_DIMVARU_V2           0x1209
#define LF_DIMVARLU_V2          0X120A

#define LF_BCLASS_V2            0x1400
#define LF_VBCLASS_V2           0x1401
#define LF_IVBCLASS_V2          0x1402
#define LF_FRIENDFCN_V2         0x1403
#define LF_INDEX_V2             0x1404
#define LF_MEMBER_V2            0x1405
#define LF_STMEMBER_V2          0x1406
#define LF_METHOD_V2            0x1407
#define LF_NESTTYPE_V2          0x1408
#define LF_VFUNCTAB_V2          0x1409
#define LF_FRIENDCLS_V2         0x140A
#define LF_ONEMETHOD_V2         0x140B
#define LF_VFUNCOFF_V2          0x140C
#define LF_NESTTYPEEX_V2        0x140D

#define LF_ENUMERATE_V3         0x1502
#define LF_ARRAY_V3             0x1503
#define LF_CLASS_V3             0x1504
#define LF_STRUCTURE_V3         0x1505
#define LF_UNION_V3             0x1506
#define LF_ENUM_V3              0x1507
#define LF_MEMBER_V3            0x150D
#define LF_STMEMBER_V3          0x150E
#define LF_METHOD_V3            0x150F
#define LF_NESTTYPE_V3          0x1510
#define LF_ONEMETHOD_V3         0x1511

#define S_COMPILAND_V3          0x1101
#define S_THUNK_V3              0x1102
#define S_BLOCK_V3              0x1103
#define S_LABEL_V3              0x1105
#define S_REGISTER_V3           0x1106
#define S_CONSTANT_V3           0x1107
#define S_UDT_V3                0x1108
#define S_BPREL_V3              0x110B
#define S_LDATA_V3              0x110C
#define S_GDATA_V3              0x110D
#define S_PUB_V3                0x110E
#define S_LPROC_V3              0x110F
#define S_GPROC_V3              0x1110
#define S_BPREL_XXXX_V3         0x1111
#define S_MSTOOL_V3             0x1116
#define S_PUB_FUNC1_V3          0x1125
#define S_PUB_FUNC2_V3          0x1127
#define S_SECTINFO_V3           0x1136
#define S_SUBSECTINFO_V3        0x1137
#define S_ENTRYPOINT_V3         0x1138
#define S_SECUCOOKIE_V3         0x113A
#define S_MSTOOLINFO_V3         0x113C
#define S_MSTOOLENV_V3          0x113D

