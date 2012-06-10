
// Copyright (c) 2012 by Digital Mars
// All Rights Reserved
// written by David Held
// http://www.digitalmars.com
// License for redistribution is by either the Artistic License
// in artistic.txt, or the GNU General Public License in gnu.txt.
// See the included readme.txt for details.
//---------------------------------------------------------------------------
#include <cppunit/extensions/HelperMacros.h>
#include <cppunit/ui/text/TestRunner.h>
#include <cstring>                      // std::memset()
#include <ostream>
#include <iomanip>
#include "..\UTF.h"
//---------------------------------------------------------------------------
// TODO: Move to shared location
#define countof(a)  (sizeof(a)/sizeof(a[0]))

template <typename T, size_t N>
class Buffer
{
public:             // Interface
                    Buffer()
    {
        std::memset(m_data, 0, N * sizeof(T));
    }

                    Buffer(T const data[])
    {
        std::memcpy(m_data, data, N * sizeof(T));
    }

    T const*        GetData() const             { return m_data; }
    T*              GetData()                   { return m_data; }

    bool            operator==(Buffer const& rhs) const
    {
        return std::memcmp(m_data, rhs.m_data, N * sizeof(T)) == 0;
    }

private:            // Implementation
    T               m_data[N];
};

template <typename T, size_t N>
std::ostream& operator<<(std::ostream &s, Buffer<T, N> const& buffer)
{
    static int const WIDTH = sizeof(T) * 2;
    s.flags(s.hex);
    s.fill('0');
    s << "0x" << std::setw(WIDTH) << static_cast<int>(buffer.GetData()[0]);
    for (size_t i = 1; i != N; ++i)
    {
        s << " 0x" << std::setw(WIDTH) << static_cast<int>(buffer.GetData()[i]);
    }
    return s;
}
//---------------------------------------------------------------------------
using namespace Unicode;
//---------------------------------------------------------------------------
class UTFValidationTest : public CppUnit::TestFixture
{
public:             // Tests
    void            testIsValidTooLarge()
    {
        CPPUNIT_ASSERT(!utf_isValidDchar(0x00201234));
    }

    void            testIsValidSurrogate()
    {
        CPPUNIT_ASSERT(!utf_isValidDchar(0xD900D800));
    }

    void            testIsValidNonCharacter1()
    {
        // TODO: Review this!
        CPPUNIT_ASSERT(utf_isValidDchar(0x03FFFE));
    }

    void            testIsValidNonCharacter2()
    {
        // TODO: Review this!
        CPPUNIT_ASSERT(utf_isValidDchar(0x00FDD9));
    }

    void            testIsValidPrivateUse1()
    {
        CPPUNIT_ASSERT(utf_isValidDchar(0x00E123));
    }

    void            testIsValidPrivateUse2()
    {
        CPPUNIT_ASSERT(utf_isValidDchar(0x0F1234));
    }

    void            testIsValidPrivateUse3()
    {
        CPPUNIT_ASSERT(utf_isValidDchar(0x101234));
    }

    void            testIsValidASCII()
    {
        CPPUNIT_ASSERT(utf_isValidDchar('A'));
    }

    void            testIsValidNonASCII()
    {
        CPPUNIT_ASSERT(utf_isValidDchar(0x001234));
    }

public:             // Implementation
CPPUNIT_TEST_SUITE(UTFValidationTest);
CPPUNIT_TEST(testIsValidTooLarge);
CPPUNIT_TEST(testIsValidSurrogate);
CPPUNIT_TEST(testIsValidNonCharacter1);
CPPUNIT_TEST(testIsValidNonCharacter2);
CPPUNIT_TEST(testIsValidPrivateUse1);
CPPUNIT_TEST(testIsValidPrivateUse2);
CPPUNIT_TEST(testIsValidPrivateUse3);
CPPUNIT_TEST(testIsValidASCII);
CPPUNIT_TEST(testIsValidNonASCII);
CPPUNIT_TEST_SUITE_END();
};
//---------------------------------------------------------------------------
class UTFPredicateTest : public CppUnit::TestFixture
{
private:            // Constants
    static size_t const END = sizeof(ALPHA_TABLE) / sizeof(ALPHA_TABLE[0]);

public:             // Tests
    void            testAlphaTable()
    {
        CPPUNIT_ASSERT(ALPHA_TABLE[0][0] <= ALPHA_TABLE[0][1]);
        for (size_t i = 1; i != END; ++i)
        {
            // Ranges must be non-empty
            CPPUNIT_ASSERT_EQUAL(
                i + 1, i + (ALPHA_TABLE[i][0] <= ALPHA_TABLE[i][1])
            );
            // Ranges must be ascending order, and gaps must be non-empty
            CPPUNIT_ASSERT_EQUAL(
                i + 1, i + (ALPHA_TABLE[i-1][1] + 1 < ALPHA_TABLE[i][0])
            );
        }
    }

    void            testIsUniAlphaTrue()
    {
        for (size_t i = 0; i != END; ++i)
        {
            // Test beginning, middle end of each range
            CPPUNIT_ASSERT(isUniAlpha(ALPHA_TABLE[i][0]));
            CPPUNIT_ASSERT(isUniAlpha(ALPHA_TABLE[i][1]));
            CPPUNIT_ASSERT(
                isUniAlpha((ALPHA_TABLE[i][0] + ALPHA_TABLE[i][1]) / 2)
            );
        }
    }

    void            testIsUniAlphaFalse()
    {
        // Low boundary
        CPPUNIT_ASSERT(!isUniAlpha(0x0000));
        CPPUNIT_ASSERT(!isUniAlpha((0x000 + ALPHA_TABLE[0][0]) / 2));
        for (size_t i = 1; i != END; ++i)
        {
            // Test beginning, middle end of each range-gap
            utf32_t begin = ALPHA_TABLE[i-1][1] + 1;
            utf32_t end = ALPHA_TABLE[i][0] - 1;
            CPPUNIT_ASSERT(!isUniAlpha(begin));
            CPPUNIT_ASSERT(!isUniAlpha(end));
            CPPUNIT_ASSERT(!isUniAlpha((begin + end) / 2));
        }
        // High boundary
        CPPUNIT_ASSERT(!isUniAlpha((ALPHA_TABLE[END-1][1] + 0xFFFF) / 2));
        CPPUNIT_ASSERT(!isUniAlpha(0xFFFF));
    }

public:             // Implementation
CPPUNIT_TEST_SUITE(UTFPredicateTest);
CPPUNIT_TEST(testAlphaTable);
CPPUNIT_TEST(testIsUniAlphaTrue);
CPPUNIT_TEST(testIsUniAlphaFalse);
CPPUNIT_TEST_SUITE_END();
};
//---------------------------------------------------------------------------
class UTFCodeLengthTest : public CppUnit::TestFixture
{
public:             // Tests
    void            testCodeLengthChar1()
    {
        CPPUNIT_ASSERT_EQUAL(1, utf_codeLengthChar('x'));
        CPPUNIT_ASSERT_EQUAL(1, utf_codeLength(1, 'x'));
    }

    void            testCodeLengthChar2()
    {
        CPPUNIT_ASSERT_EQUAL(2, utf_codeLengthChar(0x0000A2));
        CPPUNIT_ASSERT_EQUAL(2, utf_codeLength(1, 0x0000A2));
    }

    void            testCodeLengthChar3()
    {
        CPPUNIT_ASSERT_EQUAL(3, utf_codeLengthChar(0x0020AC));
        CPPUNIT_ASSERT_EQUAL(3, utf_codeLength(1, 0x0020AC));
    }

    void            testCodeLengthChar4()
    {
        CPPUNIT_ASSERT_EQUAL(4, utf_codeLengthChar(0x024B62));
        CPPUNIT_ASSERT_EQUAL(4, utf_codeLength(1, 0x024B62));
    }

    void            testCodeLengthWChar1()
    {
        CPPUNIT_ASSERT_EQUAL(1, utf_codeLengthWchar(0x0000A2));
        CPPUNIT_ASSERT_EQUAL(1, utf_codeLength(2, 0x0000A2));
    }

    void            testCodeLengthWChar2()
    {
        CPPUNIT_ASSERT_EQUAL(2, utf_codeLengthWchar(0x01D11E));
        CPPUNIT_ASSERT_EQUAL(2, utf_codeLength(2, 0x01D11E));
    }

    void            testCodeLengthUCS4()
    {
        CPPUNIT_ASSERT_EQUAL(1, utf_codeLength(4, 0x0020AC));
    }

public:             // Implementation
CPPUNIT_TEST_SUITE(UTFCodeLengthTest);
CPPUNIT_TEST(testCodeLengthChar1);
CPPUNIT_TEST(testCodeLengthChar2);
CPPUNIT_TEST(testCodeLengthChar3);
CPPUNIT_TEST(testCodeLengthChar4);
CPPUNIT_TEST(testCodeLengthWChar1);
CPPUNIT_TEST(testCodeLengthWChar2);
CPPUNIT_TEST(testCodeLengthUCS4);
CPPUNIT_TEST_SUITE_END();
};
//---------------------------------------------------------------------------
class UTFEncodeTest : public CppUnit::TestFixture
{
private:            // Types
    typedef Buffer<utf8_t, 4>   UTF8Buffer;
    typedef Buffer<utf16_t, 2>  UTF16Buffer;
    typedef Buffer<utf32_t, 1>  UTF32Buffer;

public:             // Tests
    void            testEncodeCharASCII()
    {
        static utf8_t const VALUE[] = { 'X', 0x00, 0x00, 0x00 };
        utf_encodeChar(utf8Buffer_.GetData(), 'X');
        CPPUNIT_ASSERT_EQUAL(UTF8Buffer(VALUE), utf8Buffer_);
        utf_encode(1, utf8Buffer_.GetData(), 'X');
        CPPUNIT_ASSERT_EQUAL(UTF8Buffer(VALUE), utf8Buffer_);
    }

    void            testEncodeChar2Unit()
    {
        static utf8_t const VALUE[] = { 0xC2, 0xA2, 0x00, 0x00 };
        utf_encodeChar(utf8Buffer_.GetData(), 0x0000A2);
        CPPUNIT_ASSERT_EQUAL(UTF8Buffer(VALUE), utf8Buffer_);
        utf_encode(1, utf8Buffer_.GetData(), 0x0000A2);
        CPPUNIT_ASSERT_EQUAL(UTF8Buffer(VALUE), utf8Buffer_);
    }

    void            testEncodeChar3Unit()
    {
        static utf8_t const VALUE[] = { 0xE2, 0x82, 0xAC, 0x00 };
        utf_encodeChar(utf8Buffer_.GetData(), 0x0020AC);
        CPPUNIT_ASSERT_EQUAL(UTF8Buffer(VALUE), utf8Buffer_);
        utf_encode(1, utf8Buffer_.GetData(), 0x0020AC);
        CPPUNIT_ASSERT_EQUAL(UTF8Buffer(VALUE), utf8Buffer_);
    }

    void            testEncodeChar4Unit()
    {
        static utf8_t const VALUE[] = { 0xF0, 0xA4, 0xAD, 0xA2 };
        utf_encodeChar(utf8Buffer_.GetData(), 0x024B62);
        CPPUNIT_ASSERT_EQUAL(UTF8Buffer(VALUE), utf8Buffer_);
        utf_encode(1, utf8Buffer_.GetData(), 0x024B62);
        CPPUNIT_ASSERT_EQUAL(UTF8Buffer(VALUE), utf8Buffer_);
    }

    void            testEncodeWCharBMP()
    {
        static utf16_t const VALUE[] = { 0x6C34, 0x0000 };
        utf_encodeWchar(utf16Buffer_.GetData(), 0x6C34);
        CPPUNIT_ASSERT_EQUAL(UTF16Buffer(VALUE), utf16Buffer_);
        utf_encode(2, utf16Buffer_.GetData(), 0x6C34);
        CPPUNIT_ASSERT_EQUAL(UTF16Buffer(VALUE), utf16Buffer_);
    }

    void            testEncodeWCharSupplementary()
    {
        static utf16_t const VALUE[] = { 0xD834, 0xDD1E };
        utf_encodeWchar(utf16Buffer_.GetData(), 0x01D11E);
        CPPUNIT_ASSERT_EQUAL(UTF16Buffer(VALUE), utf16Buffer_);
        utf_encode(2, utf16Buffer_.GetData(), 0x01D11E);
        CPPUNIT_ASSERT_EQUAL(UTF16Buffer(VALUE), utf16Buffer_);
    }

    void            testEncodeUCS4()
    {
        static utf32_t const VALUE[] = { 0x01D11E };
        utf_encode(4, utf32Buffer_.GetData(), 0x01D11E);
        CPPUNIT_ASSERT_EQUAL(UTF32Buffer(VALUE), utf32Buffer_);
    }

private:            // Implementation
    UTF8Buffer      utf8Buffer_;
    UTF16Buffer     utf16Buffer_;
    UTF32Buffer     utf32Buffer_;

public:             // Implementation
CPPUNIT_TEST_SUITE(UTFEncodeTest);
CPPUNIT_TEST(testEncodeCharASCII);
CPPUNIT_TEST(testEncodeChar2Unit);
CPPUNIT_TEST(testEncodeChar3Unit);
CPPUNIT_TEST(testEncodeChar4Unit);
CPPUNIT_TEST(testEncodeWCharBMP);
CPPUNIT_TEST(testEncodeWCharSupplementary);
CPPUNIT_TEST(testEncodeUCS4);
CPPUNIT_TEST_SUITE_END();
};
//---------------------------------------------------------------------------
class UTFDecodeTest : public CppUnit::TestFixture
{
public:             // Interface
    void            setUp()
    {
        i_ = 0;
        c_ = 0;
    }

public:             // Tests
    void            testDecodeCharASCII()
    {
        static utf8_t const VALUE[] = "X";
        CPPUNIT_ASSERT(
            utf_decodeChar(VALUE, sizeof(VALUE) - 1, &i_, &c_) == UTF8_DECODE_OK
        );
        CPPUNIT_ASSERT_EQUAL(size_t(1), i_);
        CPPUNIT_ASSERT_EQUAL(dchar_t('X'), c_);
    }

    void            testDecodeCharOutsideCodeSpace()
    {
        static utf8_t const VALUE[] = { 0xF9, 0x81, 0x92, 0xA3, 0xB4, 0x00 };
        CPPUNIT_ASSERT_EQUAL(
            UTF8_DECODE_OUTSIDE_CODE_SPACE,
            utf_decodeChar(VALUE, sizeof(VALUE) - 1, &i_, &c_)
        );
        CPPUNIT_ASSERT_EQUAL(size_t(1), i_);
        CPPUNIT_ASSERT_EQUAL(dchar_t(0xF9), c_);
    }

    void            testDecodeCharTruncatedSequence()
    {
        static utf8_t const VALUE[] = { 0xF0, 0x81, 0x92, 0xA3 };
        CPPUNIT_ASSERT_EQUAL(
            UTF8_DECODE_TRUNCATED_SEQUENCE,
            utf_decodeChar(VALUE, sizeof(VALUE) - 1, &i_, &c_)
        );
        CPPUNIT_ASSERT_EQUAL(size_t(1), i_);
        CPPUNIT_ASSERT_EQUAL(dchar_t(0xF0), c_);
    }

    void            testDecodeCharOverlong()
    {
        static utf8_t const VALUE[] = { 0xC0, 0x81, 0x00 };
        CPPUNIT_ASSERT_EQUAL(
            UTF8_DECODE_OVERLONG,
            utf_decodeChar(VALUE, sizeof(VALUE) - 1, &i_, &c_)
        );
        CPPUNIT_ASSERT_EQUAL(size_t(1), i_);
        CPPUNIT_ASSERT_EQUAL(dchar_t(0xC0), c_);
    }

    void            testDecodeCharInvalidTrailer()
    {
        static utf8_t const VALUE[] = { 0xC2, 0x23, 0x00 };
        CPPUNIT_ASSERT_EQUAL(
            UTF8_DECODE_INVALID_TRAILER,
            utf_decodeChar(VALUE, sizeof(VALUE) - 1, &i_, &c_)
        );
        CPPUNIT_ASSERT_EQUAL(size_t(1), i_);
        CPPUNIT_ASSERT_EQUAL(dchar_t(0xC2), c_);
    }

    void            testDecodeCharInvalidCodePoint()
    {
        static utf8_t const VALUE[] = { 0xEF, 0xBF, 0xBF, 0x00 };
        CPPUNIT_ASSERT_EQUAL(
            UTF8_DECODE_INVALID_CODE_POINT,
            utf_decodeChar(VALUE, sizeof(VALUE) - 1, &i_, &c_)
        );
        CPPUNIT_ASSERT_EQUAL(size_t(1), i_);
        CPPUNIT_ASSERT_EQUAL(dchar_t(0xEF), c_);
    }

    void            testDecodeChar2Unit()
    {
        static utf8_t const VALUE[] = { 0xD3, 0x93, 0x00 };
        CPPUNIT_ASSERT(
            utf_decodeChar(VALUE, sizeof(VALUE) - 1, &i_, &c_) == UTF8_DECODE_OK
        );
        CPPUNIT_ASSERT_EQUAL(size_t(2), i_);
        CPPUNIT_ASSERT_EQUAL(dchar_t(0x04D3), c_);
    }

    void            testDecodeChar3Unit()
    {
        static utf8_t const VALUE[] = { 0xE3, 0x93, 0xA4, 0x00 };
        CPPUNIT_ASSERT(
            utf_decodeChar(VALUE, sizeof(VALUE) - 1, &i_, &c_) == UTF8_DECODE_OK
        );
        CPPUNIT_ASSERT_EQUAL(size_t(3), i_);
        CPPUNIT_ASSERT_EQUAL(dchar_t(0x34E4), c_);
    }

    void            testDecodeChar4Unit()
    {
        static utf8_t const VALUE[] = { 0xF3, 0x93, 0xA4, 0xB5, 0x00 };
        CPPUNIT_ASSERT(
            utf_decodeChar(VALUE, sizeof(VALUE) - 1, &i_, &c_) == UTF8_DECODE_OK
        );
        CPPUNIT_ASSERT_EQUAL(size_t(4), i_);
        CPPUNIT_ASSERT_EQUAL(dchar_t(0x0D3935), c_);
    }

    void            testDecodeWCharASCII()
    {
        static utf16_t const VALUE[] = { 0x0058, 0x0000 };
        CPPUNIT_ASSERT(
            utf_decodeWchar(VALUE, countof(VALUE) - 1, &i_, &c_)
                == UTF16_DECODE_OK
        );
        CPPUNIT_ASSERT_EQUAL(size_t(1), i_);
        CPPUNIT_ASSERT_EQUAL(dchar_t('X'), c_);
    }

    void            testDecodeWCharTruncatedSequence()
    {
        static utf16_t const VALUE[] = { 0xD858, 0x0000 };
        CPPUNIT_ASSERT_EQUAL(
            UTF16_DECODE_TRUNCATED_SEQUENCE,
            utf_decodeWchar(VALUE, countof(VALUE) - 1, &i_, &c_)
        );
        CPPUNIT_ASSERT_EQUAL(size_t(1), i_);
        CPPUNIT_ASSERT_EQUAL(dchar_t(0xD858), c_);
    }

    void            testDecodeWCharInvalidSurrogate()
    {
        static utf16_t const VALUE[] = { 0xD858, 0xD842, 0x0000 };
        CPPUNIT_ASSERT_EQUAL(
            UTF16_DECODE_INVALID_SURROGATE,
            utf_decodeWchar(VALUE, countof(VALUE) - 1, &i_, &c_)
        );
        CPPUNIT_ASSERT_EQUAL(size_t(1), i_);
        CPPUNIT_ASSERT_EQUAL(dchar_t(0xD858), c_);
    }

    void            testDecodeWCharUnpairedSurrogate()
    {
        static utf16_t const VALUE[] = { 0xDD42, 0x0000 };
        CPPUNIT_ASSERT_EQUAL(
            UTF16_DECODE_UNPAIRED_SURROGATE,
            utf_decodeWchar(VALUE, countof(VALUE) - 1, &i_, &c_)
        );
        CPPUNIT_ASSERT_EQUAL(size_t(1), i_);
        CPPUNIT_ASSERT_EQUAL(dchar_t(0xDD42), c_);
    }

    void            testDecodeWCharInvalidCodePoint()
    {
        static utf16_t const VALUE[] = { 0xFFFE, 0x0000 };
        CPPUNIT_ASSERT_EQUAL(
            UTF16_DECODE_INVALID_CODE_POINT,
            utf_decodeWchar(VALUE, countof(VALUE) - 1, &i_, &c_)
        );
        CPPUNIT_ASSERT_EQUAL(size_t(1), i_);
        CPPUNIT_ASSERT_EQUAL(dchar_t(0xFFFE), c_);
    }

    void            testDecodeWCharBMP()
    {
        static utf16_t const VALUE[] = { 0xA960, 0x0000 };
        CPPUNIT_ASSERT(
            utf_decodeWchar(VALUE, countof(VALUE) - 1, &i_, &c_)
                == UTF16_DECODE_OK
        );
        CPPUNIT_ASSERT_EQUAL(size_t(1), i_);
        CPPUNIT_ASSERT_EQUAL(dchar_t(0xA960), c_);
    }

    void            testDecodeWCharSupplementary()
    {
        static utf16_t const VALUE[] = { 0xD801, 0xDC00, 0x0000 };
        CPPUNIT_ASSERT(
            utf_decodeWchar(VALUE, countof(VALUE) - 1, &i_, &c_)
                == UTF16_DECODE_OK
        );
        CPPUNIT_ASSERT_EQUAL(size_t(2), i_);
        CPPUNIT_ASSERT_EQUAL(dchar_t(0x010400), c_);
    }

private:            // Implementation
    size_t          i_;
    dchar_t         c_;

public:             // Implementation
CPPUNIT_TEST_SUITE(UTFDecodeTest);
CPPUNIT_TEST(testDecodeCharASCII);
CPPUNIT_TEST(testDecodeCharOutsideCodeSpace);
CPPUNIT_TEST(testDecodeCharTruncatedSequence);
CPPUNIT_TEST(testDecodeCharOverlong);
CPPUNIT_TEST(testDecodeCharInvalidTrailer);
CPPUNIT_TEST(testDecodeCharInvalidCodePoint);
CPPUNIT_TEST(testDecodeChar2Unit);
CPPUNIT_TEST(testDecodeChar3Unit);
CPPUNIT_TEST(testDecodeChar4Unit);
CPPUNIT_TEST(testDecodeWCharASCII);
CPPUNIT_TEST(testDecodeWCharTruncatedSequence);
CPPUNIT_TEST(testDecodeWCharInvalidSurrogate);
CPPUNIT_TEST(testDecodeWCharUnpairedSurrogate);
CPPUNIT_TEST(testDecodeWCharInvalidCodePoint);
CPPUNIT_TEST(testDecodeWCharBMP);
CPPUNIT_TEST(testDecodeWCharSupplementary);
CPPUNIT_TEST_SUITE_END();
};
//---------------------------------------------------------------------------
int main()
{
    CppUnit::TextUi::TestRunner runner;
    runner.addTest(UTFValidationTest::suite());
    runner.addTest(UTFPredicateTest::suite());
    runner.addTest(UTFCodeLengthTest::suite());
    runner.addTest(UTFEncodeTest::suite());
    runner.addTest(UTFDecodeTest::suite());
    return !runner.run();
}
//---------------------------------------------------------------------------
