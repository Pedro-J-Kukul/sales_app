// File: lib/screens/sales/sale_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import '../../models/sale.dart';
import '../../models/user.dart';
import '../../models/product.dart';
import '../../services/sale_service.dart';
import '../../utils/permissions.dart';

class SaleDetailScreen extends StatefulWidget {
  final Sale sale;
  final String currentUserRole;

  const SaleDetailScreen({
    super.key,
    required this.sale,
    required this.currentUserRole,
  });

  @override
  State<SaleDetailScreen> createState() => _SaleDetailScreenState();
}

class _SaleDetailScreenState extends State<SaleDetailScreen> {
  static final logger = Logger();

  late Sale currentSale;
  bool isEditing = false;
  bool isLoading = false;
  bool isLoadingData = true;
  String? errorMessage;

  // Form data
  final quantityController = TextEditingController();
  List<User> users = [];
  List<Product> products = [];
  User? selectedUser;
  Product? selectedProduct;

  // Permissions
  bool get canEdit => Permissions.canDeleteSales(widget.currentUserRole);
  bool get canDelete => Permissions.canDeleteSales(widget.currentUserRole);

  @override
  void initState() {
    super.initState();
    currentSale = widget.sale;
    _initializeForm();

    logger.i('Opening sale detail for: ID ${currentSale.id}');
    logger.d('Current user role: ${widget.currentUserRole}');
    logger.d('Can edit: $canEdit, Can delete: $canDelete');
  }

  @override
  void dispose() {
    quantityController.dispose();
    super.dispose();
  }

  Future<void> _initializeForm() async {
    quantityController.text = currentSale.quantity.toString();

    if (canEdit) {
      try {
        // Load users and products for dropdowns
        final futures = await Future.wait([
          SaleService.getUsers(),
          SaleService.getProducts(),
        ]);

        if (mounted) {
          setState(() {
            users = futures[0] as List<User>;
            products = futures[1] as List<Product>;

            // Find selected user and product
            selectedUser = users.firstWhere(
              (u) => u.id == currentSale.userId,
              orElse: () => users.isNotEmpty
                  ? users.first
                  : User(
                      id: currentSale.userId,
                      firstName: 'Unknown',
                      lastName: 'User',
                      email: 'unknown@example.com',
                      role: 'guest',
                      isActive: true,
                      createdAt: DateTime.now(),
                      updatedAt: DateTime.now(),
                      version: 1,
                    ),
            );

            selectedProduct = products.firstWhere(
              (p) => p.id == currentSale.productId,
              orElse: () => products.isNotEmpty
                  ? products.first
                  : Product(
                      id: currentSale.productId,
                      name: 'Unknown Product',
                      price: 0.0,
                      createdAt: DateTime.now(),
                      updatedAt: DateTime.now(),
                    ),
            );

            isLoadingData = false;
          });
        }

        logger.i(
          'Loaded ${users.length} users and ${products.length} products',
        );
      } catch (e) {
        logger.e('Failed to load dropdown data: $e');
        if (mounted) {
          setState(() {
            isLoadingData = false;
            errorMessage = 'Failed to load form data: $e';
          });
        }
      }
    } else {
      setState(() {
        isLoadingData = false;
      });
    }
  }

  Future<void> _saveSale() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final updates = <String, dynamic>{};

      final quantity = int.tryParse(quantityController.text);
      if (quantity == null || quantity <= 0) {
        throw Exception('Please enter a valid quantity');
      }

      if (selectedUser != null && selectedUser!.id != currentSale.userId) {
        updates['user_id'] = selectedUser!.id;
      }
      if (selectedProduct != null &&
          selectedProduct!.id != currentSale.productId) {
        updates['product_id'] = selectedProduct!.id;
      }
      if (quantity != currentSale.quantity) {
        updates['quantity'] = quantity;
      }

      if (updates.isEmpty) {
        setState(() {
          isEditing = false;
          isLoading = false;
        });
        return;
      }

      logger.i('Saving sale updates: $updates');

      final updatedSale = await SaleService.updateSale(currentSale.id, updates);

      if (mounted) {
        setState(() {
          currentSale = updatedSale;
          isEditing = false;
          isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sale updated successfully'),
            backgroundColor: Colors.green,
          ),
        );

        // Return true to indicate changes were made
        Navigator.pop(context, true);
      }

      logger.i('Sale saved successfully');
    } catch (e) {
      logger.e('Failed to save sale: $e');
      if (mounted) {
        setState(() {
          isLoading = false;
          errorMessage = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  Future<void> _deleteSale() async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Sale'),
          content: Text(
            'Are you sure you want to delete Sale #${currentSale.id}?  This action cannot be undone.',
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
      logger.i('Deleting sale: ${currentSale.id}');

      await SaleService.deleteSale(currentSale.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sale deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );

        // Return true to indicate changes were made
        Navigator.pop(context, true);
      }

      logger.i('Sale deleted successfully');
    } catch (e) {
      logger.e('Failed to delete sale: $e');
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
        title: Text('Sale #${currentSale.id}'),
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
              onPressed: isLoading ? null : _deleteSale,
              tooltip: 'Delete Sale',
            ),
        ],
      ),
      body: isLoadingData
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Sale info card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          CircleAvatar(
                            radius: 30,
                            backgroundColor: Colors.blue,
                            child: Text(
                              currentSale.id.toString(),
                              style: const TextStyle(
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
                          if (isEditing && users.isNotEmpty) ...[
                            DropdownButtonFormField<User>(
                              initialValue: selectedUser,
                              decoration: const InputDecoration(
                                labelText: 'Customer',
                                border: OutlineInputBorder(),
                              ),
                              items: users.map((user) {
                                return DropdownMenuItem<User>(
                                  value: user,
                                  child: Text(
                                    '${user.firstName} ${user.lastName}',
                                  ),
                                );
                              }).toList(),
                              onChanged: (User? value) {
                                setState(() {
                                  selectedUser = value;
                                });
                              },
                            ),
                            const SizedBox(height: 16),
                          ] else ...[
                            _buildInfoRow(
                              'Customer ID',
                              currentSale.userId.toString(),
                            ),
                          ],

                          if (isEditing && products.isNotEmpty) ...[
                            DropdownButtonFormField<Product>(
                              initialValue: selectedProduct,
                              decoration: const InputDecoration(
                                labelText: 'Product',
                                border: OutlineInputBorder(),
                              ),
                              items: products.map((product) {
                                return DropdownMenuItem<Product>(
                                  value: product,
                                  child: Text(
                                    '${product.name} (\$${product.price.toStringAsFixed(2)})',
                                  ),
                                );
                              }).toList(),
                              onChanged: (Product? value) {
                                setState(() {
                                  selectedProduct = value;
                                });
                              },
                            ),
                            const SizedBox(height: 16),
                          ] else ...[
                            _buildInfoRow(
                              'Product ID',
                              currentSale.productId.toString(),
                            ),
                          ],

                          TextField(
                            controller: quantityController,
                            enabled: isEditing,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Quantity',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Sale metadata card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Sale Information',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),

                          _buildInfoRow('Sale ID', currentSale.id.toString()),
                          _buildInfoRow(
                            'Sold At',
                            _formatDate(currentSale.soldAt),
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
                            onPressed: isLoading ? null : _saveSale,
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

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}
