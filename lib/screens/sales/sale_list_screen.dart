// File: lib/screens/sales/sales_list_screen.dart

import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:sales_app/models/sale.dart';
import 'package:sales_app/utils/api_client.dart';
import 'package:sales_app/widgets/custom_list_card.dart';
import 'package:sales_app/widgets/custom_pagination.dart';
import 'package:sales_app/widgets/custom_state_views.dart';
import 'sale_detail_screen.dart';

class SalesListScreen extends StatefulWidget {
  final String currentUserRole;

  const SalesListScreen({super.key, required this.currentUserRole});

  @override
  State<SalesListScreen> createState() => _SalesListScreenState();
}

class _SalesListScreenState extends State<SalesListScreen> {
  static final logger = Logger();

  List<Sale> sales = [];
  Map<String, dynamic> metadata = {};
  bool isLoading = true;
  String? errorMessage;

  // Filter variables
  final searchController = TextEditingController();
  int currentPage = 1;
  final int pageSize = 20;

  @override
  void initState() {
    super.initState();
    _loadSales();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<void> _loadSales({bool showLoading = true}) async {
    if (showLoading) {
      setState(() {
        isLoading = true;
        errorMessage = null;
      });
    }

    try {
      logger.i('Loading sales - Page: $currentPage');

      final result = await ApiClient.getSales(
        page: currentPage,
        pageSize: pageSize,
      );

      if (mounted) {
        setState(() {
          sales = result['sales'] as List<Sale>;
          metadata = result['metadata'] as Map<String, dynamic>;
          isLoading = false;
          errorMessage = null;
        });
      }

      logger.i('Loaded ${sales.length} sales successfully');
    } catch (e) {
      logger.e('Failed to load sales: $e');
      if (mounted) {
        setState(() {
          isLoading = false;
          errorMessage = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  Future<void> _refreshSales() async {
    currentPage = 1;
    await _loadSales(showLoading: false);
  }

  void _onSaleTap(Sale sale) {
    logger.i('Opening sale details for: ID ${sale.id}');

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SaleDetailScreen(
          sale: sale,
          currentUserRole: widget.currentUserRole,
        ),
      ),
    ).then((result) {
      // Refresh sales list if sale was updated/deleted
      if (result == true) {
        _refreshSales();
      }
    });
  }

  Widget _buildSaleCard(Sale sale) {
    return CustomListCard(
      leading: CircleAvatar(
        backgroundColor: Colors.blue,
        child: Text(
          sale.id.toString(),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      title: Text('Sale #${sale.id}'),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Cashier ID: ${sale.userId} • Product ID: ${sale.productId}'),
          Text('Quantity: ${sale.quantity}'),
          const SizedBox(height: 4),
          Text(
            'Sold: ${_formatDate(sale.soldAt)}',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
        ],
      ),
      onTap: () => _onSaleTap(sale),
    );
  }

  void _changePage(int page) {
    setState(() {
      currentPage = page;
    });
    _loadSales();
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sales History'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshSales,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshSales,
        child: Column(
          children: [
            Expanded(
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : errorMessage != null
                  ? CustomErrorView(
                      message: errorMessage!,
                      onRetry: _refreshSales,
                    )
                  : sales.isEmpty
                  ? const CustomEmptyView(
                      message: 'No sales found',
                      icon: Icons.shopping_cart,
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: sales.length,
                      itemBuilder: (context, index) =>
                          _buildSaleCard(sales[index]),
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
