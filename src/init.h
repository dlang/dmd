
/* Compiler implementation of the D programming language
 * Copyright (c) 1999-2014 by Digital Mars
 * All Rights Reserved
 * written by Walter Bright
 * http://www.digitalmars.com
 * Distributed under the Boost Software License, Version 1.0.
 * http://www.boost.org/LICENSE_1_0.txt
 * https://github.com/D-Programming-Language/dmd/blob/master/src/init.h
 */

#ifndef INIT_H
#define INIT_H

#include "root.h"

#include "mars.h"
#include "arraytypes.h"
#include "visitor.h"

class Identifier;
class Expression;
struct Scope;
class Type;
class AggregateDeclaration;
class ErrorInitializer;
class VoidInitializer;
class StructInitializer;
class ArrayInitializer;
class ExpInitializer;

enum NeedInterpret { INITnointerpret, INITinterpret };

class Initializer : public RootObject
{
public:
    Loc loc;

    Initializer(Loc loc);
    virtual Initializer *syntaxCopy() = 0;
    static Initializers *arraySyntaxCopy(Initializers *ai);

    /* Translates to an expression to infer type.
     * Returns ExpInitializer or ErrorInitializer.
     */
    virtual Initializer *inferType(Scope *sc) = 0;

    // needInterpret is INITinterpret if must be a manifest constant, 0 if not.
    virtual Initializer *semantic(Scope *sc, Type *t, NeedInterpret needInterpret) = 0;
    virtual Expression *toExpression(Type *t = NULL) = 0;
    char *toChars();

    virtual ErrorInitializer   *isErrorInitializer() { return NULL; }
    virtual VoidInitializer    *isVoidInitializer() { return NULL; }
    virtual StructInitializer  *isStructInitializer()  { return NULL; }
    virtual ArrayInitializer   *isArrayInitializer()  { return NULL; }
    virtual ExpInitializer     *isExpInitializer()  { return NULL; }
    virtual void accept(Visitor *v) { v->visit(this); }
};

class VoidInitializer : public Initializer
{
public:
    Type *type;         // type that this will initialize to

    VoidInitializer(Loc loc);
    Initializer *syntaxCopy();
    Initializer *inferType(Scope *sc);
    Initializer *semantic(Scope *sc, Type *t, NeedInterpret needInterpret);
    Expression *toExpression(Type *t = NULL);

    virtual VoidInitializer *isVoidInitializer() { return this; }
    void accept(Visitor *v) { v->visit(this); }
};

class ErrorInitializer : public Initializer
{
public:
    ErrorInitializer();
    Initializer *syntaxCopy();
    Initializer *inferType(Scope *sc);
    Initializer *semantic(Scope *sc, Type *t, NeedInterpret needInterpret);
    Expression *toExpression(Type *t = NULL);

    virtual ErrorInitializer *isErrorInitializer() { return this; }
    void accept(Visitor *v) { v->visit(this); }
};

class StructInitializer : public Initializer
{
public:
    Identifiers field;  // of Identifier *'s
    Initializers value; // parallel array of Initializer *'s

    StructInitializer(Loc loc);
    Initializer *syntaxCopy();
    void addInit(Identifier *field, Initializer *value);
    Initializer *inferType(Scope *sc);
    Initializer *semantic(Scope *sc, Type *t, NeedInterpret needInterpret);
    Expression *toExpression(Type *t = NULL);

    StructInitializer *isStructInitializer() { return this; }
    void accept(Visitor *v) { v->visit(this); }
};

class ArrayInitializer : public Initializer
{
public:
    Expressions index;  // indices
    Initializers value; // of Initializer *'s
    size_t dim;         // length of array being initialized
    Type *type;         // type that array will be used to initialize
    bool sem;           // true if semantic() is run

    ArrayInitializer(Loc loc);
    Initializer *syntaxCopy();
    void addInit(Expression *index, Initializer *value);
    bool isAssociativeArray();
    Initializer *inferType(Scope *sc);
    Initializer *semantic(Scope *sc, Type *t, NeedInterpret needInterpret);
    Expression *toExpression(Type *t = NULL);
    Expression *toAssocArrayLiteral();

    ArrayInitializer *isArrayInitializer() { return this; }
    void accept(Visitor *v) { v->visit(this); }
};

class ExpInitializer : public Initializer
{
public:
    Expression *exp;
    bool expandTuples;

    ExpInitializer(Loc loc, Expression *exp);
    Initializer *syntaxCopy();
    Initializer *inferType(Scope *sc);
    Initializer *semantic(Scope *sc, Type *t, NeedInterpret needInterpret);
    Expression *toExpression(Type *t = NULL);

    virtual ExpInitializer *isExpInitializer() { return this; }
    void accept(Visitor *v) { v->visit(this); }
};

#endif
