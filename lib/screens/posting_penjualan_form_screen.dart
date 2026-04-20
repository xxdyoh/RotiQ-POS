import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../services/posting_penjualan_service.dart';
import '../models/posting_penjualan_model.dart';
import '../widgets/base_layout.dart';

class PostingPenjualanFormScreen extends StatefulWidget {
  final Map<String, dynamic>? postingHeader;
  final VoidCallback onPostingSaved;

  const PostingPenjualanFormScreen({
    super.key,
    this.postingHeader,
    required this.onPostingSaved,
  });

  @override
  State<PostingPenjualanFormScreen> createState() => _PostingPenjualanFormScreenState();
}

class _PostingPenjualanFormScreenState extends State<PostingPenjualanFormScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _keteranganController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();

  // Colors
  final Color _primaryDark = const Color(0xFF2C3E50);
  final Color _primaryLight = const Color(0xFF34495E);
  final Color _accentGold = const Color(0xFFF6A918);
  final Color _accentMint = const Color(0xFF06D6A0);
  final Color _accentCoral = const Color(0xFFFF6B6B);
  final Color _accentSky = const Color(0xFF4CC9F0);
  final Color _bgSoft = const Color(0xFFF8FAFC);
  final Color _surfaceWhite = Colors.white;
  final Color _textDark = const Color(0xFF1A202C);
  final Color _textMedium = const Color(0xFF718096);
  final Color _textLight = const Color(0xFFA0AEC0);
  final Color _borderSoft = const Color(0xFFE2E8F0);

  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;
  bool _isSaving = false;
  bool _isLoadingPenjualan = false;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  List<PostingPenjualanItem> _items = [];
  List<PostingPenjualanItem> _filteredItems = [];

  String? _nomorPosting;

  final NumberFormat _numberFormat = NumberFormat('#,###');

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
    _animationController.forward();

    if (widget.postingHeader != null) {
      _nomorPosting = widget.postingHeader!['stbj_nomor'];
      _selectedDate = DateTime.parse(widget.postingHeader!['stbj_tanggal']);
      _keteranganController.text = widget.postingHeader!['stbj_keterangan'] ?? '';
      _loadPostingDetail();
    }
  }

  @override
  void dispose() {
    _keteranganController.dispose();
    _searchController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadPostingDetail() async {
    if (_nomorPosting == null) return;
    setState(() => _isLoading = true);

    try {
      final detail = await PostingPenjualanService.getPostingPenjualanDetail(_nomorPosting!);
      final details = List<Map<String, dynamic>>.from(detail['details']);

      setState(() {
        _items = details.map((item) {
          return PostingPenjualanItem(
            itemId: int.tryParse(item['stbjd_brg_kode']?.toString() ?? '0') ?? 0,
            itemNama: item['item_nama'] ?? '',
            qty: int.tryParse(item['stbjd_qty']?.toString() ?? '0') ?? 0,
          );
        }).toList();
        _filteredItems = List.from(_items);
      });
    } catch (e) {
      _showToast('Gagal memuat detail: ${e.toString()}', type: ToastType.error);
    } finally {
      setState(() => _isLoading = false);
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
                size: 16,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  message,
                  style: GoogleFonts.montserrat(fontSize: 11, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
        backgroundColor: type == ToastType.success ? _accentMint :
        type == ToastType.error ? _accentCoral : _accentSky,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        margin: const EdgeInsets.all(12),
      ),
    );
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

  Future<void> _loadPenjualan() async {
    final tanggalStr = DateFormat('yyyy-MM-dd').format(_selectedDate);

    setState(() => _isLoadingPenjualan = true);

    try {
      final penjualanData = await PostingPenjualanService.loadPenjualan(tanggalStr);

      if (penjualanData.isEmpty) {
        _showToast('Tidak ada data penjualan untuk tanggal ini', type: ToastType.info);
        setState(() => _isLoadingPenjualan = false);
        return;
      }

      final newItems = penjualanData.map((data) {
        return PostingPenjualanItem(
          itemId: int.tryParse(data['item_id']?.toString() ?? '0') ?? 0,
          itemNama: data['item_nama']?.toString() ?? '',
          qty: int.tryParse(data['qty']?.toString() ?? '0') ?? 0,
          referensi: data['referensi_list']?.toString(),
        );
      }).toList();

      setState(() {
        _items = newItems;
        _filteredItems = List.from(newItems);
      });

      _showToast('Berhasil load ${newItems.length} item', type: ToastType.success);
      HapticFeedback.lightImpact();
    } catch (e) {
      _showToast('Error: $e', type: ToastType.error);
    } finally {
      setState(() => _isLoadingPenjualan = false);
    }
  }

  void _filterItems(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredItems = List.from(_items);
      } else {
        final searchLower = query.toLowerCase();
        _filteredItems = _items.where((item) {
          return item.itemNama.toLowerCase().contains(searchLower) ||
              item.itemId.toString().contains(searchLower);
        }).toList();
      }
    });
  }

  Future<void> _savePosting() async {
    if (_keteranganController.text.trim().isEmpty) {
      _showToast('Keterangan harus diisi!', type: ToastType.error);
      return;
    }

    if (_items.isEmpty) {
      _showToast('Minimal satu item harus ada! Klik Load Penjualan', type: ToastType.error);
      return;
    }

    setState(() => _isSaving = true);
    HapticFeedback.mediumImpact();

    try {
      final tanggalStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
      final itemsJson = _items.map((item) => item.toJson()).toList();

      final result = widget.postingHeader == null
          ? await PostingPenjualanService.createPostingPenjualan(
        tanggal: tanggalStr,
        keterangan: _keteranganController.text.trim(),
        items: itemsJson,
      )
          : await PostingPenjualanService.updatePostingPenjualan(
        nomor: _nomorPosting!,
        tanggal: tanggalStr,
        keterangan: _keteranganController.text.trim(),
        items: itemsJson,
      );

      if (result['success']) {
        _showToast(result['message'], type: ToastType.success);
        widget.onPostingSaved();
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

  int get _totalQuantity {
    return _items.fold(0, (sum, item) => sum + item.qty);
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.postingHeader != null;

    return BaseLayout(
      title: isEdit ? 'Edit Posting Penjualan' : 'Tambah Posting Penjualan',
      showBackButton: true,
      showSidebar: true,
      isFormScreen: true,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Container(
          color: _bgSoft,
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Card
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: _surfaceWhite,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: _borderSoft),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Nomor (jika edit)
                            if (_nomorPosting != null) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: _primaryDark.withOpacity(0.05),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: _primaryDark.withOpacity(0.1)),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.receipt, size: 14, color: _primaryDark),
                                    const SizedBox(width: 8),
                                    Text(
                                      _nomorPosting!,
                                      style: GoogleFonts.montserrat(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: _primaryDark,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                            ],

                            // Row: Tanggal & Keterangan
                            Row(
                              children: [
                                Expanded(
                                  flex: 2,
                                  child: _buildFieldLabel('Tanggal'),
                                ),
                                Expanded(
                                  flex: 3,
                                  child: _buildFieldLabel('Keterangan *'),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Expanded(
                                  flex: 2,
                                  child: _buildDateField(),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  flex: 3,
                                  child: _buildKeteranganField(),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Detail Section Header
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: _surfaceWhite,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: _borderSoft),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: _accentMint.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Icon(Icons.shopping_cart, size: 14, color: _accentMint),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Detail Item',
                                  style: GoogleFonts.montserrat(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: _textDark,
                                  ),
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                // Total Qty
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: _accentGold.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: _accentGold.withOpacity(0.3)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        'Total Qty: ',
                                        style: GoogleFonts.montserrat(
                                          fontSize: 10,
                                          color: _textMedium,
                                        ),
                                      ),
                                      Text(
                                        _numberFormat.format(_totalQuantity),
                                        style: GoogleFonts.montserrat(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: _accentGold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                // Load Penjualan Button
                                Container(
                                  height: 32,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [_accentSky, _accentSky.withOpacity(0.8)],
                                    ),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      onTap: _isLoadingPenjualan ? null : _loadPenjualan,
                                      borderRadius: BorderRadius.circular(6),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 12),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            _isLoadingPenjualan
                                                ? SizedBox(
                                              width: 14,
                                              height: 14,
                                              child: CircularProgressIndicator(
                                                color: Colors.white,
                                                strokeWidth: 2,
                                              ),
                                            )
                                                : Icon(Icons.download_rounded, size: 14, color: Colors.white),
                                            const SizedBox(width: 4),
                                            Text(
                                              'Load Penjualan',
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
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Search Bar
                      Container(
                        height: 40,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: _surfaceWhite,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: _borderSoft),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.search_rounded, size: 16, color: _textLight),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                controller: _searchController,
                                style: GoogleFonts.montserrat(fontSize: 11, color: _textDark),
                                onChanged: _filterItems,
                                decoration: InputDecoration(
                                  hintText: 'Cari item...',
                                  hintStyle: GoogleFonts.montserrat(fontSize: 11, color: _textLight),
                                  border: InputBorder.none,
                                  isDense: true,
                                  contentPadding: EdgeInsets.zero,
                                ),
                              ),
                            ),
                            if (_searchController.text.isNotEmpty)
                              GestureDetector(
                                onTap: () {
                                  _searchController.clear();
                                  _filterItems('');
                                },
                                child: Icon(Icons.close_rounded, size: 16, color: _textLight),
                              ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Grid Header
                      if (_filteredItems.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: _primaryDark,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 50,
                                child: Text(
                                  'No',
                                  style: GoogleFonts.montserrat(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 3,
                                child: Text(
                                  'Nama Item',
                                  style: GoogleFonts.montserrat(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              SizedBox(
                                width: 80,
                                child: Text(
                                  'Qty',
                                  style: GoogleFonts.montserrat(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                      // Detail Rows
                      if (_filteredItems.isEmpty && !_isLoading && !_isLoadingPenjualan)
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: _surfaceWhite,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: _borderSoft),
                          ),
                          child: Column(
                            children: [
                              Icon(Icons.shopping_cart_outlined, size: 36, color: _textLight),
                              const SizedBox(height: 8),
                              Text(
                                'Belum ada item',
                                style: GoogleFonts.montserrat(fontSize: 11, color: _textLight),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Klik "Load Penjualan" untuk memuat data',
                                style: GoogleFonts.montserrat(fontSize: 10, color: _textLight),
                              ),
                            ],
                          ),
                        )
                      else if (_isLoading || _isLoadingPenjualan)
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: _surfaceWhite,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: _borderSoft),
                          ),
                          child: Center(
                            child: Column(
                              children: [
                                SizedBox(
                                  width: 32,
                                  height: 32,
                                  child: CircularProgressIndicator(
                                    color: _accentGold,
                                    strokeWidth: 2,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Memuat data...',
                                  style: GoogleFonts.montserrat(fontSize: 11, color: _textLight),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        ..._filteredItems.asMap().entries.map((entry) {
                          final index = entry.key;
                          final item = entry.value;
                          return _buildDetailRow(index, item);
                        }).toList(),
                    ],
                  ),
                ),
              ),

              // Bottom Save Button
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _surfaceWhite,
                  border: Border(top: BorderSide(color: _borderSoft)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Total Item & Qty',
                            style: GoogleFonts.montserrat(fontSize: 10, color: _textLight),
                          ),
                          Row(
                            children: [
                              Icon(Icons.inventory_rounded, size: 12, color: _primaryDark),
                              const SizedBox(width: 4),
                              Text(
                                '${_items.length} item',
                                style: GoogleFonts.montserrat(fontSize: 11, fontWeight: FontWeight.w600, color: _textDark),
                              ),
                              const SizedBox(width: 12),
                              Icon(Icons.shopping_cart_rounded, size: 12, color: _accentGold),
                              const SizedBox(width: 4),
                              Text(
                                _numberFormat.format(_totalQuantity),
                                style: GoogleFonts.montserrat(fontSize: 11, fontWeight: FontWeight.w600, color: _accentGold),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 130,
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [_accentGold, _accentGold.withOpacity(0.8)],
                        ),
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: _accentGold.withOpacity(0.2),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: _isSaving ? null : _savePosting,
                          borderRadius: BorderRadius.circular(8),
                          child: Center(
                            child: _isSaving
                                ? SizedBox(
                              width: 20,
                              height: 20,
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
                                  size: 16,
                                  color: Colors.white,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  isEdit ? 'UPDATE' : 'SIMPAN',
                                  style: GoogleFonts.montserrat(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
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
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFieldLabel(String text) {
    return Text(
      text,
      style: GoogleFonts.montserrat(fontSize: 10, fontWeight: FontWeight.w600, color: _textMedium),
    );
  }

  Widget _buildDateField() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _selectDate(context),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: _bgSoft,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _borderSoft),
          ),
          child: Row(
            children: [
              Icon(Icons.calendar_today, size: 14, color: _accentGold),
              const SizedBox(width: 8),
              Text(
                DateFormat('dd MMM yyyy').format(_selectedDate),
                style: GoogleFonts.montserrat(fontSize: 11, color: _textDark),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildKeteranganField() {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: _bgSoft,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _borderSoft),
      ),
      child: TextFormField(
        controller: _keteranganController,
        style: GoogleFonts.montserrat(fontSize: 11, color: _textDark),
        decoration: InputDecoration(
          hintText: 'Keterangan...',
          hintStyle: GoogleFonts.montserrat(fontSize: 11, color: _textLight),
          border: InputBorder.none,
          isDense: true,
          contentPadding: EdgeInsets.zero,
        ),
      ),
    );
  }

  Widget _buildDetailRow(int index, PostingPenjualanItem item) {
    final isEven = index % 2 == 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 1),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isEven ? _surfaceWhite : _bgSoft,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: _borderSoft.withOpacity(0.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // No
          SizedBox(
            width: 50,
            child: Text(
              '${index + 1}',
              style: GoogleFonts.montserrat(fontSize: 10, fontWeight: FontWeight.w500, color: _textMedium),
            ),
          ),

          // Nama Item
          Expanded(
            flex: 3,
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
                Text(
                  'ID: ${item.itemId}',
                  style: GoogleFonts.montserrat(
                    fontSize: 9,
                    color: _textMedium,
                  ),
                ),
              ],
            ),
          ),

          // Qty (readonly)
          SizedBox(
            width: 80,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _accentGold.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: _accentGold.withOpacity(0.3)),
              ),
              child: Text(
                _numberFormat.format(item.qty),
                textAlign: TextAlign.center,
                style: GoogleFonts.montserrat(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: _accentGold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum ToastType { success, error, info }