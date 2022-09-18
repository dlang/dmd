module message_with_null;

void main()
{
    throw new Exception("hello\0 world!");
}
