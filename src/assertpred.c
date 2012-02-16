// Compiler implementation of the D programming language
// Copyright (c) 1999-2012 by Digital Mars
// All Rights Reserved
// http://www.digitalmars.com
// License for redistribution is by either the Artistic License
// in artistic.txt, or the GNU General Public License in gnu.txt.
// See the included readme.txt for details.

#include <stdlib.h>

#include "expression.h"
#include "scope.h"
#include "declaration.h"
#include "init.h"
#include "parse.h"
#include "root/rmem.h"
#include "id.h"

/*******************************************************************************

This module is to implement bug 5547: Improve assert to give information on
values given to it when it fails.

The improved assert is activated only if it is in the `unittest` block, and
there is no message (the 2nd argument).

Currently, it only recognizes asserts of the form:

    assert(a <rel> b);
    assert(std.math.approxEqual(...));
    assert(!std.math.approxEqual(...));
    assert(std.math.feqrel(a, b) <rel> c);

where `<rel>` is one of the comparison operators (`==`, `>=`, `!<>=` etc) and
the `in`, `is`, `!is` operators, but it is flexible to allow for future
extension. When the assert fails, an AssertError with message like

    unittest failure: <value of a> <rel> <value of b>

will be thrown.

Users who want the old behavior can provide an empty message:

    assert(expr, "");

Internally, the assert will be transformed into

       assert(a <rel> b)
    => (auto __assertPred123 = a,
        auto __assertPred124 = b,
        assert(__assertPred123 <rel> __assertPred124,
               __unittest_toString(a) ~ " <rel> " ~ __unittest_toString(b) ~ " is unexpected")
       )

where __unittest_toString is a template function which converts any type to
string.

*/

/*******************************************************************************
 * Check if the scope "sc" is included in a unittest block.
 */
static bool isInUnitTest(Scope* sc)
{
    for (; sc; sc = sc->enclosing)
        if (sc->func && sc->func->isUnitTestDeclaration())
            return true;
    return false;
}

/*******************************************************************************
 * Convert the expression 'e' into a temporary variable, and append the
 * declaration expression into 'decls'.
 */
static void toTempVar(Expression*& e, Scope* sc, Expressions* declarations)
{
    //e = e->semantic(sc);
    Loc loc = e->loc;
    Identifier* name = Lexer::uniqueId("__asserttmp");
    ExpInitializer* init = new ExpInitializer(loc, e);
    VarDeclaration* var = new VarDeclaration(loc, e->type, name, init);
    DeclarationExp* de = new DeclarationExp(loc, var);
    e = new VarExp(loc, var);
    declarations->push(de);
}

static const char* special_call_funcs[] = {
    "feqrel",
    "approxEqual",
    "opEquals"
};

static const char* special_call_methods[] = {
    "opEquals",
    "opCmp"
};

static void formatAssert(Expression*& e, Scope* sc, PREC parent_prec,
                         Expressions* messages, Expressions* declarations);

static bool formatCall(Loc loc, Identifier* name, Expressions* args, Expression*& pre_dot,
                       Scope* sc, Expressions* messages, Expressions* declarations,
                       const char* const* special_call_ids_array, size_t special_call_ids_count)
{
    for (size_t i = 0; i < special_call_ids_count; ++ i)
    {
        const char* special_name = special_call_ids_array[i];
        if (strncmp(name->string, special_name, name->len+1) == 0)
        {
            if (pre_dot)
            {
                formatAssert(pre_dot, sc, PREC_unary, messages, declarations);
                messages->push(new StringExp(loc, (char*)"."));
            }

            messages->push(new StringExp(loc, name->toChars(), name->len));
            messages->push(new StringExp(loc, (char*)"("));

            for (size_t j = 0; j < args->dim; ++ j)
            {
                if (j != 0)
                    messages->push(new StringExp(loc, (char*)", "));
                formatAssert(args->tdata()[j], sc, PREC_expr, messages, declarations);
            }
            messages->push(new StringExp(loc, (char*)")"));

            return true;
        }
    }
    return false;
}

static void formatAssert(Expression*& e, Scope* sc, PREC parent_prec,
                         Expressions* messages, Expressions* declarations)
{
    PREC cur_prec = precedence[e->op];
    if (cur_prec <= parent_prec)
        messages->push(new StringExp(e->loc, (char*)"("));

    switch (e->op)
    {
        case TOKidentity:   case TOKnotidentity:case TOKequal:  case TOKnotequal:
        case TOKlt:         case TOKle:         case TOKgt:     case TOKge:
        case TOKunord:      case TOKue:         case TOKleg:    case TOKlg:
        case TOKug:         case TOKuge:        case TOKul:     case TOKule:
        case TOKandand:     case TOKoror:       case TOKin:
        {
            BinExp* bin_exp = (BinExp*)e;

            formatAssert(bin_exp->e1, sc, cur_prec, messages, declarations);

            const char* oper = Token::toChars(e->op);
            size_t op_len = strlen(oper);
            char* operator_with_spaces = (char*)mem.malloc(op_len + 3);
            operator_with_spaces[0] = ' ';
            memcpy(operator_with_spaces+1, oper, op_len);
            operator_with_spaces[op_len+1] = ' ';
            operator_with_spaces[op_len+2] = '\0';

            messages->push(new StringExp(e->loc, operator_with_spaces));

            formatAssert(bin_exp->e2, sc, cur_prec, messages, declarations);

            break;
        }

        case TOKnot:
        {
            messages->push(new StringExp(e->loc, (char*)"!"));
            formatAssert(((UnaExp*)e)->e1, sc, cur_prec, messages, declarations);
            break;
        }

        case TOKint64:
        case TOKfloat64:
        case TOKcomplex80:
        case TOKnull:
        case TOKstring:
        {
            messages->push(new StringExp(e->loc, e->toChars()));
            break;
        }

        case TOKcall:
        {
            CallExp* ce = (CallExp*)e;
            if (ce->e1->op == TOKvar)
            {
                VarExp* ve = (VarExp*)ce->e1;
                Expression* null_exp = NULL;
                if (formatCall(ve->loc, ve->var->ident, ce->arguments, null_exp,
                               sc, messages, declarations,
                               special_call_funcs, sizeof(special_call_funcs)/sizeof(*special_call_funcs)))
                    break;
            }
            else if (ce->e1->op == TOKdotvar)
            {
                DotVarExp* dve = (DotVarExp*)ce->e1;
                if (formatCall(dve->loc, dve->var->ident, ce->arguments, dve->e1,
                               sc, messages, declarations,
                               special_call_methods, sizeof(special_call_methods)/sizeof(*special_call_methods)))
                    break;
            }
            // fallthrough
        }

        default:
        {
            toTempVar(e, sc, declarations);

            IdentifierExp* id_exp = new IdentifierExp(e->loc, Id::unittest_toString);
            CallExp* call_exp = new CallExp(e->loc, id_exp, e->syntaxCopy());
            messages->push(call_exp);

            break;
        }
    }

outside:
    if (cur_prec <= parent_prec)
        messages->push(new StringExp(e->loc, (char*)")"));
}

/*******************************************************************************
 * Fold the array [a, b, c, d] to 'a ~ (b ~ (c ~ (d ~ ...' where ~ is given by T.
 */

template <typename T>
Expression* reduceToBinExp(Expressions* es, Expression* final_expression)
{
    Expression* e2 = final_expression;
    size_t i = es->dim;
    while (i > 0)
    {
        Expression* e1 = es->tdata()[--i];
        e2 = new T(e2->loc, e1, e2);
    }
    return e2;
}

Expression* transformToAssertPred(AssertExp* e, Scope *sc)
{
    if (!isInUnitTest(sc))
        return NULL;

    Expressions messages;
    Expressions declarations;
    formatAssert(e->e1, sc, PREC_zero, &messages, &declarations);

    Expression* msg = reduceToBinExp<CatExp>(&messages, new StringExp(e->loc, (char*)"  is unexpected"));
    AssertExp* new_assert_exp = new AssertExp(e->loc, e->e1, msg);

    return reduceToBinExp<CommaExp>(&declarations, new_assert_exp);
}


