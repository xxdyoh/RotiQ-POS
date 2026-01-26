import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/setengahjadi_service.dart';
import '../models/setengahjadi.dart';
import '../widgets/base_layout.dart';
import '../routes/app_routes.dart';

class SetengahJadiListScreen extends StatefulWidget {
  const SetengahJadiListScreen({super.key});

  @override
  State<SetengahJadiListScreen> createState() => _SetengahJadiListScreenState();
}

class _SetengahJadiListScreenState extends State<SetengahJadiListScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = false;
  List<SetengahJadi> _items = [];
  List<SetengahJadi> _filteredItems = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final items = await SetengahJadiService.getSetengahJadi();
      setState(() {
        _items = items;
        _filteredItems = items;
      });
    } catch (e) {
      _showErrorSnackbar('Gagal memuat data: ${e.toString()}');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _filterItems(String query) {
    setState(() {
      _filteredItems = _items.where((item) {
        return item.stjNama.toLowerCase().contains(query.toLowerCase());
      }).toList();
    });
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 16),
            const SizedBox(width: 6),
            Text(message, style: GoogleFonts.montserrat(fontSize: 12)),
          ],
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        margin: const EdgeInsets.all(12),
      ),
    );
  }

  void _showSuccessSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 16),
            const SizedBox(width: 6),
            Text(message, style: GoogleFonts.montserrat(fontSize: 12)),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        margin: const EdgeInsets.all(12),
      ),
    );
  }

  // ========== FIX: NAVIGASI YANG BENAR ==========
  void _openAddSetengahJadi() {
    Navigator.pushNamed(
      context,
      AppRoutes.setengahJadiForm,
      arguments: {
        'onSaved': _loadData,
      },
    );
  }

  void _openEditSetengahJadi(SetengahJadi item) {
    Navigator.pushNamed(
      context,
      AppRoutes.setengahJadiForm,
      arguments: {
        'setengahJadi': item,
        'onSaved': _loadData,
      },
    );
  }

  void _deleteSetengahJadi(SetengahJadi item) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 20),
            const SizedBox(width: 8),
            Text('Hapus Setengah Jadi?', style: GoogleFonts.montserrat(fontSize: 14)),
          ],
        ),
        content: Text('Apakah Anda yakin ingin menghapus "${item.stjNama}"?',
            style: GoogleFonts.montserrat(fontSize: 12)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Batal', style: GoogleFonts.montserrat(fontSize: 12, color: Colors.grey[600])),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _performDelete(item);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            ),
            child: Text('Hapus', style: GoogleFonts.montserrat(fontSize: 12, color: Colors.white)),
          ),
        ],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _performDelete(SetengahJadi item) async {
    setState(() => _isLoading = true);
    try {
      final result = await SetengahJadiService.deleteSetengahJadi(item.stjId.toString());
      if (result['success']) {
        _showSuccessSnackbar(result['message']);
        await _loadData();
      } else {
        _showErrorSnackbar(result['message']);
      }
    } catch (e) {
      _showErrorSnackbar('Error: ${e.toString()}');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BaseLayout(
      title: 'Setengah Jadi',
      showBackButton: false,
      showSidebar: true,
      isFormScreen: false,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // ========== SEARCH SECTION - COMPACT ==========
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
                                hintText: 'Cari setengah jadi...',
                                hintStyle: GoogleFonts.montserrat(
                                  fontSize: 11,
                                  color: Colors.grey.shade500,
                                ),
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
                              constraints: const BoxConstraints(minWidth: 20),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // ========== FIXED ADD BUTTON ==========
                  Container(
                    height: 34,
                    child: ElevatedButton.icon(
                      onPressed: _openAddSetengahJadi, // ← INI YANG HARUSNYA BEKERJA
                      icon: const Icon(Icons.add, size: 14, color: Colors.white),
                      label: Text('Tambah',
                          style: GoogleFonts.montserrat(fontSize: 11, fontWeight: FontWeight.w500)),
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

            // ========== SUMMARY - COMPACT ==========
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Total: ${_filteredItems.length} item${_filteredItems.length != 1 ? 's' : ''}',
                    style: GoogleFonts.montserrat(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  if (_isLoading)
                    SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: const Color(0xFFF6A918)),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // ========== ITEMS LIST ==========
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFFF6A918)))
                  : _filteredItems.isEmpty
                  ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.construction_outlined, size: 40, color: Colors.grey.shade400),
                    const SizedBox(height: 8),
                    Text(
                      _searchController.text.isEmpty
                          ? 'Tidak ada data setengah jadi'
                          : 'Setengah jadi tidak ditemukan',
                      style: GoogleFonts.montserrat(
                        color: Colors.grey.shade500,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              )
                  : Container(
                margin: const EdgeInsets.symmetric(horizontal: 12),
                child: ListView.separated(
                  itemCount: _filteredItems.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 6),
                  itemBuilder: (context, index) => _buildItemCard(_filteredItems[index]),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemCard(SetengahJadi item) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => _openEditSetengahJadi(item), // ← FIXED: TAP CARD UNTUK EDIT
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: Colors.teal.shade50,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(Icons.construction_rounded, size: 14, color: Colors.teal.shade700),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.stjNama,
                        style: GoogleFonts.montserrat(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'ID: ${item.stjId}',
                        style: GoogleFonts.montserrat(fontSize: 9, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(color: Colors.blue.shade200, width: 1),
                  ),
                  child: Text(
                    'STOK: ${item.stjStock}',
                    style: GoogleFonts.montserrat(
                      fontSize: 8,
                      fontWeight: FontWeight.w700,
                      color: Colors.blue.shade700,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                // ========== FIXED POPUP MENU ==========
                PopupMenuButton(
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: Colors.blue.shade100,
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Icon(Icons.edit, size: 12, color: Colors.blue.shade700),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Edit',
                            style: GoogleFonts.montserrat(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey.shade800,
                            ),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: Colors.red.shade100,
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Icon(Icons.delete, size: 12, color: Colors.red.shade700),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Hapus',
                            style: GoogleFonts.montserrat(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey.shade800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  onSelected: (value) {
                    if (value == 'edit') {
                      _openEditSetengahJadi(item); // ← FIXED: ON SELECT EDIT
                    } else if (value == 'delete') {
                      _deleteSetengahJadi(item); // ← FIXED: ON SELECT DELETE
                    }
                  },
                  icon: Icon(Icons.more_vert, size: 16, color: Colors.grey.shade600),
                  offset: const Offset(0, 0),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 30),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(color: Colors.grey.shade200, width: 1),
                  ),
                  elevation: 2,
                  color: Colors.white,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}