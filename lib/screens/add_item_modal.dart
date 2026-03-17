import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/stokin_service.dart';
import '../models/stokin_model.dart';

class AddItemModal extends StatefulWidget {
  final List<StokinItem> existingItems;

  const AddItemModal({super.key, required this.existingItems});

  @override
  _AddItemModalState createState() => _AddItemModalState();
}

class _AddItemModalState extends State<AddItemModal> {
  // Warna konsisten dengan screen lainnya
  final Color _primaryDark = const Color(0xFF2C3E50);
  final Color _primaryLight = const Color(0xFF34495E);
  final Color _accentGold = const Color(0xFFF6A918);
  final Color _accentMint = const Color(0xFF06D6A0);
  final Color _accentCoral = const Color(0xFFFF6B6B);
  final Color _accentSky = const Color(0xFF4CC9F0);
  final Color _bgLight = const Color(0xFFFAFAFA);
  final Color _bgCard = const Color(0xFFFFFFFF);
  final Color _textPrimary = const Color(0xFF1A202C);
  final Color _textSecondary = const Color(0xFF718096);
  final Color _borderColor = const Color(0xFFE2E8F0);

  List<Map<String, dynamic>> _searchResults = [];
  List<StokinItem> _selectedItems = [];
  TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;
  bool _showRotiOnly = false;
  final Map<int, TextEditingController> _qtyControllers = {};
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _searchItems();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    _qtyControllers.values.forEach((controller) => controller.dispose());
    super.dispose();
  }

  Future<void> _searchItems() async {
    if (_isSearching) return;

    setState(() => _isSearching = true);

    try {
      final results = await StokinService.searchItems(
        search: _searchController.text.isNotEmpty ? _searchController.text : null,
      );

      setState(() {
        _searchResults = results ?? [];
        _selectedItems.clear();
        _initializeQtyControllers();
        _showRotiOnly = false;
      });
    } catch (e) {
      _showErrorSnackbar('Error: ${e.toString()}');
    } finally {
      setState(() => _isSearching = false);
    }
  }

  Future<void> _loadRotiItems() async {
    if (_isSearching) return;

    setState(() => _isSearching = true);

    try {
      final results = await StokinService.loadRotiItems(
        search: _searchController.text.isNotEmpty ? _searchController.text : null,
      );

      setState(() {
        _searchResults = results ?? [];
        _selectedItems.clear();
        _initializeQtyControllers();
        _showRotiOnly = true;
      });
    } catch (e) {
      _showErrorSnackbar('Error: ${e.toString()}');
    } finally {
      setState(() => _isSearching = false);
    }
  }

  void _initializeQtyControllers() {
    for (var item in _searchResults) {
      final itemId = item['item_id'];
      if (itemId != null && !_qtyControllers.containsKey(itemId)) {
        _qtyControllers[itemId] = TextEditingController(text: '0');
      }
    }
  }

  void _toggleItem(Map<String, dynamic> item) {
    final itemId = item['item_id'];

    if (itemId == null) {
      _showErrorSnackbar('Item ID tidak valid');
      return;
    }

    final itemName = item['item_nama']?.toString() ?? 'Tanpa Nama';
    final alreadyInList = widget.existingItems.any((i) => i.itemId == itemId);

    if (alreadyInList) {
      _showInfoSnackbar('Item sudah ditambahkan sebelumnya');
      return;
    }

    final existingIndex = _selectedItems.indexWhere((i) => i.itemId == itemId);

    if (existingIndex == -1) {
      final qtyController = _qtyControllers[itemId];
      final qty = qtyController != null ? (int.tryParse(qtyController.text) ?? 0) : 0;

      setState(() {
        _selectedItems.add(StokinItem(
          itemId: itemId,
          itemNama: itemName,
          qty: qty,
        ));
      });
    } else {
      setState(() {
        _selectedItems.removeAt(existingIndex);
        final controller = _qtyControllers[itemId];
        if (controller != null) {
          controller.text = '0';
        }
      });
    }
  }

  void _toggleSelectAll() {
    final allSelected = _searchResults.every((item) {
      final itemId = item['item_id'];
      return itemId != null && _selectedItems.any((i) => i.itemId == itemId);
    });

    if (allSelected) {
      setState(() {
        _selectedItems.clear();
        for (var item in _searchResults) {
          final itemId = item['item_id'];
          if (itemId != null) {
            final controller = _qtyControllers[itemId];
            if (controller != null) {
              controller.text = '0';
            }
          }
        }
      });
    } else {
      setState(() {
        _selectedItems.clear();
        for (var item in _searchResults) {
          final itemId = item['item_id'];
          if (itemId == null) continue;

          if (widget.existingItems.any((i) => i.itemId == itemId)) {
            continue;
          }

          final qtyController = _qtyControllers[itemId];
          final qty = qtyController != null ? (int.tryParse(qtyController.text) ?? 0) : 0;

          _selectedItems.add(StokinItem(
            itemId: itemId,
            itemNama: item['item_nama']?.toString() ?? 'Tanpa Nama',
            qty: qty,
          ));
        }
      });
    }
  }

  bool _isItemSelected(int itemId) {
    return _selectedItems.any((i) => i.itemId == itemId);
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.white, size: 14),
            const SizedBox(width: 6),
            Expanded(child: Text(message, style: GoogleFonts.montserrat(fontSize: 11))),
          ],
        ),
        backgroundColor: _accentCoral,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        margin: const EdgeInsets.all(12),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showInfoSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.info_outline, color: Colors.white, size: 14),
            const SizedBox(width: 6),
            Expanded(child: Text(message, style: GoogleFonts.montserrat(fontSize: 11))),
          ],
        ),
        backgroundColor: _accentSky,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        margin: const EdgeInsets.all(12),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: _bgCard,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(12),
          topRight: Radius.circular(12),
        ),
      ),
      child: Column(
        children: [
          // HEADER
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [_primaryDark, _primaryLight],
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(
                        Icons.inventory_2_outlined,
                        size: 14,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Pilih Item',
                      style: GoogleFonts.montserrat(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: Icon(Icons.close, size: 16, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                  padding: EdgeInsets.zero,
                ),
              ],
            ),
          ),

          // SEARCH BAR
          Container(
            margin: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 36,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: _bgLight,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: _borderColor),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.search, size: 14, color: _textSecondary),
                        const SizedBox(width: 6),
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            decoration: InputDecoration(
                              hintText: 'Cari item...',
                              hintStyle: GoogleFonts.montserrat(
                                fontSize: 11,
                                color: _textSecondary.withOpacity(0.5),
                              ),
                              border: InputBorder.none,
                              isDense: true,
                            ),
                            style: GoogleFonts.montserrat(fontSize: 11),
                            onSubmitted: (_) => _searchItems(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  height: 36,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [_accentGold, _accentGold.withOpacity(0.8)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: ElevatedButton.icon(
                    onPressed: _searchItems,
                    icon: _isSearching
                        ? SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                        : const Icon(Icons.search, size: 12, color: Colors.white),
                    label: Text(
                      'Cari',
                      style: GoogleFonts.montserrat(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      foregroundColor: Colors.white,
                      shadowColor: Colors.transparent,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // LOAD ROTI BUTTON
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(
              width: double.infinity,
              height: 34,
              child: ElevatedButton.icon(
                onPressed: _loadRotiItems,
                icon: Icon(Icons.restaurant, size: 12, color: Colors.white),
                label: Text(
                  'LOAD ALL ROTI',
                  style: GoogleFonts.montserrat(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _accentSky,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
              ),
            ),
          ),

          const SizedBox(height: 8),

          // INFO BAR
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: _bgLight,
              border: Border(bottom: BorderSide(color: _borderColor), top: BorderSide(color: _borderColor)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${_searchResults.length} item ditemukan',
                  style: GoogleFonts.montserrat(
                    fontSize: 10,
                    color: _textSecondary,
                  ),
                ),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: _accentGold.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: _accentGold.withOpacity(0.3)),
                      ),
                      child: Text(
                        '${_selectedItems.length} dipilih',
                        style: GoogleFonts.montserrat(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          color: _accentGold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: _toggleSelectAll,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: _accentSky.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: _accentSky.withOpacity(0.3)),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.check_box_outlined,
                              size: 10,
                              color: _accentSky,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'PILIH SEMUA',
                              style: GoogleFonts.montserrat(
                                fontSize: 8,
                                fontWeight: FontWeight.w600,
                                color: _accentSky,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // LIST ITEMS - DENGAN SCROLL CONTROLLER
          Expanded(
            child: _isSearching
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 30,
                    height: 30,
                    child: CircularProgressIndicator(
                      color: _accentGold,
                      strokeWidth: 2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Mencari item...',
                    style: GoogleFonts.montserrat(
                      fontSize: 11,
                      color: _textSecondary,
                    ),
                  ),
                ],
              ),
            )
                : _searchResults.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.search_off,
                    size: 36,
                    color: _borderColor,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _searchController.text.isEmpty
                        ? 'Mulai pencarian item'
                        : 'Item tidak ditemukan',
                    style: GoogleFonts.montserrat(
                      fontSize: 11,
                      color: _textSecondary,
                    ),
                  ),
                ],
              ),
            )
                : Scrollbar(
              controller: _scrollController,
              thumbVisibility: true,
              thickness: 6,
              radius: const Radius.circular(10),
              child: ListView.separated(
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                separatorBuilder: (context, index) => const SizedBox(height: 8),
                itemCount: _searchResults.length,
                itemBuilder: (context, index) {
                  final item = _searchResults[index];
                  final itemId = item['item_id'];
                  final itemName = item['item_nama']?.toString() ?? 'Tanpa Nama';

                  if (itemId == null) return const SizedBox();

                  final isSelected = _isItemSelected(itemId);
                  final controller = _qtyControllers[itemId];

                  if (controller == null) {
                    _qtyControllers[itemId] = TextEditingController(text: '0');
                  }

                  final currentController = _qtyControllers[itemId]!;
                  final alreadyInList = widget.existingItems.any((i) => i.itemId == itemId);

                  return Container(
                    decoration: BoxDecoration(
                      color: _bgCard,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSelected ? _accentGold : _borderColor,
                        width: isSelected ? 1.5 : 1,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          // Checkbox / Status
                          if (!alreadyInList)
                            GestureDetector(
                              onTap: () => _toggleItem(item),
                              child: Container(
                                width: 20,
                                height: 20,
                                decoration: BoxDecoration(
                                  color: isSelected ? _accentGold : _bgLight,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: isSelected ? _accentGold : _borderColor,
                                    width: 1.5,
                                  ),
                                ),
                                child: isSelected
                                    ? Icon(
                                  Icons.check,
                                  size: 14,
                                  color: Colors.white,
                                )
                                    : null,
                              ),
                            )
                          else
                            Container(
                              width: 20,
                              height: 20,
                              decoration: BoxDecoration(
                                color: _accentCoral.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: _accentCoral.withOpacity(0.5)),
                              ),
                              child: Icon(
                                Icons.block,
                                size: 12,
                                color: _accentCoral,
                              ),
                            ),

                          const SizedBox(width: 12),

                          // Item Info
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  itemName,
                                  style: GoogleFonts.montserrat(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: alreadyInList
                                        ? _textSecondary
                                        : _textPrimary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'ID: $itemId',
                                  style: GoogleFonts.montserrat(
                                    fontSize: 9,
                                    color: _textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(width: 12),

                          // QTY Input - FIXED CENTER
                          Container(
                            width: 70,
                            height: 32,
                            decoration: BoxDecoration(
                              color: _bgLight,
                              border: Border.all(
                                color: isSelected ? _accentGold : _borderColor,
                                width: 1,
                              ),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Center(  // Center untuk memastikan posisi tengah
                              child: TextField(
                                controller: currentController,
                                keyboardType: TextInputType.number,
                                textAlign: TextAlign.center,
                                textAlignVertical: TextAlignVertical.center,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                ],
                                style: GoogleFonts.montserrat(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: isSelected ? _accentGold : _textSecondary,
                                  height: 1.0,
                                ),
                                decoration: InputDecoration(
                                  hintText: '0',
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.zero,  // Hilangkan padding
                                  isDense: true,
                                  hintStyle: GoogleFonts.montserrat(
                                    fontSize: 11,
                                    color: _textSecondary.withOpacity(0.5),
                                    height: 1.0,
                                  ),
                                ),
                                enabled: isSelected || (int.tryParse(currentController.text) ?? 0) > 0,
                                onChanged: (value) {
                                  final qty = int.tryParse(value) ?? 0;
                                  final selectedIndex = _selectedItems.indexWhere((i) => i.itemId == itemId);
                                  if (selectedIndex != -1) {
                                    _selectedItems[selectedIndex] = StokinItem(
                                      itemId: _selectedItems[selectedIndex].itemId,
                                      itemNama: _selectedItems[selectedIndex].itemNama,
                                      qty: qty,
                                    );
                                  }
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          // FOOTER BUTTONS
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _bgCard,
              border: Border(top: BorderSide(color: _borderColor)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _textSecondary,
                      side: BorderSide(color: _borderColor),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    child: Text(
                      'BATAL',
                      style: GoogleFonts.montserrat(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: _textSecondary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _selectedItems.isEmpty ? null : () {
                      Navigator.pop(context, _selectedItems);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _selectedItems.isEmpty ? _borderColor : _accentGold,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    child: Text(
                      'TAMBAH ${_selectedItems.length} ITEM',
                      style: GoogleFonts.montserrat(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}