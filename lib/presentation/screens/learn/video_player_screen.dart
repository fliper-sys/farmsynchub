import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

/// Plays a YouTube video inside the app via an embedded IFrame player.
///
/// Only Android and Web have a working WebView implementation for this
/// package - there is no Windows desktop implementation, so callers should
/// check [VideoPlayerScreen.isSupported] first and fall back to opening the
/// video in an external browser/app on unsupported platforms.
class VideoPlayerScreen extends StatefulWidget {
  const VideoPlayerScreen({
    super.key,
    required this.videoId,
    required this.title,
  });

  final String videoId;
  final String title;

  /// Whether in-app playback is available on the current platform.
  static bool get isSupported =>
      kIsWeb || defaultTargetPlatform == TargetPlatform.android;

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  late final YoutubePlayerController _controller;
  StreamSubscription<YoutubePlayerValue>? _subscription;
  String? _playerErrorCode;
  String? _resourceErrorMessage;

  @override
  void initState() {
    super.initState();
    _controller = YoutubePlayerController(
      params: const YoutubePlayerParams(
        showFullscreenButton: true,
        showControls: true,
        strictRelatedVideos: true,
      ),
      // A WebView resource error (such as error 512) means the embedded
      // player page itself failed to load - often because of network,
      // origin, or embed restrictions on the video. Surface it so we can
      // show a graceful fallback instead of a silent black screen.
      onWebResourceError: (YoutubeWebResourceError error) {
        if (!mounted) return;
        setState(() {
          _resourceErrorMessage =
              '${error.errorType} - ${error.errorCode} ${error.description}';
        });
      },
    );
    // Cue (don't autoplay) the video - browsers frequently block autoplay,
    // which can surface as an IFrame load failure (e.g. a 512 WebView
    // resource error). The user presses play in the player controls.
    _controller.cueVideoById(videoId: widget.videoId);

    // Watch the player value stream for YouTube IFrame errors (2, 5, 100,
    // 101, 105, 150, ...) and clear any transient error once the player is
    // ready again.
    _subscription = _controller.stream.listen((YoutubePlayerValue value) {
      if (!mounted) return;
      setState(() {
        if (value.hasError) {
          _playerErrorCode = value.error.name;
        } else {
          _playerErrorCode = null;
        }
      });
    });
  }

  Future<void> _openInYouTube() async {
    final Uri uri =
        Uri.parse('https://www.youtube.com/watch?v=${widget.videoId}');
    final bool canLaunch = await canLaunchUrl(uri);
    if (canLaunch) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _controller.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(widget.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      body: YoutubePlayerScaffold(
        controller: _controller,
        aspectRatio: 16 / 9,
        builder: (BuildContext context, Widget player) {
          if (_playerErrorCode != null || _resourceErrorMessage != null) {
            return _buildErrorFallback();
          }
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                player,
                const SizedBox(height: 12),
                Text(
                  'Tap play to watch the video.',
                  style: TextStyle(color: Colors.white.withOpacity(0.7)),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildErrorFallback() {
    final String detail = _resourceErrorMessage ??
        (_playerErrorCode != null
            ? 'YouTube error: $_playerErrorCode'
            : 'unknown error');

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.error_outline_rounded,
                color: Colors.white70, size: 48),
            const SizedBox(height: 16),
            const Text(
              "This video couldn't load in the in-app player.",
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              'The video may be unavailable for embedding or the player '
              'failed to load. Open it directly in YouTube instead.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white.withOpacity(0.7)),
            ),
            const SizedBox(height: 6),
            Text(
              detail,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white.withOpacity(0.45)),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _openInYouTube,
              icon: const Icon(Icons.open_in_new_rounded),
              label: const Text('Open in YouTube'),
            ),
          ],
        ),
      ),
    );
  }
}
