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

  // Color Palette - Minimalis & Elegan
  static const Color _primaryDark = Color(0xFF1A202C);
  static const Color _surfaceWhite = Color(0xFFFFFFFF);
  static const Color _bgLight = Color(0xFFF7F9FC);
  static const Color _textPrimary = Color(0xFF1A202C);
  static const Color _textSecondary = Color(0xFF64748B);
  static const Color _textTertiary = Color(0xFF94A3B8);
  static const Color _borderColor = Color(0xFFE2E8F0);
  static const Color _accentBlue = Color(0xFF3B82F6);
  static const Color _accentRed = Color(0xFFEF4444);
  static const Color _accentGreen = Color(0xFF10B981);
  static const Color _accentOrange = Color(0xFFF59E0B);

  String? _selectedCategory;
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

      // Pastikan kategori yang tersimpan ada di list categories
      final savedCategory = widget.item!['Category']?.toString();
      final categoryExists = widget.categories.any((c) => c['ct_nama'] == savedCategory);
      _selectedCategory = categoryExists ? savedCategory : null;

      _loadItemSetengahJadiDetails();
    }
    _loadSetengahJadi();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _loadSetengahJadi() async {
    setState(() => _isLoadingSetengahJadi = true);
    try {
      final items = await SetengahJadiService.getSetengahJadi();
      setState(() => _setengahJadiList = items);
    } catch (e) {
      // Jangan tampilkan toast error, biarkan list kosong
      print('Error loading setengah jadi: $e'); // <-- DEBUG SAJA
      setState(() {
        _setengahJadiList = [];
      });
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
      // Jangan tampilkan toast error, ini normal jika item tidak punya detail
      // _showSnackbar('Gagal memuat detail', isError: true); // <-- HAPUS/KOMENTAR
      setState(() {
        _setengahJadiDetails = []; // Kosongkan
      });
    } finally {
      setState(() => _isLoadingDetails = false);
    }
  }

  void _addSetengahJadiDetail(SetengahJadi setengahJadi, int qty) {
    // Cek apakah sudah ada
    final existingIndex = _setengahJadiDetails.indexWhere((d) => d['stjId'] == setengahJadi.stjId);
    if (existingIndex != -1) {
      _showSnackbar('Bahan sudah ada dalam list', isError: true);
      return;
    }

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

  void _showSnackbar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.montserrat(fontSize: 12, color: Colors.white)),
        backgroundColor: isError ? _accentRed : _accentGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _saveItem() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCategory == null) {
      _showSnackbar('Kategori harus dipilih', isError: true);
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
        _showSnackbar(itemResult['message'], isError: true);
        setState(() => _isLoading = false);
        return;
      }

      // Hanya update detail jika ada item yang dipilih
      if (_setengahJadiDetails.isNotEmpty) {
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
            _showSnackbar(detailResult['message'], isError: true);
            setState(() => _isLoading = false);
            return; // <-- JANGAN LANJUT JIKA GAGAL
          }
        }
      }

      _showSnackbar('Item berhasil disimpan');
      widget.onItemSaved();
      Navigator.pop(context);
    } catch (e) {
      _showSnackbar('Error: ${e.toString()}', isError: true);
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
      child: Container(
        color: _bgLight,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Informasi Item Card
                      _buildSectionCard(
                        title: 'Informasi Item',
                        icon: Icons.inventory_2_outlined,
                        children: [
                          // 1 Row: Nama | Kategori | Harga
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 3,
                                child: _buildTextField(
                                  label: 'Nama Item',
                                  controller: _nameController,
                                  hint: 'Nama item',
                                  validator: (v) => v?.trim().isEmpty == true ? 'Wajib diisi' : null,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                flex: 2,
                                child: _buildDropdownField(
                                  label: 'Kategori',
                                  value: _selectedCategory,
                                  hint: 'Pilih',
                                  items: widget.categories.map((c) => c['ct_nama'] as String).toList(),
                                  onChanged: (v) => setState(() => _selectedCategory = v),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                flex: 2,
                                child: _buildPriceField(
                                  label: 'Harga',
                                  controller: _priceController,
                                  hint: '0',
                                  validator: (v) {
                                    if (v == null || v.isEmpty) return 'Harga harus diisi';
                                    final n = double.tryParse(v.replaceAll(',', ''));
                                    if (n == null || n <= 0) return 'Harga > 0';
                                    return null;
                                  },
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Bahan Setengah Jadi Card
                      _buildSectionCard(
                        title: 'Bahan Setengah Jadi',
                        icon: Icons.precision_manufacturing_outlined,
                        isLoading: _isLoadingDetails,
                        actions: [
                          _buildAddButton(
                            onPressed: _showAddSetengahJadiDialog,
                          ),
                        ],
                        children: [
                          if (_setengahJadiDetails.isEmpty)
                            _buildEmptyState('Belum ada bahan setengah jadi')
                          else
                            ..._setengahJadiDetails.asMap().entries.map((entry) {
                              final index = entry.key;
                              final detail = entry.value;
                              return _buildSetengahJadiItem(
                                detail: detail,
                                onTap: () => _showEditQtyDialog(index, detail['qty']),
                                onDelete: () => _removeSetengahJadiDetail(index),
                              );
                            }).toList(),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Bottom Button
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _surfaceWhite,
                border: Border(top: BorderSide(color: _borderColor)),
              ),
              child: _buildSaveButton(isEdit: isEdit),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPriceField({
    required String label,
    required TextEditingController controller,
    String? hint,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.montserrat(fontSize: 10, fontWeight: FontWeight.w500, color: _textSecondary)),
        const SizedBox(height: 4),
        Container(
          height: 38,
          decoration: BoxDecoration(
            color: _bgLight,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: _borderColor),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.only(left: 10, right: 4),
                child: Text('Rp', style: GoogleFonts.montserrat(fontSize: 12, fontWeight: FontWeight.w500, color: _textSecondary)),
              ),
              Expanded(
                child: TextFormField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.left,
                  style: GoogleFonts.montserrat(fontSize: 12, color: _textPrimary),
                  decoration: InputDecoration(
                    hintText: hint,
                    hintStyle: GoogleFonts.montserrat(fontSize: 12, color: _textTertiary),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0), // <-- PASTIKAN INI
                    isDense: true,
                  ),
                  validator: validator,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
    List<Widget> actions = const [],
    bool isLoading = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: _surfaceWhite,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: _bgLight,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
              border: Border(bottom: BorderSide(color: _borderColor)),
            ),
            child: Row(
              children: [
                Icon(icon, size: 16, color: _textSecondary),
                const SizedBox(width: 8),
                Text(title, style: GoogleFonts.montserrat(fontSize: 12, fontWeight: FontWeight.w600, color: _textPrimary)),
                const Spacer(),
                if (isLoading)
                  const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                else
                  ...actions,
              ],
            ),
          ),
          // Content
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(children: children),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    String? hint,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.montserrat(fontSize: 10, fontWeight: FontWeight.w500, color: _textSecondary)),
        const SizedBox(height: 4),
        Container(
          height: maxLines == 1 ? 38 : null,
          decoration: BoxDecoration(
            color: _bgLight,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: _borderColor),
          ),
          child: Center( // <-- TAMBAHKAN CENTER UNTUK VERTICAL CENTER
            child: TextFormField(
              controller: controller,
              keyboardType: keyboardType,
              textAlign: TextAlign.left, // <-- HORIZONTAL RATA KIRI
              maxLines: maxLines,
              style: GoogleFonts.montserrat(fontSize: 12, color: _textPrimary),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: GoogleFonts.montserrat(fontSize: 12, color: _textTertiary),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 0), // <-- VERTICAL 0 KARENA SUDAH CENTER
                isDense: true,
              ),
              validator: validator,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdownField({
    required String label,
    required String? value,
    required String hint,
    required List<String> items,
    required Function(String?) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.montserrat(fontSize: 10, fontWeight: FontWeight.w500, color: _textSecondary)),
        const SizedBox(height: 4),
        Container(
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: _bgLight,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: _borderColor),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: items.contains(value) ? value : null,
              isExpanded: true,
              hint: Text(hint, style: GoogleFonts.montserrat(fontSize: 12, color: _textTertiary)),
              items: items.map((item) {
                return DropdownMenuItem<String>(
                  value: item,
                  child: Text(item, style: GoogleFonts.montserrat(fontSize: 12, color: _textPrimary)),
                );
              }).toList(),
              onChanged: onChanged,
              icon: Icon(Icons.arrow_drop_down, color: _textSecondary, size: 18),
              dropdownColor: _surfaceWhite,
              borderRadius: BorderRadius.circular(6),
              menuMaxHeight: 300,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAddButton({required VoidCallback onPressed}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: _accentBlue,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.add, size: 14, color: Colors.white),
              const SizedBox(width: 4),
              Text('Tambah', style: GoogleFonts.montserrat(fontSize: 10, fontWeight: FontWeight.w500, color: Colors.white)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inbox_outlined, size: 36, color: _textTertiary),
            const SizedBox(height: 8),
            Text(message, style: GoogleFonts.montserrat(fontSize: 11, color: _textSecondary)),
          ],
        ),
      ),
    );
  }

  Widget _buildSetengahJadiItem({
    required Map<String, dynamic> detail,
    required VoidCallback onTap,
    required VoidCallback onDelete,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(10),
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
              color: _accentBlue.withOpacity(0.08),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(Icons.precision_manufacturing_outlined, size: 15, color: _accentBlue),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(detail['stjNama'], style: GoogleFonts.montserrat(fontSize: 12, fontWeight: FontWeight.w500, color: _textPrimary)),
                const SizedBox(height: 2),
                Text('ID: ${detail['stjId']}', style: GoogleFonts.montserrat(fontSize: 10, color: _textSecondary)),
              ],
            ),
          ),
          GestureDetector(
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _accentOrange.withOpacity(0.08),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: _accentOrange.withOpacity(0.2)),
              ),
              child: Text('${detail['qty'].toInt()}', style: GoogleFonts.montserrat(fontSize: 12, fontWeight: FontWeight.w600, color: _accentOrange)),
            ),
          ),
          const SizedBox(width: 6),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onDelete,
              borderRadius: BorderRadius.circular(4),
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Icon(Icons.delete_outlined, size: 16, color: _accentRed),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSaveButton({required bool isEdit}) {
    return SizedBox(
      width: double.infinity,
      height: 40,
      child: Material(
        color: _primaryDark,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: _isLoading ? null : _saveItem,
          borderRadius: BorderRadius.circular(8),
          child: Center(
            child: _isLoading
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(isEdit ? Icons.edit_outlined : Icons.add, size: 16, color: Colors.white),
                const SizedBox(width: 8),
                Text(
                  isEdit ? 'UPDATE ITEM' : 'TAMBAH ITEM',
                  style: GoogleFonts.montserrat(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
                ),
              ],
            ),
          ),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: _accentOrange.withOpacity(0.08),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(Icons.edit_outlined, size: 16, color: _accentOrange),
            ),
            const SizedBox(width: 8),
            Text('Edit Jumlah', style: GoogleFonts.montserrat(fontSize: 14, fontWeight: FontWeight.w600, color: _textPrimary)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _setengahJadiDetails[index]['stjNama'],
              style: GoogleFonts.montserrat(fontSize: 12, color: _textSecondary),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildQtyButton(Icons.remove, () {
                  if (tempQuantity > 1) {
                    tempQuantity--;
                    qtyController.text = tempQuantity.toString();
                  }
                }),
                const SizedBox(width: 8),
                SizedBox(
                  width: 80,
                  height: 40,
                  child: Container(
                    decoration: BoxDecoration(
                      color: _bgLight,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: _borderColor),
                    ),
                    child: TextField(
                      controller: qtyController,
                      textAlign: TextAlign.center,
                      keyboardType: TextInputType.number,
                      style: GoogleFonts.montserrat(fontSize: 14, fontWeight: FontWeight.w600, color: _textPrimary),
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8), // <-- TAMBAHKAN PADDING
                        isDense: true,
                      ),
                      onChanged: (v) => tempQuantity = int.tryParse(v) ?? tempQuantity,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _buildQtyButton(Icons.add, () {
                  tempQuantity++;
                  qtyController.text = tempQuantity.toString();
                }),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Batal', style: GoogleFonts.montserrat(fontSize: 12, color: _textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              if (tempQuantity > 0) {
                _updateSetengahJadiQty(index, tempQuantity);
                Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryDark,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            ),
            child: Text('Simpan', style: GoogleFonts.montserrat(fontSize: 12, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }

  Widget _buildQtyButton(IconData icon, VoidCallback onPressed) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: _bgLight,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: _borderColor),
          ),
          child: Icon(icon, size: 18, color: _textPrimary),
        ),
      ),
    );
  }
}