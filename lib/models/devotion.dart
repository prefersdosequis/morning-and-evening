class Devotion {
  final String type; // 'morning' or 'evening'
  final int day;
  final String title;
  final String content;

  Devotion({
    required this.type,
    required this.day,
    required this.title,
    required this.content,
  });

  factory Devotion.fromJson(Map<String, dynamic> json) {
    return Devotion(
      type: json['type'] as String,
      day: json['day'] as int,
      title: json['title'] as String,
      content: json['content'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'day': day,
      'title': title,
      'content': content,
    };
  }
}






