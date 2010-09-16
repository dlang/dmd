
// Support functions for Objective-C integration with DMD
// Copyright (c) 2010 Michel Fortin
// All Rights Reserved
// http://michelf.com/
// License for redistribution is by either the Artistic License
// in artistic.txt, or the GNU General Public License in gnu.txt.
// See the included readme.txt for details.

#ifndef OBJC_H
#define OBJC_H

#include "root.h"
#include "mtype.h"
#include "stringtable.h"

struct Identifier;
struct Symbol;

struct ObjcSymbols
{
	static Symbol *msgSend;
	static Symbol *msgSend_stret;
	static Symbol *msgSend_fpret;

	static Symbol *getMsgSend(Type *ret, int hasHiddenArg);	
	static Symbol *getCString(const char *str, size_t len, const char *symbolName);
	static Symbol *getImageInfo();
	static Symbol *getModuleInfo();
	
	static Symbol *getClassName(const char *str, size_t len);
	static Symbol *getClassReference(const char *str, size_t len);
	static Symbol *getClassReference(Identifier *ident);
};

// Helper class to efficiently build a selector from identifiers and colon tokens
struct ObjcSelectorBuilder
{
	size_t slen;
	Identifier *parts[10];
	size_t partCount;
	int colonCount;
	
	ObjcSelectorBuilder() { partCount = 0; colonCount = 0; slen = 0; }
	void addIdentifier(Identifier *id);
	void addColon();
	int isValid();
	const char *toString();
};

struct ObjcSelector
{
	static StringTable stringtable;
	static int incnum;
	
	const char *stringvalue;
	size_t stringlen;
	size_t paramCount;
	elem *element;
	
	ObjcSelector(const char *sv, size_t len, size_t pcount);
	elem *toElem();
	
	static ObjcSelector *lookup(ObjcSelectorBuilder *builder);
	static ObjcSelector *lookup(const char *s, size_t len, size_t pcount);
	static ObjcSelector *create(Identifier *ident, size_t pcount);
};

#endif