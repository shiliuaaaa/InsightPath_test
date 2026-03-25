import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../models/course.dart';
import '../models/section.dart';
import '../models/file_item.dart';
import '../models/ai_message.dart';
import '../models/file_list_response.dart';
import '../services/section_service.dart';
import '../services/ai_service.dart';
import '../services/auth_service.dart';
import '../utils/app_theme.dart';
import 'courseware_viewer_page.dart';

class CourseInnerPage extends StatefulWidget {
  final Course course;

  const CourseInnerPage({super.key, required this.course});

  @override
  State<CourseInnerPage> createState() => _CourseInnerPageState();
}

class _CourseInnerPageState extends State<CourseInnerPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final SectionService _sectionService = SectionService();
  final AuthService _auth = AuthService();

  String _role = 'STUDENT';

  // ========== 讲义区 ==========
  bool _loadingDisplay = false;
  String? _displayError;
  String? _displayContent;
  Section? _displaySection;
  final TextEditingController _noteController = TextEditingController();
  bool _savingNote = false;

  // ========== 资料区 ==========
  bool _loadingFiles = false;
  String? _filesError;
  List<FileItem> _files = [];
  int _currentFolderId = 0;
  final List<FileItem> _folderStack = [];
  Section? _storageSection;
  List<PathItem> _path = [];

  // ========== AI 区 ==========
  final AiService _aiService = AiService();
  final TextEditingController _aiInputController = TextEditingController();
  final List<AiMessage> _messages = [];
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadUserRole();
    _loadDisplaySection();
    _loadStorageSection();
  }

  Future<void> _loadUserRole() async {
    final user = await _auth.getCurrentUser();
    if (!mounted) return;
    setState(() {
      _role = user?['role'] as String? ?? 'STUDENT';
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _aiInputController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  // ========== 讲义相关 ==========
  Future<void> _loadDisplaySection() async {
    setState(() {
      _loadingDisplay = true;
      _displayError = null;
    });

    try {
      final sections = await _sectionService.fetchSections(widget.course.id);
      final display = sections.firstWhere(
        (s) => s.type == 'DISPLAY',
        orElse: () => Section(
          id: 0,
          courseId: widget.course.id,
          title: '讲义',
          type: 'DISPLAY',
          orderIndex: 0,
        ),
      );
      _displaySection = display;

      final content = await _sectionService.fetchDisplayContent(
        widget.course.id,
        display.id,
      );
      final finalContent = content ?? '# 暂无讲义内容';
      if (mounted) {
        setState(() {
          _displayContent = finalContent;
          _noteController.text = finalContent;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _displayError = '加载讲义失败：$e';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _loadingDisplay = false);
      }
    }
  }

  /// 问题6修复：教师保存讲义同步到后端
  Future<void> _saveNote() async {
    final text = _noteController.text;
    if (_displaySection == null) return;
    setState(() => _savingNote = true);
    try {
      final ok = await _sectionService.updateDisplayContent(
        widget.course.id,
        _displaySection!.id,
        text,
      );
      if (!mounted) return;
      if (ok) {
        setState(() => _displayContent = text);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('讲义已保存')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('保存失败，请重试')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('保存失败：$e')),
      );
    } finally {
      if (mounted) setState(() => _savingNote = false);
    }
  }

  Widget _buildDisplayTab() {
    if (_loadingDisplay) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_displayError != null) {
      return Center(child: Text(_displayError!));
    }
    if (_displayContent == null) {
      return const Center(child: Text('暂无讲义内容'));
    }

    final isTeacher = _role == 'TEACHER';

    if (isTeacher) {
      return Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Expanded(
              child: TextField(
                controller: _noteController,
                maxLines: null,
                expands: true,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                  labelText: '讲义内容（Markdown）',
                ),
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: ElevatedButton.icon(
                onPressed: _savingNote ? null : _saveNote,
                icon: _savingNote
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save),
                label: const Text('保存讲义'),
              ),
            ),
          ],
        ),
      );
    } else {
      return RefreshIndicator(
        onRefresh: _loadDisplaySection,
        child: Markdown(
          data: _displayContent!,
          padding: const EdgeInsets.all(16),
        ),
      );
    }
  }

  // ========== 资料相关 ==========
  bool _uploading = false;

  Future<void> _createFolder() async {
    if (_storageSection == null || _storageSection!.id == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('资料栏目未初始化，请刷新页面重试')));
      return;
    }
    final ctrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(children: [
          Icon(Icons.create_new_folder_outlined, color: AppTheme.primary),
          SizedBox(width: 10),
          Text('新建文件夹'),
        ]),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(hintText: '文件夹名称'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('创建'),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    final ok = await _sectionService.createFolder(
      courseId: widget.course.id,
      sectionId: _storageSection!.id,
      name: name,
      parentId: _currentFolderId,
    );
    if (!mounted) return;
    if (ok) {
      _loadFiles(parentId: _currentFolderId);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('创建文件夹失败，请重试')));
    }
  }

  Future<void> _uploadFile() async {
    if (_storageSection == null || _storageSection!.id == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('资料栏目未初始化，请刷新页面重试')));
      return;
    }
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      type: FileType.any,
    );
    if (result == null || result.files.isEmpty) return;
    final picked = result.files.first;
    if (picked.path == null) return;

    setState(() => _uploading = true);
    try {
      final ok = await _sectionService.uploadFile(
        courseId: widget.course.id,
        sectionId: _storageSection!.id,
        file: File(picked.path!),
        fileName: picked.name,
        parentId: _currentFolderId,
      );
      if (!mounted) return;
      if (ok) {
        _loadFiles(parentId: _currentFolderId);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('"${picked.name}" 上传成功'),
            backgroundColor: AppTheme.successColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('上传失败，请重试')));
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _loadStorageSection() async {
    setState(() {
      _loadingFiles = true;
      _filesError = null;
    });

    try {
      final sections = await _sectionService.fetchSections(widget.course.id);
      final storage = sections.firstWhere(
        (s) => s.type == 'STORAGE',
        orElse: () => Section(
          id: 0,
          courseId: widget.course.id,
          title: '资料',
          type: 'STORAGE',
          orderIndex: 0,
        ),
      );
      _storageSection = storage;
      await _loadFiles(parentId: 0);
    } catch (e) {
      if (mounted) {
        setState(() => _filesError = '加载资料区失败：$e');
      }
    } finally {
      if (mounted) setState(() => _loadingFiles = false);
    }
  }

  Future<void> _loadFiles({required int parentId}) async {
    if (_storageSection == null) return;
    setState(() {
      _loadingFiles = true;
      _filesError = null;
    });

    try {
      final FileListResponse? result = await _sectionService.fetchFiles(
        courseId: widget.course.id,
        sectionId: _storageSection!.id,
        parentId: parentId,
      );
      if (mounted) {
        setState(() {
          if (result != null) {
            _files = result.files;
            _currentFolderId = result.currentFolderId;
            _path = result.path;
          } else {
            _files = [];
            _path = [];
          }
        });
      }
    } catch (e) {
      if (mounted) setState(() => _filesError = '加载文件失败：$e');
    } finally {
      if (mounted) setState(() => _loadingFiles = false);
    }
  }

  /// 问题7修复：重命名对接后端
  Future<void> _renameItem(FileItem item) async {
    final controller = TextEditingController(text: item.name);
    final newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('重命名'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: '新名称'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('确定'),
          ),
        ],
      ),
    );

    if (newName == null || newName.isEmpty || _storageSection == null) return;

    final ok = await _sectionService.renameFile(
      courseId: widget.course.id,
      sectionId: _storageSection!.id,
      itemId: item.id,
      newName: newName,
    );

    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('重命名成功')));
      _loadFiles(parentId: _currentFolderId);
    } else {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('重命名失败，请重试')));
    }
  }

  /// 问题7修复：删除对接后端
  Future<void> _deleteItem(FileItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除「${item.name}」吗？${item.type == 'FOLDER' ? '\n文件夹内所有内容将一并删除。' : ''}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true || _storageSection == null) return;

    final ok = await _sectionService.deleteFile(
      courseId: widget.course.id,
      sectionId: _storageSection!.id,
      itemId: item.id,
      type: item.type,
    );

    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('删除成功')));
      _loadFiles(parentId: _currentFolderId);
    } else {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('删除失败，请重试')));
    }
  }

  IconData _fileIcon(String? ext) {
    switch ((ext ?? '').toLowerCase()) {
      case 'pdf': return Icons.picture_as_pdf_rounded;
      case 'doc': case 'docx': return Icons.description_rounded;
      case 'xls': case 'xlsx': return Icons.table_chart_rounded;
      case 'ppt': case 'pptx': return Icons.slideshow_rounded;
      case 'jpg': case 'jpeg': case 'png': case 'gif': case 'webp': return Icons.image_rounded;
      case 'mp4': case 'mov': case 'avi': return Icons.video_file_rounded;
      case 'mp3': case 'wav': return Icons.audio_file_rounded;
      case 'zip': case 'rar': case '7z': return Icons.folder_zip_rounded;
      case 'txt': case 'md': return Icons.text_snippet_rounded;
      default: return Icons.insert_drive_file_rounded;
    }
  }

  String _formatSize(int? sizeBytes) {
    if (sizeBytes == null || sizeBytes <= 0) return '';
    if (sizeBytes < 1024) return '$sizeBytes B';
    if (sizeBytes < 1024 * 1024) {
      return '${(sizeBytes / 1024).toStringAsFixed(1)} KB';
    }
    if (sizeBytes < 1024 * 1024 * 1024) {
      return '${(sizeBytes / 1024 / 1024).toStringAsFixed(1)} MB';
    }
    return '${(sizeBytes / 1024 / 1024 / 1024).toStringAsFixed(1)} GB';
  }

  Widget _buildStorageTab() {
    if (_loadingFiles) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_filesError != null) {
      return Center(child: Text(_filesError!));
    }

    final listView = Expanded(
      child: RefreshIndicator(
        onRefresh: () => _loadFiles(parentId: _currentFolderId),
        child: _files.isEmpty
            ? const Center(child: Text('暂无文件'))
            : ListView.builder(
                itemCount: _files.length,
                itemBuilder: (context, index) {
                  final item = _files[index];
                  final isFolder = item.type == 'FOLDER';

                  return Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: const Border.fromBorderSide(BorderSide(color: Color(0xFFF0F0F5))),
                    ),
                    child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                    leading: Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        color: isFolder
                            ? const Color(0xFFFFF3E0)
                            : AppTheme.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        isFolder ? Icons.folder_rounded : _fileIcon(item.extension),
                        color: isFolder ? const Color(0xFFF59E0B) : AppTheme.primary,
                        size: 22,
                      ),
                    ),
                    title: Text(item.name,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppTheme.titleColor),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text(
                      isFolder ? '${item.itemCount ?? 0} 项' : _formatSize(item.sizeBytes),
                      style: const TextStyle(fontSize: 12, color: AppTheme.hintColor),
                    ),
                    trailing: _role == 'TEACHER'
                        ? PopupMenuButton<String>(
                            icon: const Icon(Icons.more_vert_rounded, size: 18, color: AppTheme.hintColor),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            onSelected: (value) {
                              if (value == 'rename') { _renameItem(item); }
                              else if (value == 'delete') { _deleteItem(item); }
                            },
                            itemBuilder: (context) => [
                              const PopupMenuItem(value: 'rename',
                                child: Row(children: [Icon(Icons.drive_file_rename_outline_rounded, size: 18), SizedBox(width: 8), Text('重命名')])),
                              const PopupMenuItem(value: 'delete',
                                child: Row(children: [Icon(Icons.delete_outline_rounded, size: 18, color: Colors.red), SizedBox(width: 8), Text('删除', style: TextStyle(color: Colors.red))])),
                            ],
                          )
                        : const Icon(Icons.chevron_right_rounded, size: 18, color: AppTheme.hintColor),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    onTap: isFolder
                        ? () {
                            _folderStack.add(item);
                            _loadFiles(
                                parentId: int.tryParse(item.id) ?? 0);
                          }
                        : () {
                            // 跳转到预览页面
                            final hasPdf = item.pdfUrl != null && item.pdfUrl!.isNotEmpty;
                            final ext = (item.extension ?? '').toLowerCase();
                            const imageExts = {'jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'};
                            final isImage = imageExts.contains(ext);
                            final canPreview = hasPdf || isImage || ext == 'pdf';

                            if (canPreview || (item.url != null && item.url!.isNotEmpty)) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => CoursewareViewerPage(
                                    fileName: item.name,
                                    pdfUrl: hasPdf ? item.pdfUrl : (ext == 'pdf' ? _sectionService.getFileAccessUrl(item.url!) : null),
                                    rawUrl: item.url,
                                    extension: item.extension,
                                  ),
                                ),
                              );
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('该格式暂不支持在线预览')),
                              );
                            }
                          },
                  ),
                  );
                },
              ),
      ),
    );

    final backTile = _currentFolderId != 0
        ? ListTile(
            leading: const Icon(Icons.arrow_upward),
            title: const Text('返回上一级'),
            onTap: () {
              if (_folderStack.isNotEmpty) {
                final parent = _folderStack.removeLast();
                _loadFiles(parentId: parent.parentId);
              } else {
                _loadFiles(parentId: 0);
              }
            },
          )
        : null;

    return Column(
      children: [
        if (backTile != null) backTile,
        // 面包屑导航
        if (_path.isNotEmpty)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              children: _path.map((p) {
                final isLast = p == _path.last;
                return GestureDetector(
                  onTap: isLast
                      ? null
                      : () {
                          while (_folderStack.isNotEmpty &&
                              _folderStack.last.id != p.id.toString()) {
                            _folderStack.removeLast();
                          }
                          if (_folderStack.isNotEmpty) _folderStack.removeLast();
                          _loadFiles(parentId: p.id);
                        },
                  child: Row(
                    children: [
                      Text(
                        p.name,
                        style: TextStyle(
                          color: isLast ? Colors.black : Colors.blue,
                          fontSize: 13,
                        ),
                      ),
                      if (!isLast)
                        const Icon(Icons.chevron_right, size: 16),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Row(
            children: [
              if (_role == 'TEACHER') ...[  
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _createFolder,
                    icon: const Icon(Icons.create_new_folder_outlined, size: 18),
                    label: const Text('新建文件夹'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.primary,
                      side: const BorderSide(color: AppTheme.primary),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _uploading ? null : _uploadFile,
                    icon: _uploading
                        ? const SizedBox(width: 16, height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.upload_file_rounded, size: 18),
                    label: Text(_uploading ? '上传中...' : '上传文件'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.secondary,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        listView,
      ],
    );
  }

  // ========== AI 区 ==========

  /// 问题8修复：清空历史同步到后端
  Future<void> _clearAiHistory() async {
    try {
      await _aiService.clearChatHistory(widget.course.id);
    } catch (_) {
      // 即使后端失败，本地也清空
    } finally {
      if (mounted) {
        setState(() => _messages.clear());
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('对话记录已清除')),
        );
      }
    }
  }

  Future<void> _sendMessage() async {
    final text = _aiInputController.text.trim();
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
      _aiInputController.clear();
    });

    try {
      final reply = await _aiService.sendChat(
        courseId: widget.course.id,
        message: text,
      );
      if (reply != null && mounted) {
        setState(() => _messages.add(reply));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('发送失败：$e')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Widget _buildAiTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            children: [
              ElevatedButton.icon(
                onPressed: _messages.isEmpty ? null : _clearAiHistory,
                icon: const Icon(Icons.delete_sweep, size: 18),
                label: const Text('清空聊天'),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: _messages.length,
            itemBuilder: (context, index) {
              final m = _messages[index];
              final isUser = m.role == 'USER';
              return Align(
                alignment:
                    isUser ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  padding: const EdgeInsets.all(10),
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.75,
                  ),
                  decoration: BoxDecoration(
                    color: isUser
                        ? Colors.blue.shade100
                        : Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(m.content),
                ),
              );
            },
          ),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _aiInputController,
                  minLines: 1,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    hintText: '向课程 AI 提问…',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: _sending ? null : _sendMessage,
                icon: _sending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ========== 页面整体 ==========
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.course.title),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '讲义'),
            Tab(text: '资料'),
            Tab(text: '课程 AI'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildDisplayTab(),
          _buildStorageTab(),
          _buildAiTab(),
        ],
      ),
    );
  }
}
