
/* Compiler implementation of the D programming language
 * Copyright (c) 1999-2014 by Digital Mars
 * All Rights Reserved
 * written by Walter Bright
 * http://www.digitalmars.com
 * Distributed under the Boost Software License, Version 1.0.
 * http://www.boost.org/LICENSE_1_0.txt
 * https://github.com/D-Programming-Language/dmd/blob/master/src/lexer.h
 */

#ifndef DMD_LEXER_H
#define DMD_LEXER_H

#ifdef __DMC__
#pragma once
#endif /* __DMC__ */

#include "root.h"
#include "mars.h"
#include "tokens.h"

struct StringTable;
class Identifier;

class Lexer
{
public:
    static OutBuffer stringbuffer;

    Loc scanloc;                // for error messages

    const utf8_t *base;        // pointer to start of buffer
    const utf8_t *end;         // past end of buffer
    const utf8_t *p;           // current character
    const utf8_t *line;        // start of current line
    Token token;
    int doDocComment;           // collect doc comment information
    int anyToken;               // !=0 means seen at least one token
    int commentToken;           // !=0 means comments are TOKcomment's
    bool errors;                // errors occurred during lexing or parsing

    Lexer(const char *filename,
        const utf8_t *base, size_t begoffset, size_t endoffset,
        int doDocComment, int commentToken);

    static void initLexer();

    TOK nextToken();
    TOK peekNext();
    TOK peekNext2();
    void scan(Token *t);
    Token *peek(Token *t);
    Token *peekPastParen(Token *t);
    unsigned escapeSequence();
    TOK wysiwygStringConstant(Token *t, int tc);
    TOK hexStringConstant(Token *t);
    TOK delimitedStringConstant(Token *t);
    TOK tokenStringConstant(Token *t);
    TOK escapeStringConstant(Token *t, int wide);
    TOK charConstant(Token *t, int wide);
    void stringPostfix(Token *t);
    TOK number(Token *t);
    TOK inreal(Token *t);

    Loc loc()
    {
        scanloc.charnum = (unsigned)(1 + p-line);
        return scanloc;
    }

    void error(const char *format, ...);
    void error(Loc loc, const char *format, ...);
    void deprecation(const char *format, ...);
    void poundLine();
    unsigned decodeUTF();
    void getDocComment(Token *t, unsigned lineComment);

    static const utf8_t *combineComments(const utf8_t *c1, const utf8_t *c2);

private:
    void endOfLine();
};

#endif /* DMD_LEXER_H */
