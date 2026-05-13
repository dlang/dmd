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
}
