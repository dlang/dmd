module imports.testptrref_usetmpl;
import imports.testptrref_tmpl;

void* intPtrInstance()
{
    return &TStruct!(int*).gsharedInstance;
}

