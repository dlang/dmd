Files in the Back End
=====================

Data Structures
---------------
* **aarray.d**        simple hash table
* **el.d**            expression trees (intermediate code)
* **outbuf.d**        resizable buffer
* **dlist.d**         liked list
* **barray.d**        array of bits

Optimisations
-------------

* **blockopt.d**      manage and simple optimizations on graphs of basic blocks
* **gdag.d**          Directed acyclic graphs and global optimizer common subexpressions
* **gflow.d**         global data flow analysis
* **global.h**        declarations for back end
* **glocal.d**        global optimizations
* **gloop.d**         global loop optimizations
* **go.d**            global optimizer main loop
* **go.h**            global optimizer declarations
* **gother.d**        other global optimizations
* **evalu8.d**        constant folding
* **divcoeff.d**      convert divisions to multiplications

Debug Information
-----------------

* **cv4.d**           CodeView symbolic debug info declarations
* **cv8.d**
* **dcgcv.d**
* **dwarf.d**         generate DWARF symbolic debug info
* **dwarf2.d**        Dwarf 3 spec declarations
* **dwarfdbginf.d**
* **dwarfeh.d**       Dwarf Exception handling tables
* **ee.d**            handle IDDE debugger expression evaluation

Object File Generation
----------------------

* **melf.d**          declarations for ELF file format
* **elfobj.d**        generate ELF object files
* **machobj.d**       generate Mach-O object files
* **mach.d**          declarations for Mach-O object file format
* **cgobj.d**         generate OMF object files
* **out.d**           write data definitions to object file
* **dt.d**            static data for later output to object file

Exception Handling
------------------

* **exh.d**           exception handling support
* **nteh.d**          Windows structured exception handling support

Miscellaneous
-------------

* **bcomplex.d**      our own complex number implementation because we can't rely on host C compiler
* **md5.d**           implementation of MD5 message digest
* **md5.d**i          API for md5.d
* **newman.d**        "new" C++ name mangling scheme
* **os.d**            some operating system specific support
* **cc.d**            common definitions
* **cdef.d**          configuration
* **backconfig.d**    configuration
* **compress.d**      identifier comperssion
* **debugprint.d**     pretty printing for debug builds
* **iasm.h**          declarations for inline assembler
* **ptrntab.d**       instruction tables for inline assembler
* **oper.h**          operators for expression tree
* **optabgen.d**      generate tables for back end
* **ty.d**            type masks
* **ph2.d**           leaking allocator
* **symbol.d**        symbols for the back end
* **type.d**          back end type
* **var.d**           global variables

Code Generation
---------------

* **cg.d**            global variables for code generator
* **cg87.d**          x87 FPU code generation
* **cgcod.d**         main loop for code generator
* **cgcs.d**          compute common subexpressions for non-optimized code generation
* **cgcv.d**          CodeView symbol debug info generation
* **cgcv.h**          header for cgcv.d
* **cgelem.d**        local optimizations of elem trees
* **cgen.d**          generate/manage linked list of code instructions
* **cgreg.d**         register allocator
* **cgsched.d**       instruction scheduler
* **cgxmm.d**         xmm
* **cod1.d**          code gen
* **cod2.d**          code gen
* **cod3.d**          code gen
* **cod4.d**          code gen
* **cod5.d**          code gen
* **code.d**          memory management for code instructions
* **code.d**          define registers, register masks, and the CPU instruction linked list
* **code_x86.d**
* **dcode.d**         aloocate and free code blocks
* **drtlsym.d**       compiler runtime function symbols
* **xmm.d**           xmm opcodes
