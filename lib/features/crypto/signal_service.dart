import 'dart:convert';
import 'dart:typed_data';
import 'package:libsignal_protocol_dart/libsignal_protocol_dart.dart';
import 'storage/signal_store.dart';

class SignalService {
  late MySignalProtocolStore _store;
  late SignalProtocolAddress _selfAddress;

  Future<void> initialize(String username, int deviceId) async {
    _selfAddress = SignalProtocolAddress(username, deviceId);
    
    // In a real app, we'd load these from SecureStorage
    final identityKeyPair = KeyHelper.generateIdentityKeyPair();
    final registrationId = KeyHelper.generateRegistrationId(false);
    
    _store = MySignalProtocolStore(identityKeyPair, registrationId);
    
    // Generate initial pre-keys and signed pre-key
    final preKeys = KeyHelper.generatePreKeys(0, 100);
    for (var key in preKeys) {
      await _store.storePreKey(key.id, key);
    }
    
    final signedPreKey = KeyHelper.generateSignedPreKey(identityKeyPair, 0);
    await _store.storeSignedPreKey(signedPreKey.id, signedPreKey);
  }

  Future<Map<String, dynamic>> getPreKeyBundle() async {
    final identityKeyPair = await _store.getIdentityKeyPair();
    final signedPreKey = await _store.loadSignedPreKey(0);
    
    // Pick one pre-key to bundle (simplified)
    final preKey = await _store.loadPreKey(0);

    return {
      'registrationId': await _store.getLocalRegistrationId(),
      'identityKey': base64Encode(identityKeyPair.getPublicKey().serialize()),
      'signedPreKey': {
        'id': signedPreKey.id,
        'publicKey': base64Encode(signedPreKey.getKeyPair().publicKey.serialize()),
        'signature': base64Encode(signedPreKey.signature),
      },
      'preKey': {
        'id': preKey.id,
        'publicKey': base64Encode(preKey.getKeyPair().publicKey.serialize()),
      }
    };
  }

  Future<CiphertextMessage> encryptMessage(
    String recipientUsername, 
    int recipientDeviceId, 
    String plaintext,
    {Map<String, dynamic>? bundle}
  ) async {
    final remoteAddress = SignalProtocolAddress(recipientUsername, recipientDeviceId);
    
    // Check if session exists
    if (!await _store.containsSession(remoteAddress)) {
      if (bundle != null) {
        await establishSession(recipientUsername, recipientDeviceId, bundle);
      } else {
        throw Exception('No session and no bundle provided for $recipientUsername');
      }
    }
    
    final sessionCipher = SessionCipher(_store, remoteAddress);
    
    final message = await sessionCipher.encrypt(
      Uint8List.fromList(utf8.encode(plaintext))
    );
    
    return message;
  }

  Future<String> decryptMessage(
    String senderUsername, 
    int senderDeviceId, 
    CiphertextMessage ciphertext
  ) async {
    final remoteAddress = SignalProtocolAddress(senderUsername, senderDeviceId);
    final sessionCipher = SessionCipher(_store, remoteAddress);
    
    late Uint8List plaintext;
    if (ciphertext is PreKeySignalMessage) {
      plaintext = await sessionCipher.decryptFromPreKeySignalMessage(ciphertext);
    } else if (ciphertext is SignalMessage) {
      plaintext = await sessionCipher.decryptFromSignalMessage(ciphertext);
    } else {
      throw Exception('Unknown ciphertext message type');
    }
    
    return utf8.decode(plaintext);
  }

  Future<void> establishSession(
    String username, 
    int deviceId, 
    Map<String, dynamic> bundle
  ) async {
    final remoteAddress = SignalProtocolAddress(username, deviceId);
    
    final preKeyBundle = PreKeyBundle(
      bundle['registrationId'],
      deviceId,
      bundle['preKey']['id'],
      Curve.decodePoint(base64Decode(bundle['preKey']['publicKey']), 0),
      bundle['signedPreKey']['id'],
      Curve.decodePoint(base64Decode(bundle['signedPreKey']['publicKey']), 0),
      base64Decode(bundle['signedPreKey']['signature']),
      IdentityKey(Curve.decodePoint(base64Decode(bundle['identityKey']), 0)),
    );

    final sessionBuilder = SessionBuilder(_store, remoteAddress);
    await sessionBuilder.processPreKeyBundle(preKeyBundle);
  }
}
