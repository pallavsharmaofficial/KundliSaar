// ignore_for_file: implementation_imports

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;
import 'package:pdf/pdf.dart';
import 'package:pdf/src/pdf/format/base.dart';
import 'package:pdf/src/pdf/format/bool.dart';
import 'package:pdf/src/pdf/format/dict.dart';
import 'package:pdf/src/pdf/format/num.dart';
import 'package:pdf/src/pdf/format/object_base.dart';
import 'package:pdf/src/pdf/format/string.dart';
import 'package:pointycastle/export.dart' as pc;

/// Password protection for the PDF itself: the standard security handler,
/// revision 6, which is AES with a 256-bit key (ISO 32000-2, the scheme
/// Acrobat, Chrome, Preview, Android and iOS viewers all open).
///
/// The `pdf` package has the hook for encryption ([PdfEncryption]) but no
/// implementation of it, so this is one. Every string and stream the writer
/// emits passes through [encrypt]; the file key never leaves this object, and
/// what goes into the file is the usual /U /UE /O /OE /Perms entries from which
/// a viewer recovers it with the password.
///
/// Honest limits, said once here: this makes the file ask for a password
/// wherever it ends up. It does not make an eight-digit password strong; a
/// determined person can try every one of the hundred million of them.
class PdfAes256Encryption extends PdfEncryption {
  PdfAes256Encryption(
    PdfDocument document, {
    required String userPassword,
    String? ownerPassword,
    this.permissions = defaultPermissions,
    Random? random,
  }) : _random = random ?? Random.secure(),
       super(document) {
    final Uint8List user = _prepare(userPassword);
    final Uint8List owner = _prepare(ownerPassword ?? _randomPassword(_random));

    _fileKey = _bytes(32);

    // Algorithm 8: the user entries.
    final Uint8List uValidation = _bytes(8);
    final Uint8List uKeySalt = _bytes(8);
    final Uint8List uHash = hashR6(user, uValidation, Uint8List(0));
    final Uint8List u = Uint8List.fromList(<int>[
      ...uHash,
      ...uValidation,
      ...uKeySalt,
    ]);
    final Uint8List ue = _aesNoPad(
      hashR6(user, uKeySalt, Uint8List(0)),
      Uint8List(16),
      _fileKey,
      encrypt: true,
    );

    // Algorithm 9: the owner entries, bound to /U.
    final Uint8List oValidation = _bytes(8);
    final Uint8List oKeySalt = _bytes(8);
    final Uint8List oHash = hashR6(owner, oValidation, u);
    final Uint8List o = Uint8List.fromList(<int>[
      ...oHash,
      ...oValidation,
      ...oKeySalt,
    ]);
    final Uint8List oe = _aesNoPad(
      hashR6(owner, oKeySalt, u),
      Uint8List(16),
      _fileKey,
      encrypt: true,
    );

    // Algorithm 10: /Perms, so a viewer can tell the entries were not edited.
    final Uint8List perms = Uint8List(16);
    final ByteData pd = ByteData.sublistView(perms);
    pd.setUint32(0, permissions & 0xFFFFFFFF, Endian.little);
    pd.setUint32(4, 0xFFFFFFFF, Endian.little);
    perms[8] = 0x54; // 'T': metadata is encrypted too
    perms[9] = 0x61; // 'a'
    perms[10] = 0x64; // 'd'
    perms[11] = 0x62; // 'b'
    perms.setRange(12, 16, _bytes(4));
    final pc.AESEngine ecb = pc.AESEngine()
      ..init(true, pc.KeyParameter(_fileKey));
    final Uint8List permsOut = Uint8List(16);
    ecb.processBlock(perms, 0, permsOut, 0);

    PdfString raw(Uint8List v) =>
        PdfString(v, format: PdfStringFormat.binary, encrypted: false);

    params['/Filter'] = const PdfName('/Standard');
    params['/V'] = const PdfNum(5);
    params['/R'] = const PdfNum(6);
    params['/Length'] = const PdfNum(256);
    params['/P'] = PdfNum(permissions.toSigned(32));
    params['/O'] = raw(o);
    params['/U'] = raw(u);
    params['/OE'] = raw(oe);
    params['/UE'] = raw(ue);
    params['/Perms'] = raw(permsOut);
    params['/EncryptMetadata'] = const PdfBool(true);
    params['/CF'] = PdfDict<PdfDataType>.values(<String, PdfDataType>{
      '/StdCF': PdfDict<PdfDataType>.values(<String, PdfDataType>{
        '/AuthEvent': const PdfName('/DocOpen'),
        '/CFM': const PdfName('/AESV3'),
        '/Length': const PdfNum(32),
      }),
    });
    params['/StmF'] = const PdfName('/StdCF');
    params['/StrF'] = const PdfName('/StdCF');

    // Acrobat's extension level for AES-256, so older readers say what is
    // wrong instead of showing garbage.
    document.catalog.params['/Extensions'] = PdfDict<PdfDataType>.values(
      <String, PdfDataType>{
        '/ADBE': PdfDict<PdfDataType>.values(<String, PdfDataType>{
          '/BaseVersion': const PdfName('/1.7'),
          '/ExtensionLevel': const PdfNum(8),
        }),
      },
    );
  }

  /// Print (also at high quality), copy and read aloud are allowed; changing,
  /// annotating and assembling the document are not. Bits 7, 8 and 13 to 32
  /// are reserved and must be set.
  static const int defaultPermissions =
      0xFFFFF0C0 | 0x04 | 0x10 | 0x200 | 0x800;

  /// The /P value: a set bit is a permitted action.
  final int permissions;

  final Random _random;
  late final Uint8List _fileKey;

  Uint8List _bytes(int n) =>
      Uint8List.fromList(List<int>.generate(n, (_) => _random.nextInt(256)));

  static String _randomPassword(Random r) => List<String>.generate(
    24,
    (_) =>
        'abcdefghijkmnpqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ23456789'[r.nextInt(
          54,
        )],
  ).join();

  /// The password as the standard says: UTF-8, at most 127 bytes.
  static Uint8List _prepare(String password) {
    final List<int> b = utf8.encode(password);
    return Uint8List.fromList(b.length > 127 ? b.sublist(0, 127) : b);
  }

  // -------------------------------------------------------------------------
  // The writer's hook
  // -------------------------------------------------------------------------

  @override
  Uint8List encrypt(Uint8List input, PdfObjectBase object) {
    final Uint8List iv = _bytes(16);
    final int pad = 16 - input.length % 16;
    final Uint8List padded = Uint8List(input.length + pad)
      ..setRange(0, input.length, input)
      ..fillRange(input.length, input.length + pad, pad);
    final Uint8List body = _aesNoPad(_fileKey, iv, padded, encrypt: true);
    final Uint8List out = Uint8List(16 + body.length);
    out.setRange(0, 16, iv);
    out.setRange(16, out.length, body);
    return out;
  }

  /// Reads back what [encrypt] wrote, for the tests.
  static Uint8List decryptWith(Uint8List fileKey, Uint8List data) {
    if (data.length < 32 || (data.length - 16) % 16 != 0) {
      throw const FormatException('not an AES-CBC block');
    }
    final Uint8List iv = Uint8List.sublistView(data, 0, 16);
    final Uint8List plain = _aesNoPad(
      fileKey,
      iv,
      Uint8List.sublistView(data, 16),
      encrypt: false,
    );
    final int pad = plain.last;
    return Uint8List.sublistView(plain, 0, plain.length - pad);
  }

  // -------------------------------------------------------------------------
  // Algorithm 2.B and the pieces it is made of
  // -------------------------------------------------------------------------

  static Uint8List _aesNoPad(
    Uint8List key,
    Uint8List iv,
    Uint8List data, {
    required bool encrypt,
  }) {
    final pc.CBCBlockCipher cbc = pc.CBCBlockCipher(pc.AESEngine())
      ..init(
        encrypt,
        pc.ParametersWithIV<pc.KeyParameter>(pc.KeyParameter(key), iv),
      );
    final Uint8List out = Uint8List(data.length);
    for (int off = 0; off < data.length; off += 16) {
      cbc.processBlock(data, off, out, off);
    }
    return out;
  }

  /// The hash of revision 6 (ISO 32000-2, algorithm 2.B): a SHA-256 seed, then
  /// at least sixty-four rounds of AES-128-CBC over the password, the running
  /// hash and [udata], each round picking SHA-256, -384 or -512 from the
  /// result, and further rounds until the last byte allows stopping.
  static Uint8List hashR6(Uint8List password, Uint8List salt, Uint8List udata) {
    Uint8List k = Uint8List.fromList(
      crypto.sha256.convert(<int>[...password, ...salt, ...udata]).bytes,
    );
    Uint8List e = Uint8List(0);
    int round = 0;
    while (true) {
      round++;
      final Uint8List unit = Uint8List.fromList(<int>[
        ...password,
        ...k,
        ...udata,
      ]);
      final Uint8List k1 = Uint8List(unit.length * 64);
      for (int i = 0; i < 64; i++) {
        k1.setRange(i * unit.length, (i + 1) * unit.length, unit);
      }
      e = _aesNoPad(
        Uint8List.sublistView(k, 0, 16),
        Uint8List.sublistView(k, 16, 32),
        k1,
        encrypt: true,
      );
      int mod = 0;
      for (int i = 0; i < 16; i++) {
        mod += e[i];
      }
      mod %= 3;
      final crypto.Hash h = switch (mod) {
        0 => crypto.sha256,
        1 => crypto.sha384,
        _ => crypto.sha512,
      };
      k = Uint8List.fromList(h.convert(e).bytes);
      if (round >= 64 && e.last <= round - 32) break;
    }
    return Uint8List.sublistView(k, 0, 32);
  }

  /// Does [password] open a file whose /U entry is [u]? This is what a viewer
  /// does first.
  static bool checksUserPassword(Uint8List u, String password) {
    if (u.length < 48) return false;
    final Uint8List h = hashR6(
      _prepare(password),
      Uint8List.sublistView(u, 32, 40),
      Uint8List(0),
    );
    for (int i = 0; i < 32; i++) {
      if (h[i] != u[i]) return false;
    }
    return true;
  }

  /// Recovers the file key from /U and /UE with the user password.
  static Uint8List fileKeyFromUser(Uint8List u, Uint8List ue, String password) {
    final Uint8List key = hashR6(
      _prepare(password),
      Uint8List.sublistView(u, 40, 48),
      Uint8List(0),
    );
    return _aesNoPad(key, Uint8List(16), ue, encrypt: false);
  }
}

/// Lets a test (or any caller) read the /Encrypt entries it needs.
extension PdfAes256Entries on PdfAes256Encryption {
  Uint8List entry(String key) => (params[key] as PdfString).value;
}
