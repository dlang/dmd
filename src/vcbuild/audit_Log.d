module dmd.Audit_Log;
import std.array;
import std.algorithm;
import dmd.globals;

void Audit_Log(string message, string paramaters, string functioncall = __FUNCTION__, string modulecall = __MODULE__ )
{
    auto list = paramaters.replace("-log=", "");
    auto callList = list.splitter(',');
    if(any!((a) => a == functioncall || a == modulecall)(callList))
    {

    }
}
