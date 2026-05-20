// plain function
void foo(bool shouldthrow)
{
    if(shouldthrow) {
        throw new Exception("here");
    }
    try {
        foo(true);
    }
    catch(Exception e) {
        // happy
    }
    catch(Throwable t) {
        assert(0, "should not reach here");
    }
}

void main()
{
    foo(false);
    foo2(false);
}

// inferred attrs function template
void foo2()(bool shouldthrow)
{
    if(shouldthrow) {
        throw new Exception("here");
    }
    try {
        foo2(true);
    }
    catch(Exception e) {
        // happy
    }
    catch(Throwable t) {
        assert(0, "should not reach here");
    }
}
