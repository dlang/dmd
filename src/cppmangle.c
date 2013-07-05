
// Compiler implementation of the D programming language
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
#include "mangle.h"
#include "target.h"

/* Do mangling for C++ linkage.
 * Follows Itanium C++ ABI 1.86
 * No attempt is made to support mangling of templates, operator
 * overloading, or special functions.
 *
 * So why don't we use the C++ ABI for D name mangling?
 * Because D supports a lot of things (like modules) that the C++
 * ABI has no concept of. These affect every D mangled name,
 * so nothing would be compatible anyway.
 */

ItaniumCPPMangler::ItaniumCPPMangler()
{
    buf = new OutBuffer();
}

ItaniumCPPMangler::~ItaniumCPPMangler()
{
    delete buf;
}

void ItaniumCPPMangler::visitDsymbol(Dsymbol *d)
{
    assert(!buf->size);
    buf->writestring("__Z" + !global.params.isOSX);      // "__Z" for OSX, "_Z" for other
    prefixName(d);
    buf->writeByte(0);
}

void ItaniumCPPMangler::visitDsymbol(VarDeclaration *d)
{
    assert(!buf->size);
    if (!(d->storage_class & (STCextern | STCgshared)))
    {
        d->error("C++ static non- __gshared non-extern variables not supported");
        return;
    }

    Dsymbol *p = d->toParent();
    if (p && !p->isModule()) //for example: char Namespace1::beta[6] should be mangled as "_ZN10Namespace14betaE"
    {
        buf->writestring("__ZN" + !global.params.isOSX);      // "__Z" for OSX, "_Z" for other
        prefixName(p);
        sourceName(d);
        buf->writeByte('E');
        buf->writeByte(0);
    }
    else //char beta[6] should mangle as "beta"
    {
        buf->writestring(d->ident->toChars());
    }
}

void ItaniumCPPMangler::visitDsymbol(FuncDeclaration *d)
{
    /*
    * <mangled-name> ::= _Z <encoding>
    * <encoding> ::= <function name> <bare-function-type>
    *         ::= <data name>
    *         ::= <special-name>
    */ 
    assert(!buf->size);
    buf->writestring("__Z" + !global.params.isOSX);      // "_Z" for OSX
    Dsymbol *p = d->toParent();
    if (p && !p->isModule())
    {
        buf->writeByte('N');
        if (d->type->isConst())
            buf->writeByte('K');
        prefixName(p);
        sourceName(d);
        buf->writeByte('E');
    }
    else
    {
        sourceName(d);
    }

    TypeFunction *tf = (TypeFunction *)d->type;
    assert(tf->ty == Tfunction);
    argsCppMangle(tf->parameters, tf->varargs);

    buf->writeByte(0);
}


const char *ItaniumCPPMangler::result()
{
    return (const char *)buf->extractData();
}

static void writeBase36(OutBuffer *buf, unsigned i)
{
    if (i >= 36)
    {
        writeBase36(buf, i / 36);
        i %= 36;
    }
    if (i < 10)
        buf->writeByte(i + '0');
    else if (i < 36)
        buf->writeByte(i - 10 + 'A');
    else
        assert(0);
}

int ItaniumCPPMangler::substitute(void *p)
{
    for (size_t i = 0; i < components.dim; i++)
    {
        if (p == components[i])
        {
            /* Sequence is S_, S0_, .., S9_, SA_, ..., SZ_, S10_, ...
             */
            buf->writeByte('S');
            if (i)
                writeBase36(buf, i-1);
            buf->writeByte('_');
            return 1;
        }
    }
    components.push(p);
    return 0;
}

int ItaniumCPPMangler::exist(void *p)
{
    for (size_t i = 0; i < components.dim; i++)
    {
        if (p == components[i])
        {
            return 1;
        }
    }
    return 0;
}

void ItaniumCPPMangler::store(void *p)
{
    components.push(p);
}

void ItaniumCPPMangler::sourceName(Dsymbol *s)
{
    char *name = s->ident->toChars();
    buf->printf("%d%s", strlen(name), name);
}

void ItaniumCPPMangler::prefixName(Dsymbol *s)
{
    if (!substitute(s))
    {
        Dsymbol *p = s->toParent();
        if (p && !p->isModule())
        {
            prefixName(p);
        }
        sourceName(s);
    }
}

void ItaniumCPPMangler::mangleName(Dsymbol *s)
{
    Dsymbol *p = s->toParent();
    if (p && !p->isModule())
    {
        buf->writeByte('N');
        prefixName(p);
        sourceName(s);
        buf->writeByte('E');
    }
    else
        sourceName(s);
}

/* ============= Type Encodings ============================================= */

void ItaniumCPPMangler::visitType(Type *type)
{
    type->error(Loc(), "Unsupported type %s\n", type->toChars());
    assert(0); //Assert, because this error should be handled in frontend
}

void ItaniumCPPMangler::visitType(TypeBasic *type)
{
    char c;
    char p = 0;

    /* ABI spec says:
     * v        void
     * w        wchar_t
     * b        bool
     * c        char
     * a        signed char
     * h        unsigned char
     * s        short
     * t        unsigned short
     * i        int
     * j        unsigned int
     * l        long
     * m        unsigned long
     * x        long long, __int64
     * y        unsigned long long, __int64
     * n        __int128
     * o        unsigned __int128
     * f        float
     * d        double
     * e        long double, __float80
     * g        __float128
     * z        ellipsis
     * u <source-name>  # vendor extended type
     */

    switch (type->ty)
    {
        case Tvoid:     c = 'v';        break;
        case Tint8:     c = 'a';        break;
        case Tuns8:     c = 'h';        break;
        case Tint16:    c = 's';        break;
        case Tuns16:    c = 't';        break;
        case Tint32:    c = 'i';        break;
        case Tuns32:    c = 'j';        break;
        case Tfloat32:  c = 'f';        break;
        case Tint64:    c = 'x';        break;
        case Tuns64:    c = 'y';        break;
        case Tfloat64:  c = 'd';        break;
        case Tfloat80:  c = (Target::realsize == 16) ? 'g' : 'e'; break;
        case Tbool:     c = 'b';        break;
        case Tchar:     c = 'c';        break;
        case Twchar:    c = 't';        break;
        case Tdchar:    c = 'w';        break;

        case Timaginary32: p = 'G'; c = 'f';    break;
        case Timaginary64: p = 'G'; c = 'd';    break;
        case Timaginary80: p = 'G'; c = 'e';    break;
        case Tcomplex32:   p = 'C'; c = 'f';    break;
        case Tcomplex64:   p = 'C'; c = 'd';    break;
        case Tcomplex80:   p = 'C'; c = 'e';    break;

        default:        visitType((Type *)type);  return;
    }
    if (p || type->isConst() || type->isShared())
    {
        if (substitute(type))
            return;
    }
    if (type->isShared())
        buf->writeByte('V'); //shared -> volatile

    if (type->isConst())
        buf->writeByte('K');

    if (p)
        buf->writeByte(p);

    buf->writeByte(c);
}

void ItaniumCPPMangler::visitType(TypeVector *type)
{
    if (!substitute(type))
    {
        if (type->isShared())
            buf->writeByte('V');
        if (type->isConst())
            buf->writeByte('K');
        assert(type->basetype && type->basetype->ty == Tsarray);
        assert(((TypeSArray *)type->basetype)->dim);
        buf->printf("Dv%llu_", ((TypeSArray *)type->basetype)->dim->toInteger());// -- Gnu ABI v.4
        //buf->writestring("U8__vector"); -- Gnu ABI v.3
        type->basetype->nextOf()->acceptVisitor(this);
    }
}

void ItaniumCPPMangler::visitType(TypeSArray *type)
{
    if (!substitute(type))
    {
        if (type->isShared())
            buf->writeByte('V');
        if (type->isConst())
            buf->writeByte('K');
        buf->printf("A%llu_", type->dim ? type->dim->toInteger() : 0);
        type->next->acceptVisitor(this);
    }
}

void ItaniumCPPMangler::visitType(TypePointer *type)
{
    if (!exist(type))
    {
        if (type->isShared())
            buf->writeByte('V');
        if (type->isConst())
            buf->writeByte('K');
        buf->writeByte('P');
        type->next->acceptVisitor(this);
        store(type);
    }
    else
        substitute(type);
}

void ItaniumCPPMangler::visitType(TypeReference *type)
{
    if (!exist(type))
    {
        buf->writeByte('R');
        type->next->acceptVisitor(this);
        store(type);
    }
    else
        substitute(type);
}

void ItaniumCPPMangler::visitType(TypeFunction *type)
{
   /*
     *  <function-type> ::= F [Y] <bare-function-type> E
     *  <bare-function-type> ::= <signature type>+
     *  # types are possible return type, then parameter types
     */

    /* ABI says:
        "The type of a non-static member function is considered to be different,
        for the purposes of substitution, from the type of a namespace-scope or
        static member function whose type appears similar. The types of two
        non-static member functions are considered to be different, for the
        purposes of substitution, if the functions are members of different
        classes. In other words, for the purposes of substitution, the class of
        which the function is a member is considered part of the type of
        function."

        BUG: Right now, types of functions are never merged, so our simplistic
        component matcher always finds them to be different.
        We should use Type::equals on these, and use different
        TypeFunctions for non-static member functions, and non-static
        member functions of different classes.
     */
    if (!exist(type))
    {
        buf->writeByte('F');
        if (type->linkage == LINKc)
            buf->writeByte('Y');
        Type *t = type->next;
        if (type->isref)
            t  = t->referenceTo();
        t->acceptVisitor(this);
        argsCppMangle(type->parameters, type->varargs);
        buf->writeByte('E');
        store(type);
    }
    else
        substitute(type);
}

void ItaniumCPPMangler::visitType(TypeStruct *type)
{
    if (!exist(type))
    {
        if (type->isShared())
            buf->writeByte('V');
        if (type->isConst())
            buf->writeByte('K');

        if (!substitute(type->sym))
            mangleName(type->sym);

        if (type->isShared() || type->isConst())
            store(type);
    }
    else
        substitute(type);
}

void ItaniumCPPMangler::visitType(TypeEnum *type)
{
    if (!exist(type))
    {
        if (type->isShared())
            buf->writeByte('V');
        if (type->isConst())
            buf->writeByte('K');

        if (!substitute(type->sym))
            mangleName(type->sym);

        if (type->isShared() || type->isConst())
            store(type);
    }
    else
        substitute(type);
}

void ItaniumCPPMangler::visitType(TypeClass *type)
{
    if (!substitute(type))
    {
        buf->writeByte('P');
        if (!substitute(type->sym))
        {
            if (type->isShared())
                buf->writeByte('V');
            if (type->isConst())
                buf->writeByte('K');
            mangleName(type->sym);
        }
    }
}


struct ArgsCppMangleCtx
{
    ItaniumCPPMangler *mangler;
    size_t cnt;
};

static int argsCppMangleDg(void *ctx, size_t n, Parameter *arg)
{
    ArgsCppMangleCtx *p = (ArgsCppMangleCtx *)ctx;

    Type *t = arg->type->merge2();
    if (arg->storageClass & (STCout | STCref))
        t = t->referenceTo();
    else if (arg->storageClass & STClazy)
    {   // Mangle as delegate
        Type *td = new TypeFunction(NULL, t, 0, LINKd);
        td = new TypeDelegate(td);
        t = t->merge();
    }
    if (t->ty == Tsarray)
    {   // Mangle static arrays as pointers
        t = t->pointerTo();
    }

    /* If it is a basic, enum or struct type,
     * then don't mark it const
     */
    if ((t->ty == Tenum || t->ty == Tstruct || t->ty == Tpointer || t->isTypeBasic()) && t->isConst())
        t->mutableOf()->acceptVisitor(p->mangler);
    else
        t->acceptVisitor(p->mangler);

    p->cnt++;
    return 0;
}

void ItaniumCPPMangler::argsCppMangle(Parameters *arguments, int varargs)
{
    size_t n = 0;
    if (arguments)
    {
        ArgsCppMangleCtx ctx = { this, 0 };
        Parameter::foreach(arguments, &argsCppMangleDg, &ctx);
        n = ctx.cnt;
    }
    if (varargs)
        buf->writestring("z");
    else if (!n)
        buf->writeByte('v');            // encode ( ) arguments
}

VisualCPPMangler::VisualCPPMangler()
{
    buf = new OutBuffer();
}

VisualCPPMangler::~VisualCPPMangler()
{
    delete buf;
}

void VisualCPPMangler::visitDsymbol(Dsymbol *d)
{
    assert(!buf->size);
    buf->writeByte('?');
    mangleIdent(d);
    buf->writeByte(0);
}

void VisualCPPMangler::visitDsymbol(FuncDeclaration *d)
{
    assert(!buf->size);
    assert(d);
    buf->writeByte('?');
    mangleIdent(d);

    if (d->needThis())
    {
        if (d->isVirtual() && d->vtblIndex != -1)
        {
            switch(d->protection)
            {
                case PROTprivate:
                    buf->writeByte('E');
                    break;
                case PROTprotected:
                    buf->writeByte('M');
                    break;
                default:
                    buf->writeByte('U');
                    break;
            }
        }
        else
        {
            switch(d->protection)
            {
                case PROTprivate:
                    buf->writeByte('A');
                    break;
                case PROTprotected:
                    buf->writeByte('I');
                    break;
                default:
                    buf->writeByte('Q');
                    break;
            }
        }

        if (d->isConst())
        {
            buf->writeByte('B');
        }
        else
        {
            buf->writeByte('A');
        }
    }
    else if (d->isMember2()) //static function
    {
        switch(d->protection)
        {
            case PROTprivate:
                buf->writeByte('C');
                break;
            case PROTprotected:
                buf->writeByte('K');
                break;
            default:
                buf->writeByte('S');
                break;
        }
    }
    else //top-level function
    {
        buf->writeByte('Y');
    }

    const char *args = mangleFunction((TypeFunction *)d->type, (bool)d->needThis());
    buf->writestring(args);
    buf->writeByte(0);
}

void VisualCPPMangler::visitDsymbol(VarDeclaration *d)
{
    assert(!buf->size);
    assert(d);
    if (!(d->storage_class & (STCextern | STCgshared)))
    {
        d->error("C++ static non- __gshared non-extern variables not supported");
        return;
    }
    buf->writeByte('?');
    mangleIdent(d);

    assert(!d->needThis());

    if (d->parent && d->parent->isModule()) //static member
    {
        buf->writeByte('3');
    }
    else
    {
        switch(d->protection)
        {
            case PROTprivate:
                buf->writeByte('0');
                break;
            case PROTprotected:
                buf->writeByte('1');
                break;
            default:
                buf->writeByte('2');
                break;
        }
    }

    char cv_mod = 0;
    Type *t = d->type;

    if (t->isSharedConst())
    {
        cv_mod = 'D'; //const volatile
    }
    else if (t->isShared())
    {
        cv_mod = 'C'; //volatile
    }
    else if (t->isConst())
    {
        cv_mod = 'B'; //const
    }
    else
    {
        cv_mod = 'A'; //mutable
    }

    if (t->ty != Tpointer)
        t = t->mutableOf();

    t->acceptVisitor(this);

    buf->writeByte(cv_mod);
    buf->writeByte(0);
}

const char *VisualCPPMangler::result()
{
    return (const char *)buf->extractData();
}

void VisualCPPMangler::visitType(Type *type)
{
    type->error(Loc(), "Unsupported type %s\n", type->toChars());
    assert(0); //Assert, because this error should be handled in frontend
}

void VisualCPPMangler::visitType(TypeBasic *type)
{
    //printf("VisualCPPMangler::visitType(TypeBasic); is_not_top_type = %d\n", (int)is_not_top_type);
    if (type->isConst() || type->isShared())
    {
        if (checkTypeSaved(type)) return;
    }

    if ((type->ty == Tbool)&&checkTypeSaved(type))//try to replace long name with number
    {
        return;
    }
    mangleModifier(type);
    switch (type->ty)
    {
        case Tvoid:     buf->writeByte('X');        break;
        case Tint8:     buf->writeByte('C');        break;
        case Tuns8:     buf->writeByte('E');        break;
        case Tint16:    buf->writeByte('F');        break;
        case Tuns16:    buf->writeByte('G');        break;
        case Tint32:    buf->writeByte('H');        break;
        case Tuns32:    buf->writeByte('I');        break;
        case Tfloat32:  buf->writeByte('M');        break;
        case Tint64:    buf->writestring("_J");     break;
        case Tuns64:    buf->writestring("_K");     break;
        case Tfloat64:  buf->writeByte('N');        break;
        case Tbool:     buf->writestring("_N");     break;
        case Tchar:     buf->writeByte('D');        break;
        case Twchar:    buf->writeByte('G');        break; //unsigned short

        case Tfloat80:
            if(global.params.is64bit)
                buf->writestring("_T"); //Intel long double
            else
                buf->writestring("_Z"); //DigitalMars long double
            break;

        case Tdchar:
            if(global.params.is64bit)
                buf->writestring("_W"); //Visual C++ wchar_t
            else
                buf->writestring("_Y"); //DigitalMars wchar_t
            break;

        default:        visitType((Type*)type); return;
    }
    is_not_top_type = false;
    ignore_const = false;
}

void VisualCPPMangler::visitType(TypeVector *type)
{
    //printf("VisualCPPMangler::visitType(TypeVector); is_not_top_type = %d\n", (int)is_not_top_type);
    if (checkTypeSaved(type)) return;
    buf->writestring("T__m128@@"); //may be better as __m128i or __m128d?
    is_not_top_type = false;
    ignore_const = false;
}

void VisualCPPMangler::visitType(TypeSArray *type)
{
    //printf("VisualCPPMangler::visitType(TypeSArray); is_not_top_type = %d\n", (int)is_not_top_type);
    if (checkTypeSaved(type)) return;
    //first dimension always mangled as const pointer
    buf->writeByte('Q');
    if (global.params.is64bit)
        buf->writeByte('E');
    is_not_top_type = true;
    assert(type->nextOf());
    if (type->nextOf()->ty == Tsarray)
    {
        mangleArray((TypeSArray*)type->nextOf());
    }
    else
    {
        type->nextOf()->acceptVisitor(this);
    }
}

void VisualCPPMangler::visitType(TypePointer *type)
{
    //printf("VisualCPPMangler::visitType(TypePointer); is_not_top_type = %d\n", (int)is_not_top_type);
    if (type->nextOf()->ty == Tfunction)
    {
        type->nextOf()->acceptVisitor(this);
        return;
    }

    if (checkTypeSaved(type)) return;
    mangleModifier(type);
    if (type->isSharedConst())
    {
        buf->writeByte('S'); //const volatile
    }
    else if (type->isShared())
    {
        buf->writeByte('R'); //volatile
    }
    else if (type->isConst())
    {
        buf->writeByte('Q'); //const
    }
    else
    {
        buf->writeByte('P'); //mutable
    }

    if (global.params.is64bit)
        buf->writeByte('E');
    is_not_top_type = true;
    assert(type->nextOf());
    if (type->nextOf()->ty == Tsarray)
    {
        mangleArray((TypeSArray*)type->nextOf());
    }
    else
    {
        type->nextOf()->acceptVisitor(this);
    }
}

void VisualCPPMangler::visitType(TypeReference *type)
{
    //printf("VisualCPPMangler::visitType(TypeReference); is_not_top_type = %d\n", (int)is_not_top_type);
    if (checkTypeSaved(type)) return;

    if (type->isShared())
    {
        buf->writeByte('B'); //volatile
    }
    else
    {
        buf->writeByte('A'); //mutable
    }

    is_not_top_type = true;
    assert(type->nextOf());
    if (type->nextOf()->ty == Tsarray)
    {
        mangleArray((TypeSArray*)type->nextOf());
    }
    else
    {
        type->nextOf()->acceptVisitor(this);
    }
}

void VisualCPPMangler::visitType(TypeFunction *type)
{
    //printf("VisualCPPMangler::visitType(TypeFunction); is_not_top_type = %d\n", (int)is_not_top_type);
    const char *arg = mangleFunction(type); //compute args before checking to save; args should be saved before function type
    if (checkTypeSaved(type)) return;
    buf->writeByte('6'); //pointer to function
    buf->writestring(arg);
    is_not_top_type = false;
    ignore_const = false;
}

void VisualCPPMangler::visitType(TypeStruct *type)
{
    if (checkTypeSaved(type)) return;
    //printf("VisualCPPMangler::visitType(TypeStruct); is_not_top_type = %d\n", (int)is_not_top_type);
    mangleModifier(type);
    if (type->sym->isUnionDeclaration())
        buf->writeByte('T');
    else
        buf->writeByte('U');
    mangleIdent(type->sym);
    is_not_top_type = false;
    ignore_const = false;
}

void VisualCPPMangler::visitType(TypeEnum *type)
{
    //printf("VisualCPPMangler::visitType(TypeEnum); is_not_top_type = %d\n", (int)is_not_top_type);
    if (checkTypeSaved(type)) return;
    mangleModifier(type);
    buf->writeByte('W');

    switch(type->sym->memtype->ty)
    {
        case Tchar:
        case Tint8:
            buf->writeByte('0');
            break;
        case Tuns8:
            buf->writeByte('1');
            break;
        case Tint16:
            buf->writeByte('2');
            break;
        case Tuns16:
            buf->writeByte('3');
            break;
        case Tint32:
            buf->writeByte('4');
            break;
        case Tuns32:
            buf->writeByte('5');
            break;
        case Tint64:
            buf->writeByte('6');
            break;
        case Tuns64:
            buf->writeByte('7');
            break;
        default:
            visitType((Type*)type);
            break;
    }

    mangleIdent(type->sym);
    is_not_top_type = false;
    ignore_const = false;
}

//D class mangled as pointer to C++ class
//const(Object) mangled as Object const* const
void VisualCPPMangler::visitType(TypeClass *type)
{
    //printf("VisualCPPMangler::visitType(TypeClass); is_not_top_type = %d\n", (int)is_not_top_type);
    if (checkTypeSaved(type)) return;

    if (type->isSharedConst())
    {
        buf->writeByte('S'); //const volatile
    }
    else if (type->isShared())
    {
        buf->writeByte('R'); //volatile
    }
    else if (type->isConst())
    {
        buf->writeByte('Q'); //const
    }
    else
    {
        buf->writeByte('P'); //mutable
    }

    if (global.params.is64bit)
        buf->writeByte('E');

    mangleModifier(type);

    buf->writeByte('V');

    mangleIdent(type->sym);
    is_not_top_type = false;
    ignore_const = false;
}

void VisualCPPMangler::mangleName(const char *name)
{
    for (size_t i=0; i<10; i++)
    {
        if (!saved_idents[i]) //no saved same name
        {
           saved_idents[i] = name;
           break;
        }
        if (!strcmp(saved_idents[i], name)) //ok, we've found same name. use index instead of name
        {
            buf->writeByte(i + '0');
            return;
        }
    }
    buf->writestring(name);
    buf->writeByte('@');
}

void VisualCPPMangler::mangleIdent(Dsymbol *sym)
{
    Dsymbol *p = sym;
    while (p && !p->isModule())
    {
        mangleName(p->ident->toChars());
        p = p->toParent();
    }
    buf->writeByte('@');
}

void VisualCPPMangler::mangleNumber(uint64_t num)
{
    if (!num) //0 encoded as "A@"
    {
        buf->writeByte('A');
        buf->writeByte('@');
    }
    if (num <= 10) //5 encoded as "4"
    {
        buf->writeByte(num-1 + '0');
        return;
    }

    char buff[17];
    buff[16] = 0;
    size_t i=16;
    while (num)
    {
        --i;
        buff[i] = num%16 + 'A';
        num /=16;
    }
    buf->writestring(&buff[i]);
    buf->writeByte('@');
}

bool VisualCPPMangler::checkTypeSaved(Type *type)
{
    if (is_not_top_type) return false;
    for (size_t i=0; i<10; i++)
    {
        if (!saved_types[i]) //no saved same type
        {
            printf("Save type '%s' as num %u\n", type->toChars(), i);
           saved_types[i] = type;
           return false;
        }
        if (saved_types[i]->equals(type)) //ok, we've found same type. use index instead of type
        {
            buf->writeByte(i + '0');
            is_not_top_type = false;
            ignore_const = false;
            return true;
        }
    }
    return false;
}

void VisualCPPMangler::mangleModifier(Type *type)
{
    if (ignore_const) return;
    if (type->isSharedConst())
    {
        if (is_not_top_type)
            buf->writeByte('D'); //const volatile
        else if (type->ty != Tpointer)
            buf->writestring("_Q"); //may be dmc specific
    }
    else if (type->isShared())
    {
        if (is_not_top_type)
            buf->writeByte('C'); //volatile
        else if (type->ty != Tpointer)
            buf->writestring("_P"); //may be dmc specific
    }
    else if (type->isConst())
    {
        if (is_not_top_type)
            buf->writeByte('B'); //const
        else if (type->ty != Tpointer)
            buf->writestring("_O");
    }
    else if (is_not_top_type)
        buf->writeByte('A'); //mutable
}

void VisualCPPMangler::mangleArray(TypeSArray *type)
{
    mangleModifier(type);
    size_t i=0;
    Type *cur = type;
    while (cur && cur->ty == Tsarray) //
    {
        i++;
        cur = cur->nextOf();
    }
    buf->writeByte('Y');
    mangleNumber(i); //count of dimensions
    cur = type;
    while (cur && cur->ty == Tsarray) //sizes of dimensions
    {
        TypeSArray *sa = (TypeSArray*)cur;
        mangleNumber(sa->dim ? sa->dim->toInteger() : 0);
        cur = cur->nextOf();
    }
    ignore_const = true;
    cur->acceptVisitor(this);
}

const char *VisualCPPMangler::mangleFunction(TypeFunction *type, bool needthis)
{
    OutBuffer tmpbuf;
    OutBuffer *oldbuf = buf; //save base buffer
                             //we need to save args mangling into other buffer, 
                             //because we need process arguments of function type before function type
    buf = &tmpbuf;
    //Calling convention
    switch(type->linkage)
    {
        case LINKc:
            buf->writeByte('A');
            break;
        case LINKcpp:
            if (needthis)
                buf->writeByte('E'); //thiscall
            else
                buf->writeByte('A'); //cdecl
            break;
        case LINKwindows:
            buf->writeByte('G');//stdcall
            break;
        case LINKpascal:
            buf->writeByte('C');
            break;
        default:
            visitType((Type*)type);
            break;
    }
    Type *rettype = type->next;
    if (type->isref)
        rettype = rettype->referenceTo();
    is_not_top_type = false;
    ignore_const = false;

    rettype->acceptVisitor(this);

    if (!type->parameters || !type->parameters->dim)
    {
        if (type->varargs == 1)
            buf->writeByte('Z');
        else
            buf->writeByte('X');
    }
    else
    {
        for (size_t i=0; i<type->parameters->dim; ++i)
        {
            mangleParamenter((*type->parameters)[i]);
        }
        if (type->varargs == 1)
        {
            buf->writeByte('Z');
        }
        else
        {
            buf->writeByte('@');
        }
    }

    buf->writeByte('Z');
    buf->writeByte(0);
    const char *ret = buf->extractData();
    
    buf = oldbuf; //restore base buffer
    return ret;
}

void VisualCPPMangler::mangleParamenter(Parameter *p)
{
    Type *t = p->type;
    if (p->storageClass & (STCout | STCref))
        t = t->referenceTo();
    else if (p->storageClass & STClazy)
    {   // Mangle as delegate
        Type *td = new TypeFunction(NULL, t, 0, LINKd);
        td = new TypeDelegate(td);
        t = t->merge();
    }
    is_not_top_type = false;
    ignore_const = false;
    t->acceptVisitor(this);
}
