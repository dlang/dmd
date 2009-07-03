
// Copyright (c) 1999-2006 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// www.digitalmars.com


#include	<stdio.h>
#include	<string.h>
#include	<stdlib.h>
#include	<ctype.h>

#include	"root.h"
#include	"mem.h"

#define LOG	0

char *skipspace(const char *p);

#if __GNUC__
char *strupr(char *s)
{
    char *t = s;
    
    while (*s)
    {
	*s = toupper(*s);
	s++;
    }

    return t;
}
#endif /* unix */

/*****************************
 * Read and analyze .ini file.
 * Input:
 *	argv0	program name (argv[0])
 *	inifile	.ini file name
 */

void inifile(char *argv0, char *inifile)
{
    char *path;		// need path for @P macro
    char *filename;
    OutBuffer buf;
    int i;
    int k;
    int envsection = 0;

#if LOG
    printf("inifile(argv0 = '%s', inifile = '%s')\n", argv0, inifile);
#endif
    path = FileName::path(argv0);
    if (FileName::absolute(inifile))
    {
	filename = inifile;
    }
    else
    {
	/* Look for inifile in the following sequence of places:
	 *	o current directory
	 *	o home directory
	 *	o directory off of argv0
	 *	o /etc/
	 */
	if (FileName::exists(inifile))
	{
	    filename = inifile;
	}
	else
	{
	    filename = FileName::combine(getenv("HOME"), inifile);
	    if (!FileName::exists(filename))
	    {	//mem.free(filename);
		filename = FileName::replaceName(argv0, inifile);
#if linux
		if (!FileName::exists(filename))
		{   //mem.free(filename);
		    filename = FileName::combine("/etc/", inifile);
		}
#endif
	    }
	}
    }
#if LOG
    printf("\tpath = '%s', filename = '%s'\n", path, filename);
#endif

    File file(filename);

    if (file.read())
	return;			// error reading file

    // Parse into lines
    int eof = 0;
    for (i = 0; i < file.len && !eof; i++)
    {
	int linestart = i;

	for (; i < file.len; i++)
	{
	    switch (file.buffer[i])
	    {
		case '\r':
		    break;

		case '\n':
		    // Skip if it was preceded by '\r'
		    if (i && file.buffer[i - 1] == '\r')
			goto Lskip;
		    break;

		case 0:
		case 0x1A:
		    eof = 1;
		    break;

		default:
		    continue;
	    }
	    break;
	}

	// The line is file.buffer[linestart..i]
	char *line;
	int len;
	char *p;
	char *pn;

	line = (char *)&file.buffer[linestart];
	len = i - linestart;

	buf.reset();

	// First, expand the macros.
	// Macros are bracketed by % characters.

	for (k = 0; k < len; k++)
	{
	    if (line[k] == '%')
	    {
		int j;

		for (j = k + 1; j < len; j++)
		{
		    if (line[j] == '%')
		    {
			if (j - k == 3 && memicmp(&line[k + 1], "@P", 2) == 0)
			{
			    // %@P% is special meaning the path to the .ini file
			    p = path;
			}
			else
			{   int len = j - k;
			    char tmp[10];	// big enough most of the time

			    if (len <= sizeof(tmp))
				p = tmp;
			    else
				p = (char *)alloca(len);
			    len--;
			    memcpy(p, &line[k + 1], len);
			    p[len] = 0;
			    strupr(p);
			    p = getenv(p);
			    if (!p)
				p = "";
			}
			buf.writestring(p);
			k = j;
			goto L1;
		    }
		}
	    }
	    buf.writeByte(line[k]);
	 L1:
	    ;
	}

	// Remove trailing spaces
	while (buf.offset && isspace(buf.data[buf.offset - 1]))
	    buf.offset--;

	p = buf.toChars();

	// The expanded line is in p.
	// Now parse it for meaning.

	p = skipspace(p);
	switch (*p)
	{
	    case ';':		// comment
	    case 0:		// blank
		break;

	    case '[':		// look for [Environment]
		p = skipspace(p + 1);
		for (pn = p; isalnum(*pn); pn++)
		    ;
		if (pn - p == 11 &&
		    memicmp(p, "Environment", 11) == 0 &&
		    *skipspace(pn) == ']'
		   )
		    envsection = 1;
		else
		    envsection = 0;
		break;

	    default:
		if (envsection)
		{
		    pn = p;

		    // Convert name to upper case;
		    // remove spaces bracketing =
		    for (p = pn; *p; p++)
		    {   if (islower(*p))
			    *p &= ~0x20;
			else if (isspace(*p))
			    memmove(p, p + 1, strlen(p));
			else if (*p == '=')
			{
			    p++;
			    while (isspace(*p))
				memmove(p, p + 1, strlen(p));
			    break;
			}
		    }

		    putenv(strdup(pn));
#if LOG
		    printf("\tputenv('%s')\n", pn);
		    //printf("getenv(\"TEST\") = '%s'\n",getenv("TEST"));
#endif
		}
		break;
	}

     Lskip:
	;
    }
}

/********************
 * Skip spaces.
 */

char *skipspace(const char *p)
{
    while (isspace(*p))
	p++;
    return (char *)p;
}

