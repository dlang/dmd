void main()
{
    enum union LocalPacket
    {
        case Data(int);

        int value() { return 42; }

        case Ping(long);
    }

    assert(LocalPacket.Data(1).value() == 42);
    assert(LocalPacket.Ping(2).value() == 42);
}