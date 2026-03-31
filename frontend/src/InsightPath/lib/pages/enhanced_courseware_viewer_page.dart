import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart'; 
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import '../models/course.dart';
import '../models/file_item.dart';
import '../models/section.dart';
import '../models/ai_message.dart';
import '../models/rag_search_response.dart';
import '../services/ai_service.dart';
import '../services/rag_service.dart';
import '../utils/app_theme.dart';
import '../pages/global_ai_tutor_page.dart';
import '../pages/animation_player_page.dart';

class EnhancedCoursewareViewerPage extends StatefulWidget {
  final String fileUrl;
  final String fileName;
  final int courseId;
  final int sectionId;
  final int courseFileId; // 新增：course_files表的ID

  const EnhancedCoursewareViewerPage({
    Key? key,
    required this.fileUrl,
    required this.fileName,
    required this.courseId,
    required this.sectionId,
    required this.courseFileId, // 传递course_file_id
  }) : super(key: key);

  @override
  State<EnhancedCoursewareViewerPage> createState() => _EnhancedCoursewareViewerPageState();
}

class _EnhancedCoursewareViewerPageState extends State<EnhancedCoursewareViewerPage> {
  final Completer<SfPdfViewerController> _completer = Completer();
  final RagService _ragService = RagService(http.Client(), AuthService());
  final TextEditingController _queryController = TextEditingController();
  
  List<HighlightData> _highlights = [];
  Set<String> _highlightedChunks = {};
  bool _isProcessing = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.fileName),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: _isProcessing ? null : _showSearchDialog,
          ),
          PopupMenuButton<String>(
            onSelected: (String choice) {
              if (choice == 'process') {
                _startDocumentProcessing();
              }
            },
            itemBuilder: (BuildContext context) {
              return [
                const PopupMenuItem<String>(
                  value: 'process',
                  child: Text('处理文档（生成AI索引）'),
                ),
              ];
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          SfPdfViewer.network(
            widget.fileUrl,
            controller: _completer.future,
          ),
          // 高亮覆盖层
          Positioned.fill(
            child: CustomPaint(
              painter: HighlightOverlayPainter(_highlights),
            ),
          ),
          // 处理进度指示器
          if (_isProcessing)
            Container(
              color: Colors.black26,
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('正在处理文档...', style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _startDocumentProcessing() async {
    setState(() {
      _isProcessing = true;
    });

    try {
      final success = await _ragService.processDocument(widget.courseFileId);
      if (success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('文档处理已启动，请稍后使用搜索功能')),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('文档处理启动失败')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('处理请求失败:  $ e')),
        );
      }
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  void _showSearchDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('AI智能搜索'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _queryController,
                decoration: const InputDecoration(
                  hintText: '输入您的问题...',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.question_answer),
                ),
                onSubmitted: (value) => _performSearch(),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: _performSearch,
              child: const Text('搜索'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _performSearch() async {
    if (_queryController.text.isEmpty) return;

    Navigator.pop(context); // 关闭搜索框

    try {
      // 执行语义搜索
      final response = await _ragService.semanticSearch(
        query: _queryController.text,
        documentId: widget.courseFileId,
      );

      // 解析引用并高亮显示
      _highlightReferences(response.references);
      
      // 显示AI答案
      _showAnswerDialog(response.answer, response.references);

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('搜索失败:  $ e')),
        );
      }
    }
  }

  void _highlightReferences(List<SearchReference> references) {
    final controllerFuture = _completer.future;
    controllerFuture.then((pdfController) async {
      // 清除之前的所有高亮
      _clearHighlights();

      // 添加新的高亮
      for (final ref in references) {
        // 跳过已经高亮过的块
        if (_highlightedChunks.contains(ref.chunkId)) continue;
        
        _highlightedChunks.add(ref.chunkId);
        
        // 等待页面信息可用
        await Future.delayed(const Duration(milliseconds: 100));
        
        try {
          // 获取页面尺寸
          final pageInfo = await pdfController.getPageInfo(ref.pageNumber - 1);
          final pageSize = Size(pageInfo.width.toDouble(), pageInfo.height.toDouble());
          
          // 转换归一化坐标为像素坐标
          final pixelCoords = _normalizeToPixel(ref.coordinates!, pageSize);

          // 添加高亮数据
          setState(() {
            _highlights.add(HighlightData(
              rect: pixelCoords,
              pageNumber: ref.pageNumber - 1,
              color: Colors.yellow.withOpacity(0.4),
              confidence: ref.confidenceScore!,
            ));
          });

          // 导航到对应页面
          if (pdfController.pageController.page?.round() != ref.pageNumber - 1) {
            pdfController.jumpToPage(ref.pageNumber - 1);
          }
        } catch (e) {
          print('Error getting page info:  $ e');
        }
      }
    });
  }

  Rect _normalizeToPixel(List<double> normalizedCoords, Size pageSize) {
    return Rect.fromLTWH(
      normalizedCoords[0] * pageSize.width,  // x0
      normalizedCoords[1] * pageSize.height, // y0
      (normalizedCoords[2] - normalizedCoords[0]) * pageSize.width,  // width
      (normalizedCoords[3] - normalizedCoords[1]) * pageSize.height, // height
    );
  }

  void _clearHighlights() {
    setState(() {
      _highlights.clear();
      _highlightedChunks.clear();
    });
  }

  void _showAnswerDialog(String answer, List<SearchReference> references) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.lightbulb, color: Colors.blue),
              const SizedBox(width: 8),
              const Text('AI回答'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  answer,
                  style: const TextStyle(fontSize: 16),
                ),
                if (references.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text(
                    '参考资料:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  ...references.asMap().entries.map((entry) {
                    final index = entry.key;
                    final ref = entry.value;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.blue.shade100,
                          foregroundColor: Colors.blue,
                          child: Text(' $ {index + 1}'),
                        ),
                        title: Text(
                          '第 $ {ref.pageNumber}页',
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        subtitle: Text(
                          ' $ {ref.content.length > 100 ? ref.content.substring(0, 100) + '...' : ref.content}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: Icon(
                          Icons.arrow_forward_ios,
                          size: 16,
                          color: Theme.of(context).primaryColor,
                        ),
                        onTap: () {
                          // 点击跳转到对应高亮位置
                          _jumpToHighlight(ref.chunkId);
                          Navigator.pop(context);
                        },
                      ),
                    );
                  }).toList(),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('关闭'),
            ),
          ],
        );
      },
    );
  }

  void _jumpToHighlight(String chunkId) {
    final highlight = _highlights.firstWhere(
      (h) => _getChunkIdFromHighlight(h) == chunkId,
      orElse: () => _highlights.first,
    );
    
    _completer.future.then((controller) {
      controller.jumpToPage(highlight.pageNumber);
    });
  }

  String _getChunkIdFromHighlight(HighlightData highlight) {
    // 这里需要一种方式将highlight与chunkId关联
    // 可以通过在HighlightData中添加chunkId字段
    return '';
  }
}

// 扩展高亮数据类
class HighlightData {
  final Rect rect;
  final int pageNumber;
  final Color color;
  final double confidence;

  HighlightData({
    required this.rect,
    required this.pageNumber,
    required this.color,
    required this.confidence,
  });
}

// 高亮绘制器
class HighlightOverlayPainter extends CustomPainter {
  final List<HighlightData> highlights;

  HighlightOverlayPainter(this.highlights);

  @override
  void paint(Canvas canvas, Size size) {
    for (final highlight in highlights) {
      // 绘制半透明黄色矩形
      final paint = Paint()
        ..color = highlight.color
        ..style = PaintingStyle.fill;
      
      canvas.drawRect(highlight.rect, paint);
      
      // 添加脉冲动画效果
      final borderPaint = Paint()
        ..color = Colors.yellow.shade800
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke;
      
      canvas.drawRect(highlight.rect, borderPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}