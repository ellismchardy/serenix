"""Build the History Sync test fixture from an hr-tracker capture dump.

Usage: python scripts/make-sync-fixture.py <capture.txt> <fixture.txt>

Reads the text dump of a .pklg capture (hr-tracker/captures/*.txt), keeps only the messages on
the Strap's fd4b characteristics, and writes one per line, grouped by connection:

    # connection 2026-10-27 19:43:14.003
    19:44:05.728 out fd4b0002 aa0108000001e671...
    19:44:06.059 in fd4b0003 aa010c0001002711...

The serial, device ID, Bluetooth addresses and the fd4b0007 token are replaced with fake values
of the same length, and the CRC of every changed Frame is recalculated (docs/conventions.md,
Testing). The script fails if any original identifier is left. The raw capture is never
committed.
"""

import re
import sys
import zlib

# Replacements keep each identifier's length, so Frame lengths and header checks don't change.
FAKE_SERIAL = b"5AG0000000"
FAKE_DEVICE_ID = b"deadbeef"  # repeated, then cut to the original's length
FAKE_ADDRESSES = [b"00:11:22:33:44:55", b"66:77:88:99:AA:BB"]
FAKE_TOKEN_CHAR = b"X"

CONNECTION = re.compile(r"^(\d{4}-\d\d-\d\d) (\d\d:\d\d:\d\d)(\.\d{3})?\d* connection handle")
MESSAGE = re.compile(
    r"^(\d\d:\d\d:\d\d)(\.\d{3})?\d* (phone->strap|strap->phone)\s+(?:WRITE_REQ|NOTIFY)\s+"
    r"h=0x\w+ \((fd4b\w+)\) len=\s*\d+ ([0-9a-f]+)$"
)
SERIAL = re.compile(rb"5AG\d{7}")
# In the 0x91 reply the device ID is lowercase hex ASCII, between a NUL and a carriage return.
DEVICE_ID = re.compile(rb"\x00([0-9a-f]{32,64})\x0d")
ADDRESS = re.compile(rb"[0-9A-F]{2}(?::[0-9A-F]{2}){5}")
# The one non-Frame message (on fd4b0007) carries a 33-character ASCII token.
TOKEN = re.compile(rb"[A-Za-z0-9]{20,}")

FRAME_START = bytes([0xAA, 0x01])
# Console-log Frames (type 0x32) carry ASCII from byte 21 up to the CRC (hr-tracker protocol.md).
CONSOLE_LOG = 0x32
CONSOLE_TEXT_START = 21


def is_frame(message):
    return message[:2] == FRAME_START


def read_capture(path):
    """Return the connection start times and the fd4b messages, in capture order."""
    connections, messages = [], []
    with open(path, encoding="utf-8") as dump:
        text = dump.read()
    for line in text.splitlines():
        if m := CONNECTION.match(line):
            connections.append(f"{m[1]} {m[2]}{m[3] or '.000'}")
        elif m := MESSAGE.match(line):
            direction = "out" if m[3] == "phone->strap" else "in"
            messages.append([m[1] + (m[2] or ".000"), direction, m[4], bytearray.fromhex(m[5])])
    return connections, messages


def scrub_console_logs(frames, originals):
    """Replace Bluetooth addresses in console logs, including ones split across Frames."""
    spans = []  # (frame, offset) for each character of the joined console text
    for frame in frames:
        if is_frame(frame) and frame[8] == CONSOLE_LOG:
            # Each Frame's text ends in a NUL; skip it so text split across Frames joins up.
            text_range = range(CONSOLE_TEXT_START, len(frame) - 4)
            spans += [(frame, i) for i in text_range if frame[i]]
    text = bytes(frame[i] for frame, i in spans)
    fakes = {}
    for m in ADDRESS.finditer(text):
        fake = fakes.setdefault(m[0], FAKE_ADDRESSES[len(fakes) % len(FAKE_ADDRESSES)])
        originals.add(m[0])
        for k, byte in enumerate(fake):
            frame, i = spans[m.start() + k]
            frame[i] = byte


def scrub(message, originals):
    """Replace the serial, the device ID and (in non-Frame messages) tokens."""
    for m in SERIAL.finditer(bytes(message)):
        originals.add(m[0])
        message[m.start() : m.end()] = FAKE_SERIAL
    for m in DEVICE_ID.finditer(bytes(message)):
        originals.add(m[1])
        message[m.start(1) : m.end(1)] = (FAKE_DEVICE_ID * 8)[: len(m[1])]
    if not is_frame(message):
        for m in TOKEN.finditer(bytes(message)):
            originals.add(m[0])
            message[m.start() : m.end()] = FAKE_TOKEN_CHAR * len(m[0])


def recalculate_crc(frame):
    """CRC32 of the body (byte 8 up to the CRC), little-endian."""
    frame[-4:] = zlib.crc32(bytes(frame[8:-4])).to_bytes(4, "little")


def leak_forms(original):
    """Every byte form an identifier could still take in the fixture."""
    forms = [original, original.upper()]
    if ADDRESS.fullmatch(original):
        raw = bytes.fromhex(original.decode().replace(":", ""))
        forms += [raw, raw[::-1]]
    elif re.fullmatch(rb"(?:[0-9a-f]{2}){16,32}", original):
        forms.append(bytes.fromhex(original.decode()))
    return forms


def main(capture, out):
    connections, messages = read_capture(capture)
    payloads = [m[3] for m in messages]
    before = [bytes(p) for p in payloads]
    originals = set()
    scrub_console_logs(payloads, originals)
    for payload in payloads:
        scrub(payload, originals)
    for payload, old in zip(payloads, before):
        if payload != old and is_frame(payload):
            recalculate_crc(payload)

    every = b"".join(bytes(p) for p in payloads)
    for original in originals:
        if any(form in every for form in leak_forms(original)):
            sys.exit(f"identifier left in fixture: {original!r}")

    lines = [
        "# History Sync capture, 27 Oct 2026, cleaned by scripts/make-sync-fixture.py.",
        "# One message per line: capture time, direction (out = phone to Strap),",
        "# characteristic, hex. Every message is a Frame except the one on fd4b0007.",
    ]
    starts = iter(connections)
    next_start = next(starts, None)
    for time, direction, characteristic, payload in messages:
        # Times are compared without the date, so a capture must not cross midnight.
        while next_start and time >= next_start.split()[1]:
            lines.append(f"# connection {next_start}")
            next_start = next(starts, None)
        lines.append(f"{time} {direction} {characteristic} {payload.hex()}")
    with open(out, "w", encoding="utf-8", newline="\n") as fixture:
        fixture.write("\n".join(lines) + "\n")
    print(f"{len(messages)} messages, {len(connections)} connections, {len(originals)} IDs replaced")


if __name__ == "__main__":
    main(*sys.argv[1:])
