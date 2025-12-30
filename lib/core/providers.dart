import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../services/api_service.dart';
import '../services/websocket_service.dart';
import '../features/crypto/signal_service.dart';

final apiServiceProvider = Provider((ref) => ApiService());
final webSocketServiceProvider = Provider((ref) => WebSocketService());
final signalServiceProvider = Provider((ref) => SignalService());
final secureStorageProvider = Provider((ref) => const FlutterSecureStorage());

final authProvider = StateProvider<int?>((ref) => null); // Stores current user ID
