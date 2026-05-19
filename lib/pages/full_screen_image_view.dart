import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class FullScreenImageView extends StatefulWidget {
  final String imagePath;
  final List<String>? imageFileNames;
  final List<String>? imageUrls;
  final int initialIndex;

  const FullScreenImageView({
    super.key,
    required this.imagePath,
    this.imageFileNames,
    this.imageUrls,
    this.initialIndex = 0,
  });

  @override
  State<FullScreenImageView> createState() => _FullScreenImageViewState();
}

class _FullScreenImageViewState extends State<FullScreenImageView> {
  late PageController _pageController;
  late int _currentIndex;

  bool get _isNetwork =>
      widget.imageUrls != null && widget.imageUrls!.isNotEmpty;
  int get _itemCount =>
      _isNetwork ? widget.imageUrls!.length : (widget.imageFileNames?.length ?? 1);
  List<String> get _allUrls =>
      _isNetwork ? widget.imageUrls! : [];

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasMultiple = _itemCount > 1;

    return GestureDetector(
      onTap: () => Navigator.pop(context),
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            Center(
              child: hasMultiple
                  ? PageView.builder(
                      controller: _pageController,
                      onPageChanged: (index) {
                        setState(() {
                          _currentIndex = index;
                        });
                      },
                      itemCount: _itemCount,
                      itemBuilder: (context, index) =>
                          _buildImageViewer(index),
                    )
                  : _buildImageViewer(_currentIndex),
            ),
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              right: 16,
              child: IconButton(
                icon: const Icon(Icons.close,
                    color: Colors.white, size: 28),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            if (hasMultiple)
              Positioned(
                bottom: MediaQuery.of(context).padding.bottom + 16,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    _itemCount,
                    (index) => Container(
                      width: 8,
                      height: 8,
                      margin:
                          const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: index == _currentIndex
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.4),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageViewer(int index) {
    if (_isNetwork) {
      return InteractiveViewer(
        panEnabled: true,
        scaleEnabled: true,
        minScale: 0.5,
        maxScale: 4,
        child: CachedNetworkImage(
          imageUrl: _allUrls[index],
          fit: BoxFit.contain,
          errorWidget: (context, url, error) => const Center(
            child: Icon(Icons.broken_image,
                color: Colors.white54, size: 64),
          ),
          placeholder: (context, url) => const Center(
            child: CircularProgressIndicator(color: Colors.white54),
          ),
        ),
      );
    }
    return InteractiveViewer(
      panEnabled: true,
      scaleEnabled: true,
      minScale: 0.5,
      maxScale: 4,
      child: Image.file(
        File(widget.imagePath),
        fit: BoxFit.contain,
      ),
    );
  }
}
