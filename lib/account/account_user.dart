/// The signed-in account, as the server describes it.
class AccountUser {
  const AccountUser({required this.id, required this.email, this.name, required this.hasPassword});

  factory AccountUser.fromJson(Map<String, dynamic> json) => AccountUser(
    id: json['id'] as String,
    email: json['email'] as String,
    name: json['name'] as String?,
    hasPassword: json['hasPassword'] as bool? ?? true,
  );

  Map<String, Object?> toJson() => {'id': id, 'email': email, 'name': name, 'hasPassword': hasPassword};

  final String id;
  final String email;
  final String? name;

  /// False for a Google-only account: deleting it then asks for no password.
  final bool hasPassword;
}
