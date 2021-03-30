
/* Compiler implementation of the D programming language
 * Copyright (C) 1999-2021 by The D Language Foundation, All Rights Reserved
 * written by Walter Bright
 * http://www.digitalmars.com
 * Distributed under the Boost Software License, Version 1.0.
 * http://www.boost.org/LICENSE_1_0.txt
 * https://github.com/D-Programming-Language/dmd/blob/master/src/cppmanglewin.c
 */

/**
 * Do mangling for C++ linkage for Digital Mars C++ and Microsoft Visual C++
 */

#include "root/dsystem.h"

#include "mars.h"
#include "dsymbol.h"
#include "mtype.h"
#include "scope.h"
#include "init.h"
#include "expression.h"
#include "attrib.h"
#include "declaration.h"
#include "template.h"
#include "id.h"
#include "enum.h"
#include "import.h"
#include "aggregate.h"
#include "target.h"

typedef int (*ForeachDg)(void *ctx, size_t paramidx, Parameter *param);
int Parameter_foreach(Parameters *parameters, ForeachDg dg, void *ctx, size_t *pn = NULL);
bool isSpecialEnumIdent(const Identifier *ident);

#define VC_SAVED_TYPE_CNT 10
#define VC_SAVED_IDENT_CNT 10

class VisualCPPMangler : public Visitor
{
    const char *saved_idents[VC_SAVED_IDENT_CNT];
    Type *saved_types[VC_SAVED_TYPE_CNT];

    // IS_NOT_TOP_TYPE: when we mangling one argument, we can call visit several times (for base types of arg type)
    // but we must save only arg type:
    // For example: if we have an int** argument, we should save "int**" but visit will be called for "int**", "int*", "int"
    // This flag is set up by the visit(NextType, ) function  and should be reset when the arg type output is finished.
    // MANGLE_RETURN_TYPE: return type shouldn't be saved and substituted in arguments
    // IGNORE_CONST: in some cases we should ignore CV-modifiers.

    enum Flags
    {
        IS_NOT_TOP_TYPE    = 0x1,
        MANGLE_RETURN_TYPE = 0x2,
        IGNORE_CONST       = 0x4,
        IS_DMC             = 0x8
    };

    int flags;
    OutBuffer buf;

    VisualCPPMangler(VisualCPPMangler *rvl)
        : flags(0), buf()
    {
        flags |= (rvl->flags & IS_DMC);
        memcpy(&saved_idents, &rvl->saved_idents, sizeof(const char*) * VC_SAVED_IDENT_CNT);
        memcpy(&saved_types, &rvl->saved_types, sizeof(Type*) * VC_SAVED_TYPE_CNT);
    }

public:
    VisualCPPMangler(bool isdmc)
        : flags(0), buf()
    {
        if (isdmc)
        {
            flags |= IS_DMC;
        }
        memset(&saved_idents, 0, sizeof(const char*) * VC_SAVED_IDENT_CNT);
        memset(&saved_types, 0, sizeof(Type*) * VC_SAVED_TYPE_CNT);
    }

    void visit(Type *type)
    {
        if (type->isImmutable() || type->isShared())
        {
            type->error(Loc(), "Internal Compiler Error: shared or immutable types can not be mapped to C++ (%s)", type->toChars());
        }
        else
        {
            type->error(Loc(), "Internal Compiler Error: type %s can not be mapped to C++\n", type->toChars());
        }
        fatal(); // Fatal, because this error should be handled in frontend
    }

    void visit(TypeBasic *type)
    {
        //printf("visit(TypeBasic); is_not_top_type = %d\n", (int)(flags & IS_NOT_TOP_TYPE));
        if (type->isImmutable() || type->isShared())
        {
            visit((Type*)type);
            return;
        }

        if (type->isConst() && ((flags & IS_NOT_TOP_TYPE) || (flags & IS_DMC)))
        {
            if (checkTypeSaved(type))
                return;
        }

        if ((type->ty == Tbool) && checkTypeSaved(type))// try to replace long name with number
        {
            return;
        }
        mangleModifier(type);
        switch (type->ty)
        {
            case Tvoid:     buf.writeByte('X');        break;
            case Tint8:     buf.writeByte('C');        break;
            case Tuns8:     buf.writeByte('E');        break;
            case Tint16:    buf.writeByte('F');        break;
            case Tuns16:    buf.writeByte('G');        break;
            case Tint32:    buf.writeByte('H');        break;
            case Tuns32:    buf.writeByte('I');        break;
            case Tfloat32:  buf.writeByte('M');        break;
            case Tint64:    buf.writestring("_J");     break;
            case Tuns64:    buf.writestring("_K");     break;
            case Tint128:   buf.writestring("_L");     break;
            case Tuns128:   buf.writestring("_M");     break;
            case Tfloat64:  buf.writeByte('N');        break;
            case Tbool:     buf.writestring("_N");     break;
            case Tchar:     buf.writeByte('D');        break;
            case Tdchar:    buf.writeByte('I');        break; // unsigned int

            case Tfloat80:
                if (flags & IS_DMC)
                    buf.writestring("_Z"); // DigitalMars long double
                else
                    buf.writestring("_T"); // Intel long double
                break;

            case Twchar:
                if (flags & IS_DMC)
                    buf.writestring("_Y"); // DigitalMars wchar_t
                else
                    buf.writestring("_W"); // Visual C++ wchar_t
                break;

            default:        visit((Type*)type); return;
        }
        flags &= ~IS_NOT_TOP_TYPE;
        flags &= ~IGNORE_CONST;
    }

    void visit(TypeVector *type)
    {
        //printf("visit(TypeVector); is_not_top_type = %d\n", (int)(flags & IS_NOT_TOP_TYPE));
        if (checkTypeSaved(type))
            return;
        buf.writestring("T__m128@@"); // may be better as __m128i or __m128d?
        flags &= ~IS_NOT_TOP_TYPE;
        flags &= ~IGNORE_CONST;
    }

    void visit(TypeSArray *type)
    {
        // This method can be called only for static variable type mangling.
        //printf("visit(TypeSArray); is_not_top_type = %d\n", (int)(flags & IS_NOT_TOP_TYPE));
        if (checkTypeSaved(type))
            return;
        // first dimension always mangled as const pointer
        if (flags & IS_DMC)
            buf.writeByte('Q');
        else
            buf.writeByte('P');

        flags |= IS_NOT_TOP_TYPE;
        assert(type->next);
        if (type->next->ty == Tsarray)
        {
            mangleArray((TypeSArray*)type->next);
        }
        else
        {
            type->next->accept(this);
        }
    }

    // attention: D int[1][2]* arr mapped to C++ int arr[][2][1]; (because it's more typical situation)
    // There is not way to map int C++ (*arr)[2][1] to D
    void visit(TypePointer *type)
    {
        //printf("visit(TypePointer); is_not_top_type = %d\n", (int)(flags & IS_NOT_TOP_TYPE));
        if (type->isImmutable() || type->isShared())
        {
            visit((Type*)type);
            return;
        }

        assert(type->next);
        if (type->next->ty == Tfunction)
        {
            const char *arg = mangleFunctionType((TypeFunction*)type->next); // compute args before checking to save; args should be saved before function type

            // If we've mangled this function early, previous call is meaningless.
            // However we should do it before checking to save types of function arguments before function type saving.
            // If this function was already mangled, types of all it arguments are save too, thus previous can't save
            // anything if function is saved.
            if (checkTypeSaved(type))
                return;

            if (type->isConst())
                buf.writeByte('Q'); // const
            else
                buf.writeByte('P'); // mutable

            buf.writeByte('6'); // pointer to a function
            buf.writestring(arg);
            flags &= ~IS_NOT_TOP_TYPE;
            flags &= ~IGNORE_CONST;
            return;
        }
        else if (type->next->ty == Tsarray)
        {
            if (checkTypeSaved(type))
                return;
            mangleModifier(type);

            if (type->isConst() || !(flags & IS_DMC))
                buf.writeByte('Q'); // const
            else
                buf.writeByte('P'); // mutable

            if (global.params.is64bit)
                buf.writeByte('E');
            flags |= IS_NOT_TOP_TYPE;

            mangleArray((TypeSArray*)type->next);
            return;
        }
        else
        {
            if (checkTypeSaved(type))
                return;
            mangleModifier(type);

            if (type->isConst())
            {
                buf.writeByte('Q'); // const
            }
            else
            {
                buf.writeByte('P'); // mutable
            }

            if (global.params.is64bit)
                buf.writeByte('E');
            flags |= IS_NOT_TOP_TYPE;
            type->next->accept(this);
        }
    }

    void visit(TypeReference *type)
    {
        //printf("visit(TypeReference); type = %s\n", type->toChars());
        if (checkTypeSaved(type))
            return;

        if (type->isImmutable() || type->isShared())
        {
            visit((Type*)type);
            return;
        }

        buf.writeByte('A'); // mutable

        if (global.params.is64bit)
            buf.writeByte('E');
        flags |= IS_NOT_TOP_TYPE;
        assert(type->next);
        if (type->next->ty == Tsarray)
        {
            mangleArray((TypeSArray*)type->next);
        }
        else
        {
            type->next->accept(this);
        }
    }

    void visit(TypeFunction *type)
    {
        const char *arg = mangleFunctionType(type);

        if ((flags & IS_DMC))
        {
            if (checkTypeSaved(type))
                return;
        }
        else
        {
            buf.writestring("$$A6");
        }
        buf.writestring(arg);
        flags &= ~(IS_NOT_TOP_TYPE | IGNORE_CONST);
    }

    void visit(TypeStruct *type)
    {
        if (checkTypeSaved(type))
            return;
        //printf("visit(TypeStruct); is_not_top_type = %d\n", (int)(flags & IS_NOT_TOP_TYPE));
        mangleModifier(type);
        if (type->sym->isUnionDeclaration())
            buf.writeByte('T');
        else
            buf.writeByte(type->cppmangle == CPPMANGLEclass ? 'V' : 'U');
        mangleIdent(type->sym);
        flags &= ~IS_NOT_TOP_TYPE;
        flags &= ~IGNORE_CONST;
    }

    void visit(TypeEnum *type)
    {
        //printf("visit(TypeEnum); is_not_top_type = %d\n", (int)(flags & IS_NOT_TOP_TYPE));
        const Identifier *id = type->sym->ident;
        const char *c = NULL;
        if (id == Id::__c_long_double)
            c = "O"; // VC++ long double
        else if (id == Id::__c_long)
            c = "J"; // VC++ long
        else if (id == Id::__c_ulong)
            c = "K"; // VC++ unsigned long
        else if (id == Id::__c_longlong)
            c = "_J"; // VC++ long long
        else if (id == Id::__c_ulonglong)
            c = "_K"; // VC++ unsigned long long
        else if (id == Id::__c_wchar_t)
        {
            c = (flags & IS_DMC) ? "_Y" : "_W";
        }

        if (c)
        {
            if (type->isConst() && ((flags & IS_NOT_TOP_TYPE) || (flags & IS_DMC)))
            {
                if (checkTypeSaved(type))
                    return;
            }
            mangleModifier(type);
            buf.writestring(c);
        }
        else
        {
            if (checkTypeSaved(type))
                return;
            mangleModifier(type);
            buf.writeByte('W');

            switch (type->sym->memtype->ty)
            {
                case Tchar:
                case Tint8:
                    buf.writeByte('0');
                    break;
                case Tuns8:
                    buf.writeByte('1');
                    break;
                case Tint16:
                    buf.writeByte('2');
                    break;
                case Tuns16:
                    buf.writeByte('3');
                    break;
                case Tint32:
                    buf.writeByte('4');
                    break;
                case Tuns32:
                    buf.writeByte('5');
                    break;
                case Tint64:
                    buf.writeByte('6');
                    break;
                case Tuns64:
                    buf.writeByte('7');
                    break;
                default:
                    visit((Type*)type);
                    break;
            }
            mangleIdent(type->sym);
        }
        flags &= ~IS_NOT_TOP_TYPE;
        flags &= ~IGNORE_CONST;
    }

    // D class mangled as pointer to C++ class
    // const(Object) mangled as Object const* const
    void visit(TypeClass *type)
    {
        //printf("visit(TypeClass); is_not_top_type = %d\n", (int)(flags & IS_NOT_TOP_TYPE));
        if (checkTypeSaved(type))
            return;
        if (flags & IS_NOT_TOP_TYPE)
            mangleModifier(type);

        if (type->isConst())
            buf.writeByte('Q');
        else
            buf.writeByte('P');

        if (global.params.is64bit)
            buf.writeByte('E');

        flags |= IS_NOT_TOP_TYPE;
        mangleModifier(type);

        buf.writeByte(type->cppmangle == CPPMANGLEstruct ? 'U' : 'V');

        mangleIdent(type->sym);
        flags &= ~IS_NOT_TOP_TYPE;
        flags &= ~IGNORE_CONST;
    }

    char *mangleOf(Dsymbol *s)
    {
        VarDeclaration *vd = s->isVarDeclaration();
        FuncDeclaration *fd = s->isFuncDeclaration();
        if (vd)
        {
            mangleVariable(vd);
        }
        else if (fd)
        {
            mangleFunction(fd);
        }
        else
        {
            assert(0);
        }
        return buf.extractChars();
    }
private:

    void mangleFunction(FuncDeclaration *d)
    {
        // <function mangle> ? <qualified name> <flags> <return type> <arg list>
        assert(d);
        buf.writeByte('?');
        mangleIdent(d);

        if (d->needThis()) // <flags> ::= <virtual/protection flag> <const/volatile flag> <calling convention flag>
        {
            // Pivate methods always non-virtual in D and it should be mangled as non-virtual in C++
            //printf("%s: isVirtualMethod = %d, isVirtual = %d, vtblIndex = %d, interfaceVirtual = %p\n",
                //d->toChars(), d->isVirtualMethod(), d->isVirtual(), (int)d->vtblIndex, d->interfaceVirtual);
            if (d->isVirtual() && (d->vtblIndex != -1 || d->interfaceVirtual || d->overrideInterface()))
            {
                switch (d->protection.kind)
                {
                    case Prot::private_:
                        buf.writeByte('E');
                        break;
                    case Prot::protected_:
                        buf.writeByte('M');
                        break;
                    default:
                        buf.writeByte('U');
                        break;
                }
            }
            else
            {
                switch (d->protection.kind)
                {
                    case Prot::private_:
                        buf.writeByte('A');
                        break;
                    case Prot::protected_:
                        buf.writeByte('I');
                        break;
                    default:
                        buf.writeByte('Q');
                        break;
                }
            }
            if (global.params.is64bit)
                buf.writeByte('E');
            if (d->type->isConst())
            {
                buf.writeByte('B');
            }
            else
            {
                buf.writeByte('A');
            }
        }
        else if (d->isMember2()) // static function
        {                        // <flags> ::= <virtual/protection flag> <calling convention flag>
            switch (d->protection.kind)
            {
                case Prot::private_:
                    buf.writeByte('C');
                    break;
                case Prot::protected_:
                    buf.writeByte('K');
                    break;
                default:
                    buf.writeByte('S');
                    break;
            }
        }
        else // top-level function
        {    // <flags> ::= Y <calling convention flag>
            buf.writeByte('Y');
        }

        const char *args = mangleFunctionType((TypeFunction *)d->type, (bool)d->needThis(), d->isCtorDeclaration() || d->isDtorDeclaration());
        buf.writestring(args);
    }

    void mangleVariable(VarDeclaration *d)
    {
        // <static variable mangle> ::= ? <qualified name> <protection flag> <const/volatile flag> <type>
        assert(d);
        // fake mangling for fields to fix https://issues.dlang.org/show_bug.cgi?id=16525
        if (!(d->storage_class & (STCextern | STCfield | STCgshared)))
        {
            d->error("Internal Compiler Error: C++ static non- __gshared non-extern variables not supported");
            fatal();
        }
        buf.writeByte('?');
        mangleIdent(d);

        assert((d->storage_class & STCfield) || !d->needThis());

        Dsymbol *parent = d->toParent3();
        while (parent && parent->isNspace())
        {
            parent = parent->toParent3();
        }
        if (parent && parent->isModule()) // static member
        {
            buf.writeByte('3');
        }
        else
        {
            switch (d->protection.kind)
            {
                case Prot::private_:
                    buf.writeByte('0');
                    break;
                case Prot::protected_:
                    buf.writeByte('1');
                    break;
                default:
                    buf.writeByte('2');
                    break;
            }
        }

        char cv_mod = 0;
        Type *t = d->type;

        if (t->isImmutable() || t->isShared())
        {
            visit((Type*)t);
            return;
        }
        if (t->isConst())
        {
            cv_mod = 'B'; // const
        }
        else
        {
            cv_mod = 'A'; // mutable
        }

        if (t->ty != Tpointer)
            t = t->mutableOf();

        t->accept(this);

        if ((t->ty == Tpointer || t->ty == Treference || t->ty == Tclass) && global.params.is64bit)
        {
            buf.writeByte('E');
        }

        buf.writeByte(cv_mod);
    }

    void mangleName(Dsymbol *sym, bool dont_use_back_reference = false)
    {
        //printf("mangleName('%s')\n", sym->toChars());
        const char *name = NULL;
        bool is_dmc_template = false;
        if (sym->isDtorDeclaration())
        {
            buf.writestring("?1");
            return;
        }
        if (TemplateInstance *ti = sym->isTemplateInstance())
        {
            VisualCPPMangler tmp((flags & IS_DMC) ? true : false);
            tmp.buf.writeByte('?');
            tmp.buf.writeByte('$');
            tmp.buf.writestring(ti->name->toChars());
            tmp.saved_idents[0] = ti->name->toChars();
            tmp.buf.writeByte('@');
            if (flags & IS_DMC)
            {
                tmp.mangleIdent(sym->parent, true);
                is_dmc_template = true;
            }

            bool is_var_arg = false;
            for (size_t i = 0; i < ti->tiargs->length; i++)
            {
                RootObject *o = (*ti->tiargs)[i];

                TemplateParameter *tp = NULL;
                TemplateValueParameter *tv = NULL;
                TemplateTupleParameter *tt = NULL;
                if (!is_var_arg)
                {
                    TemplateDeclaration *td = ti->tempdecl->isTemplateDeclaration();
                    assert(td);
                    tp = (*td->parameters)[i];
                    tv = tp->isTemplateValueParameter();
                    tt = tp->isTemplateTupleParameter();
                }

                if (tt)
                {
                    is_var_arg = true;
                    tp = NULL;
                }
                if (tv)
                {
                    if (tv->valType->isintegral())
                    {

                        tmp.buf.writeByte('$');
                        tmp.buf.writeByte('0');

                        Expression *e = isExpression(o);
                        assert(e);

                        if (tv->valType->isunsigned())
                        {
                            tmp.mangleNumber(e->toUInteger());
                        }
                        else if(is_dmc_template)
                        {
                            // NOTE: DMC mangles everything based on
                            // unsigned int
                            tmp.mangleNumber(e->toInteger());
                        }
                        else
                        {
                            sinteger_t val = e->toInteger();
                            if (val < 0)
                            {
                                val = -val;
                                tmp.buf.writeByte('?');
                            }
                            tmp.mangleNumber(val);
                        }
                    }
                    else
                    {
                        sym->error("Internal Compiler Error: C++ %s template value parameter is not supported", tv->valType->toChars());
                        fatal();
                    }
                }
                else if (!tp || tp->isTemplateTypeParameter())
                {
                    Type *t = isType(o);
                    assert(t);
                    t->accept(&tmp);
                }
                else if (tp->isTemplateAliasParameter())
                {
                    Dsymbol *d = isDsymbol(o);
                    Expression *e = isExpression(o);
                    if (!d && !e)
                    {
                        sym->error("Internal Compiler Error: %s is unsupported parameter for C++ template", o->toChars());
                        fatal();
                    }
                    if (d && d->isFuncDeclaration())
                    {
                        tmp.buf.writeByte('$');
                        tmp.buf.writeByte('1');
                        tmp.mangleFunction(d->isFuncDeclaration());
                    }
                    else if (e && e->op == TOKvar && ((VarExp*)e)->var->isVarDeclaration())
                    {
                        tmp.buf.writeByte('$');
                        if (flags & IS_DMC)
                            tmp.buf.writeByte('1');
                        else
                            tmp.buf.writeByte('E');
                        tmp.mangleVariable(((VarExp*)e)->var->isVarDeclaration());
                    }
                    else if (d && d->isTemplateDeclaration() && d->isTemplateDeclaration()->onemember)
                    {

                        Dsymbol *ds = d->isTemplateDeclaration()->onemember;
                        if (flags & IS_DMC)
                        {
                            tmp.buf.writeByte('V');
                        }
                        else
                        {
                            if (ds->isUnionDeclaration())
                            {
                                tmp.buf.writeByte('T');
                            }
                            else if (ds->isStructDeclaration())
                            {
                                tmp.buf.writeByte('U');
                            }
                            else if (ds->isClassDeclaration())
                            {
                                tmp.buf.writeByte('V');
                            }
                            else
                            {
                                sym->error("Internal Compiler Error: C++ templates support only integral value, type parameters, alias templates and alias function parameters");
                                fatal();
                            }
                        }
                        tmp.mangleIdent(d);
                    }
                    else
                    {
                        sym->error("Internal Compiler Error: %s is unsupported parameter for C++ template: (%s)", o->toChars());
                        fatal();
                    }

                }
                else
                {
                    sym->error("Internal Compiler Error: C++ templates support only integral value, type parameters, alias templates and alias function parameters");
                    fatal();
                }
            }
            name = tmp.buf.extractChars();
        }
        else
        {
            name = sym->ident->toChars();
        }
        assert(name);
        if (is_dmc_template)
        {
            if (checkAndSaveIdent(name))
                return;
        }
        else
        {
            if (dont_use_back_reference)
            {
                saveIdent(name);
            }
            else
            {
                if (checkAndSaveIdent(name))
                    return;
            }
        }
        buf.writestring(name);
        buf.writeByte('@');
    }

    // returns true if name already saved
    bool checkAndSaveIdent(const char *name)
    {
        for (size_t i = 0; i < VC_SAVED_IDENT_CNT; i++)
        {
            if (!saved_idents[i]) // no saved same name
            {
                saved_idents[i] = name;
                break;
            }

            if (!strcmp(saved_idents[i], name)) // ok, we've found same name. use index instead of name
            {
                buf.writeByte(i + '0');
                return true;
            }
        }
        return false;
    }

    void saveIdent(const char *name)
    {
        for (size_t i = 0; i < VC_SAVED_IDENT_CNT; i++)
        {
            if (!saved_idents[i]) // no saved same name
            {
                saved_idents[i] = name;
                break;
            }

            if (!strcmp(saved_idents[i], name)) // ok, we've found same name. use index instead of name
            {
                return;
            }
        }
    }

    void mangleIdent(Dsymbol *sym, bool dont_use_back_reference = false)
    {
        // <qualified name> ::= <sub-name list> @
        // <sub-name list>  ::= <sub-name> <name parts>
        //                  ::= <sub-name>

        // <sub-name> ::= <identifier> @
        //            ::= ?$ <identifier> @ <template args> @
        //            :: <back reference>

        // <back reference> ::= 0-9

        // <template args> ::= <template arg> <template args>
        //                ::= <template arg>

        // <template arg>  ::= <type>
        //                ::= $0<encoded integral number>

        //printf("mangleIdent('%s')\n", sym->toChars());
        Dsymbol *p = sym;
        if (p->toParent3() && p->toParent3()->isTemplateInstance())
        {
            p = p->toParent3();
        }
        while (p && !p->isModule())
        {
            mangleName(p, dont_use_back_reference);

            p = p->toParent3();
            if (p->toParent3() && p->toParent3()->isTemplateInstance())
            {
                p = p->toParent3();
            }
        }
        if (!dont_use_back_reference)
            buf.writeByte('@');
    }

    void mangleNumber(dinteger_t num)
    {
        if (!num) // 0 encoded as "A@"
        {
            buf.writeByte('A');
            buf.writeByte('@');
            return;
        }
        if (num <= 10) // 5 encoded as "4"
        {
            buf.writeByte((char)(num - 1 + '0'));
            return;
        }

        char buff[17];
        buff[16] = 0;
        size_t i = 16;
        while (num)
        {
            --i;
            buff[i] = num % 16 + 'A';
            num /=16;
        }
        buf.writestring(&buff[i]);
        buf.writeByte('@');
    }

    bool checkTypeSaved(Type *type)
    {
        if (flags & IS_NOT_TOP_TYPE)
            return false;
        if (flags & MANGLE_RETURN_TYPE)
            return false;
        for (size_t i = 0; i < VC_SAVED_TYPE_CNT; i++)
        {
            if (!saved_types[i]) // no saved same type
            {
                saved_types[i] = type;
                return false;
            }
            if (saved_types[i]->equals(type)) // ok, we've found same type. use index instead of type
            {
                buf.writeByte(i + '0');
                flags &= ~IS_NOT_TOP_TYPE;
                flags &= ~IGNORE_CONST;
                return true;
            }
        }
        return false;
    }

    void mangleModifier(Type *type)
    {
        if (flags & IGNORE_CONST)
            return;
        if (type->isImmutable() || type->isShared())
        {
            visit((Type*)type);
            return;
        }
        if (type->isConst())
        {
            if (flags & IS_NOT_TOP_TYPE)
                buf.writeByte('B'); // const
                else if ((flags & IS_DMC) && type->ty != Tpointer)
                    buf.writestring("_O");
        }
        else if (flags & IS_NOT_TOP_TYPE)
            buf.writeByte('A'); // mutable
    }

    void mangleArray(TypeSArray *type)
    {
        mangleModifier(type);
        size_t i=0;
        Type *cur = type;
        while (cur && cur->ty == Tsarray)
        {
            i++;
            cur = cur->nextOf();
        }
        buf.writeByte('Y');
        mangleNumber(i); // count of dimensions
        cur = type;
        while (cur && cur->ty == Tsarray) // sizes of dimensions
        {
            TypeSArray *sa = (TypeSArray*)cur;
            mangleNumber(sa->dim ? sa->dim->toInteger() : 0);
            cur = cur->nextOf();
        }
        flags |= IGNORE_CONST;
        cur->accept(this);
    }

    static int mangleParameterDg(void *ctx, size_t, Parameter *p)
    {
        VisualCPPMangler *mangler = (VisualCPPMangler *)ctx;

        Type *t = p->type;
        if (p->storageClass & (STCout | STCref))
        {
            t = t->referenceTo();
        }
        else if (p->storageClass & STClazy)
        {
            // Mangle as delegate
            Type *td = new TypeFunction(ParameterList(), t, LINKd);
            td = new TypeDelegate(td);
            t = t->merge();
        }
        if (t->ty == Tsarray)
        {
            t->error(Loc(), "Internal Compiler Error: unable to pass static array to extern(C++) function.");
            t->error(Loc(), "Use pointer instead.");
            fatal();
        }
        mangler->flags &= ~IS_NOT_TOP_TYPE;
        mangler->flags &= ~IGNORE_CONST;
        t->accept(mangler);

        return 0;
    }

    const char *mangleFunctionType(TypeFunction *type, bool needthis = false, bool noreturn = false)
    {
        VisualCPPMangler tmp(this);
        // Calling convention
        if (global.params.is64bit) // always Microsoft x64 calling convention
        {
            tmp.buf.writeByte('A');
        }
        else
        {
            switch (type->linkage)
            {
                case LINKc:
                    tmp.buf.writeByte('A');
                    break;
                case LINKcpp:
                    if (needthis && type->parameterList.varargs != VARARGvariadic)
                        tmp.buf.writeByte('E'); // thiscall
                    else
                        tmp.buf.writeByte('A'); // cdecl
                    break;
                case LINKwindows:
                    tmp.buf.writeByte('G'); // stdcall
                    break;
                default:
                    tmp.visit((Type*)type);
                    break;
            }
        }

        tmp.flags &= ~IS_NOT_TOP_TYPE;
        if (noreturn)
        {
            tmp.buf.writeByte('@');
        }
        else
        {
            Type *rettype = type->next;
            if (type->isref)
                rettype = rettype->referenceTo();
            flags &= ~IGNORE_CONST;
            if (rettype->ty == Tstruct)
            {
                tmp.buf.writeByte('?');
                tmp.buf.writeByte('A');
            }
            else if (rettype->ty == Tenum)
            {
                Identifier *id = rettype->toDsymbol(NULL)->ident;
                if (!isSpecialEnumIdent(id))
                {
                    tmp.buf.writeByte('?');
                    tmp.buf.writeByte('A');
                }
            }
            tmp.flags |= MANGLE_RETURN_TYPE;
            rettype->accept(&tmp);
            tmp.flags &= ~MANGLE_RETURN_TYPE;
        }
        if (!type->parameterList.parameters || !type->parameterList.parameters->length)
        {
            if (type->parameterList.varargs == VARARGvariadic)
                tmp.buf.writeByte('Z');
            else
                tmp.buf.writeByte('X');
        }
        else
        {
            Parameter_foreach(type->parameterList.parameters, &mangleParameterDg, (void*)&tmp);
            if (type->parameterList.varargs == VARARGvariadic)
            {
                tmp.buf.writeByte('Z');
            }
            else
            {
                tmp.buf.writeByte('@');
            }
        }

        tmp.buf.writeByte('Z');
        const char *ret = tmp.buf.extractChars();
        memcpy(&saved_idents, &tmp.saved_idents, sizeof(const char*) * VC_SAVED_IDENT_CNT);
        memcpy(&saved_types, &tmp.saved_types, sizeof(Type*) * VC_SAVED_TYPE_CNT);
        return ret;
    }
};

const char *toCppMangleMSVC(Dsymbol *s)
{
    VisualCPPMangler v(!global.params.mscoff);
    return v.mangleOf(s);
}

const char *cppTypeInfoMangleMSVC(Dsymbol *)
{
    //printf("cppTypeInfoMangleMSVC(%s)\n", s->toChars());
    assert(0);
    return NULL;
}
