import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdfx/pdfx.dart';
import '../../core/theme.dart';
import '../../services/models.dart';
import '../../services/firebase_service.dart';

class DocumentDetailScreen extends StatefulWidget {
  final AppDocument document;

  const DocumentDetailScreen({
    super.key,
    required this.document,
  });

  @override
  State<DocumentDetailScreen> createState() => _DocumentDetailScreenState();
}

class _DocumentDetailScreenState extends State<DocumentDetailScreen> {
  PdfControllerPinch? _pdfController;

  bool get _isPdf => widget.document.fileType == 'pdf';

  @override
  void initState() {
    super.initState();
    if (_isPdf) {
      _pdfController = PdfControllerPinch(
        document: _openPdfFromUrl(widget.document.fileUrl),
      );
    }
  }

  Future<PdfDocument> _openPdfFromUrl(String url) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/pdf_preview_${widget.document.id}.pdf');
    if (!await file.exists()) {
      final client = HttpClient();
      final request = await client.getUrl(Uri.parse(url));
      final response = await request.close();
      final bytes = await response.fold<List<int>>([], (acc, chunk) => acc..addAll(chunk));
      await file.writeAsBytes(bytes);
      client.close();
    }
    return PdfDocument.openFile(file.path);
  }

  @override
  void dispose() {
    _pdfController?.dispose();
    super.dispose();
  }

  void _openFullscreen(BuildContext context) {
    Navigator.push(
      context,
      PageRouteBuilder(
        opaque: false,
        transitionDuration: const Duration(milliseconds: 280),
        pageBuilder: (ctx, anim, secondaryAnim) => _FullscreenImageViewer(
          url: widget.document.fileUrl,
          heroTag: 'doc-image-${widget.document.id}',
        ),
        transitionsBuilder: (ctx, animation, secondaryAnim, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isImage = !_isPdf &&
        (widget.document.fileType == 'image' ||
            widget.document.fileUrl.contains('.jpg') ||
            widget.document.fileUrl.contains('.jpeg') ||
            widget.document.fileUrl.contains('.png') ||
            widget.document.fileUrl.contains('.webp'));

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(widget.document.fileName),
        actions: [
          IconButton(
            icon: Icon(
              widget.document.isStarred ? Icons.star : Icons.star_border,
              color: widget.document.isStarred ? Colors.amber : null,
            ),
            onPressed: () async {
              try {
                await FirebaseService.toggleDocumentStar(widget.document);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(widget.document.isStarred ? 'Removed from Starred' : 'Added to Starred'),
                      duration: const Duration(seconds: 1),
                    ),
                  );
                }
              } catch (_) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Could not update star.'), backgroundColor: Colors.red),
                  );
                }
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.share_outlined),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Sharing coming soon!')),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            onPressed: () => _confirmDelete(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_isPdf) ...[
              SizedBox(
                height: 500,
                child: PdfViewPinch(
                  controller: _pdfController!,
                  scrollDirection: Axis.vertical,
                  builders: PdfViewPinchBuilders<DefaultBuilderOptions>(
                    options: const DefaultBuilderOptions(),
                    documentLoaderBuilder: (_) => const Center(
                      child: CircularProgressIndicator(),
                    ),
                    pageLoaderBuilder: (_) => const Center(
                      child: CircularProgressIndicator(),
                    ),
                    errorBuilder: (_, err) => Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error_outline, size: 48, color: Colors.grey),
                          const SizedBox(height: 12),
                          Text('Could not load PDF', style: TextStyle(color: Colors.grey.shade600)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ] else if (isImage) ...[
              GestureDetector(
                onDoubleTap: () => _openFullscreen(context),
                child: Hero(
                  tag: 'doc-image-${widget.document.id}',
                  child: InteractiveViewer(
                    minScale: 0.1,
                    maxScale: 4.0,
                    child: Image.network(
                      widget.document.fileUrl,
                      width: double.infinity,
                      fit: BoxFit.contain,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Container(
                          height: 300,
                          alignment: Alignment.center,
                          child: CircularProgressIndicator(
                            value: loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded /
                                    loadingProgress.expectedTotalBytes!
                                : null,
                          ),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          height: 300,
                          color: Colors.grey.shade100,
                          alignment: Alignment.center,
                          child: const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.broken_image_outlined, size: 64, color: Colors.grey),
                              SizedBox(height: 16),
                              Text('Could not load image', style: TextStyle(color: Colors.grey)),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.touch_app_outlined, size: 14, color: Colors.grey.shade400),
                    const SizedBox(width: 4),
                    Text(
                      'Double tap to view fullscreen',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
                    ),
                  ],
                ),
              ),
            ] else
              Container(
                height: 300,
                color: Colors.grey.shade100,
                alignment: Alignment.center,
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.insert_drive_file_outlined, size: 64, color: Colors.grey),
                    SizedBox(height: 16),
                    Text('Preview not available', style: TextStyle(color: Colors.grey)),
                  ],
                ),
              ),

            Padding(
              padding: 3.paddingAll,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Details',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  VaultlyTheme.verticalSpace(2),
                  _buildDetailRow('Category', widget.document.category),
                  _buildDetailRow('Uploaded', DateFormat('MMMM dd, yyyy').format(widget.document.createdAt)),
                  if (widget.document.expiryDate != null)
                    _buildDetailRow('Expiry Date', DateFormat('MMMM dd, yyyy').format(widget.document.expiryDate!)),
                  VaultlyTheme.verticalSpace(4),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Document'),
        content: const Text('Are you sure you want to permanently delete this document?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              try {
                messenger.showSnackBar(
                  const SnackBar(content: Text('Deleting document...')),
                );
                await FirebaseService.deleteDocument(widget.document);
                messenger.hideCurrentSnackBar();
                messenger.showSnackBar(
                  const SnackBar(content: Text('Document deleted.')),
                );
                navigator.pop();
              } catch (_) {
                messenger.showSnackBar(
                  const SnackBar(content: Text('Delete failed. Please try again.'), backgroundColor: Colors.red),
                );
              }
            },
            child: const Text('DELETE', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

class _FullscreenImageViewer extends StatefulWidget {
  final String url;
  final String heroTag;

  const _FullscreenImageViewer({required this.url, required this.heroTag});

  @override
  State<_FullscreenImageViewer> createState() => _FullscreenImageViewerState();
}

class _FullscreenImageViewerState extends State<_FullscreenImageViewer> {
  bool _showControls = true;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _toggleControls() => setState(() => _showControls = !_showControls);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: _toggleControls,
        onDoubleTap: () => Navigator.pop(context),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Center(
              child: Hero(
                tag: widget.heroTag,
                child: InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 8.0,
                  child: Image.network(
                    widget.url,
                    fit: BoxFit.contain,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return SizedBox(
                        width: double.infinity,
                        height: 300,
                        child: Center(
                          child: CircularProgressIndicator(
                            color: Colors.white54,
                            value: loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded /
                                    loadingProgress.expectedTotalBytes!
                                : null,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
            AnimatedOpacity(
              opacity: _showControls ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 200),
              child: SafeArea(
                child: Align(
                  alignment: Alignment.topLeft,
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Material(
                      color: Colors.black45,
                      borderRadius: BorderRadius.circular(24),
                      child: IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            AnimatedOpacity(
              opacity: _showControls ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 200),
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 32),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black45,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.touch_app_outlined, size: 14, color: Colors.white54),
                        SizedBox(width: 6),
                        Text(
                          'Double tap to close · Pinch to zoom',
                          style: TextStyle(color: Colors.white54, fontSize: 12),
                        ),
                      ],
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
}
