import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/video_model.dart';

class VideoPlayerWidget extends StatefulWidget {
  final VideoModel video;
  final bool isPlaying;
  final VoidCallback? onVideoChanged;

  const VideoPlayerWidget({
    Key? key,
    required this.video,
    required this.isPlaying,
    this.onVideoChanged,
  }) : super(key: key);

  @override
  _VideoPlayerWidgetState createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget>
    with WidgetsBindingObserver {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _isLiked = false;
  bool _isSaved = false;
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeVideo();
    _checkLikeAndSaveStatus();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (_controller != null) {
      switch (state) {
        case AppLifecycleState.paused:
        case AppLifecycleState.inactive:
          _controller?.pause();
          break;
        case AppLifecycleState.resumed:
          if (widget.isPlaying && _isInitialized) {
            _controller?.play();
          }
          break;
        default:
          break;
      }
    }
  }

  Future<void> _initializeVideo() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _hasError = false;
      _errorMessage = '';
    });

    try {
      // Dispose previous controller if exists
      await _controller?.dispose();
      
      _controller = VideoPlayerController.networkUrl(
        Uri.parse(widget.video.videoUrl),
        videoPlayerOptions: VideoPlayerOptions(
          mixWithOthers: false,
          allowBackgroundPlayback: false,
        ),
      );

      // Add error listener
      _controller!.addListener(_videoListener);

      // Initialize with timeout
      await _controller!.initialize().timeout(
        Duration(seconds: 30),
        onTimeout: () {
          throw Exception('Video initialization timeout');
        },
      );

      if (!mounted) return;

      _controller!.setLooping(true);
      
      setState(() {
        _isInitialized = true;
        _isLoading = false;
      });

      // Auto-play if this video should be playing
      if (widget.isPlaying) {
        await _controller!.play();
      }

      // Notify parent that video changed
      widget.onVideoChanged?.call();

    } catch (e) {
      if (!mounted) return;
      
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = 'Failed to load video: ${e.toString()}';
      });
      
      print('Video initialization error: $e');
    }
  }

  void _videoListener() {
    if (!mounted || _controller == null) return;

    if (_controller!.value.hasError) {
      setState(() {
        _hasError = true;
        _errorMessage = 'Video playback error: ${_controller!.value.errorDescription}';
      });
    }
  }

  void _checkLikeAndSaveStatus() {
    if (!mounted) return;
    
    setState(() {
      _isLiked = widget.video.likes.contains(currentUserId);
      _isSaved = widget.video.saves.contains(currentUserId);
    });
  }

  @override
  void didUpdateWidget(VideoPlayerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // If video changed, reinitialize
    if (widget.video.id != oldWidget.video.id) {
      _initializeVideo();
      _checkLikeAndSaveStatus();
      return;
    }
    
    // Handle play/pause state changes
    if (widget.isPlaying != oldWidget.isPlaying && _controller != null && _isInitialized) {
      if (widget.isPlaying) {
        _controller!.play();
      } else {
        _controller!.pause();
      }
    }
  }

  Future<void> _toggleLike() async {
    if (currentUserId.isEmpty) return;

    try {
      final videoRef = FirebaseFirestore.instance
          .collection('videos')
          .doc(widget.video.id);

      if (_isLiked) {
        await videoRef.update({
          'likes': FieldValue.arrayRemove([currentUserId])
        });
      } else {
        await videoRef.update({
          'likes': FieldValue.arrayUnion([currentUserId])
        });
      }

      if (mounted) {
        setState(() {
          _isLiked = !_isLiked;
        });
      }
    } catch (e) {
      print('Error toggling like: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update like status'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _toggleSave() async {
    if (currentUserId.isEmpty) return;

    try {
      final videoRef = FirebaseFirestore.instance
          .collection('videos')
          .doc(widget.video.id);

      if (_isSaved) {
        await videoRef.update({
          'saves': FieldValue.arrayRemove([currentUserId])
        });
      } else {
        await videoRef.update({
          'saves': FieldValue.arrayUnion([currentUserId])
        });
      }

      if (mounted) {
        setState(() {
          _isSaved = !_isSaved;
        });
      }
    } catch (e) {
      print('Error toggling save: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update save status'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _downloadVideo() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Download feature would be implemented here'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _retryVideo() {
    _initializeVideo();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Video Player or Error/Loading State
          if (_isLoading)
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Loading video...',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            )
          else if (_hasError)
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    color: Colors.red,
                    size: 60,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Video unavailable',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      _errorMessage,
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _retryVideo,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      'Retry',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
            )
          else if (_isInitialized && _controller != null)
            Center(
              child: AspectRatio(
                aspectRatio: _controller!.value.aspectRatio,
                child: VideoPlayer(_controller!),
              ),
            )
          else
            Center(
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2,
              ),
            ),

          // Overlay Controls
          if (_isInitialized && !_hasError)
            Positioned(
              right: 16,
              bottom: 170,
              child: Column(
                children: [
                  // Like Button
                  _buildActionButton(
                    icon: _isLiked ? Icons.favorite : Icons.favorite_border,
                    color: _isLiked ? Colors.red : Colors.white,
                    count: widget.video.likes.length,
                    onTap: _toggleLike,
                  ),
                  SizedBox(height: 20),
                  
                  // Save Button
                  _buildActionButton(
                    icon: _isSaved ? Icons.bookmark : Icons.bookmark_border,
                    color: _isSaved ? Colors.yellow : Colors.white,
                    count: widget.video.saves.length,
                    onTap: _toggleSave,
                  ),
                  SizedBox(height: 20),
                  
                  // Download Button
                  _buildActionButton(
                    icon: Icons.download,
                    color: Colors.white,
                    onTap: _downloadVideo,
                  ),
                ],
              ),
            ),

          // Caption
          if (widget.video.caption.isNotEmpty)
            Positioned(
              left: 16,
              bottom: 80,
              right: 100,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  widget.video.caption,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required Color color,
    int? count,
    required VoidCallback onTap,
  }) {
    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.4),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: color,
              size: 28,
            ),
          ),
        ),
        if (count != null) ...[
          SizedBox(height: 4),
          Text(
            count > 999 ? '${(count / 1000).toStringAsFixed(1)}k' : '$count',
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ],
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.removeListener(_videoListener);
    _controller?.dispose();
    super.dispose();
  }
}