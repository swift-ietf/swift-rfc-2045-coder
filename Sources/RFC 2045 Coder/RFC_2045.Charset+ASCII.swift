public import ASCII
public import ASCII_Serializer
public import Binary_Serializable
public import Byte
public import Parseable_ASCII
public import RFC_2045

extension RFC_2045.Charset: @retroactive ASCII.Parseable {}

extension RFC_2045.Charset: @retroactive ASCII.Serializable, @retroactive Binary.Serializable {

    public static func serialize<Buffer: RangeReplaceableCollection>(
        _ value: borrowing RFC_2045.Charset,
        into buffer: inout Buffer
    ) where Buffer.Element == ASCII.Code {
        for byte in value.rawValue.utf8 { buffer.append(ASCII.Code(byte)) }
    }

    public static func serialize<Buffer: RangeReplaceableCollection>(
        _ value: borrowing RFC_2045.Charset,
        into buffer: inout Buffer
    ) where Buffer.Element == Byte {
        buffer.append(contentsOf: value.rawValue.utf8.lazy.map(Byte.init(bitPattern:)))
    }
}

extension [Byte] {

    public init(_ charset: RFC_2045.Charset) {
        self = [Byte](charset.rawValue.utf8.lazy.map(Byte.init(bitPattern:)))
    }
}
