import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:video_player/video_player.dart';

class UploadScreen extends StatefulWidget {
  @override
  _UploadScreenState createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  File? _videoFile;
  VideoPlayerController? _controller;
  final _captionController = TextEditingController();
  bool _isUploading = false;
  double _uploadProgress = 0.0;

  Future<void> _pickVideo() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickVideo(source: ImageSource.gallery);

      if (pickedFile != null) {
        setState(() {
          _videoFile = File(pickedFile.path);
        });
        await _initializeVideoPlayer();
      }
    } catch (e) {
      _showSnackBar('Error picking video: $e');
    }
  }

  Future<void> _initializeVideoPlayer() async {
    if (_videoFile == null) return;

    try {
      _controller = VideoPlayerController.file(_videoFile!);
      await _controller!.initialize();
      _controller!.setLooping(true);
      _controller!.play();

      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      _showSnackBar('Error loading video preview: $e');
    }
  }

  Future<void> _uploadVideo() async {
    if (_videoFile == null) {
      _showSnackBar('Please select a video first');
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showSnackBar('User not authenticated');
      return;
    }

    // Refresh auth token
    try {
      await user.getIdToken(true);
    } catch (e) {
      _showSnackBar('Authentication expired. Please sign in again.');
      return;
    }

    setState(() {
      _isUploading = true;
      _uploadProgress = 0.0;
    });

    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'videos/${user.uid}/${timestamp}.mp4';

      // Create reference with proper path structure
      final storageRef = FirebaseStorage.instance.ref(fileName);

      // Set metadata with correct content type
      final metadata = SettableMetadata(
        contentType: 'video/mp4',
        customMetadata: {
          'uploadedBy': user.uid,
          'uploadedAt': timestamp.toString(),
        },
      );

      // Start upload task
      final uploadTask = storageRef.putFile(_videoFile!, metadata);

      // Track upload progress
      uploadTask.snapshotEvents.listen((snapshot) {
        if (snapshot.totalBytes > 0 && mounted) {
          setState(() {
            _uploadProgress = snapshot.bytesTransferred / snapshot.totalBytes;
          });
        }
      });

      // Complete upload
      final taskSnapshot = await uploadTask;
      final downloadUrl = await taskSnapshot.ref.getDownloadURL();

      // Save to Firestore with server timestamp
      // In your _uploadVideo function, ensure you're using FieldValue.serverTimestamp()
      await FirebaseFirestore.instance.collection('videos').add({
        'videoUrl': downloadUrl,
        'caption': _captionController.text.trim(),
        'userId': user.uid,
        'createdAt': FieldValue.serverTimestamp(), // Use server timestamp
        'likes': <String>[],
        'saves': <String>[],
        'views': 0,
      });

      _showSnackBar('Video uploaded successfully!');
      if (mounted) Navigator.pop(context);
    } on FirebaseException catch (e) {
      String errorMessage = 'Upload failed: ';
      if (e.code == 'permission-denied' || e.code == 'unauthorized') {
        errorMessage += 'Permission denied. Please check your storage rules.';
      } else {
        errorMessage += e.message ?? e.code;
      }
      _showSnackBar(errorMessage);
    } catch (e) {
      _showSnackBar('Upload failed: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
          _uploadProgress = 0.0;
        });
      }
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text('Upload Video', style: TextStyle(color: Colors.white)),
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Video Preview Area
            Container(
              height: 400,
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[700]!),
              ),
              child: _videoFile == null
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.video_library_outlined,
                          color: Colors.grey,
                          size: 80,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'No video selected',
                          style: TextStyle(color: Colors.grey, fontSize: 18),
                        ),
                      ],
                    )
                  : ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child:
                          _controller != null &&
                              _controller!.value.isInitialized
                          ? AspectRatio(
                              aspectRatio: _controller!.value.aspectRatio,
                              child: VideoPlayer(_controller!),
                            )
                          : Center(
                              child: CircularProgressIndicator(
                                color: Colors.white,
                              ),
                            ),
                    ),
            ),

            SizedBox(height: 20),

            // Select Video Button
            ElevatedButton.icon(
              onPressed: _isUploading ? null : _pickVideo,
              icon: Icon(Icons.video_library, color: Colors.white),
              label: Text(
                'Select Video',
                style: TextStyle(color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey[800],
                padding: EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),

            SizedBox(height: 20),

            // Caption Input
            TextField(
              controller: _captionController,
              style: TextStyle(color: Colors.white),
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Write a caption...',
                hintStyle: TextStyle(color: Colors.grey),
                filled: true,
                fillColor: Colors.grey[900],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
            ),

            SizedBox(height: 30),

            // Upload Progress
            if (_isUploading) ...[
              Column(
                children: [
                  LinearProgressIndicator(
                    value: _uploadProgress,
                    backgroundColor: Colors.grey[800],
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.red),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Uploading... ${(_uploadProgress * 100).toInt()}%',
                    style: TextStyle(color: Colors.white, fontSize: 14),
                  ),
                ],
              ),
              SizedBox(height: 20),
            ],

            // Upload Button
            SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: _isUploading ? null : _uploadVideo,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: _isUploading
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          ),
                          SizedBox(width: 12),
                          Text(
                            'Uploading...',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      )
                    : Text(
                        'Upload Video',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller?.dispose();
    _captionController.dispose();
    super.dispose();
  }
}
