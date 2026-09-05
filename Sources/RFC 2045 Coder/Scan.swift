import Byte
import Cursor

enum Scan {

    static func run<Input: Cursor.`Protocol`<Byte, Never>>(
        _ input: inout Input,
        while predicate: (UInt8) -> Bool
    ) -> [Byte] {
        var bytes: [Byte] = []
        while true {
            let mark = input.checkpoint
            guard let byte = input.next(), predicate(byte.bitPattern) else {
                input.seek(to: mark)
                return bytes
            }
            bytes.append(byte)
        }
    }

    static func skipWhitespace<Input: Cursor.`Protocol`<Byte, Never>>(_ input: inout Input) {
        _ = run(&input) { $0 == 0x20 || $0 == 0x09 }
    }

    static func take<Input: Cursor.`Protocol`<Byte, Never>>(
        _ input: inout Input,
        _ byte: UInt8
    ) -> Bool {
        let mark = input.checkpoint
        guard let next = input.next(), next.bitPattern == byte else {
            input.seek(to: mark)
            return false
        }
        return true
    }

    static func append<Buffer: RangeReplaceableCollection<Byte>>(
        _ string: String,
        into buffer: inout Buffer
    ) {
        buffer.append(contentsOf: string.utf8.lazy.map(Byte.init(bitPattern:)))
    }
}
