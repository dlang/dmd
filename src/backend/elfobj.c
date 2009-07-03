// Copyright (C) ?-1998 by Symantec
// Copyright (C) 2000-2009 by Digital Mars
// All Rights Reserved
// http://www.digitalmars.com
/*
 * This source file is made available for personal use
 * only. The license is in /dmd/src/dmd/backendlicense.txt
 * For any other uses, please contact Digital Mars.
 */


// Output to ELF object files

#if SCPP || MARS
#include	<stdio.h>
#include	<string.h>
#include	<stdlib.h>

#if __sun&&__SVR4
#include	<alloca.h>
#endif

#include	"cc.h"
#include	"global.h"
#include	"code.h"
#include	"type.h"
#include	"melf.h"
#include	"outbuf.h"
#include	"filespec.h"
#include	"cv4.h"
#include	"cgcv.h"
#include	"dt.h"

#include	"aa.h"
#include	"tinfo.h"

#if ELFOBJ

#include	"dwarf.h"

//#define DEBSYM 0x7E

static Outbuffer *fobjbuf;

regm_t BYTEREGS = BYTEREGS_INIT;
regm_t ALLREGS = ALLREGS_INIT;

static char __file__[] = __FILE__;	// for tassert.h
#include	"tassert.h"

#define MATCH_SECTION 1

#define DEST_LEN (IDMAX + IDOHD + 1)
char *obj_mangle2(Symbol *s,char *dest);

#if MARS
// C++ name mangling is handled by front end
#define cpp_mangle(s) ((s)->Sident)
#endif


/******************************************
 */

symbol *GOTsym;	// global offset table reference

symbol *elfobj_getGOTsym()
{
    if (!GOTsym)
    {
	GOTsym = symbol_name("_GLOBAL_OFFSET_TABLE_",SCglobal,tspvoid);
    }
    return GOTsym;
}

static void objfile_write(FILE *fd, void *buffer, unsigned len);

STATIC char * objmodtoseg (const char *modname);
STATIC void obj_browse_flush();
STATIC void objfixupp (struct FIXUP *);
STATIC void ledata_new (int seg,targ_size_t offset);
static int obj_align(Symbol *s);
void obj_tlssections();

static IDXSYM elf_addsym(IDXSTR sym, targ_size_t val, unsigned sz,
			unsigned typ,unsigned bind,IDXSEC sec);
static long elf_align(FILE *fd, targ_size_t size, long offset);

// The object file is built is several separate pieces

// Non-repeatable section types have single output buffers
//	Pre-allocated buffers are defined for:
//		Section Names string table
//		Section Headers table 
//		Symbol table
//		String table
//		Notes section
//		Comment data

// Section Names  - String table for section names only
static Outbuffer *section_names;
#define SEC_NAMES_INIT	800
#define SEC_NAMES_INC	400

// String Table  - String table for all other names
static Outbuffer *symtab_strings;


// Section Headers
Outbuffer  *SECbuf;		// Buffer to build section table in
#define SecHdrTab ((Elf32_Shdr *)SECbuf->buf)
#define GET_SECTION(secidx) (SecHdrTab + secidx)
#define GET_SECTION_NAME(secidx) (section_names->buf + SecHdrTab[secidx].sh_name)

// The relocation for text and data seems to get lost.
// Try matching the order gcc output them
// This means defining the sections and then removing them if they are
// not used.
static int section_cnt;	// Number of sections in table

#define SHI_TEXT	1
#define SHI_RELTEXT	2
#define SHI_DATA	3
#define SHI_RELDATA	4
#define SHI_BSS		5
#define SHI_RODAT	6
#define SHI_STRINGS	7
#define SHI_SYMTAB	8
#define SHI_SECNAMES	9
#define SHI_COM		10
#define SHI_NOTE	11

IDXSYM *mapsec2sym;
#define S2S_INC 20

#define SymbolTable   ((Elf32_Sym *)SYMbuf->buf)
#define SymbolTable64 ((Elf64_Sym *)SYMbuf->buf)
static int symbol_idx;		// Number of symbols in symbol table
static int local_cnt;		// Number of symbols with STB_LOCAL

#define STI_FILE 1		// Where file symbol table entry is
#define STI_TEXT 2
#define STI_DATA 3
#define STI_BSS  4
#define STI_GCC  5		// Where "gcc2_compiled" symbol is */
#define STI_RODAT 6		// Symbol for readonly data
#define STI_NOTE 7		// Where note symbol table entry is
#define STI_COM  8

// NOTE: There seems to be a requirement that the read-only data have the
// same symbol table index and section index. Use section NOTE as a place
// holder. When a read-only string section is required, swap to NOTE.

// Symbol Table
Outbuffer  *SYMbuf;		// Buffer to build symbol table in

// Notes data (note currently used)
static Outbuffer *note_data;
static IDXSEC secidx_note;	// Final table index for note data

// Comment data	for compiler version
static Outbuffer *comment_data;
static const char compiler[] = "\0Digital Mars C/C++"
	VERSION
	;	// compiled by ...

// Each compiler segment is an elf section
// Predefined compiler segments CODE,DATA,CDATA,UDATA map to indexes
//	into SegData[]
//	An additionl index is reserved for comment data
//	New compiler segments are added to end.
//
// There doesn't seem to be any way to get reserved data space in the
//	same section as initialized data or code, so section offsets should
//	be continuous when adding data. Fix-ups anywhere withing existing data.

#define COMD UDATA+1
#define OB_SEG_SIZ	10		// initial number of segments supported
#define OB_SEG_INC	10		// increment for additional segments

#define OB_CODE_STR	100000		// initial size for code
#define OB_CODE_INC	100000		// increment for additional code
#define OB_DATA_STR	100000		// initial size for data
#define OB_DATA_INC	100000		// increment for additional data
#define OB_CDATA_STR	  1024		// initial size for data
#define OB_CDATA_INC	  1024		// increment for additional data
#define OB_COMD_STR	   256		// initial size for comments
					// increment as needed
#define OB_XTRA_STR	   250		// initial size for extra segments
#define OB_XTRA_INC	 10000		// increment size

#define MAP_SEG2SECIDX(seg) (SegData[seg]->SDshtidx)
#define MAP_SEG2SYMIDX(seg) (SegData[seg]->SDsymidx)
#define MAP_SEG2SEC(seg) (&SecHdrTab[MAP_SEG2SECIDX(seg)])
#define MAP_SEG2TYP(seg) (MAP_SEG2SEC(seg)->sh_flags & SHF_EXECINSTR ? CODE : DATA)

seg_data **SegData;
int seg_count;
int seg_max;
int seg_tlsseg = UNKNOWN;
int seg_tlsseg_bss = UNKNOWN;

int elf_getsegment2(IDXSEC shtidx, IDXSYM symidx, IDXSEC relidx);


/*******************************
 * Output a string into a string table
 * Input:
 *	strtab	=	string table for entry
 *	str	=	string to add
 *
 * Returns index into the specified string table.
 */

IDXSTR elf_addstr(Outbuffer *strtab, const char *str)
{
    //dbg_printf("elf_addstr(strtab = x%x str = '%s')\n",strtab,str);
    IDXSTR idx = strtab->size();	// remember starting offset
    strtab->writeString(str);
    //dbg_printf("\tidx %d, new size %d\n",idx,strtab->size());
    return idx;
}

/*******************************
 * Find a string in a string table
 * Input:
 *	strtab	=	string table for entry
 *	str	=	string to find
 *
 * Returns index into the specified string table or 0.
 */

static IDXSTR elf_findstr(Outbuffer *strtab, const char *str, const char *suffix)
{
    const char *ent = (char *)strtab->buf+1;
    const char *pend = ent+strtab->size() - 1;
    const char *s = str;
    const char *sx = suffix;
    int len = strlen(str);

    if (suffix)
	len += strlen(suffix);

    while(ent < pend)
    {
	if(*ent == 0)			// end of table entry
	{
	    if(*s == 0 && !sx)		// end of string - found a match
	    {
		return ent - (const char *)strtab->buf - len;
	    }
	    else			// table entry too short
	    {
		s = str;		// back to beginning of string
		sx = suffix;
		ent++;			// start of next table entry
	    }
	}
	else if (*s == 0 && sx && *sx == *ent)
	{				// matched first string
	    s = sx+1;			// switch to suffix
	    ent++;
	    sx = NULL;
	}
	else				// continue comparing
	{
	    if (*ent == *s)
	    {				// Have a match going
		ent++;
		s++;
	    }
	    else			// no match
	    {
		while(*ent != 0)	// skip to end of entry
		    ent++;
		ent++;			// start of next table entry
		s = str;		// back to beginning of string
		sx = suffix;
	    }
	}
    }
    return 0;			// never found match
}

/*******************************
 * Output a mangled string into the symbol string table
 * Input:
 *	str	=	string to add
 *
 * Returns index into the table.
 */

static IDXSTR elf_addmangled(Symbol *s)
{
    //printf("elf_addmangled(%s)\n", s->Sident);
    char dest[DEST_LEN];
    char *destr;
    const char *name;
    int len;
    IDXSTR namidx;

    namidx = symtab_strings->size();
    destr = obj_mangle2(s, dest);
    name = destr;
    if (CPP && name[0] == '_' && name[1] == '_')
    {
	if (strncmp(name,"__ct__",6) == 0)
	    name += 4;
#if 0
	switch(name[2])
	{
	    case 'c':
		if (strncmp(name,"__ct__",6) == 0)
		    name += 4;
		break;
	    case 'd':
		if (strcmp(name,"__dl__FvP") == 0)
		    name = "__builtin_delete";
		break;
	    case 'v':
		//if (strcmp(name,"__vec_delete__FvPiUIPi") == 0)
		    //name = "__builtin_vec_del";
		//else 
		//if (strcmp(name,"__vn__FPUI") == 0)
		    //name = "__builtin_vec_new";
		break;
	    case 'n':
		if (strcmp(name,"__nw__FPUI") == 0)
		    name = "__builtin_new";
		break;
	}
#endif
    }
    else if (tyfunc(s->ty()) && s->Sfunc && s->Sfunc->Fredirect)
	name = s->Sfunc->Fredirect;
    len = strlen(name);
    symtab_strings->reserve(len+1);
    strcpy((char *)symtab_strings->p,name);
    symtab_strings->setsize(namidx+len+1);
    if (destr != dest)			// if we resized result
	mem_free(destr);
    //dbg_printf("\telf_addmagled symtab_strings %s namidx %d len %d size %d\n",name, namidx,len,symtab_strings->size());
    return namidx;
}

/*******************************
 * Output a symbol into the symbol table
 * Input:
 *	stridx	=	string table index for name
 *	val	=	value associated with symbol
 *	sz	=	symbol size
 *	typ	=	symbol type
 *	bind	=	symbol binding
 *	segidx	=	segment index for segment where symbol is defined
 *
 * Returns the symbol table index for the symbol
 */

static IDXSYM elf_addsym(IDXSTR nam, targ_size_t val, unsigned sz, 
	unsigned typ, unsigned bind, IDXSEC sec)
{
    //dbg_printf("elf_addsym(nam %d, val %d, sz %x, typ %x, bind %x, sec %d\n",
	    //nam,val,sz,typ,bind,sec);
    if (I64)
    {
	if (!SYMbuf)
	{   SYMbuf = new Outbuffer(50 * sizeof(Elf64_Sym));
	    SYMbuf->reserve(100 * sizeof(Elf64_Sym));
	}
	Elf64_Sym sym;
	sym.st_name = nam;
	sym.st_value = val;
	sym.st_size = sz;
	sym.st_info = ELF_ST_INFO(bind,typ);
	sym.st_other = 0;
	sym.st_shndx = sec;
	SYMbuf->write(&sym,sizeof(sym));
    }
    else
    {
	if (!SYMbuf)
	{   SYMbuf = new Outbuffer(50 * sizeof(Elf32_Sym));
	    SYMbuf->reserve(100 * sizeof(Elf32_Sym));
	}
	Elf32_Sym sym;
	sym.st_name = nam;
	sym.st_value = val;
	sym.st_size = sz;
	sym.st_info = ELF_ST_INFO(bind,typ);
	sym.st_other = 0;
	sym.st_shndx = sec;
	SYMbuf->write(&sym,sizeof(sym));
    }
    if (bind == STB_LOCAL)
	local_cnt++;
    //dbg_printf("\treturning symbol table index %d\n",symbol_idx);
    return symbol_idx++;
}

/*******************************
 * Create a new section header table entry.
 *
 * Input:
 *	name	=	section name
 *	suffix	=	suffix for name or NULL
 *	type	=	type of data in section sh_type
 *	flags	=	attribute flags sh_flags
 * Output:
 *	section_cnt = assigned number for this section
 *		Note: Sections will be reordered on output
 */

static IDXSEC elf_newsection2(
	elf_u32_f32 name,
	elf_u32_f32 type,
	elf_u32_f32 flags,
	elf_add_f32 addr,
	elf_off_f32 offset,
	elf_u32_f32 size,
	elf_u32_f32 link,
	elf_u32_f32 info,
	elf_u32_f32 addralign,
	elf_u32_f32 entsize)
{
    Elf32_Shdr sec;

    sec.sh_name = name;
    sec.sh_type = type;
    sec.sh_flags = flags;
    sec.sh_addr = addr;
    sec.sh_offset = offset;
    sec.sh_size = size;
    sec.sh_link = link;
    sec.sh_info = info;
    sec.sh_addralign = addralign;
    sec.sh_entsize = entsize;

    if (!SECbuf)
    {	SECbuf = new Outbuffer(4 * sizeof(Elf32_Shdr));
	SECbuf->reserve(16 * sizeof(Elf32_Shdr));
    }
    SECbuf->write((void *)&sec, sizeof(sec));
    return section_cnt++;
}

static IDXSEC elf_newsection(const char *name, const char *suffix,
      	elf_u32_f32 type, elf_u32_f32 flags)
{
    Elf32_Shdr sec;

//    dbg_printf("elf_newsection(%s,%s,type %d, flags x%x)\n",
//        name?name:"",suffix?suffix:"",type,flags);

#if 1
    int namidx = elf_addstr(section_names,name); 
#else
    int namidx = section_names->size();
    section_names->writeString(name);
#endif
    					// name in section names table
    if (suffix)				// suffix - back up over NUL and
    {					//	    append suffix string
	section_names->setsize(section_names->size()-1);
	section_names->writeString(suffix);
    };
    return elf_newsection2(namidx,type,flags,0,0,0,0,0,0,0);
}

/**************************
 * Ouput read only data and generate a symbol for it.
 *
 */

symbol *elf_sym_cdata(tym_t ty,char *p,int len)
{
    symbol *s;

#if 0
    if (OPT_IS_SET(OPTfwritable_strings))
    {
	alignOffset(DATA, tysize(ty));
	s = symboldata(Doffset, ty);
	SegData[DATA]->SDbuf->write(p,len);
	s->Sseg = DATA;
	s->Soffset = Doffset;	// Remember its offset into DATA section
	Doffset += len;
    }
    else
#endif
    {
	//printf("elf_sym_cdata(ty = %x, p = %x, len = %d, CDoffset = %x)\n", ty, p, len, CDoffset);
	alignOffset(CDATA, tysize(ty));
	s = symboldata(CDoffset, ty);
	obj_bytes(CDATA, CDoffset, len, p);
	s->Sseg = CDATA;
    }
				
    s->Sfl = /*(config.flags3 & CFG3pic) ? FLgotoff :*/ FLextern;
    return s;
}

/**************************
 * Ouput read only data for data
 *
 */

int elf_data_cdata(char *p, int len, int *pseg)
{
    int oldoff;
    /*if (OPT_IS_SET(OPTfwritable_strings))
    {
	oldoff = Doffset;
	SegData[DATA]->SDbuf->reserve(len);
	SegData[DATA]->SDbuf->writen(p,len);
	Doffset += len;
	*pseg = DATA;
    }
    else*/
    {
	oldoff = CDoffset;
	SegData[CDATA]->SDbuf->reserve(len);
	SegData[CDATA]->SDbuf->writen(p,len);
	CDoffset += len;
	*pseg = CDATA;
    }
    return oldoff;
}

int elf_data_cdata(char *p, int len)
{
    int pseg;
    
    return elf_data_cdata(p, len, &pseg);
}

/******************************
 * Perform initialization that applies to all .o output files.
 *	Called before any other obj_xxx routines
 */

void obj_init(Outbuffer *objbuf, const char *filename, const char *csegname)
{
    //printf("obj_init()\n");

    cseg = CODE;
    fobjbuf = objbuf;
    
    mapsec2sym = NULL;
    note_data = NULL;
    secidx_note = 0;
    comment_data = NULL;
    seg_tlsseg = UNKNOWN;
    seg_tlsseg_bss = UNKNOWN;
    GOTsym = NULL;

    // Initialize buffers

    if (symtab_strings)
	symtab_strings->setsize(1);
    else
    {	symtab_strings = new Outbuffer(1024);
	symtab_strings->reserve(2048);
	symtab_strings->writeByte(0);
    }

    static char section_names_init[] =
      "\0.symtab\0.strtab\0.shstrtab\0.text\0.data\0.bss\0.note\0\
.comment\0.rel.text\0.rel.data\0.rodata";
    #define SEC_NAMIDX_NONE	0
    #define SEC_NAMIDX_SYMS	1	// .symtab
    #define SEC_NAMIDX_STRS	9	// .strtab
    #define SEC_NAMIDX_SECS	17	// .shstrtab
    #define SEC_NAMIDX_TEXT	27	// .text
    #define SEC_NAMIDX_DATA	33	// .data
    #define SEC_NAMIDX_BSS	39	// .bss
    #define SEC_NAMIDX_NOTE	44	// .note
    #define SEC_NAMIDX_COM	50	// .comment
    #define SEC_NAMIDX_TEXTREL	59	// .rel.text
    #define SEC_NAMIDX_DATAREL  69	// .rel.data
    #define SEC_NAMIDX_RODATA   79	// .rodata

    if (section_names)
	section_names->setsize(sizeof(section_names_init));
    else
    {	section_names = new Outbuffer(512);
	section_names->reserve(1024);
	section_names->writen(section_names_init, sizeof(section_names_init));
    }

    if (SECbuf)
	SECbuf->setsize(0);
    section_cnt = 0;

    // name,type,flags,addr,offset,size,link,info,addralign,entsize
    elf_newsection2(0,		     SHT_NULL,   0,			0,0,0,0,0, 0,0);
    elf_newsection2(SEC_NAMIDX_TEXT,SHT_PROGDEF,SHF_ALLOC|SHF_EXECINSTR,0,0,0,0,0, 16,0);
    elf_newsection2(SEC_NAMIDX_TEXTREL,SHT_REL, 0,0,0,0,SHI_SYMTAB,      SHI_TEXT,4,8);
    elf_newsection2(SEC_NAMIDX_DATA,SHT_PROGDEF,SHF_ALLOC|SHF_WRITE,   0,0,0,0,0, 4,0);
    elf_newsection2(SEC_NAMIDX_DATAREL,SHT_REL, 0,0,0,0,SHI_SYMTAB,      SHI_DATA,4,8);
    elf_newsection2(SEC_NAMIDX_BSS, SHT_NOBITS,SHF_ALLOC|SHF_WRITE,   0,0,0,0,0, 32,0);
    elf_newsection2(SEC_NAMIDX_RODATA,SHT_PROGDEF,SHF_ALLOC,           0,0,0,0,0, 1,0);
    elf_newsection2(SEC_NAMIDX_STRS,SHT_STRTAB, 0,			0,0,0,0,0, 1,0);
    elf_newsection2(SEC_NAMIDX_SYMS,SHT_SYMTAB, 0,			0,0,0,0,0, 4,0);
    elf_newsection2(SEC_NAMIDX_SECS,SHT_STRTAB, 0,			0,0,0,0,0, 1,0);
    elf_newsection2(SEC_NAMIDX_COM, SHT_PROGDEF,0,			0,0,0,0,0, 1,0);
    elf_newsection2(SEC_NAMIDX_NOTE,SHT_NOTE,   0,			0,0,0,0,0, 1,0);


    if (SYMbuf)
	SYMbuf->setsize(0);
    symbol_idx = 0;
    local_cnt = 0;
    // The symbols that every object file has
    elf_addsym(0, 0, 0, STT_NOTYPE,  STB_LOCAL, 0);
    elf_addsym(0, 0, 0, STT_FILE,    STB_LOCAL, SHT_ABS);	// STI_FILE
    elf_addsym(0, 0, 0, STT_SECTION, STB_LOCAL, SHI_TEXT);	// STI_TEXT
    elf_addsym(0, 0, 0, STT_SECTION, STB_LOCAL, SHI_DATA);	// STI_DATA
    elf_addsym(0, 0, 0, STT_SECTION, STB_LOCAL, SHI_BSS);	// STI_BSS
    elf_addsym(0, 0, 0, STT_NOTYPE,  STB_LOCAL, SHI_TEXT);	// STI_GCC
    elf_addsym(0, 0, 0, STT_SECTION, STB_LOCAL, SHI_RODAT);	// STI_RODAT
    elf_addsym(0, 0, 0, STT_SECTION, STB_LOCAL, SHI_NOTE);	// STI_NOTE
    elf_addsym(0, 0, 0, STT_SECTION, STB_LOCAL, SHI_COM);	// STI_COM

    // Initialize output buffers for CODE, DATA and COMMENTS
    //	    (NOTE not supported, BSS not required)

    seg_count = 0;

    elf_getsegment2(SHI_TEXT, STI_TEXT, SHI_RELTEXT);
    assert(SegData[CODE]->SDseg == CODE);

    elf_getsegment2(SHI_DATA, STI_DATA, SHI_RELDATA);
    assert(SegData[DATA]->SDseg == DATA);

    elf_getsegment2(SHI_RODAT, STI_RODAT, 0);
    assert(SegData[CDATA]->SDseg == CDATA);

    elf_getsegment2(SHI_BSS, STI_BSS, 0);
    assert(SegData[UDATA]->SDseg == UDATA);

    elf_getsegment2(SHI_COM, STI_COM, 0);
    assert(SegData[COMD]->SDseg == COMD);

    if (config.fulltypes)
	dwarf_initfile(filename);
}

/**************************
 * Initialize the start of object output for this particular .o file.
 *
 * Input:
 *	filename:	Name of source file
 *	csegname:	User specified default code segment name
 */

void obj_initfile(const char *filename, const char *csegname, const char *modname)
{
    //dbg_printf("obj_initfile(filename = %s, modname = %s)\n",filename,modname);

    IDXSTR name = elf_addstr(symtab_strings, filename);
    if (I64)
	SymbolTable64[STI_FILE].st_name = name;
    else
	SymbolTable[STI_FILE].st_name = name;

#if 0
    // compiler flag for linker
    if (I64)
	SymbolTable64[STI_GCC].st_name = elf_addstr(symtab_strings,"gcc2_compiled.");
    else
	SymbolTable[STI_GCC].st_name = elf_addstr(symtab_strings,"gcc2_compiled.");
#endif

    if (csegname && *csegname && strcmp(csegname,".text"))
    {	// Define new section and make it the default for cseg segment
	// NOTE: cseg is initialized to CODE
	IDXSEC newsecidx;
	Elf32_Shdr *newtextsec;
	IDXSYM newsymidx;
	SegData[cseg]->SDshtidx = newsecidx =
	    elf_newsection(csegname,0,SHT_PROGDEF,SHF_ALLOC|SHF_EXECINSTR);
	newtextsec = &SecHdrTab[newsecidx];
	newtextsec->sh_addralign = 4;
	SegData[cseg]->SDsymidx = 
	    elf_addsym(0, 0, 0, STT_SECTION, STB_LOCAL, newsecidx);
    }
    if (config.fulltypes)
	dwarf_initmodule(filename, modname);
}

/***************************
 * Renumber symbols so they are
 * ordered as locals, weak and then global
 * Returns:
 *	sorted symbol table, caller must free with util_free()
 */

void *elf_renumbersyms()
{   void *symtab;
    int nextlocal = 0;
    int nextglobal = local_cnt;

    SYMIDX *sym_map = (SYMIDX *)util_malloc(sizeof(SYMIDX),symbol_idx);

    if (I64)
    {
	Elf64_Sym *oldsymtab = (Elf64_Sym *)SYMbuf->buf;
	Elf64_Sym *symtabend = oldsymtab+symbol_idx;

	symtab = util_malloc(sizeof(Elf64_Sym),symbol_idx);

	Elf64_Sym *sl = (Elf64_Sym *)symtab;
	Elf64_Sym *sg = sl + local_cnt;

	int old_idx = 0;
	for(Elf64_Sym *s = oldsymtab; s != symtabend; s++)
	{   // reorder symbol and map new #s to old
	    int bind = ELF_ST_BIND(s->st_info);
	    if (bind == STB_LOCAL)
	    {
		*sl++ = *s;
		sym_map[old_idx] = nextlocal++;
	    }
	    else
	    {
		*sg++ = *s;
		sym_map[old_idx] = nextglobal++;
	    }
	    old_idx++;
	}
    }
    else
    {
	Elf32_Sym *oldsymtab = (Elf32_Sym *)SYMbuf->buf;
	Elf32_Sym *symtabend = oldsymtab+symbol_idx;

	symtab = util_malloc(sizeof(Elf32_Sym),symbol_idx);

	Elf32_Sym *sl = (Elf32_Sym *)symtab;
	Elf32_Sym *sg = sl + local_cnt;

	int old_idx = 0;
	for(Elf32_Sym *s = oldsymtab; s != symtabend; s++)
	{   // reorder symbol and map new #s to old
	    int bind = ELF_ST_BIND(s->st_info);
	    if (bind == STB_LOCAL)
	    {
		*sl++ = *s;
		sym_map[old_idx] = nextlocal++;
	    }
	    else
	    {
		*sg++ = *s;
		sym_map[old_idx] = nextglobal++;
	    }
	    old_idx++;
	}
    }

    // Renumber the relocations
    for (int i = 1; i <= seg_count; i++)
    {				// Map indicies in the segment table
	seg_data *pseg = SegData[i];
	pseg->SDsymidx = sym_map[pseg->SDsymidx];
	if (pseg->SDrel)
	{
	    if (I64)
	    {
		Elf64_Rel *rel = (Elf64_Rel *) pseg->SDrel->buf;
		for (int r = 0; r < pseg->SDrelcnt; r++)
		{
		    unsigned t = ELF64_R_TYPE(rel->r_info);
		    unsigned si = ELF64_R_SYM(rel->r_info);
		    rel->r_info = ELF64_R_INFO(sym_map[si],t);
		    rel++;
		}
	    }
	    else
	    {
		Elf32_Rel *rel = (Elf32_Rel *) pseg->SDrel->buf;
		assert(pseg->SDrelcnt == pseg->SDrel->size() / sizeof(Elf32_Rel));
		for (int r = 0; r < pseg->SDrelcnt; r++)
		{
		    unsigned t = ELF32_R_TYPE(rel->r_info);
		    unsigned si = ELF32_R_IDX(rel->r_info);
		    rel->r_info = ELF32_R_INFO(sym_map[si],t);
		    rel++;
		}
	    }
	}
    };

    return symtab;
}
	    
		
/***************************
 * Fixup and terminate object file.
 */

void obj_termfile()
{
    //dbg_printf("obj_termfile\n");
    if (configv.addlinenumbers)
    {
	dwarf_termmodule();
    }
}

/*********************************
 * Terminate package.
 */

void obj_term()
{
    //printf("obj_term()\n");
#if SCPP
    if (!errcnt)
#endif
    {
        outfixlist();		// backpatches
    }

    if (configv.addlinenumbers)
    {
	dwarf_termfile();
    }

#if SCPP
    if (errcnt)
	return;
#endif

    // Write out the bytes for the header
    static const char elf_string32[EI_NIDENT] =
    {
	ELFMAG0,ELFMAG1,ELFMAG2,ELFMAG3,
	ELFCLASS32,		// EI_CLASS
	ELFDATA2LSB,	// EI_DATA
	EV_CURRENT,		// EI_VERSION
	ELFOSABI_LINUX,0,	// EI_OSABI,EI_ABIVERSION
	0,0,0,0,0,0,0
    };
    static const char elf_string64[EI_NIDENT] =
    {
	ELFMAG0,ELFMAG1,ELFMAG2,ELFMAG3,
	ELFCLASS64,		// EI_CLASS
	ELFDATA2LSB,	// EI_DATA
	EV_CURRENT,		// EI_VERSION
	ELFOSABI_LINUX,0,	// EI_OSABI,EI_ABIVERSION
	0,0,0,0,0,0,0
    };
    fobjbuf->write(I64 ? elf_string64 : elf_string32, EI_NIDENT);

    long foffset;
    Elf32_Shdr *sechdr;
    seg_data *seg;
    void *symtab = elf_renumbersyms();
    FILE *fd = NULL;

    // Output the ELF Header
    // The section header is build in the static variable elf_header
    static Elf64_Ehdr elf_header =
    {
	ET_REL,				// e_type
	EM_X86_64,			// e_machine
	EV_CURRENT,			// e_version
	0,				// e_entry
	0,				// e_phoff
	0,				// e_shoff
	0,				// e_flags
	sizeof(Elf64_Ehdr),		// e_ehsize
	sizeof(Elf64_Phdr),		// e_phentsize
	0,				// e_phnum
	sizeof(Elf64_Shdr),		// e_shentsize
	0,				// e_shnum
	0				// e_shstrndx
    };
    int hdrsize = I64 ? sizeof(Elf64_Ehdr) : sizeof(Elf32_Hdr);

    elf_header.e_shnum = section_cnt;
    elf_header.e_shstrndx = SHI_SECNAMES;
    fobjbuf->writezeros(hdrsize);

	    // Walk through sections determining size and file offsets
	    // Sections will be output in the following order
	    //	Null segment
	    //	For each Code/Data Segment
	    //	    code/data to load
	    //	    relocations without addens
	    //	.bss
	    //	notes
	    //	comments
	    //	section names table
	    //	symbol table
	    //	strings table

    foffset = EI_NIDENT + hdrsize; 	// start after header 
				    // section header table at end

    //
    // First output individual section data associate with program
    //	code and data
    //
    //printf("Setup offsets and sizes foffset %d\n\tsection_cnt %d, seg_count %d\n",foffset,section_cnt,seg_count);
    for (int i=1; i<= seg_count; i++)
    {
	seg = SegData[i]; 
	sechdr = MAP_SEG2SEC(i);	// corresponding section
	foffset = elf_align(fd,sechdr->sh_addralign,foffset);
	if (i == UDATA) // 0, BSS never allocated
	{   // but foffset as if it has
	    sechdr->sh_offset = foffset;
	    sechdr->sh_size = seg->SDoffset;
				// accumulated size	
	    continue;
	}
	else if (sechdr->sh_type == SHT_NOBITS) // .tbss never allocated
	{
	    sechdr->sh_offset = foffset;
	    sechdr->sh_size = seg->SDoffset;
				// accumulated size	
	    continue;
	}
	else if (!seg->SDbuf)
	    continue;		// For others leave sh_offset as 0

	sechdr->sh_offset = foffset;
	//printf("\tsection name %d,",sechdr->sh_name);
	if (seg->SDbuf && seg->SDbuf->size())
	{
	    //printf(" - size %d\n",seg->SDbuf->size());
	    sechdr->sh_size = seg->SDbuf->size();
	    fobjbuf->write(seg->SDbuf->buf, sechdr->sh_size);
	    foffset += sechdr->sh_size;
	}
	//printf(" assigned offset %d, size %d\n",foffset,sechdr->sh_size);
    }

    //
    // Next output any notes or comments
    //
    if (note_data)
    {
	sechdr = &SecHdrTab[secidx_note];		// Notes
	sechdr->sh_size = note_data->size();
	sechdr->sh_offset = foffset;
	fobjbuf->write(note_data->buf, sechdr->sh_size);
	foffset += sechdr->sh_size;
    }

    if (comment_data)
    {
	sechdr = &SecHdrTab[SHI_COM];		// Comments
	sechdr->sh_size = comment_data->size();
	sechdr->sh_offset = foffset;
	fobjbuf->write(comment_data->buf, sechdr->sh_size);
	foffset += sechdr->sh_size;
    }

    //
    // Then output string table for section names
    //
    sechdr = &SecHdrTab[SHI_SECNAMES];	// Section Names
    sechdr->sh_size = section_names->size();
    sechdr->sh_offset = foffset;
    //dbg_printf("section names offset %d\n",foffset);
    fobjbuf->write(section_names->buf, sechdr->sh_size);
    foffset += sechdr->sh_size;

    //
    // Symbol table and string table for symbols next
    //
    //dbg_printf("output symbol table size %d\n",SYMbuf->size());
    sechdr = &SecHdrTab[SHI_SYMTAB];	// Symbol Table
    sechdr->sh_size = SYMbuf->size();
    sechdr->sh_entsize = I64 ? sizeof(Elf64_Sym) : sizeof(Elf32_Sym);
    sechdr->sh_link = SHI_STRINGS;
    sechdr->sh_info = local_cnt;
    foffset = elf_align(fd,4,foffset);
    sechdr->sh_offset = foffset;
    fobjbuf->write(symtab, sechdr->sh_size);
    foffset += sechdr->sh_size;
    util_free(symtab);

    //dbg_printf("output section strings size 0x%x,offset 0x%x\n",symtab_strings->size(),foffset);
    sechdr = &SecHdrTab[SHI_STRINGS];	// Symbol Strings
    sechdr->sh_size = symtab_strings->size();
    sechdr->sh_offset = foffset;
    fobjbuf->write(symtab_strings->buf, sechdr->sh_size);
    foffset += sechdr->sh_size;

    //
    // Now the relocation data for program code and data sections
    //
    foffset = elf_align(fd,4,foffset);
    //dbg_printf("output relocations size 0x%x, foffset 0x%x\n",section_names->size(),foffset);
    for (int i=1; i<= seg_count; i++)
    {
	seg = SegData[i]; 
	if (!seg->SDbuf)
	    continue;		// 0, BSS never allocated
	if (seg->SDrel && seg->SDrel->size())
	{
	    assert(seg->SDrelidx);
	    sechdr = &SecHdrTab[seg->SDrelidx];
	    sechdr->sh_size = seg->SDrel->size();
	    sechdr->sh_offset = foffset;
	    assert(seg->SDrelcnt == seg->SDrel->size() / sizeof(Elf32_Rel));
	    fobjbuf->write(seg->SDrel->buf, sechdr->sh_size);
	    foffset += sechdr->sh_size;
	}
    }

    //
    // Finish off with the section header table
    //
    elf_header.e_shoff = foffset;	// remember location in elf header
    //dbg_printf("output section header table\n");

    // Output the completed Section Header Table
    if (I64)
    {	// Translate section headers to 64 bits
	int sz = section_cnt * sizeof(Elf64_Shdr);
	fobjbuf->reserve(sz);
	for (int i = 0; i < section_cnt; i++)
	{
	    Elf32_Shdr *p = SecHdrTab + i;
	    Elf64_Shdr s;
	    s.sh_name      = p->sh_name;
	    s.sh_type      = p->sh_type;
	    s.sh_flags     = p->sh_flags;
	    s.sh_addr      = p->sh_addr;
	    s.sh_offset    = p->sh_offset;
	    s.sh_size      = p->sh_size;
	    s.sh_link      = p->sh_link;
	    s.sh_info      = p->sh_info;
	    s.sh_addralign = p->sh_addralign;
	    s.sh_entsize   = p->sh_entsize;
	    fobjbuf->write(&s, sizeof(s));
	}
	foffset += sz;
    }
    else
    {
	fobjbuf->write(SecHdrTab, section_cnt * sizeof(Elf32_Shdr));
	foffset += section_cnt * sizeof(Elf32_Shdr);
    }

    //
    // Now that we have correct offset to section header table, e_shoff,
    //	go back and re-output the elf header
    //
    fobjbuf->position(EI_NIDENT, hdrsize);
    if (I64)
    {
	fobjbuf->write(&elf_header, hdrsize);
    }
    else
    {	Elf32_Hdr h;
	// Transfer to 32 bit header
	h.e_type      = elf_header.e_type;
	h.e_machine   = EM_386;
	h.e_version   = elf_header.e_version;
	h.e_entry     = elf_header.e_entry;
	h.e_phoff     = elf_header.e_phoff;
	h.e_shoff     = elf_header.e_shoff;
	h.e_flags     = elf_header.e_flags;
	h.e_ehsize    = sizeof(Elf32_Hdr);
	h.e_phentsize = sizeof(elf_pht);
	h.e_phnum     = elf_header.e_phnum;
	h.e_shentsize = sizeof(Elf32_Shdr);
	h.e_shnum     = elf_header.e_shnum;
	h.e_shstrndx  = elf_header.e_shstrndx;
	fobjbuf->write(&h, hdrsize);
    }
    fobjbuf->position(foffset, 0);
    fobjbuf->flush();
}

/*****************************
 * Line number support.
 */

/***************************
 * Record file and line number at segment and offset.
 * The actual .debug_line segment is put out by dwarf_termfile().
 * Input:
 *	cseg	current code segment
 */

void objlinnum(Srcpos srcpos, targ_size_t offset)
{
    unsigned linnum = srcpos.Slinnum;
    if (linnum == 0)
	return;

#if 0
#if MARS
    printf("objlinnum(cseg=%d, filename=%s linnum=%u, offset=x%lx)\n",
	cseg,srcpos.Sfilename ? srcpos.Sfilename : "null",linnum,offset);
#endif
#if SCPP
    printf("objlinnum(cseg=%d, filptr=%p linnum=%u, offset=x%lx)\n",
	cseg,srcpos.Sfilptr ? *srcpos.Sfilptr : 0,linnum,offset);
    if (srcpos.Sfilptr)
    {
	Sfile *sf = *srcpos.Sfilptr;
	printf("filename = %s\n", sf ? sf->SFname : "null");
    }
#endif
#endif

#if MARS
    if (!srcpos.Sfilename)
	return;
#endif
#if SCPP
    Sfile *sf;
    if (srcpos.Sfilptr)
    {	sfile_debug(&srcpos_sfile(srcpos));
	sf = *srcpos.Sfilptr;
    }
    else
	return;
#endif

    size_t i;
    seg_data *seg = SegData[cseg];

    // Find entry i in SDlinnum_data[] that corresponds to srcpos filename
    for (i = 0; 1; i++)
    {
	if (i == seg->SDlinnum_count)
	{   // Create new entry
	    if (seg->SDlinnum_count == seg->SDlinnum_max)
	    {	// Enlarge array
		unsigned newmax = seg->SDlinnum_max * 2 + 1;
		//printf("realloc %d\n", newmax * sizeof(linnum_data));
		seg->SDlinnum_data = (linnum_data *)mem_realloc(
		    seg->SDlinnum_data, newmax * sizeof(linnum_data));
		memset(seg->SDlinnum_data + seg->SDlinnum_max, 0,
		    (newmax - seg->SDlinnum_max) * sizeof(linnum_data));
		seg->SDlinnum_max = newmax;
	    }
	    seg->SDlinnum_count++;
#if MARS
	    seg->SDlinnum_data[i].filename = srcpos.Sfilename;
#endif
#if SCPP
	    seg->SDlinnum_data[i].filptr = sf;
#endif
	    break;
	}
#if MARS
	if (seg->SDlinnum_data[i].filename == srcpos.Sfilename)
#endif
#if SCPP
	if (seg->SDlinnum_data[i].filptr == sf)
#endif
	    break;
    }

    linnum_data *ld = &seg->SDlinnum_data[i];
//    printf("i = %d, ld = x%x\n", i, ld);
    if (ld->linoff_count == ld->linoff_max)
    {
	if (!ld->linoff_max)
	    ld->linoff_max = 8;
	ld->linoff_max *= 2;
	ld->linoff = (unsigned (*)[2])mem_realloc(ld->linoff, ld->linoff_max * sizeof(unsigned) * 2);
    }
    ld->linoff[ld->linoff_count][0] = srcpos.Slinnum;
    ld->linoff[ld->linoff_count][1] = offset;
    ld->linoff_count++;
}


/*******************************
 * Set start address
 */

void obj_startaddress(Symbol *s)
{
    //dbg_printf("obj_startaddress(Symbol *%s)\n",s->Sident);
    //obj.startaddress = s;
}

/*******************************
 * Output library name.
 * Output:
 */

void obj_includelib(const char *name)
{
    //dbg_printf("obj_includelib(name *%s)\n",name);
}

/**************************
 * Embed string in executable.
 */

void obj_exestr(const char *p)
{
    //dbg_printf("obj_exestr(char *%s)\n",p);
}

/**************************
 * Embed string in obj.
 */

void obj_user(const char *p)
{
    //dbg_printf("obj_user(char *%s)\n",p);
}

/*******************************
 * Output a weak extern record.
 */

void obj_wkext(Symbol *s1,Symbol *s2)
{
    //dbg_printf("obj_wkext(Symbol *%s,Symbol *s2)\n",s1->Sident,s2->Sident);
#if 0
    char buffer[2+2+2];
    int i;

    buffer[0] = 0x80;
    buffer[1] = 0xA8;
    i = 2;
    i += insidx(&buffer[2],s1->Sxtrnnum);
    i += insidx(&buffer[i],s2->Sxtrnnum);
    objrecord(COMENT,buffer,i);
#endif
}

/*******************************
 * Output file name record.
 *
 * Currently assumes that obj_filename will not be called
 *	twice for the same file.
 */

void obj_filename(const char *modname)
{   unsigned strtab_idx;
    unsigned symtab_idx;

    //dbg_printf("obj_filename(char *%s)\n",modname);
    strtab_idx = elf_addstr(symtab_strings,modname);
    elf_addsym(strtab_idx,0,0,STT_FILE,STB_LOCAL,SHT_ABS);
}

/*******************************
 * Embed compiler version in .obj file.
 */

void obj_compiler()
{
    //dbg_printf("obj_compiler\n");
    comment_data = new Outbuffer();
    comment_data->write(compiler,sizeof(compiler));
    //dbg_printf("Comment data size %d\n",comment_data->size());
}

#if 0
/********************************
 * Convert module name to code segment name.
 * Output:
 *	mem_malloc'd code seg name
 */

STATIC char * objmodtoseg(const char *modname)
{   char *csegname = NULL;

    if (LARGECODE)		// if need to add in module name
    {	int i;
	char *m;
	static const char suffix[] = "_TEXT";

	// Prepend the module name to the beginning of the _TEXT
	m = filespecgetroot(filespecname(modname));
	strupr(m);
	i = strlen(m);
	csegname = mem_malloc(i + sizeof(suffix));
	strcpy(csegname,m);
	strcat(csegname,suffix);
	mem_free(m);
    }
    return csegname;
}
#endif

//#if NEWSTATICDTOR

/**************************************
 * Symbol is the function that calls the static constructors.
 * Put a pointer to it into a special segment that the startup code
 * looks at.
 * Input:
 *	s	static constructor function
 *	dtor	!=0 if leave space for static destructor
 *	seg	1:	user
 *		2:	lib
 *		3:	compiler
 */

void obj_staticctor(Symbol *s,int dtor,int none)
{
// Static constructors and destructors
    IDXSEC seg;
    Outbuffer *buf;

    //dbg_printf("obj_staticctor(%s) offset %x\n",s->Sident,s->Soffset);
    //symbol_print(s);
    s->Sseg = seg = 
	elf_getsegment(".ctors", NULL, SHT_PROGDEF, SHF_ALLOC|SHF_WRITE, 4);
    buf = SegData[seg]->SDbuf;
    if (I64)
	buf->write64(s->Soffset);
    else
	buf->write32(s->Soffset);
    elf_addrel(seg,SegData[seg]->SDoffset,RI_TYPE_SYM32,STI_TEXT,0);
    SegData[seg]->SDoffset = buf->size();
}

/**************************************
 * Symbol is the function that calls the static destructors.
 * Put a pointer to it into a special segment that the exit code
 * looks at.
 * Input:
 *	s	static destructor function
 */

void obj_staticdtor(Symbol *s)
{
    IDXSEC seg;
    Outbuffer *buf;

    //dbg_printf("obj_staticdtor(%s) offset %x\n",s->Sident,s->Soffset);
    //symbol_print(s);
    seg = elf_getsegment(".dtors", NULL, SHT_PROGDEF, SHF_ALLOC|SHF_WRITE, 4);
    buf = SegData[seg]->SDbuf;
    if (I64)
	buf->write64(s->Soffset);
    else
	buf->write32(s->Soffset);
    //elf_addrel(seg,0,RI_TYPE_SYM32,STI_TEXT,0);
    elf_addrel(seg,SegData[seg]->SDoffset,RI_TYPE_SYM32,s->Sxtrnnum,0);
    SegData[seg]->SDoffset = buf->size();
}

//#else

/***************************************
 * Stuff pointer to function in its own segment.
 * Used for static ctor and dtor lists.
 */

void obj_funcptr(Symbol *s)
{
    //dbg_printf("obj_funcptr(%s) \n",s->Sident);
}

//#endif

/***************************************
 * Stuff the following data in a separate segment:
 *	pointer to function
 *	pointer to ehsym
 *	length of function
 */

void obj_ehtables(Symbol *sfunc,targ_size_t size,Symbol *ehsym)
{
    //dbg_printf("obj_ehtables(%s) \n",sfunc->Sident);

    symbol *ehtab_entry;
    dt_t **pdte;

    ehtab_entry = symbol_generate(SCstatic,type_alloc(TYint));
    symbol_keep(ehtab_entry);
    elf_getsegment(".deh_beg", NULL, SHT_PROGDEF, SHF_ALLOC, 4);
    ehtab_entry->Sseg = elf_getsegment(".deh_eh", NULL, SHT_PROGDEF, SHF_ALLOC, 4);
    elf_getsegment(".deh_end", NULL, SHT_PROGDEF, SHF_ALLOC, 4);
    ehtab_entry->Stype->Tmangle = mTYman_c;
    ehsym->Stype->Tmangle = mTYman_c;
    pdte = &ehtab_entry->Sdt;
    pdte = dtxoff(pdte,sfunc,0,TYnptr);
    pdte = dtxoff(pdte,ehsym,0,TYnptr);
    pdte = dtnbytes(pdte,4,(char *)&sfunc->Ssize);
    outdata(ehtab_entry);
}

/*********************************************
 * Put out symbols that define the beginning/end of the .deh_eh section.
 */

void obj_ehsections()
{   int sec;
    IDXSYM symidx;
    IDXSTR namidx;

    sec = elf_getsegment(".deh_beg", NULL, SHT_PROGDEF, SHF_ALLOC, 4);
    //obj_bytes(sec, 0, 4, NULL);

    namidx = elf_addstr(symtab_strings,"_deh_beg");
    elf_addsym(namidx, 0, 0, STT_OBJECT, STB_GLOBAL, MAP_SEG2SECIDX(sec));
    //elf_addsym(namidx, 0, 4, STT_OBJECT, STB_GLOBAL, MAP_SEG2SECIDX(sec));

    elf_getsegment(".deh_eh", NULL, SHT_PROGDEF, SHF_ALLOC, 4);

    sec = elf_getsegment(".deh_end", NULL, SHT_PROGDEF, SHF_ALLOC, 4);
    namidx = elf_addstr(symtab_strings,"_deh_end");
    elf_addsym(namidx, 0, 0, STT_OBJECT, STB_GLOBAL, MAP_SEG2SECIDX(sec));

    obj_tlssections();
}

/*********************************************
 * Put out symbols that define the beginning/end of the thread local storage sections.
 */

void obj_tlssections()
{
    IDXSTR namidx;

    int sec = elf_getsegment(".tdata", NULL, SHT_PROGDEF, SHF_ALLOC|SHF_WRITE|SHF_TLS, 4);
    obj_bytes(sec, 0, 4, NULL);

    namidx = elf_addstr(symtab_strings,"_tlsstart");
    elf_addsym(namidx, 0, 4, STT_TLS, STB_GLOBAL, MAP_SEG2SECIDX(sec));

    elf_getsegment(".tdata.", NULL, SHT_PROGDEF, SHF_ALLOC|SHF_WRITE|SHF_TLS, 4);

    sec = elf_getsegment(".tcommon", NULL, SHT_NOBITS, SHF_ALLOC|SHF_WRITE|SHF_TLS, 4);
    namidx = elf_addstr(symtab_strings,"_tlsend");
    elf_addsym(namidx, 0, 4, STT_TLS, STB_GLOBAL, MAP_SEG2SECIDX(sec));
}

/*********************************
 * Setup for Symbol s to go into a COMDAT segment.
 * Output (if s is a function):
 *	cseg		segment index of new current code segment
 *	Coffset		starting offset in cseg
 * Returns:
 *	"segment index" of COMDAT
 */

int obj_comdat(Symbol *s)
{
    const char *prefix;
    int type;
    int flags;

    //printf("obj_comdat(Symbol *%s\n",s->Sident);
    //symbol_print(s);
    symbol_debug(s);
    if (tyfunc(s->ty()))
    {
	//s->Sfl = FLcode;	// was FLoncecode
	//prefix = ".gnu.linkonce.t";	// doesn't work, despite documentation
	prefix = ".text.";		// undocumented, but works
	type = SHT_PROGDEF;
	flags = SHF_ALLOC|SHF_EXECINSTR;
    }
    else if ((s->ty() & mTYLINK) == mTYthread)
    {
	/* Ensure that ".tdata" precedes any other .tdata. section, as the ld
	 * linker script fails to work right.
	 */
	elf_getsegment(".tdata", NULL, SHT_PROGDEF, SHF_ALLOC|SHF_WRITE|SHF_TLS, 4);

	s->Sfl = FLtlsdata;
	prefix = ".tdata.";
	type = SHT_PROGDEF;
	flags = SHF_ALLOC|SHF_WRITE|SHF_TLS;
    }
    else
    {
	s->Sfl = FLdata;
	//prefix = ".gnu.linkonce.d.";
	prefix = ".data.";
	type = SHT_PROGDEF;
	flags = SHF_ALLOC|SHF_WRITE;
    }

    s->Sseg = elf_getsegment(prefix, cpp_mangle(s), type, flags, 4);
				// find or create new segment
    SegData[s->Sseg]->SDsym = s;
    if (s->Sfl == FLdata || s->Sfl == FLtlsdata)
    {
	objpubdef(s->Sseg,s,0);
	searchfixlist(s);		// backpatch any refs to this symbol
    }
    return s->Sseg;
}

/********************************
 * Get a segment for a segment name.
 * Input:
 *	name		name of segment, if NULL then revert to default name
 *	suffix		append to name
 *	align		alignment
 * Returns:
 *	segment index of found or newly created segment
 */

int elf_getsegment2(IDXSEC shtidx, IDXSYM symidx, IDXSEC relidx)
{
    //printf("SegData = %p\n", SegData);
    int seg = ++seg_count;
    if (seg_count >= seg_max)
    {				// need more room in segment table
	seg_max += OB_SEG_INC;
	SegData = (seg_data **)mem_realloc(SegData,seg_max * sizeof(seg_data *));
	memset(&SegData[seg_count], 0, (seg_max - seg_count) * sizeof(seg_data *));
    }
    assert(seg_count < seg_max);
    if (!SegData[seg])
    {	SegData[seg] = (seg_data *)mem_calloc(sizeof(seg_data));
	//printf("test2: SegData[%d] = %p\n", seg, SegData[seg]);
    }

    seg_data *pseg = SegData[seg];
    pseg->SDseg = seg;
    pseg->SDshtidx = shtidx;
    pseg->SDoffset = 0;
    if (pseg->SDbuf)
	pseg->SDbuf->setsize(0);
    else
    {	if (SecHdrTab[shtidx].sh_type != SHT_NOBITS)
	{   pseg->SDbuf = new Outbuffer(OB_XTRA_STR);
	    pseg->SDbuf->reserve(1024);
	}
    }
    if (pseg->SDrel)
	pseg->SDrel->setsize(0);
    pseg->SDsymidx = symidx;
    pseg->SDrelidx = relidx;
    pseg->SDrelmaxoff = 0;
    pseg->SDrelindex = 0;
    pseg->SDrelcnt = 0;
    pseg->SDshtidxout = 0;
    pseg->SDsym = NULL;
    return seg;
}

int elf_getsegment(const char *name, const char *suffix, int type, int flags,
	int align)
{
    //printf("elf_getsegment(%s,%s,flags %x, align %d)\n",name,suffix,flags,align);

    IDXSTR namidx;
    if (namidx = elf_findstr(section_names,name,suffix))
    {					// this section name exists
	for (int seg = CODE; seg <= seg_count; seg++)
	{				// should be in segment table
	    if (MAP_SEG2SEC(seg)->sh_name == namidx)
	    {
		return seg;		// found section for segment
	    }
	}
	assert(0);	// but it's not a segment
	// FIX - should be an error message conflict with section names
    }

    //dbg_printf("\tNew segment - %d size %d\n", seg,SegData[seg]->SDbuf);
    IDXSEC shtidx = elf_newsection(name,suffix,type,flags);
    SecHdrTab[shtidx].sh_addralign = align;
    IDXSYM symidx = elf_addsym(0, 0, 0, STT_SECTION, STB_LOCAL, shtidx);
    int seg = elf_getsegment2(shtidx, symidx, 0);
    //printf("-elf_getsegment() = %d\n", seg);
    return seg;
}

/********************************
 * Define a new code segment.
 * Input:
 *	name		name of segment, if NULL then revert to default
 *	suffix	0	use name as is
 *		1	append "_TEXT" to name
 * Output:
 *	cseg		segment index of new current code segment
 *	Coffset		starting offset in cseg
 * Returns:
 *	segment index of newly created code segment
 */

int obj_codeseg(char *name,int suffix)
{
    int seg;
    const char *sfx;

    //dbg_printf("obj_codeseg(%s,%x)\n",name,suffix);

    sfx = (suffix) ? "_TEXT" : NULL;

    if (!name)				// returning to default code segment
    {
	if (cseg != CODE)		// not the current default
	{
	    SegData[cseg]->SDoffset = Coffset;
	    Coffset = SegData[CODE]->SDoffset;
	    cseg = CODE;
	}
	return cseg;
    }

    seg = elf_getsegment(name, sfx, SHT_PROGDEF, SHF_ALLOC|SHF_EXECINSTR, 4);
				    // find or create code segment

    cseg = seg;				// new code segment index
    Coffset = 0;

    return seg;
}

/*********************************
 * Define segments for Thread Local Storage.
 * Here's what the elf tls spec says:
 *	Field		.tbss			.tdata
 *	sh_name		.tbss			.tdata
 *	sh_type		SHT_NOBITS		SHT_PROGBITS
 *	sh_flags	SHF_ALLOC|SHF_WRITE|	SHF_ALLOC|SHF_WRITE|
 *			SHF_TLS			SHF_TLS
 *	sh_addr		virtual addr of section	virtual addr of section
 *	sh_offset	0			file offset of initialization image
 *	sh_size		size of section		size of section
 * 	sh_link		SHN_UNDEF		SHN_UNDEF
 *	sh_info		0			0
 *	sh_addralign	alignment of section	alignment of section
 *	sh_entsize	0			0
 * We want _tlsstart and _tlsend to bracket all the D tls data.
 * The default linker script (ld -verbose) says:
 *  .tdata	: { *(.tdata .tdata.* .gnu.linkonce.td.*) }
 *  .tbss	: { *(.tbss .tbss.* .gnu.linkonce.tb.*) *(.tcommon) }
 * so if we assign names:
 *	_tlsstart .tdata
 *	symbols   .tdata.
 *	symbols   .tbss
 *	_tlsend   .tbss.
 * this should work.
 * Don't care about sections emitted by other languages, as we presume they
 * won't be storing D gc roots in their tls.
 * Output:
 *	seg_tlsseg	set to segment number for TLS segment.
 * Returns:
 *	segment for TLS segment
 */

seg_data *obj_tlsseg()
{
    /* Ensure that ".tdata" precedes any other .tdata. section, as the ld
     * linker script fails to work right.
     */
    elf_getsegment(".tdata", NULL, SHT_PROGDEF, SHF_ALLOC|SHF_WRITE|SHF_TLS, 4);

    static const char tlssegname[] = ".tdata.";
    //dbg_printf("obj_tlsseg(\n");

    if (seg_tlsseg == UNKNOWN)
    {
	seg_tlsseg = elf_getsegment(tlssegname, NULL, SHT_PROGDEF,
	    SHF_ALLOC|SHF_WRITE|SHF_TLS, 4);
    }
    return SegData[seg_tlsseg];
}


/*********************************
 * Define segments for Thread Local Storage.
 * Output:
 *	seg_tlsseg_bss	set to segment number for TLS segment.
 * Returns:
 *	segment for TLS segment
 */

seg_data *obj_tlsseg_bss()
{
    static const char tlssegname[] = ".tbss";
    //dbg_printf("obj_tlsseg_bss(\n");

    if (seg_tlsseg_bss == UNKNOWN)
    {
	seg_tlsseg_bss = elf_getsegment(tlssegname, NULL, SHT_NOBITS,
	    SHF_ALLOC|SHF_WRITE|SHF_TLS, 4);
    }
    return SegData[seg_tlsseg_bss];
}


/*******************************
 * Output an alias definition record.
 */

void obj_alias(const char *n1,const char *n2)
{   unsigned len;
    char *buffer;

    dbg_printf("obj_alias(%s,%s)\n",n1,n2);
    assert(0);
#if NOT_DONE
    buffer = (char *) alloca(strlen(n1) + strlen(n2) + 2 * ONS_OHD);
    len = obj_namestring(buffer,n1);
    len += obj_namestring(buffer + len,n2);
    objrecord(ALIAS,buffer,len);
#endif
}

char *unsstr (unsigned value)
{
    static char buffer [64];
    
    sprintf (buffer, "%d", value);
    return buffer;
}

/*******************************
 * Mangle a name.
 * Returns:
 *	mangled name
 */

char *obj_mangle2(Symbol *s,char *dest)
{   
    size_t len;
    char *name;

    //dbg_printf("obj_mangle('%s'), mangle = x%x\n",s->Sident,type_mangle(s->Stype));
    symbol_debug(s);
    assert(dest);
#if SCPP
    name = CPP ? cpp_mangle(s) : s->Sident;
#elif MARS
    name = cpp_mangle(s);
#else
    name = s->Sident;
#endif
    len = strlen(name);			// # of bytes in name
    //dbg_printf("len %d\n",len);
    switch (type_mangle(s->Stype))
    {	
	case mTYman_pas:		// if upper case
	case mTYman_for:
	    if (len >= DEST_LEN)
		dest = (char *)mem_malloc(len + 1);
	    memcpy(dest,name,len + 1);	// copy in name and ending 0
	    for (int i = 0; 1; i++)
	    {	char c = dest[i];
		if (!c)
		    break;
		if (c >= 'a' && c <= 'z')
		    dest[i] = c + 'A' - 'a';
	    }
	    break;
	case mTYman_std:
#if TARGET_LINUX || TARGET_FREEBSD || TARGET_SOLARIS
	    if (tyfunc(s->ty()) && !variadic(s->Stype))
#else
	    if (!(config.flags4 & CFG4oldstdmangle) &&
		config.exe == EX_NT && tyfunc(s->ty()) &&
		!variadic(s->Stype))
#endif
	    {
		char *pstr = unsstr(type_paramsize(s->Stype));
		size_t pstrlen = strlen(pstr);
		size_t destlen = len + 1 + pstrlen + 1;

		if (destlen > DEST_LEN)
		    dest = (char *)mem_malloc(destlen);
		memcpy(dest,name,len);
		dest[len] = '@';
		memcpy(dest + 1 + len, pstr, pstrlen + 1);
		break;
	    }
	case mTYman_cpp:
	case mTYman_c:
	case mTYman_d:
	case mTYman_sys:
	case 0:
	    if (len >= DEST_LEN)
		dest = (char *)mem_malloc(len + 1);
	    memcpy(dest,name,len+1);// copy in name and trailing 0
	    break;

	default:
#ifdef DEBUG
	    printf("mangling %x\n",type_mangle(s->Stype));
	    symbol_print(s);
#endif
	    printf("%d\n", type_mangle(s->Stype));
	    assert(0);
    }
    //dbg_printf("\t %s\n",dest);
    return dest;
}

/*******************************
 * Export a function name.
 */

void obj_export(Symbol *s,unsigned argsize)
{   char *coment;
    size_t len;

    //dbg_printf("obj_export(%s,%d)\n",s->Sident,argsize);

}

/*******************************
 * Update data information about symbol
 *	align for output and assign segment
 *	if not already specified.
 *
 * Input:
 *	sdata		data symbol
 *	datasize	output size
 *	seg		default seg if not known
 * Returns:
 *	actual seg
 */

int elf_data_start(Symbol *sdata,int datasize,int seg)
{
    targ_size_t alignbytes;
    //dbg_printf("elf_data_start(%s,size %d,seg %d)\n",sdata->Sident,datasize,seg);
    //symbol_print(sdata);

    if (sdata->Sseg == UNKNOWN)	// if we don't know then there
	sdata->Sseg = seg;	// wasn't any segment override
    else
	seg = sdata->Sseg;
    targ_size_t offset = Offset(seg);
    alignbytes = align(datasize, offset) - offset;
    if (alignbytes)
	obj_lidata(seg, offset, alignbytes);
    sdata->Soffset = offset + alignbytes;
    return seg;
}
	
/*******************************
 * Update function info before codgen
 *
 * If code for this function is in a different segment
 * than the current default in cseg, switch cseg to new segment.
 */

void elf_func_start(Symbol *sfunc)
{
    //dbg_printf("elf_func_start(%s)\n",sfunc->Sident);
    symbol_debug(sfunc);

    if ((tybasic(sfunc->ty()) == TYmfunc) && (sfunc->Sclass == SCextern))
    {					// create a new code segment
	sfunc->Sseg = 
	    elf_getsegment(".gnu.linkonce.t.", cpp_mangle(sfunc), SHT_PROGDEF, SHF_ALLOC|SHF_EXECINSTR,4);

    }
    else if (sfunc->Sseg == UNKNOWN)
	sfunc->Sseg = CODE;
    //dbg_printf("sfunc->Sseg %d CODE %d cseg %d Coffset %d\n",sfunc->Sseg,CODE,cseg,Coffset);
    cseg = sfunc->Sseg;
    assert(cseg == CODE || cseg > COMD);
    objpubdef(cseg, sfunc, Coffset);
    sfunc->Soffset = Coffset;

    if (config.fulltypes)
	dwarf_func_start(sfunc);
}

/*******************************
 * Update function info after codgen
 */

void elf_func_term(Symbol *sfunc)
{ 
    //dbg_printf("elf_func_term(%s) offset %x, Coffset %x symidx %d\n",
//	    sfunc->Sident, sfunc->Soffset,Coffset,sfunc->Sxtrnnum);

    // fill in the function size
    if (I64)
	SymbolTable64[sfunc->Sxtrnnum].st_size = Coffset - sfunc->Soffset;
    else
	SymbolTable[sfunc->Sxtrnnum].st_size = Coffset - sfunc->Soffset;
    if (config.fulltypes)
	dwarf_func_term(sfunc);
}

/********************************
 * Output a public definition.
 * Input:
 *	seg =		segment index that symbol is defined in
 *	s ->		symbol
 *	offset =	offset of name within segment
 */

void objpubdef(int seg, Symbol *s, targ_size_t offset)
{
    int bind;
    switch (s->Sclass)
    {
	case SCglobal:
	case SCinline:
	    bind = STB_GLOBAL;
	    break;
	case SCcomdat:
	case SCcomdef:
	    bind = STB_WEAK;
	    break;
	default:
	    bind = STB_LOCAL;
	    break;
    }

#if 0
    //printf("\nobjpubdef(%d,%s,%d)\n",seg,s->Sident,offset);
    //symbol_print(s);
#endif

    symbol_debug(s);
    IDXSTR namidx = elf_addmangled(s);
    //printf("\tnamidx %d,section %d\n",namidx,MAP_SEG2SECIDX(seg));
    if (tyfunc(s->ty()))
    {
	s->Sxtrnnum = elf_addsym(namidx, offset, Offset(s->Sseg)-offset,
	    STT_FUNC, bind,MAP_SEG2SECIDX(seg));
    }
    else
    {
	s->Sxtrnnum = elf_addsym(namidx, offset, type_size(s->Stype),
	    (s->ty() & mTYthread) ? STT_TLS : STT_OBJECT,
	    bind,MAP_SEG2SECIDX(seg));
    }
    fflush(NULL);
}

/*******************************
 * Output an external symbol for name.
 * Input:
 *	name	Name to do EXTDEF on
 *		(Not to be mangled)
 * Returns:
 *	Symbol table index of the definition
 *	NOTE: Numbers will not be linear.
 */

int objextern(const char *name)
{   
    //dbg_printf("objextdef('%s')\n",name);
    assert(name);
    IDXSTR namidx = elf_addstr(symtab_strings,name);
    IDXSYM symidx = elf_addsym(namidx, 0, 0, STT_NOTYPE, STB_GLOBAL, SHT_UNDEF);
    return symidx;
}

int objextdef(const char *name)
{   
    return objextern(name);
}

/*******************************
 * Output an external for existing symbol.
 * Input:
 *	s	Symbol to do EXTDEF on
 *		(Name is to be mangled)
 * Returns:
 *	Symbol table index of the definition
 *	NOTE: Numbers will not be linear.
 */

int objextern(Symbol *s)
{
    IDXSTR namidx;
    int symtype,sectype;
    int size;

    //dbg_printf("objextern('%s') %x\n",s->Sident,s->Svalue);
    symbol_debug(s);
    namidx = elf_addmangled(s);

#if SCPP
    if (s->Sscope && !tyfunc(s->ty()))
    {
	symtype = STT_OBJECT;
	sectype = SHT_COMMON;
	size = type_size(s->Stype);
    }
    else
#endif
    {
	symtype = STT_NOTYPE;
	sectype = SHT_UNDEF;
	size = 0;
    }
    if (s->ty() & mTYthread)
    {
	//printf("objextern('%s') %x TLS\n",s->Sident,s->Svalue);
	symtype = STT_TLS;
    }

    s->Sxtrnnum = elf_addsym(namidx, size, size, symtype, 
    	/*(s->ty() & mTYweak) ? STB_WEAK : */STB_GLOBAL, sectype);
    return s->Sxtrnnum;

}

/*******************************
 * Output a common block definition.
 * Input:
 *	p ->	external identifier
 *	size	size in bytes of each elem
 *	count	number of elems
 * Returns:
 *	Symbol table index for symbol
 */

int obj_comdef(Symbol *s,targ_size_t size,targ_size_t count)
{
    //printf("obj_comdef('%s',%d,%d)\n",s->Sident,size,count);
    symbol_debug(s);

    if (s->ty() & mTYthread)
    {
	s->Sseg = elf_getsegment(".tbss.", cpp_mangle(s),
		SHT_NOBITS, SHF_ALLOC|SHF_WRITE|SHF_TLS, 4);
	s->Sfl = FLtlsdata;
	SegData[s->Sseg]->SDsym = s;
	SegData[s->Sseg]->SDoffset += size * count;
	objpubdef(s->Sseg, s, 0);
	searchfixlist(s);
	return s->Sseg;
    }
    else
    {
	s->Sseg = elf_getsegment(".bss.", cpp_mangle(s),
		SHT_NOBITS, SHF_ALLOC|SHF_WRITE, 4);
	s->Sfl = FLudata;
	SegData[s->Sseg]->SDsym = s;
	SegData[s->Sseg]->SDoffset += size * count;
	objpubdef(s->Sseg, s, 0);
	searchfixlist(s);
	return s->Sseg;
    }
#if 0
    IDXSTR namidx = elf_addmangled(s);
    alignOffset(UDATA,size);
    IDXSYM symidx = elf_addsym(namidx, SegData[UDATA]->SDoffset, size*count, 
	    	    (s->ty() & mTYthread) ? STT_TLS : STT_OBJECT,
		    STB_WEAK, SHI_BSS);
    //dbg_printf("\tobj_comdef returning symidx %d\n",symidx);
    s->Sseg = UDATA;
    s->Sfl = FLudata;
    SegData[UDATA]->SDoffset += size * count;
    return symidx;
#endif
}

int obj_comdef(Symbol *s, int flag, targ_size_t size, targ_size_t count)
{
    return obj_comdef(s, size, count);
}

/***************************************
 * Append an iterated data block of 0s.
 * (uninitialized data only)
 */

void obj_write_zeros(seg_data *pseg, targ_size_t count)
{
    obj_lidata(pseg->SDseg, pseg->SDoffset, count);
}

/***************************************
 * Output an iterated data block of 0s.
 *
 *	For boundary alignment and initialization
 */

void obj_lidata(int seg,targ_size_t offset,targ_size_t count)
{
    //printf("obj_lidata(%d,%x,%d)\n",seg,offset,count);
    if (seg == UDATA || seg == UNKNOWN)
    {	// Use SDoffset to record size of .BSS section
	SegData[UDATA]->SDoffset += count;
    }
    else if (MAP_SEG2SEC(seg)->sh_type == SHT_NOBITS)
    {	// Use SDoffset to record size of .TBSS section
	SegData[seg]->SDoffset += count;
    }
    else
    {
	obj_bytes(seg, offset, count, NULL);
    }
}

/***********************************
 * Append byte to segment.
 */

void obj_write_byte(seg_data *pseg, unsigned byte)
{
    obj_byte(pseg->SDseg, pseg->SDoffset, byte);
}

/************************************
 * Output byte to object file.
 */

void obj_byte(int seg,targ_size_t offset,unsigned byte)
{
    Outbuffer *buf = SegData[seg]->SDbuf;
    int save = buf->size();
    //dbg_printf("obj_byte(seg=%d, offset=x%lx, byte=x%x)\n",seg,offset,byte);
    buf->setsize(offset);
    buf->writeByte(byte);
    if (save > offset+1)
	buf->setsize(save);
    SegData[seg]->SDoffset = offset+1;
    //dbg_printf("\tsize now %d\n",buf->size());
}

/***********************************
 * Append bytes to segment.
 */

void obj_write_bytes(seg_data *pseg, unsigned nbytes, void *p)
{
    obj_bytes(pseg->SDseg, pseg->SDoffset, nbytes, p);
}

/************************************
 * Output bytes to object file.
 * Returns:
 *	nbytes
 */

unsigned obj_bytes(int seg, targ_size_t offset, unsigned nbytes, void *p)
{
#if 0
    if (!(seg >= 0 && seg <= seg_count))
    {	printf("obj_bytes: seg = %d, seg_count = %d\n", seg, seg_count);
	*(char*)0=0;
    }
#endif
    assert(seg >= 0 && seg <= seg_count);
    Outbuffer *buf = SegData[seg]->SDbuf;
    if (buf == NULL)
    {
	//dbg_printf("obj_bytes(seg=%d, offset=x%lx, nbytes=%d, p=x%x)\n", seg, offset, nbytes, p);
	//raise(SIGSEGV);
	assert(buf != NULL);
    }
    int save = buf->size();
    //dbg_printf("obj_bytes(seg=%d, offset=x%lx, nbytes=%d, p=x%x)\n",
	    //seg,offset,nbytes,p);
    buf->setsize(offset);
    buf->reserve(nbytes);
    if (p)
    {
	buf->writen(p,nbytes);
    }
    else
    {	// Zero out the bytes
	buf->clearn(nbytes);
    }
    if (save > offset+nbytes)
	buf->setsize(save);
    SegData[seg]->SDoffset = offset+nbytes;
    return nbytes;
}

/*******************************
 * Output a relocation entry for a segment
 * Input:
 *	seg =		where the address is going
 *	offset =	offset within seg
 *	type =		ELF relocation type
 *	index =		Related symbol table index
 *	val =		addend or displacement from address
 */

int relcnt=0;

void elf_addrel(int seg, targ_size_t offset, unsigned type, 
					IDXSYM symidx, targ_size_t val)
{
    seg_data *segdata;
    Outbuffer *buf;
    IDXSEC secidx;

    //assert(val == 0);
    relcnt++;
    //dbg_printf("%d-elf_addrel(seg %d,offset x%x,type x%x,symidx %d,val %d)\n",
	    //relcnt,seg, offset, type, symidx,val);

    assert(seg >= 0 && seg <= seg_count);
    segdata = SegData[seg];
    secidx = MAP_SEG2SECIDX(seg);
    assert(secidx != 0);

    if (segdata->SDrel == NULL)
	segdata->SDrel = new Outbuffer();
    if (segdata->SDrel->size() == 0)
    {	IDXSEC relidx;

	if (secidx == SHI_TEXT)
	    relidx = SHI_RELTEXT;
	else if (secidx == SHI_DATA)
	    relidx = SHI_RELDATA;
	else
	{
	    // Get the section name, and make a copy because
	    // elf_newsection() may reallocate the string buffer.
	    char *section_name = (char *)GET_SECTION_NAME(secidx);
	    int len = strlen(section_name) + 1;
	    char *p = (char *)alloca(len);
	    memcpy(p, section_name, len);

	    relidx = elf_newsection(".rel", p, SHT_REL, 0);
	    segdata->SDrelidx = relidx;
	}
	Elf32_Shdr *relsec = &SecHdrTab[relidx];
	relsec->sh_link = SHI_SYMTAB;
	relsec->sh_info = secidx;
	relsec->sh_entsize = I64 ? sizeof(Elf64_Rel) : sizeof(Elf32_Rel);
	relsec->sh_addralign = 4;
    }

    if (I64)
    {
	Elf64_Rel rel;
	rel.r_offset = offset;		// build relocation information
	rel.r_info = ELF64_R_INFO(symidx,type);
	buf = segdata->SDrel;
	buf->write(&rel,sizeof(rel));
	segdata->SDrelcnt++;

	if (offset >= segdata->SDrelmaxoff)
	    segdata->SDrelmaxoff = offset;
	else
	{   // insert numerically
	    int i;
	    Elf64_Rel *relbuf = (Elf64_Rel *)buf->buf;	
	    i = relbuf[segdata->SDrelindex].r_offset > offset ? 0 : segdata->SDrelindex;
	    while (i < segdata->SDrelcnt)
	    {
		if (relbuf[i].r_offset > offset)
		    break;
		i++;
	    }
	    assert(i != segdata->SDrelcnt);	// slide greater offsets down
	    memmove(relbuf+i+1,relbuf+i,sizeof(Elf64_Rel) * (segdata->SDrelcnt - i - 1));
	    *(relbuf+i) = rel;		// copy to correct location
	    segdata->SDrelindex = i;	// next entry usually greater
	}
    }
    else
    {
	Elf32_Rel rel;
	rel.r_offset = offset;		// build relocation information
	rel.r_info = ELF32_R_INFO(symidx,type);
	buf = segdata->SDrel;
	buf->write(&rel,sizeof(rel));
	segdata->SDrelcnt++;

	if (offset >= segdata->SDrelmaxoff)
	    segdata->SDrelmaxoff = offset;
	else
	{   // insert numerically
	    int i;
	    Elf32_Rel *relbuf = (Elf32_Rel *)buf->buf;	
	    i = relbuf[segdata->SDrelindex].r_offset > offset ? 0 : segdata->SDrelindex;
	    while (i < segdata->SDrelcnt)
	    {
		if (relbuf[i].r_offset > offset)
		    break;
		i++;
	    }
	    assert(i != segdata->SDrelcnt);	// slide greater offsets down
	    memmove(relbuf+i+1,relbuf+i,sizeof(Elf32_Rel) * (segdata->SDrelcnt - i - 1));
	    *(relbuf+i) = rel;		// copy to correct location
	    segdata->SDrelindex = i;	// next entry usually greater
	}
    }
}

/*******************************
 * Refer to address that is in the data segment.
 * Input:
 *	seg =		where the address is going
 *	offset =	offset within seg
 *	val =		displacement from address
 *	targetdatum =	DATA, CDATA or UDATA, depending where the address is
 *	flags =		CFoff, CFseg
 * Example:
 *	int *abc = &def[3];
 *	to allocate storage:
 *		reftodatseg(DATA,offset,3 * sizeof(int *),UDATA);
 */

void reftodatseg(int seg,targ_size_t offset,targ_size_t val,
	unsigned targetdatum,int flags)
{
    Outbuffer *buf;
    int save;

    buf = SegData[seg]->SDbuf;
    save = buf->size();
    buf->setsize(offset);
    //dbg_printf("reftodatseg(seg=%d, offset=x%lx, val=x%lx,data %x, flags %x )\n",
    //	seg,offset,val,targetdatum,flags);
    /*if (OPT_IS_SET(OPTfwritable_strings))
    {
	elf_addrel(seg,offset,RI_TYPE_SYM32,STI_DATA,0);
    }
    else*/
    {
	unsigned type = RI_TYPE_SYM32;

	if (MAP_SEG2TYP(seg) == CODE && config.flags3 & CFG3pic)
	    type = RI_TYPE_GOTOFF;
	else if (MAP_SEG2SEC(targetdatum)->sh_flags & SHF_TLS)
	    type = config.flags3 & CFG3pic ? RI_TYPE_TLS_GD : RI_TYPE_TLS_LE;

	elf_addrel(seg,offset,type,STI_RODAT,0);
    }
    if (I64)
	buf->write64(val);
    else
	buf->write32(val);
    if (save > offset + NPTRSIZE)
	buf->setsize(save);
}

/*******************************
 * Refer to address that is in the code segment.
 * Only offsets are output, regardless of the memory model.
 * Used to put values in switch address tables.
 * Input:
 *	seg =		where the address is going (CODE or DATA)
 *	offset =	offset within seg
 *	val =		displacement from start of this module
 */

void reftocodseg(int seg,targ_size_t offset,targ_size_t val)
{
    Outbuffer *buf;
    int save;
    int segtyp = MAP_SEG2TYP(seg);

    //dbg_printf("reftocodseg(seg=%d, offset=x%lx, val=x%lx )\n",seg,offset,val);
    assert(seg > 0);		// COMDATs not done yet
    buf = SegData[seg]->SDbuf;
    save = buf->size();
    buf->setsize(offset);
#if 0
    if (segtyp == CODE)
    {
	val = val - funcsym_p->Soffset;
	elf_addrel(seg,offset,RI_TYPE_PC32,funcsym_p->Sxtrnnum,0);
    }
    else
#endif
    {
	val = val - funcsym_p->Soffset;
	elf_addrel(seg,offset,
		(config.flags3 & CFG3pic) ? RI_TYPE_GOTOFF : RI_TYPE_SYM32,
		funcsym_p->Sxtrnnum,0);
    }
    if (I64)
	buf->write64(val);
    else
	buf->write32(val);
    if (save > offset + NPTRSIZE)
	buf->setsize(save);
}

/*******************************
 * Refer to an identifier.
 * Input:
 *	segtyp =	where the address is going (CODE or DATA)
 *	offset =	offset within seg
 *	s ->		Symbol table entry for identifier
 *	val =		displacement from identifier
 *	flags =		CFselfrel: self-relative
 *			CFseg: get segment
 *			CFoff: get offset
 * Returns:
 *	number of bytes in reference (2 or 4 or 8)
 */

int reftoident(int seg, targ_size_t offset, Symbol *s, targ_size_t val,
	int flags)
{
    tym_t ty;
    bool external = TRUE;
    Outbuffer *buf;
    elf_u32_f32 relinfo,refseg;
    int segtyp = MAP_SEG2TYP(seg);
    //assert(val == 0);

#if 0
    dbg_printf("\nreftoident('%s' seg %d, offset x%lx, val x%lx, flags x%x)\n",
    	s->Sident,seg,offset,val,flags);
    dbg_printf("Sseg = %d, Sxtrnnum = %d\n",s->Sseg,s->Sxtrnnum);
    symbol_print(s);
#endif

    ty = s->ty();
    if (s->Sxtrnnum)
    {				// identifier is defined somewhere else
	if (I64)
	{
	    if (SymbolTable64[s->Sxtrnnum].st_shndx != SHT_UNDEF)
		external = FALSE;
	}
	else
	{
	    if (SymbolTable[s->Sxtrnnum].st_shndx != SHT_UNDEF)
		external = FALSE;
	}
    }

    switch (s->Sclass)
    {
	case SClocstat:
	    buf = SegData[seg]->SDbuf;
	    refseg = /*(OPT_IS_SET(OPTfwritable_strings)) ?
		STI_DATA : */STI_RODAT;
	    relinfo = config.flags3 & CFG3pic ?
		  RI_TYPE_GOTOFF:RI_TYPE_SYM32,STI_RODAT;
	    if (s->Sfl == FLtlsdata)
		relinfo = config.flags3 & CFG3pic ? RI_TYPE_TLS_GD : RI_TYPE_TLS_LE;
	    elf_addrel(seg,offset,relinfo,refseg,0);
	    if (I64)
		buf->write64(val + s->Soffset);
	    else
		buf->write32(val + s->Soffset);
	    break;

	case SCcomdat:
	case_SCcomdat:
	case SCstatic:
#if 0
	    if ((s->Sflags & SFLthunk) && s->Soffset)
	    {			// A thunk symbol that has be defined
		assert(s->Sseg == seg);
		val = (s->Soffset+val) - (offset+4);
		goto outaddrval;
	    }
	    // FALL_THROUGH
#endif

	case SCextern:
	case SCcomdef:
	case_extern: 
	case SCglobal:
	    if (!s->Sxtrnnum)
	    {	// not in symbol table yet - class might change
		//dbg_printf("\tadding %s to fixlist\n",s->Sident);
		addtofixlist(s,offset,seg,val,flags);
		return NPTRSIZE;
	    }
	    else
	    {
		int save;
		buf = SegData[seg]->SDbuf;
	       	save = buf->size();
		buf->setsize(offset);
		if (flags & CFselfrel)
		{		// only for function references within code segments
		    if (!external && 		// local definition found
			 s->Sseg == seg &&	// within same code segment
			  (!(config.flags3 & CFG3pic) ||	// not position indp code
			   s->Sclass == SCstatic)) // or is pic, but declared static
		    {			// Can use PC relative
			//dbg_printf("\tdoing PC relative\n");
		        val = (s->Soffset+val) - (offset+NPTRSIZE);
		    }
		    else
		    {
		    	val = (targ_size_t)-NPTRSIZE;
			//dbg_printf("\tadding relocation\n");
		        elf_addrel(seg,offset,
		    		config.flags3 & CFG3pic ?  RI_TYPE_PLT32 : RI_TYPE_PC32,
				s->Sxtrnnum,0);
		    }
		}
		else 
		{	// code to code code to data, data to code, data to data refs
		    refseg = s->Sxtrnnum;	// default to name symbol table entry
		    if (s->Sclass == SCstatic)
		    {				// offset into .data or .bss seg
			refseg = MAP_SEG2SYMIDX(s->Sseg);
						// use segment symbol table entry
			val += s->Soffset;
			if (!(config.flags3 & CFG3pic) ||	// all static refs from normal code
			     segtyp == DATA)	// or refs from data from posi indp
			{
			   relinfo = RI_TYPE_SYM32;
			}
			else
			{
			    relinfo = RI_TYPE_GOTOFF;
			}
	    	    }
	    	    else if (config.flags3 & CFG3pic && s == GOTsym)
		    {			// relocation for Gbl Offset Tab
		    	relinfo =  RI_TYPE_GOTPC;
		    }
		    else if (segtyp == DATA)
		    {			// relocation from with in DATA seg
			relinfo = RI_TYPE_SYM32;
		    }
		    else
		    {			// relocation from with in CODE seg
			relinfo = config.flags3 & CFG3pic ?
	 		     RI_TYPE_GOT32 : RI_TYPE_SYM32;
	    	    }
		    if ((s->ty() & mTYLINK) & mTYthread)
		    {
			if (config.flags3 & CFG3pic)
			{
			    if (s->Sclass == SCstatic)
				relinfo = RI_TYPE_TLS_LE;  // TLS_GD?
			    else
				relinfo = RI_TYPE_TLS_IE;
			}
			else
			{
			    if (s->Sclass == SCstatic)
				relinfo = RI_TYPE_TLS_LE;
			    else
				relinfo = RI_TYPE_TLS_IE;
			}
		    }
		    //printf("\t\t************* adding relocation\n");
		    elf_addrel(seg,offset,relinfo,refseg,0);
		}
outaddrval:
		if (I64)
		    buf->write64(val);
		else
		    buf->write32(val);
		if (save > offset + NPTRSIZE)
		    buf->setsize(save);
	    }
	    break;

	case SCsinline:
	case SCeinline:
	    printf ("Undefined inline value <<fixme>>\n");
	    //warerr(WM_undefined_inline,s->Sident);
	case SCinline:
	    if (tyfunc(ty))
	    {
		s->Sclass = SCextern;
		goto case_extern;
	    }
	    else if (config.flags2 & CFG2comdat)
		goto case_SCcomdat;	// treat as initialized common block

	default:
#ifdef DEBUG
	    //symbol_print(s);
#endif
	    assert(0);
    }
    return NPTRSIZE;
}

/*****************************************
 * Generate far16 thunk.
 * Input:
 *	s	Symbol to generate a thunk for
 */

void obj_far16thunk(Symbol *s)
{
    //dbg_printf("obj_far16thunk('%s')\n", s->Sident);
    assert(0);
}

/**************************************
 * Mark object file as using floating point.
 */

void obj_fltused()
{
    //dbg_printf("obj_fltused()\n");
}

static int obj_align(Symbol *s)
{
    if (type_size(s->Stype) == CHARSIZE)
	return 1;
    else if (type_size(s->Stype) == SHORTSIZE)
	return 2;
    else if (type_size(s->Stype) == LONGSIZE)
	return 4;
    else
	return I64 ? 8 : 4;
}

/************************************
 * Close and delete .OBJ file.
 */

void objfile_delete()
{
    //remove(fobjname);	// delete corrupt output file
}

/**********************************
 * Terminate.
 */

void objfile_term()
{
#if TERMCODE
    mem_free(fobjname);
    fobjname = NULL;
#endif
}

/**********************************
  * Write to the object file
  */
void objfile_write(FILE *fd, void *buffer, unsigned len)
{
    fobjbuf->write(buffer, len);
}

long elf_align(FILE *fd, targ_size_t size,long foffset)
{
    long offset;
    switch (size)
    {
	case 0:
	case 1:
	    return foffset;
	case 4:
	    offset = (foffset + 3) & ~3;
	    break;
	case 8:
	    offset = (foffset + 7) & ~7;
	    break;
	case 16:
	    offset = (foffset + 15) & ~15;
	    break;
	case 32:
	    offset = (foffset + 31) & ~31;
	    break;
	default:
	    dbg_printf("size was %d\n",(int)size);
	    assert(0);
	    break;
    }
    if (offset > foffset)
	fobjbuf->writezeros(offset - foffset);
    return offset;
}

/***************************************
 * Stuff pointer to ModuleInfo in its own segment.
 */

#if MARS

void obj_moduleinfo(Symbol *scc)
{
    int offset, codeOffset, refOffset;
    Outbuffer *buf;
    int seg;
    
    /* Put in the ModuleInfo reference for some reason. */
    /*{
	seg = DATA;
	offset = SegData[seg]->SDoffset;
	SegData[seg]->SDoffset += reftoident(seg, offset, scc, 0, CFoff);
    }*/
    
    /* Put in the ModuleReference. */
    {
	/* struct ModuleReference
	 * {
	 *	void*	next;
	 *	ModuleReference* module;
	 * }
	 */
	seg = DATA;
	SegData[seg]->SDoffset = SegData[seg]->SDbuf->size();
	refOffset = SegData[seg]->SDoffset;
	SegData[seg]->SDbuf->writezeros(NPTRSIZE);
	SegData[seg]->SDoffset += NPTRSIZE;
	SegData[seg]->SDoffset += reftoident(seg, SegData[seg]->SDoffset, scc, 0, CFoff);
    }
    
    /* Constructor that links the ModuleReference into the code. */
    {
	/*	ret
	 *	pushad
	 *	mov	EAX,&ModuleReference
	 *	mov	ECX,_DmoduleRef
	 *	mov	EDX,[ECX]
	 *	mov	[EAX],EDX
	 *	mov	[ECX],EAX
	 *	popad
	 *	ret
	 */

	seg = CODE;
	buf = SegData[seg]->SDbuf;
	SegData[seg]->SDoffset = buf->size();
	codeOffset = SegData[seg]->SDoffset + 1;
//	codeOffset = SegData[seg]->SDoffset;
	buf->writeByte(0xC3); /* ret */
	
	buf->writeByte(0x60); /* pushad */
	
	/* movl ModuleReference*, %eax */
	buf->writeByte(0xB8);
	buf->write32(refOffset);
	elf_addrel(seg, codeOffset + 2, RI_TYPE_SYM32, STI_DATA, 0);
	
	/* movl _Dmodule_ref, %ecx */
	buf->writeByte(0xB9);
	buf->write32(0);//offset);
	elf_addrel(seg, codeOffset + 7, RI_TYPE_SYM32, objextern("_Dmodule_ref"), 0);

	buf->writeByte(0x8B); buf->writeByte(0x11); /* movl (%ecx), %edx */
	buf->writeByte(0x89); buf->writeByte(0x10); /* movl %edx, (%eax) */
	buf->writeByte(0x89); buf->writeByte(0x01); /* movl %eax, (%ecx) */
	
	buf->writeByte(0x61); /* popad */
	buf->writeByte(0xC3); /* ret */
	SegData[seg]->SDoffset = buf->size();
    }
    
    /* Create the linked list-generating code. */
    seg = elf_getsegment(".ctors", NULL, SHT_PROGDEF, SHF_ALLOC|SHF_WRITE,4);
    
    buf = SegData[seg]->SDbuf;
    buf->write32(codeOffset);
    elf_addrel(seg, SegData[seg]->SDoffset, RI_TYPE_SYM32, STI_TEXT, 0);
    SegData[seg]->SDoffset += NPTRSIZE;
}

#endif

/************************************
 * Output long word of data.
 * Input:
 *	seg	CODE, DATA, CDATA, UDATA
 *	offset	offset of start of data
 *	data	long word of data
 *   Present only if size == 2:
 *	lcfd	LCxxxx | FDxxxx
 *	if (FD_F2 | FD_T6)
 *		idx1 = external Symbol #
 *	else
 *		idx1 = frame datum
 *		idx2 = target datum
 */

void obj_long(int seg,targ_size_t offset,unsigned long data,
	unsigned lcfd,unsigned idx1,unsigned idx2)
{ 
    printf ("obj_long\n");
    exit (1);
    /*
    unsigned i;

    if (
	(seg != obj.ledata->lseg ||		// or segments don't match
	 obj.ledata->i + tysize[TYfptr] > LEDATAMAX || // or it'll overflow
	 offset < obj.ledata->offset ||	// underflow
	 offset > obj.ledata->offset + obj.ledata->i
	)
     )
	ledata_new(seg,offset);
  i = offset - obj.ledata->offset;
  if (obj.ledata->i < i + tysize[TYfptr])
	obj.ledata->i = i + tysize[TYfptr];
  TOLONG(obj.ledata->data + i,data);
  if (I32)				// if 6 byte far pointers
	TOWORD(obj.ledata->data + i + LONGSIZE,0);		// fill out seg
  addfixup(offset - obj.ledata->offset,lcfd,idx1,idx2);
  */
}

/*************************************
 */

void elfobj_gotref(symbol *s)
{
    //printf("elfobj_gotref(%x '%s', %d)\n",s,s->Sident, s->Sclass);
    switch(s->Sclass)
    {
	case SCstatic:
	case SClocstat:
	    s->Sfl = FLgotoff;
	    break;

	case SCextern:
	case SCglobal:
	case SCcomdat:
	case SCcomdef:
	    s->Sfl = FLgot;
	    break;

	default:
	    break;
    }
}

#endif
#endif
