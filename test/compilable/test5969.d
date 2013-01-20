struct F
{
    int a;
    float b;
}

void main()
{
    F f;
    foreach (_; f.tupleof) { }
    foreach (_; typeof(F.tupleof)) { }
}
