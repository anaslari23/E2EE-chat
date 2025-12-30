import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../providers/message_provider.dart';
import '../../../../core/providers.dart';
import 'dart:async';

enum CallType { voice, video }
enum CallStatus { idle, ringing, outgoing, connected, ended }

class CallState {
  final CallStatus status;
  final CallType? type;
  final int? peerId;
  final RTCVideoRenderer? localRenderer;
  final RTCVideoRenderer? remoteRenderer;
  final String? remoteSdp;
  final String? errorMessage;

  CallState({
    this.status = CallStatus.idle,
    this.type,
    this.peerId,
    this.localRenderer,
    this.remoteRenderer,
    this.remoteSdp,
    this.errorMessage,
  });

  CallState copyWith({
    CallStatus? status,
    CallType? type,
    int? peerId,
    RTCVideoRenderer? localRenderer,
    RTCVideoRenderer? remoteRenderer,
    String? remoteSdp,
    String? errorMessage,
  }) {
    return CallState(
      status: status ?? this.status,
      type: type ?? this.type,
      peerId: peerId ?? this.peerId,
      localRenderer: localRenderer ?? this.localRenderer,
      remoteRenderer: remoteRenderer ?? this.remoteRenderer,
      remoteSdp: remoteSdp ?? this.remoteSdp,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

class CallNotifier extends StateNotifier<CallState> {
  final Ref ref;
  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  
  // ICE Server configuration (Public STUN servers)
  final Map<String, dynamic> _iceConfig = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
      {'urls': 'stun:stun1.l.google.com:19302'},
    ]
  };

  CallNotifier(this.ref) : super(CallState()) {
    _listenToSignaling();
  }

  void _listenToSignaling() {
    final ws = ref.read(webSocketServiceProvider);
    ws.messages.listen((data) async {
      if (data['type'] == 'signaling') {
        final senderId = data['sender_id'];
        final sig = data['data'];

        if (sig['type'] == 'offer') {
          _handleOffer(senderId, sig);
        } else if (sig['type'] == 'answer') {
          _handleAnswer(sig);
        } else if (sig['type'] == 'candidate') {
          _handleCandidate(sig);
        } else if (sig['type'] == 'reject') {
          _handleReject();
        } else if (sig['type'] == 'busy') {
          _handleBusy();
        } else if (sig['type'] == 'end') {
          _handleEnd();
        }
      }
    });
  }

  Future<void> makeCall(int peerId, CallType type) async {
    state = state.copyWith(status: CallStatus.outgoing, peerId: peerId, type: type);
    
    try {
      await _initializeRenderers();
      _peerConnection = await createPeerConnection(_iceConfig);
      
      // Setup local stream
      final constraints = {
        'audio': true,
        'video': type == CallType.video,
      };
      _localStream = await navigator.mediaDevices.getUserMedia(constraints);
      state.localRenderer?.srcObject = _localStream;
      
      _localStream!.getTracks().forEach((track) {
        _peerConnection!.addTrack(track, _localStream!);
      });

      _peerConnection!.onIceCandidate = (candidate) {
        _sendSignaling(peerId, {
          'type': 'candidate',
          'candidate': candidate.toMap(),
        });
      };

      _peerConnection!.onTrack = (event) {
        if (event.streams.isNotEmpty) {
          state.remoteRenderer?.srcObject = event.streams[0];
        }
      };

      // Create Offer
      RTCSessionDescription offer = await _peerConnection!.createOffer();
      await _peerConnection!.setLocalDescription(offer);
      
      _sendSignaling(peerId, {
        'type': 'offer',
        'sdp': offer.sdp,
        'callType': type.toString(),
      });
      
    } catch (e) {
      state = state.copyWith(status: CallStatus.idle, errorMessage: e.toString());
      _cleanup();
    }
  }

  Future<void> _handleOffer(int senderId, Map<String, dynamic> sig) async {
    if (state.status != CallStatus.idle) {
      _sendSignaling(senderId, {'type': 'busy'});
      return;
    }
    
    final callType = sig['callType'] == CallType.video.toString() 
        ? CallType.video : CallType.voice;
        
    state = state.copyWith(
      status: CallStatus.ringing, 
      peerId: senderId, 
      type: callType,
      remoteSdp: sig['sdp'],
    );
  }

  Future<void> acceptCall() async {
    if (state.status != CallStatus.ringing || state.peerId == null || state.remoteSdp == null) return;
    
    try {
      await _initializeRenderers();
      _peerConnection = await createPeerConnection(_iceConfig);
      
      final constraints = {
        'audio': true,
        'video': state.type == CallType.video,
      };
      _localStream = await navigator.mediaDevices.getUserMedia(constraints);
      state.localRenderer?.srcObject = _localStream;
      _localStream!.getTracks().forEach((track) {
        _peerConnection!.addTrack(track, _localStream!);
      });

      _peerConnection!.onIceCandidate = (candidate) {
        _sendSignaling(state.peerId!, {
          'type': 'candidate',
          'candidate': candidate.toMap(),
        });
      };

      _peerConnection!.onTrack = (event) {
        if (event.streams.isNotEmpty) {
          state.remoteRenderer?.srcObject = event.streams[0];
        }
      };

      // Set Remote Description (the offer)
      await _peerConnection!.setRemoteDescription(
        RTCSessionDescription(state.remoteSdp!, 'offer')
      );
      
      // Create Answer
      RTCSessionDescription answer = await _peerConnection!.createAnswer();
      await _peerConnection!.setLocalDescription(answer);

      _sendSignaling(state.peerId!, {
        'type': 'answer',
        'sdp': answer.sdp,
      });

      state = state.copyWith(status: CallStatus.connected);
    } catch (e) {
      state = state.copyWith(status: CallStatus.idle, errorMessage: e.toString());
      _cleanup();
    }
  }

  // Refined implementations below... (I'll update them in the actual file)
  
  void _sendSignaling(int peerId, Map<String, dynamic> data) {
    final ws = ref.read(webSocketServiceProvider);
    // Simplified: Always sending to device 1 for this prototype
    ws.sendSignalingMessage(peerId, 1, data);
  }

  Future<void> _initializeRenderers() async {
    final local = RTCVideoRenderer();
    final remote = RTCVideoRenderer();
    await local.initialize();
    await remote.initialize();
    state = state.copyWith(localRenderer: local, remoteRenderer: remote);
  }

  void _handleAnswer(Map<String, dynamic> sig) async {
    if (_peerConnection == null) return;
    await _peerConnection!.setRemoteDescription(
      RTCSessionDescription(sig['sdp'], 'answer')
    );
    state = state.copyWith(status: CallStatus.connected);
  }

  void _handleCandidate(Map<String, dynamic> sig) async {
    if (_peerConnection == null) return;
    await _peerConnection!.addCandidate(
      RTCIceCandidate(
        sig['candidate']['candidate'],
        sig['candidate']['sdpMid'],
        sig['candidate']['sdpMLineIndex'],
      )
    );
  }

  void _handleReject() {
    state = state.copyWith(status: CallStatus.ended);
    Future.delayed(const Duration(seconds: 2), () {
      state = CallState();
      _cleanup();
    });
  }

  void _handleEnd() {
    _handleReject();
  }

  void rejectCall() {
    if (state.peerId != null) {
      _sendSignaling(state.peerId!, {'type': 'reject'});
    }
    _cleanup();
    state = CallState();
  }

  void endCall() {
    if (state.peerId != null) {
      _sendSignaling(state.peerId!, {'type': 'end'});
    }
    _cleanup();
    state = CallState();
  }

  void _handleBusy() {
    state = state.copyWith(status: CallStatus.ended, errorMessage: 'User is busy');
    Future.delayed(const Duration(seconds: 2), () {
      state = CallState();
      _cleanup();
    });
  }

  void _cleanup() {
    _localStream?.dispose();
    _peerConnection?.close();
    state.localRenderer?.dispose();
    state.remoteRenderer?.dispose();
    _peerConnection = null;
    _localStream = null;
  }
}

final callStateProvider = StateNotifierProvider<CallNotifier, CallState>((ref) {
  return CallNotifier(ref);
});
