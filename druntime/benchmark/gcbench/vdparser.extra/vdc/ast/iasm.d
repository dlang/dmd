// This file is part of Visual D
//
// Visual D integrates the D programming language into Visual Studio
// Copyright (c) 2010-2011 by Rainer Schuetze, All Rights Reserved
//
// Distributed under the Boost Software License, Version 1.0.
// See accompanying file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt

module vdc.ast.iasm;

import vdc.util;
import vdc.lexer;
import vdc.ast.node;
import vdc.ast.writer;

class AsmInstruction : Node
{
    mixin ForwardCtor!();

    Token[] tokens;

    void addToken(Token tok)
    {
        Token ntok = new Token;
        ntok.copy(tok);
        tokens ~= ntok;
    }

    override void toD(CodeWriter writer)
    {
        foreach(t; tokens)
        {
            writer(t.txt, " ");
        }
    }
}


//AsmInstruction:
//    Identifier : AsmInstruction
//    "align" IntegerExpression
//    "even"
//    "naked"
//    "db" Operands
//    "ds" Operands
//    "di" Operands
//    "dl" Operands
//    "df" Operands
//    "dd" Operands
//    "de" Operands
//    Opcode
//    Opcode Operands
//
//Operands:
//    Operand
//    Operand , Operands
//
//IntegerExpression:
//    IntegerLiteral
//    Identifier
//
//Operand:
//    AsmExp
//
//AsmExp:
//    AsmLogOrExp
//    AsmLogOrExp ? AsmExp : AsmExp
//
//AsmLogOrExp:
//    AsmLogAndExp
//    AsmLogAndExp || AsmLogAndExp
//
//AsmLogAndExp:
//    AsmOrExp
//    AsmOrExp && AsmOrExp
//
//AsmOrExp:
//    AsmXorExp
//    AsmXorExp | AsmXorExp
//
//AsmXorExp:
//    AsmAndExp
//    AsmAndExp ^ AsmAndExp
//
//AsmAndExp:
//    AsmEqualExp
//    AsmEqualExp & AsmEqualExp
//
//AsmEqualExp:
//    AsmRelExp
//    AsmRelExp == AsmRelExp
//    AsmRelExp != AsmRelExp
//
//AsmRelExp:
//    AsmShiftExp
//    AsmShiftExp < AsmShiftExp
//    AsmShiftExp <= AsmShiftExp
//    AsmShiftExp > AsmShiftExp
//    AsmShiftExp >= AsmShiftExp
//
//AsmShiftExp:
//    AsmAddExp
//    AsmAddExp << AsmAddExp
//    AsmAddExp >> AsmAddExp
//    AsmAddExp >>> AsmAddExp
//
//AsmAddExp:
//    AsmMulExp
//    AsmMulExp + AsmMulExp
//    AsmMulExp - AsmMulExp
//
//AsmMulExp:
//    AsmBrExp
//    AsmBrExp * AsmBrExp
//    AsmBrExp / AsmBrExp
//    AsmBrExp % AsmBrExp
//
//AsmBrExp:
//    AsmUnaExp
//    AsmBrExp [ AsmExp ]
//
//AsmUnaExp:
//    AsmTypePrefix AsmExp
//    "offsetof" AsmExp
//    "seg" AsmExp
//    + AsmUnaExp
//    - AsmUnaExp
//    ! AsmUnaExp
//    ~ AsmUnaExp
//    AsmPrimaryExp
//
//AsmPrimaryExp:
//    IntegerLiteral
//    FloatLiteral
//    "__LOCAL_SIZE"
//    $
//    Register
//    DotIdentifier
//
//DotIdentifier:
//    Identifier
//    Identifier . DotIdentifier
//
//AsmTypePrefix:
//    "near"  "ptr"
//    "far"   "ptr"
//    byte    "ptr"
//    short   "ptr"
//    int     "ptr"
//    "word"  "ptr"
//    "dword" "ptr"
//    "qword" "ptr"
//    float   "ptr"
//    double  "ptr"
//    real    "ptr"
//
//Register:
//    TOK_register
//
//Opcode:
//    TOK_opcode
//
//Identifier:
//    TOK_Identifier
//
//Integer:
//    IntegerLiteral
//
//IntegerLiteral:
//    TOK_IntegerLiteral
//
//FloatLiteral:
//    TOK_FloatLiteral
//
//StringLiteral:
//    TOK_StringLiteral
//
//CharacterLiteral:
//    TOK_CharacterLiteral
//
//// removed from grammar:
////
////Register:
////    AL AH AX EAX
////    BL BH BX EBX
////    CL CH CX ECX
////    DL DH DX EDX
////    BP EBP
////    SP ESP
////    DI EDI
////    SI ESI
////    ES CS SS DS GS FS
////    CR0 CR2 CR3 CR4
////    DR0 DR1 DR2 DR3 DR6 DR7
////    TR3 TR4 TR5 TR6 TR7
////    ST
////    ST(0) ST(1) ST(2) ST(3) ST(4) ST(5) ST(6) ST(7)
////    MM0 MM1 MM2 MM3 MM4 MM5 MM6 MM7
////    XMM0 XMM1 XMM2 XMM3 XMM4 XMM5 XMM6 XMM7
////
