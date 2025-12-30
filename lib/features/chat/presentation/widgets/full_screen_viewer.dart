import 'dart:io';
import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';

class FullScreenMediaViewer extends StatelessWidget {
  final File file;
  final String fileName;

  const FullScreenMediaViewer({
    super.key,
    required this.file,
    required this.fileName,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          fileName,
          style: const TextStyle(color: Colors.white, fontSize: 16),
        ),
      ),
      body: PhotoView(
        imageProvider: FileImage(file),
        minScale: PhotoViewComputedScale.contained,
        maxScale: PhotoViewComputedScale.covered * 2.5,
        heroAttributes: PhotoViewHeroAttributes(tag: file.path),
      ),
    );
  }
}
