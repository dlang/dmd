
// Copyright (c) 1999-2012 by Digital Mars
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

#include "aav.h"

#include "expression.h"
#include "statement.h"
#include "mtype.h"
#include "declaration.h"
#include "scope.h"
#include "id.h"
#include "module.h"
#include "init.h"

extern int binary(const char *p , const char **tab, int high);
void buildArrayIdent(Expression *e, OutBuffer *buf, Expressions *arguments);
Expression *buildArrayLoop(Expression *e, Parameters *fparams);

/**************************************
 * Hash table of array op functions already generated or known about.
 */

AA *arrayfuncs;

/**************************************
 * Structure to contain information needed to insert an array op call
 */

struct ArrayOp
{
    FuncDeclaration *cFunc; // Stub for optimized druntime version
    FuncDeclaration *dFunc; // Full D version for ctfe
};

/**************************************
 * Search for a druntime array op
 */
int isDruntimeArrayOp(Identifier *ident)
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
    char *name = ident->toChars();
    int i = binary(name, libArrayopFuncs, sizeof(libArrayopFuncs) / sizeof(char *));
    if (i != -1)
        return 1;

#ifdef DEBUG    // Make sure our array is alphabetized
    for (i = 0; i < sizeof(libArrayopFuncs) / sizeof(char *); i++)
    {
        if (strcmp(name, libArrayopFuncs[i]) == 0)
            assert(0);
    }
#endif
    return 0;
}

ArrayOp *buildArrayOp(Identifier *ident, BinExp *exp, Scope *sc, Loc loc)
{
    Parameters *fparams = new Parameters();
    Expression *loopbody = buildArrayLoop(exp, fparams);

    ArrayOp *op = new ArrayOp;
    if (isDruntimeArrayOp(ident))
        op->cFunc = FuncDeclaration::genCfunc(fparams, exp->type, ident);
    else
        op->cFunc = NULL;

    /* Construct the function body:
     *  foreach (i; 0 .. p.length)    for (size_t i = 0; i < p.length; i++)
     *      loopbody;
     *  return p;
     */

    Parameter *p = (*fparams)[0];
    // foreach (i; 0 .. p.length)
    Statement *s1 = new ForeachRangeStatement(Loc(), TOKforeach,
        new Parameter(0, NULL, Id::p, NULL),
        new IntegerExp(Loc(), 0, Type::tsize_t),
        new ArrayLengthExp(Loc(), new IdentifierExp(Loc(), p->ident)),
        new ExpStatement(Loc(), loopbody));
    //printf("%s\n", s1->toChars());
    Statement *s2 = new ReturnStatement(Loc(), new IdentifierExp(Loc(), p->ident));
    //printf("s2: %s\n", s2->toChars());
    Statement *fbody = new CompoundStatement(Loc(), s1, s2);

    // Built-in array ops should be @trusted, pure and nothrow
    StorageClass stc = STCtrusted | STCpure | STCnothrow;

    /* Construct the function
     */
    TypeFunction *ftype = new TypeFunction(fparams, exp->type, 0, LINKc, stc);
    //printf("ftype: %s\n", ftype->toChars());
    FuncDeclaration *fd = new FuncDeclaration(Loc(), Loc(), ident, STCundefined, ftype);
    fd->fbody = fbody;
    fd->protection = PROTpublic;
    fd->linkage = LINKc;
    fd->isArrayOp = 1;

    if (!op->cFunc)
        sc->module->importedFrom->members->push(fd);

    sc = sc->push();
    sc->parent = sc->module->importedFrom;
    sc->stc = 0;
    sc->linkage = LINKc;
    fd->semantic(sc);
    fd->semantic2(sc);
    unsigned errors = global.startGagging();
    fd->semantic3(sc);
    if (global.endGagging(errors))
    {
        fd->type = Type::terror;
        fd->errors = true;
        fd->fbody = NULL;
    }
    sc->pop();

    if (op->cFunc)
    {
        op->cFunc->dArrayOp = fd;
        op->cFunc->type = fd->type;
    }
    op->dFunc = fd;
    return op;
}

/**********************************************
 * Check that there are no uses of arrays without [].
 */
bool isArrayOpValid(Expression *e)
{
    if (e->op == TOKslice)
        return true;
    if (e->op == TOKarrayliteral)
    {
        Type *t = e->type->toBasetype();
        while (t->ty == Tarray || t->ty == Tsarray)
            t = t->nextOf()->toBasetype();
        return (t->ty != Tvoid);
    }
    Type *tb = e->type->toBasetype();

    BinExp *be;
    if (tb->ty == Tarray || tb->ty == Tsarray)
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
            case TOKpow:
            case TOKpowass:
                be = (BinExp *)e;
                return isArrayOpValid(be->e1) && isArrayOpValid(be->e2);

            case TOKconstruct:
                be = (BinExp *)e;
                return be->e1->op == TOKslice && isArrayOpValid(be->e2);

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

Expression *arrayOp(BinExp *e, Scope *sc)
{
    //printf("BinExp::arrayOp() %s\n", toChars());

    Type *tb = e->type->toBasetype();
    assert(tb->ty == Tarray || tb->ty == Tsarray);
    Type *tbn = tb->nextOf()->toBasetype();
    if (tbn->ty == Tvoid)
    {
        e->error("Cannot perform array operations on void[] arrays");
        return new ErrorExp();
    }
    if (!isArrayOpValid(e))
    {
        e->error("invalid array operation %s (did you forget a [] ?)", e->toChars());
        return new ErrorExp();
    }

    Expressions *arguments = new Expressions();

    /* The expression to generate an array operation for is mangled
     * into a name to use as the array operation function name.
     * Mangle in the operands and operators in RPN order, and type.
     */
    OutBuffer buf;
    buf.writestring("_array");
    buildArrayIdent(e, &buf, arguments);
    buf.writeByte('_');

    /* Append deco of array element type
     */
    buf.writestring(e->type->toBasetype()->nextOf()->toBasetype()->mutableOf()->deco);

    char *name = buf.peekString();
    Identifier *ident = Lexer::idPool(name);

    ArrayOp **pOp = (ArrayOp **)_aaGet(&arrayfuncs, ident);
    ArrayOp *op = *pOp;

    if (!op)
        op = buildArrayOp(ident, e, sc, e->loc);

    if (op->dFunc && op->dFunc->errors)
    {
        const char *fmt;
        if (tbn->ty == Tstruct || tbn->ty == Tclass)
            fmt = "invalid array operation '%s' because %s doesn't support necessary arithmetic operations";
        else if (!tbn->isscalar())
            fmt = "invalid array operation '%s' because %s is not a scalar type";
        else
            fmt = "invalid array operation '%s' for element type %s";

        e->error(fmt, e->toChars(), tbn->toChars());
        return new ErrorExp();
    }

    *pOp = op;

    FuncDeclaration *fd = op->cFunc ? op->cFunc : op->dFunc;
    Expression *ev = new VarExp(e->loc, fd);
    Expression *ec = new CallExp(e->loc, ev, arguments);

    return ec->semantic(sc);
}

Expression *arrayOp(BinAssignExp *e, Scope *sc)
{
    //printf("BinAssignExp::arrayOp() %s\n", toChars());

    /* Check that the elements of e1 can be assigned to
     */
    Type *tn = e->e1->type->toBasetype()->nextOf();

    if (tn && (!tn->isMutable() || !tn->isAssignable()))
    {
        e->error("slice %s is not mutable", e->e1->toChars());
        return new ErrorExp();
    }
    if (e->e1->op == TOKarrayliteral)
    {
        return e->e1->modifiableLvalue(sc, e->e1);
    }

    return arrayOp((BinExp *)e, sc);
}

/******************************************
 * Construct the identifier for the array operation function,
 * and build the argument list to pass to it.
 */

void buildArrayIdent(Expression *e, OutBuffer *buf, Expressions *arguments)
{
    class BuildArrayIdentVisitor : public Visitor
    {
        OutBuffer *buf;
        Expressions *arguments;
    public:
        BuildArrayIdentVisitor(OutBuffer *buf, Expressions *arguments)
            : buf(buf), arguments(arguments)
        {
        }

        void visit(Expression *e)
        {
            buf->writestring("Exp");
            arguments->shift(e);
        }

        void visit(CastExp *e)
        {
            Type *tb = e->type->toBasetype();
            if (tb->ty == Tarray || tb->ty == Tsarray)
            {
                e->e1->accept(this);
            }
            else
                visit((Expression *)e);
        }

        void visit(ArrayLiteralExp *e)
        {
            buf->writestring("Slice");
            arguments->shift(e);
        }

        void visit(SliceExp *e)
        {
            buf->writestring("Slice");
            arguments->shift(e);
        }

        void visit(AssignExp *e)
        {
            /* Evaluate assign expressions right to left
             */
            e->e2->accept(this);
            e->e1->accept(this);
            buf->writestring("Assign");
        }

        void visit(BinAssignExp *e)
        {
            /* Evaluate assign expressions right to left
             */
            e->e2->accept(this);
            e->e1->accept(this);
            const char *s;
            switch(e->op)
            {
            case TOKaddass: s = "Addass"; break;
            case TOKminass: s = "Subass"; break;
            case TOKmulass: s = "Mulass"; break;
            case TOKdivass: s = "Divass"; break;
            case TOKmodass: s = "Modass"; break;
            case TOKxorass: s = "Xorass"; break;
            case TOKandass: s = "Andass"; break;
            case TOKorass:  s = "Orass";  break;
            case TOKpowass: s = "Powass"; break;
            default: assert(0);
            }
            buf->writestring(s);
        }

        void visit(NegExp *e)
        {
            e->e1->accept(this);
            buf->writestring("Neg");
        }

        void visit(ComExp *e)
        {
            e->e1->accept(this);
            buf->writestring("Com");
        }

        void visit(BinExp *e)
        {
            /* Evaluate assign expressions left to right
             */
            const char *s = NULL;
            switch(e->op)
            {
            case TOKadd: s = "Add"; break;
            case TOKmin: s = "Sub"; break;
            case TOKmul: s = "Mul"; break;
            case TOKdiv: s = "Div"; break;
            case TOKmod: s = "Mod"; break;
            case TOKxor: s = "Xor"; break;
            case TOKand: s = "And"; break;
            case TOKor:  s = "Or";  break;
            case TOKpow: s = "Pow"; break;
            default: break;
            }
            if (s)
            {
                e->e1->accept(this);
                e->e2->accept(this);
                buf->writestring(s);
            }
            else
                visit((Expression *)e);
        }
    };

    BuildArrayIdentVisitor v(buf, arguments);
    e->accept(&v);
}

/******************************************
 * Construct the inner loop for the array operation function,
 * and build the parameter list.
 */

Expression *buildArrayLoop(Expression *e, Parameters *fparams)
{
    class BuildArrayLoopVisitor : public Visitor
    {
        Parameters *fparams;
        Expression *result;

    public:
        BuildArrayLoopVisitor(Parameters *fparams)
            : fparams(fparams), result(NULL)
        {
        }

        void visit(Expression *e)
        {
            Identifier *id = Identifier::generateId("c", fparams->dim);
            Parameter *param = new Parameter(0, e->type, id, NULL);
            fparams->shift(param);
            result = new IdentifierExp(Loc(), id);
        }

        void visit(CastExp *e)
        {
            Type *tb = e->type->toBasetype();
            if (tb->ty == Tarray || tb->ty == Tsarray)
            {
                e->e1->accept(this);
            }
            else
                visit((Expression *)e);
        }

        void visit(ArrayLiteralExp *e)
        {
            Identifier *id = Identifier::generateId("p", fparams->dim);
            Parameter *param = new Parameter(STCconst, e->type, id, NULL);
            fparams->shift(param);
            Expression *ie = new IdentifierExp(Loc(), id);
            Expressions *arguments = new Expressions();
            Expression *index = new IdentifierExp(Loc(), Id::p);
            arguments->push(index);
            result = new ArrayExp(Loc(), ie, arguments);
        }

        void visit(SliceExp *e)
        {
            Identifier *id = Identifier::generateId("p", fparams->dim);
            Parameter *param = new Parameter(STCconst, e->type, id, NULL);
            fparams->shift(param);
            Expression *ie = new IdentifierExp(Loc(), id);
            Expressions *arguments = new Expressions();
            Expression *index = new IdentifierExp(Loc(), Id::p);
            arguments->push(index);
            result = new ArrayExp(Loc(), ie, arguments);
        }

        void visit(AssignExp *e)
        {
            /* Evaluate assign expressions right to left
             */
            Expression *ex2 = buildArrayLoop(e->e2);
            /* Need the cast because:
             *   b = c + p[i];
             * where b is a byte fails because (c + p[i]) is an int
             * which cannot be implicitly cast to byte.
             */
            ex2 = new CastExp(Loc(), ex2, e->e1->type->nextOf());
            Expression *ex1 = buildArrayLoop(e->e1);
            Parameter *param = (*fparams)[0];
            param->storageClass = 0;
            result = new AssignExp(Loc(), ex1, ex2);
        }

        void visit(BinAssignExp *e)
        {
            /* Evaluate assign expressions right to left
             */
            Expression *ex2 = buildArrayLoop(e->e2);
            Expression *ex1 = buildArrayLoop(e->e1);
            Parameter *param = (*fparams)[0];
            param->storageClass = 0;
            switch(e->op)
            {
            case TOKaddass: result = new AddAssignExp(e->loc, ex1, ex2); return;
            case TOKminass: result = new MinAssignExp(e->loc, ex1, ex2); return;
            case TOKmulass: result = new MulAssignExp(e->loc, ex1, ex2); return;
            case TOKdivass: result = new DivAssignExp(e->loc, ex1, ex2); return;
            case TOKmodass: result = new ModAssignExp(e->loc, ex1, ex2); return;
            case TOKxorass: result = new XorAssignExp(e->loc, ex1, ex2); return;
            case TOKandass: result = new AndAssignExp(e->loc, ex1, ex2); return;
            case TOKorass:  result = new OrAssignExp(e->loc, ex1, ex2); return;
            case TOKpowass: result = new PowAssignExp(e->loc, ex1, ex2); return;
            default:
                assert(0);
            }
        }

        void visit(NegExp *e)
        {
            Expression *ex1 = buildArrayLoop(e->e1);
            result = new NegExp(Loc(), ex1);
        }

        void visit(ComExp *e)
        {
            Expression *ex1 = buildArrayLoop(e->e1);
            result = new ComExp(Loc(), ex1);
        }

        void visit(BinExp *e)
        {
            switch(e->op)
            {
            case TOKadd:
            case TOKmin:
            case TOKmul:
            case TOKdiv:
            case TOKmod:
            case TOKxor:
            case TOKand:
            case TOKor:
            case TOKpow:
            {
                /* Evaluate assign expressions left to right
                 */
                BinExp *be = (BinExp *)e->copy();
                be->e1 = buildArrayLoop(be->e1);
                be->e2 = buildArrayLoop(be->e2);
                be->type = NULL;
                result = be;
                return;
            }
            default:
                visit((Expression *)e);
                return;
            }
        }

        Expression *buildArrayLoop(Expression *e)
        {
            e->accept(this);
            return result;
        }
    };

    BuildArrayLoopVisitor v(fparams);
    return v.buildArrayLoop(e);
}

/***********************************************
 * Test if operand is a valid array op operand.
 */

bool isArrayOperand(Expression *e)
{
    //printf("Expression::isArrayOperand() %s\n", e->toChars());
    if (e->op == TOKslice)
        return true;
    if (e->op == TOKarrayliteral)
    {
        Type *t = e->type->toBasetype();
        while (t->ty == Tarray || t->ty == Tsarray)
            t = t->nextOf()->toBasetype();
        return (t->ty != Tvoid);
    }
    if (e->type->toBasetype()->ty == Tarray)
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
        case TOKpow:
        case TOKpowass:
        case TOKneg:
        case TOKtilde:
            return true;

        default:
            break;
        }
    }
    return false;
}
