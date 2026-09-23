#!/usr/bin/env bash

obj_decl="${OUTPUT_BASE}_decl${OBJ}"
obj_refs="${OUTPUT_BASE}_refs${OBJ}"
obj_refs_ctfe="${OUTPUT_BASE}_refs_ctfe${OBJ}"
$DMD -c -m${MODEL} -of${obj_decl}      ${EXTRA_FILES}/${TEST_NAME}_declarations.d
$DMD -c -m${MODEL} -of${obj_refs}      ${EXTRA_FILES}/${TEST_NAME}_references.d -I${EXTRA_FILES}
$DMD -c -m${MODEL} -of${obj_refs_ctfe} ${EXTRA_FILES}/${TEST_NAME}_references.d -I${EXTRA_FILES} -version=Reference_for_CTFE_only

# TypeInfo_Class only emitted once along with the class/interface declaration:
nm --defined-only ${obj_decl} | grep -F _D24ti_emission_declarations1C7__ClassZ
nm --defined-only ${obj_decl} | grep -F _D24ti_emission_declarations1I11__InterfaceZ
if nm --defined-only ${obj_decl} | grep -F TypeInfo; then
    echo "Expected no non-TypeInfo_Class TypeInfo definitions along with the declarations!"
    exit 1
fi

# all other non-builtin TypeInfos are emitted lazily in an object file referencing it:

nm --defined-only ${obj_refs} | grep -F _D38TypeInfo_C24ti_emission_declarations1I6__initZ
nm --defined-only ${obj_refs} | grep -F _D38TypeInfo_E24ti_emission_declarations1E6__initZ
nm --defined-only ${obj_refs} | grep -F _D38TypeInfo_S24ti_emission_declarations1S6__initZ
nm --defined-only ${obj_refs} | grep -F _D39TypeInfo_xC24ti_emission_declarations1C6__initZ
if nm --defined-only ${obj_refs} | grep -E '__(Class|Interface)Z'; then
    echo "Expected no TypeInfo_Class definitions for referencing object file!"
    exit 1
fi

if nm --defined-only ${obj_refs_ctfe} | grep -E 'TypeInfo|__(Class|Interface)Z'; then
    echo "Expected no TypeInfo definitions for CTFE-only references!"
    exit 1
fi

rm_retry ${obj_decl} ${obj_refs} ${obj_refs_ctfe}
