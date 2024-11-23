// https://issues.dlang.org/show_bug.cgi?id=17955
/*
TEST_OUTPUT:
---
fail_compilation/fail17955.d(110): Error: cannot create instance of abstract class `SimpleTimeZone`
        new SimpleTimeZone;
        ^
fail_compilation/fail17955.d(104):        class `SimpleTimeZone` is declared here
class SimpleTimeZone : TimeZone
^
fail_compilation/fail17955.d(101):        function `bool hasDST()` is not implemented
    abstract bool hasDST();
                  ^
fail_compilation/fail17955.d(122): Error: template instance `fail17955.SimpleTimeZone.fromISOExtString!dstring` error instantiating
            SimpleTimeZone.fromISOExtString(zoneStr);
                                           ^
fail_compilation/fail17955.d(54):        instantiated from here: `fromISOExtString!string`
    enum isISOExtStringSerializable = T.fromISOExtString("");
                                                        ^
fail_compilation/fail17955.d(85):        instantiated from here: `isISOExtStringSerializable!(SysTime)`
    static if (isISOExtStringSerializable!T)
               ^
fail_compilation/fail17955.d(78):        instantiated from here: `toRedis!(SysTime)`
    enum isRedisType = toRedis!(typeof(F));
                       ^
fail_compilation/fail17955.d(69):        ... (2 instantiations, -v to show) ...
        static if (PRED!T)
                   ^
fail_compilation/fail17955.d(61):        instantiated from here: `indicesOf!(isRedisType, resetCodeExpireTime)`
    alias unstrippedMemberIndices = indicesOf!(Select!(strip_id,
                                    ^
fail_compilation/fail17955.d(96):        instantiated from here: `RedisStripped!(User, true)`
    RedisObjectCollection!(RedisStripped!User) m_users;
                           ^
fail_compilation/fail17955.d(122): Error: calling non-static function `fromISOExtString` requires an instance of type `SimpleTimeZone`
            SimpleTimeZone.fromISOExtString(zoneStr);
                                           ^
fail_compilation/fail17955.d(124): Error: undefined identifier `DateTimeException`
        catch (DateTimeException e) {}
        ^
fail_compilation/fail17955.d(54): Error: variable `fail17955.isISOExtStringSerializable!(SysTime).isISOExtStringSerializable` - type `void` is inferred from initializer `fromISOExtString("")`, and variables cannot be of type `void`
    enum isISOExtStringSerializable = T.fromISOExtString("");
         ^
fail_compilation/fail17955.d(83): Error: function `fail17955.toRedis!(SysTime).toRedis` has no `return` statement, but is expected to return a value of type `string`
string toRedis(T)()
       ^
---
*/

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

        catch (DateTimeException e) {}
    }
}

template Select(bool condition, T...)
{
    alias Select = Alias!(T[condition]);
}
