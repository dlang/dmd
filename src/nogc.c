
/* Compiler implementation of the D programming language
 * Copyright (c) 1999-2014 by Digital Mars
 * All Rights Reserved
 * written by Walter Bright
 * http://www.digitalmars.com
 * Distributed under the Boost Software License, Version 1.0.
 * http://www.boost.org/LICENSE_1_0.txt
 * https://github.com/D-Programming-Language/dmd/blob/master/src/nogc.c
 */

#include "mars.h"
#include "init.h"
#include "visitor.h"
#include "expression.h"
#include "statement.h"
#include "declaration.h"
#include "id.h"
#include "module.h"
#include "scope.h"
#include "tokens.h"

bool walkPostorder(Expression *e, StoppableVisitor *v);

void FuncDeclaration::printGCUsage(Loc loc, const char* warn)
{
    if (!global.params.vgc)
        return;

    Module *m = getModule();
    if (m && m->isRoot() && !inUnittest())
    {
        fprintf(global.stdmsg, "%s: vgc: %s\n", loc.toChars(), warn);
    }
}

/**************************************
 * Look for GC-allocations
 */
class NOGCVisitor : public StoppableVisitor
{
public:
    FuncDeclaration *f;
    bool err;

    NOGCVisitor(FuncDeclaration *f)
    {
        this->f = f;
        this->err = false;
    }

    void doCond(Expression *exp)
    {
        if (exp)
            walkPostorder(exp, this);
    }

    void visit(Expression *e)
    {
    }

    void visit(DeclarationExp *e)
    {
        // Note that, walkPostorder does not support DeclarationExp today.
        VarDeclaration *v = e->declaration->isVarDeclaration();
        if (v && !(v->storage_class & STCmanifest) && !v->isDataseg() && v->init)
        {
            if (v->init->isVoidInitializer())
            {
            }
            else
            {
                ExpInitializer *ei = v->init->isExpInitializer();
                assert(ei);
                doCond(ei->exp);
            }
        }
    }

    void visit(CallExp *e)
    {
    }

    void visit(ArrayLiteralExp *e)
    {
        if (e->type->ty != Tarray || !e->elements || !e->elements->dim)
            return;

        if (f->setGC())
        {
            e->error("array literal in @nogc function %s may cause GC allocation",
                f->toChars());
            err = true;
            return;
        }
        f->printGCUsage(e->loc, "array literal may cause GC allocation");
    }

    void visit(AssocArrayLiteralExp *e)
    {
        if (!e->keys->dim)
            return;

        if (f->setGC())
        {
            e->error("associative array literal in @nogc function %s may cause GC allocation", f->toChars());
            err = true;
            return;
        }
        f->printGCUsage(e->loc, "associative array literal may cause GC allocation");
    }

    void visit(NewExp *e)
    {
        if (e->member && !e->member->isNogc() && f->setGC())
        {
            // @nogc-ness is already checked in NewExp::semantic
            return;
        }
        if (e->onstack)
            return;
        if (e->allocator)
            return;

        if (f->setGC())
        {
            e->error("cannot use 'new' in @nogc function %s", f->toChars());
            err = true;
            return;
        }
        f->printGCUsage(e->loc, "'new' causes GC allocation");
    }

    void visit(DeleteExp *e)
    {
        if (e->e1->op == TOKvar)
        {
            VarDeclaration *v =  ((VarExp *)e->e1)->var->isVarDeclaration();
            if (v && v->onstack)
                return;     // delete for scope allocated class object
        }

        if (f->setGC())
        {
            e->error("cannot use 'delete' in @nogc function %s", f->toChars());
            err = true;
            return;
        }
        f->printGCUsage(e->loc, "'delete' requires GC");
    }

    void visit(IndexExp* e)
    {
        Type *t1b = e->e1->type->toBasetype();
        if (t1b->ty == Taarray)
        {
            if (f->setGC())
            {
                e->error("indexing an associative array in @nogc function %s may cause GC allocation", f->toChars());
                err = true;
                return;
            }
            f->printGCUsage(e->loc, "indexing an associative array may cause GC allocation");
        }
    }

    void visit(AssignExp *e)
    {
        if (e->e1->op == TOKarraylength)
        {
            if (f->setGC())
            {
                e->error("setting 'length' in @nogc function %s may cause GC allocation", f->toChars());
                err = true;
                return;
            }
            f->printGCUsage(e->loc, "setting 'length' may cause GC allocation");
        }
    }

    void visit(CatAssignExp *e)
    {
        if (f->setGC())
        {
            e->error("cannot use operator ~= in @nogc function %s", f->toChars());
            err = true;
            return;
        }
        f->printGCUsage(e->loc, "operator ~= may cause GC allocation");
    }

    void visit(CatExp *e)
    {
        if (f->setGC())
        {
            e->error("cannot use operator ~ in @nogc function %s", f->toChars());
            err = true;
            return;
        }
        f->printGCUsage(e->loc, "operator ~ may cause GC allocation");
    }
};

Expression *checkGC(Scope *sc, Expression *e)
{
    FuncDeclaration *f = sc->func;
    if (e && e->op != TOKerror &&
        f && sc->intypeof != 1 && !(sc->flags & SCOPEctfe) &&
        (f->type->ty == Tfunction && ((TypeFunction *)f->type)->isnogc ||
         (f->flags & FUNCFLAGnogcInprocess) ||
         global.params.vgc))
    {
        NOGCVisitor gcv(f);
        walkPostorder(e, &gcv);
        if (gcv.err)
            return new ErrorExp();
    }
    return e;
}
