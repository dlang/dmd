module imports.test7491c;

class B1
{
private:
    import imports.test7491e;   // std.algorithm;
    import algorithm = imports.test7491e;
}

class B2
{
protected:
    import imports.test7491e;   // std.algorithm;
    import algorithm = imports.test7491e;
}

class B3
{
public:
    import imports.test7491e;   // std.algorithm;
    import algorithm = imports.test7491e;
}
