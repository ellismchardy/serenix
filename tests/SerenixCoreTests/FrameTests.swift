import SerenixCore
import Testing

private let capture = SyncCapture.historySync20261027

/// Commands the phone sent to the Strap.
private let capturedCommands = capture.messages.filter { $0.direction == .out }

/// Frames the Strap sent. The one message on fd4b0007 is not a Frame.
private let strapFrames = capture.messages.filter {
    $0.direction == .in && $0.characteristic != "fd4b0007"
}

/// Frame layout: `aa 01`, 2-byte length, 2 bytes, 2-byte header check, body, 4-byte CRC.
private let headerSize = 8
private let crcSize = 4

@Test func everyCapturedCommandEncodesToItsCapturedBytes() throws {
    #expect(capturedCommands.count == 164)
    for message in capturedCommands {
        let bytes = message.bytes
        // Command body: 23 <sequence> <op> <arguments...>
        let sequence = bytes[9]
        let command = Command(op: bytes[10], arguments: Array(bytes[11..<(bytes.count - crcSize)]))
        #expect(try command.frame(sequence: sequence) == bytes, "command at \(message.time)")
    }
}

@Test func everyStrapFrameParsesWithItsBody() throws {
    #expect(strapFrames.count == 2513)
    for message in strapFrames {
        let frame = try Frame(bytes: message.bytes)
        #expect(
            frame.body == Array(message.bytes[headerSize..<(message.bytes.count - crcSize)]),
            "Frame at \(message.time)"
        )
    }
}

@Test func strapReplyParsesToItsTypeAndBody() throws {
    // The Strap's reply to 0x61, as captured.
    let bytes: [UInt8] = [
        0xaa, 0x01, 0x0c, 0x00, 0x01, 0x00, 0x27, 0x11,
        0x24, 0x4c, 0x61, 0x01, 0x01, 0x00, 0x00, 0x00,
        0xe2, 0x3e, 0xc1, 0xdd,
    ]
    let frame = try Frame(bytes: bytes)
    #expect(frame.type == 0x24)
    #expect(frame.body == [0x24, 0x4c, 0x61, 0x01, 0x01, 0x00, 0x00, 0x00])
}

@Test func strapFrameWithOneBodyByteChangedIsRejectedAsBadCRC() {
    for message in strapFrames {
        var bytes = message.bytes
        let bodyCount = bytes.count - headerSize - crcSize
        bytes[headerSize + bodyCount / 2] ^= 0x01
        #expect(throws: FrameError.badCRC, "Frame at \(message.time)") {
            try Frame(bytes: bytes)
        }
    }
}

@Test func messageNotStartingWithFrameMarkerIsRejectedAsNotAFrame() throws {
    let nonFrames = capture.messages.filter { $0.characteristic == "fd4b0007" }
    #expect(nonFrames.count == 1)
    let message = try #require(nonFrames.first)
    #expect(throws: FrameError.notAFrame) {
        try Frame(bytes: message.bytes)
    }
}

@Test func frameWhoseLengthFieldDisagreesWithItsSizeIsRejectedAsLengthMismatch() throws {
    // A captured Strap reply with one body byte dropped, so it is a byte shorter than its
    // length field says.
    let message = try #require(strapFrames.first)
    var bytes = message.bytes
    bytes.remove(at: headerSize + 1)
    #expect(throws: FrameError.lengthMismatch) {
        try Frame(bytes: bytes)
    }
}

@Test func buildingCommandOfLengthWithNoKnownHeaderCheckFails() {
    // Body 23 <sequence> 16 00 00 is 5 bytes, so the length field would be 9, which no
    // captured command uses.
    let command = Command(op: 0x16, arguments: [0x00, 0x00])
    #expect(throws: FrameError.unknownLength(9)) {
        try command.frame(sequence: 1)
    }
}
