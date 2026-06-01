#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["cryptography>=42"]
# ///
"""Encrypt a SQLite database for transport, matching the app's Dart decryptor
(`lib/services/aes_file_decryptor.dart`).

Output layout: magic `GZDRAES1` (8 bytes) + salt (16) + iv (16) + AES-256-CBC,
PKCS7-padded ciphertext. Key = PBKDF2-HMAC-SHA256(password, salt, 120000, 32).

The password is prompted interactively — it never appears on the command line.
The app asks for the same password after download to decrypt on the fly.

Usage:
  ./encrypt_db.py owners.sqlite owners.sqlite.enc
  # then upload the .enc to R2:
  rclone copyto owners.sqlite.enc cloudflare:gozdar-kataster/owners.sqlite.enc
"""

import getpass
import os
import sys

from cryptography.hazmat.primitives import padding
from cryptography.hazmat.primitives.ciphers import Cipher, algorithms, modes
from cryptography.hazmat.primitives.hashes import SHA256
from cryptography.hazmat.primitives.kdf.pbkdf2 import PBKDF2HMAC

MAGIC = b"GZDRAES1"
ITERATIONS = 120_000
CHUNK = 1024 * 1024


def main() -> None:
    if len(sys.argv) != 3:
        sys.exit("usage: encrypt_db.py <input.sqlite> <output.sqlite.enc>")
    src, dst = sys.argv[1], sys.argv[2]
    if not os.path.exists(src):
        sys.exit(f"Input not found: {src}")

    pw = getpass.getpass("Password: ")
    if not pw:
        sys.exit("Empty password.")
    if pw != getpass.getpass("Confirm:  "):
        sys.exit("Passwords do not match.")

    salt = os.urandom(16)
    iv = os.urandom(16)
    key = PBKDF2HMAC(SHA256(), 32, salt, ITERATIONS).derive(pw.encode())
    encryptor = Cipher(algorithms.AES(key), modes.CBC(iv)).encryptor()
    padder = padding.PKCS7(128).padder()

    total = os.path.getsize(src)
    done = 0
    with open(src, "rb") as fi, open(dst, "wb") as fo:
        fo.write(MAGIC + salt + iv)
        while True:
            chunk = fi.read(CHUNK)
            if not chunk:
                break
            fo.write(encryptor.update(padder.update(chunk)))
            done += len(chunk)
            pct = done / total * 100 if total else 100
            print(f"\r  {done // (1024 * 1024)}/{total // (1024 * 1024)} MB "
                  f"({pct:.0f}%)", end="", flush=True)
        fo.write(encryptor.update(padder.finalize()))
        fo.write(encryptor.finalize())
    print(f"\nEncrypted -> {dst} ({os.path.getsize(dst) // (1024 * 1024)} MB)")


if __name__ == "__main__":
    main()
