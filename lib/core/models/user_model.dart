class UserModel {
  final String id;
  final String name;
  final String email;
  final String photoUrl;
  final String currency;
  final bool biometricsEnabled;
  final String familyWalletId;
  final int xp;
  final int level;
  final String upiId;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.photoUrl,
    required this.currency,
    required this.biometricsEnabled,
    required this.familyWalletId,
    required this.xp,
    required this.level,
    required this.upiId,
  });

  factory UserModel.fromMap(Map<dynamic, dynamic> map) {
    return UserModel(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      photoUrl: map['photoUrl'] ?? '',
      currency: map['currency'] ?? '₹',
      biometricsEnabled: map['biometricsEnabled'] ?? false,
      familyWalletId: map['familyWalletId'] ?? '',
      xp: map['xp'] ?? 0,
      level: map['level'] ?? 1,
      upiId: map['user_upi_id'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'photoUrl': photoUrl,
      'biometricsEnabled': biometricsEnabled,
      'familyWalletId': familyWalletId,
      'xp': xp,
      'level': level,
      'user_upi_id': upiId,
    };
  }
}
