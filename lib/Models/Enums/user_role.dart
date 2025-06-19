// lib/models/enums/user_role.dart
enum UserRole {
  admin('admin'),
  customer('customer'),
  store('store'),
  driver('driver');

  const UserRole(this.value);
  final String value;

  static UserRole fromString(String value) {
    return UserRole.values.firstWhere(
          (role) => role.value == value,
      orElse: () => UserRole.customer,
    );
  }
}