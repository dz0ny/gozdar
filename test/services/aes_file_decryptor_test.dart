import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gozdar/services/aes_file_decryptor.dart';

void main() {
  // Fixture produced by tools/parcels/encrypt_db.py (Python/cryptography) with
  // password "test-pass-123", fixed salt/iv — verifies Python -> Dart compat.
  const password = 'test-pass-123';
  const encB64 =
      'R1pEUkFFUzEAAQIDBAUGBwgJCgsMDQ4PEBESExQVFhcYGRobHB0eH5bFm1+qkLpAitI7AMnR'
      '29GHxXf/DPQmtn8ZgEW7JIaTCGt5uyRnxbMLpBnoZAEoVhePowpA7dmO0Bxr17JU72xaw8+'
      '38Xsj6ODwdhq586ahJInnRvc4I2FV7BdkGvXt0EHPg2s53Ho+LRWxA0L9JtPMspa5GSdDIZ'
      'X7ZXOAXfo6Ly5yDsNfa5DtX7kCdP4LLwHefnO3a40iL1roSsXjb4Q3gdmKV/X4dyz+EWP4a'
      '/1iRgNGZGcK/zh/SCO7Mv+MIZCzh4vhR98U24xD1hFEL2HmNMb2sCMgcZAGG8huci4NFny5'
      'ds4qvBRSZfW+B6D3BCPTOyzcvPvCGDE6zo3pNL4OpdcOyhnP2lCrnDOAyQeArbdyN4ipCQ+'
      '9JwiITC9bvYg8PJLk6QAp2P1ErfMl9SdF5X0CD2xUbC+qE9AE/W7aGPoEP/hERbwUuw6ztX'
      'EUgtBiJmPY+YJAs54jksR3s2u4albu+TAUBYia1jEYN2wEJznjB3aUxavi3g0z2Qc8VKQed'
      'YklokPXTo7o9Znb6svlcAvraKmAC3hPHz7IgAO7R5VL/uXBu7ZM0BdstSSvFUABaVm2RejK'
      'C/7PEndoQb1syia2Tm5n6ayiC3ec1jQYJoj0JRndf5ZR8CVTKncLtp83oX8ZQJ9yGQsqvPv'
      'ggntQBlLozzsE2MsL40lb2FtAolwKWk/ZXZrXNK2zOA4fAAxtyimIgY0coPVo5c5MFPFR3Q'
      'JDLusGhvQDeEsQS/gpg5NMGGLTsKVsYv6FCwnCIkW8HwmXxsu+qykTtpxWmG+mW9Z9jaFmO'
      'u0B6/+E065DBYGCr+/jUFfKVA1MHui92CThPGnp+CPDiamtdgP64ufCksUxaGwobXH6ptnJ'
      'oRM+9q8cJSGfLg51aOBS70xr8L2XavA8QpJzN//feh4ivzUULNRKuFeI+5bgINKHX5wa3OV'
      'CREkSCgyh1insIAT5wdPNJxwE9SWNYHpxWEBHfBw01UF2lxbzTyafOR3BsqDRP5/wzUKDPA'
      'D4YR1qVAiXgvdM09d8UySDz+joha7S54wIZUYv6hp1FdwpbN73s55DsjNCojbC50vF22CSe'
      'dwcjcr+ZqwM/kofvpe7a+cos47nJpbhQrYmKX0PPcMVwuGGHnV+OoU24vUYGuYH1Rwe7a6J'
      'hrcRwBEC1ak9WJM6+5SM7lru76MI1e3U+2ahFI3IQ6voxEY6QnwWWi3fyvhsm5mR8iOe8JZ'
      'TEFUOarwuk7E21kOTclHwd30/yp3b08ZH1kI5vSzsD5YYjwM5BcZIIV9Yc8RI0Kn1T0xONg'
      'z2eNPqw4mxyBjAEx8laddWxQoZD5A5u/ZFRZ/gnjCurbnAcRRI1jAn6ijdz0zuC56FXH94X'
      'lvkf9TrzX59ie9QtG+czcduZLt5dnYcwxuGz5aHiwM5BENpsSpsofNeYF91Gg/mkNZIgd5E'
      'yPZQqkU6t+Iq+Bx6h8QQefxCHvJENNiVV79n/iuxDUS21LBHr+h3t7g=';

  Future<List<int>> decryptToBytes(List<int> enc, String pw) async {
    final tmp = await Directory.systemTemp.createTemp('aes_test');
    final out = File('${tmp.path}/out.bin');
    final sink = out.openWrite();
    try {
      await AesFileDecryptor.decrypt(
        input: Stream.value(enc),
        out: sink,
        password: pw,
      );
    } finally {
      await sink.close();
    }
    final bytes = await out.readAsBytes();
    await tmp.delete(recursive: true);
    return bytes;
  }

  test('decrypts a Python-encrypted file with the correct password', () async {
    final enc = base64.decode(encB64);
    final expected = utf8.encode('GOZDAR-KATASTER-TEST-' * 53);
    final got = await decryptToBytes(enc, password);
    expect(got, equals(expected));
  });

  test('rejects a wrong password', () async {
    final enc = base64.decode(encB64);
    expect(
      () => decryptToBytes(enc, 'wrong-password'),
      throwsA(isA<AesDecryptException>()),
    );
  });

  test('decrypts when the stream is split into small chunks', () async {
    final enc = base64.decode(encB64);
    final expected = utf8.encode('GOZDAR-KATASTER-TEST-' * 53);
    final tmp = await Directory.systemTemp.createTemp('aes_test_chunks');
    final out = File('${tmp.path}/out.bin');
    final sink = out.openWrite();
    // 7-byte chunks straddle the 40-byte header and 16-byte block boundaries.
    Stream<List<int>> chunked() async* {
      for (var i = 0; i < enc.length; i += 7) {
        yield enc.sublist(i, (i + 7).clamp(0, enc.length));
      }
    }
    await AesFileDecryptor.decrypt(
        input: chunked(), out: sink, password: password);
    await sink.close();
    final got = await out.readAsBytes();
    await tmp.delete(recursive: true);
    expect(got, equals(expected));
  });
}
