/**
 * Windows API header module
 *
 * Translated from Windows SDK 10.0.28000.0 um/propsys.h
 *
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source: $(DRUNTIMESRC core/sys/windows/_propsys.d)
 */
module core.sys.windows.propsys;
version (Windows):

pragma(lib, "propsys");

import core.sys.windows.basetyps, core.sys.windows.oaidl, core.sys.windows.objidl,
  core.sys.windows.ocidl, core.sys.windows.shlobj, core.sys.windows.unknwn,
  core.sys.windows.w32api, core.sys.windows.windef, core.sys.windows.wtypes;

static if (_WIN32_WINNT >= 0x600):

alias CONDITION_OPERATION = int;
enum : CONDITION_OPERATION {
    COP_IMPLICIT = 0,
    COP_EQUAL,
    COP_NOTEQUAL,
    COP_LESSTHAN,
    COP_GREATERTHAN,
    COP_LESSTHANOREQUAL,
    COP_GREATERTHANOREQUAL,
    COP_VALUE_STARTSWITH,
    COP_VALUE_ENDSWITH,
    COP_VALUE_CONTAINS,
    COP_VALUE_NOTCONTAINS,
    COP_DOSWILDCARDS,
    COP_WORD_EQUAL,
    COP_WORD_STARTSWITH,
    COP_APPLICATION_SPECIFIC
}

alias GETPROPERTYSTOREFLAGS = int;
enum : GETPROPERTYSTOREFLAGS {
    GPS_DEFAULT                 = 0,
    GPS_HANDLERPROPERTIESONLY   = 0x1,
    GPS_READWRITE               = 0x2,
    GPS_TEMPORARY               = 0x4,
    GPS_FASTPROPERTIESONLY      = 0x8,
    GPS_OPENSLOWITEM            = 0x10,
    GPS_DELAYCREATION           = 0x20,
    GPS_BESTEFFORT              = 0x40,
    GPS_NO_OPLOCK               = 0x80,
    GPS_PREFERQUERYPROPERTIES   = 0x100,
    GPS_EXTRINSICPROPERTIES     = 0x200,
    GPS_EXTRINSICPROPERTIESONLY = 0x400,
    GPS_VOLATILEPROPERTIES      = 0x800,
    GPS_VOLATILEPROPERTIESONLY  = 0x1000,
    GPS_MASK_VALID              = 0x1fff
}

alias PKA_FLAGS = int;
enum : PKA_FLAGS {
    PKA_SET = 0,
    PKA_APPEND,
    PKA_DELETE
}

alias PSC_STATE = int;
enum : PSC_STATE {
    PSC_NORMAL      = 0,
    PSC_NOTINSOURCE = 1,
    PSC_DIRTY       = 2,
    PSC_READONLY    = 3
}

alias PROPENUMTYPE = int;
enum : PROPENUMTYPE {
    PET_DISCRETEVALUE = 0,
    PET_RANGEDVALUE   = 1,
    PET_DEFAULTVALUE  = 2,
    PET_ENDRANGE      = 3
}

alias PROPDESC_TYPE_FLAGS = int;
enum : PROPDESC_TYPE_FLAGS {
    PDTF_DEFAULT                   = 0,
    PDTF_MULTIPLEVALUES            = 0x1,
    PDTF_ISINNATE                  = 0x2,
    PDTF_ISGROUP                   = 0x4,
    PDTF_CANGROUPBY                = 0x8,
    PDTF_CANSTACKBY                = 0x10,
    PDTF_ISTREEPROPERTY            = 0x20,
    PDTF_INCLUDEINFULLTEXTQUERY    = 0x40,
    PDTF_ISVIEWABLE                = 0x80,
    PDTF_ISQUERYABLE               = 0x100,
    PDTF_CANBEPURGED               = 0x200,
    PDTF_SEARCHRAWVALUE            = 0x400,
    PDTF_DONTCOERCEEMPTYSTRINGS    = 0x800,
    PDTF_ALWAYSINSUPPLEMENTALSTORE = 0x1000,
    PDTF_ISSYSTEMPROPERTY          = 0x80000000,
    PDTF_MASK_ALL                  = 0x80001fff
}

alias PROPDESC_VIEW_FLAGS = int;
enum : PROPDESC_VIEW_FLAGS {
    PDVF_DEFAULT             = 0,
    PDVF_CENTERALIGN         = 0x1,
    PDVF_RIGHTALIGN          = 0x2,
    PDVF_BEGINNEWGROUP       = 0x4,
    PDVF_FILLAREA            = 0x8,
    PDVF_SORTDESCENDING      = 0x10,
    PDVF_SHOWONLYIFPRESENT   = 0x20,
    PDVF_SHOWBYDEFAULT       = 0x40,
    PDVF_SHOWINPRIMARYLIST   = 0x80,
    PDVF_SHOWINSECONDARYLIST = 0x100,
    PDVF_HIDELABEL           = 0x200,
    PDVF_HIDDEN              = 0x800,
    PDVF_CANWRAP             = 0x1000,
    PDVF_MASK_ALL            = 0x1bff
}

alias PROPDESC_DISPLAYTYPE = int;
enum : PROPDESC_DISPLAYTYPE {
    PDDT_STRING     = 0,
    PDDT_NUMBER     = 1,
    PDDT_BOOLEAN    = 2,
    PDDT_DATETIME   = 3,
    PDDT_ENUMERATED = 4
}

alias PROPDESC_GROUPING_RANGE = int;
enum : PROPDESC_GROUPING_RANGE {
    PDGR_DISCRETE     = 0,
    PDGR_ALPHANUMERIC = 1,
    PDGR_SIZE         = 2,
    PDGR_DYNAMIC      = 3,
    PDGR_DATE         = 4,
    PDGR_PERCENT      = 5,
    PDGR_ENUMERATED   = 6
}

alias PROPDESC_FORMAT_FLAGS = int;
enum : PROPDESC_FORMAT_FLAGS {
    PDFF_DEFAULT              = 0,
    PDFF_PREFIXNAME           = 0x1,
    PDFF_FILENAME             = 0x2,
    PDFF_ALWAYSKB             = 0x4,
    PDFF_RESERVED_RIGHTTOLEFT = 0x8,
    PDFF_SHORTTIME            = 0x10,
    PDFF_LONGTIME             = 0x20,
    PDFF_HIDETIME             = 0x40,
    PDFF_SHORTDATE            = 0x80,
    PDFF_LONGDATE             = 0x100,
    PDFF_HIDEDATE             = 0x200,
    PDFF_RELATIVEDATE         = 0x400,
    PDFF_USEEDITINVITATION    = 0x800,
    PDFF_READONLY             = 0x1000,
    PDFF_NOAUTOREADINGORDER   = 0x2000,
    PDFF_PREFERFRIENDLY       = 0x10000000
}

alias PROPDESC_SORTDESCRIPTION = int;
enum : PROPDESC_SORTDESCRIPTION {
    PDSD_GENERAL          = 0,
    PDSD_A_Z              = 1,
    PDSD_LOWEST_HIGHEST   = 2,
    PDSD_SMALLEST_BIGGEST = 3,
    PDSD_OLDEST_NEWEST    = 4
}

alias PROPDESC_RELATIVEDESCRIPTION_TYPE = int;
enum : PROPDESC_RELATIVEDESCRIPTION_TYPE {
    PDRDT_GENERAL  = 0,
    PDRDT_DATE     = 1,
    PDRDT_SIZE     = 2,
    PDRDT_COUNT    = 3,
    PDRDT_REVISION = 4,
    PDRDT_LENGTH   = 5,
    PDRDT_DURATION = 6,
    PDRDT_SPEED    = 7,
    PDRDT_RATE     = 8,
    PDRDT_RATING   = 9,
    PDRDT_PRIORITY = 10
}

alias PROPDESC_AGGREGATION_TYPE = int;
enum : PROPDESC_AGGREGATION_TYPE {
    PDAT_DEFAULT   = 0,
    PDAT_FIRST     = 1,
    PDAT_SUM       = 2,
    PDAT_AVERAGE   = 3,
    PDAT_DATERANGE = 4,
    PDAT_UNION     = 5,
    PDAT_MAX       = 6,
    PDAT_MIN       = 7
}

alias PROPDESC_CONDITION_TYPE = int;
enum : PROPDESC_CONDITION_TYPE {
    PDCOT_NONE     = 0,
    PDCOT_STRING   = 1,
    PDCOT_SIZE     = 2,
    PDCOT_DATETIME = 3,
    PDCOT_BOOLEAN  = 4,
    PDCOT_NUMBER   = 5
}

alias PROPDESC_SEARCHINFO_FLAGS = int;
enum : PROPDESC_SEARCHINFO_FLAGS {
    PDSIF_DEFAULT         = 0,
    PDSIF_ININVERTEDINDEX = 0x1,
    PDSIF_ISCOLUMN        = 0x2,
    PDSIF_ISCOLUMNSPARSE  = 0x4,
    PDSIF_ALWAYSINCLUDE   = 0x8,
    PDSIF_USEFORTYPEAHEAD = 0x10
}

alias PROPDESC_COLUMNINDEX_TYPE = int;
enum : PROPDESC_COLUMNINDEX_TYPE {
    PDCIT_NONE         = 0,
    PDCIT_ONDISK       = 1,
    PDCIT_INMEMORY     = 2,
    PDCIT_ONDEMAND     = 3,
    PDCIT_ONDISKALL    = 4,
    PDCIT_ONDISKVECTOR = 5
}

alias PROPDESC_ENUMFILTER = int;
enum : PROPDESC_ENUMFILTER {
    PDEF_ALL             = 0,
    PDEF_SYSTEM          = 1,
    PDEF_NONSYSTEM       = 2,
    PDEF_VIEWABLE        = 3,
    PDEF_QUERYABLE       = 4,
    PDEF_INFULLTEXTQUERY = 5,
    PDEF_COLUMN          = 6
}

alias PERSIST_SPROPSTORE_FLAGS = int;
enum : PERSIST_SPROPSTORE_FLAGS {
    FPSPS_DEFAULT                   = 0,
    FPSPS_READONLY                  = 0x1,
    FPSPS_TREAT_NEW_VALUES_AS_DIRTY = 0x2
}

struct SERIALIZEDPROPSTORAGE;
alias PUSERIALIZEDPROPSTORAGE = SERIALIZEDPROPSTORAGE*;
alias PCUSERIALIZEDPROPSTORAGE = const(SERIALIZEDPROPSTORAGE)*;

enum PKEY_PIDSTR_MAX = 10;
enum GUIDSTRING_MAX = 1 + 8 + 1 + 4 + 1 + 4 + 1 + 4 + 1 + 12 + 1 + 1;
enum PKEYSTR_MAX = GUIDSTRING_MAX + 1 + PKEY_PIDSTR_MAX;

interface IInitializeWithFile : IUnknown {
    HRESULT Initialize(LPCWSTR, DWORD);
}

interface IInitializeWithStream : IUnknown {
    HRESULT Initialize(IStream, DWORD);
}

interface IPropertyStore : IUnknown {
    HRESULT GetCount(DWORD*);
    HRESULT GetAt(DWORD, PROPERTYKEY*);
    HRESULT GetValue(REFPROPERTYKEY, PROPVARIANT*);
    HRESULT SetValue(REFPROPERTYKEY, REFPROPVARIANT);
    HRESULT Commit();
}
alias LPPROPERTYSTORE = IPropertyStore;

interface INamedPropertyStore : IUnknown {
    HRESULT GetNamedValue(LPCWSTR, PROPVARIANT*);
    HRESULT SetNamedValue(LPCWSTR, REFPROPVARIANT);
    HRESULT GetNameCount(DWORD*);
    HRESULT GetNameAt(DWORD, BSTR*);
}

interface IObjectWithPropertyKey : IUnknown {
    HRESULT SetPropertyKey(REFPROPERTYKEY);
    HRESULT GetPropertyKey(PROPERTYKEY*);
}

interface IPropertyChange : IObjectWithPropertyKey {
    HRESULT ApplyToPropVariant(REFPROPVARIANT, PROPVARIANT*);
}

interface IPropertyChangeArray : IUnknown {
    HRESULT GetCount(UINT*);
    HRESULT GetAt(UINT, REFIID, void**);
    HRESULT InsertAt(UINT, IPropertyChange);
    HRESULT Append(IPropertyChange);
    HRESULT AppendOrReplace(IPropertyChange);
    HRESULT RemoveAt(UINT);
    HRESULT IsKeyInArray(REFPROPERTYKEY);
}

interface IPropertyStoreCapabilities : IUnknown {
    HRESULT IsPropertyWritable(REFPROPERTYKEY);
}

interface IPropertyStoreCache : IPropertyStore {
    HRESULT GetState(REFPROPERTYKEY, PSC_STATE*);
    HRESULT GetValueAndState(REFPROPERTYKEY, PROPVARIANT*, PSC_STATE*);
    HRESULT SetState(REFPROPERTYKEY, PSC_STATE);
    HRESULT SetValueAndState(REFPROPERTYKEY, const(PROPVARIANT)*, PSC_STATE);
}

interface IPropertyEnumType : IUnknown {
    HRESULT GetEnumType(PROPENUMTYPE*);
    HRESULT GetValue(PROPVARIANT*);
    HRESULT GetRangeMinValue(PROPVARIANT*);
    HRESULT GetRangeSetValue(PROPVARIANT*);
    HRESULT GetDisplayText(LPWSTR*);
}

static if (_WIN32_WINNT >= 0x601) {
    interface IPropertyEnumType2 : IPropertyEnumType {
        HRESULT GetImageReference(LPWSTR*);
    }
}

interface IPropertyEnumTypeList : IUnknown {
    HRESULT GetCount(UINT*);
    HRESULT GetAt(UINT, REFIID, void**);
    HRESULT GetConditionAt(UINT, REFIID, void**);
    HRESULT FindMatchingIndex(REFPROPVARIANT, UINT*);
}

interface IPropertyDescription : IUnknown {
    HRESULT GetPropertyKey(PROPERTYKEY*);
    HRESULT GetCanonicalName(LPWSTR*);
    HRESULT GetPropertyType(VARTYPE*);
    HRESULT GetDisplayName(LPWSTR*);
    HRESULT GetEditInvitation(LPWSTR*);
    HRESULT GetTypeFlags(PROPDESC_TYPE_FLAGS, PROPDESC_TYPE_FLAGS*);
    HRESULT GetViewFlags(PROPDESC_VIEW_FLAGS*);
    HRESULT GetDefaultColumnWidth(UINT*);
    HRESULT GetDisplayType(PROPDESC_DISPLAYTYPE*);
    HRESULT GetColumnState(SHCOLSTATEF*);
    HRESULT GetGroupingRange(PROPDESC_GROUPING_RANGE*);
    HRESULT GetRelativeDescriptionType(PROPDESC_RELATIVEDESCRIPTION_TYPE*);
    HRESULT GetRelativeDescription(REFPROPVARIANT, REFPROPVARIANT, LPWSTR*, LPWSTR*);
    HRESULT GetSortDescription(PROPDESC_SORTDESCRIPTION*);
    HRESULT GetSortDescriptionLabel(BOOL, LPWSTR*);
    HRESULT GetAggregationType(PROPDESC_AGGREGATION_TYPE*);
    HRESULT GetConditionType(PROPDESC_CONDITION_TYPE*, CONDITION_OPERATION*);
    HRESULT GetEnumTypeList(REFIID, void**);
    HRESULT CoerceToCanonicalValue(PROPVARIANT*);
    HRESULT FormatForDisplay(REFPROPVARIANT, PROPDESC_FORMAT_FLAGS, LPWSTR*);
    HRESULT IsValueCanonical(REFPROPVARIANT);
}

static if (_WIN32_WINNT >= 0x601) {
    interface IPropertyDescription2 : IPropertyDescription {
        HRESULT GetImageReferenceForValue(REFPROPVARIANT, LPWSTR*);
    }
}

interface IPropertyDescriptionAliasInfo : IPropertyDescription {
    HRESULT GetSortByAlias(REFIID, void**);
    HRESULT GetAdditionalSortByAliases(REFIID, void**);
}

interface IPropertyDescriptionSearchInfo : IPropertyDescription {
    HRESULT GetSearchInfoFlags(PROPDESC_SEARCHINFO_FLAGS*);
    HRESULT GetColumnIndexType(PROPDESC_COLUMNINDEX_TYPE*);
    HRESULT GetProjectionString(LPWSTR*);
    HRESULT GetMaxSize(UINT*);
}

static if (_WIN32_WINNT >= 0x601) {
    interface IPropertyDescriptionRelatedPropertyInfo : IPropertyDescription {
        HRESULT GetRelatedProperty(LPCWSTR, REFIID, void**);
    }
}

interface IPropertySystem : IUnknown {
    HRESULT GetPropertyDescription(REFPROPERTYKEY, REFIID, void**);
    HRESULT GetPropertyDescriptionByName(LPCWSTR, REFIID, void**);
    HRESULT GetPropertyDescriptionListFromString(LPCWSTR, REFIID, void**);
    HRESULT EnumeratePropertyDescriptions(PROPDESC_ENUMFILTER, REFIID, void**);
    HRESULT FormatForDisplay(REFPROPERTYKEY, REFPROPVARIANT, PROPDESC_FORMAT_FLAGS, LPWSTR, DWORD);
    HRESULT FormatForDisplayAlloc(REFPROPERTYKEY, REFPROPVARIANT, PROPDESC_FORMAT_FLAGS, LPWSTR*);
    HRESULT RegisterPropertySchema(LPCWSTR);
    HRESULT UnregisterPropertySchema(LPCWSTR);
    HRESULT RefreshPropertySchema();
}

interface IPropertyDescriptionList : IUnknown {
    HRESULT GetCount(UINT*);
    HRESULT GetAt(UINT, REFIID, void**);
}

interface IPropertyStoreFactory : IUnknown {
    HRESULT GetPropertyStore(GETPROPERTYSTOREFLAGS, IUnknown, REFIID, void**);
    HRESULT GetPropertyStoreForKeys(const(PROPERTYKEY)*, UINT, GETPROPERTYSTOREFLAGS, REFIID, void**);
}

interface IDelayedPropertyStoreFactory : IPropertyStoreFactory {
    HRESULT GetDelayedPropertyStore(GETPROPERTYSTOREFLAGS, DWORD, REFIID, void**);
}

interface IPersistSerializedPropStorage : IUnknown {
    HRESULT SetFlags(PERSIST_SPROPSTORE_FLAGS);
    HRESULT SetPropertyStorage(PCUSERIALIZEDPROPSTORAGE, DWORD);
    HRESULT GetPropertyStorage(SERIALIZEDPROPSTORAGE**, DWORD*);
}

static if (_WIN32_WINNT >= 0x601) {
    interface IPersistSerializedPropStorage2 : IPersistSerializedPropStorage {
        HRESULT GetPropertyStorageSize(DWORD*);
        HRESULT GetPropertyStorageBuffer(SERIALIZEDPROPSTORAGE*, DWORD, DWORD*);
    }
}

interface IPropertySystemChangeNotify : IUnknown {
    HRESULT SchemaRefreshed();
}

interface ICreateObject : IUnknown {
    HRESULT CreateObject(REFCLSID, IUnknown, REFIID, void**);
}

extern (Windows) nothrow @nogc {
    HRESULT PSFormatForDisplay(REFPROPERTYKEY, REFPROPVARIANT, PROPDESC_FORMAT_FLAGS, LPWSTR, DWORD);
    HRESULT PSFormatForDisplayAlloc(REFPROPERTYKEY, REFPROPVARIANT, PROPDESC_FORMAT_FLAGS, PWSTR*);
    HRESULT PSFormatPropertyValue(IPropertyStore, IPropertyDescription, PROPDESC_FORMAT_FLAGS, LPWSTR*);
    HRESULT PSStringFromPropertyKey(REFPROPERTYKEY, LPWSTR, UINT);
    HRESULT PSPropertyKeyFromString(LPCWSTR, PROPERTYKEY*);
    HRESULT PSCreateMemoryPropertyStore(REFIID, void**);
    HRESULT PSCreateDelayedMultiplexPropertyStore(GETPROPERTYSTOREFLAGS, IDelayedPropertyStoreFactory,
      const(DWORD)*, DWORD, REFIID, void**);
    HRESULT PSCreateMultiplexPropertyStore(IUnknown*, DWORD, REFIID, void**);
    HRESULT PSCreatePropertyChangeArray(const(PROPERTYKEY)*, const(PKA_FLAGS)*, const(PROPVARIANT)*, UINT,
      REFIID, void**);
    HRESULT PSCreateSimplePropertyChange(PKA_FLAGS, REFPROPERTYKEY, REFPROPVARIANT, REFIID, void**);
    HRESULT PSGetPropertyDescription(REFPROPERTYKEY, REFIID, void**);
    HRESULT PSGetPropertyDescriptionByName(LPCWSTR, REFIID, void**);
    HRESULT PSLookupPropertyHandlerCLSID(PCWSTR, GUID*);
    HRESULT PSGetItemPropertyHandler(IUnknown, BOOL, REFIID, void**);
    HRESULT PSGetItemPropertyHandlerWithCreateObject(IUnknown, BOOL, IUnknown, REFIID, void**);
    HRESULT PSGetPropertyValue(IPropertyStore, IPropertyDescription, PROPVARIANT*);
    HRESULT PSSetPropertyValue(IPropertyStore, IPropertyDescription, REFPROPVARIANT);
    HRESULT PSRegisterPropertySchema(PCWSTR);
    HRESULT PSUnregisterPropertySchema(PCWSTR);
    HRESULT PSRefreshPropertySchema();
    HRESULT PSEnumeratePropertyDescriptions(PROPDESC_ENUMFILTER, REFIID, void**);
    HRESULT PSGetPropertyKeyFromName(PCWSTR, PROPERTYKEY*);
    HRESULT PSGetNameFromPropertyKey(REFPROPERTYKEY, PWSTR*);
    HRESULT PSCoerceToCanonicalValue(REFPROPERTYKEY, PROPVARIANT*);
    HRESULT PSGetPropertyDescriptionListFromString(LPCWSTR, REFIID, void**);
    HRESULT PSCreatePropertyStoreFromPropertySetStorage(IPropertySetStorage, DWORD, REFIID, void**);
    HRESULT PSCreatePropertyStoreFromObject(IUnknown, DWORD, REFIID, void**);
    HRESULT PSCreateAdapterFromPropertyStore(IPropertyStore, REFIID, void**);
    HRESULT PSGetPropertySystem(REFIID, void**);
    HRESULT PSGetPropertyFromPropertyStorage(PCUSERIALIZEDPROPSTORAGE, DWORD, REFPROPERTYKEY, PROPVARIANT*);
    HRESULT PSGetNamedPropertyFromPropertyStorage(PCUSERIALIZEDPROPSTORAGE, DWORD, LPCWSTR, PROPVARIANT*);

    static if (_WIN32_WINNT >= 0x601) {
        HRESULT PSGetImageReferenceForValue(REFPROPERTYKEY, REFPROPVARIANT, PWSTR*);

        HRESULT PSPropertyBag_ReadType(IPropertyBag, LPCWSTR, VARIANT*, VARTYPE);
        HRESULT PSPropertyBag_ReadStr(IPropertyBag, LPCWSTR, LPWSTR, int);
        HRESULT PSPropertyBag_ReadStrAlloc(IPropertyBag, LPCWSTR, PWSTR*);
        HRESULT PSPropertyBag_ReadBSTR(IPropertyBag, LPCWSTR, BSTR*);
        HRESULT PSPropertyBag_WriteStr(IPropertyBag, LPCWSTR, LPCWSTR);
        HRESULT PSPropertyBag_WriteBSTR(IPropertyBag, LPCWSTR, BSTR);
        HRESULT PSPropertyBag_ReadInt(IPropertyBag, LPCWSTR, INT*);
        HRESULT PSPropertyBag_WriteInt(IPropertyBag, LPCWSTR, INT);
        HRESULT PSPropertyBag_ReadSHORT(IPropertyBag, LPCWSTR, SHORT*);
        HRESULT PSPropertyBag_WriteSHORT(IPropertyBag, LPCWSTR, SHORT);
        HRESULT PSPropertyBag_ReadLONG(IPropertyBag, LPCWSTR, LONG*);
        HRESULT PSPropertyBag_WriteLONG(IPropertyBag, LPCWSTR, LONG);
        HRESULT PSPropertyBag_ReadDWORD(IPropertyBag, LPCWSTR, DWORD*);
        HRESULT PSPropertyBag_WriteDWORD(IPropertyBag, LPCWSTR, DWORD);
        HRESULT PSPropertyBag_ReadBOOL(IPropertyBag, LPCWSTR, BOOL*);
        HRESULT PSPropertyBag_WriteBOOL(IPropertyBag, LPCWSTR, BOOL);
        HRESULT PSPropertyBag_ReadPOINTL(IPropertyBag, LPCWSTR, POINTL*);
        HRESULT PSPropertyBag_WritePOINTL(IPropertyBag, LPCWSTR, const(POINTL)*);
        HRESULT PSPropertyBag_ReadPOINTS(IPropertyBag, LPCWSTR, POINTS*);
        HRESULT PSPropertyBag_WritePOINTS(IPropertyBag, LPCWSTR, const(POINTS)*);
        HRESULT PSPropertyBag_ReadRECTL(IPropertyBag, LPCWSTR, RECTL*);
        HRESULT PSPropertyBag_WriteRECTL(IPropertyBag, LPCWSTR, const(RECTL)*);
        HRESULT PSPropertyBag_ReadStream(IPropertyBag, LPCWSTR, IStream*);
        HRESULT PSPropertyBag_WriteStream(IPropertyBag, LPCWSTR, IStream);
        HRESULT PSPropertyBag_Delete(IPropertyBag, LPCWSTR);
        HRESULT PSPropertyBag_ReadULONGLONG(IPropertyBag, LPCWSTR, ULONGLONG*);
        HRESULT PSPropertyBag_WriteULONGLONG(IPropertyBag, LPCWSTR, ULONGLONG);
        HRESULT PSPropertyBag_ReadUnknown(IPropertyBag, LPCWSTR, REFIID, void**);
        HRESULT PSPropertyBag_WriteUnknown(IPropertyBag, LPCWSTR, IUnknown);
        HRESULT PSPropertyBag_ReadGUID(IPropertyBag, LPCWSTR, GUID*);
        HRESULT PSPropertyBag_WriteGUID(IPropertyBag, LPCWSTR, const(GUID)*);
        HRESULT PSPropertyBag_ReadPropertyKey(IPropertyBag, LPCWSTR, PROPERTYKEY*);
        HRESULT PSPropertyBag_WritePropertyKey(IPropertyBag, LPCWSTR, REFPROPERTYKEY);
    }

    static if (_WIN32_WINNT >= 0x602) {
        HRESULT PropVariantToWinRTPropertyValue(REFPROPVARIANT, REFIID, void**);
        HRESULT WinRTPropertyValueToPropVariant(IUnknown, PROPVARIANT*);
    }
}
