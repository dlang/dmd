module dmd.ctfe.bc_limits;

enum bc_max_members = 96;
enum bc_max_locals = ubyte.max * 128;
enum bc_max_errors = ubyte.max * 256;
enum bc_max_arrays = ubyte.max * 16;
enum bc_max_structs = ubyte.max * 12;
enum bc_max_classes = ubyte.max * 14;
enum bc_max_slices = ubyte.max * 8;
enum bc_max_types = ubyte.max * 32;
enum bc_max_pointers = ubyte.max * 8;
enum bc_max_functions = ubyte.max * 56;
