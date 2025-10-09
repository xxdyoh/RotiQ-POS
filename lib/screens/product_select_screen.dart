import 'package:flutter/material.dart';
import '../models/product.dart';
import '../services/api_service.dart';
import 'package:intl/intl.dart';

class ProductSelectScreen extends StatefulWidget {
  const ProductSelectScreen({Key? key}) : super(key: key);

  @override
  State<ProductSelectScreen> createState() => _ProductSelectScreenState();
}

class _ProductSelectScreenState extends State<ProductSelectScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<Product> _products = [];
  List<Product> _filteredProducts = [];
  bool _isLoading = false;
  String _selectedCategory = 'Semua';
  List<String> _categories = ['Semua'];
  final currencyFormat = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

  // State untuk multi-select
  final Map<String, int> _selectedProducts = {}; // productId -> quantity
  bool get _selectionMode => _selectedProducts.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _loadProducts();
    _searchController.addListener(_filterProducts);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadProducts() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final products = await ApiService.getProducts();
      setState(() {
        _products = products;
        _filteredProducts = products;
        _isLoading = false;

        // Extract unique categories
        final categorySet = <String>{'Semua'};
        for (var product in products) {
          if (product.category != null && product.category!.isNotEmpty) {
            categorySet.add(product.category!);
          }
        }
        _categories = categorySet.toList();
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        _showErrorSnackbar('Gagal memuat item: ${e.toString()}');
      }
    }
  }

  void _filterProducts() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredProducts = _products.where((product) {
        final matchesSearch = query.isEmpty ||
            product.name.toLowerCase().contains(query) ||
            (product.category?.toLowerCase().contains(query) ?? false);

        final matchesCategory = _selectedCategory == 'Semua' ||
            product.category == _selectedCategory;

        return matchesSearch && matchesCategory;
      }).toList();
    });
  }

  void _filterByCategory(String category) {
    setState(() {
      _selectedCategory = category;
    });
    _filterProducts();
  }

  // Methods untuk selection management
  void _toggleProductSelection(Product product) {
    setState(() {
      if (_selectedProducts.containsKey(product.id)) {
        _selectedProducts.remove(product.id);
      } else {
        _selectedProducts[product.id] = 1; // Default quantity 1
      }
    });
  }

  void _updateProductQuantity(Product product, int quantity) {
    setState(() {
      if (quantity <= 0) {
        _selectedProducts.remove(product.id);
      } else if (quantity > product.stock) {
        _selectedProducts[product.id] = product.stock;
        _showErrorSnackbar('Quantity melebihi stock');
      } else {
        _selectedProducts[product.id] = quantity;
      }
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedProducts.clear();
    });
  }

  void _confirmSelection() {
    if (_selectedProducts.isEmpty) {
      _showErrorSnackbar('Pilih minimal 1 item');
      return;
    }

    Navigator.pop(context, _selectedProducts);
  }

  bool _isProductSelected(Product product) {
    return _selectedProducts.containsKey(product.id);
  }

  int _getSelectedQuantity(Product product) {
    return _selectedProducts[product.id] ?? 0;
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.white, size: 20),
            SizedBox(width: 8),
            Text(message),
          ],
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Row(
          children: [
            Icon(Icons.inventory_2, color: Colors.white, size: 24),
            SizedBox(width: 8),
            Text(
              _selectionMode ? 'Pilih Item (${_selectedProducts.length})' : 'Pilih Item',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: Colors.white,
              ),
            ),
          ],
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFFF6A918),
                Color(0xFFFFC107),
                Color(0xFFFFD54F),
              ],
              stops: [0.0, 0.6, 1.0],
            ),
          ),
        ),
        actions: [
          if (_selectionMode) ...[
            IconButton(
              icon: Icon(Icons.clear, color: Colors.white),
              onPressed: _clearSelection,
              tooltip: 'Batal',
            ),
            IconButton(
              icon: Icon(Icons.check, color: Colors.white),
              onPressed: _confirmSelection,
              tooltip: 'Tambah ke Order',
            ),
          ],
        ],
      ),
      body: Column(
        children: [
          // Search Section
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                // Search Bar
                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Cari item...',
                      prefixIcon: Icon(Icons.search, color: Color(0xFFF6A918)),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                        icon: Icon(Icons.clear, size: 20),
                        onPressed: () {
                          _searchController.clear();
                        },
                      )
                          : null,
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                  ),
                ),
                SizedBox(height: 12),
                // Category Filter
                _buildCategoryFilter(),
              ],
            ),
          ),

          // Results Info
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Colors.grey[100],
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${_filteredProducts.length} item ditemukan',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (_selectionMode)
                  Text(
                    '${_selectedProducts.length} item dipilih',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFFF6A918),
                      fontWeight: FontWeight.bold,
                    ),
                  )
                else if (_selectedCategory != 'Semua')
                  GestureDetector(
                    onTap: () => _filterByCategory('Semua'),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Filter: $_selectedCategory',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFFF6A918),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        SizedBox(width: 4),
                        Icon(Icons.close, size: 14, color: Color(0xFFF6A918)),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          // Product List
          Expanded(
            child: _isLoading
                ? _buildLoadingState()
                : _filteredProducts.isEmpty
                ? _buildEmptyState()
                : _buildProductGrid(),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryFilter() {
    return SizedBox(
      height: 40,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _categories.length,
        itemBuilder: (context, index) {
          final category = _categories[index];
          final isSelected = _selectedCategory == category;

          return Padding(
            padding: EdgeInsets.only(right: 8),
            child: Container(
              constraints: BoxConstraints(maxWidth: 150),
              child: FilterChip(
                label: Text(
                  _truncateCategory(category),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: isSelected ? Colors.white : Colors.grey[700],
                  ),
                ),
                selected: isSelected,
                onSelected: (selected) => _filterByCategory(category),
                backgroundColor: Colors.white,
                selectedColor: Color(0xFFF6A918),
                checkmarkColor: Colors.white,
                side: BorderSide(
                  color: isSelected ? Color(0xFFF6A918) : Colors.grey[300]!,
                ),
                shape: StadiumBorder(
                  side: BorderSide(
                    color: isSelected ? Color(0xFFF6A918) : Colors.grey[300]!,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  String _truncateCategory(String category) {
    if (category.length <= 15) return category;
    return '${category.substring(0, 12)}...';
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            color: Color(0xFFF6A918),
            strokeWidth: 2,
          ),
          SizedBox(height: 16),
          Text(
            'Memuat item...',
            style: TextStyle(
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(
                Icons.search_off_rounded,
                size: 64,
                color: Colors.grey[400],
              ),
            ),
            SizedBox(height: 24),
            Text(
              'Item tidak ditemukan',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
              ),
            ),
            SizedBox(height: 8),
            Text(
              _searchController.text.isEmpty && _selectedCategory == 'Semua'
                  ? 'Tidak ada item tersedia'
                  : 'Coba gunakan kata kunci lain atau filter yang berbeda',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
            SizedBox(height: 16),
            if (_searchController.text.isNotEmpty || _selectedCategory != 'Semua')
              ElevatedButton.icon(
                onPressed: () {
                  _searchController.clear();
                  _filterByCategory('Semua');
                },
                icon: Icon(Icons.refresh, size: 18),
                label: Text('Reset Pencarian'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFFF6A918),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductGrid() {
    return RefreshIndicator(
      onRefresh: _loadProducts,
      color: Color(0xFFF6A918),
      backgroundColor: Colors.white,
      child: GridView.builder(
        padding: EdgeInsets.all(16),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.65,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemCount: _filteredProducts.length,
        itemBuilder: (context, index) {
          final product = _filteredProducts[index];
          final isOutOfStock = product.stock == 0;

          return _buildProductCard(product, isOutOfStock);
        },
      ),
    );
  }

  Widget _buildProductCard(Product product, bool isOutOfStock) {
    final isSelected = _isProductSelected(product);
    final selectedQuantity = _getSelectedQuantity(product);

    return Card(
      elevation: isSelected ? 4 : 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: isSelected
            ? BorderSide(color: Color(0xFFF6A918), width: 2)
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: isOutOfStock ? null : () => _toggleProductSelection(product),
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Product Image
                Expanded(
                  flex: 3,
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(16),
                      ),
                    ),
                    child: Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                          child: _buildProductImage(product),
                        ),

                        if (product.category != null && product.category!.isNotEmpty)
                          Positioned(
                            bottom: 8,
                            left: 8,
                            child: Container(
                              constraints: BoxConstraints(maxWidth: 80),
                              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.7),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                _truncateCategory(product.category!),
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),

                        Positioned(
                          top: 8,
                          right: 8,
                          child: Container(
                            padding: EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                            decoration: BoxDecoration(
                              color: isOutOfStock ? Colors.red : Colors.green,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              isOutOfStock ? 'HABIS' : '${product.stock}',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),

                        if (isSelected)
                          Container(
                            decoration: BoxDecoration(
                              color: Color(0xFFF6A918).withOpacity(0.2),
                              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),

                // Product Info
                Expanded(
                  flex: 2,
                  child: Padding(
                    padding: EdgeInsets.all(10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          product.name,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isOutOfStock ? Colors.grey : Colors.black87,
                            height: 1.2,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),

                        Text(
                          currencyFormat.format(product.price),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: isOutOfStock ? Colors.grey : Color(0xFFF6A918),
                          ),
                        ),

                        if (isSelected)
                          _buildQuantityControls(product, selectedQuantity)
                        else if (!isOutOfStock)
                          _buildAddButton(product),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            if (isSelected)
              Positioned(
                top: 4,
                left: 4,
                child: Container(
                  padding: EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Color(0xFFF6A918),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.check, size: 16, color: Colors.white),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuantityControls(Product product, int quantity) {
    return Container(
      width: double.infinity,
      height: 28,
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(6),
            ),
            child: IconButton(
              padding: EdgeInsets.zero,
              icon: Icon(Icons.remove, size: 14),
              onPressed: () {
                _updateProductQuantity(product, quantity - 1);
              },
            ),
          ),

          Expanded(
            child: Container(
              height: 28,
              child: TextField(
                textAlign: TextAlign.center,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  contentPadding: EdgeInsets.zero,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(0),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(0),
                    borderSide: BorderSide(color: Color(0xFFF6A918)),
                  ),
                ),
                controller: TextEditingController(text: quantity.toString()),
                onChanged: (value) {
                  final newQuantity = int.tryParse(value) ?? 0;
                  _updateProductQuantity(product, newQuantity);
                },
              ),
            ),
          ),

          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(6),
            ),
            child: IconButton(
              padding: EdgeInsets.zero,
              icon: Icon(Icons.add, size: 14),
              onPressed: () {
                _updateProductQuantity(product, quantity + 1);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddButton(Product product) {
    return Container(
      width: double.infinity,
      height: 28,
      child: ElevatedButton(
        onPressed: () {
          _toggleProductSelection(product);
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: Color(0xFFF6A918),
          foregroundColor: Colors.white,
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add, size: 14),
            SizedBox(width: 2),
            Text(
              'Tambah',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductImage(Product product) {
    if (product.image != null && product.image!.isNotEmpty) {
      return Image.memory(
        product.image!,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (context, error, stackTrace) {
          return _buildPlaceholderImage();
        },
      );
    } else {
      return _buildPlaceholderImage();
    }
  }

  Widget _buildPlaceholderImage() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inventory_2_outlined,
            size: 28,
            color: Colors.grey[400],
          ),
          SizedBox(height: 2),
          Text(
            'No Image',
            style: TextStyle(
              fontSize: 8,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }
}