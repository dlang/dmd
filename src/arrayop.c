
// Copyright (c) 1999-2010 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// http://www.digitalmars.com
// License for redistribution is by either the Artistic License
// in artistic.txt, or the GNU General Public License in gnu.txt.
// See the included readme.txt for details.

#include <stdio.h>
#include <string.h>
#include <assert.h>

#include "rmem.h"

#include "stringtable.h"

#include "expression.h"
#include "statement.h"
#include "mtype.h"
#include "declaration.h"
#include "scope.h"
#include "id.h"
#include "module.h"
#include "init.h"

extern int binary(const char *p , const char **tab, int high);

/**************************************
 * Hash table of array op functions already generated or known about.
 */

StringTable arrayfuncs;

/**********************************************
 * Check that there are no uses of arrays without [].
 */
bool isArrayOpValid(Expression *e)
{
    if (e->op == TOKslice)
        return true;
    Type *tb = e->type->toBasetype();

    if ( (tb->ty == Tarray) || (tb->ty == Tsarray) )
    {
        switch (e->op)
        {
            case TOKadd:
            case TOKmin:
            case TOKmul:
            case TOKdiv:
            case TOKmod:
            case TOKxor:
            case TOKand:
            case TOKor:
            case TOKassign:
            case TOKaddass:
            case TOKminass:
            case TOKmulass:
            case TOKdivass:
            case TOKmodass:
            case TOKxorass:
            case TOKandass:
            case TOKorass:
#if DMDV2
            case TOKpow:
            case TOKpowass:
#endif
                 return isArrayOpValid(((BinExp *)e)->e1) && isArrayOpValid(((BinExp *)e)->e2);

            case TOKcall:
                 return false; // TODO: Decide if [] is required after arrayop calls.

            case TOKneg:
            case TOKtilde:
                 return isArrayOpValid(((UnaExp *)e)->e1);

            default:
                return false;
        }
    }
    return true;
}

/***********************************
 * Construct the array operation expression.
 */

Expression *BinExp::arrayOp(Scope *sc)
{
    //printf("BinExp::arrayOp() %s\n", toChars());

    Type *tb = type->toBasetype();
    assert(tb->ty == Tarray || tb->ty == Tsarray);
    if (tb->nextOf()->toBasetype()->ty == Tvoid)
    {
        error("Cannot perform array operations on void[] arrays");
        return new ErrorExp();
    }

    if (!isArrayOpValid(e2))
    {
        e2->error("invalid array operation %s (did you forget a [] ?)", toChars());
        return new ErrorExp();
    }

    Expressions *arguments = new Expressions();

    /* The expression to generate an array operation for is mangled
     * into a name to use as the array operation function name.
     * Mangle in the operands and operators in RPN order, and type.
     */
    OutBuffer buf;
    buf.writestring("_array");
    buildArrayIdent(&buf, arguments);
    buf.writeByte('_');

    /* Append deco of array element type
     */
#if DMDV2
    buf.writestring(type->toBasetype()->nextOf()->toBasetype()->mutableOf()->deco);
#else
    buf.writestring(type->toBasetype()->nextOf()->toBasetype()->deco);
#endif

    size_t namelen = buf.offset;
    buf.writeByte(0);
    char *name = (char *)buf.extractData();

    /* Look up name in hash table
     */
    StringValue *sv = arrayfuncs.update(name, namelen);
    FuncDeclaration *fd = (FuncDeclaration *)sv->ptrvalue;
    if (!fd)
    {
        /* Some of the array op functions are written as library functions,
         * presumably to optimize them with special CPU vector instructions.
         * List those library functions here, in alpha order.
         */
        static const char *libArrayopFuncs[] =
        {
            "_arrayExpSliceAddass_a",
            "_arrayExpSliceAddass_d",           // T[]+=T
            "_arrayExpSliceAddass_f",           // T[]+=T
            "_arrayExpSliceAddass_g",
            "_arrayExpSliceAddass_h",
            "_arrayExpSliceAddass_i",
            "_arrayExpSliceAddass_k",
            "_arrayExpSliceAddass_s",
            "_arrayExpSliceAddass_t",
            "_arrayExpSliceAddass_u",
            "_arrayExpSliceAddass_w",

            "_arrayExpSliceDivass_d",           // T[]/=T
            "_arrayExpSliceDivass_f",           // T[]/=T

            "_arrayExpSliceMinSliceAssign_a",
            "_arrayExpSliceMinSliceAssign_d",   // T[]=T-T[]
            "_arrayExpSliceMinSliceAssign_f",   // T[]=T-T[]
            "_arrayExpSliceMinSliceAssign_g",
            "_arrayExpSliceMinSliceAssign_h",
            "_arrayExpSliceMinSliceAssign_i",
            "_arrayExpSliceMinSliceAssign_k",
            "_arrayExpSliceMinSliceAssign_s",
            "_arrayExpSliceMinSliceAssign_t",
            "_arrayExpSliceMinSliceAssign_u",
            "_arrayExpSliceMinSliceAssign_w",

            "_arrayExpSliceMinass_a",
            "_arrayExpSliceMinass_d",           // T[]-=T
            "_arrayExpSliceMinass_f",           // T[]-=T
            "_arrayExpSliceMinass_g",
            "_arrayExpSliceMinass_h",
            "_arrayExpSliceMinass_i",
            "_arrayExpSliceMinass_k",
            "_arrayExpSliceMinass_s",
            "_arrayExpSliceMinass_t",
            "_arrayExpSliceMinass_u",
            "_arrayExpSliceMinass_w",

            "_arrayExpSliceMulass_d",           // T[]*=T
            "_arrayExpSliceMulass_f",           // T[]*=T
            "_arrayExpSliceMulass_i",
            "_arrayExpSliceMulass_k",
            "_arrayExpSliceMulass_s",
            "_arrayExpSliceMulass_t",
            "_arrayExpSliceMulass_u",
            "_arrayExpSliceMulass_w",

            "_arraySliceExpAddSliceAssign_a",
            "_arraySliceExpAddSliceAssign_d",   // T[]=T[]+T
            "_arraySliceExpAddSliceAssign_f",   // T[]=T[]+T
            "_arraySliceExpAddSliceAssign_g",
            "_arraySliceExpAddSliceAssign_h",
            "_arraySliceExpAddSliceAssign_i",
            "_arraySliceExpAddSliceAssign_k",
            "_arraySliceExpAddSliceAssign_s",
            "_arraySliceExpAddSliceAssign_t",
            "_arraySliceExpAddSliceAssign_u",
            "_arraySliceExpAddSliceAssign_w",

            "_arraySliceExpDivSliceAssign_d",   // T[]=T[]/T
            "_arraySliceExpDivSliceAssign_f",   // T[]=T[]/T

            "_arraySliceExpMinSliceAssign_a",
            "_arraySliceExpMinSliceAssign_d",   // T[]=T[]-T
            "_arraySliceExpMinSliceAssign_f",   // T[]=T[]-T
            "_arraySliceExpMinSliceAssign_g",
            "_arraySliceExpMinSliceAssign_h",
            "_arraySliceExpMinSliceAssign_i",
            "_arraySliceExpMinSliceAssign_k",
            "_arraySliceExpMinSliceAssign_s",
            "_arraySliceExpMinSliceAssign_t",
            "_arraySliceExpMinSliceAssign_u",
            "_arraySliceExpMinSliceAssign_w",

            "_arraySliceExpMulSliceAddass_d",   // T[] += T[]*T
            "_arraySliceExpMulSliceAddass_f",
            "_arraySliceExpMulSliceAddass_r",

            "_arraySliceExpMulSliceAssign_d",   // T[]=T[]*T
            "_arraySliceExpMulSliceAssign_f",   // T[]=T[]*T
            "_arraySliceExpMulSliceAssign_i",
            "_arraySliceExpMulSliceAssign_k",
            "_arraySliceExpMulSliceAssign_s",
            "_arraySliceExpMulSliceAssign_t",
            "_arraySliceExpMulSliceAssign_u",
            "_arraySliceExpMulSliceAssign_w",

            "_arraySliceExpMulSliceMinass_d",   // T[] -= T[]*T
            "_arraySliceExpMulSliceMinass_f",
            "_arraySliceExpMulSliceMinass_r",

            "_arraySliceSliceAddSliceAssign_a",
            "_arraySliceSliceAddSliceAssign_d", // T[]=T[]+T[]
            "_arraySliceSliceAddSliceAssign_f", // T[]=T[]+T[]
            "_arraySliceSliceAddSliceAssign_g",
            "_arraySliceSliceAddSliceAssign_h",
            "_arraySliceSliceAddSliceAssign_i",
            "_arraySliceSliceAddSliceAssign_k",
            "_arraySliceSliceAddSliceAssign_r", // T[]=T[]+T[]
            "_arraySliceSliceAddSliceAssign_s",
            "_arraySliceSliceAddSliceAssign_t",
            "_arraySliceSliceAddSliceAssign_u",
            "_arraySliceSliceAddSliceAssign_w",

            "_arraySliceSliceAddass_a",
            "_arraySliceSliceAddass_d",         // T[]+=T[]
            "_arraySliceSliceAddass_f",         // T[]+=T[]
            "_arraySliceSliceAddass_g",
            "_arraySliceSliceAddass_h",
            "_arraySliceSliceAddass_i",
            "_arraySliceSliceAddass_k",
            "_arraySliceSliceAddass_s",
            "_arraySliceSliceAddass_t",
            "_arraySliceSliceAddass_u",
            "_arraySliceSliceAddass_w",

            "_arraySliceSliceMinSliceAssign_a",
            "_arraySliceSliceMinSliceAssign_d", // T[]=T[]-T[]
            "_arraySliceSliceMinSliceAssign_f", // T[]=T[]-T[]
            "_arraySliceSliceMinSliceAssign_g",
            "_arraySliceSliceMinSliceAssign_h",
            "_arraySliceSliceMinSliceAssign_i",
            "_arraySliceSliceMinSliceAssign_k",
            "_arraySliceSliceMinSliceAssign_r", // T[]=T[]-T[]
            "_arraySliceSliceMinSliceAssign_s",
            "_arraySliceSliceMinSliceAssign_t",
            "_arraySliceSliceMinSliceAssign_u",
            "_arraySliceSliceMinSliceAssign_w",

            "_arraySliceSliceMinass_a",
            "_arraySliceSliceMinass_d",         // T[]-=T[]
            "_arraySliceSliceMinass_f",         // T[]-=T[]
            "_arraySliceSliceMinass_g",
            "_arraySliceSliceMinass_h",
            "_arraySliceSliceMinass_i",
            "_arraySliceSliceMinass_k",
            "_arraySliceSliceMinass_s",
            "_arraySliceSliceMinass_t",
            "_arraySliceSliceMinass_u",
            "_arraySliceSliceMinass_w",

            "_arraySliceSliceMulSliceAssign_d", // T[]=T[]*T[]
            "_arraySliceSliceMulSliceAssign_f", // T[]=T[]*T[]
            "_arraySliceSliceMulSliceAssign_i",
            "_arraySliceSliceMulSliceAssign_k",
            "_arraySliceSliceMulSliceAssign_s",
            "_arraySliceSliceMulSliceAssign_t",
            "_arraySliceSliceMulSliceAssign_u",
            "_arraySliceSliceMulSliceAssign_w",

            "_arraySliceSliceMulass_d",         // T[]*=T[]
            "_arraySliceSliceMulass_f",         // T[]*=T[]
            "_arraySliceSliceMulass_i",
            "_arraySliceSliceMulass_k",
            "_arraySliceSliceMulass_s",
            "_arraySliceSliceMulass_t",
            "_arraySliceSliceMulass_u",
            "_arraySliceSliceMulass_w",
        };

        int i = binary(name, libArrayopFuncs, sizeof(libArrayopFuncs) / sizeof(char *));
        if (i == -1)
        {
#ifdef DEBUG    // Make sure our array is alphabetized
            for (i = 0; i < sizeof(libArrayopFuncs) / sizeof(char *); i++)
            {
                if (strcmp(name, libArrayopFuncs[i]) == 0)
                    assert(0);
            }
#endif
            /* Not in library, so generate it.
             * Construct the function body:
             *  foreach (i; 0 .. p.length)    for (size_t i = 0; i < p.length; i++)
             *      loopbody;
             *  return p;
             */

            Parameters *fparams = new Parameters();
            Expression *loopbody = buildArrayLoop(fparams);
            Parameter *p = fparams->tdata()[0 /*fparams->dim - 1*/];
#if DMDV1
            // for (size_t i = 0; i < p.length; i++)
            Initializer *init = new ExpInitializer(0, new IntegerExp(0, 0, Type::tsize_t));
            Dsymbol *d = new VarDeclaration(0, Type::tsize_t, Id::p, init);
            Statement *s1 = new ForStatement(0,
                new DeclarationStatement(0, d),
                new CmpExp(TOKlt, 0, new IdentifierExp(0, Id::p), new ArrayLengthExp(0, new IdentifierExp(0, p->ident))),
                new PostExp(TOKplusplus, 0, new IdentifierExp(0, Id::p)),
                new ExpStatement(0, loopbody));
#else
            // foreach (i; 0 .. p.length)
            Statement *s1 = new ForeachRangeStatement(0, TOKforeach,
                new Parameter(0, NULL, Id::p, NULL),
                new IntegerExp(0, 0, Type::tint32),
                new ArrayLengthExp(0, new IdentifierExp(0, p->ident)),
                new ExpStatement(0, loopbody));
#endif
            Statement *s2 = new ReturnStatement(0, new IdentifierExp(0, p->ident));
            //printf("s2: %s\n", s2->toChars());
            Statement *fbody = new CompoundStatement(0, s1, s2);

            /* Construct the function
             */
            TypeFunction *ftype = new TypeFunction(fparams, type, 0, LINKc);
            //printf("ftype: %s\n", ftype->toChars());
            fd = new FuncDeclaration(loc, 0, Lexer::idPool(name), STCundefined, ftype);
            fd->fbody = fbody;
            fd->protection = PROTpublic;
            fd->linkage = LINKc;
            fd->isArrayOp = 1;

            sc->module->importedFrom->members->push(fd);

            sc = sc->push();
            sc->parent = sc->module->importedFrom;
            sc->stc = 0;
            sc->linkage = LINKc;
            fd->semantic(sc);
            fd->semantic2(sc);
            fd->semantic3(sc);
            sc->pop();
        }
        else
        {   /* In library, refer to it.
             */
            fd = FuncDeclaration::genCfunc(type, name);
        }
        sv->ptrvalue = fd;      // cache symbol in hash table
    }

    /* Call the function fd(arguments)
     */
    Expression *ec = new VarExp(0, fd);
    Expression *e = new CallExp(loc, ec, arguments);
    e->type = type;
    return e;
}

/******************************************
 * Construct the identifier for the array operation function,
 * and build the argument list to pass to it.
 */

void Expression::buildArrayIdent(OutBuffer *buf, Expressions *arguments)
{
    buf->writestring("Exp");
    arguments->shift(this);
}

void CastExp::buildArrayIdent(OutBuffer *buf, Expressions *arguments)
{
    Type *tb = type->toBasetype();
    if (tb->ty == Tarray || tb->ty == Tsarray)
    {
        e1->buildArrayIdent(buf, arguments);
    }
    else
        Expression::buildArrayIdent(buf, arguments);
}

void SliceExp::buildArrayIdent(OutBuffer *buf, Expressions *arguments)
{
    buf->writestring("Slice");
    arguments->shift(this);
}

void AssignExp::buildArrayIdent(OutBuffer *buf, Expressions *arguments)
{
    /* Evaluate assign expressions right to left
     */
    e2->buildArrayIdent(buf, arguments);
    e1->buildArrayIdent(buf, arguments);
    buf->writestring("Assign");
}

#define X(Str) \
void Str##AssignExp::buildArrayIdent(OutBuffer *buf, Expressions *arguments) \
{                                                       \
    /* Evaluate assign expressions right to left        \
     */                                                 \
    e2->buildArrayIdent(buf, arguments);                \
    e1->buildArrayIdent(buf, arguments);                \
    buf->writestring(#Str);                             \
    buf->writestring("ass");                            \
}

X(Add)
X(Min)
X(Mul)
X(Div)
X(Mod)
X(Xor)
X(And)
X(Or)
#if DMDV2
X(Pow)
#endif

#undef X

void NegExp::buildArrayIdent(OutBuffer *buf, Expressions *arguments)
{
    e1->buildArrayIdent(buf, arguments);
    buf->writestring("Neg");
}

void ComExp::buildArrayIdent(OutBuffer *buf, Expressions *arguments)
{
    e1->buildArrayIdent(buf, arguments);
    buf->writestring("Com");
}

#define X(Str) \
void Str##Exp::buildArrayIdent(OutBuffer *buf, Expressions *arguments)  \
{                                                                       \
    /* Evaluate assign expressions left to right                        \
     */                                                                 \
    e1->buildArrayIdent(buf, arguments);                                \
    e2->buildArrayIdent(buf, arguments);                                \
    buf->writestring(#Str);                                             \
}

X(Add)
X(Min)
X(Mul)
X(Div)
X(Mod)
X(Xor)
X(And)
X(Or)
#if DMDV2
X(Pow)
#endif

#undef X

/******************************************
 * Construct the inner loop for the array operation function,
 * and build the parameter list.
 */

Expression *Expression::buildArrayLoop(Parameters *fparams)
{
    Identifier *id = Identifier::generateId("c", fparams->dim);
    Parameter *param = new Parameter(0, type, id, NULL);
    fparams->shift(param);
    Expression *e = new IdentifierExp(0, id);
    return e;
}

Expression *CastExp::buildArrayLoop(Parameters *fparams)
{
    Type *tb = type->toBasetype();
    if (tb->ty == Tarray || tb->ty == Tsarray)
    {
        return e1->buildArrayLoop(fparams);
    }
    else
        return Expression::buildArrayLoop(fparams);
}

Expression *SliceExp::buildArrayLoop(Parameters *fparams)
{
    Identifier *id = Identifier::generateId("p", fparams->dim);
    Parameter *param = new Parameter(STCconst, type, id, NULL);
    fparams->shift(param);
    Expression *e = new IdentifierExp(0, id);
    Expressions *arguments = new Expressions();
    Expression *index = new IdentifierExp(0, Id::p);
    arguments->push(index);
    e = new ArrayExp(0, e, arguments);
    return e;
}

Expression *AssignExp::buildArrayLoop(Parameters *fparams)
{
    /* Evaluate assign expressions right to left
     */
    Expression *ex2 = e2->buildArrayLoop(fparams);
#if DMDV2
    /* Need the cast because:
     *   b = c + p[i];
     * where b is a byte fails because (c + p[i]) is an int
     * which cannot be implicitly cast to byte.
     */
    ex2 = new CastExp(0, ex2, e1->type->nextOf());
#endif
    Expression *ex1 = e1->buildArrayLoop(fparams);
    Parameter *param = fparams->tdata()[0];
    param->storageClass = 0;
    Expression *e = new AssignExp(0, ex1, ex2);
    return e;
}

#define X(Str) \
Expression *Str##AssignExp::buildArrayLoop(Parameters *fparams) \
{                                                               \
    /* Evaluate assign expressions right to left                \
     */                                                         \
    Expression *ex2 = e2->buildArrayLoop(fparams);              \
    Expression *ex1 = e1->buildArrayLoop(fparams);              \
    Parameter *param = fparams->tdata()[0];           \
    param->storageClass = 0;                                    \
    Expression *e = new Str##AssignExp(0, ex1, ex2);            \
    return e;                                                   \
}

X(Add)
X(Min)
X(Mul)
X(Div)
X(Mod)
X(Xor)
X(And)
X(Or)
#if DMDV2
X(Pow)
#endif

#undef X

Expression *NegExp::buildArrayLoop(Parameters *fparams)
{
    Expression *ex1 = e1->buildArrayLoop(fparams);
    Expression *e = new NegExp(0, ex1);
    return e;
}

Expression *ComExp::buildArrayLoop(Parameters *fparams)
{
    Expression *ex1 = e1->buildArrayLoop(fparams);
    Expression *e = new ComExp(0, ex1);
    return e;
}

#define X(Str) \
Expression *Str##Exp::buildArrayLoop(Parameters *fparams)       \
{                                                               \
    /* Evaluate assign expressions left to right                \
     */                                                         \
    Expression *ex1 = e1->buildArrayLoop(fparams);              \
    Expression *ex2 = e2->buildArrayLoop(fparams);              \
    Expression *e = new Str##Exp(0, ex1, ex2);                  \
    return e;                                                   \
}

X(Add)
X(Min)
X(Mul)
X(Div)
X(Mod)
X(Xor)
X(And)
X(Or)
#if DMDV2
X(Pow)
#endif

#undef X


/***********************************************
 * Test if operand is a valid array op operand.
 */

int Expression::isArrayOperand()
{
    //printf("Expression::isArrayOperand() %s\n", toChars());
    if (op == TOKslice)
        return 1;
    if (type->toBasetype()->ty == Tarray)
    {
        switch (op)
        {
            case TOKadd:
            case TOKmin:
            case TOKmul:
            case TOKdiv:
            case TOKmod:
            case TOKxor:
            case TOKand:
            case TOKor:
            case TOKassign:
            case TOKaddass:
            case TOKminass:
            case TOKmulass:
            case TOKdivass:
            case TOKmodass:
            case TOKxorass:
            case TOKandass:
            case TOKorass:
#if DMDV2
            case TOKpow:
            case TOKpowass:
#endif
            case TOKneg:
            case TOKtilde:
                return 1;

            default:
                break;
        }
    }
    return 0;
}
