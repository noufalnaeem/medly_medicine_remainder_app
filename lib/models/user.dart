class User {
  final int? id;
  final String? email;
  final String? phone;
  final String role; // 'patient' or 'caregiver'
  final int? linkedPatientId;
  final String? password;
  final String? patientCode;

  User({
    this.id,
    this.email,
    this.phone,
    required this.role,
    this.linkedPatientId,
    this.password,
    this.patientCode,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'email': email,
      'phone': phone,
      'role': role,
      'linked_patient_id': linkedPatientId,
      'password': password,
      if (patientCode != null) 'patient_code': patientCode,
    };
  }

  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      id: map['id'],
      email: map['email'],
      phone: map['phone'],
      role: map['role'],
      linkedPatientId: map['linked_patient_id'],
      password: map['password'],
      patientCode: map['patient_code'],
    );
  }
}
