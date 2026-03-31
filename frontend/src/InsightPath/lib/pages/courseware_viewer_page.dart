import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

import '../models/ai_message.dart';
import '../models/animation_dsl.dart';
import '../services/ai_service.dart';
import '../services/auth_service.dart';
import '../utils/app_theme.dart';
import '../widgets/animation_canvas.dart';
import 'global_ai_tutor_page.dart';

class CoursewareViewerPage extends StatefulWidget {
  final String fileName;
  final String? pdfUrl;
  final String? rawUrl;
  final String? extension;
  final String? pageContent;
  final int? courseId;
  final int? sectionId;

  const CoursewareViewerPage({
    super.key,
    required this.fileName,
    this.pdfUrl,
    this.rawUrl,
    this.extension,
    this.pageContent,
    this.courseId,
    this.sectionId,
  });

  @override
  State<CoursewareViewerPage> createState() => _CoursewareViewerPageState();
}

class _CoursewareViewerPageState extends State<CoursewareViewerPage> {
  static const String _baseUrl = 'http://localhost:8080';

  final AuthService _auth = AuthService();
  final AiService _aiService = AiService();
  final PdfViewerController _pdfController = PdfViewerController();

  bool _loading = false;
  String? _error;
  String _role = 'STUDENT';
  int _currentPageNumber = 1;
  List<SectionAiConfig> _presetConfigs = [];

  static const _imageExts = {'jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'};

  bool get _isPdf {
    final ext = (widget.extension ?? '').toLowerCase();
    return ext == 'pdf' || widget.pdfUrl != null;
  }

  bool get _isImage {
    final ext = (widget.extension ?? '').toLowerCase();
    return _imageExts.contains(ext);
  }

  bool get _isTeacher => _role == 'TEACHER';

  SectionAiConfig? get _currentPagePreset {
    final list = _presetConfigs.where((e) => e.pageNumber == _currentPageNumber).toList();
    if (list.isEmpty) return null;
    list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return list.first;
  }

  @override
  void initState() {
    super.initState();
    _initRoleAndPresets();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _initRoleAndPresets() async {
    final user = await _auth.getCurrentUser();
    final role = user?['role'] as String? ?? 'STUDENT';

    List<SectionAiConfig> presets = [];
    if (widget.sectionId != null) {
      presets = await _aiService.getPresetConfigs('${widget.sectionId}');
    }

    if (!mounted) return;
    setState(() {
      _role = role;
      _presetConfigs = presets;
    });
  }

  Future<void> _reloadPresets() async {
    if (widget.sectionId == null) return;
    final presets = await _aiService.getPresetConfigs('${widget.sectionId}');
    if (!mounted) return;
    setState(() => _presetConfigs = presets);
  }

  String _buildUrl(String path) {
    if (path.startsWith('http')) return path;
    return '$_baseUrl$path';
  }

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

  AnimationScript? _parseScript(String dsl) {
    try {
      final json = jsonDecode(dsl);
      if (json is Map<String, dynamic>) {
        return AnimationScript.fromJson(json);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  AnimationScript _defaultBubbleSortScript() {
    final initialValues = [5, 3, 8, 1, 2];
    final nodeOrder = List.generate(initialValues.length, (i) => 'node_$i');
    final values = List<int>.from(initialValues);
    final steps = <Map<String, dynamic>>[];

    steps.add({
      'step_index': 0,
      'narration': '初始化数组：$initialValues。',
      'actions': [
        {'action': 'CREATE', 'entity_id': 'array_container', 'type': 'ArrayContainer', 'index': [0, 0]},
        for (var i = 0; i < initialValues.length; i++)
          {
            'action': 'CREATE',
            'entity_id': 'node_$i',
            'type': 'ArrayNode',
            'value': '${initialValues[i]}',
            'pos': i,
            'theme': 'default',
          },
      ],
    });

    var stepIndex = 1;
    final n = values.length;

    for (var pass = 0; pass < n - 1; pass++) {
      final rightBoundary = n - 1 - pass;
      for (var j = 0; j < rightBoundary; j++) {
        final leftId = nodeOrder[j];
        final rightId = nodeOrder[j + 1];
        final leftVal = values[j];
        final rightVal = values[j + 1];
        final shouldSwap = leftVal > rightVal;

        final actions = <Map<String, dynamic>>[
          {'action': 'UPDATE', 'entity_id': leftId, 'theme': 'active'},
          {'action': 'UPDATE', 'entity_id': rightId, 'theme': 'active'},
        ];

        if (shouldSwap) {
          actions.add({'action': 'SWAP', 'entity_id_1': leftId, 'entity_id_2': rightId});

          final tmpValue = values[j];
          values[j] = values[j + 1];
          values[j + 1] = tmpValue;

          final tmpId = nodeOrder[j];
          nodeOrder[j] = nodeOrder[j + 1];
          nodeOrder[j + 1] = tmpId;
        }

        actions.add({'action': 'UPDATE', 'entity_id': leftId, 'theme': 'default'});
        actions.add({'action': 'UPDATE', 'entity_id': rightId, 'theme': 'default'});

        if (j == rightBoundary - 1) {
          actions.add({'action': 'UPDATE', 'entity_id': nodeOrder[rightBoundary], 'theme': 'locked'});
        }

        final suffix = j == rightBoundary - 1 ? '，${values[rightBoundary]} 到达末尾。' : '。';
        steps.add({
          'step_index': stepIndex++,
          'narration': '第${pass + 1}轮：比较 $leftVal 和 $rightVal，${shouldSwap ? '交换' : '不交换'}$suffix',
          'actions': actions,
        });
      }
    }

    steps.add({
      'step_index': stepIndex,
      'narration': '排序完成：$values。',
      'actions': [
        for (final id in nodeOrder)
          {'action': 'UPDATE', 'entity_id': id, 'theme': 'locked'},
      ],
    });

    return AnimationScript.fromJson({
      'version': '4.0',
      'title': '冒泡排序演示',
      'scene': 'array_sort',
      'steps': steps,
    });
  }

  void _openScriptPlayer(AnimationScript script) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AnimationCanvas(script: script)),
    );
  }

  void _playCurrentPreset() {
    final script = _defaultBubbleSortScript();
    _openScriptPlayer(script);
  }

  Future<void> _showTeacherPresetActions() async {
    final preset = _currentPagePreset;
    if (preset == null) {
      await _showTeacherPresetSheet();
      return;
    }

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.6)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('第 $_currentPageNumber 页动画',
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                    const SizedBox(height: 12),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.play_circle_fill_rounded, color: AppTheme.primary),
                      title: const Text('播放动画'),
                      onTap: () {
                        Navigator.pop(ctx);
                        _playCurrentPreset();
                      },
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.auto_fix_high_rounded, color: AppTheme.secondary),
                      title: const Text('更换动画（重新生成）'),
                      onTap: () {
                        Navigator.pop(ctx);
                        _showTeacherPresetSheet(initialPrompt: preset.prompt);
                      },
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.delete_outline_rounded, color: AppTheme.errorColor),
                      title: const Text('删除动画', style: TextStyle(color: AppTheme.errorColor)),
                      onTap: () async {
                        Navigator.pop(ctx);
                        final ok = await _aiService.deletePresetConfig(
                          '${widget.sectionId}',
                          _currentPageNumber,
                        );
                        if (!mounted) return;
                        if (ok) {
                          await _reloadPresets();
                          ScaffoldMessenger.of(context)
                              .showSnackBar(const SnackBar(content: Text('动画已删除')));
                        } else {
                          ScaffoldMessenger.of(context)
                              .showSnackBar(const SnackBar(content: Text('删除失败，请稍后重试')));
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _showTeacherPresetSheet({String? initialPrompt}) async {
    final promptController = TextEditingController(text: initialPrompt ?? '');
    bool generating = false;
    bool saving = false;
    AnimationScript? previewScript;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 14,
                right: 14,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 14,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.82),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.6)),
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.auto_awesome_rounded, color: AppTheme.primary),
                            const SizedBox(width: 8),
                            Text('预设知径 · 第 $_currentPageNumber 页',
                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                            const Spacer(),
                            IconButton(
                              onPressed: () => Navigator.pop(ctx),
                              icon: const Icon(Icons.close_rounded),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        TextField(
                          controller: promptController,
                          minLines: 2,
                          maxLines: 4,
                          decoration: const InputDecoration(
                            hintText: '例如：演示冒泡排序的交换过程',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: generating
                                    ? null
                                    : () async {
                                        final prompt = promptController.text.trim();
                                        if (prompt.isEmpty) return;
                                        setSheetState(() => generating = true);
                                        try {
                                          final script = _defaultBubbleSortScript();
                                          setSheetState(() => previewScript = script);
                                        } finally {
                                          setSheetState(() => generating = false);
                                        }
                                      },
                                icon: generating
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                      )
                                    : const Icon(Icons.auto_fix_high_rounded),
                                label: Text(generating ? '生成中...' : '生成预览'),
                              ),
                            ),
                          ],
                        ),
                        if (previewScript != null) ...[
                          const SizedBox(height: 12),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.85),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFE7ECF3)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(previewScript!.title,
                                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                                const SizedBox(height: 4),
                                Text('共 ${previewScript!.steps.length} 步 · ${previewScript!.steps.first.narration}',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 12, color: AppTheme.bodyColor)),
                                const SizedBox(height: 8),
                                OutlinedButton.icon(
                                  onPressed: () => _openScriptPlayer(previewScript!),
                                  icon: const Icon(Icons.play_circle_outline_rounded, size: 18),
                                  label: const Text('打开预览播放器'),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: saving
                                  ? null
                                  : () async {
                                      if (widget.sectionId == null) return;
                                      final prompt = promptController.text.trim();
                                      if (prompt.isEmpty) return;
                                      final dsl = jsonEncode(previewScript!.toJson());
                                      setSheetState(() => saving = true);
                                      final ok = await _aiService.savePresetConfig(
                                        '${widget.sectionId}',
                                        _currentPageNumber,
                                        prompt,
                                        dsl,
                                      );
                                      setSheetState(() => saving = false);
                                      if (!mounted) return;
                                      if (ok) {
                                        Navigator.pop(ctx);
                                        await _reloadPresets();
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(const SnackBar(content: Text('预设已保存到当前页')));
                                      } else {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(const SnackBar(content: Text('保存失败，请稍后重试')));
                                      }
                                    },
                              icon: saving
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                    )
                                  : const Icon(Icons.save_rounded),
                              label: Text(saving ? '保存中...' : '保存预设到当前页'),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _showStudentAiSheet() async {
    final promptController = TextEditingController();
    bool generating = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 14,
                right: 14,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 14,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.82),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.6)),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('AI 助教', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                        const SizedBox(height: 8),
                        TextField(
                          controller: promptController,
                          minLines: 2,
                          maxLines: 4,
                          decoration: const InputDecoration(
                            hintText: '描述你想看的动画讲解',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: generating
                                ? null
                                : () async {
                                    final prompt = promptController.text.trim();
                                    if (prompt.isEmpty) return;
                                    setSheetState(() => generating = true);
                                    try {
                                      final script = _defaultBubbleSortScript();
                                      if (!mounted) return;
                                      Navigator.pop(ctx);
                                      _openScriptPlayer(script);
                                    } finally {
                                      setSheetState(() => generating = false);
                                    }
                                  },
                            icon: generating
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : const Icon(Icons.auto_awesome_rounded),
                            label: Text(generating ? '生成中...' : '生成动画讲解'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget? _buildAdaptiveFab() {
    if (!_isPdf || widget.sectionId == null) return null;

    if (_isTeacher) {
      return FloatingActionButton.extended(
        onPressed: _showTeacherPresetSheet,
        icon: const Icon(Icons.add_rounded),
        label: const Text('预设知径'),
      );
    }

    return FloatingActionButton.extended(
      onPressed: _showStudentAiSheet,
      icon: const Icon(Icons.smart_toy_outlined),
      label: const Text('AI 助教'),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      floatingActionButton: _buildAdaptiveFab(),
      appBar: AppBar(
        title: Text(
          widget.fileName,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          if (_isPdf)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: const Color(0xFFE8ECF2)),
                    ),
                    child: Text('第 $_currentPageNumber 页', style: const TextStyle(fontSize: 12)),
                  ),
                  if (_currentPagePreset != null) ...[
                    const SizedBox(width: 6),
                    Tooltip(
                      message: '播放当前页动画',
                      child: Material(
                        color: AppTheme.primary,
                        shape: const CircleBorder(),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: _isTeacher ? _showTeacherPresetActions : _playCurrentPreset,
                          child: Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: AppTheme.primary),
                            ),
                            child: const Icon(
                              Icons.play_arrow_rounded,
                              size: 14,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
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
    if (_isPdf && widget.pdfUrl != null) {
      return FutureBuilder<String?>(
        future: _auth.getSavedToken(),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
          }
          final headers = snap.data != null ? {'Authorization': 'Bearer ${snap.data}'} : <String, String>{};
          return SfPdfViewer.network(
            _buildUrl(widget.pdfUrl!),
            controller: _pdfController,
            headers: headers,
            onPageChanged: (details) {
              if (!mounted) return;
              setState(() => _currentPageNumber = details.newPageNumber);
            },
            onDocumentLoadFailed: (details) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('PDF 加载失败：${details.description}')),
              );
            },
          );
        },
      );
    }

    if (_isImage && widget.rawUrl != null) {
      return _ImageViewer(
        url: '$_baseUrl/api/v1/common/static/${widget.rawUrl}?usage=COURSE_MATERIAL',
        auth: _auth,
      );
    }

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
                  Icon(Icons.insert_drive_file_outlined,
                      size: 72, color: AppTheme.primary.withValues(alpha: 0.7)),
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
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
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
              headers: snap.data != null ? {'Authorization': 'Bearer ${snap.data}'} : {},
              loadingBuilder: (ctx, child, progress) {
                if (progress == null) return child;
                return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
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
  int? _sessionId;
  String? _attachedFileName;
  String? _attachedFileContext;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _attachFile() async {
    if (_sending) return;
    final picked = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      withData: false,
      type: FileType.any,
    );
    if (picked == null || picked.files.isEmpty || picked.files.first.path == null) {
      return;
    }

    final file = File(picked.files.first.path!);
    if (!await file.exists()) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('文件不存在，无法读取')),
      );
      return;
    }

    String text;
    try {
      text = await file.readAsString();
    } catch (_) {
      try {
        final bytes = await file.readAsBytes();
        text = const Utf8Decoder(allowMalformed: true).convert(bytes);
      } catch (_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('暂不支持解析该文件内容')),
        );
        return;
      }
    }

    final normalized = text.trim();
    if (normalized.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('文件内容为空')),
      );
      return;
    }

    final clipped = normalized.length > 8000 ? normalized.substring(0, 8000) : normalized;
    if (!mounted) return;
    setState(() {
      _attachedFileName = picked.files.first.name;
      _attachedFileContext = clipped;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已附加：${picked.files.first.name}')),
    );
  }

  void _clearAttachedFile() {
    if (!mounted) return;
    setState(() {
      _attachedFileName = null;
      _attachedFileContext = null;
    });
  }

  Future<void> _ensureSession() async {
    if (_sessionId != null) return;
    _sessionId = await _aiService.createGlobalSession();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;

    final currentFileContext = _attachedFileContext;

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
      _attachedFileName = null;
      _attachedFileContext = null;
    });

    await _ensureSession();
    String? reply;
    if (_sessionId != null) {
      reply = await _aiService.sendGlobalMessage(
        '$_sessionId',
        '【资料上下文】${widget.sourceTitle}\n$text',
        enableWebSearch: true,
        fileContext: currentFileContext,
      );
    }
    if (!mounted) return;
    setState(() {
      _sending = false;
      if (reply != null && reply.trim().isNotEmpty) {
        _messages.add(
          AiMessage(
            id: DateTime.now().millisecondsSinceEpoch + 1,
            role: 'ASSISTANT',
            content: reply,
            createdAt: DateTime.now(),
          ),
        );
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
          if (_attachedFileName != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F0FE),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFD2E3FC)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.attach_file_rounded, size: 16, color: Color(0xFF1A73E8)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _attachedFileName!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF1F2937),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: _clearAttachedFile,
                      child: const Icon(Icons.close_rounded, size: 16, color: Color(0xFF6B7280)),
                    ),
                  ],
                ),
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
                  onPressed: _attachFile,
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
