import 'dart:typed_data';
import 'package:libsignal_protocol_dart/libsignal_protocol_dart.dart';

class MySignalProtocolStore extends SignalProtocolStore {
  final Map<int, PreKeyRecord> _preKeys = {};
  final Map<int, SignedPreKeyRecord> _signedPreKeys = {};
  final Map<SignalProtocolAddress, SessionRecord> _sessions = {};
  final Map<SignalProtocolAddress, IdentityKey?> _identityKeys = {};
  
  late IdentityKeyPair _identityKeyPair;
  late int _registrationId;

  MySignalProtocolStore(this._identityKeyPair, this._registrationId);

  @override
  Future<IdentityKeyPair> getIdentityKeyPair() async => _identityKeyPair;

  @override
  Future<int> getLocalRegistrationId() async => _registrationId;

  @override
  Future<bool> saveIdentity(SignalProtocolAddress address, IdentityKey? identityKey) async {
    _identityKeys[address] = identityKey;
    return true;
  }

  @override
  Future<bool> isTrustedIdentity(SignalProtocolAddress address, IdentityKey? identityKey, Direction direction) async {
    return true; // Simplified for MVP
  }

  @override
  Future<PreKeyRecord> loadPreKey(int preKeyId) async {
    if (!_preKeys.containsKey(preKeyId)) {
      throw InvalidKeyIdException('No such prekey: $preKeyId');
    }
    return _preKeys[preKeyId]!;
  }

  @override
  Future<void> storePreKey(int preKeyId, PreKeyRecord record) async {
    _preKeys[preKeyId] = record;
  }

  @override
  Future<bool> containsPreKey(int preKeyId) async {
    return _preKeys.containsKey(preKeyId);
  }

  @override
  Future<void> removePreKey(int preKeyId) async {
    _preKeys.remove(preKeyId);
  }

  @override
  Future<SessionRecord> loadSession(SignalProtocolAddress address) async {
    return _sessions[address] ?? SessionRecord();
  }

  @override
  Future<List<int>> getSubDeviceSessions(String name) async {
    return [];
  }

  @override
  Future<void> storeSession(SignalProtocolAddress address, SessionRecord record) async {
    _sessions[address] = record;
  }

  @override
  Future<bool> containsSession(SignalProtocolAddress address) async {
    return _sessions.containsKey(address);
  }

  @override
  Future<void> deleteSession(SignalProtocolAddress address) async {
    _sessions.remove(address);
  }

  @override
  Future<void> deleteAllSessions(String name) async {
    _sessions.removeWhere((key, value) => key.getName() == name);
  }

  @override
  Future<SignedPreKeyRecord> loadSignedPreKey(int signedPreKeyId) async {
    if (!_signedPreKeys.containsKey(signedPreKeyId)) {
      throw InvalidKeyIdException('No such signed prekey: $signedPreKeyId');
    }
    return _signedPreKeys[signedPreKeyId]!;
  }

  @override
  Future<List<SignedPreKeyRecord>> loadSignedPreKeys() async {
    return _signedPreKeys.values.toList();
  }

  @override
  Future<void> storeSignedPreKey(int signedPreKeyId, SignedPreKeyRecord record) async {
    _signedPreKeys[signedPreKeyId] = record;
  }

  @override
  Future<bool> containsSignedPreKey(int signedPreKeyId) async {
    return _signedPreKeys.containsKey(signedPreKeyId);
  }

  @override
  Future<void> removeSignedPreKey(int signedPreKeyId) async {
    _signedPreKeys.remove(signedPreKeyId);
  }

  @override
  Future<IdentityKey?> getIdentity(SignalProtocolAddress address) async {
    return _identityKeys[address];
  }
}
