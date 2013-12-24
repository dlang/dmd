module imports.test7491a;

class B1
{
private:
    import imports.test7491c;   // std.algorithm;
    import algorithm = imports.test7491c;
}
class B2
{
protected:
    import imports.test7491c;   // std.algorithm;
    import algorithm = imports.test7491c;
}
class B3
{
public:
    import imports.test7491c;   // std.algorithm;
    import algorithm = imports.test7491c;
}
