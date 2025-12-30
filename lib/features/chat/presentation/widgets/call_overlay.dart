import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../providers/call_provider.dart';
import 'package:lucide_icons/lucide_icons.dart';

class CallOverlay extends ConsumerWidget {
  const CallOverlay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final callState = ref.watch(callStateProvider);
    
    if (callState.status == CallStatus.idle) return const SizedBox.shrink();

    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          // Basic Background
          Container(
            width: double.infinity,
            height: double.infinity,
            color: Colors.black.withAlpha(200),
          ),

          // Remote Video (Background when connected)
          if (callState.status == CallStatus.connected && callState.type == CallType.video)
            RTCVideoView(callState.remoteRenderer!, objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover),

          // Main Call Content
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  const SizedBox(height: 40),
                  _buildCallHeader(callState),
                  const Spacer(),
                  if (callState.status == CallStatus.connected && callState.type == CallType.video)
                    _buildLocalVideoPreview(callState),
                  const SizedBox(height: 40),
                  _buildCallControls(context, ref, callState),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCallHeader(CallState state) {
    String statusText = '';
    switch (state.status) {
      case CallStatus.ringing: statusText = 'Incoming Call...'; break;
      case CallStatus.outgoing: statusText = 'Calling...'; break;
      case CallStatus.connected: statusText = 'Connected'; break;
      case CallStatus.ended: statusText = 'Call Ended'; break;
      default: statusText = '';
    }

    return Column(
      children: [
        CircleAvatar(
          radius: 50,
          backgroundColor: Colors.blue.withAlpha(50),
          child: const Icon(LucideIcons.user, size: 50, color: Colors.white),
        ),
        const SizedBox(height: 16),
        Text(
          'User ${state.peerId}',
          style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          statusText,
          style: TextStyle(color: Colors.white.withAlpha(180), fontSize: 16),
        ),
      ],
    );
  }

  Widget _buildLocalVideoPreview(CallState state) {
    return Align(
      alignment: Alignment.bottomRight,
      child: Container(
        width: 120,
        height: 180,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withAlpha(50), width: 2),
        ),
        clipBehavior: Clip.antiAlias,
        child: RTCVideoView(state.localRenderer!, mirror: true, objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover),
      ),
    );
  }

  Widget _buildCallControls(BuildContext context, WidgetRef ref, CallState state) {
    if (state.status == CallStatus.ringing) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _CircleButton(
            icon: LucideIcons.x,
            color: Colors.red,
            onPressed: () => ref.read(callStateProvider.notifier).rejectCall(),
          ),
          _CircleButton(
            icon: state.type == CallType.video ? LucideIcons.video : LucideIcons.phone,
            color: Colors.green,
            onPressed: () => ref.read(callStateProvider.notifier).acceptCall(),
          ),
        ],
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _CircleButton(
          icon: LucideIcons.micOff,
          color: Colors.white.withAlpha(50),
          onPressed: () {},
        ),
        _CircleButton(
          icon: LucideIcons.phoneOff,
          color: Colors.red,
          onPressed: () => ref.read(callStateProvider.notifier).endCall(),
        ),
        _CircleButton(
          icon: LucideIcons.videoOff,
          color: Colors.white.withAlpha(50),
          onPressed: () {},
        ),
      ],
    );
  }
}

class _CircleButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;

  const _CircleButton({required this.icon, required this.color, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: IconButton(
        icon: Icon(icon, color: Colors.white, size: 28),
        onPressed: onPressed,
      ),
    );
  }
}
