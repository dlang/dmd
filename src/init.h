
// Copyright (c) 1999-2004 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// www.digitalmars.com
// License for redistribution is by either the Artistic License
// in artistic.txt, or the GNU General Public License in gnu.txt.
// See the included readme.txt for details.

#ifndef INIT_H
#define INIT_H

#include "root.h"

#include "mars.h"

struct Identifier;
struct Expression;
struct Scope;
struct Type;
struct dt_t;
struct AggregateDeclaration;
struct ExpInitializer;

struct Initializer : Object
{
    Loc loc;

    Initializer(Loc loc);
    virtual Initializer *syntaxCopy();
    virtual Initializer *semantic(Scope *sc, Type *t);
    virtual Expression *toExpression() = 0;
    virtual void toCBuffer(OutBuffer *buf) = 0;

    static Array *arraySyntaxCopy(Array *ai);

    virtual dt_t *toDt();

    virtual ExpInitializer *isExpInitializer() { return NULL; }
};

struct StructInitializer : Initializer
{
    Array field;	// of Identifier *'s before semantic(), VarDeclaration *'s after
    Array value;	// parallel array of Initializer *'s
    AggregateDeclaration *ad;	// which aggregate this is for

    StructInitializer(Loc loc);
    Initializer *syntaxCopy();
    void addInit(Identifier *field, Initializer *value);
    Initializer *semantic(Scope *sc, Type *t);
    Expression *toExpression();
    void toCBuffer(OutBuffer *buf);

    dt_t *toDt();
};

struct ArrayInitializer : Initializer
{
    Array index;	// of Expression *'s
    Array value;	// of Initializer *'s
    unsigned dim;	// length of array being initialized
    Type *type;		// type that array will be used to initialize
    int sem;		// !=0 if semantic() is run

    ArrayInitializer(Loc loc);
    Initializer *syntaxCopy();
    void addInit(Expression *index, Initializer *value);
    Initializer *semantic(Scope *sc, Type *t);
    Expression *toExpression();
    void toCBuffer(OutBuffer *buf);

    dt_t *toDt();
    dt_t *toDtBit();	// for bit arrays
};

struct ExpInitializer : Initializer
{
    Expression *exp;

    ExpInitializer(Loc loc, Expression *exp);
    Initializer *syntaxCopy();
    Initializer *semantic(Scope *sc, Type *t);
    Expression *toExpression();
    void toCBuffer(OutBuffer *buf);

    dt_t *toDt();

    virtual ExpInitializer *isExpInitializer() { return this; }
};

#endif
