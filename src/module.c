
// Copyright (c) 1999-2002 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// www.digitalmars.com
// License for redistribution is by either the Artistic License
// in artistic.txt, or the GNU General Public License in gnu.txt.
// See the included readme.txt for details.

#include "mars.h"
#include "module.h"

#define MARS 1
#include "html.h"

ClassDeclaration *Module::moduleinfo;

DsymbolTable *Module::modules;

void Module::init()
{
    modules = new DsymbolTable();
}

Module::Module(char *filename, Identifier *ident)
	: Package(ident)
{
    FileName *srcfilename;
    FileName *cfilename;
    FileName *hfilename;
    FileName *objfilename;
    FileName *symfilename;

    //printf("Module::Module(filename = '%s', ident = '%s')\n", filename, ident->toChars());
    this->arg = filename;
    md = NULL;
    errors = 0;
    members = NULL;
    isHtml = 0;
    needmoduleinfo = 0;
    insearch = 0;
    semanticdone = 0;
    decldefs = NULL;
    vmoduleinfo = NULL;
    massert = NULL;
    marray = NULL;
    sctor = NULL;
    sdtor = NULL;
    stest = NULL;
    sfilename = NULL;

    srcfilename = FileName::defaultExt(filename, global.mars_ext);
    if (!srcfilename->equalsExt(global.mars_ext))
    {
	if (srcfilename->equalsExt("html") || srcfilename->equalsExt("htm"))
	    isHtml = 1;
	else
	{   error("source file name '%s' must have .%s extension", srcfilename->toChars(), global.mars_ext);
	    fatal();
	}
    }

    char *argobj;
    if (global.params.objname)
	argobj = global.params.objname;
    else
	argobj = FileName::name(filename);
    argobj = FileName::combine(global.params.objdir, argobj);
    objfilename = FileName::forceExt(argobj, "obj");

    symfilename = FileName::forceExt(filename, global.sym_ext);

    srcfile = new File(srcfilename);
    objfile = new File(objfilename);
    symfile = new File(symfilename);
}

void Module::deleteObjFile()
{
    objfile->remove();
}

Module::~Module()
{
}

char *Module::kind()
{
    return "module";
}

Module *Module::load(Loc loc, Array *packages, Identifier *ident)
{   Module *m;
    char *filename;

    //printf("Module::load(ident = '%s')\n", ident->toChars());

    // Build module filename by turning:
    //	foo.bar.baz
    // into:
    //	foo\bar\baz
    filename = ident->toChars();
    if (packages && packages->dim)
    {
	OutBuffer buf;
	int i;

	for (i = 0; i < packages->dim; i++)
	{   Identifier *pid = (Identifier *)packages->data[i];

	    buf.writestring(pid->toChars());
#if _WIN32
	    buf.writeByte('\\');
#else
	    buf.writeByte('/');
#endif
	}
	buf.writestring(filename);
	buf.writeByte(0);
	filename = (char *)buf.extractData();
    }

    m = new Module(filename, ident);
    m->loc = loc;

    // Find the sym file
    char *s;
    s = FileName::searchPath(global.path, m->symfile->toChars(), 1);
    if (s)
	m->symfile = new File(s);

    // BUG: the sym file is actually a source file that is
    // parsed. Someday make it a real symbol table
    m->srcfile = m->symfile;
    m->read();
    m->parse();

    return m;
}

void Module::read()
{
    //printf("Module::read() file '%s'\n",srcfile->toChars());
    srcfile->readv();
}

void Module::parse()
{   char *srcname;
    unsigned char *buf;
    unsigned buflen;

    //printf("Module::parse()\n");

    srcname = srcfile->name->toChars();
    //printf("Module::parse(srcname = '%s')\n", srcname);

    buf = srcfile->buffer;
    buflen = srcfile->len;

    if (buflen >= 2)
    {
	if (buf[0] == 0xFF && buf[1] == 0xFE)
	{   // Unicode little endian (X86)
	    // Convert it to ascii, replacing wide characters with \uXXXX

	    OutBuffer *dbuf = new OutBuffer();
	    unsigned short *pu = (unsigned short *)(buf);
	    unsigned short *pumax = (unsigned short *)(buf + buflen);

	    if (buflen & 1)
	    {	error("odd length of wide char source %u", buflen);
		fatal();
	    }

	    dbuf->reserve(buflen / 2);
	    while (++pu < pumax)
	    {	unsigned u = *pu;

		if (u & ~0xFF)
		{
		    // Write as "\uXXXX"
		    dbuf->printf("\\u%04x", u);		// not too efficent
		}
		else
		    dbuf->writeByte(u);
	    }
	    dbuf->writeByte(0);
	    buf = dbuf->data;
	    buflen = dbuf->offset - 1;
	}
	else if (buf[0] == 0xFE && buf[1] == 0xFF)
	{   // Unicode big endian
	    // Convert it to ascii, replacing wide characters with \uXXXX

	    OutBuffer *dbuf = new OutBuffer();
	    unsigned short *pu = (unsigned short *)(buf);
	    unsigned short *pumax = (unsigned short *)(buf + buflen);

	    if (buflen & 1)
	    {	error("odd length of wide char source %u", buflen);
		fatal();
	    }

	    dbuf->reserve(buflen / 2);
	    while (++pu < pumax)
	    {	unsigned u = *pu;

		if (u & 0xFF)
		{
		    // Write as "\uXXXX"
		    dbuf->printf("\\u%02x%02", u & 0xFF, u >> 8); // not too efficent
		}
		else
		    dbuf->writeByte(u >> 8);
	    }
	    dbuf->writeByte(0);
	    buf = dbuf->data;
	    buflen = dbuf->offset - 1;
	}
    }

    if (isHtml)
    {
	OutBuffer *dbuf = new OutBuffer();
	Html h(srcname, buf, buflen);
	h.extractCode(dbuf);
	buf = dbuf->data;
	buflen = dbuf->offset;
    }
    Parser p(this, buf, buflen);
    members = p.parseModule();
    md = p.md;

    if (md)
	this->ident = md->id;

    // Update global list of modules
    DsymbolTable *dst = md ? Package::resolve(md->packages, &this->parent, NULL)
			   : modules;

    if (!dst->insert(this))
    {
	if (md)
	    error(loc, "is in multiple packages %s", md->toChars());
	else
	     assert(0);			// must not be multiply defined
    }
}

void Module::semantic()
{   int i;

    if (semanticdone)
	return;
    semanticdone = 1;

    // Note that modules get their own scope, from scratch.
    // This is so regardless of where in the syntax a module
    // gets imported, it is unaffected by context.
    Scope *sc = new Scope(this);	// create root scope
    //printf("Module = %p\n", sc->scopesym);

    // Add import of "object" if this module isn't "object"
    if (ident != Id::object)
    {
	Import *im = new Import(0, NULL, Id::object);
	members->shift(im);
    }

    // Add all symbols into module's symbol table
    symtab = new DsymbolTable();
    for (i = 0; i < members->dim; i++)
    {	Dsymbol *s;

	s = (Dsymbol *)members->data[i];
	s->addMember(sc->scopesym);
    }

    // Pass 1 semantic routines: do public side of the definition
    for (i = 0; i < members->dim; i++)
    {	Dsymbol *s;

	s = (Dsymbol *)members->data[i];
	s->semantic(sc);
    }
    sc->pop();
}

void Module::semantic2()
{   int i;

    if (semanticdone >= 2)
	return;
    assert(semanticdone == 1);
    semanticdone = 2;

    // Note that modules get their own scope, from scratch.
    // This is so regardless of where in the syntax a module
    // gets imported, it is unaffected by context.
    Scope sc(this);	// create root scope
    //printf("Module = %p\n", sc.scopesym);

    // Pass 2 semantic routines: do initializers and function bodies
    for (i = 0; i < members->dim; i++)
    {	Dsymbol *s;

	s = (Dsymbol *)members->data[i];
	s->semantic2(&sc);
    }
}

void Module::semantic3()
{   int i;

    if (semanticdone >= 3)
	return;
    assert(semanticdone == 2);
    semanticdone = 3;

    // Note that modules get their own scope, from scratch.
    // This is so regardless of where in the syntax a module
    // gets imported, it is unaffected by context.
    Scope sc(this);	// create root scope
    //printf("Module = %p\n", sc.scopesym);

    // Pass 3 semantic routines: do initializers and function bodies
    for (i = 0; i < members->dim; i++)
    {	Dsymbol *s;

	s = (Dsymbol *)members->data[i];
	s->semantic3(&sc);
    }
}

void Module::inlineScan()
{   int i;

    if (semanticdone >= 4)
	return;
    assert(semanticdone == 3);
    semanticdone = 4;

    // Note that modules get their own scope, from scratch.
    // This is so regardless of where in the syntax a module
    // gets imported, it is unaffected by context.
    //printf("Module = %p\n", sc.scopesym);

    for (i = 0; i < members->dim; i++)
    {	Dsymbol *s;

	s = (Dsymbol *)members->data[i];
	s->inlineScan();
    }
}

void Module::gensymfile()
{
    OutBuffer buf;
    int i;

    //printf("Module::gensymfile()\n");

    buf.printf("// Sym file generated from '%s'", srcfile->toChars());
    buf.writenl();

    for (i = 0; i < members->dim; i++)
    {
	Dsymbol *s;

	s = (Dsymbol *)members->data[i];
	s->toCBuffer(&buf);
    }

    // Transfer image to file
    symfile->setbuffer(buf.data, buf.offset);
    buf.data = NULL;

    symfile->writev();
}

/**********************************
 * Determine if we need to generate an instance of ModuleInfo
 * for this Module.
 */

int Module::needModuleInfo()
{
    return needmoduleinfo;
}

Dsymbol *Module::search(Identifier *ident)
{
    /* Since modules can be circularly referenced,
     * need to stop infinite recursive searches.
     */

    Dsymbol *s;
    if (insearch)
	s = NULL;
    else
    {
	insearch = 1;
	s = ScopeDsymbol::search(ident);
	insearch = 0;
    }
    return s;
}


/* =========================== ModuleDeclaration ===================== */

ModuleDeclaration::ModuleDeclaration(Array *packages, Identifier *id)
{
    this->packages = packages;
    this->id = id;
}

char *ModuleDeclaration::toChars()
{
    OutBuffer buf;
    int i;

    if (packages && packages->dim)
    {
	for (i = 0; i < packages->dim; i++)
	{   Identifier *pid = (Identifier *)packages->data[i];

	    buf.writestring(pid->toChars());
	    buf.writeByte('.');
	}
    }
    buf.writestring(id->toChars());
    buf.writeByte(0);
    return (char *)buf.extractData();
}

/* =========================== Package ===================== */

Package::Package(Identifier *ident)
	: ScopeDsymbol(ident)
{
}


char *Package::kind()
{
    return "package";
}


DsymbolTable *Package::resolve(Array *packages, Dsymbol **pparent, Package **ppkg)
{
    DsymbolTable *dst = Module::modules;
    Dsymbol *parent = NULL;

    if (ppkg)
	*ppkg = NULL;

    if (packages)
    {   int i;

	for (i = 0; i < packages->dim; i++)
	{   Identifier *pid = (Identifier *)packages->data[i];
	    Dsymbol *p;

	    p = dst->lookup(pid);
	    if (!p)
	    {
		p = new Package(pid);
		dst->insert(p);
		p->parent = parent;
		((ScopeDsymbol *)p)->symtab = new DsymbolTable();
	    }
	    else
	    {
		assert(dynamic_cast<Package *>(p));
		if (dynamic_cast<Module *>(p))
		{   p->error("module and package have the same name");
		    fatal();
		    break;
		}
	    }
	    parent = p;
	    dst = ((Package *)p)->symtab;
	    if (ppkg && !*ppkg)
		*ppkg = (Package *)p;
	}
    }
    if (pparent)
	*pparent = parent;
    return dst;
}
