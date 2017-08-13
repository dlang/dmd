module ddmd.ctfe.bc_limits;

enum bc_max_members = 96;
enum bc_max_locals = ubyte.max * 4;
enum bc_max_errors = ubyte.max * 32;
enum bc_max_arrays = ubyte.max * 16;
enum bc_max_structs = ubyte.max * 12;
enum bc_max_slices = ubyte.max * 8;
enum bc_max_types = ubyte.max * 8;
enum bc_max_pointers = ubyte.max * 8;
