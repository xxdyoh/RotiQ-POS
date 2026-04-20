import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/minta_service.dart';
import '../models/minta_model.dart';

class AddItemModalMinta extends StatefulWidget {
  final List<MintaItem> existingItems;

  const AddItemModalMinta({super.key, required this.existingItems});

  @override
  State<AddItemModalMinta> createState() => _AddItemModalMintaState();
}

class _AddItemModalMintaState extends State<AddItemModalMinta> {
  List<Map<String, dynamic>> _searchResults = [];
  List<MintaItem> _selectedItems = [];
  TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;
  final Map<int, TextEditingController> _qtyControllers = {};

  @override
  void initState() {
    super.initState();
    _searchItems();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _qtyControllers.values.forEach((controller) => controller.dispose());
    super.dispose();
  }

  Future<void> _searchItems() async {
    if (_isSearching) return;

    setState(() => _isSearching = true);

    try {
      final results = await MintaService.searchItems(
        search: _searchController.text.isNotEmpty ? _searchController.text : null,
      );

      // DEBUG: Print hasil
      print('Search results length: ${results?.length}');
      print('Search results: $results');

      setState(() {
        _searchResults = results ?? [];
        _selectedItems.clear();
        _initializeQtyControllers();
      });
    } catch (e) {
      print('Error searching items: $e'); // DEBUG
      _showErrorSnackbar('Error: ${e.toString()}');
    } finally {
      setState(() => _isSearching = false);
    }
  }

  void _initializeQtyControllers() {
    for (var item in _searchResults) {
      final itemId = item['id'];  // <-- GANTI
      if (itemId != null && !_qtyControllers.containsKey(itemId)) {
        _qtyControllers[itemId] = TextEditingController(text: '0');
      }
    }
  }

  void _toggleItem(Map<String, dynamic> item) {
    final itemId = item['id'];
    final itemName = item['nama']?.toString() ?? 'Tanpa Nama';
    final tipe = item['tipe']?.toString() ?? 'BJ';

    print('Toggle Item - ID: $itemId, Nama: $itemName, Tipe: $tipe');

    if (itemId == null) {
      _showErrorSnackbar('Item ID tidak valid');
      return;
    }

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
        _selectedItems.add(MintaItem(
          itemId: itemId,
          itemNama: itemName,
          tipe: item['tipe']?.toString() ?? 'BJ',  // <-- SUDAH BENAR
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
      final itemId = item['id'];  // <-- GANTI
      return itemId != null && _selectedItems.any((i) => i.itemId == itemId);
    });

    if (allSelected) {
      setState(() {
        _selectedItems.clear();
        for (var item in _searchResults) {
          final itemId = item['id'];  // <-- GANTI
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
          final itemId = item['id'];  // <-- GANTI
          if (itemId == null) continue;

          if (widget.existingItems.any((i) => i.itemId == itemId)) {
            continue;
          }

          final qtyController = _qtyControllers[itemId];
          final qty = qtyController != null ? (int.tryParse(qtyController.text) ?? 0) : 0;

          _selectedItems.add(MintaItem(
            itemId: itemId,
            itemNama: item['nama']?.toString() ?? 'Tanpa Nama',  // <-- GANTI
            tipe: item['tipe']?.toString() ?? 'BJ',  // <-- TAMBAHKAN TIPE
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
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showInfoSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.blue,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _addSelectedItems() {
    final selectedItems = <MintaItem>[];
    for (var item in _searchResults) {
      final itemId = item['id'];
      if (itemId == null) continue;

      final controller = _qtyControllers[itemId];
      if (controller != null && controller.text.isNotEmpty) {
        final qty = int.tryParse(controller.text) ?? 0;
        if (qty > 0) {
          selectedItems.add(MintaItem(
            itemId: itemId,
            itemNama: item['nama']?.toString() ?? 'Unknown Item',
            tipe: item['tipe']?.toString() ?? 'BJ', // <-- PASTIKAN INI
            qty: qty,
          ));
        }
      }
    }

    print('Selected items to return:');
    for (var item in selectedItems) {
      print('  - ID: ${item.itemId}, Tipe: ${item.tipe}, Qty: ${item.qty}');
    }

    Navigator.pop(context, selectedItems);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(12),
          topRight: Radius.circular(12),
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Pilih Item',
                  style: GoogleFonts.montserrat(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, size: 18, color: Colors.grey.shade700),
                  onPressed: () => Navigator.pop(context),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 30),
                ),
              ],
            ),
          ),

          Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.02),
                  blurRadius: 3,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 34,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300, width: 1),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.search, size: 14, color: Colors.grey.shade500),
                        const SizedBox(width: 6),
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            decoration: InputDecoration(
                              hintText: 'Cari item...',
                              hintStyle: GoogleFonts.montserrat(
                                fontSize: 11,
                                color: Colors.grey.shade500,
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
                SizedBox(
                  height: 34,
                  child: ElevatedButton.icon(
                    onPressed: _searchItems,
                    icon: _isSearching
                        ? const SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                        : const Icon(Icons.search, size: 12),
                    label: Text('Cari', style: GoogleFonts.montserrat(fontSize: 11)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF6A918),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${_searchResults.length} item ditemukan',
                  style: GoogleFonts.montserrat(
                    fontSize: 10,
                    color: Colors.grey.shade700,
                  ),
                ),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.grey.shade300, width: 1),
                      ),
                      child: Text(
                        '${_selectedItems.length} dipilih',
                        style: GoogleFonts.montserrat(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFFF6A918),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: _toggleSelectAll,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.blue.shade200, width: 1),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.check_box_outlined,
                              size: 10,
                              color: Colors.blue.shade700,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'PILIH SEMUA',
                              style: GoogleFonts.montserrat(
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                                color: Colors.blue.shade700,
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

          Expanded(
            child: _isSearching
                ? const Center(
              child: CircularProgressIndicator(
                color: Color(0xFFF6A918),
                strokeWidth: 2,
              ),
            )
                : _searchResults.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.search_off,
                    size: 32,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _searchController.text.isEmpty
                        ? 'Mulai pencarian item'
                        : 'Item tidak ditemukan',
                    style: GoogleFonts.montserrat(
                      color: Colors.grey.shade500,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            )
                : ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              separatorBuilder: (context, index) => const SizedBox(height: 4),
              itemCount: _searchResults.length,
              itemBuilder: (context, index) {
                final item = _searchResults[index];
                print('Item $index: ${item['id']}, ${item['nama']}, ${item['tipe']}');
                final itemId = item['id'];  // <-- GANTI
                  final itemName = item['nama']?.toString() ?? 'Tanpa Nama';  // <-- GANTI
                  final tipe = item['tipe']?.toString() ?? 'BJ';  // <-- TAMBAHKAN

                  if (itemId == null) return const SizedBox();

                  final isSelected = _isItemSelected(itemId);
                  final controller = _qtyControllers[itemId];

                  if (controller == null) {
                    _qtyControllers[itemId] = TextEditingController(text: '0');
                  }

                  final currentController = _qtyControllers[itemId]!;
                  final alreadyInList = widget.existingItems.any((i) => i.itemId == itemId);

                  return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.02),
                            blurRadius: 2,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: Row(
                            children: [
                              if (!alreadyInList)
                                Checkbox(
                                  value: isSelected,
                                  onChanged: (_) => _toggleItem(item),
                                  activeColor: const Color(0xFFF6A918),
                                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  visualDensity: VisualDensity.compact,
                                )
                              else
                                Container(
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    color: Colors.red.shade50,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Icon(
                                    Icons.block,
                                    size: 12,
                                    color: Colors.red.shade700,
                                  ),
                                ),

                              const SizedBox(width: 8),

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
                                            ? Colors.grey.shade500
                                            : Colors.black87,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    Wrap(
                                      spacing: 4,
                                      children: [
                                        Text(
                                          'ID: $itemId',
                                          style: GoogleFonts.montserrat(
                                            fontSize: 9,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                        // Tipe badge
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                          decoration: BoxDecoration(
                                            color: tipe == 'BJ' ? Colors.blue.shade50 : Colors.green.shade50,
                                            borderRadius: BorderRadius.circular(4),
                                            border: Border.all(
                                              color: tipe == 'BJ' ? Colors.blue.shade200 : Colors.green.shade200,
                                            ),
                                          ),
                                          child: Text(
                                            tipe == 'BJ' ? 'BJ' : 'STJ',
                                            style: GoogleFonts.montserrat(
                                              fontSize: 8,
                                              fontWeight: FontWeight.w600,
                                              color: tipe == 'BJ' ? Colors.blue.shade700 : Colors.green.shade700,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(width: 8),

                              StatefulBuilder(
                                builder: (context, setLocalState) {
                                  return Container(
                                    width: 70,
                                    height: 30,
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                        color: isSelected
                                            ? const Color(0xFFF6A918)
                                            : Colors.grey.shade300,
                                        width: 1,
                                      ),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
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
                                        color: isSelected
                                            ? const Color(0xFFF6A918)
                                            : Colors.grey.shade600,
                                        height: 1.0,
                                      ),
                                      decoration: InputDecoration(
                                        hintText: '0',
                                        border: InputBorder.none,
                                        contentPadding: EdgeInsets.zero,
                                        isDense: true,
                                        hintStyle: GoogleFonts.montserrat(
                                          fontSize: 11,
                                          color: Colors.grey.shade400,
                                          height: 1.0,
                                        ),
                                      ),
                                      enabled: isSelected || (int.tryParse(currentController.text) ?? 0) > 0,
                                      onChanged: (value) {
                                        setLocalState(() {});

                                        final qty = int.tryParse(value) ?? 0;
                                        final selectedIndex = _selectedItems.indexWhere((i) => i.itemId == itemId);
                                        if (selectedIndex != -1) {
                                          _selectedItems[selectedIndex] = MintaItem(
                                            itemId: _selectedItems[selectedIndex].itemId,
                                            itemNama: _selectedItems[selectedIndex].itemNama,
                                            tipe: _selectedItems[selectedIndex].tipe,
                                            qty: qty,
                                          );
                                        }
                                      },
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                  );
                },
            ),
          ),

          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Colors.grey.shade300)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 4,
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
                      foregroundColor: Colors.grey.shade700,
                      side: BorderSide(color: Colors.grey.shade400),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      minimumSize: const Size(0, 0),
                    ),
                    child: Text(
                      'BATAL',
                      style: GoogleFonts.montserrat(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _selectedItems.isEmpty ? null : () {
                      Navigator.pop(context, _selectedItems);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _selectedItems.isEmpty
                          ? Colors.grey.shade400
                          : const Color(0xFFF6A918),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      minimumSize: const Size(0, 0),
                    ),
                    child: Text(
                      'TAMBAH ${_selectedItems.length} ITEM',
                      style: GoogleFonts.montserrat(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
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