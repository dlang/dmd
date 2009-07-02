
// Copyright (c) 1999-2004 by Digital Mars
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

#if __DMC__
#include <dos.h>
#endif

#include "mem.h"
#include "root.h"

#include "mars.h"
#include "module.h"
#include "mtype.h"
#include "id.h"
#include "debcond.h"

void getenv_setargv(const char *envvar, int *pargc, char** *pargv);

Global global;

Global::Global()
{
    mars_ext = "d";
    sym_ext  = "d";

#if _WIN32
    obj_ext  = "obj";
#elif linux
    obj_ext  = "o";
#else
#error "fix this"
#endif

    copyright = "Copyright (c) 1999-2004 by Digital Mars";
    written = "written by Walter Bright";
    version = "v0.99";
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
    char *p = loc.toChars();

    if (*p)
	printf("%s: ", p);
    mem.free(p);

    va_list ap;
    va_start(ap, format);
    printf("Error: ");
    vprintf(format, ap);
    va_end( ap );
    printf("\n");
    fflush(stdout);

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
  -d             allow deprecated features\n\
  -g             add symbolic debug info\n\
  -gt            add trace profiling hooks\n\
  -v             verbose\n\
  -O             optimize\n\
  -odobjdir      write object files to directory objdir\n\
  -offilename	 name output file to filename\n\
  -op            do not strip paths from source file\n\
  -Ipath         where to look for imports\n\
  -Llinkerflag   pass linkerflag to link\n\
  -debug         compile in debug code\n\
  -debug=level   compile in debug code <= level\n\
  -debug=ident   compile in debug code identified by ident\n\
  -inline        do function inlining\n\
  -release	 compile release version\n\
  -unittest      compile in unit tests\n\
  -version=level compile in version code >= level\n\
  -version=ident compile in version code identified by ident\n\
");
}

int main(int argc, char *argv[])
{
    int i;
    Array files;
    char *p;
    Module *m;
    int status = EXIT_SUCCESS;

    // Initialization
    Type::init();
    Id::initialize();
    Module::init();

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

    global.params.linkswitches = new Array();
    global.params.libfiles = new Array();
    global.params.objfiles = new Array();

    // Predefine version identifiers
    VersionCondition::addIdent("DigitalMars");
#if _WIN32
    VersionCondition::addIdent("Windows");
    VersionCondition::addIdent("Win32");
#endif
#if linux
    VersionCondition::addIdent("linux");
    global.params.isLinux = 1;
#endif /* linux */
    VersionCondition::addIdent("X86");
    VersionCondition::addIdent("LittleEndian");
    VersionCondition::addIdent("D_InlineAsm");

#if _WIN32
    inifile(argv[0], "sc.ini");
#endif
#if linux
    inifile(argv[0], "/etc/dmd.conf");
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
	    else if (strcmp(p + 1, "g") == 0)
		global.params.symdebug = 1;
	    else if (strcmp(p + 1, "gt") == 0)
		global.params.trace = 1;
	    else if (strcmp(p + 1, "v") == 0)
		global.params.verbose = 1;
	    else if (strcmp(p + 1, "O") == 0)
		global.params.optimize = 1;
	    else if (p[1] == 'o')
	    {
		switch (p[2])
		{
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
	    else if (strcmp(p + 1, "inline") == 0)
		global.params.useInline = 1;
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
			DebugCondition::setLevel(atoi(p + 7));
		    else if (isalpha(p[7]))
			DebugCondition::addIdent(p + 7);
		    else
			goto Lerror;
		}
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
			VersionCondition::setLevel(atoi(p + 9));
		    else if (isalpha(p[9]))
			VersionCondition::addIdent(p + 9);
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
	    else
	    {
	     Lerror:
		error("unrecognized switch '%s'",p);
		continue;

	     Lnoarg:
		error("argument expected for switch '%s'",p);
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

    if (global.params.link)
    {
	global.params.exefile = global.params.objname;
	global.params.objname = NULL;
    }
    else
    {
	if (global.params.objname && files.dim > 1)
	{
	    error("multiple source files, but only one .obj name");
	    fatal();
	}
    }

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
	    if (strcmp(ext, "o") == 0)
#else
	    if (stricmp(ext, "obj") == 0)
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

	    if (stricmp(ext, "d") == 0 || stricmp(ext, "html") == 0)
	    {
		ext--;			// skip onto '.'
		assert(*ext == '.');
		name = (char *)mem.malloc((ext - p) + 1);
		memcpy(name, p, ext - p);
		name[ext - p] = 0;		// strip extension
	    }
	    else
	    {	error("unrecognized file extension %s\n", ext);
		fatal();
	    }
	}
	else
	    name = p;
	id = new Identifier(name, 0);
	m = new Module((char *) files.data[i], id);
	modules.push(m);

	global.params.objfiles->push(m->objfile->name->str);
    }

    // Read files, parse them
    for (i = 0; i < modules.dim; i++)
    {
	m = (Module *)modules.data[i];
	if (global.params.verbose)
	    printf("parse     %s\n", m->toChars());
	m->deleteObjFile();
	m->read();
	m->parse();
    }
    if (global.errors)
	fatal();

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
	m->genobjfile();
//	m->gensymfile();
    }

    backend_term();
    if (global.errors)
	fatal();

    if (global.params.link)
	status = runLINK();

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

    env = getenv(envvar);
    if (!env)
	return;

    env = mem.strdup(env);	// create our own writable copy

    argc = *pargc;
    argv = new Array();
    argv->setDim(argc);

    for (int i = 0; i < argc; i++)
	argv->data[i] = (void *)(*pargv)[i];

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
		argv->push(env);
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


