public import ASCII
public import ASCII_Serializer
public import Binary_Serializable
public import Byte
public import Parseable_ASCII
public import RFC_2045

extension RFC_2045.ContentTransferEncoding: @retroactive ASCII.Parseable {}

extension RFC_2045.ContentTransferEncoding: @retroactive ASCII.Serializable,
    @retroactive Binary.Serializable
{

    public static func serialize<Buffer: RangeReplaceableCollection>(
        _ value: borrowing RFC_2045.ContentTransferEncoding,
        into buffer: inout Buffer
    ) where Buffer.Element == ASCII.Code {
        for byte in value.rawValue.utf8 { buffer.append(ASCII.Code(byte)) }
    }

    public static func serialize<Buffer: RangeReplaceableCollection>(
        _ value: borrowing RFC_2045.ContentTransferEncoding,
        into buffer: inout Buffer
    ) where Buffer.Element == Byte {
        buffer.append(contentsOf: value.rawValue.utf8.lazy.map(Byte.init(bitPattern:)))
    }
}

extension [Byte] {

    public init(_ contentTransferEncoding: RFC_2045.ContentTransferEncoding) {
        self = [Byte](contentTransferEncoding.rawValue.utf8.lazy.map(Byte.init(bitPattern:)))
    }

    public init(_ contentTransferEncoding: RFC_2045.ContentTransferEncoding.Type) {
        self = [Byte]("Content-Transfer-Encoding".utf8.lazy.map(Byte.init(bitPattern:)))
    }
}
