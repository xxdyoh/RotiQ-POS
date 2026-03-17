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

  // Warna konsisten dengan POS Screen dan ItemListScreen
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
              color == _accentMint ? Icons.check_circle : Icons.error_outline,
              color: Colors.white,
              size: 16,
            ),
            const SizedBox(width: 6),
            Expanded(child: Text(message, style: GoogleFonts.montserrat(fontSize: 12))),
          ],
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        margin: const EdgeInsets.all(12),
      ),
    );
  }

  Future<void> _saveItem() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCategory == null) {
      _showSnackbar('Kategori harus dipilih', _accentCoral);
      return;
    }

    setState(() => _isLoading = true);

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
        _showSnackbar(itemResult['message'], _accentCoral);
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
          details: details.map((d) => d.toJson()).toList(),
        );

        if (!detailResult['success']) {
          _showSnackbar(detailResult['message'], _accentGold);
        }
      }

      _showSnackbar('Item berhasil disimpan!', _accentMint);
      widget.onItemSaved();
      Navigator.pop(context);
    } catch (e) {
      _showSnackbar('Error: ${e.toString()}', _accentCoral);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.item != null;
    final isMobile = MediaQuery.of(context).size.width < 600;

    return BaseLayout(
      title: isEdit ? 'Edit Item' : 'Tambah Item',
      showBackButton: true,
      showSidebar: true,
      isFormScreen: true,
      child: Container(
        color: _bgLight,
        child: Column(
          children: [
            // Header dengan gradient
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [_primaryDark, _primaryLight],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 6,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white.withOpacity(0.25)),
                    ),
                    child: Icon(
                      isEdit ? Icons.edit_note : Icons.add_box_rounded,
                      size: 18,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(width: 12),
                  Text(
                    isEdit ? 'Edit Item' : 'Tambah Item Baru',
                    style: GoogleFonts.montserrat(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: ListView(
                    children: [
                      // Card Informasi Item
                      Container(
                        decoration: BoxDecoration(
                          color: _bgCard,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: _borderColor),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.03),
                              blurRadius: 3,
                              offset: Offset(0, 1),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            // Header Card
                            Container(
                              padding: EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: _bgLight,
                                borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                                border: Border(bottom: BorderSide(color: _borderColor)),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 28,
                                    height: 28,
                                    decoration: BoxDecoration(
                                      color: _primaryDark.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Icon(
                                      Icons.inventory_2,
                                      size: 14,
                                      color: _primaryDark,
                                    ),
                                  ),
                                  SizedBox(width: 10),
                                  Text(
                                    'Informasi Item',
                                    style: GoogleFonts.montserrat(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: _textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            Padding(
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
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: _textSecondary,
                                        ),
                                      ),
                                      SizedBox(height: 6),
                                      Container(
                                        height: 40,
                                        decoration: BoxDecoration(
                                          color: _bgLight,
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: _borderColor),
                                        ),
                                        child: Center( // Tambahkan Center widget
                                          child: TextFormField(
                                            controller: _nameController,
                                            style: GoogleFonts.montserrat(
                                              fontSize: 12,
                                              color: _textPrimary,
                                            ),
                                            decoration: InputDecoration(
                                              hintText: 'Masukkan nama item',
                                              hintStyle: GoogleFonts.montserrat(
                                                fontSize: 11,
                                                color: _textSecondary.withOpacity(0.5),
                                              ),
                                              border: InputBorder.none,
                                              contentPadding: EdgeInsets.symmetric(horizontal: 12),
                                              isDense: true,
                                            ),
                                            validator: (value) {
                                              if (value == null || value.trim().isEmpty) {
                                                return 'Nama item harus diisi';
                                              }
                                              return null;
                                            },
                                          ),
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
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: _textSecondary,
                                        ),
                                      ),
                                      SizedBox(height: 6),
                                      Container(
                                        height: 40,
                                        padding: EdgeInsets.symmetric(horizontal: 12),
                                        decoration: BoxDecoration(
                                          color: _bgLight,
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: _borderColor),
                                        ),
                                        child: DropdownButtonHideUnderline(
                                          child: DropdownButton<String>(
                                            value: _selectedCategory,
                                            isExpanded: true,
                                            hint: Text(
                                              'Pilih kategori',
                                              style: GoogleFonts.montserrat(
                                                fontSize: 11,
                                                color: _textSecondary.withOpacity(0.5),
                                              ),
                                            ),
                                            items: widget.categories.map((category) {
                                              return DropdownMenuItem<String>(
                                                value: category['ct_nama'],
                                                child: Container(
                                                  padding: EdgeInsets.symmetric(vertical: 4),
                                                  child: Text(
                                                    category['ct_nama'],
                                                    style: GoogleFonts.montserrat(
                                                      fontSize: 11,
                                                      color: _textPrimary,
                                                    ),
                                                  ),
                                                ),
                                              );
                                            }).toList(),
                                            onChanged: (value) {
                                              setState(() {
                                                _selectedCategory = value;
                                              });
                                            },
                                            icon: Icon(
                                              Icons.arrow_drop_down,
                                              color: _textSecondary,
                                              size: 20,
                                            ),
                                            dropdownColor: _bgCard,
                                            borderRadius: BorderRadius.circular(8),
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
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: _textSecondary,
                                        ),
                                      ),
                                      SizedBox(height: 6),
                                      Container(
                                        height: 40,
                                        decoration: BoxDecoration(
                                          color: _bgLight,
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: _borderColor),
                                        ),
                                        child: Center( // Tambahkan Center widget
                                          child: TextFormField(
                                            controller: _priceController,
                                            keyboardType: TextInputType.number,
                                            style: GoogleFonts.montserrat(
                                              fontSize: 12,
                                              color: _textPrimary,
                                            ),
                                            decoration: InputDecoration(
                                              hintText: 'Masukkan harga',
                                              hintStyle: GoogleFonts.montserrat(
                                                fontSize: 11,
                                                color: _textSecondary.withOpacity(0.5),
                                              ),
                                              border: InputBorder.none,
                                              contentPadding: EdgeInsets.symmetric(horizontal: 12),
                                              isDense: true,
                                            ),
                                            validator: (value) {
                                              if (value == null || value.isEmpty) {
                                                return 'Harga harus diisi';
                                              }
                                              final number = double.tryParse(value.replaceAll(',', ''));
                                              if (number == null || number <= 0) {
                                                return 'Harga harus angka positif';
                                              }
                                              return null;
                                            },
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      SizedBox(height: 16),

                      // Card Setengah Jadi
                      Container(
                        decoration: BoxDecoration(
                          color: _bgCard,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: _borderColor),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.03),
                              blurRadius: 3,
                              offset: Offset(0, 1),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            // Header Card dengan loading
                            Container(
                              padding: EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: _bgLight,
                                borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                                border: Border(bottom: BorderSide(color: _borderColor)),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        width: 28,
                                        height: 28,
                                        decoration: BoxDecoration(
                                          color: _accentSky.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Icon(
                                          Icons.construction_rounded,
                                          size: 14,
                                          color: _accentSky,
                                        ),
                                      ),
                                      SizedBox(width: 10),
                                      Text(
                                        'Bahan Setengah Jadi',
                                        style: GoogleFonts.montserrat(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: _textPrimary,
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (_isLoadingDetails)
                                    SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: _accentGold,
                                      ),
                                    ),
                                ],
                              ),
                            ),

                            Padding(
                              padding: EdgeInsets.all(16),
                              child: Column(
                                children: [
                                  // Tombol Tambah
                                  SizedBox(
                                    width: double.infinity,
                                    child: OutlinedButton.icon(
                                      onPressed: _showAddSetengahJadiDialog,
                                      icon: Icon(
                                        Icons.add,
                                        size: 16,
                                        color: _accentGold,
                                      ),
                                      label: Text(
                                        'TAMBAH BAHAN SETENGAH JADI',
                                        style: GoogleFonts.montserrat(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: _accentGold,
                                        ),
                                      ),
                                      style: OutlinedButton.styleFrom(
                                        side: BorderSide(color: _accentGold),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        padding: EdgeInsets.symmetric(vertical: 12),
                                      ),
                                    ),
                                  ),

                                  if (_setengahJadiDetails.isNotEmpty) SizedBox(height: 16),

                                  // List Setengah Jadi
                                  if (_setengahJadiDetails.isEmpty)
                                    Container(
                                      padding: EdgeInsets.symmetric(vertical: 24),
                                      child: Column(
                                        children: [
                                          Icon(
                                            Icons.construction_outlined,
                                            size: 40,
                                            color: _borderColor,
                                          ),
                                          SizedBox(height: 8),
                                          Text(
                                            'Belum ada bahan setengah jadi',
                                            style: GoogleFonts.montserrat(
                                              fontSize: 11,
                                              color: _textSecondary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    )
                                  else
                                    ListView.separated(
                                      shrinkWrap: true,
                                      physics: NeverScrollableScrollPhysics(),
                                      itemCount: _setengahJadiDetails.length,
                                      separatorBuilder: (_, __) => SizedBox(height: 8),
                                      itemBuilder: (context, index) {
                                        final detail = _setengahJadiDetails[index];
                                        return Container(
                                          padding: EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: _bgLight,
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(color: _borderColor),
                                          ),
                                          child: Row(
                                            children: [
                                              Container(
                                                width: 32,
                                                height: 32,
                                                decoration: BoxDecoration(
                                                  color: _accentSky.withOpacity(0.1),
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: Icon(
                                                  Icons.construction_rounded,
                                                  size: 14,
                                                  color: _accentSky,
                                                ),
                                              ),
                                              SizedBox(width: 10),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      detail['stjNama'],
                                                      style: GoogleFonts.montserrat(
                                                        fontSize: 11,
                                                        fontWeight: FontWeight.w600,
                                                        color: _textPrimary,
                                                      ),
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                    SizedBox(height: 2),
                                                    Text(
                                                      'ID: ${detail['stjId']}',
                                                      style: GoogleFonts.montserrat(
                                                        fontSize: 9,
                                                        color: _textSecondary,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              // Qty
                                              GestureDetector(
                                                onTap: () => _showEditQtyDialog(index, detail['qty']),
                                                child: Container(
                                                  padding: EdgeInsets.symmetric(
                                                    horizontal: 10,
                                                    vertical: 4,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: _accentGold.withOpacity(0.1),
                                                    borderRadius: BorderRadius.circular(4),
                                                    border: Border.all(
                                                      color: _accentGold.withOpacity(0.3),
                                                    ),
                                                  ),
                                                  child: Text(
                                                    '${detail['qty'].toInt()}',
                                                    style: GoogleFonts.montserrat(
                                                      fontSize: 11,
                                                      fontWeight: FontWeight.w700,
                                                      color: _accentGold,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              SizedBox(width: 8),
                                              IconButton(
                                                icon: Icon(
                                                  Icons.delete_outline,
                                                  size: 18,
                                                  color: _accentCoral,
                                                ),
                                                onPressed: () => _removeSetengahJadiDetail(index),
                                                padding: EdgeInsets.zero,
                                                constraints: BoxConstraints(),
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Bottom Button
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _bgCard,
                border: Border(top: BorderSide(color: _borderColor)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8,
                    offset: Offset(0, -2),
                  ),
                ],
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
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _accentGold,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                    elevation: 2,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditQtyDialog(int index, double currentQty) {
    final qtyController = TextEditingController(text: currentQty.toInt().toString());
    int tempQuantity = currentQty.toInt();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        titlePadding: EdgeInsets.all(16),
        contentPadding: EdgeInsets.fromLTRB(16, 0, 16, 16),
        title: Row(
          children: [
            Container(
              padding: EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: _accentGold.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(
                Icons.edit_note,
                size: 16,
                color: _accentGold,
              ),
            ),
            SizedBox(width: 8),
            Text(
              'Edit Jumlah',
              style: GoogleFonts.montserrat(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: _textPrimary,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _setengahJadiDetails[index]['stjNama'],
              style: GoogleFonts.montserrat(
                fontSize: 11,
                color: _textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: _borderColor),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: IconButton(
                    icon: Icon(Icons.remove, size: 16, color: _primaryDark),
                    onPressed: () {
                      if (tempQuantity > 1) {
                        tempQuantity--;
                        qtyController.text = tempQuantity.toString();
                      }
                    },
                    padding: EdgeInsets.all(8),
                    constraints: BoxConstraints(minWidth: 36, minHeight: 36),
                  ),
                ),
                SizedBox(width: 8),
                Container(
                  width: 70,
                  height: 40,
                  decoration: BoxDecoration(
                    border: Border.all(color: _borderColor),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Center( // Tambahkan Center widget
                    child: TextField(
                      controller: qtyController,
                      textAlign: TextAlign.center,
                      keyboardType: TextInputType.number,
                      style: GoogleFonts.montserrat(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: _textPrimary,
                      ),
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 8),
                        isDense: true,
                      ),
                      onChanged: (value) {
                        final newQty = int.tryParse(value);
                        if (newQty != null && newQty > 0) {
                          tempQuantity = newQty;
                        }
                      },
                    ),
                  ),
                ),
                SizedBox(width: 8),
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: _borderColor),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: IconButton(
                    icon: Icon(Icons.add, size: 16, color: _primaryDark),
                    onPressed: () {
                      tempQuantity++;
                      qtyController.text = tempQuantity.toString();
                    },
                    padding: EdgeInsets.all(8),
                    constraints: BoxConstraints(minWidth: 36, minHeight: 36),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Batal',
              style: GoogleFonts.montserrat(
                fontSize: 11,
                color: _textSecondary,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              if (tempQuantity > 0) {
                _updateSetengahJadiQty(index, tempQuantity);
                Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _accentGold,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            child: Text(
              'Simpan',
              style: GoogleFonts.montserrat(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}