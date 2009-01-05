public import core.bitmanip;
public import core.exception;
public import core.memory;
public import core.runtime;
public import core.thread;
public import core.vararg;


void main()
{
    // Bring in unit test for module by referencing a function in it
    bsf( 0 ); // bitmanip
    setAssertHandler( null ); // exception
    GC.enable(); // memory
    Runtime.collectHandler = null; // runtime
    new Thread( {} ); // thread
    va_end( null ); // vararg
}
