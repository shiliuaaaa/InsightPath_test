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

                  return ListTile(
                    leading: Icon(
                      isFolder ? Icons.folder : Icons.insert_drive_file,
                      color: isFolder ? Colors.amber : null,
                    ),
                    title: Text(item.name),
                    subtitle: Text(
                      item.updatedAt,
                      style: const TextStyle(fontSize: 12),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isFolder)
                          Text('${item.itemCount ?? 0} 项',
                              style: const TextStyle(fontSize: 12))
                        else
                          Text(_formatSize(item.sizeBytes),
                              style: const TextStyle(fontSize: 12)),
                        const SizedBox(width: 4),
                        if (_role == 'TEACHER')
                          PopupMenuButton<String>(
                            onSelected: (value) {
                              if (value == 'rename') {
                                _renameItem(item);
                              } else if (value == 'delete') {
                                _deleteItem(item);
                              }
                            },
                            itemBuilder: (context) => const [
                              PopupMenuItem(
                                value: 'rename',
                                child: Row(children: [
                                  Icon(Icons.edit, size: 18),
                                  SizedBox(width: 8),
                                  Text('重命名'),
                                ]),
                              ),
                              PopupMenuItem(
                                value: 'delete',
                                child: Row(children: [
                                  Icon(Icons.delete, size: 18),
                                  SizedBox(width: 8),
                                  Text('删除'),
                                ]),
                              ),
                            ],
                          ),
                      ],
                    ),
                    onTap: isFolder
                        ? () {
                            _folderStack.add(item);
                            _loadFiles(
                                parentId: int.tryParse(item.id) ?? 0);
                          }
                        : () {
                            // TODO: 打开/下载文件
                          },
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
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            children: [
              if (_role == 'TEACHER') ...[  
                ElevatedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('新建文件夹功能待实现')),
                    );
                  },
                  icon: const Icon(Icons.create_new_folder, size: 18),
                  label: const Text('新建文件夹'),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('上传文件功能待实现')),
                    );
                  },
                  icon: const Icon(Icons.upload_file, size: 18),
                  label: const Text('上传文件'),
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
