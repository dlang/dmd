/**
 * Bindings to parts of the Core Foundation framework.
 *
 * Compiler implementation of the
 * $(LINK2 http://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (C) 1999-2019 by The D Language Foundation, All Rights Reserved
 * Authors:     $(LINK2 http://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/src/dmd/root/core_foundation.d, root/_core_foundation.d)
 * Documentation: https://dlang.org/phobos/dmd_root_core_foundation.html
 * Coverage:    https://codecov.io/gh/dlang/dmd/src/master/src/dmd/root/core_foundation.d
 */
module dmd.backend.core_foundation;

version (OSX):
@system:
nothrow:
@nogc:
package:

extern (D):

/**
 * Releases a Core Foundation object.
 *
 * Will do nothing if `cf` is `null`.
 *
 * Params:
 *  cf = A CFType object to release. This value may be `null`.
 */
void release(CFTypeRef cf)
{
    if (cf)
        CFRelease(cf);
}

/**
 * Casts the given Core Foundation object to the specified type `T`.
 *
 * This will perform a check using `CFGetTypeID` to verify that the given object
 * is of the target type `T`.
 *
 * ---
 * cf.asInstanceOf!CFDictionaryRefs
 * ---
 *
 * Params:
 *  T = the target type to cast to. Should be a Core Foundation reference type,
 *      i.e. the type should end with `Ref`
 *
 *  cf = the object to cast
 *
 * Returns: the `cf` object casted to `T` or `null` if `cf` is not of the type `T`
 */
T asInstanceOf(T)(CFTypeRef cf)
{
    enum type = T.stringof[2 .. $ - 1];
    mixin("const typeId = " ~ type ~ "GetTypeID;");

    return cf.CFGetTypeID == typeId ? cast(T) cf : null;
}

/**
 * Converts the given Core Foundation string to a D string.
 *
 * The maximum allowed string length is 1024 bytes. If the given string is
 * longer it will be truncated.
 *
 * The converted D string contains a trailing `\0`.
 *
 * Params:
 *  str = the string to convert
 *  buffer = where to place the convert string
 *
 * Returns: a buffer structure containing the D string. Use `[]` to extract the
 *  D string.
 */
const(char[]) toString(CFStringRef str, char[] buffer)
{
    if (!str)
        return null;

    const length = str.CFStringGetLength;
    const range = CFRange(0, length);
    CFIndex usedBufferLength;

    const convertedLength = str.CFStringGetBytes(
        range,
        CFStringBuiltInEncodings.utf8, 0, false,
        buffer.ptr, buffer.length, usedBufferLength
    );

    if (convertedLength < length || usedBufferLength + 1 > buffer.length)
        return null;

    buffer[usedBufferLength] = '\0';

    return buffer[0 .. usedBufferLength + 1];
}

/// Wraps a Core Foundation object and releases it when it goes out of scope.
struct AutoRelease(T)
{
    /// The wrapped Core Foundation object.
    T cf;

    ///
    alias cf this;

    @disable this(this);

    ///
    ~this() const nothrow @nogc
    {
        cf.release();
    }
}

/**
 * Wraps a CFReadStreamRef object and closes and releases it when it goes out of
 * scope.
 */
struct Stream
{
    /// The wrapped Core Foundation stream.
    CFReadStreamRef stream;

    /// `true` if the stream is open.
    private immutable bool isOpen;

    ///
    alias stream this;

    @disable this(this);

    /// Returns: true if the stream is valid and open.
    bool opCast() const pure nothrow @nogc
    {
        return stream && isOpen;
    }

    ///
    ~this() nothrow @nogc
    {
        stream.CFReadStreamClose();
        stream.release();
    }
}

/// Convenience function for creating an `AutoRelease` value.
AutoRelease!T autoRelease(T)(T cf)
{
    return AutoRelease!T(cf);
}

/**
 * Converts a D string to a Core Foundation string.
 *
 * Params:
 *  str = the D string to convert.
 *
 * Returns: the new Core Foundation string
 */
AutoRelease!CFStringRef cfString(string str)
{
    return CFStringCreateWithBytesNoCopy(kCFAllocatorDefault, str.ptr,
        str.length, CFStringBuiltInEncodings.utf8, false, kCFAllocatorNull).autoRelease;
}

/**
 * Creates a new Core Foundation URL object.
 *
 * Params:
 *  path = the string to convert to a URL
 *
 * Returns: the new Core Foundation URL
 */
AutoRelease!CFURLRef createUrl(const char[] path)
{
    return CFURLCreateFromFileSystemRepresentation(kCFAllocatorDefault,
        path.ptr, path.length, false).autoRelease;
}

/**
 * Creates a new Core Foundation stream object.
 *
 * Params:
 *  url = the path of the file to read
 *
 * Returns: the new Core Foundation stream
 */
Stream createStream(CFURLRef url)
{
    auto stream = CFReadStreamCreateWithFile(kCFAllocatorDefault, url);
    if (!stream) return Stream();

    return Stream(stream, stream.CFReadStreamOpen());
}

/**
 * Creates a property list with a Core Foundation stream input.
 *
 * Params:
 *  stream = the file to read
 *
 * Returns: the property list read from the stream
 */
AutoRelease!CFPropertyListRef createPropertyList(CFReadStreamRef stream)
{
    return CFPropertyListCreateWithStream(kCFAllocatorDefault, stream, 0,
        CFPropertyListMutabilityOptions.immutable_, null, null).autoRelease;
}

/**
 * Convenience function to create a property list from a file.
 *
 * Params:
 *  path = the path to the file to read
 *
 * Returns: the property list read from the file
 */
AutoRelease!CFPropertyListRef createPropertyListFromFile(const char[] path)
{
    const url = path.createUrl();
    if (!url) return typeof(return).init;

    auto stream = url.createStream();
    if (!stream) return typeof(return).init;

    return stream.createPropertyList();
}

extern (C):

/// Priority values used for kAXPriorityKey.
alias CFIndex = ptrdiff_t;

/**
 * A bitfield used for passing special allocation and other requests into
 * Core Foundation functions.
 */
alias CFOptionFlags = size_t;

/**
 * A type for unique, constant integer values that identify particular
 * Core Foundation opaque types.
 *
 * Defines a type identifier in Core Foundation. A type ID is an integer that
 * identifies the opaque type to which a Core Foundation object "belongs." You
 * use type IDs in various contexts, such as when you are operating on
 * heterogeneous collections. Core Foundation provides programmatic interfaces
 * for obtaining and evaluating type IDs.
 *
 * Because the value for a type ID can change from release to release, your code
 * should not rely on stored or hard-coded type IDs nor should it hard-code any
 * observed properties of a type ID (such as, for example, it being a small
 * integer).
 */
alias CFTypeID = size_t;

/**
 * An untyped "generic" reference to any Core Foundation object.
 *
 * The `CFTypeRef` type is the base type defined in Core Foundation. It is used
 * as the type and return value in several polymorphic functions. It is a
 * generic object reference that acts as a placeholder for other true
 * Core Foundation objects.
 */
alias CFTypeRef = const(void)*;

/**
 * An integer type for constants used to specify supported string encodings in
 * various CFString functions.
 *
 * This type is used to define the constants for the built-in encodings
 * (see CFStringBuiltInEncodings for a list) and for platform-dependent
 * encodings (see External String Encodings). If CFString does not recognize or
 * support the string encoding of a particular string, CFString functions will
 * identify the string’s encoding as kCFStringEncodingInvalidId.
 */
alias CFStringEncoding = uint;

/**
 * A reference to a CFPropertyList object.
 *
 * This is an abstract type for property list objects. The return value of the
 * CFPropertyListCreateFromXMLData function depends on the contents of the given
 * XML data. CFPropertyListRef can be a reference to any of the property list
 * objects: CFData, CFString, CFArray, CFDictionary, CFDate, CFBoolean, and
 * CFNumber.
 */
alias CFPropertyListRef = CFTypeRef;

private struct __CFError;

/// A reference to a CFError object.
alias CFErrorRef = __CFError*;

///
private struct __CFURL;

/// A reference to a CFURL object.
alias CFURLRef = const(__CFURL)*;

private struct __CFAllocator;

/**
 * A reference to a CFAllocator object.
 *
 * The `CFAllocatorRef` type is a reference type used in many Core Foundation
 * parameters and function results. It refers to a CFAllocator object, which
 * allocates, reallocates, and deallocates memory for Core Foundation objects.
 */
alias CFAllocatorRef = const(__CFAllocator)*;

private struct __CFReadStream;

/// A reference to a readable stream object.
alias CFReadStreamRef = __CFReadStream*;

private struct __CFDictionary;

/// A reference to an immutable dictionary object.
alias CFDictionaryRef = __CFDictionary*;

private struct __CFString;

/**
 * A reference to a CFString object.
 *
 * The CFStringRef type refers to a CFString object, which "encapsulates" a
 * Unicode string along with its length. CFString is an opaque type that defines
 * the characteristics and behavior of CFString objects.
 *
 * Values of type CFStringRef may refer to immutable or mutable strings, as
 * CFMutableString objects respond to all functions intended for immutable
 * CFString objects. Functions which accept CFStringRef values, and which need
 * to hold on to the values immutably, should call CFStringCreateCopy
 * (instead of CFRetain) to do so.
 */
alias CFStringRef = __CFString*;

/**
 * Type for flags that determine the degree of mutability of newly created
 * property lists.
 */
enum CFPropertyListMutabilityOptions : CFOptionFlags
{
    /// Specifies that the property list should be immutable.
    immutable_ = 0,

    /**
     * Specifies that the property list should have mutable containers but
     * immutable leaves.
     */
    mutableContainers = 1 << 0,

    /**
     * Specifies that the property list should have mutable containers and
     * mutable leaves.
     */
    mutableContainersAndLeaves = 1 << 1,
}

/// Specifies the format of a property list.
enum CFPropertyListFormat : CFIndex
{
    /// OpenStep format (use of this format is discouraged).
    openStepFormat = 1,

    /// XML format version 1.0.
    xmlFormat_v1_0 = 100,

    /// Binary format version 1.0.
    binaryFormat_v1_0 = 200
}

/// Encodings that are built-in on all platforms on which macOS runs.
enum CFStringBuiltInEncodings : CFStringEncoding
{
    /// An encoding constant that identifies the UTF 8 encoding.
    utf8 = 0x08000100
}

/**
 * A structure representing a range of sequential items in a container, such as
 * characters in a buffer or elements in a collection.
 */
struct CFRange
{
    /**
     * An integer representing the starting location of the range. For type
     * compatibility with the rest of the system, LONG_MAX is the maximum value
     * you should use for location.
     */
    CFIndex location;

    /**
     * An integer representing the number of items in the range. For type
     * compatibility with the rest of the system, LONG_MAX is the maximum value
     * you should use for length.
     */
    CFIndex length;
}

/// This is a synonym for NULL.
extern const CFAllocatorRef kCFAllocatorDefault;

/**
 * This allocator does nothing—it allocates no memory.
 *
 * This allocator is useful as the bytesDeallocator in CFData or
 * contentsDeallocator in CFString where the memory should not be freed.
 */
extern const CFAllocatorRef kCFAllocatorNull;

/**
 * Releases a Core Foundation object.
 *
 * If the retain count of cf becomes zero the memory allocated to the object
 * is deallocated and the object is destroyed. If you create, copy, or
 * explicitly retain (see the CFRetain function) a Core Foundation object, you
 * are responsible for releasing it when you no longer need it
 * (see Memory Management Programming Guide for Core Foundation).
 *
 * Special Considerations:
 * If cf is NULL, this will cause a runtime error and your application will
 * crash.
 *
 * Params:
 *  cf = A CFType object to release. This value must not be NULL.
 */
void CFRelease(CFTypeRef cf);

/**
 * Retains a Core Foundation object.
 *
 * Params:
 *  cf = The CFType object to retain. This value must not be NULL.
 *
 * Returns: the input value, cf
 */
CFTypeRef CFRetain(CFTypeRef cf);

/**
 * Returns the unique identifier of an opaque type to which a
 * Core Foundation object belongs.
 *
 * This function returns a value that uniquely identifies the opaque type of any
 * Core Foundation object. You can compare this value with the known CFTypeID
 * identifier obtained with a “GetTypeID” function specific to a type, for
 * example CFDateGetTypeID. These values might change from release to release or
 * platform to platform.
 *
 * Params:
 *  cf = The CFType object to examine.
 *
 * Returns: A value of type CFTypeID that identifies the opaque type of `cf`.
 */
CFTypeID CFGetTypeID(CFTypeRef cf);

/**
 * Returns the type identifier for the CFDictionary opaque type.
 *
 * CFMutableDictionary objects have the same type identifier as
 * CFDictionary objects.
 *
 * Returns: The type identifier for the CFDictionary opaque type.
 */
CFTypeID CFDictionaryGetTypeID();

/**
 * Returns the type identifier for the CFString opaque type.
 *
 * CFMutableString objects have the same type identifier as CFString objects.
 *
 * Returns: The type identifier for the CFString opaque type.
 */
CFTypeID CFStringGetTypeID();

/**
 * Creates a new CFURL object for a file system entity using the native
 * representation.
 *
 * Params:
 *  allocator = The allocator to use to allocate memory for the new CFURL
 *      object. Pass NULL or kCFAllocatorDefault to use the current default
 *      allocator.
 *
 *  buffer = The character bytes to convert into a CFURL object. This should be
 *      the path as you would use in POSIX function calls.
 *
 *  bufLen = The number of character bytes in the buffer (usually the result of
 *      a call to strlen), not including any null termination.
 *
 *  isDirectory = A Boolean value that specifies whether the string is treated
 *      as a directory path when resolving against relative path components—true
 *      if the pathname indicates a directory, false otherwise.
 *
 * Returns: A new CFURL object. Ownership follows the create rule.
 *  See The Create Rule.
 */
CFURLRef CFURLCreateFromFileSystemRepresentation(
    CFAllocatorRef allocator,
    const char* buffer,
    CFIndex bufLen,
    bool isDirectory
);

/**
 * Creates a readable stream for a file.
 *
 * You must open the stream, using CFReadStreamOpen, before reading from it.
 *
 * Params:
 *  alloc = The allocator to use to allocate memory for the new object.Pass NULL
 *      or kCFAllocatorDefault to use the current default allocator.
 *
 *  fileURL = The URL of the file to read. The URL must use the file scheme.
 *
 * Returns: The new readable stream object, or NULL on failure. Ownership
 *  follows the The Create Rule.
 */
CFReadStreamRef CFReadStreamCreateWithFile(
    CFAllocatorRef alloc,
    CFURLRef fileURL
);

/**
 * Opens a stream for reading.
 *
 * Opening a stream causes it to reserve all the system resources it requires.
 * If the stream can open in the background without blocking, this function
 * always returns true. To learn when a background open operation completes, you
 * can either schedule the stream into a run loop with
 * CFReadStreamScheduleWithRunLoop and wait for the stream’s client (set with
 * CFReadStreamSetClient) to be notified or you can poll the stream using
 * CFReadStreamGetStatus, waiting for a status of kCFStreamStatusOpen or kCFStreamStatusError.
 *
 * You do not need to wait until a stream has finished opening in the
 * background before calling the CFReadStreamRead function. The read operation
 * will simply block until the open has completed.
 *
 * Params:
 *  stream = The stream to open.
 *
 * Returns: TRUE if stream was successfully opened, FALSE otherwise. If stream
 *  is not in the kCFStreamStatusNotOpen state, this function returns FALSE.
 */
bool CFReadStreamOpen(CFReadStreamRef stream);

/**
 * Closes a readable stream.
 *
 * This function terminates the flow of bytes and releases any system resources
 * required by the stream. The stream is removed from any run loops in which it
 * was scheduled. Once closed, the stream cannot be reopened.
 *
 * Params:
 *  stream = The stream to close.
 */
void CFReadStreamClose(CFReadStreamRef stream);

/**
 * Create and return a property list with a CFReadStream input.
 *
 * Params:
 *  allocator = The allocator to use to allocate memory for the new property
 *      list object. Pass NULL or kCFAllocatorDefault to use the current default
 *      allocator.
 *
 *  stream = A CFReadStream that contains a serialized representation of a
 *      property list.
 *
 *  streamLength = The number of bytes to read from the stream. Pass 0 to read
 *      until the end of the stream is detected.
 *
 *  options = A CFPropertyListMutabilityOptions constant to specify the
 *      mutability of the returned property list—see Property List Mutability
 *      Options for possible values.
 *
 *  format = If this parameter is non-NULL, on return it will be set to the
 *      format of the data. See CFPropertyListFormat for possible values.
 *
 *  error =If this parameter is non-NULL, if an error occurs, on return this
 *      will contain a CFError error describing the problem. Ownership follows
 *      the The Create Rule.
 *
 * Returns: A new property list created from the data in stream. If an error
 *  occurs while parsing the data, returns NULL. Ownership follows the
 *  The Create Rule.
 */
CFPropertyListRef CFPropertyListCreateWithStream(
    CFAllocatorRef allocator,
    CFReadStreamRef stream,
    CFIndex streamLength,
    CFPropertyListMutabilityOptions options,
    CFPropertyListFormat* format,
    CFErrorRef* error
);

/**
 * Returns a Boolean value that indicates whether a given value for a given key
 * is in a dictionary, and returns that value indirectly if it exists.
 *
 * Params:
 *  theDict = The dictionary to examine.
 *
 *  key = The key for which to find a match in theDict. The key hash and equal
 *      callbacks provided when the dictionary was created are used to compare.
 *      If the hash callback was NULL, key is treated as a pointer and converted
 *      to an integer. If the equal callback was NULL, pointer equality
 *      (in C, ==) is used. If key, or any of the keys in theDict, is not
 *      understood by the equal callback, the behavior is undefined.
 *
 *  value = A pointer to memory which, on return, is filled with the
 *      pointer-sized value if a matching key is found. If no key match is
 *      found, the contents of the storage pointed to by this parameter are
 *      undefined. This value may be NULL, in which case the value from the
 *      dictionary is not returned (but the return value of this function still
 *      indicates whether or not the key-value pair was present). If the value
 *      is a Core Foundation object, ownership follows the The Get Rule.
 *
 * Returns: true if a matching key was found, otherwise false.
 */
bool CFDictionaryGetValueIfPresent(
    CFDictionaryRef theDict,
    const void* key,
    const void** value
);

/**
 * Returns the value associated with a given key.
 *
 * Params:
 *  theDict = The dictionary to examine.
 *
 *  key = The key for which to find a match in theDict. The key hash and equal
 *      callbacks provided when the dictionary was created are used to compare.
 *      If the hash callback was NULL, the key is treated as a pointer and
 *      converted to an integer. If the equal callback was NULL, pointer
 *      equality (in C, ==) is used. If key, or any of the keys in theDict, is
 *      not understood by the equal callback, the behavior is undefined.
 *
 * Returns: The value associated with key in theDict, or NULL if no key-value
 *  pair matching key exists. Since NULL is also a valid value in some
 *  dictionaries, use CFDictionaryGetValueIfPresent to distinguish between a
 *  value that is not found, and a NULL value. If the value is a Core Foundation
 *  object, ownership follows the The Get Rule.
 */
const(void*) CFDictionaryGetValue(CFDictionaryRef theDict, const void* key);

/**
 * Returns the number (in terms of UTF-16 code pairs) of Unicode characters in a
 * string.
 *
 * Params
 *  theString = The string to examine.
 *
 * Returns: The number (in terms of UTF-16 code pairs) of characters stored in
 *  theString.
 */
CFIndex CFStringGetLength(CFStringRef theString);

/**
 * Fetches a range of the characters from a string into a byte buffer after
 * converting the characters to a specified encoding.
 *
 * This function is the basic encoding-conversion function for CFString objects.
 * As with the other functions that get the character contents of CFString
 * objects, it allows conversion to a supported 8-bit encoding. Unlike most of
 * those other functions, it also allows “lossy conversion.” The function
 * permits the specification of a “loss byte” in a parameter; if a character
 * cannot be converted this character is substituted and conversion proceeds.
 * (With the other functions, conversion stops at the first error and the
 * operation fails.)
 *
 * Because this function takes a range and returns the number of characters
 * converted, it can be called repeatedly with a small fixed size buffer and
 * different ranges of the string to do the conversion incrementally.
 *
 * This function also handles any necessary manipulation of character data in an
 * “external representation” format. This format makes the data portable and
 * persistent (disk-writable); in Unicode it often includes a BOM
 * (byte order marker) that specifies the endianness of the data.
 *
 * The CFStringCreateExternalRepresentation function also handles external
 * representations and performs lossy conversions. The complementary function
 * CFStringCreateWithBytes creates a string from the characters in a byte buffer.
 *
 * Params:
 *  theString = The string upon which to operate.
 *
 *  range = The range of characters in theString to process. The specified range
 *      must not exceed the length of the string.
 *
 *  encoding = The string encoding of the characters to copy to the byte buffer.
 *      8, 16, and 32-bit encodings are supported.
 *
 *  lossByte = A character (for example, '?') that should be substituted for
 *      characters that cannot be converted to the specified encoding. Pass 0 if
 *      you do not want lossy conversion to occur.
 *
 *  isExternalRepresentation = true if you want the result to be in an
 *      “external representation” format, otherwise false. In an
 *      “external representation” format, the result may contain a
 *      byte order marker (BOM) specifying endianness and this function might
 *      have to perform byte swapping.
 *
 *  buffer = The byte buffer into which the converted characters are written.
 *      The buffer can be allocated on the heap or stack. Pass NULL if you do
 *      not want conversion to take place but instead want to know if conversion
 *      will succeed (the function result is greater than 0) and, if so, how
 *      many bytes are required (usedBufLen).
 *
 *  maxBufLen = The size of buffer and the maximum number of bytes that can be
 *      written to it.
 *
 *  usedBufLen = On return, the number of converted bytes actually in buffer.
 *      You may pass NULL if you are not interested in this information.
 */
CFIndex CFStringGetBytes(
    CFStringRef theString,
    CFRange range,
    CFStringEncoding encoding,
    char lossByte,
    bool isExternalRepresentation,
    char* buffer,
    CFIndex maxBufLen,
    out CFIndex usedBufLen
);

/**
 * Creates a string from a buffer, containing characters in a specified encoding,
 * that might serve as the backing store for the new string.
 *
 * This function takes an explicit length, and allows you to specify whether the
 * data is an external format—that is, whether to pay attention to the BOM
 * character (if any) and do byte swapping if necessary
 *
 * Special Considerations:
 * If an error occurs during the creation of the string, then bytes is not
 * deallocated. In this case, the caller is responsible for freeing the buffer.
 * This allows the caller to continue trying to create a string with the buffer,
 * without having the buffer deallocate
 *
 * Params:
 *  alloc = The allocator to use to allocate memory for the new CFString object.
 *      Pass NULL or kCFAllocatorDefault to use the current default allocator.
 *
 *  bytes = A buffer containing characters in the encoding specified by encoding.
 *      The buffer must not contain a length byte (as in Pascal buffers) or any
 *      terminating NULL character (as in C buffers).
 *
 *  numBytes = The number of bytes in bytes.
 *  encoding = The character encoding of bytes.
 *
 *  isExternalRepresentation = true if the characters in the byte buffer are in
 *      an “external representation” format—that is, whether the buffer contains
 *      a BOM (byte order marker). This is usually the case for bytes that are
 *      read in from a text file or received over the network.
 *      Otherwise, pass false.
 *
 *  contentsDeallocator = The allocator to use to deallocate bytes when it is no
 *      longer needed. You can pass NULL or kCFAllocatorDefault to request the
 *      default allocator for this purpose. If the buffer does not need to be
 *      deallocated, or if you want to assume responsibility for deallocating
 *      the buffer (and not have the string deallocate it), pass kCFAllocatorNull.
 */
CFStringRef CFStringCreateWithBytesNoCopy(
    CFAllocatorRef alloc,
    const char* bytes,
    CFIndex numBytes,
    CFStringEncoding encoding,
    bool isExternalRepresentation,
    CFAllocatorRef contentsDeallocator
);
