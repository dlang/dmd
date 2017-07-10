// REQUIRED_ARGS: -gf
// PERMUTE_ARGS:

import core.time;

void main(string[] args)
{
    // https://issues.dlang.org/show_bug.cgi?id=4014
    // -gf should drag in full definitions of Object, TickDuration and ClockType
    Object o = new Object;
    TickDuration duration; // struct
    ClockType ct; // enumerator

    version (CRuntime_Microsoft)
    {
        IDiaDataSource source;
        IDiaSession session;
        IDiaSymbol globals;
        if (!openDebugInfo(&source, &session, &globals))
        {
            printf("failed to access debug info, skipping further tests.\n");
            return;
        }

        // dumpSymbols(globals, SymTagEnum.SymTagNull, null, 0);

        IDiaSymbol objsym = searchSymbol(globals, "object.Object");
        testSymbolHasChildren(objsym, "object.Object");
        objsym.Release();

        IDiaSymbol ticksym = searchSymbol(globals, "core.time.TickDuration");
        testSymbolHasChildren(ticksym, "core.time.TickDuration");
        ticksym.Release();

        IDiaSymbol ctsym = searchSymbol(globals, "core.time.ClockType");
        testSymbolHasChildren(ctsym, "core.time.ClockType");
        ctsym.Release();

        testLineNumbers(session, globals);

        source.Release();
        session.Release();
        globals.Release();
    }
}

///////////////////////////////////////////////////////////////
// https://issues.dlang.org/show_bug.cgi?id=15432
void call15432(string col) {}

int test15432() // line 8
{
    call15432(null);
    return 0;
}
enum lineAfterTest15432 = __LINE__;

version(CRuntime_Microsoft):

void testSymbolHasChildren(IDiaSymbol sym, string name)
{
    sym || assert(false, "no debug info found for " ~ name);

    LONG count;
    IDiaEnumSymbols enumSymbols;
    HRESULT hr = sym.findChildren(SymTagEnum.SymTagNull, null, NameSearchOptions.nsNone, &enumSymbols);
    hr == S_OK || assert(false, "incomplete debug info for " ~ name);
    enumSymbols.get_Count(&count) == S_OK || assert(false);
    count > 0  || assert(false, "incomplete debug info for " ~ name);

    enumSymbols.Release();
}

void testLineNumbers(IDiaSession session, IDiaSymbol globals)
{
    IDiaSymbol funcsym = searchSymbol(globals, test15432.mangleof);
    assert(funcsym, "symbol test15432 not found");
    ubyte[] funcRange;
    Line[] lines = findSymbolLineNumbers(session, funcsym, &funcRange);
    assert(lines, "no line number info for test15432");

    //dumpLineNumbers(lines, funcRange);

    assert (lines[$-1].line == lineAfterTest15432 - 1);
    ubyte codeByte = lines[$-1].addr[0];
    assert(codeByte == 0x48 || codeByte == 0x5d || codeByte == 0xc3); // should be one of "mov rsp,rbp", "pop rbp" or "ret"
}

import core.stdc.stdio;
import core.stdc.wchar_;

import core.sys.windows.windows;
import core.sys.windows.wtypes;
import core.sys.windows.objbase;
import core.sys.windows.unknwn;

pragma(lib, "ole32.lib");
pragma(lib, "oleaut32.lib");

// defintions translated from the DIA SDK header dia2.h
GUID uuid_DiaSource_V120 = { 0xe6756135, 0x1e65, 0x4d17, [0x85, 0x76, 0x61, 0x07, 0x61, 0x39, 0x8c, 0x3c] };
GUID uuid_DiaSource_V140 = { 0x3bfcea48, 0x620f, 0x4b6b, [0x81, 0xf7, 0xb9, 0xaf, 0x75, 0x45, 0x4c, 0x7d] };

interface IDiaDataSource : IUnknown
{
    static const GUID iid = { 0x79F1BB5F, 0xB66E, 0x48e5, [0xB6, 0xA9, 0x15, 0x45, 0xC3, 0x23, 0xCA, 0x3D] };

    HRESULT get_lastError(BSTR* pRetVal);
    HRESULT loadDataFromPdb(LPCOLESTR pdbPath);
    HRESULT loadAndValidateDataFromPdb(LPCOLESTR pdbPath, GUID* pcsig70, DWORD sig,
            DWORD age);
    HRESULT loadDataForExe(LPCOLESTR executable, LPCOLESTR searchPath, IUnknown pCallback);
    HRESULT loadDataFromIStream(IStream pIStream);
    HRESULT openSession(IDiaSession* ppSession);
    HRESULT loadDataFromCodeViewInfo(LPCOLESTR executable,
            LPCOLESTR searchPath, DWORD cbCvInfo, BYTE* pbCvInfo, IUnknown pCallback);
    HRESULT loadDataFromMiscInfo(LPCOLESTR executable,
            LPCOLESTR searchPath, DWORD timeStampExe, DWORD timeStampDbg,
            DWORD sizeOfExe, DWORD cbMiscInfo, BYTE* pbMiscInfo, IUnknown pCallback);
}

interface IDiaSession : IUnknown
{
public:
    static const GUID iid = { 0x2F609EE1, 0xD1C8, 0x4E24, [0x82, 0x88, 0x33, 0x26, 0xBA, 0xDC, 0xD2, 0x11] };

    HRESULT get_loadAddress(ULONGLONG* pRetVal);
    HRESULT put_loadAddress(ULONGLONG NewVal);
    HRESULT get_globalScope(IDiaSymbol* pRetVal);
    HRESULT getEnumTables(IDiaEnumTables* ppEnumTables);
    HRESULT getSymbolsByAddr(IDiaEnumSymbolsByAddr* ppEnumbyAddr);
    HRESULT findChildren(IDiaSymbol parent, SymTagEnum symtag,
            LPCOLESTR name, DWORD compareFlags, IDiaEnumSymbols* ppResult);
    HRESULT findChildrenEx(IDiaSymbol parent, SymTagEnum symtag,
            LPCOLESTR name, DWORD compareFlags, IDiaEnumSymbols* ppResult);
    HRESULT findChildrenExByAddr(IDiaSymbol parent, SymTagEnum symtag, LPCOLESTR name,
            DWORD compareFlags, DWORD isect, DWORD offset, IDiaEnumSymbols* ppResult);
    HRESULT findChildrenExByVA(IDiaSymbol parent, SymTagEnum symtag,
            LPCOLESTR name, DWORD compareFlags, ULONGLONG va,
            IDiaEnumSymbols* ppResult);
    HRESULT findChildrenExByRVA(IDiaSymbol parent, SymTagEnum symtag,
            LPCOLESTR name, DWORD compareFlags, DWORD rva, IDiaEnumSymbols* ppResult);
    HRESULT findSymbolByAddr(DWORD isect, DWORD offset,
            SymTagEnum symtag, IDiaSymbol* ppSymbol);
    HRESULT findSymbolByRVA(DWORD rva, SymTagEnum symtag, IDiaSymbol* ppSymbol);
    HRESULT findSymbolByVA(ULONGLONG va, SymTagEnum symtag, IDiaSymbol* ppSymbol);
    HRESULT findSymbolByToken(ULONG token, SymTagEnum symtag, IDiaSymbol* ppSymbol);
    HRESULT symsAreEquiv(IDiaSymbol symbolA, IDiaSymbol symbolB);
    HRESULT symbolById(DWORD id, IDiaSymbol* ppSymbol);
    HRESULT findSymbolByRVAEx(DWORD rva, SymTagEnum symtag,
            IDiaSymbol* ppSymbol, LONG* displacement);
    HRESULT findSymbolByVAEx(ULONGLONG va, SymTagEnum symtag,
            IDiaSymbol* ppSymbol, LONG* displacement);
    HRESULT findFile(IDiaSymbol pCompiland, LPCOLESTR name,
            DWORD compareFlags, IDiaEnumSourceFiles* ppResult);
    HRESULT findFileById(DWORD uniqueId, IDiaSourceFile* ppResult);
    HRESULT findLines(IDiaSymbol compiland, IDiaSourceFile file,
            IDiaEnumLineNumbers* ppResult);
    HRESULT findLinesByAddr(DWORD seg, DWORD offset, DWORD length,
            IDiaEnumLineNumbers* ppResult);
    HRESULT findLinesByRVA(DWORD rva, DWORD length, IDiaEnumLineNumbers* ppResult);
    HRESULT findLinesByVA(ULONGLONG va, DWORD length, IDiaEnumLineNumbers* ppResult);
    HRESULT findLinesByLinenum(IDiaSymbol compiland, IDiaSourceFile file,
            DWORD linenum, DWORD column, IDiaEnumLineNumbers* ppResult);
    HRESULT findInjectedSource(LPCOLESTR srcFile, IDiaEnumInjectedSources* ppResult);
    HRESULT getEnumDebugStreams(IDiaEnumDebugStreams* ppEnumDebugStreams);
    HRESULT findInlineFramesByAddr(IDiaSymbol parent, DWORD isect,
            DWORD offset, IDiaEnumSymbols* ppResult);
    HRESULT findInlineFramesByRVA(IDiaSymbol parent, DWORD rva,
            IDiaEnumSymbols* ppResult);
    HRESULT findInlineFramesByVA(IDiaSymbol parent, ULONGLONG va,
            IDiaEnumSymbols* ppResult);
    HRESULT findInlineeLines(IDiaSymbol parent, IDiaEnumLineNumbers* ppResult);
    HRESULT findInlineeLinesByAddr(IDiaSymbol parent, DWORD isect,
            DWORD offset, DWORD length, IDiaEnumLineNumbers* ppResult);
    HRESULT findInlineeLinesByRVA(IDiaSymbol parent, DWORD rva,
            DWORD length, IDiaEnumLineNumbers* ppResult);
    HRESULT findInlineeLinesByVA(IDiaSymbol parent, ULONGLONG va,
            DWORD length, IDiaEnumLineNumbers* ppResult);
    HRESULT findInlineeLinesByLinenum(IDiaSymbol compiland, IDiaSourceFile file,
            DWORD linenum, DWORD column, IDiaEnumLineNumbers* ppResult);
    HRESULT findInlineesByName(LPCOLESTR name, DWORD option, IDiaEnumSymbols* ppResult);
    HRESULT findAcceleratorInlineeLinesByLinenum(IDiaSymbol parent,
            IDiaSourceFile file, DWORD linenum, DWORD column,
            IDiaEnumLineNumbers* ppResult);
    HRESULT findSymbolsForAcceleratorPointerTag(IDiaSymbol parent,
            DWORD tagValue, IDiaEnumSymbols* ppResult);
    HRESULT findSymbolsByRVAForAcceleratorPointerTag(IDiaSymbol parent,
            DWORD tagValue, DWORD rva, IDiaEnumSymbols* ppResult);
    HRESULT findAcceleratorInlineesByName(LPCOLESTR name,
            DWORD option, IDiaEnumSymbols* ppResult);
    HRESULT addressForVA(ULONGLONG va, DWORD* pISect, DWORD* pOffset);
    HRESULT addressForRVA(DWORD rva, DWORD* pISect, DWORD* pOffset);
    HRESULT findILOffsetsByAddr(DWORD isect, DWORD offset,
            DWORD length, IDiaEnumLineNumbers* ppResult);
    HRESULT findILOffsetsByRVA(DWORD rva, DWORD length, IDiaEnumLineNumbers* ppResult);
    HRESULT findILOffsetsByVA(ULONGLONG va, DWORD length,
            IDiaEnumLineNumbers* ppResult);
    HRESULT findInputAssemblyFiles(IDiaEnumInputAssemblyFiles* ppResult);
    HRESULT findInputAssembly(DWORD index, IDiaInputAssemblyFile* ppResult);
    HRESULT findInputAssemblyById(DWORD uniqueId, IDiaInputAssemblyFile* ppResult);
    HRESULT getFuncMDTokenMapSize(DWORD* pcb);
    HRESULT getFuncMDTokenMap(DWORD cb, DWORD* pcb, BYTE* pb);
    HRESULT getTypeMDTokenMapSize(DWORD* pcb);
    HRESULT getTypeMDTokenMap(DWORD cb, DWORD* pcb, BYTE* pb);
    HRESULT getNumberOfFunctionFragments_VA(ULONGLONG vaFunc,
            DWORD cbFunc, DWORD* pNumFragments);
    HRESULT getNumberOfFunctionFragments_RVA(DWORD rvaFunc,
            DWORD cbFunc, DWORD* pNumFragments);
    HRESULT getFunctionFragments_VA(ULONGLONG vaFunc, DWORD cbFunc,
            DWORD cFragments, ULONGLONG* pVaFragment, DWORD* pLenFragment);
    HRESULT getFunctionFragments_RVA(DWORD rvaFunc, DWORD cbFunc,
            DWORD cFragments, DWORD* pRvaFragment, DWORD* pLenFragment);
    HRESULT getExports(IDiaEnumSymbols* ppResult);
    HRESULT getHeapAllocationSites(IDiaEnumSymbols* ppResult);
    HRESULT findInputAssemblyFile(IDiaSymbol pSymbol, IDiaInputAssemblyFile* ppResult);
}

interface IDiaSymbol : IUnknown
{
    static GUID iid = { 0xcb787b2f, 0xbd6c, 0x4635, [0xba, 0x52, 0x93, 0x31, 0x26, 0xbd, 0x2d, 0xcd] };

    HRESULT get_symIndexId(DWORD* pRetVal);
    HRESULT get_symTag(DWORD* pRetVal);
    HRESULT get_name(BSTR* pRetVal);
    HRESULT get_lexicalParent(IDiaSymbol* pRetVal);
    HRESULT get_classParent(IDiaSymbol* pRetVal);
    HRESULT get_type(IDiaSymbol* pRetVal);
    HRESULT get_dataKind(DWORD* pRetVal);
    HRESULT get_locationType(DWORD* pRetVal);
    HRESULT get_addressSection(DWORD* pRetVal);
    HRESULT get_addressOffset(DWORD* pRetVal);
    HRESULT get_relativeVirtualAddress(DWORD* pRetVal);
    HRESULT get_virtualAddress(ULONGLONG* pRetVal);
    HRESULT get_registerId(DWORD* pRetVal);
    HRESULT get_offset(LONG* pRetVal);
    HRESULT get_length(ULONGLONG* pRetVal);
    HRESULT get_slot(DWORD* pRetVal);
    HRESULT get_volatileType(BOOL* pRetVal);
    HRESULT get_constType(BOOL* pRetVal);
    HRESULT get_unalignedType(BOOL* pRetVal);
    HRESULT get_access(DWORD* pRetVal);
    HRESULT get_libraryName(BSTR* pRetVal);
    HRESULT get_platform(DWORD* pRetVal);
    HRESULT get_language(DWORD* pRetVal);
    HRESULT get_editAndContinueEnabled(BOOL* pRetVal);
    HRESULT get_frontEndMajor(DWORD* pRetVal);
    HRESULT get_frontEndMinor(DWORD* pRetVal);
    HRESULT get_frontEndBuild(DWORD* pRetVal);
    HRESULT get_backEndMajor(DWORD* pRetVal);
    HRESULT get_backEndMinor(DWORD* pRetVal);
    HRESULT get_backEndBuild(DWORD* pRetVal);
    HRESULT get_sourceFileName(BSTR* pRetVal);
    HRESULT get_unused(BSTR* pRetVal);
    HRESULT get_thunkOrdinal(DWORD* pRetVal);
    HRESULT get_thisAdjust(LONG* pRetVal);
    HRESULT get_virtualBaseOffset(DWORD* pRetVal);
    HRESULT get_virtual(BOOL* pRetVal);
    HRESULT get_intro(BOOL* pRetVal);
    HRESULT get_pure(BOOL* pRetVal);
    HRESULT get_callingConvention(DWORD* pRetVal);
    HRESULT get_value(VARIANT* pRetVal);
    HRESULT get_baseType(DWORD* pRetVal);
    HRESULT get_token(DWORD* pRetVal);
    HRESULT get_timeStamp(DWORD* pRetVal);
    HRESULT get_guid(GUID* pRetVal);
    HRESULT get_symbolsFileName(BSTR* pRetVal);
    HRESULT get_reference(BOOL* pRetVal);
    HRESULT get_count(DWORD* pRetVal);
    HRESULT get_bitPosition(DWORD* pRetVal);
    HRESULT get_arrayIndexType(IDiaSymbol* pRetVal);
    HRESULT get_packed(BOOL* pRetVal);
    HRESULT get_constructor(BOOL* pRetVal);
    HRESULT get_overloadedOperator(BOOL* pRetVal);
    HRESULT get_nested(BOOL* pRetVal);
    HRESULT get_hasNestedTypes(BOOL* pRetVal);
    HRESULT get_hasAssignmentOperator(BOOL* pRetVal);
    HRESULT get_hasCastOperator(BOOL* pRetVal);
    HRESULT get_scoped(BOOL* pRetVal);
    HRESULT get_virtualBaseClass(BOOL* pRetVal);
    HRESULT get_indirectVirtualBaseClass(BOOL* pRetVal);
    HRESULT get_virtualBasePointerOffset(LONG* pRetVal);
    HRESULT get_virtualTableShape(IDiaSymbol* pRetVal);
    HRESULT get_lexicalParentId(DWORD* pRetVal);
    HRESULT get_classParentId(DWORD* pRetVal);
    HRESULT get_typeId(DWORD* pRetVal);
    HRESULT get_arrayIndexTypeId(DWORD* pRetVal);
    HRESULT get_virtualTableShapeId(DWORD* pRetVal);
    HRESULT get_code(BOOL* pRetVal);
    HRESULT get_function(BOOL* pRetVal);
    HRESULT get_managed(BOOL* pRetVal);
    HRESULT get_msil(BOOL* pRetVal);
    HRESULT get_virtualBaseDispIndex(DWORD* pRetVal);
    HRESULT get_undecoratedName(BSTR* pRetVal);
    HRESULT get_age(DWORD* pRetVal);
    HRESULT get_signature(DWORD* pRetVal);
    HRESULT get_compilerGenerated(BOOL* pRetVal);
    HRESULT get_addressTaken(BOOL* pRetVal);
    HRESULT get_rank(DWORD* pRetVal);
    HRESULT get_lowerBound(IDiaSymbol* pRetVal);
    HRESULT get_upperBound(IDiaSymbol* pRetVal);
    HRESULT get_lowerBoundId(DWORD* pRetVal);
    HRESULT get_upperBoundId(DWORD* pRetVal);
    HRESULT get_dataBytes(DWORD cbData, DWORD* pcbData, BYTE* pbData);
    HRESULT findChildren(SymTagEnum symtag, LPCOLESTR name,
            DWORD compareFlags, IDiaEnumSymbols* ppResult);
    HRESULT findChildrenEx(SymTagEnum symtag, LPCOLESTR name,
            DWORD compareFlags, IDiaEnumSymbols* ppResult);
    HRESULT findChildrenExByAddr(SymTagEnum symtag, LPCOLESTR name,
            DWORD compareFlags, DWORD isect, DWORD offset,
            IDiaEnumSymbols* ppResult);
    HRESULT findChildrenExByVA(SymTagEnum symtag, LPCOLESTR name,
            DWORD compareFlags, ULONGLONG va, IDiaEnumSymbols* ppResult);
    HRESULT findChildrenExByRVA(SymTagEnum symtag, LPCOLESTR name,
            DWORD compareFlags, DWORD rva, IDiaEnumSymbols* ppResult);
    HRESULT get_targetSection(DWORD* pRetVal);
    HRESULT get_targetOffset(DWORD* pRetVal);
    HRESULT get_targetRelativeVirtualAddress(DWORD* pRetVal);
    HRESULT get_targetVirtualAddress(ULONGLONG* pRetVal);
    HRESULT get_machineType(DWORD* pRetVal);
    HRESULT get_oemId(DWORD* pRetVal);
    HRESULT get_oemSymbolId(DWORD* pRetVal);
    HRESULT get_types(DWORD cTypes, DWORD* pcTypes, IDiaSymbol* pTypes);
    HRESULT get_typeIds(DWORD cTypeIds, DWORD* pcTypeIds, DWORD* pdwTypeIds);
    HRESULT get_objectPointerType(IDiaSymbol* pRetVal);
    HRESULT get_udtKind(DWORD* pRetVal);
    HRESULT get_undecoratedNameEx(DWORD undecorateOptions, BSTR* name);
    HRESULT get_noReturn(BOOL* pRetVal);
    HRESULT get_customCallingConvention(BOOL* pRetVal);
    HRESULT get_noInline(BOOL* pRetVal);
    HRESULT get_optimizedCodeDebugInfo(BOOL* pRetVal);
    HRESULT get_notReached(BOOL* pRetVal);
    HRESULT get_interruptReturn(BOOL* pRetVal);
    HRESULT get_farReturn(BOOL* pRetVal);
    HRESULT get_isStatic(BOOL* pRetVal);
    HRESULT get_hasDebugInfo(BOOL* pRetVal);
    HRESULT get_isLTCG(BOOL* pRetVal);
    HRESULT get_isDataAligned(BOOL* pRetVal);
    HRESULT get_hasSecurityChecks(BOOL* pRetVal);
    HRESULT get_compilerName(BSTR* pRetVal);
    HRESULT get_hasAlloca(BOOL* pRetVal);
    HRESULT get_hasSetJump(BOOL* pRetVal);
    HRESULT get_hasLongJump(BOOL* pRetVal);
    HRESULT get_hasInlAsm(BOOL* pRetVal);
    HRESULT get_hasEH(BOOL* pRetVal);
    HRESULT get_hasSEH(BOOL* pRetVal);
    HRESULT get_hasEHa(BOOL* pRetVal);
    HRESULT get_isNaked(BOOL* pRetVal);
    HRESULT get_isAggregated(BOOL* pRetVal);
    HRESULT get_isSplitted(BOOL* pRetVal);
    HRESULT get_container(IDiaSymbol* pRetVal);
    HRESULT get_inlSpec(BOOL* pRetVal);
    HRESULT get_noStackOrdering(BOOL* pRetVal);
    HRESULT get_virtualBaseTableType(IDiaSymbol* pRetVal);
    HRESULT get_hasManagedCode(BOOL* pRetVal);
    HRESULT get_isHotpatchable(BOOL* pRetVal);
    HRESULT get_isCVTCIL(BOOL* pRetVal);
    HRESULT get_isMSILNetmodule(BOOL* pRetVal);
    HRESULT get_isCTypes(BOOL* pRetVal);
    HRESULT get_isStripped(BOOL* pRetVal);
    HRESULT get_frontEndQFE(DWORD* pRetVal);
    HRESULT get_backEndQFE(DWORD* pRetVal);
    HRESULT get_wasInlined(BOOL* pRetVal);
    HRESULT get_strictGSCheck(BOOL* pRetVal);
    HRESULT get_isCxxReturnUdt(BOOL* pRetVal);
    HRESULT get_isConstructorVirtualBase(BOOL* pRetVal);
    HRESULT get_RValueReference(BOOL* pRetVal);
    HRESULT get_unmodifiedType(IDiaSymbol* pRetVal);
    HRESULT get_framePointerPresent(BOOL* pRetVal);
    HRESULT get_isSafeBuffers(BOOL* pRetVal);
    HRESULT get_intrinsic(BOOL* pRetVal);
    HRESULT get_sealed(BOOL* pRetVal);
    HRESULT get_hfaFloat(BOOL* pRetVal);
    HRESULT get_hfaDouble(BOOL* pRetVal);
    HRESULT get_liveRangeStartAddressSection(DWORD* pRetVal);
    HRESULT get_liveRangeStartAddressOffset(DWORD* pRetVal);
    HRESULT get_liveRangeStartRelativeVirtualAddress(DWORD* pRetVal);
    HRESULT get_countLiveRanges(DWORD* pRetVal);
    HRESULT get_liveRangeLength(ULONGLONG* pRetVal);
    HRESULT get_offsetInUdt(DWORD* pRetVal);
    HRESULT get_paramBasePointerRegisterId(DWORD* pRetVal);
    HRESULT get_localBasePointerRegisterId(DWORD* pRetVal);
    HRESULT get_isLocationControlFlowDependent(BOOL* pRetVal);
    HRESULT get_stride(DWORD* pRetVal);
    HRESULT get_numberOfRows(DWORD* pRetVal);
    HRESULT get_numberOfColumns(DWORD* pRetVal);
    HRESULT get_isMatrixRowMajor(BOOL* pRetVal);
    HRESULT get_numericProperties(DWORD cnt, DWORD* pcnt, DWORD* pProperties);
    HRESULT get_modifierValues(DWORD cnt, DWORD* pcnt, WORD* pModifiers);
    HRESULT get_isReturnValue(BOOL* pRetVal);
    HRESULT get_isOptimizedAway(BOOL* pRetVal);
    HRESULT get_builtInKind(DWORD* pRetVal);
    HRESULT get_registerType(DWORD* pRetVal);
    HRESULT get_baseDataSlot(DWORD* pRetVal);
    HRESULT get_baseDataOffset(DWORD* pRetVal);
    HRESULT get_textureSlot(DWORD* pRetVal);
    HRESULT get_samplerSlot(DWORD* pRetVal);
    HRESULT get_uavSlot(DWORD* pRetVal);
    HRESULT get_sizeInUdt(DWORD* pRetVal);
    HRESULT get_memorySpaceKind(DWORD* pRetVal);
    HRESULT get_unmodifiedTypeId(DWORD* pRetVal);
    HRESULT get_subTypeId(DWORD* pRetVal);
    HRESULT get_subType(IDiaSymbol* pRetVal);
    HRESULT get_numberOfModifiers(DWORD* pRetVal);
    HRESULT get_numberOfRegisterIndices(DWORD* pRetVal);
    HRESULT get_isHLSLData(BOOL* pRetVal);
    HRESULT get_isPointerToDataMember(BOOL* pRetVal);
    HRESULT get_isPointerToMemberFunction(BOOL* pRetVal);
    HRESULT get_isSingleInheritance(BOOL* pRetVal);
    HRESULT get_isMultipleInheritance(BOOL* pRetVal);
    HRESULT get_isVirtualInheritance(BOOL* pRetVal);
    HRESULT get_restrictedType(BOOL* pRetVal);
    HRESULT get_isPointerBasedOnSymbolValue(BOOL* pRetVal);
    HRESULT get_baseSymbol(IDiaSymbol* pRetVal);
    HRESULT get_baseSymbolId(DWORD* pRetVal);
    HRESULT get_objectFileName(BSTR* pRetVal);
    HRESULT get_isAcceleratorGroupSharedLocal(BOOL* pRetVal);
    HRESULT get_isAcceleratorPointerTagLiveRange(BOOL* pRetVal);
    HRESULT get_isAcceleratorStubFunction(BOOL* pRetVal);
    HRESULT get_numberOfAcceleratorPointerTags(DWORD* pRetVal);
    HRESULT get_isSdl(BOOL* pRetVal);
    HRESULT get_isWinRTPointer(BOOL* pRetVal);
    HRESULT get_isRefUdt(BOOL* pRetVal);
    HRESULT get_isValueUdt(BOOL* pRetVal);
    HRESULT get_isInterfaceUdt(BOOL* pRetVal);
    HRESULT findInlineFramesByAddr(DWORD isect, DWORD offset,
            IDiaEnumSymbols* ppResult);
    HRESULT findInlineFramesByRVA(DWORD rva, IDiaEnumSymbols* ppResult);
    HRESULT findInlineFramesByVA(ULONGLONG va, IDiaEnumSymbols* ppResult);
    HRESULT findInlineeLines(IDiaEnumLineNumbers* ppResult);
    HRESULT findInlineeLinesByAddr(DWORD isect, DWORD offset,
            DWORD length, IDiaEnumLineNumbers* ppResult);
    HRESULT findInlineeLinesByRVA(DWORD rva, DWORD length,
            IDiaEnumLineNumbers* ppResult);
    HRESULT findInlineeLinesByVA(ULONGLONG va, DWORD length,
            IDiaEnumLineNumbers* ppResult);
    HRESULT findSymbolsForAcceleratorPointerTag(DWORD tagValue,
            IDiaEnumSymbols* ppResult);
    HRESULT findSymbolsByRVAForAcceleratorPointerTag(DWORD tagValue,
            DWORD rva, IDiaEnumSymbols* ppResult);
    HRESULT get_acceleratorPointerTags(DWORD cnt, DWORD* pcnt, DWORD* pPointerTags);
    HRESULT getSrcLineOnTypeDefn(IDiaLineNumber* ppResult);
    HRESULT get_isPGO(BOOL* pRetVal);
    HRESULT get_hasValidPGOCounts(BOOL* pRetVal);
    HRESULT get_isOptimizedForSpeed(BOOL* pRetVal);
    HRESULT get_PGOEntryCount(DWORD* pRetVal);
    HRESULT get_PGOEdgeCount(DWORD* pRetVal);
    HRESULT get_PGODynamicInstructionCount(ULONGLONG* pRetVal);
    HRESULT get_staticSize(DWORD* pRetVal);
    HRESULT get_finalLiveStaticSize(DWORD* pRetVal);
    HRESULT get_phaseName(BSTR* pRetVal);
    HRESULT get_hasControlFlowCheck(BOOL* pRetVal);
    HRESULT get_constantExport(BOOL* pRetVal);
    HRESULT get_dataExport(BOOL* pRetVal);
    HRESULT get_privateExport(BOOL* pRetVal);
    HRESULT get_noNameExport(BOOL* pRetVal);
    HRESULT get_exportHasExplicitlyAssignedOrdinal(BOOL* pRetVal);
    HRESULT get_exportIsForwarder(BOOL* pRetVal);
    HRESULT get_ordinal(DWORD* pRetVal);
    HRESULT get_frameSize(DWORD* pRetVal);
    HRESULT get_exceptionHandlerAddressSection(DWORD* pRetVal);
    HRESULT get_exceptionHandlerAddressOffset(DWORD* pRetVal);
    HRESULT get_exceptionHandlerRelativeVirtualAddress(DWORD* pRetVal);
    HRESULT get_exceptionHandlerVirtualAddress(ULONGLONG* pRetVal);
    HRESULT findInputAssemblyFile(IDiaInputAssemblyFile* ppResult);
    HRESULT get_characteristics(DWORD* pRetVal);
    HRESULT get_coffGroup(IDiaSymbol* pRetVal);
    HRESULT get_bindID(DWORD* pRetVal);
    HRESULT get_bindSpace(DWORD* pRetVal);
    HRESULT get_bindSlot(DWORD* pRetVal);
}

interface IDiaEnumSymbols : IUnknown
{
    HRESULT get__NewEnum(IUnknown* pRetVal);
    HRESULT get_Count(LONG* pRetVal);
    HRESULT Item(DWORD index, IDiaSymbol* symbol);
    HRESULT Next(ULONG celt, IDiaSymbol* rgelt, ULONG* pceltFetched);
    HRESULT Skip(ULONG celt);
    HRESULT Reset();
    HRESULT Clone(IDiaEnumSymbols* ppenum);
};

// unused interfaces, stubbed out for now
interface IStream : IUnknown
{
}

interface IDiaInputAssemblyFile : IUnknown
{
}

interface IDiaEnumTables : IUnknown
{
}

interface IDiaEnumSymbolsByAddr : IUnknown
{
}

interface IDiaEnumLineNumbers : IUnknown
{
    HRESULT get__NewEnum(IUnknown *pRetVal);
    HRESULT get_Count(LONG *pRetVal);
    HRESULT Item(DWORD index, IDiaLineNumber *lineNumber);
    HRESULT Next(ULONG celt, IDiaLineNumber *rgelt, ULONG *pceltFetched);
    HRESULT Skip(ULONG celt);
    HRESULT Reset();
    HRESULT Clone(IDiaEnumLineNumbers *ppenum);
}

interface IDiaSourceFile : IUnknown
{
}

interface IDiaLineNumber : IUnknown
{
    HRESULT get_compiland(IDiaSymbol *pRetVal);
    HRESULT get_sourceFile(IDiaSourceFile *pRetVal);
    HRESULT get_lineNumber(DWORD *pRetVal);
    HRESULT get_lineNumberEnd(DWORD *pRetVal);
    HRESULT get_columnNumber(DWORD *pRetVal);
    HRESULT get_columnNumberEnd(DWORD *pRetVal);
    HRESULT get_addressSection(DWORD *pRetVal);
    HRESULT get_addressOffset(DWORD *pRetVal);
    HRESULT get_relativeVirtualAddress(DWORD *pRetVal);
    HRESULT get_virtualAddress(ULONGLONG *pRetVal);
    HRESULT get_length(DWORD *pRetVal);
    HRESULT get_sourceFileId(DWORD *pRetVal);
    HRESULT get_statement(BOOL *pRetVal);
    HRESULT get_compilandId(DWORD *pRetVal);
}

interface IDiaEnumSourceFiles : IUnknown
{
}

interface IDiaEnumInjectedSources : IUnknown
{
}

interface IDiaEnumDebugStreams : IUnknown
{
}

interface IDiaEnumInputAssemblyFiles : IUnknown
{
}

struct VARIANT
{
}

enum SymTagEnum
{
    SymTagNull,
    SymTagExe,
    SymTagCompiland,
    SymTagCompilandDetails,
    SymTagCompilandEnv,
    SymTagFunction,
    SymTagBlock,
    SymTagData,
    SymTagAnnotation,
    SymTagLabel,
    SymTagPublicSymbol,
    SymTagUDT,
    SymTagEnum,
    SymTagFunctionType,
    SymTagPointerType,
    SymTagArrayType,
    SymTagBaseType,
    SymTagTypedef,
    SymTagBaseClass,
    SymTagFriend,
    SymTagFunctionArgType,
    SymTagFuncDebugStart,
    SymTagFuncDebugEnd,
    SymTagUsingNamespace,
    SymTagVTableShape,
    SymTagVTable,
    SymTagCustom,
    SymTagThunk,
    SymTagCustomType,
    SymTagManagedType,
    SymTagDimension,
    SymTagCallSite,
    SymTagInlineSite,
    SymTagBaseInterface,
    SymTagVectorType,
    SymTagMatrixType,
    SymTagHLSLType,
    SymTagCaller,
    SymTagCallee,
    SymTagExport,
    SymTagHeapAllocationSite,
    SymTagCoffGroup,
    SymTagMax
};

enum LocationType
{
    LocIsNull,
    LocIsStatic,
    LocIsTLS,
    LocIsRegRel,
    LocIsThisRel,
    LocIsEnregistered,
    LocIsBitField,
    LocIsSlot,
    LocIsIlRel,
    LocInMetaData,
    LocIsConstant,
    LocTypeMax
};

enum DataKind
{
    DataIsUnknown,
    DataIsLocal,
    DataIsStaticLocal,
    DataIsParam,
    DataIsObjectPtr,
    DataIsFileStatic,
    DataIsGlobal,
    DataIsMember,
    DataIsStaticMember,
    DataIsConstant
};

enum UdtKind
{
    UdtStruct,
    UdtClass,
    UdtUnion,
    UdtInterface
};

enum BasicType
{
    btNoType = 0,
    btVoid = 1,
    btChar = 2,
    btWChar = 3,
    btInt = 6,
    btUInt = 7,
    btFloat = 8,
    btBCD = 9,
    btBool = 10,
    btLong = 13,
    btULong = 14,
    btCurrency = 25,
    btDate = 26,
    btVariant = 27,
    btComplex = 28,
    btBit = 29,
    btBSTR = 30,
    btHresult = 31,
    btChar16 = 32, // char16_t
    btChar32 = 33, // char32_t
};

enum NameSearchOptions
{
    nsNone = 0,
    nsfCaseSensitive = 0x1,
    nsfCaseInsensitive = 0x2,
    nsfFNameExt = 0x4,
    nsfRegularExpression = 0x8,
    nsfUndecoratedName = 0x10,
    nsCaseSensitive = nsfCaseSensitive,
    nsCaseInsensitive = nsfCaseInsensitive,
    nsFNameExt = (nsfCaseInsensitive | nsfFNameExt),
    nsRegularExpression = (nsfRegularExpression | nsfCaseSensitive),
    nsCaseInRegularExpression = (nsfRegularExpression | nsfCaseInsensitive)
};

bool openDebugInfo(IDiaDataSource* source, IDiaSession* session, IDiaSymbol* globals)
{
    wchar[MAX_PATH] exepath;
    DWORD len = GetModuleFileNameW(null, exepath.ptr, MAX_PATH);
    len < MAX_PATH || assert("executable path too long");

    HRESULT hr = CoInitialize(NULL);

    hr = CoCreateInstance(&uuid_DiaSource_V120, null, CLSCTX.CLSCTX_INPROC_SERVER,
                          &IDiaDataSource.iid, cast(void**)source);
    if (hr != S_OK)
        hr = CoCreateInstance(&uuid_DiaSource_V140, null, CLSCTX.CLSCTX_INPROC_SERVER,
                              &IDiaDataSource.iid, cast(void**)source);
    if (hr != S_OK)
        return false;

    hr = source.loadDataForExe(exepath.ptr, null, null);
    hr == S_OK || assert(false, "loadDataForExe failed");

    // Open a session for querying symbols
    hr = source.openSession(session);
    hr == S_OK || assert(false, "openSession failed");

    // Retrieve a reference to the global scope
    hr = session.get_globalScope(globals);
    hr == S_OK || assert(false, "get_globalScope failed");

    return true;
}

void printSymbol(IDiaSymbol sym, int indent)
{
    BSTR name;
    DWORD tag;
    HRESULT hr = sym.get_symTag(&tag);
    hr == S_OK || assert(false, "cannot get SymTag of symbol");
    hr = sym.get_name(&name);
    if (hr != S_OK)
        name = cast(BSTR) "no-name"w.ptr;
    printf("%*s%02x %S\n", indent, "".ptr, tag, name);
    if (hr == S_OK)
        SysFreeString(name);
}

void dumpSymbols(IDiaSymbol parent, SymTagEnum tag, const(wchar)* name, int indent)
{
    IDiaEnumSymbols enumSymbols;
    HRESULT hr = parent.findChildren(tag, name, NameSearchOptions.nsfRegularExpression, &enumSymbols);
    if (hr != S_OK)
        return;

    DWORD celt;
    IDiaSymbol sym;
    while (enumSymbols.Next(1, &sym, &celt) == S_OK && celt == 1)
    {
        printSymbol(sym, indent + 2);
        dumpSymbols(sym, tag, null, indent + 4);
        sym.Release();
    }
    enumSymbols.Release();
}

IDiaSymbol searchSymbol(IDiaSymbol parent, const(wchar)* name, SymTagEnum tag = SymTagEnum.SymTagNull)
{
    IDiaEnumSymbols enumSymbols;
    // findChildren by name doesn't seem to work with '.' in name
    HRESULT hr = parent.findChildren(tag, null, NameSearchOptions.nsNone, &enumSymbols);
    if (hr != S_OK)
        return null;

    DWORD celt;
    IDiaSymbol sym;
    while (enumSymbols.Next(1, &sym, &celt) == S_OK && celt == 1)
    {
        BSTR symname;
        hr = sym.get_name(&symname);
        if (hr == S_OK)
        {
            scope(exit) SysFreeString(symname);
            if (wcscmp(symname, name) == 0)
                break;
        }
        sym.Release();
        sym = null;
    }
    enumSymbols.Release();
    return sym;
}

struct Line
{
    DWORD line;
    ubyte* addr;
}

// linker generated symbol
__gshared extern(C) extern ubyte __ImageBase;

Line[] findSymbolLineNumbers(IDiaSession session, IDiaSymbol sym, ubyte[]* funcRange)
{
    DWORD rva;
    HRESULT hr = sym.get_relativeVirtualAddress(&rva);
    if (hr != S_OK)
        return null;

    ULONGLONG length;
    hr = sym.get_length(&length);
    if (hr != S_OK)
        return null;

    IDiaEnumLineNumbers dialines;
    hr = session.findLinesByRVA(rva, cast(DWORD)length, &dialines);
    if (hr != S_OK)
        return null;
    scope(exit) dialines.Release();

    ubyte* rvabase = &__ImageBase;
    *funcRange = rvabase[rva .. rva+length];

    Line[] lines;
    IDiaLineNumber line;
    ULONG fetched;
    while(dialines.Next(1, &line, &fetched) == S_OK)
    {
        DWORD lno, lrva;
        if (line.get_lineNumber(&lno) == S_OK && line.get_relativeVirtualAddress(&lrva) == S_OK)
            lines ~= Line(lno, rvabase + lrva);
        line.Release();
    }
    return lines;
}

void dumpLineNumbers(Line[] lines, ubyte[] funcRange)
{
    import core.stdc.stdio;
    void dumpLine(int lno, ubyte* beg, ubyte* end)
    {
        printf("%8d:", lno);
        while (beg < end)
            printf(" %02x", *beg++);
        printf("\n");
    }
    if (lines[0].addr != funcRange.ptr)
        dumpLine(0, funcRange.ptr, lines[0].addr);
    for (int i = 1; i < lines.length; i++)
        dumpLine(lines[i-1].line, lines[i-1].addr, lines[i].addr);
    dumpLine(lines[$-1].line, lines[$-1].addr, funcRange.ptr + funcRange.length);
}
