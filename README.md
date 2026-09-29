# swift-rfc-2045-coder

Wire coders for the MIME types of [swift-rfc-2045](https://github.com/swift-ietf/swift-rfc-2045): `RFC_2045.ContentType.Coder`, `RFC_2045.ContentTransferEncoding.Coder`, `RFC_2045.Charset.Coder` and `RFC_2045.Parameter.Name.Coder` read and write their RFC 2045 field grammars over any byte cursor, `Coder.Codable` gives every one of them `encoded()` and `init(decoding:)`, and the `ASCII.Parseable`, `ASCII.Serializable` and `Binary.Serializable` conformances, the `[Byte].init(_:)` forms and the `ContentType` text forms (`description`, `headerValue`, `RawRepresentable`) live here together with the `RFC_5322.Header` and `RFC_5322.Header.Value` initializers for the Content-Type and Content-Transfer-Encoding fields. The domain package keeps the validating `init(_:)` / `init(ascii:)` initializers and stays free of parser and serializer dependencies; add the product `RFC 2045 Coder` to any target that renders or streams MIME headers on the wire.

```swift
import Byte
import Byte_Standard_Library_Integration
import RFC_2045
import RFC_2045_Coder

var input: ArraySlice<Byte> = "text/html; charset=UTF-8\r\n"
let contentType = try RFC_2045.ContentType.coder.parse(&input)
contentType.headerValue                              // "text/html; charset=UTF-8"

let header = try RFC_5322.Header(RFC_2045.ContentTransferEncoding.base64)
header.value.rawValue                                // "base64"
```
