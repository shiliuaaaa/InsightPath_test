import 'dart:ui';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

import '../services/ai_service.dart';
import '../services/auth_service.dart';
import '../models/ai_message.dart';
import '../utils/app_theme.dart';
import 'animation_player_page.dart';
import 'global_ai_tutor_page.dart';

class CoursewareViewerPage extends StatefulWidget {
  final String fileName;
  final String? pdfUrl;     // 后端返回的 pdf_url（相对路径）
  final String? rawUrl;     // 原文件 stored_name，用于非 PDF 下载
  final String? extension;
  final String? pageContent;
  final int? courseId;

  const CoursewareViewerPage({
    super.key,
    required this.fileName,
    this.pdfUrl,
    this.rawUrl,
    this.extension,
    this.pageContent,
    this.courseId,
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
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        title: Text(
          widget.fileName,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            tooltip: '动画讲解',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AnimationPlayerPage(
                    sourceTitle: widget.fileName,
                    sourceContent: widget.pageContent,
                  ),
                ),
              );
            },
            icon: const Icon(Icons.auto_awesome_rounded, size: 20),
          ),
          IconButton(
            tooltip: '小犀',
            onPressed: () {
              if (widget.courseId != null) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => _CourseAiQuickPage(
                      courseId: widget.courseId!,
                      sourceTitle: widget.fileName,
                    ),
                  ),
                );
                return;
              }
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const GlobalAiTutorPage(username: '同学'),
                ),
              );
            },
            icon: const Icon(Icons.smart_toy_outlined),
          ),
          if (!_isPdf && !_isImage)
            IconButton(
              tooltip: '用应用打开',
              onPressed: _loading ? null : _downloadAndOpen,
              icon: _loading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary),
                    )
                  : const Icon(Icons.open_in_new_rounded, size: 18),
            ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFEAF3FF), AppTheme.bg],
          ),
        ),
        child: _buildBody(),
      ),
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
        padding: const EdgeInsets.all(24),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppTheme.radiusL),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(AppTheme.radiusL),
                border: Border.all(color: Colors.white.withValues(alpha: 0.8)),
              ),
              padding: const EdgeInsets.all(26),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.insert_drive_file_outlined, size: 72, color: AppTheme.primary.withValues(alpha: 0.7)),
                  const SizedBox(height: 20),
                  Text(
                    widget.fileName,
                    style: const TextStyle(color: AppTheme.titleColor, fontSize: 16, fontWeight: FontWeight.w600),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    '该格式暂不支持在线预览\n点击下方按钮用本机应用打开',
                    style: TextStyle(color: AppTheme.bodyColor, fontSize: 13),
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
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
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
          ),
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

class _CourseAiQuickPage extends StatefulWidget {
  const _CourseAiQuickPage({required this.courseId, required this.sourceTitle});

  final int courseId;
  final String sourceTitle;

  @override
  State<_CourseAiQuickPage> createState() => _CourseAiQuickPageState();
}

class _CourseAiQuickPageState extends State<_CourseAiQuickPage> {
  final AiService _aiService = AiService();
  final TextEditingController _controller = TextEditingController();
  final List<AiMessage> _messages = [];
  bool _sending = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;

    setState(() {
      _sending = true;
      _messages.add(
        AiMessage(
          id: DateTime.now().millisecondsSinceEpoch,
          role: 'USER',
          content: text,
          createdAt: DateTime.now(),
        ),
      );
      _controller.clear();
    });

    final reply = await _aiService.sendChat(courseId: widget.courseId, message: text);
    if (!mounted) return;
    setState(() {
      _sending = false;
      if (reply != null) {
        _messages.add(reply);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(title: const Text('小犀')),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            child: Text(
              '当前资料：${widget.sourceTitle}',
              style: const TextStyle(fontSize: 13, color: AppTheme.hintColor),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _messages.length,
              itemBuilder: (_, i) {
                final m = _messages[i];
                final isUser = m.role == 'USER';
                return Align(
                  alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 5),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
                    decoration: BoxDecoration(
                      color: isUser ? const Color(0xFF1A73E8) : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      m.content,
                      style: TextStyle(color: isUser ? Colors.white : const Color(0xFF1F2937)),
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 6, 10, 12),
            child: Row(
              children: [
                IconButton(
                  onPressed: () {},
                  icon: const Icon(Icons.add_circle_outline_rounded, color: AppTheme.hintColor),
                ),
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      hintText: '围绕当前资料提问...',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _send(),
                  ),
                ),
                IconButton(
                  onPressed: _sending ? null : _send,
                  icon: _sending
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send_rounded),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

