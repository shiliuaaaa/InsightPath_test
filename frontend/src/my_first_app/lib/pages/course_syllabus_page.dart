import 'package:flutter/material.dart';

import '../utils/app_theme.dart';
import 'courseware_viewer_page.dart';
import 'lesson_quiz_page.dart';

class CourseSyllabusPage extends StatefulWidget {
  const CourseSyllabusPage({super.key});

  @override
  State<CourseSyllabusPage> createState() => _CourseSyllabusPageState();
}

class _CourseSyllabusPageState extends State<CourseSyllabusPage> {
  final List<Map<String, dynamic>> syllabusData = [
    {
      'chapter': '第一章：排序算法之美',
      'lessons': [
        {
          'title': '1.1 冒泡排序的原理与图解',
          'type': 'pdf',
          'url': 'https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf',
        },
        {
          'title': '1.2 [随堂测试] 冒泡的边界条件',
          'type': 'quiz',
          'quizId': 'q_001',
        },
        {
          'title': '1.3 选择排序与插入排序对比',
          'type': 'pdf',
          'url': 'https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf',
        },
      ],
    },
    {
      'chapter': '第二章：树与图的探索',
      'lessons': [
        {
          'title': '2.1 二叉树的层序遍历',
          'type': 'pdf',
          'url': 'https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf',
        },
        {
          'title': '2.2 [随堂测试] DFS 与 BFS 场景判断',
          'type': 'quiz',
          'quizId': 'q_002',
        },
        {
          'title': '2.3 图的邻接表建模实战',
          'type': 'pdf',
          'url': 'https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf',
        },
      ],
    },
    {
      'chapter': '第三章：综合训练与实战',
      'lessons': [
        {
          'title': '3.1 经典题：Top K 与优先队列',
          'type': 'pdf',
          'url': 'https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf',
        },
        {
          'title': '3.2 [综合测试] 数据结构选型题',
          'type': 'quiz',
          'quizId': 'q_003',
        },
      ],
    },
  ];

  void _onTapLesson(Map<String, dynamic> lesson) {
    final type = lesson['type'] as String? ?? '';

    if (type == 'pdf') {
      final title = lesson['title'] as String? ?? '课件预览';
      final url = lesson['url'] as String? ?? '';
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CoursewareViewerPage(
            fileName: title,
            pdfUrl: url,
            extension: 'pdf',
          ),
        ),
      );
      return;
    }

    if (type == 'quiz') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => LessonQuizPage(
            lessonTitle: lesson['title'] as String? ?? '随堂测试',
            quizId: lesson['quizId'] as String? ?? '',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        title: const Text('课程大纲', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        iconTheme: const IconThemeData(color: Colors.white),
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: AppTheme.heroGradient),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFEAF3FF), AppTheme.bg],
          ),
        ),
        child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 20),
          itemCount: syllabusData.length,
          itemBuilder: (context, chapterIndex) {
            final chapter = syllabusData[chapterIndex];
            final chapterTitle = chapter['chapter'] as String? ?? '未命名章节';
            final lessons = (chapter['lessons'] as List<dynamic>? ?? [])
                .cast<Map<String, dynamic>>();

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppTheme.radiusM),
                border: Border.all(color: const Color(0xFFEFF2F6)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Theme(
                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                  childrenPadding: const EdgeInsets.only(bottom: 8),
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
                    chapterTitle,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.titleColor,
                    ),
                  ),
                  subtitle: Text(
                    '${lessons.length} 节内容',
                    style: const TextStyle(fontSize: 12, color: AppTheme.hintColor),
                  ),
                  children: [
                    ListView.builder(
                      itemCount: lessons.length,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemBuilder: (context, lessonIndex) {
                        final lesson = lessons[lessonIndex];
                        final type = lesson['type'] as String? ?? '';
                        final isPdf = type == 'pdf';

                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14),
                          leading: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: (isPdf ? AppTheme.primary : AppTheme.secondary).withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              isPdf ? Icons.picture_as_pdf_rounded : Icons.quiz_rounded,
                              color: isPdf ? AppTheme.primary : AppTheme.secondary,
                              size: 18,
                            ),
                          ),
                          title: Text(
                            lesson['title'] as String? ?? '未命名小节',
                            style: const TextStyle(fontSize: 14, color: AppTheme.titleColor, fontWeight: FontWeight.w500),
                          ),
                          trailing: const Icon(
                            Icons.chevron_right_rounded,
                            size: 18,
                            color: AppTheme.hintColor,
                          ),
                          onTap: () => _onTapLesson(lesson),
                        );
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

