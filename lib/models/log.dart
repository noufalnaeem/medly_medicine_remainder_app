class MedicineLog {
  final int? id;
  final int medicineId;
  final String takenTime; // ISO 8601 string or similar
  final String status; // 'taken', 'missed'

  MedicineLog({
    this.id,
    required this.medicineId,
    required this.takenTime,
    required this.status,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'medicine_id': medicineId,
      'taken_time': takenTime,
      'status': status,
    };
  }

  factory MedicineLog.fromMap(Map<String, dynamic> map) {
    return MedicineLog(
      id: map['id'],
      medicineId: map['medicine_id'],
      takenTime: map['taken_time'],
      status: map['status'],
    );
  }
}
