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

  // Check if user can view sales (cashiers and admins only)
  static bool canViewSales(String role) {
    return isCashierOrAbove(role);
  }

  // Check if user can create sales (cashiers and admins)
  static bool canCreateSales(String role) {
    return isCashierOrAbove(role);
  }

  // Check if user can edit sales (admins only)
  static bool canEditSales(String role) {
    return isAdmin(role);
  }

  // Check if user can delete sales (admins only)
  static bool canDeleteSales(String role) {
    return isAdmin(role);
  }

  // USER PERMISSIONS

  // Check if user can manage users
  static bool canManageUsers(String role) {
    return isCashierOrAbove(role);
  }

  // PRODUCT PERMISSIONS

  // Check if user can manage products
  static bool canManageProducts(String role) {
    return isCashierOrAbove(role);
  }

  // OTHER PERMISSIONS

  // Check if user can view reports
  static bool canViewReports(String role) {
    return isCashierOrAbove(role);
  }

  // Check if user can delete other users
  static bool canDeleteUsers(String role) {
    return isAdmin(role);
  }

  // Check if user can edit user roles
  static bool canEditUserRoles(String role) {
    return isAdmin(role);
  }

  // Check if user can activate/deactivate users
  static bool canToggleUserStatus(String role) {
    return isAdmin(role);
  }
}
