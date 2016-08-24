module imports.ice10598a;

template TypeTuple(TL...) { alias TL TypeTuple; }

alias TypeTuple!(__traits(getMember, imports.ice10598b, (__traits(allMembers, imports.ice10598b)[0])))[0] notImportedType;
