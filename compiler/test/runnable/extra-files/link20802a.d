import link20802b;
void main()
{
     // First test from https://issues.dlang.org/show_bug.cgi?id=20802#c3
     CodepointSet('a', 'z');
     dstring s;
     decodeGrapheme(s);
}
