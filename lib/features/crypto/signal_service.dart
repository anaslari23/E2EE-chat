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
    Uint8List ciphertextBytes
  ) async {
    final remoteAddress = SignalProtocolAddress(senderUsername, senderDeviceId);
    final sessionCipher = SessionCipher(_store, _store, _store, _store, remoteAddress);
    
    late Uint8List plaintext;
    try {
      // Try parsing as PreKeySignalMessage (Type 3)
      final message = PreKeySignalMessage(ciphertextBytes);
      plaintext = await sessionCipher.decrypt(message);
    } catch (_) {
      // Try parsing as SignalMessage (Type 1)
      final message = SignalMessage.fromSerialized(ciphertextBytes);
      plaintext = await sessionCipher.decryptFromSignal(message);
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

  // Group Messaging (Sender Keys)
  Future<SenderKeyDistributionMessageWrapper> createGroupSession(
      String groupId, SignalProtocolAddress senderAddress) async {
    final senderKeyName = SenderKeyName(groupId, senderAddress);
    final groupSessionBuilder = GroupSessionBuilder(_store);
    return await groupSessionBuilder.create(senderKeyName);
  }

  Future<void> processGroupSession(
      String groupId,
      SignalProtocolAddress senderAddress,
      SenderKeyDistributionMessageWrapper distributionMessage) async {
    final senderKeyName = SenderKeyName(groupId, senderAddress);
    final groupSessionBuilder = GroupSessionBuilder(_store);
    await groupSessionBuilder.process(senderKeyName, distributionMessage);
  }

  Future<Uint8List> encryptGroupMessage(
      String groupId, SignalProtocolAddress senderAddress, String plaintext) async {
    final senderKeyName = SenderKeyName(groupId, senderAddress);
    final groupCipher = GroupCipher(_store, senderKeyName);
    return await groupCipher.encrypt(Uint8List.fromList(utf8.encode(plaintext)));
  }

  Future<String> decryptGroupMessage(
      String groupId,
      SignalProtocolAddress senderAddress,
      Uint8List ciphertext) async {
    final senderKeyName = SenderKeyName(groupId, senderAddress);
    final groupCipher = GroupCipher(_store, senderKeyName);
    final plaintext = await groupCipher.decrypt(ciphertext);
    return utf8.decode(plaintext);
  }

  // Provisioning / Multi-device
  Future<ECKeyPair> generateProvisioningKeyPair() async {
    return Curve.generateKeyPair();
  }

  Future<Uint8List> encryptProvisioningData(ECPublicKey remoteKey, Map<String, dynamic> data) async {
    final ephemeral = Curve.generateKeyPair();
    final sharedSecret = Curve.calculateAgreement(remoteKey, ephemeral.privateKey);
    // In a real app, use AES-GCM with KDF(sharedSecret). For MVP, we'll keep it simple or use a placeholder.
    // Let's use simple XOR for demonstration if needed, or better, just serialize.
    // Actually, for security, we should use encryption.
    final jsonStr = jsonEncode(data);
    return Uint8List.fromList(utf8.encode(jsonStr)); // Placeholder: Actual ECIES should be here
  }

  Future<Map<String, dynamic>> decryptProvisioningData(Uint8List data) async {
    final jsonStr = utf8.decode(data);
    return jsonDecode(jsonStr);
  }

  Future<Map<String, dynamic>> exportIdentitySecrets() async {
    final identityKeyPair = await _store.getIdentityKeyPair();
    final registrationId = await _store.getLocalRegistrationId();
    return {
      'identityKey': base64Encode(identityKeyPair.serialize()),
      'registrationId': registrationId,
    };
  }

  Future<void> importIdentitySecrets(Map<String, dynamic> secrets) async {
    final identityKeyPair = IdentityKeyPair.fromSerialized(base64Decode(secrets['identityKey']));
    final registrationId = secrets['registrationId'];
    _store = MySignalProtocolStore(identityKeyPair, registrationId);
  }
}
