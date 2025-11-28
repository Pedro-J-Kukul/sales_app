// File: lib/screens/profile/profile_screen.dart

import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import '../../models/user.dart';
import '../../services/auth_service.dart';
import '../../services/user_service.dart';
import '../../utils/permissions.dart';

class ProfileScreen extends StatefulWidget {
  final User user;

  const ProfileScreen({super.key, required this.user});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  static final logger = Logger();

  late User currentUser;
  bool isEditing = false;
  bool isLoading = false;
  String? errorMessage;
  String? successMessage;

  // Form controllers
  final firstNameController = TextEditingController();
  final lastNameController = TextEditingController();
  final emailController = TextEditingController();
  final currentPasswordController = TextEditingController();
  final newPasswordController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  String selectedRole = 'guest';
  bool isChangingPassword = false;

  // Permissions - only admins can edit their own role
  bool get canEditRole => Permissions.isAdmin(currentUser.role);

  @override
  void initState() {
    super.initState();
    currentUser = widget.user;
    _initializeForm();

    logger.i(
      'Opening profile for: ${currentUser.firstName} ${currentUser.lastName} (${currentUser.role})',
    );
  }

  @override
  void dispose() {
    firstNameController.dispose();
    lastNameController.dispose();
    emailController.dispose();
    currentPasswordController.dispose();
    newPasswordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  void _initializeForm() {
    firstNameController.text = currentUser.firstName;
    lastNameController.text = currentUser.lastName;
    emailController.text = currentUser.email;
    selectedRole = currentUser.role;
  }

  void _clearPasswordFields() {
    currentPasswordController.clear();
    newPasswordController.clear();
    confirmPasswordController.clear();
  }

  Future<void> _refreshProfile() async {
    try {
      logger.i('Refreshing profile data');
      final refreshedUser = await AuthService.getCurrentUser();

      if (mounted) {
        setState(() {
          currentUser = refreshedUser;
        });
        _initializeForm();
      }

      logger.i('Profile refreshed successfully');
    } catch (e) {
      logger.e('Failed to refresh profile: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to refresh profile: $e'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  Future<void> _saveProfile() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
      successMessage = null;
    });

    try {
      // Validate form
      if (firstNameController.text.trim().isEmpty ||
          lastNameController.text.trim().isEmpty ||
          emailController.text.trim().isEmpty) {
        throw Exception('Please fill in all required fields');
      }

      // Validate password if changing
      if (isChangingPassword) {
        if (newPasswordController.text.isEmpty) {
          throw Exception('New password is required');
        }
        if (newPasswordController.text != confirmPasswordController.text) {
          throw Exception('Passwords do not match');
        }
        if (newPasswordController.text.length < 8) {
          throw Exception('Password must be at least 8 characters long');
        }
      }

      final updates = <String, dynamic>{};

      // Check for changes and add to updates
      if (firstNameController.text.trim() != currentUser.firstName) {
        updates['first_name'] = firstNameController.text.trim();
      }
      if (lastNameController.text.trim() != currentUser.lastName) {
        updates['last_name'] = lastNameController.text.trim();
      }
      if (emailController.text.trim() != currentUser.email) {
        updates['email'] = emailController.text.trim();
      }

      // Only admins can change their own role
      if (canEditRole && selectedRole != currentUser.role) {
        updates['role'] = selectedRole;
      }

      // Add password if changing
      if (isChangingPassword && newPasswordController.text.isNotEmpty) {
        updates['password'] = newPasswordController.text;
      }

      if (updates.isEmpty) {
        setState(() {
          isEditing = false;
          isChangingPassword = false;
          isLoading = false;
          successMessage = 'No changes to save';
        });
        _clearPasswordFields();
        return;
      }

      logger.i(
        'Saving profile updates: ${updates.keys.toList()}',
      ); // Don't log actual values for security

      // Update via the profile endpoint
      final updatedUser = await UserService.updateProfile(updates);

      if (mounted) {
        setState(() {
          currentUser = updatedUser;
          isEditing = false;
          isChangingPassword = false;
          isLoading = false;
          successMessage = 'Profile updated successfully! ';
        });

        _initializeForm();
        _clearPasswordFields();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }

      logger.i('Profile saved successfully');
    } catch (e) {
      logger.e('Failed to save profile: $e');
      if (mounted) {
        setState(() {
          isLoading = false;
          errorMessage = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  void _toggleEdit() {
    if (isEditing) {
      // Cancel editing - reset form
      _initializeForm();
      _clearPasswordFields();
    }
    setState(() {
      isEditing = !isEditing;
      isChangingPassword = false;
      errorMessage = null;
      successMessage = null;
    });
  }

  void _togglePasswordChange() {
    setState(() {
      isChangingPassword = !isChangingPassword;
      if (!isChangingPassword) {
        _clearPasswordFields();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshProfile,
            tooltip: 'Refresh',
          ),
          IconButton(
            icon: Icon(isEditing ? Icons.close : Icons.edit),
            onPressed: isLoading ? null : _toggleEdit,
            tooltip: isEditing ? 'Cancel' : 'Edit Profile',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Profile header card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 50,
                      backgroundColor: _getRoleColor(currentUser.role),
                      child: Text(
                        currentUser.firstName[0].toUpperCase(),
                        style: const TextStyle(
                          fontSize: 40,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '${currentUser.firstName} ${currentUser.lastName}',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: _getRoleColor(currentUser.role),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        currentUser.role.toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Edit form card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Personal Information',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Messages
                    if (errorMessage != null)
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          border: Border.all(color: Colors.red),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error, color: Colors.red),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                errorMessage!,
                                style: const TextStyle(color: Colors.red),
                              ),
                            ),
                          ],
                        ),
                      ),

                    if (successMessage != null)
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          border: Border.all(color: Colors.green),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle, color: Colors.green),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                successMessage!,
                                style: const TextStyle(color: Colors.green),
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Form fields
                    TextField(
                      controller: firstNameController,
                      enabled: isEditing,
                      decoration: const InputDecoration(
                        labelText: 'First Name *',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.person),
                      ),
                    ),
                    const SizedBox(height: 16),

                    TextField(
                      controller: lastNameController,
                      enabled: isEditing,
                      decoration: const InputDecoration(
                        labelText: 'Last Name *',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.person),
                      ),
                    ),
                    const SizedBox(height: 16),

                    TextField(
                      controller: emailController,
                      enabled: isEditing,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Email *',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.email),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Role dropdown (only for admins)
                    if (canEditRole) ...[
                      DropdownButtonFormField<String>(
                        initialValue: selectedRole,
                        decoration: const InputDecoration(
                          labelText: 'Role',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.admin_panel_settings),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'admin',
                            child: Text('Admin'),
                          ),
                          DropdownMenuItem(
                            value: 'cashier',
                            child: Text('Cashier'),
                          ),
                          DropdownMenuItem(
                            value: 'guest',
                            child: Text('Guest'),
                          ),
                        ],
                        onChanged: isEditing && canEditRole
                            ? (value) {
                                if (value != null) {
                                  setState(() {
                                    selectedRole = value;
                                  });
                                }
                              }
                            : null,
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Password change section
                    if (isEditing) ...[
                      const Divider(),
                      const SizedBox(height: 16),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Change Password',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Switch(
                            value: isChangingPassword,
                            onChanged: (_) => _togglePasswordChange(),
                          ),
                        ],
                      ),

                      if (isChangingPassword) ...[
                        const SizedBox(height: 16),

                        TextField(
                          controller: newPasswordController,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: 'New Password *',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.lock_outline),
                            helperText: 'Minimum 8 characters',
                          ),
                        ),
                        const SizedBox(height: 16),

                        TextField(
                          controller: confirmPasswordController,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: 'Confirm New Password *',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.lock_outline),
                          ),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Account info card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Account Information',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),

                    _buildInfoRow('User ID', currentUser.id.toString()),
                    _buildInfoRow(
                      'Account Status',
                      currentUser.isActive ? 'Active' : 'Inactive',
                    ),
                    _buildInfoRow(
                      'Member Since',
                      _formatDate(currentUser.createdAt),
                    ),
                    if (currentUser.updatedAt != null)
                      _buildInfoRow(
                        'Last Updated',
                        _formatDate(currentUser.updatedAt!),
                      ),
                    _buildInfoRow(
                      'Account Version',
                      currentUser.version.toString(),
                    ),
                  ],
                ),
              ),
            ),

            if (isEditing) ...[
              const SizedBox(height: 24),

              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: isLoading ? null : _saveProfile,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Save Changes'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: isLoading ? null : _toggleEdit,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w400),
            ),
          ),
        ],
      ),
    );
  }

  Color _getRoleColor(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
        return Colors.red;
      case 'cashier':
        return Colors.blue;
      case 'guest':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}
