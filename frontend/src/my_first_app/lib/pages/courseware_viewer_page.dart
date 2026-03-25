import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

import '../services/auth_service.dart';
import '../utils/app_theme.dart';

class CoursewareViewerPage extends StatefulWidget {
  final String fileName;
  final String? pdfUrl;     // 后端返回的 pdf_url（相对路径）
  final String? rawUrl;     // 原文件 stored_name，用于非 PDF 下载
  final String? extension;

  const CoursewareViewerPage({
    super.key,
    required this.fileName,
    this.pdfUrl,
    this.rawUrl,
    this.extension,
  });

  @override
  State<CoursewareViewerPage> createState() => _CoursewareViewerPageState();
}

class _CoursewareViewerPageState extends State<CoursewareViewerPage> {
  static const String _baseUrl = 'http://localhost:8080';

  final AuthService _auth = AuthService();
  bool _loading = false;
  String? _error;

  // 图片扩展名
  static const _imageExts = {'jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'};

  bool get _isPdf {
    final ext = (widget.extension ?? '').toLowerCase();
    return ext == 'pdf' || widget.pdfUrl != null;
  }

  bool get _isImage {
    final ext = (widget.extension ?? '').toLowerCase();
    return _imageExts.contains(ext);
  }

  /// 构建带 token 的完整访问 URL
  String _buildUrl(String path) {
    if (path.startsWith('http')) return path;
    return '$_baseUrl$path';
  }

  /// 下载文件到本地临时目录，再用系统应用打开
  Future<void> _downloadAndOpen() async {
    final token = await _auth.getSavedToken();
    if (token == null) {
      _showError('请先登录');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final dir = await getTemporaryDirectory();
      final savePath = '${dir.path}/${widget.fileName}';
      final url = '$_baseUrl/api/v1/common/static/${widget.rawUrl}?usage=COURSE_MATERIAL';
      final dio = Dio();
      await dio.download(
        url,
        savePath,
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      final result = await OpenFile.open(savePath);
      if (result.type != ResultType.done) {
        _showError('无法打开文件：${result.message}');
      }
    } catch (e) {
      _showError('下载失败：$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    setState(() => _error = msg);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red.shade700),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF16213E),
        foregroundColor: Colors.white,
        title: Text(
          widget.fileName,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          if (!_isPdf && !_isImage)
            TextButton.icon(
              onPressed: _loading ? null : _downloadAndOpen,
              icon: _loading
                  ? const SizedBox(width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.open_in_new_rounded, size: 18, color: Colors.white70),
              label: const Text('用应用打开', style: TextStyle(color: Colors.white70, fontSize: 13)),
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    // 1. PDF 预览（包含 Office 转码后的 PDF）
    if (_isPdf && widget.pdfUrl != null) {
      return _PdfViewerWithAuth(
        pdfUrl: _buildUrl(widget.pdfUrl!),
        auth: _auth,
      );
    }

    // 2. 图片预览
    if (_isImage && widget.rawUrl != null) {
      return _ImageViewer(
        url: '$_baseUrl/api/v1/common/static/${widget.rawUrl}?usage=COURSE_MATERIAL',
        auth: _auth,
      );
    }

    // 3. 其他格式：提示下载用系统应用打开
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.insert_drive_file_outlined,
                size: 72, color: AppTheme.primary.withValues(alpha: 0.7)),
            const SizedBox(height: 20),
            Text(
              widget.fileName,
              style: const TextStyle(color: Colors.white, fontSize: 16,
                  fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              '该格式暂不支持在线预览\n点击下方按钮用本机应用打开',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            ElevatedButton.icon(
              onPressed: _loading ? null : _downloadAndOpen,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: _loading
                  ? const SizedBox(width: 18, height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.download_rounded),
              label: Text(_loading ? '下载中...' : '下载并打开'),
            ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(_error!, style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── PDF 查看器（带 token 认证）─────────────────────────────
class _PdfViewerWithAuth extends StatefulWidget {
  final String pdfUrl;
  final AuthService auth;
  const _PdfViewerWithAuth({required this.pdfUrl, required this.auth});

  @override
  State<_PdfViewerWithAuth> createState() => _PdfViewerWithAuthState();
}

class _PdfViewerWithAuthState extends State<_PdfViewerWithAuth> {
  late Future<Map<String, String>> _headersFuture;

  @override
  void initState() {
    super.initState();
    _headersFuture = widget.auth.getSavedToken().then(
      (t) => t != null ? {'Authorization': 'Bearer $t'} : <String, String>{},
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, String>>(
      future: _headersFuture,
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(
              child: CircularProgressIndicator(color: AppTheme.primary));
        }
        return SfPdfViewer.network(
          widget.pdfUrl,
          headers: snap.data!,
          onDocumentLoadFailed: (details) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('PDF 加载失败：${details.description}')),
            );
          },
        );
      },
    );
  }
}

// ─── 图片查看器 ────────────────────────────────────────────
class _ImageViewer extends StatefulWidget {
  final String url;
  final AuthService auth;
  const _ImageViewer({required this.url, required this.auth});

  @override
  State<_ImageViewer> createState() => _ImageViewerState();
}

class _ImageViewerState extends State<_ImageViewer> {
  late Future<String?> _tokenFuture;

  @override
  void initState() {
    super.initState();
    _tokenFuture = widget.auth.getSavedToken();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: _tokenFuture,
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
        }
        return InteractiveViewer(
          child: Center(
            child: Image.network(
              widget.url,
              headers: snap.data != null
                  ? {'Authorization': 'Bearer ${snap.data}'}
                  : {},
              loadingBuilder: (ctx, child, progress) {
                if (progress == null) return child;
                return const Center(
                    child: CircularProgressIndicator(color: AppTheme.primary));
              },
              errorBuilder: (ctx, err, _) =>
                  const Center(child: Icon(Icons.broken_image, color: Colors.white54, size: 60)),
            ),
          ),
        );
      },
    );
  }
}

