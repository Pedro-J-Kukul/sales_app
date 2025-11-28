// File: lib/screens/sales/sales_screen.dart

import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:sales_app/screens/sales/sale_list_screen.dart';
import '../../models/user.dart';
import '../../models/product.dart';
import '../../services/sale_service.dart';
import '../../services/auth_service.dart';
import '../../utils/permissions.dart';

class SalesScreen extends StatefulWidget {
  const SalesScreen({super.key});

  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> {
  static final logger = Logger();

  // Form controllers and state
  final quantityController = TextEditingController();
  List<User> cashiers = []; // Staff members who can perform sales
  List<Product> products = [];
  User? selectedCashier;
  Product? selectedProduct;
  User? currentUser; // Current logged-in user

  bool isLoading = false;
  bool isLoadingData = true;
  String? errorMessage;
  String? successMessage;
  String? currentUserRole;

  @override
  void initState() {
    super.initState();
    _initializeScreen();
  }

  @override
  void dispose() {
    quantityController.dispose();
    super.dispose();
  }

  Future<void> _initializeScreen() async {
    try {
      // Get current user and role
      currentUserRole = await AuthService.getCurrentUserRole();
      currentUser = await AuthService.getCurrentUser();
      logger.i(
        'Current user: ${currentUser?.firstName} ${currentUser?.lastName} ($currentUserRole)',
      );

      // Check if user can access sales at all
      if (!Permissions.canViewSales(currentUserRole ?? 'guest')) {
        throw Exception('You do not have permission to access sales');
      }

      // Check if user can create sales
      if (!Permissions.canCreateSales(currentUserRole ?? 'guest')) {
        throw Exception('You do not have permission to create sales');
      }

      // Load cashiers and products for dropdowns
      await _loadDropdownData();
    } catch (e) {
      logger.e('Failed to initialize sales screen: $e');
      if (mounted) {
        setState(() {
          isLoadingData = false;
          errorMessage = 'Failed to initialize: $e';
        });
      }
    }
  }

  Future<void> _loadDropdownData() async {
    try {
      logger.i('Loading dropdown data');

      final futures = await Future.wait([
        SaleService.getUsers(), // Get all users (potential cashiers)
        SaleService.getProducts(),
      ]);

      if (mounted) {
        setState(() {
          // Filter users to only show staff/cashiers/admins (not guests)
          final allUsers = futures[0] as List<User>;
          cashiers = allUsers
              .where((user) => user.role == 'admin' || user.role == 'cashier')
              .toList();

          products = futures[1] as List<Product>;

          // Auto-select and LOCK current user as the cashier
          if (currentUser != null &&
              cashiers.any((c) => c.id == currentUser!.id)) {
            selectedCashier = cashiers.firstWhere(
              (c) => c.id == currentUser!.id,
            );
          } else if (currentUser != null) {
            // If current user is not in cashiers list, add them (shouldn't happen but safety check)
            selectedCashier = currentUser;
            if (!cashiers.contains(currentUser)) {
              cashiers.add(currentUser!);
            }
          }

          isLoadingData = false;
        });
      }

      logger.i(
        'Loaded ${cashiers.length} cashiers and ${products.length} products',
      );
      logger.i(
        'Current user role: ${currentUser?.role}, Can change cashier: $canChangeCashier',
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
  }

  // Add this getter to determine if user can change cashier
  bool get canChangeCashier {
    // Only admins can select different cashiers
    // Cashiers are locked to themselves
    return currentUserRole == 'admin';
  }

  Future<void> _createSale() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
      successMessage = null;
    });

    try {
      // Validate form
      if (selectedCashier == null) {
        throw Exception('Please select the cashier performing this sale');
      }
      if (selectedProduct == null) {
        throw Exception('Please select a product');
      }

      final quantity = int.tryParse(quantityController.text);
      if (quantity == null || quantity <= 0) {
        throw Exception('Please enter a valid quantity');
      }

      // Store values before making API call (to avoid null reference after state changes)
      final cashierName =
          '${selectedCashier!.firstName} ${selectedCashier!.lastName}';
      final productName = selectedProduct!.name;
      final productPrice = selectedProduct!.price;
      final totalAmount = productPrice * quantity;

      logger.i(
        'Creating sale: Cashier ${selectedCashier!.id}, Product ${selectedProduct!.id}, Qty $quantity',
      );

      final sale = await SaleService.createSale(
        userId: selectedCashier!.id, // This is the cashier ID
        productId: selectedProduct!.id,
        quantity: quantity,
      );

      logger.i('Sale creation completed successfully: ${sale.toString()}');

      if (mounted) {
        setState(() {
          isLoading = false;
          successMessage =
              'Sale #${sale.id} created successfully!\nCashier: $cashierName\nProduct: $productName\nQuantity: $quantity\nTotal: \$${totalAmount.toStringAsFixed(2)}';
        });

        // Clear form but keep cashier selected for convenience
        setState(() {
          selectedProduct = null;
          quantityController.clear();
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Sale recorded!  Total: \$${totalAmount.toStringAsFixed(2)}',
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }

      logger.i('Sale created successfully: ID ${sale.id}');
    } catch (e, stackTrace) {
      logger.e('Failed to create sale: $e');
      logger.e('Stack trace: $stackTrace');

      if (mounted) {
        setState(() {
          isLoading = false;
          errorMessage = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }
  // File: lib/screens/sales/sales_screen.dart - Fix _clearForm method

  void _clearForm() {
    setState(() {
      // selectedCashier = null;  // Don't clear cashier - keep for convenience
      selectedProduct = null;
      quantityController.clear();
      errorMessage = null;
      successMessage = null;
    });
  }

  void _openSalesList() {
    logger.i('Opening sales list screen');

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            SalesListScreen(currentUserRole: currentUserRole ?? 'guest'),
      ),
    );
  }

  double _calculateTotal() {
    if (selectedProduct == null || quantityController.text.isEmpty) {
      return 0.0;
    }

    final quantity = int.tryParse(quantityController.text) ?? 0;
    if (quantity <= 0) return 0.0;

    return selectedProduct!.price * quantity;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Record Sale'),
        actions: [
          IconButton(
            icon: const Icon(Icons.list),
            onPressed: _openSalesList,
            tooltip: 'View Sales History',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDropdownData,
            tooltip: 'Refresh Data',
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
                  // Header card
                  Card(
                    color: Colors.blue.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          const Icon(
                            Icons.point_of_sale,
                            size: 48,
                            color: Colors.blue,
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Record New Sale',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Record a sale transaction in the system',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ],
                      ),
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

                  // Form card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Sale Details',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Cashier dropdown
                          DropdownButtonFormField<User>(
                            initialValue: selectedCashier,
                            decoration: const InputDecoration(
                              labelText: 'Cashier/Staff *',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.person_outline),
                              helperText: 'Who is performing this sale?',
                            ),
                            hint: const Text('Select cashier'),
                            items: cashiers.map((user) {
                              final isCurrentUser = currentUser?.id == user.id;
                              return DropdownMenuItem<User>(
                                value: user,
                                child: Row(
                                  children: [
                                    Text('${user.firstName} ${user.lastName}'),
                                    if (isCurrentUser) ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.blue,
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: const Text(
                                          'YOU',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              );
                            }).toList(),
                            onChanged: canChangeCashier
                                ? (User? value) {
                                    setState(() {
                                      selectedCashier = value;
                                    });
                                  }
                                : null, // Disable dropdown for cashiers
                          ),
                          const SizedBox(height: 16),

                          // Product dropdown
                          DropdownButtonFormField<Product>(
                            initialValue: selectedProduct,
                            decoration: const InputDecoration(
                              labelText: 'Product *',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.inventory),
                              helperText: 'What product is being sold?',
                            ),
                            hint: const Text('Select product'),
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

                          // Quantity field
                          TextField(
                            controller: quantityController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Quantity *',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.numbers),
                              helperText: 'How many units being sold?',
                            ),
                            onChanged: (_) => setState(
                              () {},
                            ), // Trigger rebuild for total calculation
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Total card
                  if (selectedProduct != null &&
                      quantityController.text.isNotEmpty)
                    Card(
                      color: Colors.green.shade50,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Sale Total:',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '\$${_calculateTotal().toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  const SizedBox(height: 24),

                  // Action buttons
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: isLoading ? null : _createSale,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
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
                              : const Text(
                                  'Record Sale',
                                  style: TextStyle(fontSize: 16),
                                ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: isLoading ? null : _clearForm,
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: const Text(
                            'Clear Form',
                            style: TextStyle(fontSize: 16),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }
}
