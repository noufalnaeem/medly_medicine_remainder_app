class Medicine {
  final int? id;
  final String name;
  final String purpose;
  final String dosage;
  final String schedule;
  final int patientId;
  final int quantity;

  Medicine({
    this.id,
    required this.name,
    required this.purpose,
    required this.dosage,
    required this.schedule,
    required this.patientId,
    this.quantity = 10,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'purpose': purpose,
      'dosage': dosage,
      'schedule': schedule,
      'patient_id': patientId,
      'quantity': quantity,
    };
  }

  factory Medicine.fromMap(Map<String, dynamic> map) {
    return Medicine(
      id: map['id'],
      name: map['name'],
      purpose: map['purpose'],
      dosage: map['dosage'],
      schedule: map['schedule'],
      patientId: map['patient_id'],
      quantity: (map['quantity'] as int?) ?? 10,
    );
  }
}

