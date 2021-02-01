// https://issues.dlang.org/show_bug.cgi?id=21525

void main()
{
    int[string] aa;
    aa["name"] = 5;

    int*[] pvalues;
    foreach (name, ref value; aa)
    {
        // Deprecation: copying `&value` into allocated memory escapes
        // a reference to parameter variable `value`
        pvalues ~= &value;
    }
}
