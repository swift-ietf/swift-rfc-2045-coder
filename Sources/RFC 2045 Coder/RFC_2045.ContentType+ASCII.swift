public import ASCII
public import ASCII_Serializer
public import Binary_Serializable
public import Byte
import Byte_Standard_Library_Integration
public import Parseable_ASCII
public import RFC_2045

extension RFC_2045.ContentType: @retroactive ASCII.Serializable,
    @retroactive Binary.Serializable
{

    public static func serialize<Buffer: RangeReplaceableCollection>(
        _ value: borrowing RFC_2045.ContentType,
        into buffer: inout Buffer
    ) where Buffer.Element == ASCII.Code {
        buffer.append(
            contentsOf: canonical(value).lazy.map { ASCII.Code(unchecked: $0) }
        )
    }

    public static func serialize<Buffer: RangeReplaceableCollection>(
        _ value: borrowing RFC_2045.ContentType,
        into buffer: inout Buffer
    ) where Buffer.Element == Byte {
        buffer.append(contentsOf: canonical(value))
    }

    static func canonical(_ value: borrowing RFC_2045.ContentType) -> [Byte] {

        var buffer: [Byte] = []
        buffer.reserveCapacity(
            value.type.count + 1 + value.subtype.count + (value.parameters.count * 30)
        )

        buffer.append(contentsOf: value.type.utf8.lazy.map(Byte.init(bitPattern:)))
        buffer.append(ASCII.Code.solidus.byte)
        buffer.append(contentsOf: value.subtype.utf8.lazy.map(Byte.init(bitPattern:)))

        for (name, parameterValue) in value.parameters.sorted(by: { $0.key < $1.key }) {

            buffer.append(ASCII.Code.semicolon.byte)
            buffer.append(ASCII.Code.space.byte)
            buffer.append(contentsOf: name.rawValue.utf8.lazy.map(Byte.init(bitPattern:)))
            buffer.append(ASCII.Code.equalsSign.byte)

            if RFC_2045.Grammar.requiresQuoting(parameterValue) {
                buffer.append(
                    contentsOf: RFC_2045.Grammar.quoted(parameterValue).lazy.map(
                        Byte.init(bitPattern:)
                    )
                )
            } else {
                buffer.append(
                    contentsOf: parameterValue.utf8.lazy.map(Byte.init(bitPattern:))
                )
            }
        }

        return buffer
    }
}

extension RFC_2045.ContentType: @retroactive ASCII.Parseable {

    public init(_ string: some StringProtocol) throws(Error) {
        try self.init(ascii: string.utf8.map(Byte.init(bitPattern:)))
    }

    public init<Bytes: Swift.Collection>(ascii bytes: Bytes) throws(Error)
    where Bytes.Element == Byte {

        guard !bytes.isEmpty else {
            throw Error.empty
        }

        let codes: [ASCII.Code]
        do throws(ASCII.Code.Error) {
            codes = try RFC_2045.Grammar.codes(bytes)
        } catch {
            throw Error.nonASCII(String(decoding: bytes, as: UTF8.self))
        }

        let typeSubtypeCodes: ArraySlice<ASCII.Code>
        let parameterCodes: ArraySlice<ASCII.Code>?

        if let firstSemicolon = codes.firstIndex(of: ASCII.Code.semicolon) {
            typeSubtypeCodes = codes[..<firstSemicolon]
            parameterCodes = codes[(firstSemicolon + 1)...]
        } else {
            typeSubtypeCodes = codes[...]
            parameterCodes = nil
        }

        guard let solidus = typeSubtypeCodes.firstIndex(of: ASCII.Code.solidus) else {
            throw Error.missingSeparator(String(decoding: bytes, as: UTF8.self))
        }

        let typeCodes = RFC_2045.Grammar.trimmingWhitespace(typeSubtypeCodes[..<solidus])
        let subtypeCodes = RFC_2045.Grammar.trimmingWhitespace(
            typeSubtypeCodes[(solidus + 1)...]
        )

        guard !typeCodes.isEmpty else {
            throw Error.emptyType(String(decoding: bytes, as: UTF8.self))
        }

        guard !subtypeCodes.isEmpty else {
            throw Error.emptySubtype(String(decoding: bytes, as: UTF8.self))
        }

        let type = String(decoding: typeCodes.lazy.map(\.underlying), as: UTF8.self)
            .lowercased()
        let subtype = String(decoding: subtypeCodes.lazy.map(\.underlying), as: UTF8.self)
            .lowercased()

        var parameters: [RFC_2045.Parameter.Name: String] = [:]

        if let parameterCodes {

            let all = Array(parameterCodes)
            var segmentStart = 0

            func read(_ lower: Int, _ upper: Int) {

                let segment = all[lower..<upper]

                guard let equals = segment.firstIndex(of: ASCII.Code.equalsSign) else {
                    return
                }

                let keyCodes = RFC_2045.Grammar.trimmingWhitespace(segment[..<equals])
                var valueCodes = Array(
                    RFC_2045.Grammar.trimmingWhitespace(segment[(equals + 1)...])
                )

                guard !keyCodes.isEmpty else {
                    return
                }

                let isQuoted =
                    valueCodes.count >= 2
                    && valueCodes.first == ASCII.Code.quotationMark
                    && valueCodes.last == ASCII.Code.quotationMark

                if isQuoted {
                    valueCodes = Array(valueCodes.dropFirst().dropLast())
                    var unescaped: [ASCII.Code] = []
                    unescaped.reserveCapacity(valueCodes.count)
                    var escaped = false
                    for code in valueCodes {
                        if escaped {
                            unescaped.append(code)
                            escaped = false
                        } else if code == ASCII.Code.reverseSolidus {
                            escaped = true
                        } else {
                            unescaped.append(code)
                        }
                    }
                    valueCodes = unescaped
                }

                guard
                    let key = RFC_2045.Parameter.Name(
                        rawValue: String(
                            decoding: keyCodes.lazy.map(\.underlying),
                            as: UTF8.self
                        ).lowercased()
                    )
                else {
                    return
                }

                parameters[key] = String(
                    decoding: valueCodes.lazy.map(\.underlying),
                    as: UTF8.self
                )
            }

            var inQuotedString = false
            var inQuotedPair = false

            for index in 0..<all.count {

                let code = all[index]

                if inQuotedPair {
                    inQuotedPair = false
                } else if inQuotedString {
                    if code == ASCII.Code.reverseSolidus {
                        inQuotedPair = true
                    } else if code == ASCII.Code.quotationMark {
                        inQuotedString = false
                    }
                } else if code == ASCII.Code.quotationMark {
                    inQuotedString = true
                } else if code == ASCII.Code.semicolon {
                    read(segmentStart, index)
                    segmentStart = index &+ 1
                }
            }

            read(segmentStart, all.count)
        }

        self.init(__unchecked: (), type: type, subtype: subtype, parameters: parameters)
    }
}

extension RFC_2045.ContentType: @retroactive Swift.RawRepresentable {

    public var rawValue: String {
        String(decoding: RFC_2045.ContentType.canonical(self), as: UTF8.self)
    }

    public init?(rawValue: String) {
        do throws(Error) {
            try self.init(rawValue)
        } catch {
            return nil
        }
    }
}

extension RFC_2045.ContentType: @retroactive CustomStringConvertible {

    public var description: String {
        rawValue
    }
}

extension RFC_2045.ContentType {

    public var headerValue: String {
        rawValue
    }
}

extension [Byte] {

    public init(_ contentType: RFC_2045.ContentType) {
        self = RFC_2045.ContentType.canonical(contentType)
    }

    public init(_ contentType: RFC_2045.ContentType.Type) {
        self = [Byte]("Content-Type".utf8.lazy.map(Byte.init(bitPattern:)))
    }
}
