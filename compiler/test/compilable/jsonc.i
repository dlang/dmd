/*
REQUIRED_ARGS: -o- -X -Xf-
TRANSFORM_OUTPUT: sanitize_json
TEST_OUTPUT:
---
[
    {
        "file": "VALUE_REMOVED_FOR_TEST",
        "kind": "module",
        "members": [
            {
                "baseDeco": "i",
                "char": 9,
                "kind": "enum",
                "line": 68,
                "members": [
                    {
                        "char": 17,
                        "kind": "enum member",
                        "line": 68,
                        "name": "a"
                    }
                ],
                "name": "E",
                "protection": "public"
            },
            {
                "char": 22,
                "deco": "VALUE_REMOVED_FOR_TEST",
                "kind": "alias",
                "line": 68,
                "name": "E",
                "originalType": "enum E",
                "protection": "public"
            },
            {
                "baseDeco": "s",
                "char": 15,
                "kind": "enum",
                "line": 70,
                "members": [
                    {
                        "char": 32,
                        "kind": "enum member",
                        "line": 70,
                        "name": "a2"
                    }
                ],
                "name": "E2",
                "protection": "public"
            },
            {
                "char": 38,
                "deco": "VALUE_REMOVED_FOR_TEST",
                "kind": "alias",
                "line": 70,
                "name": "E2",
                "originalType": "const enum E2 : short",
                "protection": "public"
            }
        ]
    }
]
---
*/

// https://issues.dlang.org/show_bug.cgi?id=24108
typedef enum { a, } E;

typedef const enum : short { a2, } E2; // C23 feature
