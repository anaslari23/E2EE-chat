import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ContactService {
  Future<List<String>> getHashedContacts() async {
    if (!await FlutterContacts.requestPermission()) return [];

    final contacts = await FlutterContacts.getContacts(withProperties: true);
    final Set<String> phoneHashes = {};

    for (var contact in contacts) {
      for (var phone in contact.phones) {
        final normalized = _normalizePhoneNumber(phone.number);
        if (normalized.length >= 7) {
          final hash = sha256.convert(utf8.encode(normalized)).toString();
          phoneHashes.add(hash);
        }
      }
    }

    return phoneHashes.toList();
  }

  String _normalizePhoneNumber(String phone) {
    // Remove all non-digits except +
    var normalized = phone.replaceAll(RegExp(r'[^\d+]'), '');
    
    // Convert 00 prefix to +
    if (normalized.startsWith('00')) {
      normalized = '+' + normalized.substring(2);
    }
    
    // Note: In a production app, we would use a library like 'libphonenumber'
    // to handle international formatting correctly based on the user's locale.
    return normalized;
  }
}

final contactServiceProvider = Provider((ref) => ContactService());
