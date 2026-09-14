module enum_union_traits;

struct CustomPayload
{
    int id;
}

enum union Message
{
    @("tag_none") case None(),
    case Move(int x, int y),
    @("tag_user") case User { int id; string name; },
    case CustomPayload,
    case int,
    @("tag_slice") case Slice = ubyte[],
    case Payload = CustomPayload,
}

void main()
{
    struct LocalPayload
    {
        int value;
    }

    enum union LocalMessage
    {
        case None(),
        case Payload = LocalPayload,
    }

    static foreach (index, Variant; __traits(allVariants, LocalMessage))
    {
        static if (index == 1)
        {
            static assert(__traits(variantParams, Variant).length == 0);
            static assert(__traits(variantParamNames, Variant).length == 0);
        }
    }

    static assert(is(Message == enum union));
    static assert(!is(int == enum union));
    static assert(!is(CustomPayload == enum union));

    alias Variants = __traits(allVariants, Message);
    static assert(Variants.length == 7);
    static assert(is(Message.User == struct));
    static assert(is(Message.Slice == ubyte[]));
    static assert(__traits(isSame, Variants[2], Message.User));

    static assert(__traits(getTag, Message, Variants[0]) == 0);
    static assert(__traits(getTag, Message, Variants[1]) == 1);
    static assert(__traits(getTag, Message, Variants[2]) == 2);
    static assert(__traits(getTag, Message, Variants[3]) == 3);
    static assert(__traits(getTag, Message, Variants[4]) == 4);
    static assert(__traits(getTag, Message, Variants[5]) == 5);
    static assert(__traits(getTag, Message, Variants[6]) == 6);
    static assert(is(typeof(__traits(getTag, Message, Variants[0])) == ubyte));

    static assert(__traits(variantKind, Variants[0]) == "unit");
    static assert(__traits(variantKind, Variants[1]) == "tuple");
    static assert(__traits(variantKind, Variants[2]) == "struct");
    static assert(__traits(variantKind, Variants[3]) == "bare");
    static assert(__traits(variantKind, Variants[4]) == "bare");
    static assert(__traits(variantKind, Variants[5]) == "alias");
    static assert(__traits(variantKind, Variants[6]) == "alias");

    static assert(__traits(variantParams, Variants[0]).length == 0);
    static assert(is(__traits(variantParams, Variants[1]) == AliasSeq!(int, int)));
    static assert(is(__traits(variantParams, Variants[2]) == AliasSeq!(int, string)));
    static assert(__traits(variantParams, Variants[3]).length == 0);
    static assert(__traits(variantParams, Variants[4]).length == 0);
    static assert(__traits(variantParams, Variants[5]).length == 0);
    static assert(__traits(variantParams, Variants[6]).length == 0);

    static assert(__traits(variantParamNames, Variants[0]).length == 0);
    static assert(__traits(variantParamNames, Variants[1]) == AliasSeq!("x", "y"));
    static assert(__traits(variantParamNames, Variants[2]) == AliasSeq!("id", "name"));
    static assert(__traits(variantParamNames, Variants[3]).length == 0);
    static assert(__traits(variantParamNames, Variants[4]).length == 0);
    static assert(__traits(variantParamNames, Variants[5]).length == 0);
    static assert(__traits(variantParamNames, Variants[6]).length == 0);

    static foreach (Variant; Variants)
    {
        static assert(__traits(compiles, __traits(variantParams, Variant)));
        static assert(__traits(variantParams, Variant).length ==
            __traits(variantParamNames, Variant).length);
    }

    static assert(__traits(identifier, Variants[0]) == "None");
    static assert(__traits(identifier, Variants[1]) == "Move");
    static assert(__traits(identifier, Variants[2]) == "User");
    static assert(__traits(identifier, Variants[3]) == "CustomPayload");
    static assert(__traits(identifier, Variants[4]) == "");
    static assert(__traits(identifier, Variants[5]) == "Slice");
    static assert(__traits(identifier, Variants[6]) == "Payload");

    alias NoneAttrs = __traits(getAttributes, Variants[0]);
    static assert(NoneAttrs.length == 1 && NoneAttrs[0] == "tag_none");
    alias UserAttrs = __traits(getAttributes, Variants[2]);
    static assert(UserAttrs.length == 1 && UserAttrs[0] == "tag_user");
    alias SliceAttrs = __traits(getAttributes, Variants[5]);
    static assert(SliceAttrs.length == 1 && SliceAttrs[0] == "tag_slice");

    Message.User user = Message.User(7, "Ada");
    Message userMessage = user;
    assert(userMessage.__tag == __traits(getTag, Message, Variants[2]));
    Message.Slice bytes = [ubyte(1), 2, 3];
    Message bytesMessage = bytes;
    assert(bytesMessage.__tag == __traits(getTag, Message, Variants[5]));

    static assert(!__traits(compiles, __traits(allVariants, int)));
    static assert(!__traits(compiles, __traits(getTag, Message, double)));
    static assert(!__traits(compiles, __traits(variantKind, main)));
    static assert(!__traits(compiles, __traits(variantParams, main)));
    static assert(!__traits(compiles, __traits(variantParamNames, main)));
}

template AliasSeq(T...)
{
    alias AliasSeq = T;
}