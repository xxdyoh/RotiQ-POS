import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/item_service.dart';
import '../services/setengahjadi_service.dart';
import '../models/setengahjadi.dart';
import '../widgets/base_layout.dart';
import '../models/item_setengahjadi_detail.dart';
import '../widgets/setengahjadi_selection_dialog.dart';

class ItemFormScreen extends StatefulWidget {
  final List<Map<String, dynamic>> categories;
  final Map<String, dynamic>? item;
  final VoidCallback onItemSaved;

  const ItemFormScreen({
    super.key,
    required this.categories,
    this.item,
    required this.onItemSaved,
  });

  @override
  State<ItemFormScreen> createState() => _ItemFormScreenState();
}

class _ItemFormScreenState extends State<ItemFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();

  String? _selectedCategory;
  SetengahJadi? _selectedSetengahJadi;
  List<Map<String, dynamic>> _setengahJadiDetails = [];
  List<SetengahJadi> _setengahJadiList = [];
  bool _isLoading = false;
  bool _isLoadingSetengahJadi = false;
  bool _isLoadingDetails = false;

  @override
  void initState() {
    super.initState();
    if (widget.item != null) {
      _nameController.text = widget.item!['Nama']?.toString() ?? '';
      _priceController.text = (widget.item!['Price']?.toString() ?? '0');
      _selectedCategory = widget.item!['Category']?.toString();
      _loadItemSetengahJadiDetails();
    }
    _loadSetengahJadi();
  }

  Future<void> _loadSetengahJadi() async {
    setState(() => _isLoadingSetengahJadi = true);
    try {
      final items = await SetengahJadiService.getSetengahJadi();
      setState(() => _setengahJadiList = items);
    } catch (e) {
      print('Error loading setengah jadi: $e');
    } finally {
      setState(() => _isLoadingSetengahJadi = false);
    }
  }

  Future<void> _loadItemSetengahJadiDetails() async {
    if (widget.item == null) return;

    setState(() => _isLoadingDetails = true);
    try {
      final itemId = widget.item!['id'].toString();
      final details = await ItemService.getItemSetengahJadiDetails(int.parse(itemId));

      setState(() {
        _setengahJadiDetails = details.map((detail) {
          return {
            'stjId': detail['stj_id'],
            'stjNama': detail['stj_nama'],
            'qty': detail['isj_qty'],
          };
        }).toList();
      });
    } catch (e) {
      print('Error loading item setengah jadi details: $e');
    } finally {
      setState(() => _isLoadingDetails = false);
    }
  }

  void _addSetengahJadiDetail(SetengahJadi setengahJadi, int qty) {
    setState(() {
      _setengahJadiDetails.add({
        'stjId': setengahJadi.stjId,
        'stjNama': setengahJadi.stjNama,
        'qty': qty,
      });
    });
  }

  void _updateSetengahJadiQty(int index, int newQty) {
    setState(() {
      _setengahJadiDetails[index]['qty'] = newQty;
    });
  }

  void _removeSetengahJadiDetail(int index) {
    setState(() {
      _setengahJadiDetails.removeAt(index);
    });
  }

  void _showAddSetengahJadiDialog() async {
    final selectedItems = _setengahJadiDetails
        .map((detail) => SetengahJadi(
      stjId: detail['stjId'],
      stjNama: detail['stjNama'],
      stjStock: 0,
    ))
        .toList();

    await showDialog(
      context: context,
      builder: (context) => SetengahJadiSelectionDialog(
        setengahJadiList: _setengahJadiList,
        alreadySelectedItems: selectedItems,
        onAdd: _addSetengahJadiDetail,
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  void _showSnackbar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              color == Colors.green ? Icons.check_circle : Icons.error_outline,
              color: Colors.white,
              size: 16,
            ),
            SizedBox(width: 6),
            Text(message, style: GoogleFonts.montserrat(fontSize: 12)),
          ],
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        margin: EdgeInsets.all(12),
      ),
    );
  }

  // void _showSetengahJadiDialog() async {
  //   final selected = await showDialog<SetengahJadi>(
  //     context: context,
  //     builder: (context) => SetengahJadiSelectionDialog(
  //       setengahJadiList: _setengahJadiList,
  //       selectedSetengahJadi: _selectedSetengahJadi,
  //     ),
  //   );
  //
  //   if (selected != null) {
  //     setState(() => _selectedSetengahJadi = selected);
  //   }
  // }

  Future<void> _saveItem() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    print("disini coba");

    try {
      final name = _nameController.text.trim();
      final category = _selectedCategory!;
      final price = double.tryParse(_priceController.text.replaceAll(',', '')) ?? 0;

      final itemResult = widget.item == null
          ? await ItemService.addItem(
        name: name,
        category: category,
        price: price,
      )
          : await ItemService.updateItem(
        itemId: widget.item!['id'].toString(),
        name: name,
        category: category,
        price: price,
      );

      if (!itemResult['success']) {
        _showSnackbar(itemResult['message'], Colors.red);
        setState(() => _isLoading = false);
        return;
      }

      final itemId = widget.item?['id']?.toString() ?? itemResult['data']['item_id']?.toString();
      if (itemId != null) {
        final details = _setengahJadiDetails.map((detail) {
          return ItemSetengahJadiDetail(
            itemId: int.parse(itemId),
            stjId: detail['stjId'],
            qty: detail['qty'].toDouble(),
          );
        }).toList();

        final detailResult = await ItemService.updateItemSetengahJadiDetails(
          itemId: int.parse(itemId),
          details: details,
        );

        if (!detailResult['success']) {
          _showSnackbar(detailResult['message'], Colors.orange);
        }
      }

      _showSnackbar('Item berhasil disimpan!', Colors.green);
      widget.onItemSaved();
      Navigator.pop(context);
    } catch (e) {
      _showSnackbar('Error: ${e.toString()}', Colors.red);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.item != null;

    return BaseLayout(
      title: isEdit ? 'Edit Item' : 'Tambah Item',
      showBackButton: true,
      showSidebar: true,
      isFormScreen: true,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Form(
          key: _formKey, // PASTIKAN FORM KEY DI SINI
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                padding: EdgeInsets.zero,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight,
                  ),
                  child: IntrinsicHeight(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Form Header (nama, kategori, harga)
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.03),
                                blurRadius: 3,
                                offset: Offset(0, 1),
                              ),
                            ],
                          ),
                          padding: EdgeInsets.all(16),
                          child: Column(
                            children: [
                              // Nama Item
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Nama Item',
                                    style: GoogleFonts.montserrat(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  SizedBox(height: 6),
                                  Container(
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade50,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: Colors.grey.shade300, width: 1),
                                    ),
                                    padding: EdgeInsets.symmetric(horizontal: 12),
                                    alignment: Alignment.centerLeft,
                                    child: TextFormField(
                                      controller: _nameController,
                                      autofocus: true,
                                      style: GoogleFonts.montserrat(fontSize: 13),
                                      decoration: InputDecoration(
                                        hintText: 'Masukkan nama item...',
                                        hintStyle: GoogleFonts.montserrat(
                                          fontSize: 12,
                                          color: Colors.grey.shade500,
                                        ),
                                        border: InputBorder.none,
                                        isDense: true,
                                        contentPadding: EdgeInsets.zero,
                                      ),
                                      validator: (value) {
                                        if (value == null || value.trim().isEmpty) {
                                          return 'Nama harus diisi';
                                        }
                                        return null;
                                      },
                                    ),
                                  ),
                                ],
                              ),

                              SizedBox(height: 16),

                              // Kategori
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Kategori',
                                    style: GoogleFonts.montserrat(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  SizedBox(height: 6),
                                  Container(
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade50,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: Colors.grey.shade300, width: 1),
                                    ),
                                    padding: EdgeInsets.symmetric(horizontal: 12),
                                    child: DropdownButtonHideUnderline(
                                      child: DropdownButton<String>(
                                        value: _selectedCategory,
                                        items: widget.categories.map((category) {
                                          final nama = category['ct_nama'] as String;
                                          return DropdownMenuItem<String>(
                                            value: nama,
                                            child: Container(
                                              padding: EdgeInsets.symmetric(vertical: 4),
                                              child: Text(
                                                nama,
                                                style: GoogleFonts.montserrat(
                                                  fontSize: 12,
                                                  color: Colors.black87,
                                                ),
                                              ),
                                            ),
                                          );
                                        }).toList(),
                                        onChanged: (value) {
                                          setState(() => _selectedCategory = value);
                                        },
                                        style: GoogleFonts.montserrat(fontSize: 12),
                                        icon: Icon(Icons.arrow_drop_down, size: 18, color: Colors.grey.shade600),
                                        isExpanded: true,
                                        dropdownColor: Colors.white,
                                        borderRadius: BorderRadius.circular(8),
                                        elevation: 2,
                                        hint: Text(
                                          'Pilih kategori...',
                                          style: GoogleFonts.montserrat(
                                            fontSize: 12,
                                            color: Colors.grey.shade500,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),

                              SizedBox(height: 16),

                              // Harga
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Harga',
                                    style: GoogleFonts.montserrat(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  SizedBox(height: 6),
                                  Container(
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade50,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: Colors.grey.shade300, width: 1),
                                    ),
                                    padding: EdgeInsets.symmetric(horizontal: 12),
                                    alignment: Alignment.centerLeft,
                                    child: TextFormField(
                                      controller: _priceController,
                                      keyboardType: TextInputType.number,
                                      style: GoogleFonts.montserrat(fontSize: 13),
                                      decoration: InputDecoration(
                                        hintText: 'Masukkan harga...',
                                        hintStyle: GoogleFonts.montserrat(
                                          fontSize: 12,
                                          color: Colors.grey.shade500,
                                        ),
                                        border: InputBorder.none,
                                        isDense: true,
                                        contentPadding: EdgeInsets.zero,
                                      ),
                                      validator: (value) {
                                        if (value == null || value.trim().isEmpty) {
                                          return 'Harga harus diisi';
                                        }
                                        final price = double.tryParse(value.replaceAll(',', ''));
                                        if (price == null || price <= 0) {
                                          return 'Harga harus angka dan lebih dari 0';
                                        }
                                        return null;
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        SizedBox(height: 16),

                        // Section: Setengah Jadi Details
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.03),
                                blurRadius: 3,
                                offset: Offset(0, 1),
                              ),
                            ],
                          ),
                          padding: EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Item Setengah Jadi',
                                    style: GoogleFonts.montserrat(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  if (_isLoadingDetails)
                                    SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Color(0xFFF6A918),
                                      ),
                                    ),
                                ],
                              ),
                              SizedBox(height: 8),

                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  onPressed: _showAddSetengahJadiDialog,
                                  icon: Icon(Icons.add, size: 14, color: Color(0xFFF6A918)),
                                  label: Text(
                                    'TAMBAH ITEM SETENGAH JADI',
                                    style: GoogleFonts.montserrat(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFFF6A918),
                                    ),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    side: BorderSide(color: Color(0xFFF6A918), width: 1),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    padding: EdgeInsets.symmetric(vertical: 10),
                                  ),
                                ),
                              ),

                              SizedBox(height: 12),

                              // List Setengah Jadi
                              if (_setengahJadiDetails.isEmpty)
                                Container(
                                  padding: EdgeInsets.symmetric(vertical: 20),
                                  child: Column(
                                    children: [
                                      Icon(
                                        Icons.construction_outlined,
                                        size: 36,
                                        color: Colors.grey.shade300,
                                      ),
                                      SizedBox(height: 8),
                                      Text(
                                        'Belum ada bahan setengah jadi',
                                        style: GoogleFonts.montserrat(
                                          fontSize: 11,
                                          color: Colors.grey.shade500,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              else
                                Column(
                                  children: _setengahJadiDetails.asMap().entries.map((entry) {
                                    final index = entry.key;
                                    final detail = entry.value;

                                    return Container(
                                      margin: EdgeInsets.only(bottom: 8),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade50,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: Colors.grey.shade200, width: 1),
                                      ),
                                      child: Material(
                                        color: Colors.transparent,
                                        child: ListTile(
                                          contentPadding: EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 8,
                                          ),
                                          leading: Container(
                                            width: 32,
                                            height: 32,
                                            decoration: BoxDecoration(
                                              color: Colors.teal.shade50,
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Icon(
                                              Icons.construction_rounded,
                                              size: 14,
                                              color: Colors.teal.shade700,
                                            ),
                                          ),
                                          title: Text(
                                            detail['stjNama'],
                                            style: GoogleFonts.montserrat(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.black87,
                                            ),
                                          ),
                                          subtitle: Text(
                                            'ID: ${detail['stjId']}',
                                            style: GoogleFonts.montserrat(
                                              fontSize: 9,
                                              color: Colors.grey.shade600,
                                            ),
                                          ),
                                          trailing: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              // Qty dengan edit inline
                                              GestureDetector(
                                                onTap: () {
                                                  _showEditQtyDialog(index, detail['qty']);
                                                },
                                                child: Container(
                                                  padding: EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 4,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: Colors.orange.shade50,
                                                    borderRadius: BorderRadius.circular(4),
                                                    border: Border.all(
                                                      color: Colors.orange.shade100,
                                                      width: 1,
                                                    ),
                                                  ),
                                                  child: Text(
                                                    'Qty: ${detail['qty'].toInt()}',
                                                    style: GoogleFonts.montserrat(
                                                      fontSize: 9,
                                                      fontWeight: FontWeight.w700,
                                                      color: Colors.orange.shade700,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              SizedBox(width: 8),
                                              IconButton(
                                                icon: Icon(
                                                  Icons.delete_outline,
                                                  size: 14,
                                                  color: Colors.red.shade400,
                                                ),
                                                onPressed: () {
                                                  _removeSetengahJadiDetail(index);
                                                },
                                                padding: EdgeInsets.zero,
                                                constraints: BoxConstraints(minWidth: 30),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                            ],
                          ),
                        ),

                        Spacer(),

                        // Save Button
                        Container(
                          margin: EdgeInsets.only(
                            top: 16,
                            bottom: MediaQuery.of(context).viewInsets.bottom > 0
                                ? MediaQuery.of(context).viewInsets.bottom + 8
                                : 8,
                          ),
                          child: SizedBox(
                            width: double.infinity,
                            height: 42,
                            child: ElevatedButton.icon(
                              onPressed: _isLoading ? null : _saveItem,
                              icon: _isLoading
                                  ? SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                                  : Icon(
                                isEdit ? Icons.edit : Icons.add,
                                size: 16,
                                color: Colors.white,
                              ),
                              label: Text(
                                isEdit ? 'UPDATE ITEM' : 'TAMBAH ITEM',
                                style: GoogleFonts.montserrat(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Color(0xFFF6A918),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  void _showEditQtyDialog(int index, double currentQty) {
    final qtyController = TextEditingController(text: currentQty.toInt().toString());

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Edit Jumlah',
          style: GoogleFonts.montserrat(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: TextField(
          controller: qtyController,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: InputDecoration(
            labelText: 'Qty',
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              final newQty = int.tryParse(qtyController.text.trim()) ?? 0;
              if (newQty > 0) {
                _updateSetengahJadiQty(index, newQty);
                Navigator.pop(context);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Qty harus lebih dari 0'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: Text('Simpan'),
          ),
        ],
      ),
    );
  }
}

// class SetengahJadiSelectionDialog extends StatefulWidget {
//   final List<SetengahJadi> setengahJadiList;
//   final SetengahJadi? selectedSetengahJadi;
//
//   const SetengahJadiSelectionDialog({
//     super.key,
//     required this.setengahJadiList,
//     this.selectedSetengahJadi, required List<SetengahJadi> alreadySelectedItems,
//   });
//
//   @override
//   State<SetengahJadiSelectionDialog> createState() =>
//       _SetengahJadiSelectionDialogState();
// }
//
// class _SetengahJadiSelectionDialogState extends State<SetengahJadiSelectionDialog> {
//   final TextEditingController _searchController = TextEditingController();
//   List<SetengahJadi> _filteredItems = [];
//
//   @override
//   void initState() {
//     super.initState();
//     _filteredItems = widget.setengahJadiList;
//   }
//
//   void _filterItems(String query) {
//     setState(() {
//       _filteredItems = widget.setengahJadiList.where((item) {
//         return item.stjNama.toLowerCase().contains(query.toLowerCase());
//       }).toList();
//     });
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Dialog(
//       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//       backgroundColor: Colors.white,
//       elevation: 4,
//       child: Container(
//         height: 420,
//         child: Column(
//           children: [
//             Container(
//               padding: EdgeInsets.all(16),
//               decoration: BoxDecoration(
//                 color: Colors.grey.shade50,
//                 borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
//                 border: Border(bottom: BorderSide(color: Colors.grey.shade200, width: 1)),
//               ),
//               child: Row(
//                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                 children: [
//                   Text(
//                     'Pilih Setengah Jadi',
//                     style: GoogleFonts.montserrat(
//                       fontSize: 14,
//                       fontWeight: FontWeight.w600,
//                       color: Colors.black87,
//                     ),
//                   ),
//                   IconButton(
//                     icon: Icon(Icons.close, size: 18, color: Colors.grey.shade600),
//                     onPressed: () => Navigator.pop(context),
//                     padding: EdgeInsets.zero,
//                     constraints: BoxConstraints(minWidth: 30, minHeight: 30),
//                     splashRadius: 18,
//                   ),
//                 ],
//               ),
//             ),
//
//             // Search Bar
//             Padding(
//               padding: EdgeInsets.all(12),
//               child: Container(
//                 height: 34,
//                 padding: EdgeInsets.symmetric(horizontal: 10),
//                 decoration: BoxDecoration(
//                   color: Colors.white,
//                   borderRadius: BorderRadius.circular(8),
//                   border: Border.all(color: Colors.grey.shade300, width: 1),
//                   boxShadow: [
//                     BoxShadow(
//                       color: Colors.black.withOpacity(0.02),
//                       blurRadius: 2,
//                       offset: Offset(0, 1),
//                     ),
//                   ],
//                 ),
//                 child: Row(
//                   children: [
//                     Icon(Icons.search, size: 14, color: Colors.grey.shade500),
//                     SizedBox(width: 6),
//                     Expanded(
//                       child: TextField(
//                         controller: _searchController,
//                         autofocus: true,
//                         decoration: InputDecoration(
//                           hintText: 'Cari setengah jadi...',
//                           hintStyle: GoogleFonts.montserrat(
//                             fontSize: 11,
//                             color: Colors.grey.shade500,
//                           ),
//                           border: InputBorder.none,
//                           isDense: true,
//                         ),
//                         style: GoogleFonts.montserrat(fontSize: 11),
//                         onChanged: _filterItems,
//                       ),
//                     ),
//                     if (_searchController.text.isNotEmpty)
//                       IconButton(
//                         icon: Icon(Icons.clear, size: 12, color: Colors.grey.shade500),
//                         onPressed: () {
//                           _searchController.clear();
//                           _filterItems('');
//                         },
//                         padding: EdgeInsets.zero,
//                         constraints: BoxConstraints(minWidth: 20),
//                       ),
//                   ],
//                 ),
//               ),
//             ),
//
//             // Info jumlah hasil
//             Padding(
//               padding: EdgeInsets.symmetric(horizontal: 12),
//               child: Row(
//                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                 children: [
//                   Text(
//                     'Hasil: ${_filteredItems.length} item${_filteredItems.length != 1 ? 's' : ''}',
//                     style: GoogleFonts.montserrat(
//                       fontSize: 10,
//                       color: Colors.grey.shade600,
//                       fontWeight: FontWeight.w500,
//                     ),
//                   ),
//                   if (widget.selectedSetengahJadi != null)
//                     Container(
//                       padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
//                       decoration: BoxDecoration(
//                         color: Colors.orange.shade50,
//                         borderRadius: BorderRadius.circular(4),
//                         border: Border.all(color: Colors.orange.shade100, width: 1),
//                       ),
//                       child: Text(
//                         'Dipilih: ${widget.selectedSetengahJadi!.stjNama}',
//                         style: GoogleFonts.montserrat(
//                           fontSize: 9,
//                           color: Colors.orange.shade700,
//                           fontWeight: FontWeight.w500,
//                         ),
//                         maxLines: 1,
//                         overflow: TextOverflow.ellipsis,
//                       ),
//                     ),
//                 ],
//               ),
//             ),
//
//             SizedBox(height: 8),
//
//             // List Items
//             Expanded(
//               child: _filteredItems.isEmpty
//                   ? Center(
//                 child: Column(
//                   mainAxisAlignment: MainAxisAlignment.center,
//                   children: [
//                     Icon(
//                       Icons.construction_outlined,
//                       size: 36,
//                       color: Colors.grey.shade400,
//                     ),
//                     SizedBox(height: 8),
//                     Text(
//                       _searchController.text.isEmpty
//                           ? 'Tidak ada data setengah jadi'
//                           : 'Setengah jadi tidak ditemukan',
//                       style: GoogleFonts.montserrat(
//                         fontSize: 12,
//                         color: Colors.grey.shade500,
//                       ),
//                     ),
//                   ],
//                 ),
//               )
//                   : ListView.builder(
//                 padding: EdgeInsets.symmetric(horizontal: 12),
//                 itemCount: _filteredItems.length,
//                 itemBuilder: (context, index) {
//                   final item = _filteredItems[index];
//                   final isSelected = widget.selectedSetengahJadi?.stjId == item.stjId;
//
//                   return Container(
//                     margin: EdgeInsets.only(bottom: 6),
//                     decoration: BoxDecoration(
//                       color: isSelected ? Colors.orange.shade50 : Colors.white,
//                       borderRadius: BorderRadius.circular(8),
//                       border: Border.all(
//                         color: isSelected ? Colors.orange.shade200 : Colors.grey.shade200,
//                         width: 1,
//                       ),
//                       boxShadow: isSelected
//                           ? [
//                         BoxShadow(
//                           color: Colors.orange.shade100.withOpacity(0.3),
//                           blurRadius: 4,
//                           offset: Offset(0, 1),
//                         )
//                       ]
//                           : [
//                         BoxShadow(
//                           color: Colors.black.withOpacity(0.02),
//                           blurRadius: 2,
//                           offset: Offset(0, 1),
//                         )
//                       ],
//                     ),
//                     child: Material(
//                       color: Colors.transparent,
//                       child: InkWell(
//                         borderRadius: BorderRadius.circular(8),
//                         onTap: () => Navigator.pop(context, item),
//                         splashColor: Colors.orange.shade100,
//                         highlightColor: Colors.orange.shade50.withOpacity(0.3),
//                         child: Padding(
//                           padding: EdgeInsets.all(10),
//                           child: Row(
//                             children: [
//                               // Icon dengan badge
//                               Stack(
//                                 children: [
//                                   Container(
//                                     width: 30,
//                                     height: 30,
//                                     decoration: BoxDecoration(
//                                       color: isSelected
//                                           ? Colors.orange.shade100
//                                           : Colors.teal.shade50,
//                                       borderRadius: BorderRadius.circular(6),
//                                     ),
//                                     child: Icon(
//                                       Icons.construction_rounded,
//                                       size: 14,
//                                       color: isSelected
//                                           ? Colors.orange.shade700
//                                           : Colors.teal.shade700,
//                                     ),
//                                   ),
//                                   if (item.stjStock <= 5)
//                                     Positioned(
//                                       top: -3,
//                                       right: -3,
//                                       child: Container(
//                                         width: 12,
//                                         height: 12,
//                                         decoration: BoxDecoration(
//                                           color: Colors.red.shade600,
//                                           borderRadius: BorderRadius.circular(6),
//                                           border: Border.all(
//                                             color: Colors.white,
//                                             width: 1.5,
//                                           ),
//                                         ),
//                                       ),
//                                     ),
//                                 ],
//                               ),
//                               SizedBox(width: 12),
//
//                               // Detail
//                               Expanded(
//                                 child: Column(
//                                   crossAxisAlignment: CrossAxisAlignment.start,
//                                   children: [
//                                     Text(
//                                       item.stjNama,
//                                       style: GoogleFonts.montserrat(
//                                         fontSize: 11,
//                                         fontWeight: FontWeight.w600,
//                                         color: isSelected
//                                             ? Colors.orange.shade800
//                                             : Colors.black87,
//                                       ),
//                                       maxLines: 1,
//                                       overflow: TextOverflow.ellipsis,
//                                     ),
//                                     SizedBox(height: 2),
//                                     Row(
//                                       children: [
//                                         Container(
//                                           padding: EdgeInsets.symmetric(
//                                             horizontal: 4,
//                                             vertical: 1,
//                                           ),
//                                           decoration: BoxDecoration(
//                                             color: Colors.grey.shade100,
//                                             borderRadius: BorderRadius.circular(3),
//                                           ),
//                                           child: Text(
//                                             'ID: ${item.stjId}',
//                                             style: GoogleFonts.montserrat(
//                                               fontSize: 8,
//                                               color: Colors.grey.shade700,
//                                             ),
//                                           ),
//                                         ),
//                                         SizedBox(width: 6),
//                                         Container(
//                                           padding: EdgeInsets.symmetric(
//                                             horizontal: 4,
//                                             vertical: 1,
//                                           ),
//                                           decoration: BoxDecoration(
//                                             color: item.stjStock <= 5
//                                                 ? Colors.red.shade50
//                                                 : Colors.green.shade50,
//                                             borderRadius: BorderRadius.circular(3),
//                                             border: Border.all(
//                                               color: item.stjStock <= 5
//                                                   ? Colors.red.shade100
//                                                   : Colors.green.shade100,
//                                               width: 1,
//                                             ),
//                                           ),
//                                           child: Text(
//                                             'STOK: ${item.stjStock}',
//                                             style: GoogleFonts.montserrat(
//                                               fontSize: 8,
//                                               fontWeight: FontWeight.w700,
//                                               color: item.stjStock <= 5
//                                                   ? Colors.red.shade700
//                                                   : Colors.green.shade700,
//                                             ),
//                                           ),
//                                         ),
//                                       ],
//                                     ),
//                                   ],
//                                 ),
//                               ),
//
//                               // Checkmark untuk selected
//                               if (isSelected)
//                                 Icon(
//                                   Icons.check_circle,
//                                   size: 16,
//                                   color: Colors.orange.shade700,
//                                 ),
//                             ],
//                           ),
//                         ),
//                       ),
//                     ),
//                   );
//                 },
//               ),
//             ),
//
//             // Footer dengan buttons
//             Container(
//               padding: EdgeInsets.all(12),
//               decoration: BoxDecoration(
//                 color: Colors.grey.shade50,
//                 borderRadius: BorderRadius.vertical(bottom: Radius.circular(12)),
//                 border: Border(top: BorderSide(color: Colors.grey.shade200, width: 1)),
//               ),
//               child: Row(
//                 children: [
//                   Expanded(
//                     child: OutlinedButton(
//                       onPressed: () => Navigator.pop(context, null),
//                       style: OutlinedButton.styleFrom(
//                         side: BorderSide(color: Colors.grey.shade300),
//                         shape: RoundedRectangleBorder(
//                           borderRadius: BorderRadius.circular(8),
//                         ),
//                         padding: EdgeInsets.symmetric(vertical: 8),
//                       ),
//                       child: Text(
//                         'Hapus Pilihan',
//                         style: GoogleFonts.montserrat(
//                           fontSize: 11,
//                           fontWeight: FontWeight.w500,
//                           color: Colors.grey.shade700,
//                         ),
//                       ),
//                     ),
//                   ),
//                   SizedBox(width: 8),
//                   Expanded(
//                     child: ElevatedButton(
//                       onPressed: () => Navigator.pop(context),
//                       style: ElevatedButton.styleFrom(
//                         backgroundColor: Colors.grey.shade800,
//                         foregroundColor: Colors.white,
//                         shape: RoundedRectangleBorder(
//                           borderRadius: BorderRadius.circular(8),
//                         ),
//                         padding: EdgeInsets.symmetric(vertical: 8),
//                         elevation: 0,
//                       ),
//                       child: Text(
//                         'Tutup',
//                         style: GoogleFonts.montserrat(
//                           fontSize: 11,
//                           fontWeight: FontWeight.w500,
//                         ),
//                       ),
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }