class AppNotification {
  final int? id;
  final int patientId;
  final String title;
  final String body;
  final String timestamp; // ISO-8601

  AppNotification({
    this.id,
    required this.patientId,
    required this.title,
    required this.body,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'patient_id': patientId,
      'title': title,
      'body': body,
      'timestamp': timestamp,
    };
  }

  factory AppNotification.fromMap(Map<String, dynamic> map) {
    return AppNotification(
      id: map['id'],
      patientId: map['patient_id'],
      title: map['title'],
      body: map['body'],
      timestamp: map['timestamp'],
    );
  }
}
