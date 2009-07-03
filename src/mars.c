
// Copyright (c) 1999-2006 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// www.digitalmars.com
// License for redistribution is by either the Artistic License
// in artistic.txt, or the GNU General Public License in gnu.txt.
// See the included readme.txt for details.

#include <stdio.h>
#include <stdlib.h>
#include <ctype.h>
#include <assert.h>
#include <limits.h>

#if _WIN32
#include <windows.h>
long __cdecl __ehfilter(LPEXCEPTION_POINTERS ep);
#endif

#if __DMC__
#include <dos.h>
#endif

#if linux
#include <errno.h>
#endif

#include "mem.h"
#include "root.h"

#include "mars.h"
#include "module.h"
#include "mtype.h"
#include "id.h"
#include "cond.h"
#include "expression.h"

void getenv_setargv(const char *envvar, int *pargc, char** *pargv);

Global global;

Global::Global()
{
    mars_ext = "d";
    sym_ext  = "d";
    hdr_ext  = "di";
    doc_ext  = "html";
    ddoc_ext = "ddoc";

#if _WIN32
    obj_ext  = "obj";
#elif linux
    obj_ext  = "o";
#else
#error "fix this"
#endif

    copyright = "Copyright (c) 1999-2006 by Digital Mars";
    written = "written by Walter Bright";
    version = "v0.162";
    global.structalign = 8;

    memset(&params, 0, sizeof(Param));
}

char *Loc::toChars()
{
    OutBuffer buf;
    char *p;

    if (filename)
    {
	buf.printf("%s", filename);
    }

    if (linnum)
	buf.printf("(%d)", linnum);
    buf.writeByte(0);
    return (char *)buf.extractData();
}

Loc::Loc(Module *mod, unsigned linnum)
{
    this->linnum = linnum;
    this->filename = mod ? mod->srcfile->toChars() : NULL;
}

/**************************************
 * Print error message and exit.
 */

void error(Loc loc, const char *format, ...)
{
    if (!global.gag)
    {
	char *p = loc.toChars();

	if (*p)
	    fprintf(stdmsg, "%s: ", p);
	mem.free(p);

	va_list ap;
	va_start(ap, format);
	fprintf(stdmsg, "Error: ");
	vfprintf(stdmsg, format, ap);
	va_end( ap );
	fprintf(stdmsg, "\n");
	fflush(stdmsg);
    }
    global.errors++;
}

/***************************************
 * Call this after printing out fatal error messages to clean up and exit
 * the compiler.
 */

void fatal()
{
#if 0
    *(char *)0 = 0;
#endif
    exit(EXIT_FAILURE);
}

extern void backend_init();
extern void backend_term();

void usage()
{
    printf("Digital Mars D Compiler %s\n%s %s\n",
	global.version, global.copyright, global.written);
    printf("\
Documentation: www.digitalmars.com/d/index.html\n\
Usage:\n\
  dmd files.d ... { -switch }\n\
\n\
  files.d        D source files\n\
  -c             do not link\n\
  -cov           do code coverage analysis\n\
  -D             generate documentation\n\
  -Dddocdir      write documentation file to docdir directory\n\
  -Dffilename    write documentation file to filename\n\
  -d             allow deprecated features\n\
  -debug         compile in debug code\n\
  -debug=level   compile in debug code <= level\n\
  -debug=ident   compile in debug code identified by ident\n\
  -g             add symbolic debug info\n\
  -gc            add symbolic debug info, pretend to be C\n\
  -H             generate 'header' file\n\
  -Hdhdrdir      write 'header' file to hdrdir directory\n\
  -Hffilename    write 'header' file to filename\n\
  --help         print help\n\
  -Ipath         where to look for imports\n\
  -inline        do function inlining\n\
  -Llinkerflag   pass linkerflag to link\n\
  -nofloat       do not emit reference to floating point\n\
  -O             optimize\n\
  -o-            do not write object file\n\
  -odobjdir      write object files to directory objdir\n\
  -offilename	 name output file to filename\n\
  -op            do not strip paths from source file\n\
  -profile	 profile runtime performance of generated code\n\
  -quiet         suppress unnecessary messages\n\
  -release	 compile release version\n\
  -run srcfile args...   run resulting program, passing args\n\
  -unittest      compile in unit tests\n\
  -v             verbose\n\
  -version=level compile in version code >= level\n\
  -version=ident compile in version code identified by ident\n\
  -w             enable warnings\n\
");
}

int main(int argc, char *argv[])
{
    int i;
    Array files;
    char *p;
    Module *m;
    int status = EXIT_SUCCESS;
    int argcstart = argc;

    // Initialization
    Type::init();
    Id::initialize();
    Module::init();
    initPrecedence();

    backend_init();

#if __DMC__	// DMC unique support for response files
    if (response_expand(&argc,&argv))	// expand response files
	error("can't open response file");
#endif

    files.reserve(argc - 1);

    // Set default values
    global.params.argv0 = argv[0];
    global.params.link = 1;
    global.params.useAssert = 1;
    global.params.useInvariants = 1;
    global.params.useIn = 1;
    global.params.useOut = 1;
    global.params.useArrayBounds = 1;
    global.params.useSwitchError = 1;
    global.params.useInline = 0;
    global.params.obj = 1;

    global.params.linkswitches = new Array();
    global.params.libfiles = new Array();
    global.params.objfiles = new Array();
    global.params.ddocfiles = new Array();

    // Predefine version identifiers
    VersionCondition::addPredefinedGlobalIdent("DigitalMars");
#if _WIN32
    VersionCondition::addPredefinedGlobalIdent("Windows");
    VersionCondition::addPredefinedGlobalIdent("Win32");
#endif
#if linux
    VersionCondition::addPredefinedGlobalIdent("linux");
    global.params.isLinux = 1;
#endif /* linux */
    VersionCondition::addPredefinedGlobalIdent("X86");
    VersionCondition::addPredefinedGlobalIdent("LittleEndian");
    //VersionCondition::addPredefinedGlobalIdent("D_Bits");
    VersionCondition::addPredefinedGlobalIdent("D_InlineAsm");
    VersionCondition::addPredefinedGlobalIdent("D_InlineAsm_X86");
    VersionCondition::addPredefinedGlobalIdent("all");

#if _WIN32
    inifile(argv[0], "sc.ini");
#endif
#if linux
    inifile(argv[0], "dmd.conf");
#endif
    getenv_setargv("DFLAGS", &argc, &argv);

#if 0
    for (i = 0; i < argc; i++)
    {
	printf("argv[%d] = '%s'\n", i, argv[i]);
    }
#endif

    for (i = 1; i < argc; i++)
    {
	p = argv[i];
	if (*p == '-')
	{
	    if (strcmp(p + 1, "d") == 0)
		global.params.useDeprecated = 1;
	    else if (strcmp(p + 1, "c") == 0)
		global.params.link = 0;
	    else if (strcmp(p + 1, "cov") == 0)
		global.params.cov = 1;
	    else if (strcmp(p + 1, "fPIC") == 0)
		global.params.pic = 1;
	    else if (strcmp(p + 1, "g") == 0)
		global.params.symdebug = 1;
	    else if (strcmp(p + 1, "gc") == 0)
		global.params.symdebug = 2;
	    else if (strcmp(p + 1, "gt") == 0)
	    {	error("use -profile instead of -gt\n");
		global.params.trace = 1;
	    }
	    else if (strcmp(p + 1, "profile") == 0)
		global.params.trace = 1;
	    else if (strcmp(p + 1, "v") == 0)
		global.params.verbose = 1;
	    else if (strcmp(p + 1, "w") == 0)
		global.params.warnings = 1;
	    else if (strcmp(p + 1, "O") == 0)
		global.params.optimize = 1;
	    else if (p[1] == 'o')
	    {
		switch (p[2])
		{
		    case '-':
			global.params.obj = 0;
			break;

		    case 'd':
			if (!p[3])
			    goto Lnoarg;
			global.params.objdir = p + 3;
			break;

		    case 'f':
			if (!p[3])
			    goto Lnoarg;
			global.params.objname = p + 3;
			break;

		    case 'p':
			if (p[3])
			    goto Lerror;
			global.params.preservePaths = 1;
			break;

		    case 0:
			error("-o no longer supported, use -of or -od");
			break;

		    default:
			goto Lerror;
		}
	    }
	    else if (p[1] == 'D')
	    {	global.params.doDocComments = 1;
		switch (p[2])
		{
		    case 'd':
			if (!p[3])
			    goto Lnoarg;
			global.params.docdir = p + 3;
			break;
		    case 'f':
			if (!p[3])
			    goto Lnoarg;
			global.params.docname = p + 3;
			break;

		    case 0:
			break;

		    default:
			goto Lerror;
		}
	    }
#ifdef _DH
	    else if (p[1] == 'H')
	    {	global.params.doHdrGeneration = 1;
		switch (p[2])
		{
		    case 'd':
			if (!p[3])
			    goto Lnoarg;
			global.params.hdrdir = p + 3;
			break;

		    case 'f':
			if (!p[3])
			    goto Lnoarg;
			global.params.hdrname = p + 3;
			break;

		    case 0:
			break;

		    default:
			goto Lerror;
		}
	    }
#endif
	    else if (strcmp(p + 1, "inline") == 0)
		global.params.useInline = 1;
	    else if (strcmp(p + 1, "nofloat") == 0)
		global.params.nofloat = 1;
	    else if (strcmp(p + 1, "quiet") == 0)
		global.params.quiet = 1;
	    else if (strcmp(p + 1, "release") == 0)
		global.params.release = 1;
	    else if (strcmp(p + 1, "unittest") == 0)
		global.params.useUnitTests = 1;
	    else if (p[1] == 'I')
	    {
		if (!global.params.imppath)
		    global.params.imppath = new Array();
		global.params.imppath->push(p + 2);
	    }
	    else if (memcmp(p + 1, "debug", 5) == 0)
	    {
		// Parse:
		//	-debug
		//	-debug=number
		//	-debug=identifier
		if (p[6] == '=')
		{
		    if (isdigit(p[7]))
		    {	long level;

			errno = 0;
			level = strtol(p + 7, &p, 10);
			if (*p || errno || level > INT_MAX)
			    goto Lerror;
			DebugCondition::setGlobalLevel((int)level);
		    }
		    else if (isalpha(p[7]) || p[7] == '_')
			DebugCondition::addGlobalIdent(p + 7);
		    else
			goto Lerror;
		}
		else if (p[6])
		    goto Lerror;
		else
		    global.params.debuglevel = 1;
	    }
	    else if (memcmp(p + 1, "version", 5) == 0)
	    {
		// Parse:
		//	-version=number
		//	-version=identifier
		if (p[8] == '=')
		{
		    if (isdigit(p[9]))
		    {	long level;

			errno = 0;
			level = strtol(p + 9, &p, 10);
			if (*p || errno || level > INT_MAX)
			    goto Lerror;
			VersionCondition::setGlobalLevel((int)level);
		    }
		    else if (isalpha(p[9]) || p[9] == '_')
			VersionCondition::addGlobalIdent(p + 9);
		    else
			goto Lerror;
		}
		else
		    goto Lerror;
	    }
	    else if (strcmp(p + 1, "-b") == 0)
		global.params.debugb = 1;
	    else if (strcmp(p + 1, "-c") == 0)
		global.params.debugc = 1;
	    else if (strcmp(p + 1, "-f") == 0)
		global.params.debugf = 1;
	    else if (strcmp(p + 1, "-help") == 0)
	    {	usage();
		exit(EXIT_SUCCESS);
	    }
	    else if (strcmp(p + 1, "-r") == 0)
		global.params.debugr = 1;
	    else if (strcmp(p + 1, "-x") == 0)
		global.params.debugx = 1;
	    else if (strcmp(p + 1, "-y") == 0)
		global.params.debugy = 1;
	    else if (p[1] == 'L')
	    {
		global.params.linkswitches->push(p + 2);
	    }
	    else if (strcmp(p + 1, "run") == 0)
	    {	global.params.run = 1;
		global.params.runargs_length = ((i >= argcstart) ? argc : argcstart) - i - 1;
		if (global.params.runargs_length)
		{
		    files.push(argv[i + 1]);
		    global.params.runargs = &argv[i + 2];
		    i += global.params.runargs_length;
		    global.params.runargs_length--;
		}
		else
		{   global.params.run = 0;
		    goto Lnoarg;
		}
	    }
	    else
	    {
	     Lerror:
		error("unrecognized switch '%s'", argv[i]);
		continue;

	     Lnoarg:
		error("argument expected for switch '%s'", argv[i]);
		continue;
	    }
	}
	else
	    files.push(p);
    }
    if (global.errors)
    {
	fatal();
    }
    if (files.dim == 0)
    {	usage();
	return EXIT_FAILURE;
    }

    if (global.params.release)
    {	global.params.useInvariants = 0;
	global.params.useIn = 0;
	global.params.useOut = 0;
	global.params.useAssert = 0;
	global.params.useArrayBounds = 0;
	global.params.useSwitchError = 0;
    }

    if (global.params.run)
	global.params.quiet = 1;

    if (global.params.useUnitTests)
	global.params.useAssert = 1;

    if (!global.params.obj)
	global.params.link = 0;

    if (global.params.link)
    {
	global.params.exefile = global.params.objname;
	global.params.objname = NULL;
    }
    else if (global.params.run)
    {
	error("flags conflict with -run");
	fatal();
    }
    else
    {
	if (global.params.objname && files.dim > 1)
	{
	    error("multiple source files, but only one .obj name");
	    fatal();
	}
    }
    if (global.params.cov)
	VersionCondition::addPredefinedGlobalIdent("D_Coverage");


    //printf("%d source files\n",files.dim);

    // Build import search path
    if (global.params.imppath)
    {
	for (i = 0; i < global.params.imppath->dim; i++)
	{
	    char *path = (char *)global.params.imppath->data[i];
	    Array *a = FileName::splitPath(path);

	    if (a)
	    {
		if (!global.path)
		    global.path = new Array();
		global.path->append(a);
	    }
	}
    }

    // Create Modules
    Array modules;
    modules.reserve(files.dim);
    for (i = 0; i < files.dim; i++)
    {	Identifier *id;
	char *ext;
	char *name;

	p = (char *) files.data[i];

#if _WIN32
	// Convert / to \ so linker will work
	for (int i = 0; p[i]; i++)
	{
	    if (p[i] == '/')
		p[i] = '\\';
	}
#endif

	p = FileName::name(p);		// strip path
	ext = FileName::ext(p);
	if (ext)
	{
#if TARGET_LINUX
	    if (strcmp(ext, global.obj_ext) == 0)
#else
	    if (stricmp(ext, global.obj_ext) == 0)
#endif
	    {
		global.params.objfiles->push(files.data[i]);
		continue;
	    }

#if TARGET_LINUX
	    if (strcmp(ext, "a") == 0)
#else
	    if (stricmp(ext, "lib") == 0)
#endif
	    {
		global.params.libfiles->push(files.data[i]);
		continue;
	    }

	    if (strcmp(ext, global.ddoc_ext) == 0)
	    {
		global.params.ddocfiles->push(files.data[i]);
		continue;
	    }

#if !TARGET_LINUX
	    if (stricmp(ext, "res") == 0)
	    {
		global.params.resfile = (char *)files.data[i];
		continue;
	    }

	    if (stricmp(ext, "def") == 0)
	    {
		global.params.deffile = (char *)files.data[i];
		continue;
	    }

	    if (stricmp(ext, "exe") == 0)
	    {
		global.params.exefile = (char *)files.data[i];
		continue;
	    }
#endif

	    if (stricmp(ext, global.mars_ext) == 0 ||
		stricmp(ext, "htm") == 0 ||
		stricmp(ext, "html") == 0)
	    {
		ext--;			// skip onto '.'
		assert(*ext == '.');
		name = (char *)mem.malloc((ext - p) + 1);
		memcpy(name, p, ext - p);
		name[ext - p] = 0;		// strip extension

		if (name[0] == 0 ||
		    strcmp(name, "..") == 0 ||
		    strcmp(name, ".") == 0)
		{
		Linvalid:
		    error("invalid file name '%s'", (char *)files.data[i]);
		    fatal();
		}
	    }
	    else
	    {	error("unrecognized file extension %s\n", ext);
		fatal();
	    }
	}
	else
	{   name = p;
	    if (!*name)
		goto Linvalid;
	}

	id = new Identifier(name, 0);
	m = new Module((char *) files.data[i], id, global.params.doDocComments, global.params.doHdrGeneration);
	modules.push(m);

	global.params.objfiles->push(m->objfile->name->str);
    }

#if _WIN32
  __try
  {
#endif
    // Read files, parse them
    for (i = 0; i < modules.dim; i++)
    {
	m = (Module *)modules.data[i];
	if (global.params.verbose)
	    printf("parse     %s\n", m->toChars());
	m->deleteObjFile();
	m->read(0);
	m->parse();
	if (m->isDocFile)
	{
	    m->gendocfile();

	    // Remove m from list of modules
	    modules.remove(i);
	    i--;

	    // Remove m's object file from list of object files
	    for (int j = 0; j < global.params.objfiles->dim; j++)
	    {
		if (m->objfile->name->str == global.params.objfiles->data[j])
		{
		    global.params.objfiles->remove(j);
		    break;
		}
	    }

	    if (global.params.objfiles->dim == 0)
		global.params.link = 0;
	}
    }
    if (global.errors)
	fatal();
#ifdef _DH
    if (global.params.doHdrGeneration)
    {
	/* Generate 'header' import files.
	 * Since 'header' import files must be independent of command
	 * line switches and what else is imported, they are generated
	 * before any semantic analysis.
	 */
	for (i = 0; i < modules.dim; i++)
	{
	    m = (Module *)modules.data[i];
	    if (global.params.verbose)
		printf("import    %s\n", m->toChars());
	    m->genhdrfile();
	}
    }
    if (global.errors)
	fatal();
#endif

    // Do semantic analysis
    for (i = 0; i < modules.dim; i++)
    {
	m = (Module *)modules.data[i];
	if (global.params.verbose)
	    printf("semantic  %s\n", m->toChars());
	m->semantic();
    }
    if (global.errors)
	fatal();

    // Do pass 2 semantic analysis
    for (i = 0; i < modules.dim; i++)
    {
	m = (Module *)modules.data[i];
	if (global.params.verbose)
	    printf("semantic2 %s\n", m->toChars());
	m->semantic2();
    }
    if (global.errors)
	fatal();

    // Do pass 3 semantic analysis
    for (i = 0; i < modules.dim; i++)
    {
	m = (Module *)modules.data[i];
	if (global.params.verbose)
	    printf("semantic3 %s\n", m->toChars());
	m->semantic3();
    }
    if (global.errors)
	fatal();

    // Scan for functions to inline
    if (global.params.useInline)
    {
	/* The problem with useArrayBounds and useAssert is that the
	 * module being linked to may not have generated them, so if
	 * we inline functions from those modules, the symbols for them will
	 * not be found at link time.
	 */
	if (!global.params.useArrayBounds && !global.params.useAssert)
	{
	    // Do pass 3 semantic analysis on all imported modules,
	    // since otherwise functions in them cannot be inlined
	    for (i = 0; i < Module::amodules.dim; i++)
	    {
		m = (Module *)Module::amodules.data[i];
		if (global.params.verbose)
		    printf("semantic3 %s\n", m->toChars());
		m->semantic3();
	    }
	    if (global.errors)
		fatal();
	}

	for (i = 0; i < modules.dim; i++)
	{
	    m = (Module *)modules.data[i];
	    if (global.params.verbose)
		printf("inline scan %s\n", m->toChars());
	    m->inlineScan();
	}
    }
    if (global.errors)
	fatal();

    // Generate output files
    for (i = 0; i < modules.dim; i++)
    {
	m = (Module *)modules.data[i];
	if (global.params.verbose)
	    printf("code      %s\n", m->toChars());
	if (global.params.obj)
	    m->genobjfile();
	if (global.errors)
	    m->deleteObjFile();
	else
	{
	    if (global.params.doDocComments)
		m->gendocfile();
	}
    }
#if _WIN32
  }
  __except (__ehfilter(GetExceptionInformation()))
  {
    printf("Stack overflow\n");
    fatal();
  }
#endif
    backend_term();
    if (global.errors)
	fatal();

    if (!global.params.objfiles->dim)
    {
	if (global.params.link)
	    error("no object files to link");
    }
    else
    {
	if (global.params.link)
	    status = runLINK();

	if (global.params.run)
	{
	    if (!status)
	    {
		status = runProgram();

		/* Delete .obj files and .exe file
		 */
		for (i = 0; i < modules.dim; i++)
		{
		    m = (Module *)modules.data[i];
		    m->deleteObjFile();
		}
		deleteExeFile();
	    }
	}
    }

    return status;
}



/***********************************
 * Parse and append contents of environment variable envvar
 * to argc and argv[].
 * The string is separated into arguments, processing \ and ".
 */

void getenv_setargv(const char *envvar, int *pargc, char** *pargv)
{
    char *env;
    char *p;
    Array *argv;
    int argc;

    int wildcard;		// do wildcard expansion
    int instring;
    int slash;
    char c;
    int j;

    env = getenv(envvar);
    if (!env)
	return;

    env = mem.strdup(env);	// create our own writable copy

    argc = *pargc;
    argv = new Array();
    argv->setDim(argc);

    for (int i = 0; i < argc; i++)
	argv->data[i] = (void *)(*pargv)[i];

    j = 1;			// leave argv[0] alone
    while (1)
    {
	wildcard = 1;
	switch (*env)
	{
	    case ' ':
	    case '\t':
		env++;
		break;

	    case 0:
		goto Ldone;

	    case '"':
		wildcard = 0;
	    default:
		argv->push(env);		// append
		//argv->insert(j, env);		// insert at position j
		j++;
		argc++;
		p = env;
		slash = 0;
		instring = 0;
		c = 0;

		while (1)
		{
		    c = *env++;
		    switch (c)
		    {
			case '"':
			    p -= (slash >> 1);
			    if (slash & 1)
			    {	p--;
				goto Laddc;
			    }
			    instring ^= 1;
			    slash = 0;
			    continue;

			case ' ':
			case '\t':
			    if (instring)
				goto Laddc;
			    *p = 0;
			    //if (wildcard)
				//wildcardexpand();	// not implemented
			    break;

			case '\\':
			    slash++;
			    *p++ = c;
			    continue;

			case 0:
			    *p = 0;
			    //if (wildcard)
				//wildcardexpand();	// not implemented
			    goto Ldone;

			default:
			Laddc:
			    slash = 0;
			    *p++ = c;
			    continue;
		    }
		    break;
		}
	}
    }

Ldone:
    *pargc = argc;
    *pargv = (char **)argv->data;
}

#if _WIN32

long __cdecl __ehfilter(LPEXCEPTION_POINTERS ep)
{
    //printf("%x\n", ep->ExceptionRecord->ExceptionCode);
    if (ep->ExceptionRecord->ExceptionCode == STATUS_STACK_OVERFLOW)
    {
#ifndef DEBUG
	return EXCEPTION_EXECUTE_HANDLER;
#endif
    }
    return EXCEPTION_CONTINUE_SEARCH;
}

#endif
