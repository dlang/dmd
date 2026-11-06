Files in the Back End
=====================

The backend originated in the [Digital Mars C/C++ compiler (DMC)](https://github.com/DigitalMars/Compiler/tree/master/dm/src/dmc),
but the two backends are no longer kept in sync.

Paths below are relative to this directory.

Data Structures
---------------
* **aarray.d**        hash table
* **el.d**            expression trees (intermediate representation)
* **barray.d**        generic resizeable array
* **dt.d**            intermediate representation for static data
* **dvec.d**          bit vectors

Optimisations
-------------

* **blockopt.d**      manage and simple optimizations on graphs of basic blocks
* **gdag.d**          Directed acyclic graphs and global optimizer common subexpressions
* **gflow.d**         global data flow analysis
* **global.d**        declarations for back end
* **glocal.d**        local optimizations
* **gloop.d**         global loop optimizations
* **go.d**            global optimizer main loop
* **gother.d**        other global optimizations
* **gsroa.d**         scalar replacement of aggregates (SROA)
* **evalu8.d**        constant folding
* **divcoeff.d**      convert divisions to multiplications
* **inliner.d**       inline functions using optimized intermediate code

Debug Information
-----------------

* **cv4.d**           CodeView 4 symbolic debug info declarations
* **cv8.d**           CodeView 8 symbolic debug info generation
* **dwarf.d**         interface to DWARF generation
* **dwarf2.d**        DWARF specification declarations
* **dwarfdbginf.d**   generate DWARF debug info
* **dwarfeh.d**       DWARF Exception handling tables
* **dvarstats.d**     local variable scopes and lifetimes for debug info
* **ee.d**            DMC++ IDDE debugger expression evaluation

Object File Generation
----------------------

* **melf.d**          declarations for ELF file format
* **elfobj.d**        generate ELF object files
* **machobj.d**       generate Mach-O object files
* **mach.d**          declarations for Mach-O object file format
* **mscoff.d**        declarations for Microsoft COFF object file format
* **mscoffobj.d**     generate Microsoft COFF object files
* **obj.d**           interface to *obj.d files

Exception Handling
------------------

* **eh.d**            generate exception handling tables for EH_DM and EH_WIN32
* **pdata.d**         generate Win64 `.pdata` and `.xdata` unwind sections
* **x86/nteh.d**      Windows structured exception handling support

Miscellaneous
-------------

* **bcomplex.d**      our own complex number implementation
* **cc.d**            common definitions
* **cdef.d**          configuration
* **backconfig.d**    transfer configuration from front end to back end
* **debugprint.d**    pretty print data structures
* **fp.d**            floating-point exception and modulo helpers
* **iasm.d**          declarations for inline assembler
* **mem.d**           memory allocation helpers
* **ptrntab.d**       instruction tables for inline assembler
* **oper.d**          operators for expression tree
* **ty.d**            type masks
* **symbol.d**        symbols for the back end
* **type.d**          types for the back end
* **util2.d**         utility routines, including process exit and binary search

Code Generation
---------------

* **cg.d**            global variables for code generator
* **cgcs.d**          compute common subexpressions for non-optimized code generation
* **cgcse.d**         manage stack storage for common subexpressions (CSEs)
* **cgcv.d**          interface for CodeView symbol debug info generation
* **cgelem.d**        local optimizations of elem trees
* **cgen.d**          generate/manage linked list of code instructions
* **cgsched.d**       instruction scheduler
* **code.d**          define registers, register masks, and the CPU instruction linked list
* **codebuilder.d**   construct linked list of generated code
* **dcode.d**         aloocate and free code blocks
* **dout.d**           transition from intermediate representation to code generator
* **elpicpie.d**      generate expression trees for fixed, PIC, and PIE code
* **rtlsym.d**        compiler runtime function symbols

### x86 and x86-64

Some modules in `x86/` are also used by the AArch64 backend.

* **x86/cg87.d**      x87 FPU code generation
* **x86/cgcod.d**     main loop for code generation
* **x86/cgreg.d**     register allocator
* **x86/cgxmm.d**     XMM-specific code generation
* **x86/cod1.d**      function calls and argument passing
* **x86/cod2.d**      arithmetic, pointer, and aggregate operations
* **x86/cod3.d**      function prologs, epilogs, and branches
* **x86/cod4.d**      assignment, comparison, conversion, and bit operations
* **x86/cod5.d**      select blocks that need function prologs or epilogs
* **x86/code_x86.d**  x86-specific declarations
* **x86/disasm86.d**  x86 disassembler
* **x86/xmm.d**       XMM opcodes

### AArch64

* **arm/cod1.d**      function calls and argument passing
* **arm/cod2.d**      arithmetic, pointer, and aggregate operations
* **arm/cod3.d**      function prologs, epilogs, and branches
* **arm/cod4.d**      assignment, comparison, conversion, and bit operations
* **arm/disasmarm.d** AArch64 disassembler
* **arm/instr.d**     AArch64 instruction encodings
