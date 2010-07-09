class Foo
{
    int[2] nodes;
    auto left = (){ return nodes[0]; };
    auto right = (){ return nodes[1]; };
}
