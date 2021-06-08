`enum` declarations support the `.tupleof` property

The `.tupleof` property returns a tuple of all the enum members.
This is especially designed to write loops without `__traits` code,
for example given the declaration

---
enum E {e1, e2}
---

the following code

---
foreach (v; E.tupleof)
{
    // use v
}
---

is now semantically equivalent to more verbose

---
foreach (e; __traits(allMembers, E))
{
    auto v = __traits(getMember, E, e);
    {
        // use v
    }
}
---
