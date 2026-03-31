class SearchReference {
  final String title;
  final String snippet;
  final String link;

  SearchReference({
    required this.title,
    required this.snippet,
    required this.link,
  });

  factory SearchReference.fromJson(Map<String, dynamic> json) {
    return SearchReference(
      title: json['title'] as String,
      snippet: json['snippet'] as String,
      link: json['link'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'snippet': snippet,
      'link': link,
    };
  }
}