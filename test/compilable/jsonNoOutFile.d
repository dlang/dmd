/*
REQUIRED_ARGS: -Xi=compilerInfo
PERMUTE_ARGS:
OUTPUT_FILES: jsonNoOutFile_0.json
TRANSFORM_OUTPUT: sanitize_json
TEST_OUTPUT:
---
=== jsonNoOutFile_0.json
{
    "compilerInfo": {
        "__VERSION__": 0,
        "architectures": [
            "VALUES_REMOVED_FOR_TEST"
        ],
        "interface": "dmd",
        "platforms": [
            "VALUES_REMOVED_FOR_TEST"
        ],
        "predefinedVersions": [
            "VALUES_REMOVED_FOR_TEST"
        ],
        "size_t": 0,
        "supportedFeatures": {
            "includeImports": true
        },
        "vendor": "VALUE_REMOVED_FOR_TEST",
        "version": "VALUE_REMOVED_FOR_TEST"
    }
}
---
*/

void main() {}
