public import Byte
public import Coder
public import Cursor
public import Cursor_Standard_Library_Integration
public import RFC_2045
import ASCII
import Byte_Standard_Library_Integration
import Parser
import Serializer

extension RFC_2045.ContentType {

    public struct Coder<
        Input: Cursor.`Protocol`<Byte, Never>,
        Buffer: RangeReplaceableCollection<Byte>
    >: Coding {

        public typealias Output = RFC_2045.ContentType

        public typealias Failure = RFC_2045.ContentType.Error

        public init() {}

        public borrowing func parse(_ input: inout Input) throws(Failure) -> Output {

            let start = input.checkpoint

            Scan.skipWhitespace(&input)

            let typeBytes = Scan.run(&input, while: RFC_2045.Grammar.isTokenCharacter)

            guard !typeBytes.isEmpty else {
                input.seek(to: start)
                throw .emptyType("")
            }

            guard Scan.take(&input, ASCII.Code.solidus.underlying) else {
                input.seek(to: start)
                throw .missingSeparator(String(decoding: typeBytes, as: UTF8.self))
            }

            let subtypeBytes = Scan.run(&input, while: RFC_2045.Grammar.isTokenCharacter)

            guard !subtypeBytes.isEmpty else {
                input.seek(to: start)
                throw .emptySubtype(String(decoding: typeBytes, as: UTF8.self))
            }

            var parameters: [RFC_2045.Parameter.Name: String] = [:]

            fields: while true {

                let mark = input.checkpoint

                Scan.skipWhitespace(&input)

                guard Scan.take(&input, ASCII.Code.semicolon.underlying) else {
                    input.seek(to: mark)
                    break fields
                }

                Scan.skipWhitespace(&input)

                let nameBytes = Scan.run(&input, while: RFC_2045.Grammar.isTokenCharacter)

                guard
                    !nameBytes.isEmpty,
                    Scan.take(&input, ASCII.Code.equalsSign.underlying)
                else {
                    input.seek(to: mark)
                    break fields
                }

                guard
                    let name = RFC_2045.Parameter.Name(
                        rawValue: String(decoding: nameBytes, as: UTF8.self).lowercased()
                    )
                else {
                    input.seek(to: mark)
                    break fields
                }

                guard let value = Self.value(&input) else {
                    input.seek(to: mark)
                    break fields
                }

                parameters[name] = value
            }

            do throws(Failure) {
                return try RFC_2045.ContentType(
                    type: String(decoding: typeBytes, as: UTF8.self),
                    subtype: String(decoding: subtypeBytes, as: UTF8.self),
                    parameters: parameters
                )
            } catch {
                input.seek(to: start)
                throw error
            }
        }

        static func value(_ input: inout Input) -> String? {

            guard Scan.take(&input, ASCII.Code.quotationMark.underlying) else {
                let bytes = Scan.run(&input, while: RFC_2045.Grammar.isTokenCharacter)
                guard !bytes.isEmpty else { return nil }
                return String(decoding: bytes, as: UTF8.self)
            }

            var bytes: [Byte] = []
            var escaped = false

            while let byte = input.next() {

                if escaped {
                    bytes.append(byte)
                    escaped = false
                } else if byte.bitPattern == ASCII.Code.reverseSolidus.underlying {
                    escaped = true
                } else if byte.bitPattern == ASCII.Code.quotationMark.underlying {
                    return String(decoding: bytes, as: UTF8.self)
                } else {
                    bytes.append(byte)
                }
            }

            return nil
        }

        public borrowing func serialize(
            _ output: Output,
            into buffer: inout Buffer
        ) throws(Failure) {
            buffer.append(contentsOf: RFC_2045.ContentType.canonical(output))
        }
    }

    public static var coder: Coder<ArraySlice<Byte>, [Byte]> { .init() }
}

extension RFC_2045.ContentType: Coder.Codable {}
