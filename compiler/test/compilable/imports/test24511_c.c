typedef void (*CFunctionPointer)();
typedef void (__stdcall *StdCallFunctionPointer)();

void cFunction()
{}

void __stdcall stdcallFunction()
{}

void __stdcall takesCFunctionPointer(CFunctionPointer f)
{}

void takesStdCallFunctionPointer(StdCallFunctionPointer f)
{}

typedef void (__stdcall *StdCallFunctionPointerTakingCFunctionPointer)(CFunctionPointer f);
typedef void (*CFunctionPointerTakingStdCallFunctionPointer)(StdCallFunctionPointer f);
