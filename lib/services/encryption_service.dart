import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';

class EncryptionService {
  final _algorithm = AesGcm.with256bits();

  Future<EncryptedMedia> encryptMedia(Uint8List bytes) async {
    final secretKey = await _algorithm.newSecretKey();
    final secretKeyBytes = await secretKey.extractBytes();
    
    final nonce = _algorithm.newNonce();
    
    final secretBox = await _algorithm.encrypt(
      bytes,
      secretKey: secretKey,
      nonce: nonce,
    );

    return EncryptedMedia(
      bytes: secretBox.concatenation(),
      key: Uint8List.fromList(secretKeyBytes),
      nonce: Uint8List.fromList(nonce),
    );
  }

  Future<Uint8List> decryptMedia(Uint8List encryptedBytes, Uint8List key, Uint8List nonce) async {
    final secretKey = SecretKey(key);
    
    // cryptography's AesGcm expects the concatenation or separate nonce + cipertext + mac
    // Here we assume concatenation (nonce + ciphertext + mac) if we used .concatenation()
    final secretBox = SecretBox.fromConcatenation(
      encryptedBytes,
      nonceLength: _algorithm.nonceLength,
      macLength: _algorithm.macAlgorithm.macLength,
    );

    final decryptedBytes = await _algorithm.decrypt(
      secretBox,
      secretKey: secretKey,
    );

    return Uint8List.fromList(decryptedBytes);
  }
}

class EncryptedMedia {
  final Uint8List bytes;
  final Uint8List key;
  final Uint8List nonce;

  EncryptedMedia({
    required this.bytes,
    required this.key,
    required this.nonce,
  });
}
