// File: lib/utils/permissions.dart

class Permissions {
  // Role constants
  static const String roleAdmin = 'admin';
  static const String roleCashier = 'cashier';
  static const String roleGuest = 'guest';

  // Check if user is admin
  static bool isAdmin(String role) {
    return role.toLowerCase() == roleAdmin;
  }

  // Check if user is cashier or above
  static bool isCashierOrAbove(String role) {
    final lowerRole = role.toLowerCase();
    return lowerRole == roleAdmin || lowerRole == roleCashier;
  }

  // SALES PERMISSIONS
  static bool canViewSales(String role) => isCashierOrAbove(role);
  static bool canCreateSales(String role) => isCashierOrAbove(role);
  static bool canEditSales(String role) => isAdmin(role);
  static bool canDeleteSales(String role) => isAdmin(role);

  // PRODUCT PERMISSIONS
  static bool canViewProducts(String role) => true; // Everyone
  static bool canCreateProducts(String role) => isCashierOrAbove(role);
  static bool canEditProducts(String role) => isAdmin(role);
  static bool canDeleteProducts(String role) => isAdmin(role);

  // Deprecated: Use granular permissions instead
  static bool canManageProducts(String role) => isCashierOrAbove(role);

  // USER PERMISSIONS
  static bool canViewUsers(String role) => isCashierOrAbove(role);
  static bool canCreateUsers(String role) => isAdmin(role);
  static bool canEditUsers(String role) => isAdmin(role);
  static bool canDeleteUsers(String role) => isAdmin(role);

  // Deprecated: Use granular permissions instead
  static bool canManageUsers(String role) => isAdmin(role);

  // OTHER PERMISSIONS
  static bool canViewReports(String role) => isCashierOrAbove(role);
  static bool canEditUserRoles(String role) => isAdmin(role);
  static bool canToggleUserStatus(String role) => isAdmin(role);
}
