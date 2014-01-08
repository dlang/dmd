
// Compiler implementation of the D programming language
// Copyright (c) 1999-2013 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// http://www.digitalmars.com
// License for redistribution is by either the Artistic License
// in artistic.txt, or the GNU General Public License in gnu.txt.
// See the included readme.txt for details.

#ifndef INIT_H
#define INIT_H

#include "root.h"

#include "mars.h"
#include "arraytypes.h"

class Identifier;
class Expression;
struct Scope;
class Type;
struct dt_t;
class AggregateDeclaration;
class ErrorInitializer;
class VoidInitializer;
class StructInitializer;
class ArrayInitializer;
class ExpInitializer;
struct HdrGenState;

enum NeedInterpret { INITnointerpret, INITinterpret };

class Initializer : public RootObject
{
public:
    Loc loc;

    Initializer(Loc loc);
    virtual Initializer *syntaxCopy();
    // needInterpret is INITinterpret if must be a manifest constant, 0 if not.
    virtual Initializer *semantic(Scope *sc, Type *t, NeedInterpret needInterpret);
    virtual Type *inferType(Scope *sc);
    virtual Expression *toExpression(Type *t = NULL) = 0;
    virtual void toCBuffer(OutBuffer *buf, HdrGenState *hgs) = 0;
    char *toChars();

    static Initializers *arraySyntaxCopy(Initializers *ai);

    virtual dt_t *toDt();

    virtual ErrorInitializer   *isErrorInitializer() { return NULL; }
    virtual VoidInitializer    *isVoidInitializer() { return NULL; }
    virtual StructInitializer  *isStructInitializer()  { return NULL; }
    virtual ArrayInitializer   *isArrayInitializer()  { return NULL; }
    virtual ExpInitializer     *isExpInitializer()  { return NULL; }
};

class VoidInitializer : public Initializer
{
public:
    Type *type;         // type that this will initialize to

    VoidInitializer(Loc loc);
    Initializer *syntaxCopy();
    Initializer *semantic(Scope *sc, Type *t, NeedInterpret needInterpret);
    Expression *toExpression(Type *t = NULL);
    void toCBuffer(OutBuffer *buf, HdrGenState *hgs);

    dt_t *toDt();

    virtual VoidInitializer *isVoidInitializer() { return this; }
};

class ErrorInitializer : public Initializer
{
public:
    ErrorInitializer();
    Initializer *syntaxCopy();
    Initializer *semantic(Scope *sc, Type *t, NeedInterpret needInterpret);
    Expression *toExpression(Type *t = NULL);
    void toCBuffer(OutBuffer *buf, HdrGenState *hgs);

    virtual ErrorInitializer *isErrorInitializer() { return this; }
};

class StructInitializer : public Initializer
{
public:
    Identifiers field;  // of Identifier *'s
    Initializers value; // parallel array of Initializer *'s

    StructInitializer(Loc loc);
    Initializer *syntaxCopy();
    void addInit(Identifier *field, Initializer *value);
    Initializer *semantic(Scope *sc, Type *t, NeedInterpret needInterpret);
    Expression *toExpression(Type *t = NULL);
    void toCBuffer(OutBuffer *buf, HdrGenState *hgs);

    dt_t *toDt();

    StructInitializer *isStructInitializer() { return this; }
};

class ArrayInitializer : public Initializer
{
public:
    Expressions index;  // indices
    Initializers value; // of Initializer *'s
    size_t dim;         // length of array being initialized
    Type *type;         // type that array will be used to initialize
    int sem;            // !=0 if semantic() is run

    ArrayInitializer(Loc loc);
    Initializer *syntaxCopy();
    void addInit(Expression *index, Initializer *value);
    Initializer *semantic(Scope *sc, Type *t, NeedInterpret needInterpret);
    int isAssociativeArray();
    Type *inferType(Scope *sc);
    Expression *toExpression(Type *t = NULL);
    Expression *toAssocArrayLiteral();
    void toCBuffer(OutBuffer *buf, HdrGenState *hgs);

    dt_t *toDt();

    ArrayInitializer *isArrayInitializer() { return this; }
};

class ExpInitializer : public Initializer
{
public:
    Expression *exp;
    int expandTuples;

    ExpInitializer(Loc loc, Expression *exp);
    Initializer *syntaxCopy();
    Initializer *semantic(Scope *sc, Type *t, NeedInterpret needInterpret);
    Type *inferType(Scope *sc);
    Expression *toExpression(Type *t = NULL);
    void toCBuffer(OutBuffer *buf, HdrGenState *hgs);

    dt_t *toDt();

    virtual ExpInitializer *isExpInitializer() { return this; }
};

#endif
