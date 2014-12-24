
/* Compiler implementation of the D programming language
 * Copyright (c) 2014 by Digital Mars
 * All Rights Reserved
 * written by Jacob Carlborg
 * http://www.digitalmars.com
 * Distributed under the Boost Software License, Version 1.0.
 * http://www.boost.org/LICENSE_1_0.txt
 * https://github.com/D-Programming-Language/dmd/blob/master/src/objc_func_selector.c
 */

#include "aggregate.h"
#include "attrib.h"
#include "declaration.h"
#include "expression.h"
#include "id.h"
#include "objc.h"
#include "scope.h"

void objc_FuncDeclaration_semantic_setSelector(FuncDeclaration *self, Scope *sc)
{
    if (!self->userAttribDecl)
        return;

    Expressions *udas = self->userAttribDecl->getAttributes();
    arrayExpressionSemantic(udas, sc, true);

    for (size_t i = 0; i < udas->dim; i++)
    {
        Expression *uda = (*udas)[i];
        assert(uda->type);

        if (uda->type->ty != Ttuple)
            continue;

        Expressions *exps = ((TupleExp *)uda)->exps;

        for (size_t j = 0; j < exps->dim; j++)
        {
            Expression *e = (*exps)[j];
            assert(e->type);

            if (e->type->ty == Tstruct)
            {
                StructLiteralExp *literal = (StructLiteralExp *)e;
                assert(literal->sd);

                if (strcmp(Id::udaSelector->string, literal->sd->toPrettyChars()) == 0)
                {
                    if (self->objc.selector)
                    {
                        self->error("can only have one Objective-C selector per method");
                        return;
                    }

                    assert(literal->elements->dim == 1);
                    StringExp *se = (*literal->elements)[0]->toStringExp();
                    assert(se);

                    self->objc.selector = ObjcSelector::lookup((const char *)se->toUTF8(sc)->string);
                }
            }
        }
    }
}
