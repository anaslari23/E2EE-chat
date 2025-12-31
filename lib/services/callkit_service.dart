import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:flutter_callkit_incoming/entities/entities.dart';
import 'package:uuid/uuid.dart';

class CallKitService {
  static final CallKitService _instance = CallKitService._internal();
  factory CallKitService() => _instance;
  CallKitService._internal();

  final Uuid _uuid = const Uuid();

  Future<void> showIncomingCall({
    required String uuid,
    required String name,
    required String handle, 
    bool hasVideo = false,
  }) async {
    final params = CallKitParams(
      id: uuid,
      nameCaller: name,
      appName: 'Secure Chat',
      avatar: 'https://i.pravatar.cc/100', // Placeholder
      handle: handle,
      type: hasVideo ? 1 : 0, // 0: Audio, 1: Video
      duration: 30000, 
      textAccept: 'Accept',
      textDecline: 'Decline',
      missedCallNotification: const NotificationParams(
        showNotification: true,
        isShowCallback: true,
        subtitle: 'Missed call',
        callbackText: 'Call back',
      ),
      extra: <String, dynamic>{'userId': handle},
      headers: <String, dynamic>{'apiKey': 'Abc@123!', 'platform': 'flutter'},
      android: const AndroidParams(
        isCustomNotification: true,
        isShowLogo: false,
        ringtonePath: 'system_ringtone_default',
        backgroundColor: '#0955fa',
        backgroundUrl: 'https://i.pravatar.cc/500', 
        actionColor: '#4CAF50',
      ),
      ios: const IOSParams(
        iconName: 'CallKitLogo',
        handleType: '',
        supportsVideo: true,
        maximumCallGroups: 2,
        maximumCallsPerCallGroup: 1,
        audioSessionMode: 'default',
        audioSessionActive: true,
        audioSessionPreferredSampleRate: 44100.0,
        audioSessionPreferredIOBufferDuration: 0.005,
        supportsDTMF: true,
        supportsHolding: true,
        supportsGrouping: false,
        supportsUngrouping: false,
        ringtonePath: 'system_ringtone_default',
      ),
    );

    await FlutterCallkitIncoming.showCallkitIncoming(params);
  }

  Future<void> startCall({required String uuid, required String name, required String handle, bool hasVideo = false}) async {
    final params = CallKitParams(
      id: uuid,
      nameCaller: name,
      handle: handle,
      type: hasVideo ? 1 : 0,
      extra: <String, dynamic>{'userId': handle},
      ios: const IOSParams(handleType: 'generic'),
    );
    await FlutterCallkitIncoming.startCall(params);
  }

  Future<void> endCall(String uuid) async {
    await FlutterCallkitIncoming.endCall(uuid);
  }

  Future<void> endAllCalls() async {
    await FlutterCallkitIncoming.endAllCalls();
  }
}
