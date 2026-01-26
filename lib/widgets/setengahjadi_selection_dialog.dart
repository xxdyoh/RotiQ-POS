import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/setengahjadi.dart';

class SetengahJadiSelectionDialog extends StatefulWidget {
  final List<SetengahJadi> setengahJadiList;
  final List<SetengahJadi>? alreadySelectedItems;
  final Function(SetengahJadi, int) onAdd;

  const SetengahJadiSelectionDialog({
    super.key,
    required this.setengahJadiList,
    this.alreadySelectedItems,
    required this.onAdd,
  });

  @override
  State<SetengahJadiSelectionDialog> createState() =>
      _SetengahJadiSelectionDialogState();
}

class _SetengahJadiSelectionDialogState extends State<SetengahJadiSelectionDialog> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _qtyController = TextEditingController(text: '1');
  List<SetengahJadi> _filteredItems = [];
  SetengahJadi? _selectedItem;

  @override
  void initState() {
    super.initState();
    _filteredItems = widget.setengahJadiList;
    _qtyController.text = '1';
  }

  void _filterItems(String query) {
    setState(() {
      _filteredItems = widget.setengahJadiList.where((item) {
        return item.stjNama.toLowerCase().contains(query.toLowerCase());
      }).toList();
    });
  }

  bool _isAlreadySelected(SetengahJadi item) {
    return widget.alreadySelectedItems?.any((selected) => selected.stjId == item.stjId) ?? false;
  }

  void _addSelectedItem() {
    if (_selectedItem == null) return;

    final qty = int.tryParse(_qtyController.text.trim()) ?? 0;
    if (qty <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Qty harus lebih dari 0', style: GoogleFonts.montserrat(fontSize: 12)),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    widget.onAdd(_selectedItem!, qty);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      backgroundColor: Colors.white,
      elevation: 4,
      child: Container(
        height: 500,
        child: Column(
          children: [
            // Header
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                border: Border(bottom: BorderSide(color: Colors.grey.shade200, width: 1)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Tambah Setengah Jadi',
                    style: GoogleFonts.montserrat(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, size: 18, color: Colors.grey.shade600),
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero,
                    constraints: BoxConstraints(minWidth: 30, minHeight: 30),
                  ),
                ],
              ),
            ),

            // Search Bar
            Padding(
              padding: EdgeInsets.all(12),
              child: Container(
                height: 34,
                padding: EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300, width: 1),
                ),
                child: Row(
                  children: [
                    Icon(Icons.search, size: 14, color: Colors.grey.shade500),
                    SizedBox(width: 6),
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        autofocus: true,
                        decoration: InputDecoration(
                          hintText: 'Cari setengah jadi...',
                          hintStyle: GoogleFonts.montserrat(fontSize: 11),
                          border: InputBorder.none,
                          isDense: true,
                        ),
                        style: GoogleFonts.montserrat(fontSize: 11),
                        onChanged: _filterItems,
                      ),
                    ),
                    if (_searchController.text.isNotEmpty)
                      IconButton(
                        icon: Icon(Icons.clear, size: 12, color: Colors.grey.shade500),
                        onPressed: () {
                          _searchController.clear();
                          _filterItems('');
                        },
                        padding: EdgeInsets.zero,
                        constraints: BoxConstraints(minWidth: 20),
                      ),
                  ],
                ),
              ),
            ),

            // Qty Input
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Jumlah (Qty)',
                    style: GoogleFonts.montserrat(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  SizedBox(height: 4),
                  Container(
                    height: 34,
                    padding: EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300, width: 1),
                    ),
                    child: TextField(
                      controller: _qtyController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        hintText: 'Masukkan jumlah...',
                        hintStyle: GoogleFonts.montserrat(fontSize: 11),
                        border: InputBorder.none,
                        isDense: true,
                      ),
                      style: GoogleFonts.montserrat(fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: 8),

            // Info
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Hasil: ${_filteredItems.length} item${_filteredItems.length != 1 ? 's' : ''}',
                    style: GoogleFonts.montserrat(
                      fontSize: 10,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  if (_selectedItem != null)
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.orange.shade100, width: 1),
                      ),
                      child: Text(
                        'Dipilih: ${_selectedItem!.stjNama}',
                        style: GoogleFonts.montserrat(
                          fontSize: 9,
                          color: Colors.orange.shade700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ),
            ),

            SizedBox(height: 8),

            // List Items
            Expanded(
              child: _filteredItems.isEmpty
                  ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.construction_outlined,
                      size: 36,
                      color: Colors.grey.shade400,
                    ),
                    SizedBox(height: 8),
                    Text(
                      _searchController.text.isEmpty
                          ? 'Tidak ada data setengah jadi'
                          : 'Setengah jadi tidak ditemukan',
                      style: GoogleFonts.montserrat(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              )
                  : ListView.builder(
                padding: EdgeInsets.symmetric(horizontal: 12),
                itemCount: _filteredItems.length,
                itemBuilder: (context, index) {
                  final item = _filteredItems[index];
                  final isSelected = _selectedItem?.stjId == item.stjId;
                  final alreadySelected = _isAlreadySelected(item);

                  return Container(
                    margin: EdgeInsets.only(bottom: 6),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Colors.orange.shade50
                          : alreadySelected
                          ? Colors.grey.shade100
                          : Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSelected
                            ? Colors.orange.shade200
                            : alreadySelected
                            ? Colors.grey.shade300
                            : Colors.grey.shade200,
                        width: 1,
                      ),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: alreadySelected
                            ? null
                            : () {
                          setState(() {
                            _selectedItem = item;
                            _qtyController.text = '1';
                          });
                        },
                        child: Opacity(
                          opacity: alreadySelected ? 0.6 : 1.0,
                          child: Padding(
                            padding: EdgeInsets.all(10),
                            child: Row(
                              children: [
                                Container(
                                  width: 30,
                                  height: 30,
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? Colors.orange.shade100
                                        : Colors.teal.shade50,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Icon(
                                    Icons.construction_rounded,
                                    size: 14,
                                    color: isSelected
                                        ? Colors.orange.shade700
                                        : Colors.teal.shade700,
                                  ),
                                ),
                                SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.stjNama,
                                        style: GoogleFonts.montserrat(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: isSelected
                                              ? Colors.orange.shade800
                                              : Colors.black87,
                                        ),
                                      ),
                                      SizedBox(height: 2),
                                      Row(
                                        children: [
                                          Container(
                                            padding: EdgeInsets.symmetric(
                                              horizontal: 4,
                                              vertical: 1,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.grey.shade100,
                                              borderRadius: BorderRadius.circular(3),
                                            ),
                                            child: Text(
                                              'ID: ${item.stjId}',
                                              style: GoogleFonts.montserrat(
                                                fontSize: 8,
                                                color: Colors.grey.shade700,
                                              ),
                                            ),
                                          ),
                                          SizedBox(width: 6),
                                          Container(
                                            padding: EdgeInsets.symmetric(
                                              horizontal: 4,
                                              vertical: 1,
                                            ),
                                            decoration: BoxDecoration(
                                              color: item.stjStock <= 5
                                                  ? Colors.red.shade50
                                                  : Colors.green.shade50,
                                              borderRadius: BorderRadius.circular(3),
                                              border: Border.all(
                                                color: item.stjStock <= 5
                                                    ? Colors.red.shade100
                                                    : Colors.green.shade100,
                                                width: 1,
                                              ),
                                            ),
                                            child: Text(
                                              'STOK: ${item.stjStock}',
                                              style: GoogleFonts.montserrat(
                                                fontSize: 8,
                                                fontWeight: FontWeight.w700,
                                                color: item.stjStock <= 5
                                                    ? Colors.red.shade700
                                                    : Colors.green.shade700,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                if (alreadySelected)
                                  Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.shade50,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      'SUDAH DIPILIH',
                                      style: GoogleFonts.montserrat(
                                        fontSize: 7,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.blue.shade700,
                                      ),
                                    ),
                                  ),
                                if (isSelected && !alreadySelected)
                                  Icon(
                                    Icons.check_circle,
                                    size: 16,
                                    color: Colors.orange.shade700,
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            // Footer Buttons
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(12)),
                border: Border(top: BorderSide(color: Colors.grey.shade200, width: 1)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Colors.grey.shade300),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: EdgeInsets.symmetric(vertical: 8),
                      ),
                      child: Text(
                        'Batal',
                        style: GoogleFonts.montserrat(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _selectedItem == null ? null : _addSelectedItem,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _selectedItem == null
                            ? Colors.grey.shade400
                            : Color(0xFFF6A918),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: EdgeInsets.symmetric(vertical: 8),
                      ),
                      child: Text(
                        'Tambah',
                        style: GoogleFonts.montserrat(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}