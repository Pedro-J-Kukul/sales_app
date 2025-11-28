// File: lib/screens/users/user_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import '../../models/user.dart';
import '../../services/user_service.dart';
import '../../utils/permissions.dart';

class UserDetailScreen extends StatefulWidget {
  final User user;
  final String currentUserRole;

  const UserDetailScreen({
    super.key,
    required this.user,
    required this.currentUserRole,
  });

  @override
  State<UserDetailScreen> createState() => _UserDetailScreenState();
}

class _UserDetailScreenState extends State<UserDetailScreen> {
  static final logger = Logger();

  late User currentUser;
  bool isEditing = false;
  bool isLoading = false;
  String? errorMessage;

  // Form controllers
  final firstNameController = TextEditingController();
  final lastNameController = TextEditingController();
  final emailController = TextEditingController();
  String selectedRole = 'guest';
  bool selectedActiveStatus = true;

  // Permissions
  bool get canEdit => Permissions.canManageUsers(widget.currentUserRole);
  bool get canDelete => Permissions.isAdmin(widget.currentUserRole);
  bool get canEditRole => Permissions.isAdmin(widget.currentUserRole);
  bool get canEditActiveStatus => Permissions.isAdmin(widget.currentUserRole);

  @override
  void initState() {
    super.initState();
    currentUser = widget.user;
    _initializeForm();

    logger.i(
      'Opening user detail for: ${currentUser.firstName} ${currentUser.lastName}',
    );
    logger.d('Current user role: ${widget.currentUserRole}');
    logger.d(
      'Can edit: $canEdit, Can delete: $canDelete, Can edit role: $canEditRole',
    );
  }

  @override
  void dispose() {
    firstNameController.dispose();
    lastNameController.dispose();
    emailController.dispose();
    super.dispose();
  }

  void _initializeForm() {
    firstNameController.text = currentUser.firstName;
    lastNameController.text = currentUser.lastName;
    emailController.text = currentUser.email;
    selectedRole = currentUser.role;
    selectedActiveStatus = currentUser.isActive;
  }

  Future<void> _saveUser() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final updates = <String, dynamic>{};

      // Only include changed fields
      if (firstNameController.text != currentUser.firstName) {
        updates['first_name'] = firstNameController.text;
      }
      if (lastNameController.text != currentUser.lastName) {
        updates['last_name'] = lastNameController.text;
      }
      if (emailController.text != currentUser.email) {
        updates['email'] = emailController.text;
      }

      // Only admins can change role and active status
      if (canEditRole && selectedRole != currentUser.role) {
        updates['role'] = selectedRole;
      }
      if (canEditActiveStatus && selectedActiveStatus != currentUser.isActive) {
        updates['is_active'] = selectedActiveStatus;
      }

      if (updates.isEmpty) {
        setState(() {
          isEditing = false;
          isLoading = false;
        });
        return;
      }

      logger.i('Saving user updates: $updates');

      final updatedUser = await UserService.updateUser(currentUser.id, updates);

      if (mounted) {
        setState(() {
          currentUser = updatedUser;
          isEditing = false;
          isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('User updated successfully'),
            backgroundColor: Colors.green,
          ),
        );

        // Return true to indicate changes were made
        Navigator.pop(context, true);
      }

      logger.i('User saved successfully');
    } catch (e) {
      logger.e('Failed to save user: $e');
      if (mounted) {
        setState(() {
          isLoading = false;
          errorMessage = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  Future<void> _deleteUser() async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete User'),
          content: Text(
            'Are you sure you want to delete ${currentUser.firstName} ${currentUser.lastName}? This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      logger.i(
        'Deleting user: ${currentUser.firstName} ${currentUser.lastName}',
      );

      await UserService.deleteUser(currentUser.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('User deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );

        // Return true to indicate changes were made
        Navigator.pop(context, true);
      }

      logger.i('User deleted successfully');
    } catch (e) {
      logger.e('Failed to delete user: $e');
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
    }
    setState(() {
      isEditing = !isEditing;
      errorMessage = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${currentUser.firstName} ${currentUser.lastName}'),
        actions: [
          if (canEdit)
            IconButton(
              icon: Icon(isEditing ? Icons.close : Icons.edit),
              onPressed: isLoading ? null : _toggleEdit,
              tooltip: isEditing ? 'Cancel' : 'Edit',
            ),
          if (canDelete && !isEditing)
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: isLoading ? null : _deleteUser,
              tooltip: 'Delete User',
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // User info card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 40,
                      backgroundColor: _getRoleColor(currentUser.role),
                      child: Text(
                        currentUser.firstName[0].toUpperCase(),
                        style: const TextStyle(
                          fontSize: 32,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

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

                    // Form fields
                    TextField(
                      controller: firstNameController,
                      enabled: isEditing,
                      decoration: const InputDecoration(
                        labelText: 'First Name',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),

                    TextField(
                      controller: lastNameController,
                      enabled: isEditing,
                      decoration: const InputDecoration(
                        labelText: 'Last Name',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),

                    TextField(
                      controller: emailController,
                      enabled: isEditing,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Role dropdown (only admins can edit)
                    DropdownButtonFormField<String>(
                      initialValue: selectedRole,
                      decoration: InputDecoration(
                        labelText: 'Role',
                        border: const OutlineInputBorder(),
                        suffixIcon: canEditRole
                            ? null
                            : const Icon(Icons.lock, color: Colors.grey),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'admin', child: Text('Admin')),
                        DropdownMenuItem(
                          value: 'cashier',
                          child: Text('Cashier'),
                        ),
                        DropdownMenuItem(value: 'guest', child: Text('Guest')),
                      ],
                      onChanged: (isEditing && canEditRole)
                          ? (value) {
                              if (value != null) {
                                setState(() {
                                  selectedRole = value;
                                });
                              }
                            }
                          : null, // <--- Passing null here is what actually "locks" it
                    ),
                    const SizedBox(height: 16),

                    // Active status (only admins can edit)
                    SwitchListTile(
                      title: const Text('Active'),
                      value: selectedActiveStatus,
                      onChanged: (isEditing && canEditActiveStatus)
                          ? (value) {
                              setState(() {
                                selectedActiveStatus = value;
                              });
                            }
                          : null,
                      secondary: Icon(
                        selectedActiveStatus
                            ? Icons.check_circle
                            : Icons.cancel,
                        color: selectedActiveStatus ? Colors.green : Colors.red,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // User metadata card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'User Information',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),

                    _buildInfoRow('User ID', currentUser.id.toString()),
                    _buildInfoRow(
                      'Created',
                      _formatDate(currentUser.createdAt),
                    ),
                    if (currentUser.updatedAt != null)
                      _buildInfoRow(
                        'Last Updated',
                        _formatDate(currentUser.updatedAt!),
                      ),
                    _buildInfoRow('Version', currentUser.version.toString()),
                  ],
                ),
              ),
            ),

            if (isEditing) ...[
              const SizedBox(height: 24),

              // Save/Cancel buttons
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: isLoading ? null : _saveUser,
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
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(child: Text(value)),
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
