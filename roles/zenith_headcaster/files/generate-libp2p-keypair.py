#!/usr/bin/env python3
"""Generate a libp2p Ed25519 keypair in protobuf wire format.

Output is compatible with libp2p's Keypair::from_protobuf_encoding().

Usage:
    generate-libp2p-keypair.py <output-path>

The file is written atomically (write to tmp + rename) and set to mode 0600.
Exits 0 on success, 1 on error.
"""
import os
import sys
import tempfile

from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PrivateKey
from cryptography.hazmat.primitives.serialization import (
    Encoding,
    NoEncryption,
    PrivateFormat,
    PublicFormat,
)

# libp2p protobuf wire format for Ed25519 private key:
#   field 1 (KeyType): varint 1 (Ed25519)
#   field 2 (Data):    length-delimited, 64 bytes (seed || public_key)
PROTO_HEADER = b"\x08\x01\x12\x40"


def main():
    if len(sys.argv) != 2:
        print(f"Usage: {sys.argv[0]} <output-path>", file=sys.stderr)
        sys.exit(1)

    output_path = sys.argv[1]
    output_dir = os.path.dirname(output_path) or "."

    key = Ed25519PrivateKey.generate()
    seed = key.private_bytes(Encoding.Raw, PrivateFormat.Raw, NoEncryption())
    pub = key.public_key().public_bytes(Encoding.Raw, PublicFormat.Raw)
    data = PROTO_HEADER + seed + pub

    # Atomic write: tmp file in same dir, then rename
    fd, tmp_path = tempfile.mkstemp(dir=output_dir)
    try:
        os.write(fd, data)
        os.close(fd)
        os.chmod(tmp_path, 0o600)
        os.rename(tmp_path, output_path)
    except Exception:
        os.unlink(tmp_path)
        raise

    print(f"Keypair written to {output_path} ({len(data)} bytes)")


if __name__ == "__main__":
    main()
