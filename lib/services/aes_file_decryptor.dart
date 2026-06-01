import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:pointycastle/export.dart';

/// Thrown when decryption fails (wrong password or corrupt/invalid file).
class AesDecryptException implements Exception {
  final String message;
  const AesDecryptException(this.message);
  @override
  String toString() => message;
}

/// Thrown when a decrypt stream is cancelled by the caller.
class AesCancelled implements Exception {
  const AesCancelled();
}

/// Streaming AES-256-CBC decryptor matching `tools/parcels/encrypt_db.py`.
///
/// File layout: magic `GZDRAES1` (8 bytes) + salt (16) + iv (16) + AES-256-CBC,
/// PKCS7-padded ciphertext. Key = PBKDF2-HMAC-SHA256(password, salt, 120000, 32).
///
/// Decrypts a download as it streams in, writing plaintext to [out] without ever
/// holding the whole (hundreds-of-MB) file in memory.
class AesFileDecryptor {
  static const _magic = [0x47, 0x5A, 0x44, 0x52, 0x41, 0x45, 0x53, 0x31]; // GZDRAES1
  static const _iterations = 120000;
  static const _headerLen = 8 + 16 + 16;

  /// Stream-decrypt [input] into [out]. [onBytes] reports encrypted bytes
  /// consumed (for progress). Throws [AesDecryptException] on wrong password or
  /// corrupt data, or [AesCancelled] when [isCancelled] returns true.
  static Future<void> decrypt({
    required Stream<List<int>> input,
    required IOSink out,
    required String password,
    void Function(int bytes)? onBytes,
    bool Function()? isCancelled,
  }) async {
    final header = <int>[];
    CBCBlockCipher? cipher;
    final pending = BytesBuilder(); // ciphertext bytes not yet a full block
    Uint8List? heldPlain; // last decrypted block, withheld so it can be unpadded
    var received = 0;

    void initCipher() {
      for (var i = 0; i < 8; i++) {
        if (header[i] != _magic[i]) {
          throw const AesDecryptException(
              'Datoteka ni v pričakovani obliki (napačna glava).');
        }
      }
      final salt = Uint8List.fromList(header.sublist(8, 24));
      final iv = Uint8List.fromList(header.sublist(24, 40));
      final key = _deriveKey(password, salt);
      cipher = CBCBlockCipher(AESEngine())
        ..init(false, ParametersWithIV(KeyParameter(key), iv));
    }

    void processBuffer() {
      final c = cipher!;
      final buf = pending.toBytes();
      pending.clear();
      var off = 0;
      while (buf.length - off >= 16) {
        final outBlock = Uint8List(16);
        c.processBlock(buf, off, outBlock, 0);
        off += 16;
        if (heldPlain != null) out.add(heldPlain!);
        heldPlain = outBlock;
      }
      if (off < buf.length) pending.add(buf.sublist(off));
    }

    await for (final chunk in input) {
      if (isCancelled?.call() ?? false) throw const AesCancelled();
      received += chunk.length;
      onBytes?.call(received);

      var data = chunk;
      if (cipher == null) {
        final need = _headerLen - header.length;
        if (chunk.length <= need) {
          header.addAll(chunk);
          if (header.length < _headerLen) continue;
          initCipher();
          data = const [];
        } else {
          header.addAll(chunk.sublist(0, need));
          initCipher();
          data = chunk.sublist(need);
        }
      }
      if (data.isNotEmpty) {
        pending.add(data);
        processBuffer();
      }
    }

    if (cipher == null || pending.length != 0) {
      throw const AesDecryptException('Datoteka je okvarjena ali nepopolna.');
    }
    if (heldPlain == null) {
      throw const AesDecryptException('Datoteka je prazna.');
    }
    // Validate + strip PKCS7 padding on the final block.
    final pad = heldPlain![15];
    if (pad < 1 || pad > 16) {
      throw const AesDecryptException('Napačno geslo.');
    }
    for (var i = 16 - pad; i < 16; i++) {
      if (heldPlain![i] != pad) {
        throw const AesDecryptException('Napačno geslo.');
      }
    }
    out.add(heldPlain!.sublist(0, 16 - pad));
  }

  static Uint8List _deriveKey(String password, Uint8List salt) {
    final derivator = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64))
      ..init(Pbkdf2Parameters(salt, _iterations, 32));
    return derivator.process(Uint8List.fromList(utf8.encode(password)));
  }
}
