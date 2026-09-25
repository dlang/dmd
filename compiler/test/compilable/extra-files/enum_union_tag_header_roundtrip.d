module enum_union_tag_header_roundtrip;

enum union Message
{
    case None();
    case Value(int value);
}