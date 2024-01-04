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
                "line": 43,
                "members": [
                    {
                        "char": 17,
                        "kind": "enum member",
                        "line": 43,
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
                "line": 43,
                "name": "E",
                "originalType": "enum E",
                "protection": "public"
            }
        ]
    }
]
---
*/

// https://issues.dlang.org/show_bug.cgi?id=24108
typedef enum { a, } E;
