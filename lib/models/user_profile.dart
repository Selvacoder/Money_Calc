class UserProfile {
  final String name;
  final String email;
  final String phone;
  final String photoUrl;
  final DateTime joinDate;

  UserProfile({
    required this.name,
    required this.email,
    required this.phone,
    required this.photoUrl,
    required this.joinDate,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'email': email,
      'phone': phone,
      'photoUrl': photoUrl,
      'joinDate': joinDate.toIso8601String(),
    };
  }

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      name: json['name'],
      email: json['email'],
      phone: json['phone'],
      photoUrl: json['photoUrl'],
      joinDate: DateTime.parse(json['joinDate']),
    );
  }

  static UserProfile getDefault() {
    return UserProfile(
      name: 'Guest User',
      email: 'guest@moneycalc.com',
      phone: '+91 9876543210',
      photoUrl: '',
      joinDate: DateTime.now(),
    );
  }
}
