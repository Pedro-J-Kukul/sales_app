// File: lib/screens/products/product_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import '../../models/product.dart';
import '../../services/product_service.dart';
import '../../utils/permissions.dart';

class ProductDetailScreen extends StatefulWidget {
  final Product? product; // null means create mode
  final String currentUserRole;

  const ProductDetailScreen({
    super.key,
    required this.product,
    required this.currentUserRole,
  });

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  static final logger = Logger();

  Product? currentProduct;
  bool isEditing = false;
  bool isLoading = false;
  String? errorMessage;

  // Form controllers
  final nameController = TextEditingController();
  final priceController = TextEditingController();

  // Permissions
  bool get canEdit => Permissions.canManageProducts(widget.currentUserRole);
  bool get canDelete => Permissions.canManageProducts(widget.currentUserRole);
  bool get isCreateMode => widget.product == null;

  @override
  void initState() {
    super.initState();
    currentProduct = widget.product;

    if (isCreateMode) {
      isEditing = true; // Create mode starts in editing
      logger.i('Opening product create screen');
    } else {
      _initializeForm();
      logger.i('Opening product detail for: ${currentProduct!.name}');
    }

    logger.d('Current user role: ${widget.currentUserRole}');
    logger.d('Can edit: $canEdit, Can delete: $canDelete');
  }

  @override
  void dispose() {
    nameController.dispose();
    priceController.dispose();
    super.dispose();
  }

  void _initializeForm() {
    if (currentProduct != null) {
      nameController.text = currentProduct!.name;
      priceController.text = currentProduct!.price.toString();
    }
  }

  Future<void> _saveProduct() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      // Validate form
      if (nameController.text.trim().isEmpty) {
        throw Exception('Product name is required');
      }

      final price = double.tryParse(priceController.text);
      if (price == null || price < 0) {
        throw Exception('Please enter a valid price');
      }

      Product savedProduct;

      if (isCreateMode) {
        // Create new product
        logger.i('Creating new product: ${nameController.text}');

        savedProduct = await ProductService.createProduct(
          name: nameController.text.trim(),
          price: price,
        );

        logger.i('Product created successfully: ${savedProduct.name}');
      } else {
        // Update existing product
        final updates = <String, dynamic>{};

        if (nameController.text.trim() != currentProduct!.name) {
          updates['name'] = nameController.text.trim();
        }
        if (price != currentProduct!.price) {
          updates['price'] = price;
        }

        if (updates.isEmpty) {
          setState(() {
            isEditing = false;
            isLoading = false;
          });
          return;
        }

        logger.i('Saving product updates: $updates');

        savedProduct = await ProductService.updateProduct(
          currentProduct!.id,
          updates,
        );

        logger.i('Product updated successfully');
      }

      if (mounted) {
        setState(() {
          currentProduct = savedProduct;
          isEditing = false;
          isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isCreateMode
                  ? 'Product created successfully'
                  : 'Product updated successfully',
            ),
            backgroundColor: Colors.green,
          ),
        );

        // Return true to indicate changes were made
        Navigator.pop(context, true);
      }
    } catch (e) {
      logger.e('Failed to save product: $e');
      if (mounted) {
        setState(() {
          isLoading = false;
          errorMessage = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  Future<void> _deleteProduct() async {
    if (isCreateMode) return;

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Product'),
          content: Text(
            'Are you sure you want to delete "${currentProduct!.name}"?  This action cannot be undone.',
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
      logger.i('Deleting product: ${currentProduct!.name}');

      await ProductService.deleteProduct(currentProduct!.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Product deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );

        // Return true to indicate changes were made
        Navigator.pop(context, true);
      }

      logger.i('Product deleted successfully');
    } catch (e) {
      logger.e('Failed to delete product: $e');
      if (mounted) {
        setState(() {
          isLoading = false;
          errorMessage = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  void _toggleEdit() {
    if (isEditing && !isCreateMode) {
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
    final title = isCreateMode
        ? 'Create Product'
        : currentProduct?.name ?? 'Product Detail';

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          if (!isCreateMode && canEdit)
            IconButton(
              icon: Icon(isEditing ? Icons.close : Icons.edit),
              onPressed: isLoading ? null : _toggleEdit,
              tooltip: isEditing ? 'Cancel' : 'Edit',
            ),
          if (!isCreateMode && canDelete && !isEditing)
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: isLoading ? null : _deleteProduct,
              tooltip: 'Delete Product',
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product form card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    if (!isCreateMode) ...[
                      CircleAvatar(
                        radius: 40,
                        backgroundColor: Colors.orange,
                        child: Text(
                          currentProduct!.name[0].toUpperCase(),
                          style: const TextStyle(
                            fontSize: 32,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

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
                      controller: nameController,
                      enabled: isEditing,
                      decoration: const InputDecoration(
                        labelText: 'Product Name *',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.inventory_2),
                      ),
                    ),
                    const SizedBox(height: 16),

                    TextField(
                      controller: priceController,
                      enabled: isEditing,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Price *',
                        prefixText: '\$',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.attach_money),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            if (!isCreateMode) ...[
              const SizedBox(height: 16),

              // Product info card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Product Information',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),

                      _buildInfoRow(
                        'Product ID',
                        currentProduct!.id.toString(),
                      ),
                      _buildInfoRow(
                        'Created',
                        _formatDate(currentProduct!.createdAt),
                      ),
                      _buildInfoRow(
                        'Last Updated',
                        _formatDate(currentProduct!.updatedAt),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            if (isEditing) ...[
              const SizedBox(height: 24),

              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: isLoading ? null : _saveProduct,
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
                          : Text(
                              isCreateMode ? 'Create Product' : 'Save Changes',
                            ),
                    ),
                  ),
                  if (!isCreateMode) ...[
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
