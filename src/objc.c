
#include "objc.h"
#include "identifier.h"

#include <assert.h>
#include <stdio.h>

// Backend
#include "cc.h"
#include "dt.h"
#include "type.h"
#include "mtype.h"
#include "oper.h"
#include "global.h"
#include "mach.h"
// declaration from mach backend
extern int mach_getsegment(const char *sectname, const char *segname, int align, int flags, int flags2);


Symbol *ObjcSymbols::msgSend = NULL;
Symbol *ObjcSymbols::msgSend_stret = NULL;
Symbol *ObjcSymbols::msgSend_fpret = NULL;

Symbol *ObjcSymbols::getMsgSend(Type *ret, int hasHiddenArg)
{
    if (hasHiddenArg)
    {	if (!msgSend_stret)
            msgSend_stret = symbol_name("_objc_msgSend_stret", SCglobal, type_fake(TYhfunc));
        return msgSend_stret;
    }	
    else if (ret->isfloating())
    {	if (!msgSend_fpret)
            msgSend_fpret = symbol_name("_objc_msgSend_fpret", SCglobal, type_fake(TYnfunc));
        return msgSend_fpret;
    }
    else
    {	if (!msgSend)
            msgSend = symbol_name("_objc_msgSend", SCglobal, type_fake(TYnfunc));
        return msgSend;
    }
    assert(0);
    return NULL;
}

Symbol *ObjcSymbols::getCString(const char *str, size_t len, const char *symbolName)
{
    // create data
    dt_t *dt = NULL;
    dtnbytes(&dt, len + 1, str);

    // find segment
    static int seg = -1;
    if (seg == -1)
        seg = mach_getsegment("__cstring", "__TEXT", sizeof(size_t), S_CSTRING_LITERALS, 0);

    // create symbol
    Symbol *s;
    s = symbol_name(symbolName, SCstatic, type_allocn(TYarray, tschar));
    s->Sdt = dt;
    s->Sseg = seg;
//	outdata(s);
    return s;
}

Symbol *ObjcSymbols::getImageInfo()
{
    static Symbol *sinfo = NULL;
    if (!sinfo) {
        dt_t *dt = NULL;
        dtnzeros(&dt, 8); // all zeros means no GC

        sinfo = symbol_name("L_OBJC_IMAGE_INFO", SCstatic, type_allocn(TYarray, tschar));
        sinfo->Sdt = dt;
        sinfo->Sseg = mach_getsegment("__image_info", "__OBJC", sizeof(size_t), 0);
        outdata(sinfo);
    }
    return sinfo;
}

Symbol *ObjcSymbols::getModuleInfo()
{
    static Symbol *sinfo = NULL;
    if (!sinfo) {
        dt_t *dt = NULL;
        dtdword(&dt, 7);  // version
        dtdword(&dt, 16); // size
        dtxoff(&dt, ObjcSymbols::getCString("", 0, "L_CLASS_NAME_"), 0, TYnptr); // name
        dtdword(&dt, 0);  // symtabs

        sinfo = symbol_name("L_OBJC_MODULE_INFO", SCstatic, type_allocn(TYarray, tschar));
        sinfo->Sdt = dt;
        sinfo->Sseg = mach_getsegment("__module_info", "__OBJC", sizeof(size_t), 0);
        outdata(sinfo);
    }
    return sinfo;
}

Symbol *ObjcSymbols::getClassName(const char *s, size_t len) {
	static StringTable stringtable;
    StringValue *sv = stringtable.update(s, len);
    Symbol *sy = (Symbol *) sv->ptrvalue;
    if (!sy)
    {
        static size_t classnamecount = 0;
        char namestr[42];
        sprintf(namestr, "L_OBJC_CLASS_NAME_%lu", classnamecount++);
        sy = getCString(s, len, namestr);
        sv->ptrvalue = sy;
		classnamecount;
    }
    return sy;
}


Symbol *ObjcSymbols::getClassReference(const char *s, size_t len)
{
	static StringTable stringtable;
	StringValue *sv = stringtable.update(s, len);
    Symbol *sy = (Symbol *) sv->ptrvalue;
    if (!sy)
    {
		// create data
        dt_t *dt = NULL;
        Symbol *sclsname = getClassName(s, len);
        dtxoff(&dt, sclsname, 0, TYnptr);
	
        // find segment for class references
        static int seg = -1;
        if (seg == -1)
            seg = mach_getsegment("__cls_refs", "__OBJC", sizeof(size_t), S_LITERAL_POINTERS | S_ATTR_NO_DEAD_STRIP, 0);
        
        static size_t classrefcount = 0;
        char namestr[42];
        sprintf(namestr, "L_OBJC_CLASS_REFERENCES_%lu", classrefcount++);
        sy = symbol_name(namestr, SCstatic, type_fake(TYnptr));
        sy->Sdt = dt;
        sy->Sseg = seg;
        outdata(sy);
		
        sv->ptrvalue = sy;
    }
    return sy;
}

Symbol *ObjcSymbols::getClassReference(Identifier *ident)
{
	return getClassReference(ident->string, ident->len);
}



void ObjcSelectorBuilder::addIdentifier(Identifier *id)
{
    assert(partCount < 10);
    parts[partCount] = id;
    slen += id->len;
    partCount += 1;
}

void ObjcSelectorBuilder::addColon()
{
    slen += 1;
    colonCount += 1;
}

int ObjcSelectorBuilder::isValid()
{
    if (colonCount == 0)
        return partCount == 1;
    else
        return partCount >= 1 && partCount <= colonCount;
}

const char *ObjcSelectorBuilder::toString()
{
    char *s = (char*)malloc(slen + 1);
    size_t spos = 0;
    for (size_t i = 0; i < partCount; ++i) {
        memcpy(&s[spos], parts[i]->string, parts[i]->len);
        spos += parts[i]->len;
        s[spos] = ':';
        spos += 1;
    }
    s[slen] = '\0';
    return s;
}


// MARK: Selector

StringTable ObjcSelector::stringtable;
int ObjcSelector::incnum = 0;

ObjcSelector::ObjcSelector(const char *sv, size_t len, size_t pcount)
{
    stringvalue = sv;
    stringlen = len;
    paramCount = pcount;
    element = NULL;
}	

ObjcSelector *ObjcSelector::lookup(ObjcSelectorBuilder *builder)
{
    return lookup(builder->toString(), builder->slen, builder->colonCount);
}

ObjcSelector *ObjcSelector::lookup(const char *s, size_t len, size_t pcount)
{
    StringValue *sv = stringtable.update(s, len);
    ObjcSelector *sel = (ObjcSelector *) sv->ptrvalue;
    if (!sel)
    {
        sel = new ObjcSelector(sv->lstring.string, len, pcount);
        sv->ptrvalue = sel;
    }
    return sel;
}

ObjcSelector *ObjcSelector::create(Identifier *ident, size_t pcount)
{
    // create a selector by adding a semicolon for each parameter
    ObjcSelectorBuilder selbuilder;
    selbuilder.addIdentifier(ident);
    for (size_t i = 0; i < pcount; ++i)
        selbuilder.addColon();
    
    return lookup(&selbuilder);
}


elem *ObjcSelector::toElem()
{
    if (element == NULL)
    {
        ObjcSymbols::getImageInfo();
        ObjcSymbols::getModuleInfo();
        
        printf("selector=%s len=%lu\n", stringvalue, stringlen);
        
        static size_t selcount = 0;
        char namestr[42];
        
        // create data
        dt_t *dt = NULL;
        sprintf(namestr, "L_OBJC_METH_VAR_NAME_%lu", selcount);
        Symbol *sselname = ObjcSymbols::getCString(stringvalue, stringlen, namestr);
        dtxoff(&dt, sselname, 0, TYnptr);
        
        // find segment
        static int seg = -1;
        if (seg == -1)
            seg = mach_getsegment("__message_refs", "__OBJC", sizeof(size_t), S_LITERAL_POINTERS | S_ATTR_NO_DEAD_STRIP, 0);
        
        // create symbol
        Symbol *sselref;
        sprintf(namestr, "L_OBJC_SELECTOR_REFERENCES_%lu", selcount);
        sselref = symbol_name(namestr, SCstatic, type_fake(TYnptr));
        sselref->Sdt = dt;
        sselref->Sseg = seg;
        outdata(sselref);
        
        ++selcount;

        element = el_var(sselref);
    }
    return el_copytree(element); // not creating a copy can cause problems with optimizer
}

