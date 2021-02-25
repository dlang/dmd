Files in the Back End
=====================

:warning: When contributing to the backend, make sure youd don't break DMC :warning:

The backend is shared with DMC, the DigitalMars C/C++ compiler.

To ensure compatibility, [check its source tree here](https://github.com/DigitalMars/Compiler/tree/master/dm/src/dmc).

Data Structures
---------------
* **aarray.d**        hash table
* **el.d**            expression trees (intermediate representation)
* **outbuf.d**        resizable char buffer for writing text to
* **dlist.d**         linked list
* **barray.d**        generic resizeable array
* **dt.d**            intermediate representation for static data

Optimisations
-------------

* **blockopt.d**      manage and simple optimizations on graphs of basic blocks
* **gdag.d**          Directed acyclic graphs and global optimizer common subexpressions
* **gflow.d**         global data flow analysis
* **global.d**        declarations for back end
* **glocal.d**        local optimizations
* **gloop.d**         global loop optimizations
* **go.d**            global optimizer main loop
* **goh.d**           global optimizer declarations
* **gother.d**        other global optimizations
* **gsroa.d**         SROA structured replacement of aggregate optimization
* **evalu8.d**        constant folding
* **divcoeff.d**      convert divisions to multiplications

Debug Information
-----------------

* **cv4.d**           CodeView 4 symbolic debug info declarations
* **cv8.d**           CodeView 8 symbolic debug info generation
* **dcgcv.d**         CodeView 4 symbolic debug info generation
* **dwarf.d**         interface to DWARF generation
* **dwarf2.d**        DWARF specification declarations
* **dwarfdbginf.d**   generate DWARF debug info
* **dwarfeh.d**       DWARF Exception handling tables
* **ee.d**            DMC++ IDDE debugger expression evaluation

Object File Generation
----------------------

* **melf.d**          declarations for ELF file format
* **elfobj.d**        generate ELF object files
* **machobj.d**       generate Mach-O object files
* **mach.d**          declarations for Mach-O object file format
* **cgobj.d**         generate OMF object files
* **obj.d**           interface to *obj.d files

Exception Handling
------------------

* **exh.d**           interface for exception handling support
* **nteh.d**          Windows structured exception handling support

Miscellaneous
-------------

* **backend.d**       internal header file for the backend
* **bcomplex.d**      our own complex number implementation
* **md5.d**           implementation of MD5 message digest
* **md5.di**          API for md5.d
* **newman.d**        "new" C++ name mangling scheme
* **os.d**            some operating system specific support
* **cc.d**            common definitions
* **cdef.d**          configuration
* **backconfig.d**    transfer configuration from front end to back end
* **compress.d**      identifier comperssion
* **debugprint.d**    pretty print data structures
* **iasm.d**          declarations for inline assembler
* **ptrntab.d**       instruction tables for inline assembler
* **oper.d**          operators for expression tree
* **optabgen.d**      generate tables for back end
* **ty.d**            type masks
* **ph2.d**           leaking allocator
* **symbol.d**        symbols for the back end
* **type.d**          types for the back end
* **var.d**           global variables

Code Generation
---------------

* **cg.d**            global variables for code generator
* **cg87.d**          x87 FPU code generation
* **cgcod.d**         main loop for code generator
* **cgcs.d**          compute common subexpressions for non-optimized code generation
* **cgcse.d**         manage temporaries used to save CSEs in
* **cgcv.d**          interface for CodeView symbol debug info generation
* **cgelem.d**        local optimizations of elem trees
* **cgen.d**          generate/manage linked list of code instructions
* **cgreg.d**         register allocator
* **cgsched.d**       instruction scheduler
* **cgxmm.d**         xmm specific code generation
* **cod1.d**          code gen
* **cod2.d**          code gen
* **cod3.d**          code gen
* **cod4.d**          code gen
* **cod5.d**          code gen
* **code.d**          define registers, register masks, and the CPU instruction linked list
* **codebuilder.d**   construct linked list of generated code
* **code_x86.d**      x86 specific declarations
* **dcode.d**         aloocate and free code blocks
* **drtlsym.d**       compiler runtime function symbols
* **out.d**           transition from intermediate representation to code generator
* **xmm.d**           xmm opcodes

