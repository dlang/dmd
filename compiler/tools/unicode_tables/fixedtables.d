/**
Known fixed tables.

Copyright:   Copyright (C) 1999-2024 by The D Language Foundation, All Rights Reserved
Authors:     $(LINK2 https://cattermole.co.nz, Richard (Rikki) Andrew Cattermole)
License:     $(LINK2 https://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
*/
module unicode_tables.fixedtables;
import unicode_tables.util;

immutable ValueRanges ASCII_Table = ValueRanges([
    ValueRange(0, 127)
]);

immutable ValueRanges c99_Table = ValueRanges([
    ValueRange(0x00AA, 0x00AA), ValueRange(0x00B5, 0x00B5),
    ValueRange(0x00B7, 0x00B7), ValueRange(0x00BA, 0x00BA),
    ValueRange(0x00C0, 0x00D6), ValueRange(0x00D8, 0x00F6),
    ValueRange(0x00F8, 0x01F5), ValueRange(0x01FA, 0x0217),
    ValueRange(0x0250, 0x02A8), ValueRange(0x02B0, 0x02B8),
    ValueRange(0x02BB, 0x02BB), ValueRange(0x02BD, 0x02C1),
    ValueRange(0x02D0, 0x02D1), ValueRange(0x02E0, 0x02E4),
    ValueRange(0x037A, 0x037A), ValueRange(0x0386, 0x0386),
    ValueRange(0x0388, 0x038A), ValueRange(0x038C, 0x038C),
    ValueRange(0x038E, 0x03A1), ValueRange(0x03A3, 0x03CE),
    ValueRange(0x03D0, 0x03D6), ValueRange(0x03DA, 0x03DA),
    ValueRange(0x03DC, 0x03DC), ValueRange(0x03DE, 0x03DE),
    ValueRange(0x03E0, 0x03E0), ValueRange(0x03E2, 0x03F3),
    ValueRange(0x0401, 0x040C), ValueRange(0x040E, 0x044F),
    ValueRange(0x0451, 0x045C), ValueRange(0x045E, 0x0481),
    ValueRange(0x0490, 0x04C4), ValueRange(0x04C7, 0x04C8),
    ValueRange(0x04CB, 0x04CC), ValueRange(0x04D0, 0x04EB),
    ValueRange(0x04EE, 0x04F5), ValueRange(0x04F8, 0x04F9),
    ValueRange(0x0531, 0x0556), ValueRange(0x0559, 0x0559),
    ValueRange(0x0561, 0x0587), ValueRange(0x05B0, 0x05B9),
    ValueRange(0x05BB, 0x05BD), ValueRange(0x05BF, 0x05BF),
    ValueRange(0x05C1, 0x05C2), ValueRange(0x05D0, 0x05EA),
    ValueRange(0x05F0, 0x05F2), ValueRange(0x0621, 0x063A),
    ValueRange(0x0640, 0x0652), ValueRange(0x0660, 0x0669),
    ValueRange(0x0670, 0x06B7), ValueRange(0x06BA, 0x06BE),
    ValueRange(0x06C0, 0x06CE), ValueRange(0x06D0, 0x06DC),
    ValueRange(0x06E5, 0x06E8), ValueRange(0x06EA, 0x06ED),
    ValueRange(0x06F0, 0x06F9), ValueRange(0x0901, 0x0903),
    ValueRange(0x0905, 0x0939), ValueRange(0x093D, 0x094D),
    ValueRange(0x0950, 0x0952), ValueRange(0x0958, 0x0963),
    ValueRange(0x0966, 0x096F), ValueRange(0x0981, 0x0983),
    ValueRange(0x0985, 0x098C), ValueRange(0x098F, 0x0990),
    ValueRange(0x0993, 0x09A8), ValueRange(0x09AA, 0x09B0),
    ValueRange(0x09B2, 0x09B2), ValueRange(0x09B6, 0x09B9),
    ValueRange(0x09BE, 0x09C4), ValueRange(0x09C7, 0x09C8),
    ValueRange(0x09CB, 0x09CD), ValueRange(0x09DC, 0x09DD),
    ValueRange(0x09DF, 0x09E3), ValueRange(0x09E6, 0x09F1),
    ValueRange(0x0A02, 0x0A02), ValueRange(0x0A05, 0x0A0A),
    ValueRange(0x0A0F, 0x0A10), ValueRange(0x0A13, 0x0A28),
    ValueRange(0x0A2A, 0x0A30), ValueRange(0x0A32, 0x0A33),
    ValueRange(0x0A35, 0x0A36), ValueRange(0x0A38, 0x0A39),
    ValueRange(0x0A3E, 0x0A42), ValueRange(0x0A47, 0x0A48),
    ValueRange(0x0A4B, 0x0A4D), ValueRange(0x0A59, 0x0A5C),
    ValueRange(0x0A5E, 0x0A5E), ValueRange(0x0A66, 0x0A6F),
    ValueRange(0x0A74, 0x0A74), ValueRange(0x0A81, 0x0A83),
    ValueRange(0x0A85, 0x0A8B), ValueRange(0x0A8D, 0x0A8D),
    ValueRange(0x0A8F, 0x0A91), ValueRange(0x0A93, 0x0AA8),
    ValueRange(0x0AAA, 0x0AB0), ValueRange(0x0AB2, 0x0AB3),
    ValueRange(0x0AB5, 0x0AB9), ValueRange(0x0ABD, 0x0AC5),
    ValueRange(0x0AC7, 0x0AC9), ValueRange(0x0ACB, 0x0ACD),
    ValueRange(0x0AD0, 0x0AD0), ValueRange(0x0AE0, 0x0AE0),
    ValueRange(0x0AE6, 0x0AEF), ValueRange(0x0B01, 0x0B03),
    ValueRange(0x0B05, 0x0B0C), ValueRange(0x0B0F, 0x0B10),
    ValueRange(0x0B13, 0x0B28), ValueRange(0x0B2A, 0x0B30),
    ValueRange(0x0B32, 0x0B33), ValueRange(0x0B36, 0x0B39),
    ValueRange(0x0B3D, 0x0B43), ValueRange(0x0B47, 0x0B48),
    ValueRange(0x0B4B, 0x0B4D), ValueRange(0x0B5C, 0x0B5D),
    ValueRange(0x0B5F, 0x0B61), ValueRange(0x0B66, 0x0B6F),
    ValueRange(0x0B82, 0x0B83), ValueRange(0x0B85, 0x0B8A),
    ValueRange(0x0B8E, 0x0B90), ValueRange(0x0B92, 0x0B95),
    ValueRange(0x0B99, 0x0B9A), ValueRange(0x0B9C, 0x0B9C),
    ValueRange(0x0B9E, 0x0B9F), ValueRange(0x0BA3, 0x0BA4),
    ValueRange(0x0BA8, 0x0BAA), ValueRange(0x0BAE, 0x0BB5),
    ValueRange(0x0BB7, 0x0BB9), ValueRange(0x0BBE, 0x0BC2),
    ValueRange(0x0BC6, 0x0BC8), ValueRange(0x0BCA, 0x0BCD),
    ValueRange(0x0BE7, 0x0BEF), ValueRange(0x0C01, 0x0C03),
    ValueRange(0x0C05, 0x0C0C), ValueRange(0x0C0E, 0x0C10),
    ValueRange(0x0C12, 0x0C28), ValueRange(0x0C2A, 0x0C33),
    ValueRange(0x0C35, 0x0C39), ValueRange(0x0C3E, 0x0C44),
    ValueRange(0x0C46, 0x0C48), ValueRange(0x0C4A, 0x0C4D),
    ValueRange(0x0C60, 0x0C61), ValueRange(0x0C66, 0x0C6F),
    ValueRange(0x0C82, 0x0C83), ValueRange(0x0C85, 0x0C8C),
    ValueRange(0x0C8E, 0x0C90), ValueRange(0x0C92, 0x0CA8),
    ValueRange(0x0CAA, 0x0CB3), ValueRange(0x0CB5, 0x0CB9),
    ValueRange(0x0CBE, 0x0CC4), ValueRange(0x0CC6, 0x0CC8),
    ValueRange(0x0CCA, 0x0CCD), ValueRange(0x0CDE, 0x0CDE),
    ValueRange(0x0CE0, 0x0CE1), ValueRange(0x0CE6, 0x0CEF),
    ValueRange(0x0D02, 0x0D03), ValueRange(0x0D05, 0x0D0C),
    ValueRange(0x0D0E, 0x0D10), ValueRange(0x0D12, 0x0D28),
    ValueRange(0x0D2A, 0x0D39), ValueRange(0x0D3E, 0x0D43),
    ValueRange(0x0D46, 0x0D48), ValueRange(0x0D4A, 0x0D4D),
    ValueRange(0x0D60, 0x0D61), ValueRange(0x0D66, 0x0D6F),
    ValueRange(0x0E01, 0x0E3A), ValueRange(0x0E40, 0x0E5B),
    ValueRange(0x0E81, 0x0E82), ValueRange(0x0E84, 0x0E84),
    ValueRange(0x0E87, 0x0E88), ValueRange(0x0E8A, 0x0E8A),
    ValueRange(0x0E8D, 0x0E8D), ValueRange(0x0E94, 0x0E97),
    ValueRange(0x0E99, 0x0E9F), ValueRange(0x0EA1, 0x0EA3),
    ValueRange(0x0EA5, 0x0EA5), ValueRange(0x0EA7, 0x0EA7),
    ValueRange(0x0EAA, 0x0EAB), ValueRange(0x0EAD, 0x0EAE),
    ValueRange(0x0EB0, 0x0EB9), ValueRange(0x0EBB, 0x0EBD),
    ValueRange(0x0EC0, 0x0EC4), ValueRange(0x0EC6, 0x0EC6),
    ValueRange(0x0EC8, 0x0ECD), ValueRange(0x0ED0, 0x0ED9),
    ValueRange(0x0EDC, 0x0EDD), ValueRange(0x0F00, 0x0F00),
    ValueRange(0x0F18, 0x0F19), ValueRange(0x0F20, 0x0F33),
    ValueRange(0x0F35, 0x0F35), ValueRange(0x0F37, 0x0F37),
    ValueRange(0x0F39, 0x0F39), ValueRange(0x0F3E, 0x0F47),
    ValueRange(0x0F49, 0x0F69), ValueRange(0x0F71, 0x0F84),
    ValueRange(0x0F86, 0x0F8B), ValueRange(0x0F90, 0x0F95),
    ValueRange(0x0F97, 0x0F97), ValueRange(0x0F99, 0x0FAD),
    ValueRange(0x0FB1, 0x0FB7), ValueRange(0x0FB9, 0x0FB9),
    ValueRange(0x10A0, 0x10C5), ValueRange(0x10D0, 0x10F6),
    ValueRange(0x1E00, 0x1E9B), ValueRange(0x1EA0, 0x1EF9),
    ValueRange(0x1F00, 0x1F15), ValueRange(0x1F18, 0x1F1D),
    ValueRange(0x1F20, 0x1F45), ValueRange(0x1F48, 0x1F4D),
    ValueRange(0x1F50, 0x1F57), ValueRange(0x1F59, 0x1F59),
    ValueRange(0x1F5B, 0x1F5B), ValueRange(0x1F5D, 0x1F5D),
    ValueRange(0x1F5F, 0x1F7D), ValueRange(0x1F80, 0x1FB4),
    ValueRange(0x1FB6, 0x1FBC), ValueRange(0x1FBE, 0x1FBE),
    ValueRange(0x1FC2, 0x1FC4), ValueRange(0x1FC6, 0x1FCC),
    ValueRange(0x1FD0, 0x1FD3), ValueRange(0x1FD6, 0x1FDB),
    ValueRange(0x1FE0, 0x1FEC), ValueRange(0x1FF2, 0x1FF4),
    ValueRange(0x1FF6, 0x1FFC), ValueRange(0x203F, 0x2040),
    ValueRange(0x207F, 0x207F), ValueRange(0x2102, 0x2102),
    ValueRange(0x2107, 0x2107), ValueRange(0x210A, 0x2113),
    ValueRange(0x2115, 0x2115), ValueRange(0x2118, 0x211D),
    ValueRange(0x2124, 0x2124), ValueRange(0x2126, 0x2126),
    ValueRange(0x2128, 0x2128), ValueRange(0x212A, 0x2131),
    ValueRange(0x2133, 0x2138), ValueRange(0x2160, 0x2182),
    ValueRange(0x3005, 0x3007), ValueRange(0x3021, 0x3029),
    ValueRange(0x3041, 0x3093), ValueRange(0x309B, 0x309C),
    ValueRange(0x30A1, 0x30F6), ValueRange(0x30FB, 0x30FC),
    ValueRange(0x3105, 0x312C), ValueRange(0x4E00, 0x9FA5),
    ValueRange(0xAC00, 0xD7A3)
]);

immutable ValueRanges c11_Table = ValueRanges([
    ValueRange(0x00A8, 0x00A8), ValueRange(0x00AA, 0x00AA),
    ValueRange(0x00AD, 0x00AD), ValueRange(0x00AF,0x00AF),
    ValueRange(0x00B2, 0x00B5), ValueRange(0x00B7, 0x00BA),
    ValueRange(0x00BC, 0x00BE), ValueRange(0x00C0, 0x00D6),
    ValueRange(0x00D8, 0x00F6), ValueRange(0x00F8, 0x00FF),
    ValueRange(0x0100, 0x167F), ValueRange(0x1681, 0x180D),
    ValueRange(0x180F, 0x1FFF), ValueRange(0x200B, 0x200D),
    ValueRange(0x202A, 0x202E), ValueRange(0x203F, 0x2040),
    ValueRange(0x2054, 0x2054), ValueRange(0x2060, 0x206F),
    ValueRange(0x2070, 0x218F), ValueRange(0x2460, 0x24FF),
    ValueRange(0x2776, 0x2793), ValueRange(0x2C00, 0x2DFF),
    ValueRange(0x2E80, 0x2FFF), ValueRange(0x3004, 0x3007),
    ValueRange(0x3021, 0x302F), ValueRange(0x3031, 0x303F),
    ValueRange(0x3040, 0xD7FF), ValueRange(0xF900, 0xFD3D),
    ValueRange(0xFD40, 0xFDCF), ValueRange(0xFDF0, 0xFE44),
    ValueRange(0xFE47, 0xFFFD), ValueRange(0x10000, 0x1FFFD),
    ValueRange(0x20000, 0x2FFFD), ValueRange(0x30000, 0x3FFFD),
    ValueRange(0x40000, 0x4FFFD), ValueRange(0x50000, 0x5FFFD),
    ValueRange(0x60000, 0x6FFFD), ValueRange(0x70000, 0x7FFFD),
    ValueRange(0x80000, 0x8FFFD), ValueRange(0x90000, 0x9FFFD),
    ValueRange(0xA0000, 0xAFFFD), ValueRange(0xB0000, 0xBFFFD),
    ValueRange(0xC0000, 0xCFFFD), ValueRange(0xD0000, 0xDFFFD),
    ValueRange(0xE0000, 0xEFFFD),
]);