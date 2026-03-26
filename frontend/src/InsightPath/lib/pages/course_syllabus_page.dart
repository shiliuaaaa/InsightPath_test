import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../models/file_item.dart';
import '../models/syllabus_node.dart';
import '../services/section_service.dart';
import '../utils/app_theme.dart';
import 'courseware_viewer_page.dart';

class CourseSyllabusPage extends StatefulWidget {
  const CourseSyllabusPage({
    super.key,
    required this.courseId,
    required this.courseTitle,
    this.canEdit = false,
    this.embedded = false,
    this.storageSectionId,
  });

  final int courseId;
  final String courseTitle;
  final bool canEdit;
  final bool embedded;
  final int? storageSectionId;

  @override
  State<CourseSyllabusPage> createState() => _CourseSyllabusPageState();
}

class _CourseSyllabusPageState extends State<CourseSyllabusPage> {
  final SectionService _sectionService = SectionService();

  bool _loading = true;
  List<SyllabusNode> _nodes = [];
  int? _storageSectionId;

  @override
  void initState() {
    super.initState();
    _storageSectionId = widget.storageSectionId;
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    await _ensureStorageSectionId();
    final nodes = await _sectionService.fetchSyllabus(widget.courseId);
    if (!mounted) return;
    setState(() {
      _nodes = nodes;
      _loading = false;
    });
  }

  Future<void> _ensureStorageSectionId() async {
    if (_storageSectionId != null) return;
    final sections = await _sectionService.fetchSections(widget.courseId);
    final storage = sections.where((e) => e.type == 'STORAGE').toList();
    if (storage.isNotEmpty) {
      _storageSectionId = storage.first.id;
    }
  }

  Future<List<FileItem>> _collectAllFiles() async {
    if (_storageSectionId == null) return [];
    final files = <FileItem>[];
    final queue = <int>[0];
    final visited = <int>{};

    while (queue.isNotEmpty) {
      final pid = queue.removeAt(0);
      if (visited.contains(pid)) continue;
      visited.add(pid);

      final resp = await _sectionService.fetchFiles(
        courseId: widget.courseId,
        sectionId: _storageSectionId!,
        parentId: pid,
      );
      final list = resp?.files ?? [];
      for (final f in list) {
        if (f.type == 'FOLDER') {
          final id = int.tryParse(f.id) ?? 0;
          if (id > 0) queue.add(id);
        } else {
          files.add(f);
        }
      }
    }

    return files;
  }

  Future<void> _createChapter() async {
    final controller = TextEditingController();
    final title = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('创建章节'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: '章节名称'),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, controller.text.trim()), child: const Text('创建')),
        ],
      ),
    );

    if (title == null || title.isEmpty) return;
    final ok = await _sectionService.createSyllabusChapter(courseId: widget.courseId, title: title);
    if (!mounted) return;
    if (ok != null) {
      await _loadAll();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('章节创建成功')));
    }
  }

  Future<void> _createKnowledge(SyllabusNode chapter) async {
    final titleCtrl = TextEditingController();
    int? selectedFileId;
    String? selectedFileName;

    await _ensureStorageSectionId();
    final allFiles = await _collectAllFiles();

    if (!mounted) return;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(14, 14, 14, MediaQuery.of(ctx).viewInsets.bottom + 14),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('创建知识点', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 10),
                  TextField(
                    controller: titleCtrl,
                    decoration: const InputDecoration(
                      hintText: '知识点名称',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () async {
                          final chosen = await showDialog<FileItem>(
                            context: ctx,
                            builder: (ctx2) => AlertDialog(
                              title: const Text('从资料中选择文件'),
                              content: SizedBox(
                                width: 480,
                                height: 360,
                                child: ListView.builder(
                                  itemCount: allFiles.length,
                                  itemBuilder: (_, i) {
                                    final f = allFiles[i];
                                    return ListTile(
                                      leading: const Icon(Icons.insert_drive_file_rounded),
                                      title: Text(f.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                                      onTap: () => Navigator.pop(ctx2, f),
                                    );
                                  },
                                ),
                              ),
                            ),
                          );
                          if (chosen != null) {
                            setSheetState(() {
                              selectedFileId = int.tryParse(chosen.id);
                              selectedFileName = chosen.name;
                            });
                          }
                        },
                        icon: const Icon(Icons.link_rounded),
                        label: const Text('关联资料文件'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () async {
                          if (_storageSectionId == null) return;
                          final picked = await FilePicker.platform.pickFiles(type: FileType.any);
                          if (picked == null || picked.files.isEmpty || picked.files.first.path == null) return;
                          final file = File(picked.files.first.path!);
                          final fileId = await _sectionService.uploadFileForSyllabus(
                            courseId: widget.courseId,
                            sectionId: _storageSectionId!,
                            file: file,
                            fileName: picked.files.first.name,
                            parentId: 0,
                          );
                          if (fileId != null) {
                            setSheetState(() {
                              selectedFileId = fileId;
                              selectedFileName = picked.files.first.name;
                            });
                          }
                        },
                        icon: const Icon(Icons.upload_file_rounded),
                        label: const Text('单独上传并关联'),
                      ),
                    ],
                  ),
                  if (selectedFileName != null) ...[
                    const SizedBox(height: 8),
                    Text('已选择：$selectedFileName', style: const TextStyle(fontSize: 12, color: AppTheme.bodyColor)),
                  ],
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        final title = titleCtrl.text.trim();
                        if (title.isEmpty || selectedFileId == null) return;
                        final created = await _sectionService.createSyllabusKnowledge(
                          courseId: widget.courseId,
                          chapterId: chapter.id,
                          title: title,
                          resourceFileId: selectedFileId!,
                        );
                        if (!mounted) return;
                        if (created != null) {
                          Navigator.pop(ctx);
                          await _loadAll();
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('知识点创建成功')));
                        }
                      },
                      child: const Text('创建知识点'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _createQuiz(SyllabusNode chapter) async {
    final questionCtrl = TextEditingController();
    final answerCtrl = TextEditingController();
    var quizType = 'CHOICE';
    final options = <QuizOption>[QuizOption(key: 'A', content: '')];

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(14, 14, 14, MediaQuery.of(ctx).viewInsets.bottom + 14),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('创建习题', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 10),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'CHOICE', label: Text('选择题')),
                      ButtonSegment(value: 'ESSAY', label: Text('大题')),
                    ],
                    selected: {quizType},
                    onSelectionChanged: (s) => setSheetState(() => quizType = s.first),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: questionCtrl,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      hintText: '输入题目',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  if (quizType == 'CHOICE') ...[
                    const SizedBox(height: 10),
                    ...options.asMap().entries.map((entry) {
                      final i = entry.key;
                      final option = entry.value;
                      final ctrl = TextEditingController(text: option.content);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            SizedBox(width: 26, child: Text(option.key)),
                            Expanded(
                              child: TextField(
                                controller: ctrl,
                                onChanged: (v) => options[i] = QuizOption(key: option.key, content: v),
                                decoration: const InputDecoration(
                                  hintText: '选项内容',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                    TextButton.icon(
                      onPressed: () {
                        final key = String.fromCharCode('A'.codeUnitAt(0) + options.length);
                        setSheetState(() => options.add(QuizOption(key: key, content: '')));
                      },
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('新建选项'),
                    ),
                  ],
                  const SizedBox(height: 10),
                  TextField(
                    controller: answerCtrl,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: quizType == 'CHOICE' ? '输入正确答案选项（如 A）' : '输入示例回答',
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        final q = questionCtrl.text.trim();
                        final a = answerCtrl.text.trim();
                        if (q.isEmpty || a.isEmpty) return;
                        final created = await _sectionService.createSyllabusQuiz(
                          courseId: widget.courseId,
                          chapterId: chapter.id,
                          quizType: quizType,
                          question: q,
                          answer: a,
                          options: quizType == 'CHOICE' ? options : const [],
                        );
                        if (!mounted) return;
                        if (created != null) {
                          Navigator.pop(ctx);
                          await _loadAll();
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('习题创建成功')));
                        }
                      },
                      child: const Text('创建习题'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _openKnowledge(SyllabusNode node) {
    final ext = (node.resourceExtension ?? '').toLowerCase();
    final hasPdf = node.resourcePdfUrl != null && node.resourcePdfUrl!.isNotEmpty;
    final url = node.resourceUrl;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CoursewareViewerPage(
          fileName: node.resourceName ?? node.title,
          pdfUrl: hasPdf ? node.resourcePdfUrl : (ext == 'pdf' && url != null ? _sectionService.getFileAccessUrl(url) : null),
          rawUrl: url,
          extension: node.resourceExtension,
          pageContent: '知识点：${node.title}',
          courseId: widget.courseId,
          sectionId: _storageSectionId,
        ),
      ),
    );
  }

  void _openQuiz(SyllabusNode node) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _QuizPreviewPage(node: node),
      ),
    );
  }

  Widget _buildNodeList() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_nodes.isEmpty) {
      return const Center(child: Text('暂无大纲内容'));
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 20),
      itemCount: _nodes.length,
      itemBuilder: (context, chapterIndex) {
        final chapter = _nodes[chapterIndex];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppTheme.radiusM),
            border: Border.all(color: const Color(0xFFEFF2F6)),
          ),
          child: Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
              leading: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.auto_stories_rounded, size: 16, color: AppTheme.primary),
              ),
              title: Text(
                chapter.title,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.titleColor),
              ),
              subtitle: Text('${chapter.children.length} 项', style: const TextStyle(fontSize: 12, color: AppTheme.hintColor)),
              children: [
                if (widget.canEdit)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        TextButton.icon(
                          onPressed: () => _createKnowledge(chapter),
                          icon: const Icon(Icons.lightbulb_outline_rounded, size: 18),
                          label: const Text('加知识点'),
                        ),
                        TextButton.icon(
                          onPressed: () => _createQuiz(chapter),
                          icon: const Icon(Icons.quiz_outlined, size: 18),
                          label: const Text('加习题'),
                        ),
                      ],
                    ),
                  ),
                ...chapter.children.map((node) {
                  IconData icon;
                  if (node.isKnowledge) {
                    icon = Icons.lightbulb_rounded;
                  } else if (node.isQuizChoice) {
                    icon = Icons.checklist_rounded;
                  } else {
                    icon = Icons.edit_note_rounded;
                  }

                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14),
                    leading: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: AppTheme.secondary.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(icon, color: AppTheme.secondary, size: 18),
                    ),
                    title: Text(node.title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                    subtitle: node.isKnowledge
                        ? Text(node.resourceName ?? '未关联文件', style: const TextStyle(fontSize: 12, color: AppTheme.hintColor))
                        : Text(node.question ?? '', maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12, color: AppTheme.hintColor)),
                    trailing: const Icon(Icons.chevron_right_rounded, color: AppTheme.hintColor),
                    onTap: () => node.isKnowledge ? _openKnowledge(node) : _openQuiz(node),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final content = Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFEAF3FF), AppTheme.bg],
        ),
      ),
      child: _buildNodeList(),
    );

    if (widget.embedded) {
      return Column(
        children: [
          if (widget.canEdit)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
              child: Align(
                alignment: Alignment.centerLeft,
                child: ElevatedButton.icon(
                  onPressed: _createChapter,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('创建章节'),
                ),
              ),
            ),
          Expanded(child: content),
        ],
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        title: Text('课程大纲 · ${widget.courseTitle}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        iconTheme: const IconThemeData(color: Colors.white),
        flexibleSpace: Container(decoration: const BoxDecoration(gradient: AppTheme.heroGradient)),
        actions: [
          if (widget.canEdit)
            IconButton(
              tooltip: '创建章节',
              onPressed: _createChapter,
              icon: const Icon(Icons.add_rounded, color: Colors.white),
            ),
        ],
      ),
      body: content,
    );
  }
}

class _QuizPreviewPage extends StatefulWidget {
  const _QuizPreviewPage({required this.node});

  final SyllabusNode node;

  @override
  State<_QuizPreviewPage> createState() => _QuizPreviewPageState();
}

class _QuizPreviewPageState extends State<_QuizPreviewPage> {
  String? selected;

  @override
  Widget build(BuildContext context) {
    final node = widget.node;
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(title: const Text('习题预览')),
      body: Padding(
        padding: const EdgeInsets.all(14),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFEFF2F6)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(node.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              Text(node.question ?? '', style: const TextStyle(fontSize: 14, color: AppTheme.titleColor)),
              const SizedBox(height: 12),
              if (node.isQuizChoice)
                ...node.options.map((opt) {
                  final value = '${opt.key}. ${opt.content}';
                  return RadioListTile<String>(
                    value: opt.key,
                    groupValue: selected,
                    onChanged: (v) => setState(() => selected = v),
                    title: Text(value),
                    contentPadding: EdgeInsets.zero,
                  );
                }),
              const Spacer(),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  node.isQuizChoice ? '正确答案：${node.answer ?? ''}' : '示例回答：${node.answer ?? ''}',
                  style: const TextStyle(color: AppTheme.titleColor),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
