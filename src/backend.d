// Compiler implementation of the D programming language
// Copyright (c) 1999-2015 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// http://www.digitalmars.com
// Distributed under the Boost Software License, Version 1.0.
// http://www.boost.org/LICENSE_1_0.txt

module ddmd.backend;

import ddmd.aggregate;
import ddmd.dmodule;
import ddmd.dscope;
import ddmd.expression;
import ddmd.lib;
import ddmd.mtype;
import ddmd.root.file;

struct Symbol;
struct code;
struct block;
struct Blockx;
struct elem;

extern extern (C++) void backend_init();
extern extern (C++) void backend_term();
extern extern (C++) void obj_start(char* srcfile);
extern extern (C++) void obj_end(Library library, File* objfile);
extern extern (C++) void obj_write_deferred(Library library);

extern extern (C++) void genObjFile(Module m, bool multiobj);

extern extern (C++) Symbol* toInitializer(AggregateDeclaration sd);

// type.h


alias tym_t = uint;
alias mangle_t = ubyte;
alias targ_size_t = ulong;

struct PARAM;
struct Classsym;
struct LIST;
alias list_t = LIST*;
alias type = TYPE;

extern extern (C++) type* type_fake(tym_t);
extern extern (C++) void type_incCount(type* t);
extern extern (C++) void type_setIdent(type* t, char* ident);

extern extern (C++) type* type_alloc(tym_t);
extern extern (C++) type* type_allocn(tym_t, type* tn);

extern extern (C++) type* type_pointer(type* tnext);
extern extern (C++) type* type_dyn_array(type* tnext);
extern extern (C) type* type_static_array(targ_size_t dim, type* tnext);
extern extern (C++) type* type_assoc_array(type* tkey, type* tvalue);
extern extern (C++) type* type_delegate(type* tnext);
extern extern (C) type* type_function(tym_t tyf, type** ptypes, size_t nparams, bool variadic, type* tret);
extern extern (C++) type* type_enum(const(char)* name, type* tbase);
extern extern (C++) type* type_struct_class(const(char)* name, uint alignsize, uint structsize,
    type* arg1type, type* arg2type, bool isUnion, bool isClass, bool isPOD);

extern extern (C++) void symbol_struct_addField(Symbol* s, const(char)* name, type* t, uint offset);

enum mTYbasic     = 0xFF; /* bit mask for basic types     */
enum mTYconst     = 0x100;
enum mTYimmutable = 0x00080000; // immutable data
enum mTYshared    = 0x00100000; // shared data

tym_t tybasic(tym_t ty) { return ty & mTYbasic; }

// Return true if type is a struct, class or union
bool type_struct(type* t) { return tybasic(t.Tty) == TYstruct; }

struct TYPE
{
    debug ushort id;

    tym_t Tty;     /* mask (TYxxx)                         */
    ushort Tflags; // TFxxxxx

    mangle_t Tmangle; // name mangling

    uint Tcount; // # pointing to this type
    TYPE* Tnext; // next in list
                                // TYenum: gives base type
    union
    {
        targ_size_t Tdim;   // TYarray: # of elements in array
        elem* Tel;          // TFvla: gives dimension (NULL if '*')
        PARAM* Tparamtypes; // TYfunc, TYtemplate: types of function parameters
        Classsym* Ttag;     // TYstruct,TYmemptr: tag symbol
                            // TYenum,TYvtshape: tag symbol
        char* Tident;       // TYident: identifier
        TYPE* Tkey;         // typtr: key type for associative arrays
    }

    list_t Texcspec;        // tyfunc(): list of types of exception specification
}

enum
{
    TYbool              = 0,
    TYchar              = 1,
    TYschar             = 2,    // signed char
    TYuchar             = 3,    // unsigned char
    TYchar8             = 4,
    TYchar16            = 5,
    TYshort             = 6,
    TYwchar_t           = 7,
    TYushort            = 8,    // unsigned short
    TYenum              = 9,    // enumeration value
    TYint               = 0xA,
    TYuint              = 0xB,  // unsigned
    TYlong              = 0xC,
    TYulong             = 0xD,  // unsigned long
    TYdchar             = 0xE,  // 32 bit Unicode char
    TYllong             = 0xF,  // 64 bit long
    TYullong            = 0x10, // 64 bit unsigned long
    TYfloat             = 0x11, // 32 bit real
    TYdouble            = 0x12, // 64 bit real

    // long double is mapped to either of the following at runtime:
    TYdouble_alias      = 0x13, // 64 bit real (but distinct for overload purposes)
    TYldouble           = 0x14, // 80 bit real

    // Add imaginary and complex types for D and C99
    TYifloat            = 0x15,
    TYidouble           = 0x16,
    TYildouble          = 0x17,
    TYcfloat            = 0x18,
    TYcdouble           = 0x19,
    TYcldouble          = 0x1A,

    TYnullptr           = 0x1C,
    TYnptr              = 0x1D, // data segment relative pointer
    TYref               = 0x24, // reference to another type
    TYvoid              = 0x25,
    TYstruct            = 0x26, // watch tyaggregate()
    TYarray             = 0x27, // watch tyaggregate()
    TYnfunc             = 0x28, // near C func
    TYnpfunc            = 0x2A, // near Cpp func
    TYnsfunc            = 0x2C, // near stdcall func
    TYifunc             = 0x2E, // interrupt func
    TYptr               = 0x33, // generic pointer type
    TYmfunc             = 0x37, // NT C++ member func
    TYjfunc             = 0x38, // LINKd D function
    TYhfunc             = 0x39, // C function with hidden parameter
    TYnref              = 0x3A, // near reference

    TYcent              = 0x3C, // 128 bit signed integer
    TYucent             = 0x3D, // 128 bit unsigned integer

    // SIMD vector types        // D type
    TYfloat4            = 0x3E, // float[4]
    TYdouble2           = 0x3F, // double[2]
    TYschar16           = 0x40, // byte[16]
    TYuchar16           = 0x41, // ubyte[16]
    TYshort8            = 0x42, // short[8]
    TYushort8           = 0x43, // ushort[8]
    TYlong4             = 0x44, // int[4]
    TYulong4            = 0x45, // uint[4]
    TYllong2            = 0x46, // long[2]
    TYullong2           = 0x47, // ulong[2]

// // MARS types
// #define TYaarray        TYnptr
// #define TYdelegate      (I64 ? TYcent : TYllong)
// #define TYdarray        (I64 ? TYucent : TYullong)

    TYMAX               = 0x48,
}
