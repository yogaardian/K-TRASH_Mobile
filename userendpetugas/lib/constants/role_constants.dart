class RoleConstants {
  // User Roles
  static const String user = 'user';
  static const String driver = 'driver';
  static const String petugas = 'petugas';
  static const String admin = 'admin';

  // Role lists
  static const List<String> allRoles = [user, driver, petugas, admin];
  static const List<String> mobileRoles = [user, driver, petugas];
  static const List<String> driversRoles = [driver, petugas];

  // Check if role is valid
  static bool isValidRole(String role) {
    return allRoles.contains(role);
  }

  // Check if role is driver or petugas
  static bool isDriver(String role) {
    return driversRoles.contains(role);
  }

  // Check if role is user
  static bool isUser(String role) {
    return role == user;
  }

  // Check if role is admin
  static bool isAdmin(String role) {
    return role == admin;
  }
}
