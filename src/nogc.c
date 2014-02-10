// Compiler implementation of the D programming language
// Copyright (c) 1999-2013 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// http://www.digitalmars.com
// License for redistribution is by either the Artistic License
// in artistic.txt, or the GNU General Public License in gnu.txt.
// See the included readme.txt for details.

#include "mars.h"
#include "init.h"
#include "visitor.h"
#include "expression.h"
#include "statement.h"
#include "declaration.h"
#include "id.h"

bool walkPostorder(Statement *s, StoppableVisitor *v);
bool walkPostorder(Expression *e, StoppableVisitor *v);

/**************************************
 * Look for GC-allocations
 */
class NOGCVisitor : public StoppableVisitor
{
public:
    FuncDeclaration *func;

    NOGCVisitor(FuncDeclaration *fdecl)
    {
        func = fdecl;
    }

    void doCond(Initializer *init)
    {
        if (init)
            init->accept(this);
    }

    void doCond(Expression *exp)
    {
        if (exp)
            walkPostorder(exp, this);
    }

    void visit(Initializer *init)
    {
    }
    void visit(StructInitializer *init)
    {
        for (size_t i = 0; i < init->value.dim; i++)
            doCond(init->value[i]);
    }
    void visit(ArrayInitializer *init)
    {
        for (size_t i = 0; i < init->value.dim; i++)
            doCond(init->value[i]);
    }
    void visit(ExpInitializer *init)
    {
        doCond(init->exp);
    }

    void visit(Statement *s)
    {
    }
    void visit(ExpStatement *s)
    {
        doCond(s->exp);
    }
    void visit(CompileStatement *s)
    {
    }
    void visit(WhileStatement *s)
    {
        doCond(s->condition);
    }
    void visit(DoStatement *s)
    {
        doCond(s->condition);
    }
    void visit(ForStatement *s)
    {
        doCond(s->condition);
        doCond(s->increment);
    }
    void visit(ForeachStatement *s)
    {
        doCond(s->aggr);
    }
    void visit(ForeachRangeStatement *s)
    {
        doCond(s->lwr);
        doCond(s->upr);
    }
    void visit(IfStatement *s)
    {
        doCond(s->condition);
    }
    void visit(PragmaStatement *s)
    {
        for (size_t i = 0; i < s->args->dim; i++)
            doCond((*s->args)[i]);
    }
    void visit(SwitchStatement *s)
    {
        doCond(s->condition);
    }
    void visit(CaseStatement *s)
    {
        doCond(s->exp);
    }
    void visit(CaseRangeStatement *s)
    {
        doCond(s->first);
        doCond(s->last);
    }
    void visit(ReturnStatement *s)
    {
        doCond(s->exp);
    }
    void visit(SynchronizedStatement *s)
    {
        doCond(s->exp);
    }
    void visit(WithStatement *s)
    {
        doCond(s->exp);
    }
    void visit(ThrowStatement *s)
    {
        doCond(s->exp);
    }

    void visit(Expression *e)
    {
    }
    void visit(DeclarationExp *e)
    {
        VarDeclaration *var = e->declaration->isVarDeclaration();
        if (var)
        {
            doCond(var->init);
        }
    }
    void visit(CallExp *e)
    {
        if (e->e1 && e->e1->op == TOKvar)
        {
            VarExp *ve = (VarExp*)e->e1;
            if (ve->var && ve->var->isFuncDeclaration() && ve->var->isFuncDeclaration()->ident)
            {
                Identifier *ident = ve->var->isFuncDeclaration()->ident;

                if (ident == Id::adDup)
                {
                    if (func->setGCUse(e->loc, "'dup' causes gc allocation"))
                    {
                        e->error("Can not use 'dup' in @nogc code");
                    }
                }
            }
        }
    }
    void visit(CatExp *e)
    {
        if (func->setGCUse(e->loc, "Concatenation may cause gc allocation"))
            e->error("Can not use concatenation in @nogc code");
    }
    void visit(CatAssignExp *e)
    {
        if (func->setGCUse(e->loc, "Concatenation may cause gc allocation"))
            e->error("Can not use concatenation in @nogc code");
    }
    void visit(AssignExp *e)
    {
        if (e->e1->op == TOKarraylength
           && func->setGCUse(e->loc, "Setting 'length' may cause gc allocation"))
        {
            e->error("Can not set 'length' in @nogc code");
        }
    }
    void visit(DeleteExp *e)
    {
        if (func->setGCUse(e->loc, "'delete' requires gc"))
            e->error("Can not use 'delete' in @nogc code");
    }
    void visit(NewExp *e)
    {
        if (!e->allocator && !e->onstack && func->setGCUse(e->loc, "'new' causes gc allocation"))
            e->error("Can not use 'new' in @nogc code");
    }
    void visit(NewAnonClassExp *e)
    {
        if (func->setGCUse(e->loc, "'new' causes gc allocation"))
            e->error("Can not use 'new' in @nogc code");
    }
    void visit(AssocArrayLiteralExp *e)
    {
        if (e->keys->dim
            && func->setGCUse(e->loc, "Associative array literals cause gc allocation"))
        {
            e->error("Can not use associative array literals in @nogc code");
        }
    }
    void visit(ArrayLiteralExp *e)
    {
        bool init_const = false;
        if (e->type->ty == Tarray)
        {
            init_const = true;
            for (size_t i = 0; i < e->elements->dim; i++)
            {
                if (!((*e->elements)[i])->isConst())
                {
                    init_const = false;
                    break;
                }
            }
        }
        if (e->elements && e->elements->dim != 0 && e->type->ty != Tsarray && !init_const &&
            func->setGCUse(e->loc, "Array literals cause gc allocation"))
        {
                e->error("Can not use array literals in @nogc code");
        }
    }
    void visit(IndexExp* e)
    {
        if (e->e1->type->ty == Taarray && func->setGCUse(e->loc, "Indexing an associative"
            " array may cause gc allocation"))
        {
            e->error("Can not index an associative array in @nogc code");
        }
    }
};

void checkGC(FuncDeclaration *func, Statement *stmt)
{
    if (global.params.vgc)
    {
        NOGCVisitor gcv(func);
        walkPostorder(stmt, &gcv);
    }
}
