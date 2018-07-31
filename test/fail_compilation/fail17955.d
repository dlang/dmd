// https://issues.dlang.org/show_bug.cgi?id=17955

alias Alias(alias a) = a;

template isISOExtStringSerializable(T)
{
    enum isISOExtStringSerializable = T.fromISOExtString("");
}

template RedisObjectCollection(){}

struct RedisStripped(T, bool strip_id = true)
{
    alias unstrippedMemberIndices = indicesOf!(Select!(strip_id,
            isRedisTypeAndNotID, isRedisType), T.tupleof);
}

template indicesOf(alias PRED, T...)
{
    template impl(size_t i)
    {
        static if (PRED!T)
            impl TypeTuple;
    }

    alias indicesOf = impl!0;
}

template isRedisType(alias F)
{
    enum isRedisType = toRedis!(typeof(F));
}

template isRedisTypeAndNotID(){}

string toRedis(T)()
{
    static if (isISOExtStringSerializable!T)
        return;
}

struct User
{
    SysTime resetCodeExpireTime;
}

class RedisUserManController
{
    RedisObjectCollection!(RedisStripped!User) m_users;
}

class TimeZone
{
    abstract bool hasDST();
}

class SimpleTimeZone : TimeZone
{
    unittest {}

    immutable(SimpleTimeZone) fromISOExtString(S)(S)
    {
        new SimpleTimeZone;
    }
}

struct SysTime
{

    static fromISOExtString(S)(S)
    {
        dstring zoneStr;

        try
            SimpleTimeZone.fromISOExtString(zoneStr);

        catch DateTimeException;
    }
}

template Select(bool condition, T...)
{
    alias Select = Alias!(T[condition]);
}
