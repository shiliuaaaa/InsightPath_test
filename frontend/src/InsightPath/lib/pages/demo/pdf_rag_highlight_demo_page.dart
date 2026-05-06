import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

import '../../services/auth_service.dart';

class PdfRagHighlightDemoPage extends StatefulWidget {
  const PdfRagHighlightDemoPage({
    super.key,
    required this.pdfUrl,
    required this.targetPage,
    required this.sourceTitle,
    required this.initialRects,
  });

  final String pdfUrl;
  final int targetPage;
  final String sourceTitle;
  final List<Rect> initialRects;

  @override
  State<PdfRagHighlightDemoPage> createState() =>
      _PdfRagHighlightDemoPageState();
}

class _PdfRagHighlightDemoPageState extends State<PdfRagHighlightDemoPage> {
  final AuthService _auth = AuthService();
  final PdfViewerController _controller = PdfViewerController();
  final GlobalKey _overlayKey = GlobalKey();

  late List<Rect> _rects;
  late bool _isMarking;
  Offset? _firstPoint;

  @override
  void initState() {
    super.initState();
    _rects = List<Rect>.from(widget.initialRects);
    _isMarking = widget.initialRects.isEmpty;
  }

  void _handleTapDown(TapDownDetails details) {
    if (!_isMarking) return;
    final box = _overlayKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final local = box.globalToLocal(details.globalPosition);
    final size = box.size;
    if (size.width <= 0 || size.height <= 0) return;

    final point = Offset(
      (local.dx / size.width).clamp(0.0, 1.0),
      (local.dy / size.height).clamp(0.0, 1.0),
    );

    setState(() {
      if (_firstPoint == null) {
        _firstPoint = point;
      } else {
        final rect = Rect.fromLTRB(
          point.dx < _firstPoint!.dx ? point.dx : _firstPoint!.dx,
          point.dy < _firstPoint!.dy ? point.dy : _firstPoint!.dy,
          point.dx > _firstPoint!.dx ? point.dx : _firstPoint!.dx,
          point.dy > _firstPoint!.dy ? point.dy : _firstPoint!.dy,
        );
        _rects = [..._rects, rect];
        _firstPoint = null;
      }
    });
  }

  void _undo() {
    setState(() {
      if (_firstPoint != null) {
        _firstPoint = null;
      } else if (_rects.isNotEmpty) {
        _rects = _rects.sublist(0, _rects.length - 1);
      }
    });
  }

  void _clear() {
    setState(() {
      _firstPoint = null;
      _rects = [];
    });
  }

  void _save() {
    Navigator.pop(context, _rects);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(
          _isMarking ? '第 ${widget.targetPage} 页知识点定位' : widget.sourceTitle,
        ),
        actions: [
          if (_isMarking) ...[
            TextButton(onPressed: _undo, child: const Text('撤销')),
            TextButton(onPressed: _clear, child: const Text('清空')),
            TextButton(onPressed: _save, child: const Text('保存')),
          ],
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: FutureBuilder<String?>(
              future: _auth.getSavedToken(),
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                final headers = snap.data != null
                    ? {'Authorization': 'Bearer ${snap.data}'}
                    : <String, String>{};
                return SfPdfViewer.network(
                  widget.pdfUrl,
                  controller: _controller,
                  headers: headers,
                  pageLayoutMode: PdfPageLayoutMode.continuous,
                  onDocumentLoaded: (_) =>
                      _controller.jumpToPage(widget.targetPage),
                );
              },
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              ignoring: !_isMarking,
              child: GestureDetector(
                onTapDown: _handleTapDown,
                child: Container(
                  key: _overlayKey,
                  color: Colors.transparent,
                  child: CustomPaint(
                    painter: _RagRectPainter(
                      rects: _rects,
                      firstPoint: _firstPoint,
                    ),
                    child: const SizedBox.expand(),
                  ),
                ),
              ),
            ),
          ),
          if (_isMarking)
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: IgnorePointer(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.34),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    _firstPoint == null
                        ? '已框选 ${_rects.length} 个区域。继续点击两次可新增高亮框，完成后点保存。'
                        : '再点击一次完成当前高亮框。',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      height: 1.3,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _RagRectPainter extends CustomPainter {
  const _RagRectPainter({required this.rects, required this.firstPoint});

  final List<Rect> rects;
  final Offset? firstPoint;

  @override
  void paint(Canvas canvas, Size size) {
    final fill = Paint()
      ..color = const Color(0xFFFDE047).withValues(alpha: 0.24);
    final stroke = Paint()
      ..color = const Color(0xFFFACC15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    for (final rect in rects) {
      final scaled = Rect.fromLTRB(
        rect.left * size.width,
        rect.top * size.height,
        rect.right * size.width,
        rect.bottom * size.height,
      );
      canvas.drawRect(scaled, fill);
      canvas.drawRect(scaled, stroke);
    }

    if (firstPoint != null) {
      final center = Offset(
        firstPoint!.dx * size.width,
        firstPoint!.dy * size.height,
      );
      canvas.drawCircle(center, 6, Paint()..color = const Color(0xFFF97316));
    }
  }

  @override
  bool shouldRepaint(covariant _RagRectPainter oldDelegate) {
    return oldDelegate.rects != rects || oldDelegate.firstPoint != firstPoint;
  }
}
