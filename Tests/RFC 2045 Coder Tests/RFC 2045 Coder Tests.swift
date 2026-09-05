import ASCII
import ASCII_Serializer
import Binary_Serializable
import Byte
import Byte_Standard_Library_Integration
import Coder
import Coder_Standard_Library_Integration
import Cursor_Standard_Library_Integration
import Parseable_ASCII
import Parser
import RFC_2045
import RFC_2045_Coder
import RFC_5322
import Serializer
import Testing

@Suite
struct `RFC 2045 Coder Tests` {
    @Suite struct `Content Type Tests` {}
    @Suite struct `Content Transfer Encoding Tests` {}
    @Suite struct `Charset Tests` {}
    @Suite struct `Parameter Name Tests` {}
    @Suite struct `Header Tests` {}
}

extension `RFC 2045 Coder Tests`.`Content Type Tests` {

    @Test
    func `reads a media type and stops at the first foreign byte`() throws {
        var input: ArraySlice<Byte> = "text/plain\r\nContent-Length: 12"
        #expect(try RFC_2045.ContentType.coder.parse(&input) == RFC_2045.ContentType.textPlain)
        #expect(input.first == ASCII.Code.cr.byte)
    }

    @Test
    func `reads a media type with a parameter`() throws {
        var input: ArraySlice<Byte> = "text/html; charset=UTF-8"
        let contentType = try RFC_2045.ContentType.coder.parse(&input)
        #expect(contentType == RFC_2045.ContentType.textHTMLUTF8)
        #expect(contentType.charset == RFC_2045.Charset.utf8)
        #expect(input.isEmpty)
    }

    @Test
    func `reads a quoted parameter value`() throws {
        var input: ArraySlice<Byte> = #"multipart/mixed; boundary="----=_Part 1234""#
        let contentType = try RFC_2045.ContentType.coder.parse(&input)
        #expect(contentType.boundary == "----=_Part 1234")
        #expect(contentType.isMultipart)
    }

    @Test
    func `reads a parameter list and lowercases the parameter names`() throws {
        var input: ArraySlice<Byte> = "multipart/mixed; BOUNDARY=abc; Charset=UTF-8"
        let contentType = try RFC_2045.ContentType.coder.parse(&input)
        #expect(contentType.boundary == "abc")
        #expect(contentType.parameters[.charset] == "UTF-8")
    }

    @Test
    func `restores the cursor when the media type has no separator`() {
        var input: ArraySlice<Byte> = "text plain"
        #expect(throws: RFC_2045.ContentType.Error.missingSeparator("text")) {
            try RFC_2045.ContentType.coder.parse(&input)
        }
        #expect(input.count == 10)
    }

    @Test
    func `serializes the canonical field value with its parameters sorted`() throws {
        let contentType = try RFC_2045.ContentType(
            type: "multipart",
            subtype: "mixed",
            parameters: [.charset: "UTF-8", .boundary: "abc"]
        )
        var buffer: [Byte] = []
        try RFC_2045.ContentType.coder.serialize(contentType, into: &buffer)
        #expect(
            String(decoding: buffer, as: UTF8.self)
                == "multipart/mixed; boundary=abc; charset=UTF-8"
        )
    }

    @Test
    func `serializes a parameter value that is not a token as a quoted string`() {
        let contentType = RFC_2045.ContentType.multipartMixed(boundary: "----=_Part 1234")
        #expect(contentType.description == #"multipart/mixed; boundary="----=_Part 1234""#)
    }

    @Test
    func `encodes through the codable seam and reads the bytes back`() throws {
        let contentType = RFC_2045.ContentType.textPlainUTF8
        let bytes: [Byte] = try contentType.encoded()
        var input = bytes[...]
        #expect(try RFC_2045.ContentType(decoding: &input) == contentType)
    }

    @Test
    func `a media type round trips through its text form`() throws {
        #expect(try RFC_2045.ContentType("text/plain; charset=UTF-8").description
            == "text/plain; charset=UTF-8")
        #expect(try RFC_2045.ContentType("TEXT/PLAIN").type == "text")
        #expect(try RFC_2045.ContentType("  text/plain  ").subtype == "plain")
    }

    @Test
    func `a media type reads from ASCII bytes`() throws {
        let contentType = try RFC_2045.ContentType(ascii: [Byte](utf8: "image/png"))
        #expect(contentType == RFC_2045.ContentType.imagePNG)
    }

    @Test
    func `a media type renders its header value and its serialized bytes`() {
        let contentType = RFC_2045.ContentType.textHTMLUTF8
        #expect(contentType.headerValue == "text/html; charset=UTF-8")
        #expect(contentType.rawValue == "text/html; charset=UTF-8")
        #expect([Byte](contentType) == [Byte](utf8: "text/html; charset=UTF-8"))
    }

    @Test
    func `an empty field value is refused`() {
        #expect(throws: RFC_2045.ContentType.Error.empty) {
            try RFC_2045.ContentType("")
        }
    }

    @Test
    func `a field value without a solidus is refused`() {
        #expect(throws: RFC_2045.ContentType.Error.missingSeparator("text")) {
            try RFC_2045.ContentType("text")
        }
    }

    @Test
    func `a field value outside ASCII is refused`() {
        #expect(throws: RFC_2045.ContentType.Error.nonASCII("téxt/plain")) {
            try RFC_2045.ContentType("téxt/plain")
        }
    }
}

extension `RFC 2045 Coder Tests`.`Content Transfer Encoding Tests` {

    @Test
    func `reads a mechanism name and stops at the first foreign byte`() throws {
        var input: ArraySlice<Byte> = "base64\r\n"
        #expect(try RFC_2045.ContentTransferEncoding.coder.parse(&input) == .base64)
        #expect(input.first == ASCII.Code.cr.byte)
    }

    @Test
    func `reads a mechanism name case-insensitively`() throws {
        var input: ArraySlice<Byte> = "Quoted-Printable"
        #expect(try RFC_2045.ContentTransferEncoding.coder.parse(&input) == .quotedPrintable)
    }

    @Test
    func `restores the cursor on an unknown mechanism name`() {
        var input: ArraySlice<Byte> = "uuencode"
        #expect(
            throws: RFC_2045.ContentTransferEncoding.Error.unrecognizedEncoding("uuencode")
        ) {
            try RFC_2045.ContentTransferEncoding.coder.parse(&input)
        }
        #expect(input.count == 8)
    }

    @Test
    func `serializes the mechanism name`() throws {
        var buffer: [Byte] = []
        try RFC_2045.ContentTransferEncoding.coder.serialize(.base64, into: &buffer)
        #expect(String(decoding: buffer, as: UTF8.self) == "base64")
    }

    @Test
    func `a mechanism writes itself into an ASCII buffer`() {
        var buffer: [ASCII.Code] = []
        RFC_2045.ContentTransferEncoding.serialize(.quotedPrintable, into: &buffer)
        #expect(String(decoding: buffer.lazy.map(\.underlying), as: UTF8.self)
            == "quoted-printable")
    }

    @Test
    func `a mechanism serializes to bytes`() {
        #expect(RFC_2045.ContentTransferEncoding.sevenBit.serialized == [Byte](utf8: "7bit"))
        #expect([Byte](RFC_2045.ContentTransferEncoding.eightBit) == [Byte](utf8: "8bit"))
    }
}

extension `RFC 2045 Coder Tests`.`Charset Tests` {

    @Test
    func `reads a charset identifier and uppercases it`() throws {
        var input: ArraySlice<Byte> = "utf-8; rest"
        #expect(try RFC_2045.Charset.coder.parse(&input) == RFC_2045.Charset.utf8)
        #expect(input.first == ASCII.Code.semicolon.byte)
    }

    @Test
    func `serializes a charset identifier`() throws {
        var buffer: [Byte] = []
        try RFC_2045.Charset.coder.serialize(.iso88591, into: &buffer)
        #expect(String(decoding: buffer, as: UTF8.self) == "ISO-8859-1")
    }

    @Test
    func `a charset serializes to bytes`() {
        #expect(RFC_2045.Charset.utf8.serialized == [Byte](utf8: "UTF-8"))
        #expect([Byte](RFC_2045.Charset.usASCII) == [Byte](utf8: "US-ASCII"))
    }

    @Test
    func `restores the cursor on an empty charset identifier`() {
        var input: ArraySlice<Byte> = "; charset=UTF-8"
        #expect(throws: RFC_2045.Charset.Error.empty) {
            try RFC_2045.Charset.coder.parse(&input)
        }
        #expect(input.count == 15)
    }
}

extension `RFC 2045 Coder Tests`.`Parameter Name Tests` {

    @Test
    func `reads a parameter name and stops at the equals sign`() throws {
        var input: ArraySlice<Byte> = "boundary=abc"
        #expect(try RFC_2045.Parameter.Name.coder.parse(&input) == RFC_2045.Parameter.Name.boundary)
        #expect(input.first == ASCII.Code.equalsSign.byte)
    }

    @Test
    func `serializes a parameter name`() throws {
        var buffer: [Byte] = []
        try RFC_2045.Parameter.Name.coder.serialize(.charset, into: &buffer)
        #expect(String(decoding: buffer, as: UTF8.self) == "charset")
    }

    @Test
    func `a parameter name serializes to bytes`() {
        #expect(RFC_2045.Parameter.Name.name.serialized == [Byte](utf8: "name"))
    }
}

extension `RFC 2045 Coder Tests`.`Header Tests` {

    @Test
    func `a content type becomes an RFC 5322 header`() throws {
        let header = try RFC_5322.Header(RFC_2045.ContentType.textPlainUTF8)
        #expect(header.name == RFC_5322.Header.Name.contentType)
        #expect(header.value.rawValue == "text/plain; charset=UTF-8")
    }

    @Test
    func `a transfer encoding becomes an RFC 5322 header`() throws {
        let header = try RFC_5322.Header(RFC_2045.ContentTransferEncoding.base64)
        #expect(header.name == RFC_5322.Header.Name.contentTransferEncoding)
        #expect(header.value.rawValue == "base64")
    }
}
