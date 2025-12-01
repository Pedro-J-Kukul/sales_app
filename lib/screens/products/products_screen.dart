import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:sales_app/models/product.dart';
import 'package:sales_app/utils/api_client.dart';
import 'package:sales_app/services/auth_service.dart';
import 'package:sales_app/utils/permissions.dart';
import 'package:sales_app/widgets/custom_list_card.dart';
import 'package:sales_app/widgets/custom_pagination.dart';
import 'package:sales_app/widgets/custom_state_views.dart';
import 'product_detail_screen.dart';

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  static final logger = Logger();

  List<Product> products = [];
  Map<String, dynamic> metadata = {};
  bool isLoading = true;
  String? errorMessage;
  String? currentUserRole;

  // Search and filter variables
  final searchController = TextEditingController();
  final minPriceController = TextEditingController();
  final maxPriceController = TextEditingController();
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
    minPriceController.dispose();
    maxPriceController.dispose();
    super.dispose();
  }

  Future<void> _initializeScreen() async {
    try {
      // Get current user role for permission checks
      currentUserRole = await AuthService.getCurrentUserRole();
      logger.i('Current user role: $currentUserRole');

      // Load initial products
      await _loadProducts();
    } catch (e) {
      logger.e('Failed to initialize products screen: $e');
      if (mounted) {
        setState(() {
          errorMessage = 'Failed to load products: $e';
          isLoading = false;
        });
      }
    }
  }

  Future<void> _loadProducts({bool showLoading = true}) async {
    if (showLoading) {
      setState(() {
        isLoading = true;
        errorMessage = null;
      });
    }

    try {
      logger.i(
        'Loading products - Page: $currentPage, Search: ${searchController.text}',
      );

      double? minPrice;
      double? maxPrice;

      if (minPriceController.text.isNotEmpty) {
        minPrice = double.tryParse(minPriceController.text);
      }
      if (maxPriceController.text.isNotEmpty) {
        maxPrice = double.tryParse(maxPriceController.text);
      }

      final result = await ApiClient.getProducts(
        search: searchController.text.isEmpty ? null : searchController.text,
        minPrice: minPrice,
        maxPrice: maxPrice,
        page: currentPage,
        pageSize: pageSize,
      );

      if (mounted) {
        setState(() {
          products = result['products'] as List<Product>;
          metadata = result['metadata'] as Map<String, dynamic>;
          isLoading = false;
          errorMessage = null;
        });
      }

      logger.i('Loaded ${products.length} products successfully');
    } catch (e) {
      logger.e('Failed to load products: $e');
      if (mounted) {
        setState(() {
          isLoading = false;
          errorMessage = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  Future<void> _refreshProducts() async {
    currentPage = 1;
    await _loadProducts(showLoading: false);
  }

  void _onSearchChanged() {
    // Reset to first page when searching
    currentPage = 1;
    _loadProducts();
  }

  void _onProductTap(Product product) {
    logger.i('Opening product details for: ${product.name}');

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProductDetailScreen(
          product: product,
          currentUserRole: currentUserRole ?? 'guest',
        ),
      ),
    ).then((result) {
      // Refresh products list if product was updated/deleted
      if (result == true) {
        _refreshProducts();
      }
    });
  }

  void _createProduct() {
    logger.i('Opening create product screen');

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProductDetailScreen(
          product: null, // null means create mode
          currentUserRole: currentUserRole ?? 'guest',
        ),
      ),
    ).then((result) {
      // Refresh products list if product was created
      if (result == true) {
        _refreshProducts();
      }
    });
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
                labelText: 'Search products',
                hintText: 'Search by name...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => _onSearchChanged(),
            ),
            const SizedBox(height: 16),

            // Price filters
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: minPriceController,
                    decoration: const InputDecoration(
                      labelText: 'Min Price',
                      prefixText: '\$',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    onChanged: (_) => _onSearchChanged(),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    controller: maxPriceController,
                    decoration: const InputDecoration(
                      labelText: 'Max Price',
                      prefixText: '\$',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    onChanged: (_) => _onSearchChanged(),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductCard(Product product) {
    return CustomListCard(
      leading: CircleAvatar(
        backgroundColor: Colors.orange,
        child: Text(
          product.name[0].toUpperCase(),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      title: Text(product.name),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '\$${product.price.toStringAsFixed(2)}',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.green,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Created: ${_formatDate(product.createdAt)}',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
        ],
      ),
      onTap: () => _onProductTap(product),
    );
  }

  void _changePage(int page) {
    setState(() {
      currentPage = page;
    });
    _loadProducts();
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final canManageProducts = Permissions.canManageProducts(
      currentUserRole ?? 'guest',
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Products'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshProducts,
            tooltip: 'Refresh',
          ),
        ],
      ),
      floatingActionButton: canManageProducts
          ? FloatingActionButton(
              onPressed: _createProduct,
              tooltip: 'Add Product',
              child: const Icon(Icons.add),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: _refreshProducts,
        child: Column(
          children: [
            _buildSearchAndFilters(),

            Expanded(
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : errorMessage != null
                  ? CustomErrorView(
                      message: errorMessage!,
                      onRetry: _refreshProducts,
                    )
                  : products.isEmpty
                  ? const CustomEmptyView(
                      message: 'No products found',
                      icon: Icons.inventory,
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: products.length,
                      itemBuilder: (context, index) =>
                          _buildProductCard(products[index]),
                    ),
            ),
            if (metadata.isNotEmpty)
              CustomPagination(
                currentPage: metadata['current_page'] ?? 1,
                totalPages: metadata['total_pages'] ?? 1,
                onPageChanged: _changePage,
              ),
          ],
        ),
      ),
    );
  }
}
