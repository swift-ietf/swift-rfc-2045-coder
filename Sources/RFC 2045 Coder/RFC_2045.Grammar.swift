import ASCII
import Byte
import RFC_2045

extension RFC_2045 {

    enum Grammar {

        static func isTokenCharacter(_ byte: UInt8) -> Bool {
            guard byte >= 0x21 && byte <= 0x7E else { return false }
            return switch byte {
            case 0x28, 0x29: false
            case 0x3C, 0x3E: false
            case 0x40: false
            case 0x2C: false
            case 0x3B: false
            case 0x3A: false
            case 0x5C: false
            case 0x22: false
            case 0x2F: false
            case 0x5B, 0x5D: false
            case 0x3F: false
            case 0x3D: false
            default: true
            }
        }

        static func isWhitespace(_ code: ASCII.Code) -> Bool {
            code == ASCII.Code.space
                || code == ASCII.Code.htab
                || code == ASCII.Code.lf
                || code == ASCII.Code.cr
        }

        static func trimmingWhitespace(
            _ codes: ArraySlice<ASCII.Code>
        ) -> ArraySlice<ASCII.Code> {
            var start = codes.startIndex
            var end = codes.endIndex
            while start < end && isWhitespace(codes[start]) {
                start += 1
            }
            while end > start && isWhitespace(codes[end - 1]) {
                end -= 1
            }
            return codes[start..<end]
        }

        static func codes<Bytes: Swift.Collection>(
            _ bytes: Bytes
        ) throws(ASCII.Code.Error) -> [ASCII.Code] where Bytes.Element == Byte {
            var built: [ASCII.Code] = []
            built.reserveCapacity(bytes.count)
            for byte in bytes {
                built.append(try ASCII.Code(byte))
            }
            return built
        }

        static func requiresQuoting(_ value: String) -> Bool {
            value.isEmpty || !value.utf8.allSatisfy(isTokenCharacter)
        }

        static func quoted(_ value: String) -> [UInt8] {
            var out: [UInt8] = [0x22]
            for byte in value.utf8 {
                if byte == 0x22 || byte == 0x5C {
                    out.append(0x5C)
                }
                out.append(byte)
            }
            out.append(0x22)
            return out
        }
    }
}
