// File: lib/screens/users/users_screen.dart

import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import '../../models/user.dart';
import '../../services/user_service.dart';
import '../../services/auth_service.dart';
import 'user_detail_screen.dart';

class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  static final logger = Logger();

  List<User> users = [];
  Map<String, dynamic> metadata = {};
  bool isLoading = true;
  String? errorMessage;
  String? currentUserRole;

  // Search and filter variables
  final searchController = TextEditingController();
  String? selectedRole;
  bool? selectedActiveStatus;
  int currentPage = 1;
  final int pageSize = 20;

  @override
  void initState() {
    super.initState();
    _initializeScreen();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<void> _initializeScreen() async {
    try {
      // Get current user role for permission checks
      currentUserRole = await AuthService.getCurrentUserRole();
      logger.i('Current user role: $currentUserRole');

      // Load initial users
      await _loadUsers();
    } catch (e) {
      logger.e('Failed to initialize users screen: $e');
      if (mounted) {
        setState(() {
          errorMessage = 'Failed to load users: $e';
          isLoading = false;
        });
      }
    }
  }

  Future<void> _loadUsers({bool showLoading = true}) async {
    if (showLoading) {
      setState(() {
        isLoading = true;
        errorMessage = null;
      });
    }

    try {
      logger.i(
        'Loading users - Page: $currentPage, Search: ${searchController.text}',
      );

      final result = await UserService.getUsers(
        search: searchController.text.isEmpty ? null : searchController.text,
        role: selectedRole,
        isActive: selectedActiveStatus,
        page: currentPage,
        pageSize: pageSize,
      );

      if (mounted) {
        setState(() {
          users = result['users'] as List<User>;
          metadata = result['metadata'] as Map<String, dynamic>;
          isLoading = false;
          errorMessage = null;
        });
      }

      logger.i('Loaded ${users.length} users successfully');
    } catch (e) {
      logger.e('Failed to load users: $e');
      if (mounted) {
        setState(() {
          isLoading = false;
          errorMessage = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  Future<void> _refreshUsers() async {
    currentPage = 1;
    await _loadUsers(showLoading: false);
  }

  void _onSearchChanged() {
    // Reset to first page when searching
    currentPage = 1;
    _loadUsers();
  }

  void _onUserTap(User user) {
    logger.i('Opening user details for: ${user.firstName} ${user.lastName}');

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => UserDetailScreen(
          user: user,
          currentUserRole: currentUserRole ?? 'guest',
        ),
      ),
    ).then((result) {
      // Refresh users list if user was updated/deleted
      if (result == true) {
        _refreshUsers();
      }
    });
  }

  void _changePage(int page) {
    setState(() {
      currentPage = page;
    });
    _loadUsers();
  }

  Widget _buildSearchAndFilters() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Search field
            TextField(
              controller: searchController,
              decoration: const InputDecoration(
                labelText: 'Search users',
                hintText: 'Search by name.. .',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => _onSearchChanged(),
            ),
            const SizedBox(height: 16),

            // Filters row
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: selectedRole,
                    decoration: const InputDecoration(
                      labelText: 'Role',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: null, child: Text('All Roles')),
                      DropdownMenuItem(value: 'admin', child: Text('Admin')),
                      DropdownMenuItem(
                        value: 'cashier',
                        child: Text('Cashier'),
                      ),
                      DropdownMenuItem(value: 'guest', child: Text('Guest')),
                    ],
                    onChanged: (value) {
                      setState(() {
                        selectedRole = value;
                      });
                      _onSearchChanged();
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: DropdownButtonFormField<bool>(
                    initialValue: selectedActiveStatus,
                    decoration: const InputDecoration(
                      labelText: 'Status',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: null, child: Text('All Status')),
                      DropdownMenuItem(value: true, child: Text('Active')),
                      DropdownMenuItem(value: false, child: Text('Inactive')),
                    ],
                    onChanged: (value) {
                      setState(() {
                        selectedActiveStatus = value;
                      });
                      _onSearchChanged();
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserCard(User user) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _getRoleColor(user.role),
          child: Text(
            user.firstName[0].toUpperCase(),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text('${user.firstName} ${user.lastName}'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(user.email),
            const SizedBox(height: 4),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: _getRoleColor(user.role),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    user.role.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: user.isActive ? Colors.green : Colors.red,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    user.isActive ? 'ACTIVE' : 'INACTIVE',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => _onUserTap(user),
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

  Widget _buildPagination() {
    if (metadata.isEmpty) return const SizedBox.shrink();

    final totalPages = metadata['total_pages'] ?? 1;
    final currentPageMeta = metadata['current_page'] ?? 1;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Page $currentPageMeta of $totalPages'),
            Row(
              children: [
                IconButton(
                  onPressed: currentPage > 1
                      ? () => _changePage(currentPage - 1)
                      : null,
                  icon: const Icon(Icons.chevron_left),
                ),
                IconButton(
                  onPressed: currentPage < totalPages
                      ? () => _changePage(currentPage + 1)
                      : null,
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Users Management'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshUsers,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshUsers,
        child: Column(
          children: [
            _buildSearchAndFilters(),

            Expanded(
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : errorMessage != null
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.error, size: 64, color: Colors.red[300]),
                          const SizedBox(height: 16),
                          Text(
                            errorMessage!,
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.red[700]),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _refreshUsers,
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    )
                  : users.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.people, size: 64, color: Colors.grey),
                          SizedBox(height: 16),
                          Text(
                            'No users found',
                            style: TextStyle(fontSize: 18, color: Colors.grey),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: users.length,
                      itemBuilder: (context, index) =>
                          _buildUserCard(users[index]),
                    ),
            ),

            _buildPagination(),
          ],
        ),
      ),
    );
  }
}
