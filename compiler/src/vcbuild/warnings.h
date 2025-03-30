#pragma warning(disable:4996) // This function or variable may be unsafe.
#pragma warning(disable:4127) // conditional expression is constant
#pragma warning(disable:4101) // unreferenced local variable
#pragma warning(disable:4100) // unreferenced formal parameter
#pragma warning(disable:4146) // unary minus operator applied to unsigned type, result still unsigned
#pragma warning(disable:4244) // conversion from 'int' to 'unsigned short', possible loss of data
#pragma warning(disable:4245) // conversion from 'int' to 'unsigned int', signed/unsigned mismatch
#pragma warning(disable:4018) // signed/unsigned mismatch
#pragma warning(disable:4389) // signed/unsigned mismatch
#pragma warning(disable:4505) // unreferenced local function has been removed
#pragma warning(disable:4701) // potentially uninitialized local variable 'm' used
#pragma warning(disable:4201) // nonstandard extension used : nameless struct/union
#pragma warning(disable:4189) // local variable is initialized but not referenced
#pragma warning(disable:4102) // unreferenced label
#pragma warning(disable:4800) // forcing value to bool 'true' or 'false' (performance warning)
#pragma warning(disable:4804) // '+=' : unsafe use of type 'bool' in operation
#pragma warning(disable:4390) // ';' : empty controlled statement found; is this the intent?
#pragma warning(disable:4702) // unreachable code
#pragma warning(disable:4703) // potentially uninitialized local pointer variable 'm' used
#pragma warning(disable:4063) // case '0' is not a valid value for switch of enum
#pragma warning(disable:4305) // 'initializing' : truncation from 'double' to 'float'
#pragma warning(disable:4309) // 'initializing' : truncation of constant value
#pragma warning(disable:4310) // cast truncates constant value
#pragma warning(disable:4806) // '^' : unsafe operation: no value of type 'bool' promoted to type 'int' can equal the given constant
#pragma warning(disable:4060) // switch statement contains no 'case' or 'default' labels
#pragma warning(disable:4099) // type name first seen using 'struct' now seen using 'class'
#pragma warning(disable:4725) // instruction may be inaccurate on some Pentiums
#pragma warning(disable:4510) // 'CommaExp' : default constructor could not be generated
#pragma warning(disable:4512) // 'CommaExp' : assignment operator could not be generated
#pragma warning(disable:4610) // class 'CommaExp' can never be instantiated - user defined constructor required
#pragma warning(disable:4838) // requires a narrowing conversion
#pragma warning(disable:4577) // 'noexcept' used with no exception handling mode specified
#pragma warning(disable:4805) // '|': unsafe mix of types in operation

#ifdef _WIN64
#pragma warning(disable:4366) // The result of the unary '&' operator may be unaligned
#pragma warning(disable:4267) // conversion from 'size_t' to 'unsigned int', possible loss of data
#endif

#define LITTLE_ENDIAN 1
#define __pascal
#define MARS     1
#define UNITTEST 1
#define _M_I86   1
#define DM_TARGET_CPU_X86 1
