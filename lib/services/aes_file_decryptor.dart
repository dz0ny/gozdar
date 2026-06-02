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
  ///
  /// Decrypts directly into a 64 KiB output buffer and flushes in bulk — a
  /// 300 MB DB is ~19M blocks, so per-block sink writes would be pathological.
  static Future<void> decrypt({
    required Stream<List<int>> input,
    required IOSink out,
    required String password,
    void Function(int bytes)? onBytes,
    bool Function()? isCancelled,
  }) async {
    const outCap = 1 << 16; // 64 KiB (multiple of the 16-byte block)
    final outChunk = Uint8List(outCap);
    var outLen = 0;
    CBCBlockCipher? cipher;
    var pending = Uint8List(0); // ciphertext not yet decrypted
    var received = 0;

    void flush() {
      if (outLen > 0) {
        out.add(outChunk.sublist(0, outLen)); // sublist copies; buffer reused
        outLen = 0;
      }
    }

    // Decrypt full blocks from [pending], keeping [keep] trailing bytes back
    // (the final padded block is only known at end-of-stream).
    void emit(int keep) {
      final c = cipher!;
      var off = 0;
      while (pending.length - keep - off >= 16) {
        if (outLen + 16 > outCap) flush();
        c.processBlock(pending, off, outChunk, outLen);
        off += 16;
        outLen += 16;
      }
      if (off > 0) pending = pending.sublist(off); // compact small remainder
    }

    await for (final chunk in input) {
      if (isCancelled?.call() ?? false) throw const AesCancelled();
      received += chunk.length;
      onBytes?.call(received);

      pending = _concat(pending, chunk);
      if (cipher == null) {
        if (pending.length < _headerLen) continue;
        for (var i = 0; i < 8; i++) {
          if (pending[i] != _magic[i]) {
            throw const AesDecryptException(
                'Datoteka ni v pričakovani obliki (napačna glava).');
          }
        }
        final salt = Uint8List.sublistView(pending, 8, 24);
        final iv = Uint8List.sublistView(pending, 24, 40);
        cipher = CBCBlockCipher(AESEngine())
          ..init(false, ParametersWithIV(KeyParameter(_deriveKey(password, salt)), iv));
        pending = pending.sublist(_headerLen);
      }
      emit(16); // always hold back the (possibly final) last block
    }

    if (cipher == null || pending.length != 16) {
      throw const AesDecryptException('Datoteka je okvarjena ali nepopolna.');
    }
    // Decrypt + validate + strip PKCS7 padding on the final block.
    final finalBlock = Uint8List(16);
    cipher.processBlock(pending, 0, finalBlock, 0);
    final pad = finalBlock[15];
    if (pad < 1 || pad > 16) {
      throw const AesDecryptException('Napačno geslo.');
    }
    for (var i = 16 - pad; i < 16; i++) {
      if (finalBlock[i] != pad) {
        throw const AesDecryptException('Napačno geslo.');
      }
    }
    for (var i = 0; i < 16 - pad; i++) {
      if (outLen >= outCap) flush();
      outChunk[outLen++] = finalBlock[i];
    }
    flush();
  }

  static Uint8List _concat(Uint8List a, List<int> b) {
    final r = Uint8List(a.length + b.length);
    r.setRange(0, a.length, a);
    r.setRange(a.length, r.length, b);
    return r;
  }

  static Uint8List _deriveKey(String password, Uint8List salt) {
    final derivator = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64))
      ..init(Pbkdf2Parameters(salt, _iterations, 32));
    return derivator.process(Uint8List.fromList(utf8.encode(password)));
  }
}
