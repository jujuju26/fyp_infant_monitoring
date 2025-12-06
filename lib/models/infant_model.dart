class Infant {
  String id;
  String name;
  String dob; // ISO date string e.g., 2025-01-01
  String room;
  String notes;
  String avatarUrl;

  Infant({
    required this.id,
    required this.name,
    required this.dob,
    required this.room,
    this.notes = '',
    this.avatarUrl = '',
  });

  factory Infant.fromMap(String id, Map<String, dynamic> data) {
    return Infant(
      id: id,
      name: data['name'] ?? '',
      dob: data['dob'] ?? '',
      room: data['room'] ?? '',
      notes: data['notes'] ?? '',
      avatarUrl: data['avatarUrl'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'dob': dob,
      'room': room,
      'notes': notes,
      'avatarUrl': avatarUrl,
    };
  }
}
