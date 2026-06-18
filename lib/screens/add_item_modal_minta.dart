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
  List<MintaItem> _modalItems = []; // Ganti nama biar jelas
  TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;
  final Map<int, TextEditingController> _qtyControllers = {};
  final Map<int, String> _itemStatus = {};

  // Helper: cek apakah kombinasi itemId+status sudah ada di form
  bool _isExistInForm(int itemId, String status) {
    return widget.existingItems.any((i) => i.itemId == itemId && i.status == status);
  }

  // Helper: cek apakah kombinasi itemId+status sudah dipilih di modal
  int _findInModal(int itemId, String status) {
    return _modalItems.indexWhere((i) => i.itemId == itemId && i.status == status);
  }

  // Cek apakah itemId ada di modal (apapun statusnya)
  bool _isItemIdInModal(int itemId) {
    return _modalItems.any((i) => i.itemId == itemId);
  }

  @override
  void initState() {
    super.initState();
    _searchItems();
  }

  @override
  void dispose() {
    _searchController.dispose();
    for (var c in _qtyControllers.values) { c.dispose(); }
    super.dispose();
  }

  Future<void> _searchItems() async {
    if (_isSearching) return;
    setState(() => _isSearching = true);
    try {
      final results = await MintaService.searchItems(
        search: _searchController.text.isNotEmpty ? _searchController.text : null,
      );
      setState(() {
        _searchResults = results ?? [];
        _initializeQtyControllers();
      });
    } catch (e) {
      _showErrorSnackbar('Error: ${e.toString()}');
    } finally {
      setState(() => _isSearching = false);
    }
  }

  void _initializeQtyControllers() {
    for (var item in _searchResults) {
      final itemId = item['id'];
      if (itemId != null && !_qtyControllers.containsKey(itemId)) {
        _qtyControllers[itemId] = TextEditingController(text: '0');
      }
    }
  }

  void _toggleItem(Map<String, dynamic> item) {
    final itemId = item['id'];
    final itemName = item['nama']?.toString() ?? 'Tanpa Nama';
    final tipe = item['tipe']?.toString() ?? 'BJ';

    if (itemId == null) {
      _showErrorSnackbar('Item ID tidak valid');
      return;
    }

    // Cari status yang sudah terpakai (form + modal)
    final usedStatuses = <String>{};
    for (var i in widget.existingItems) {
      if (i.itemId == itemId) usedStatuses.add(i.status);
    }
    for (var i in _modalItems) {
      if (i.itemId == itemId) usedStatuses.add(i.status);
    }

    // Tentukan status otomatis
    String? targetStatus;
    if (!usedStatuses.contains('DISPLAY')) {
      targetStatus = 'DISPLAY';
    } else if (!usedStatuses.contains('PESANAN')) {
      targetStatus = 'PESANAN';
    }

    // Cek apakah item dengan targetStatus ini sudah ada di modal (untuk toggle off)
    final existingIdx = _findInModal(itemId, targetStatus ?? '');

    if (existingIdx != -1) {
      // Sudah dicentang → uncheck
      setState(() {
        _modalItems.removeAt(existingIdx);
        final ctrl = _qtyControllers[itemId];
        if (ctrl != null) ctrl.text = '0';
      });
    } else {
      // Belum dicentang
      if (targetStatus == null) {
        _showInfoSnackbar('Item ini sudah ada dengan status DISPLAY dan PESANAN');
        return;
      }

      final qtyCtrl = _qtyControllers[itemId];
      final qty = qtyCtrl != null ? (int.tryParse(qtyCtrl.text) ?? 0) : 0;

      setState(() {
        _itemStatus[itemId] = targetStatus!; // ✅ Tambah tanda seru (!) karena sudah dicek null di atas
        _modalItems.add(MintaItem(
          itemId: itemId,
          itemNama: itemName,
          tipe: tipe,
          qty: qty,
          status: targetStatus!, // ✅ Tambah tanda seru
        ));
      });
    }
  }

  void _toggleSelectAll() {
    final allSelected = _searchResults.every((item) {
      final itemId = item['id'];
      if (itemId == null) return true;
      return _isItemIdInModal(itemId);
    });

    if (allSelected) {
      // Uncheck semua
      setState(() {
        final idsToRemove = _searchResults.map((item) => item['id']).where((id) => id != null).toSet();
        _modalItems.removeWhere((i) => idsToRemove.contains(i.itemId));
        for (var id in idsToRemove) {
          _qtyControllers[id]?.text = '0';
        }
      });
    } else {
      // Check semua yang belum
      setState(() {
        for (var item in _searchResults) {
          final itemId = item['id'];
          if (itemId == null) continue;
          if (_isItemIdInModal(itemId)) continue;

          // Cari status yang tersedia
          final usedStatuses = <String>{};
          for (var i in widget.existingItems) {
            if (i.itemId == itemId) usedStatuses.add(i.status);
          }
          for (var i in _modalItems) {
            if (i.itemId == itemId) usedStatuses.add(i.status);
          }

          String? targetStatus;
          if (!usedStatuses.contains('DISPLAY')) {
            targetStatus = 'DISPLAY';
          } else if (!usedStatuses.contains('PESANAN')) {
            targetStatus = 'PESANAN';
          }

          if (targetStatus == null) continue;

          final qtyCtrl = _qtyControllers[itemId];
          final qty = qtyCtrl != null ? (int.tryParse(qtyCtrl.text) ?? 0) : 0;

          _itemStatus[itemId] = targetStatus;
          _modalItems.add(MintaItem(
            itemId: itemId,
            itemNama: item['nama']?.toString() ?? 'Tanpa Nama',
            tipe: item['tipe']?.toString() ?? 'BJ',
            qty: qty,
            status: targetStatus,
          ));
        }
      });
    }
  }

  bool _isItemSelected(int itemId) {
    return _isItemIdInModal(itemId);
  }

  void _addSelectedItems() {
    final result = <MintaItem>[];
    for (var item in _modalItems) {
      final ctrl = _qtyControllers[item.itemId];
      if (ctrl != null && ctrl.text.isNotEmpty) {
        final qty = int.tryParse(ctrl.text) ?? 0;
        if (qty > 0) {
          result.add(MintaItem(
            itemId: item.itemId,
            itemNama: item.itemNama,
            tipe: item.tipe,
            qty: qty,
            status: item.status,
          ));
        }
      }
    }
    Navigator.pop(context, result);
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red, duration: const Duration(seconds: 2)),
    );
  }

  void _showInfoSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.blue, duration: const Duration(seconds: 2)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(topLeft: Radius.circular(12), topRight: Radius.circular(12)),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: Colors.grey.shade300))),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Pilih Item', style: GoogleFonts.montserrat(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.black87)),
                IconButton(icon: Icon(Icons.close, size: 18, color: Colors.grey.shade700), onPressed: () => Navigator.pop(context), padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 30)),
              ],
            ),
          ),

          // Search
          Container(
            margin: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 34,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade300)),
                    child: Row(
                      children: [
                        Icon(Icons.search, size: 14, color: Colors.grey.shade500),
                        const SizedBox(width: 6),
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            decoration: InputDecoration(hintText: 'Cari item...', hintStyle: GoogleFonts.montserrat(fontSize: 11, color: Colors.grey.shade500), border: InputBorder.none, isDense: true),
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
                    icon: _isSearching ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.search, size: 12),
                    label: Text('Cari', style: GoogleFonts.montserrat(fontSize: 11)),
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF6A918), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 10), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                  ),
                ),
              ],
            ),
          ),

          // Info bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: Colors.grey.shade200))),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${_searchResults.length} item', style: GoogleFonts.montserrat(fontSize: 10, color: Colors.grey.shade700)),
                Row(
                  children: [
                    Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.grey.shade300)), child: Text('${_modalItems.length} dipilih', style: GoogleFonts.montserrat(fontSize: 10, fontWeight: FontWeight.w600, color: const Color(0xFFF6A918)))),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: _toggleSelectAll,
                      child: Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.blue.shade200)), child: Row(children: [Icon(Icons.check_box_outlined, size: 10, color: Colors.blue.shade700), const SizedBox(width: 4), Text('PILIH SEMUA', style: GoogleFonts.montserrat(fontSize: 9, fontWeight: FontWeight.w600, color: Colors.blue.shade700))])),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // List
          Expanded(
            child: _isSearching
                ? const Center(child: CircularProgressIndicator(color: Color(0xFFF6A918), strokeWidth: 2))
                : _searchResults.isEmpty
                ? Center(
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.search_off, size: 32, color: Colors.grey.shade400),
                const SizedBox(height: 8),
                Text(_searchController.text.isEmpty ? 'Mulai pencarian item' : 'Item tidak ditemukan', style: GoogleFonts.montserrat(color: Colors.grey.shade500, fontSize: 12)),
              ]),
            )
                : ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              separatorBuilder: (context, index) => const SizedBox(height: 4),
              itemCount: _searchResults.length,
              itemBuilder: (context, index) {
                final item = _searchResults[index];
                final itemId = item['id'];
                final itemName = item['nama']?.toString() ?? 'Tanpa Nama';
                final tipe = item['tipe']?.toString() ?? 'BJ';
                if (itemId == null) return const SizedBox();

                final isSelected = _isItemSelected(itemId);
                final ctrl = _qtyControllers[itemId] ?? (TextEditingController(text: '0'));
                _qtyControllers[itemId] = ctrl;

                // Cek status yang dipakai
                final formStatuses = widget.existingItems.where((i) => i.itemId == itemId).map((i) => i.status).toSet();
                final modalStatuses = _modalItems.where((i) => i.itemId == itemId).map((i) => i.status).toSet();
                final allUsed = formStatuses.contains('DISPLAY') && formStatuses.contains('PESANAN');
                final modalUsed = modalStatuses.isNotEmpty;

                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 2, offset: const Offset(0, 1))]),
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Row(
                      children: [
                        if (allUsed)
                          Container(width: 24, height: 24, decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(4)), child: Icon(Icons.block, size: 12, color: Colors.red.shade700))
                        else
                          Checkbox(
                            value: modalUsed,
                            onChanged: (_) => _toggleItem(item),
                            activeColor: const Color(0xFFF6A918),
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            visualDensity: VisualDensity.compact,
                          ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(itemName, style: GoogleFonts.montserrat(fontSize: 11, fontWeight: FontWeight.w600, color: allUsed ? Colors.grey.shade500 : Colors.black87), maxLines: 1, overflow: TextOverflow.ellipsis),
                              const SizedBox(height: 2),
                              Wrap(spacing: 4, children: [
                                Text('ID: $itemId', style: GoogleFonts.montserrat(fontSize: 9, color: Colors.grey.shade600)),
                                Container(padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1), decoration: BoxDecoration(color: tipe == 'BJ' ? Colors.blue.shade50 : Colors.green.shade50, borderRadius: BorderRadius.circular(4), border: Border.all(color: tipe == 'BJ' ? Colors.blue.shade200 : Colors.green.shade200)), child: Text(tipe == 'BJ' ? 'BJ' : 'STJ', style: GoogleFonts.montserrat(fontSize: 8, fontWeight: FontWeight.w600, color: tipe == 'BJ' ? Colors.blue.shade700 : Colors.green.shade700))),
                                if (modalStatuses.isNotEmpty)
                                  Container(padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1), decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.orange.shade200)), child: Text(modalStatuses.first, style: GoogleFonts.montserrat(fontSize: 8, fontWeight: FontWeight.w600, color: Colors.orange.shade700))),
                                if (formStatuses.isNotEmpty && !modalStatuses.contains(formStatuses.first))
                                  Container(padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1), decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(4)), child: Text('Form: ${formStatuses.first}', style: GoogleFonts.montserrat(fontSize: 8, fontWeight: FontWeight.w600, color: Colors.green.shade700))),
                              ]),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 60, height: 30,
                          child: TextField(
                            controller: ctrl,
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            style: GoogleFonts.montserrat(fontSize: 12, fontWeight: FontWeight.w700, color: modalUsed ? const Color(0xFFF6A918) : Colors.grey.shade400),
                            decoration: InputDecoration(hintText: '0', hintStyle: GoogleFonts.montserrat(fontSize: 12, color: Colors.grey.shade400), border: OutlineInputBorder(borderSide: BorderSide(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(6)), contentPadding: EdgeInsets.zero, isDense: true),
                            onChanged: (value) {
                              final qty = int.tryParse(value) ?? 0;
                              final idx = _modalItems.indexWhere((i) => i.itemId == itemId);
                              if (idx != -1) {
                                setState(() {
                                  _modalItems[idx] = MintaItem(itemId: _modalItems[idx].itemId, itemNama: _modalItems[idx].itemNama, tipe: _modalItems[idx].tipe, qty: qty, status: _modalItems[idx].status);
                                });
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // Bottom bar
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Colors.grey.shade300))),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.grey.shade700, side: BorderSide(color: Colors.grey.shade400), padding: const EdgeInsets.symmetric(vertical: 10), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                    child: Text('BATAL', style: GoogleFonts.montserrat(fontSize: 11, fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _modalItems.isEmpty ? null : _addSelectedItems,
                    style: ElevatedButton.styleFrom(backgroundColor: _modalItems.isEmpty ? Colors.grey.shade400 : const Color(0xFFF6A918), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 10), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                    child: Text('TAMBAH ${_modalItems.length} ITEM', style: GoogleFonts.montserrat(fontSize: 11, fontWeight: FontWeight.w600)),
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