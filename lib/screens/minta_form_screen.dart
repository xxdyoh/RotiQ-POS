import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../services/minta_service.dart';
import '../widgets/base_layout.dart';
import 'add_item_modal_minta.dart';
import '../models/minta_model.dart';

class MintaFormScreen extends StatefulWidget {
  final Map<String, dynamic>? mintaHeader;
  final VoidCallback onMintaSaved;

  const MintaFormScreen({
    super.key,
    this.mintaHeader,
    required this.onMintaSaved,
  });

  @override
  State<MintaFormScreen> createState() => _MintaFormScreenState();
}

class _MintaFormScreenState extends State<MintaFormScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _keteranganController = TextEditingController();
  final Map<int, TextEditingController> _qtyControllers = {};
  final Map<int, TextEditingController> _ketControllers = {};

  final Color _primaryDark = const Color(0xFF2C3E50);
  final Color _primaryLight = const Color(0xFF34495E);
  final Color _accentGold = const Color(0xFFF6A918);
  final Color _accentMint = const Color(0xFF06D6A0);
  final Color _accentCoral = const Color(0xFFFF6B6B);
  final Color _accentSky = const Color(0xFF4CC9F0);

  final Color _primarySoft = const Color(0xFF2C3E50).withOpacity(0.1);
  final Color _accentGoldSoft = const Color(0xFFF6A918).withOpacity(0.1);
  final Color _accentMintSoft = const Color(0xFF06D6A0).withOpacity(0.1);

  final Color _bgSoft = const Color(0xFFF8FAFC);
  final Color _surfaceWhite = Colors.white;
  final Color _textDark = const Color(0xFF1A202C);
  final Color _textMedium = const Color(0xFF718096);
  final Color _textLight = const Color(0xFFA0AEC0);
  final Color _borderSoft = const Color(0xFFE2E8F0);
  final Color _shadowColor = const Color(0xFF2C3E50).withOpacity(0.1);

  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;
  bool _isSaving = false;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  List<MintaItem> _selectedItems = [];
  List<MintaItem> _filteredItems = [];

  String? _nomorMinta;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic));

    _animationController.forward();

    if (widget.mintaHeader != null) {
      _nomorMinta = widget.mintaHeader!['mt_nomor'];
      _selectedDate = DateTime.parse(widget.mintaHeader!['mt_tanggal']);
      _keteranganController.text = widget.mintaHeader!['mt_keterangan'] ?? '';

      _loadMintaDetail();
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _searchController.dispose();
    _keteranganController.dispose();
    _qtyControllers.values.forEach((controller) => controller.dispose());
    _ketControllers.values.forEach((controller) => controller.dispose());
    super.dispose();
  }

  Future<void> _loadMintaDetail() async {
    if (_nomorMinta == null) return;

    setState(() => _isLoading = true);

    try {
      final detail = await MintaService.getMintaDetail(_nomorMinta!);
      final details = List<Map<String, dynamic>>.from(detail['details']);

      setState(() {
        _selectedItems = details.map((detail) {
          return MintaItem(
            itemId: detail['mtd_brg_kode'],
            itemNama: detail['item_nama'] ?? '',
            qty: detail['mtd_qty']?.toInt() ?? 0,
            keterangan: detail['mtd_keterangan'] ?? '',
          );
        }).toList();

        _filteredItems = List.from(_selectedItems);
        _initializeControllers();
      });
    } catch (e) {
      _showToast('Gagal memuat detail: ${e.toString()}', type: ToastType.error);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _initializeControllers() {
    for (var item in _selectedItems) {
      _qtyControllers[item.itemId] = TextEditingController(
          text: item.qty > 0 ? item.qty.toString() : ''
      );
      _ketControllers[item.itemId] = TextEditingController(
          text: item.keterangan ?? ''
      );
    }
  }

  void _filterItems(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredItems = List.from(_selectedItems);
      } else {
        final searchLower = query.toLowerCase();
        _filteredItems = _selectedItems.where((item) {
          return item.itemNama.toLowerCase().contains(searchLower);
        }).toList();
      }
    });
  }

  void _updateItemQty(int itemId, int newQty) {
    setState(() {
      final index = _selectedItems.indexWhere((item) => item.itemId == itemId);
      if (index != -1) {
        final updatedItem = MintaItem(
          itemId: _selectedItems[index].itemId,
          itemNama: _selectedItems[index].itemNama,
          qty: newQty,
          keterangan: _selectedItems[index].keterangan,
        );
        _selectedItems[index] = updatedItem;

        final filteredIndex = _filteredItems.indexWhere((item) => item.itemId == itemId);
        if (filteredIndex != -1) {
          _filteredItems[filteredIndex] = updatedItem;
        }
      }
    });
  }

  void _updateItemKeterangan(int itemId, String keterangan) {
    setState(() {
      final index = _selectedItems.indexWhere((item) => item.itemId == itemId);
      if (index != -1) {
        final updatedItem = MintaItem(
          itemId: _selectedItems[index].itemId,
          itemNama: _selectedItems[index].itemNama,
          qty: _selectedItems[index].qty,
          keterangan: keterangan,
        );
        _selectedItems[index] = updatedItem;

        final filteredIndex = _filteredItems.indexWhere((item) => item.itemId == itemId);
        if (filteredIndex != -1) {
          _filteredItems[filteredIndex] = updatedItem;
        }
      }
    });
  }

  void _showAddItemModal() async {
    HapticFeedback.selectionClick();
    final selectedItems = await showModalBottomSheet<List<MintaItem>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.transparent,
        ),
        child: AddItemModalMinta(
          existingItems: _selectedItems,
        ),
      ),
    );

    if (selectedItems != null && selectedItems.isNotEmpty) {
      setState(() {
        for (var newItem in selectedItems) {
          final existingIndex = _selectedItems.indexWhere((item) => item.itemId == newItem.itemId);
          if (existingIndex >= 0) {
            final existingItem = _selectedItems[existingIndex];
            final updatedItem = MintaItem(
              itemId: existingItem.itemId,
              itemNama: existingItem.itemNama,
              qty: existingItem.qty + newItem.qty,
              keterangan: existingItem.keterangan,
            );
            _selectedItems[existingIndex] = updatedItem;
          } else {
            _selectedItems.add(newItem);
          }
        }
        _filteredItems = List.from(_selectedItems);
        _initializeControllers();
      });
      _showToast('${selectedItems.length} item ditambahkan', type: ToastType.success);
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: ColorScheme.light(
              primary: _primaryDark,
              onPrimary: Colors.white,
              surface: _surfaceWhite,
              onSurface: _textDark,
            ),
            dialogBackgroundColor: _surfaceWhite,
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
    }
  }

  void _showToast(String message, {required ToastType type}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Container(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Icon(
                type == ToastType.success ? Icons.check_circle_rounded :
                type == ToastType.error ? Icons.error_rounded :
                Icons.info_rounded,
                color: Colors.white,
                size: 18,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: GoogleFonts.montserrat(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
        backgroundColor: type == ToastType.success ? _accentMint :
        type == ToastType.error ? _accentCoral :
        _accentSky,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _updateAllQtyFromControllers() {
    for (var entry in _qtyControllers.entries) {
      final itemId = entry.key;
      final controller = entry.value;
      final intValue = int.tryParse(controller.text) ?? 0;
      _updateItemQty(itemId, intValue);
    }
  }

  void _updateAllKeteranganFromControllers() {
    for (var entry in _ketControllers.entries) {
      final itemId = entry.key;
      final controller = entry.value;
      _updateItemKeterangan(itemId, controller.text);
    }
  }

  Future<void> _saveMinta() async {
    _updateAllQtyFromControllers();
    _updateAllKeteranganFromControllers();

    final itemsWithQty = _selectedItems.where((item) => item.qty > 0).toList();
    if (itemsWithQty.isEmpty) {
      _showToast('Minimal satu item harus memiliki quantity!', type: ToastType.error);
      return;
    }

    setState(() => _isSaving = true);
    HapticFeedback.mediumImpact();

    try {
      final tanggalStr = DateFormat('yyyy-MM-dd').format(_selectedDate);

      final Map<String, dynamic> requestData = {
        'tanggal': tanggalStr,
        'keterangan': _keteranganController.text.trim(),
        'items': itemsWithQty.map((item) => item.toJson()).toList(),
      };

      final result = widget.mintaHeader == null
          ? await MintaService.createMinta(requestData)
          : await MintaService.updateMinta({
        'nomor': _nomorMinta!,
        'tanggal': tanggalStr,
        'keterangan': _keteranganController.text.trim(),
        'items': itemsWithQty.map((item) => item.toJson()).toList(),
      });

      if (result['success']) {
        _showToast(result['message'], type: ToastType.success);
        widget.onMintaSaved();
        Navigator.pop(context);
      } else {
        _showToast(result['message'], type: ToastType.error);
      }
    } catch (e) {
      _showToast('Error: ${e.toString()}', type: ToastType.error);
    } finally {
      setState(() => _isSaving = false);
    }
  }

  int get _totalItemsWithQty {
    return _selectedItems.where((item) => item.qty > 0).length;
  }

  int get _totalQuantity {
    return _selectedItems.fold(0, (sum, item) => sum + item.qty);
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.mintaHeader != null;

    return BaseLayout(
      title: isEdit ? 'Edit Permintaan Barang' : 'Tambah Permintaan Barang',
      showBackButton: true,
      showSidebar: true,
      isFormScreen: true,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: Container(
            color: _bgSoft,
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        _buildInfoCard(isEdit),
                        const SizedBox(height: 12),
                        _buildItemsCard(),
                      ],
                    ),
                  ),
                ),
                _buildModernBottomBar(isEdit),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard(bool isEdit) {
    return Container(
      decoration: BoxDecoration(
        color: _surfaceWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _borderSoft),
        boxShadow: [
          BoxShadow(
            color: _shadowColor,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            if (_nomorMinta != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: _primarySoft,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _primaryDark.withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.confirmation_number_rounded, size: 14, color: _primaryDark),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _nomorMinta!,
                        style: GoogleFonts.montserrat(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: _primaryDark,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
            ],
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => _selectDate(context),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      height: 40,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: _bgSoft,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: _borderSoft),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.calendar_today_rounded,
                            color: _accentGold,
                            size: 14,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Tanggal',
                                  style: GoogleFonts.montserrat(
                                    fontSize: 9,
                                    color: _textMedium,
                                  ),
                                ),
                                Text(
                                  DateFormat('dd/MM/yyyy').format(_selectedDate),
                                  style: GoogleFonts.montserrat(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: _textDark,
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
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: Container(
                    height: 40,
                    decoration: BoxDecoration(
                      color: _bgSoft,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _borderSoft),
                    ),
                    child: Center(
                      child: TextFormField(
                        controller: _keteranganController,
                        textAlignVertical: TextAlignVertical.center,
                        textAlign: TextAlign.left,
                        style: GoogleFonts.montserrat(
                          fontSize: 11,
                          color: _textDark,
                          fontWeight: FontWeight.w500,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Keterangan (opsional)',
                          hintStyle: GoogleFonts.montserrat(
                            fontSize: 11,
                            color: _textLight,
                          ),
                          prefixIcon: Icon(
                            Icons.description_rounded,
                            color: _primaryDark,
                            size: 14,
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                          isDense: true,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemsCard() {
    return Container(
      decoration: BoxDecoration(
        color: _surfaceWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _borderSoft),
        boxShadow: [
          BoxShadow(
            color: _shadowColor,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: _primarySoft,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(
                    Icons.inventory_2_rounded,
                    color: _primaryDark,
                    size: 14,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Daftar Item',
                  style: GoogleFonts.montserrat(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _textDark,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _bgSoft,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _borderSoft),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.shopping_bag_rounded,
                        size: 10,
                        color: _primaryDark,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${_selectedItems.length} items',
                        style: GoogleFonts.montserrat(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: _textDark,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 40,
                        decoration: BoxDecoration(
                          color: _bgSoft,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: _borderSoft),
                        ),
                        child: Center(
                          child: TextField(
                            controller: _searchController,
                            textAlignVertical: TextAlignVertical.center,
                            textAlign: TextAlign.left,
                            style: GoogleFonts.montserrat(fontSize: 11),
                            onChanged: _filterItems,
                            decoration: InputDecoration(
                              hintText: 'Cari item...',
                              hintStyle: GoogleFonts.montserrat(
                                fontSize: 11,
                                color: _textLight,
                              ),
                              prefixIcon: Icon(
                                Icons.search_rounded,
                                color: _primaryDark,
                                size: 14,
                              ),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                              isDense: true,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _buildModernActionButton(
                      label: 'Add Item',
                      icon: Icons.add_rounded,
                      color: _accentSky,
                      onPressed: _showAddItemModal,
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _primarySoft,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.inventory_rounded,
                            size: 10,
                            color: _primaryDark,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${_selectedItems.length}',
                            style: GoogleFonts.montserrat(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: _primaryDark,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _accentGoldSoft,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.shopping_cart_rounded,
                            size: 10,
                            color: _accentGold,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '$_totalQuantity',
                            style: GoogleFonts.montserrat(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: _accentGold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _accentMintSoft,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.check_circle_rounded,
                            size: 10,
                            color: _accentMint,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '$_totalItemsWithQty',
                            style: GoogleFonts.montserrat(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: _accentMint,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (_filteredItems.isEmpty)
                  _buildEmptyState()
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _filteredItems.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 6),
                    itemBuilder: (context, index) => _buildModernItemCard(_filteredItems[index]),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernActionButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return Container(
      height: 28,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color, color.withOpacity(0.8)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(6),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.2),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(6),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 11, color: Colors.white),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: GoogleFonts.montserrat(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModernItemCard(MintaItem item) {
    if (!_qtyControllers.containsKey(item.itemId)) {
      _qtyControllers[item.itemId] = TextEditingController(
          text: item.qty > 0 ? item.qty.toString() : ''
      );
    }
    if (!_ketControllers.containsKey(item.itemId)) {
      _ketControllers[item.itemId] = TextEditingController(
          text: item.keterangan ?? ''
      );
    }

    final qtyController = _qtyControllers[item.itemId]!;
    final ketController = _ketControllers[item.itemId]!;
    final hasQty = item.qty > 0;

    return Container(
      decoration: BoxDecoration(
        color: _surfaceWhite,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: hasQty ? _primaryDark.withOpacity(0.3) : _borderSoft,
          width: hasQty ? 1.5 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: hasQty ? _primaryDark : _bgSoft,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Icon(
                      Icons.inventory_2_outlined,
                      color: hasQty ? Colors.white : _textLight,
                      size: 16,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.itemNama,
                        style: GoogleFonts.montserrat(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: _textDark,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(
                              color: _bgSoft,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'ID: ${item.itemId}',
                              style: GoogleFonts.montserrat(
                                fontSize: 8,
                                color: _textMedium,
                              ),
                            ),
                          ),
                          if (hasQty) ...[
                            const SizedBox(width: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                              decoration: BoxDecoration(
                                color: _accentGoldSoft,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'Qty: ${item.qty}',
                                style: GoogleFonts.montserrat(
                                  fontSize: 8,
                                  fontWeight: FontWeight.w600,
                                  color: _accentGold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 60,
                  height: 32,
                  decoration: BoxDecoration(
                    color: _bgSoft,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: hasQty ? _primaryDark.withOpacity(0.3) : _borderSoft,
                    ),
                  ),
                  child: TextField(
                    controller: qtyController,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    style: GoogleFonts.montserrat(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: hasQty ? _primaryDark : _textLight,
                    ),
                    decoration: InputDecoration(
                      hintText: '0',
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 2, vertical: 8),
                      isDense: true,
                      hintStyle: GoogleFonts.montserrat(
                        fontSize: 11,
                        color: _textLight,
                      ),
                    ),
                    onChanged: (value) {
                      final intValue = int.tryParse(value) ?? 0;
                      _updateItemQty(item.itemId, intValue);
                    },
                    onTap: () {
                      qtyController.selection = TextSelection(
                        baseOffset: 0,
                        extentOffset: qtyController.text.length,
                      );
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Container(
              height: 28,
              decoration: BoxDecoration(
                color: _bgSoft,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: _borderSoft),
              ),
              child: TextField(
                controller: ketController,
                style: GoogleFonts.montserrat(fontSize: 10, color: _textDark),
                decoration: InputDecoration(
                  hintText: 'Keterangan item (opsional)',
                  hintStyle: GoogleFonts.montserrat(
                    fontSize: 9,
                    color: _textLight,
                  ),
                  prefixIcon: Icon(
                    Icons.notes_rounded,
                    color: _textLight,
                    size: 12,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  isDense: true,
                ),
                onChanged: (value) {
                  _updateItemKeterangan(item.itemId, value);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: _bgSoft,
              shape: BoxShape.circle,
            ),
            child: Icon(
              _searchController.text.isEmpty
                  ? Icons.inventory_2_outlined
                  : Icons.search_off_rounded,
              size: 32,
              color: _textLight,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _searchController.text.isEmpty
                ? 'Belum ada item'
                : 'Item tidak ditemukan',
            style: GoogleFonts.montserrat(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: _textDark,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            _searchController.text.isEmpty
                ? 'Tambah item dengan tombol di atas'
                : 'Coba kata kunci lain',
            style: GoogleFonts.montserrat(
              fontSize: 10,
              color: _textLight,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernBottomBar(bool isEdit) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _surfaceWhite,
        border: Border(top: BorderSide(color: _borderSoft)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Item dengan QTY',
                    style: GoogleFonts.montserrat(
                      fontSize: 9,
                      color: _textLight,
                    ),
                  ),
                  Row(
                    children: [
                      Icon(
                        Icons.check_circle_rounded,
                        size: 12,
                        color: _accentMint,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '$_totalItemsWithQty dari ${_selectedItems.length}',
                        style: GoogleFonts.montserrat(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: _textDark,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Container(
              width: 120,
              height: 40,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [_primaryDark, _primaryLight],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: _primaryDark.withOpacity(0.2),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _isSaving ? null : _saveMinta,
                  borderRadius: BorderRadius.circular(8),
                  child: Center(
                    child: _isSaving
                        ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                        : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          isEdit ? Icons.edit_rounded : Icons.save_rounded,
                          color: Colors.white,
                          size: 14,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          isEdit ? 'Update' : 'Simpan',
                          style: GoogleFonts.montserrat(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum ToastType { success, error, info }