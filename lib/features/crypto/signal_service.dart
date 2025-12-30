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
    final identityKeyPair = generateIdentityKeyPair();
    final registrationId = generateRegistrationId(false);
    
    _store = MySignalProtocolStore(identityKeyPair, registrationId);
    
    // Generate initial pre-keys and signed pre-key
    final preKeys = generatePreKeys(0, 100);
    for (var key in preKeys) {
      await _store.storePreKey(key.id, key);
    }
    
    final signedPreKey = generateSignedPreKey(identityKeyPair, 0);
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

  Future<Map<int, CiphertextMessage>> encryptMessageMultiDevice(
    String recipientUsername, 
    List<Map<String, dynamic>> deviceBundles, 
    String plaintext
  ) async {
    final Map<int, CiphertextMessage> ciphers = {};
    
    for (var bundle in deviceBundles) {
      final deviceId = bundle['device_id'];
      final remoteAddress = SignalProtocolAddress(recipientUsername, deviceId);
      
      if (!await _store.containsSession(remoteAddress)) {
        await establishSession(recipientUsername, deviceId, bundle['bundle']);
      }
      
      final sessionCipher = SessionCipher(_store, _store, _store, _store, remoteAddress);
      final message = await sessionCipher.encrypt(
        Uint8List.fromList(utf8.encode(plaintext))
      );
      ciphers[deviceId] = message;
    }
    
    return ciphers;
  }

  Future<String> decryptMessage(
    String senderUsername, 
    int senderDeviceId, 
    CiphertextMessage ciphertext
  ) async {
    final remoteAddress = SignalProtocolAddress(senderUsername, senderDeviceId);
    final sessionCipher = SessionCipher(_store, _store, _store, _store, remoteAddress);
    
    late Uint8List plaintext;
    if (ciphertext is PreKeySignalMessage) {
      plaintext = await sessionCipher.decrypt(ciphertext);
    } else if (ciphertext is SignalMessage) {
      plaintext = await sessionCipher.decryptFromSignal(ciphertext);
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

    final sessionBuilder = SessionBuilder(_store, _store, _store, _store, remoteAddress);
    await sessionBuilder.processPreKeyBundle(preKeyBundle);
  }
}
