import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/stokstjin_service.dart';
import '../routes/app_routes.dart';
import '../widgets/base_layout.dart';
import 'stokstjin_form_screen.dart';

class StokStjinListScreen extends StatefulWidget {
  const StokStjinListScreen({super.key});

  @override
  State<StokStjinListScreen> createState() => _StokStjinListScreenState();
}

class _StokStjinListScreenState extends State<StokStjinListScreen> {
  final TextEditingController _searchController = TextEditingController();

  bool _isLoading = false;
  List<Map<String, dynamic>> _stokStjinList = [];
  List<Map<String, dynamic>> _filteredList = [];

  @override
  void initState() {
    super.initState();
    _loadStokStjinData();
  }

  Future<void> _loadStokStjinData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final stokStjinData = await StokStjinService.getStokStjinList(
        search: _searchController.text.isEmpty ? null : _searchController.text,
      );
      setState(() {
        _stokStjinList = stokStjinData;
        _filteredList = stokStjinData;
      });
    } catch (e) {
      _showErrorSnackbar('Gagal memuat data penerimaan setengah jadi: ${e.toString()}');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _filterStokStjin(String query) {
    setState(() {
      _filteredList = _stokStjinList.where((stokStjin) {
        final nomor = stokStjin['stji_nomor']?.toString().toLowerCase() ?? '';
        final keterangan = stokStjin['stji_keterangan']?.toString().toLowerCase() ?? '';
        return nomor.contains(query.toLowerCase()) ||
            keterangan.contains(query.toLowerCase());
      }).toList();
    });
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.white, size: 16),
            SizedBox(width: 6),
            Text(
              message,
              style: GoogleFonts.montserrat(fontSize: 12),
            ),
          ],
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        margin: EdgeInsets.all(12),
      ),
    );
  }

  void _showSuccessSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white, size: 16),
            SizedBox(width: 6),
            Text(
              message,
              style: GoogleFonts.montserrat(fontSize: 12),
            ),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        margin: EdgeInsets.all(12),
      ),
    );
  }

  void _openAddStokStjin() {
    Navigator.pushNamed(
      context,
      AppRoutes.penerimaanSetengahJadiForm, // ← GUNAKAN NAMED ROUTE
      arguments: {
        'onSaved': _loadStokStjinData,
      },
    );
  }

  void _openEditStokStjin(Map<String, dynamic> stokStjin) {
    Navigator.pushNamed(
      context,
      AppRoutes.penerimaanSetengahJadiForm, // ← GUNAKAN NAMED ROUTE
      arguments: {
        'stokStjinHeader': stokStjin,
        'onSaved': _loadStokStjinData,
      },
    );
  }

  void _deleteStokStjin(Map<String, dynamic> stokStjin) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 20),
            SizedBox(width: 8),
            Text(
              'Hapus Penerimaan?',
              style: GoogleFonts.montserrat(fontSize: 14),
            ),
          ],
        ),
        content: Text(
          'Apakah Anda yakin ingin menghapus "${stokStjin['stji_nomor']}"?',
          style: GoogleFonts.montserrat(fontSize: 12),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Batal',
              style: GoogleFonts.montserrat(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _performDelete(stokStjin);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            ),
            child: Text(
              'Hapus',
              style: GoogleFonts.montserrat(
                fontSize: 12,
                color: Colors.white,
              ),
            ),
          ),
        ],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _performDelete(Map<String, dynamic> stokStjin) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final result = await StokStjinService.deleteStokStjin(stokStjin['stji_nomor'].toString());

      if (result['success']) {
        _showSuccessSnackbar(result['message']);
        await _loadStokStjinData();
      } else {
        _showErrorSnackbar(result['message']);
      }
    } catch (e) {
      _showErrorSnackbar('Error: ${e.toString()}');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
    } catch (e) {
      return dateString;
    }
  }

  @override
  Widget build(BuildContext context) {
    return BaseLayout( // ← GUNAKAN BASELAYOUT
      title: 'Penerimaan St. Jadi',
      showBackButton: false,
      showSidebar: true,
      isFormScreen: false,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            // ========== COMPACT SEARCH SECTION ==========
            Container(
              margin: EdgeInsets.all(12),
              padding: EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.02),
                    blurRadius: 3,
                    offset: Offset(0, 1),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 34,
                      padding: EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
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
                              decoration: InputDecoration(
                                hintText: 'Cari nomor/keterangan...',
                                hintStyle: GoogleFonts.montserrat(
                                  fontSize: 11,
                                  color: Colors.grey.shade500,
                                ),
                                border: InputBorder.none,
                                isDense: true,
                              ),
                              style: GoogleFonts.montserrat(fontSize: 11),
                              onChanged: _filterStokStjin,
                            ),
                          ),
                          if (_searchController.text.isNotEmpty)
                            IconButton(
                              icon: Icon(Icons.clear, size: 12, color: Colors.grey.shade500),
                              onPressed: () {
                                _searchController.clear();
                                _filterStokStjin('');
                              },
                              padding: EdgeInsets.zero,
                              constraints: BoxConstraints(minWidth: 20),
                            ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(width: 10),
                  Container(
                    height: 34,
                    child: ElevatedButton.icon(
                      onPressed: _openAddStokStjin,
                      icon: Icon(Icons.add, size: 14, color: Colors.white),
                      label: Text(
                        'Tambah',
                        style: GoogleFonts.montserrat(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFFF6A918),
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(horizontal: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ========== COMPACT SUMMARY ==========
            Container(
              margin: EdgeInsets.symmetric(horizontal: 12),
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Total: ${_filteredList.length} penerimaan',
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
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFFF6A918),
                      ),
                    ),
                ],
              ),
            ),

            SizedBox(height: 8),

            // ========== STOK STJIN LIST ==========
            Expanded(
              child: _isLoading
                  ? Center(
                child: CircularProgressIndicator(color: Color(0xFFF6A918)),
              )
                  : _filteredList.isEmpty
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
                          ? 'Tidak ada data penerimaan'
                          : 'Penerimaan tidak ditemukan',
                      style: GoogleFonts.montserrat(
                        color: Colors.grey.shade500,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              )
                  : Container(
                margin: EdgeInsets.symmetric(horizontal: 12),
                child: ListView.separated(
                  itemCount: _filteredList.length,
                  separatorBuilder: (context, index) => SizedBox(height: 6),
                  itemBuilder: (context, index) => _buildStokStjinCard(_filteredList[index]),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStokStjinCard(Map<String, dynamic> stokStjin) {
    final nomor = stokStjin['stji_nomor']?.toString() ?? '-';
    final tanggal = stokStjin['stji_tanggal']?.toString() ?? '';
    final keterangan = stokStjin['stji_keterangan']?.toString() ?? '-';

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 3,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => _openEditStokStjin(stokStjin),
          child: Padding(
            padding: EdgeInsets.all(10),
            child: Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
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
                SizedBox(width: 10),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        nomor,
                        style: GoogleFonts.montserrat(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 4),
                      Text(
                        keterangan,
                        style: GoogleFonts.montserrat(
                          fontSize: 10,
                          color: Colors.grey.shade600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),

                SizedBox(width: 8),

                // Date Badge
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(
                      color: Colors.grey.shade200,
                      width: 1,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _formatDate(tanggal),
                        style: GoogleFonts.montserrat(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      Text(
                        'TANGGAL',
                        style: GoogleFonts.montserrat(
                          fontSize: 7,
                          color: Colors.grey.shade500,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(width: 6),

                // POPUP MENU DENGAN INKWELL
                PopupMenuButton(
                  itemBuilder: (context) => [
                    // Edit Menu
                    PopupMenuItem(
                      value: 'edit',
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(6),
                          onTap: () {
                            Navigator.pop(context);
                            _openEditStokStjin(stokStjin);
                          },
                          splashColor: Colors.blue.shade100,
                          highlightColor: Colors.blue.shade50.withOpacity(0.3),
                          child: Container(
                            padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                            child: Row(
                              children: [
                                Container(
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    color: Colors.blue.shade100,
                                    borderRadius: BorderRadius.circular(5),
                                  ),
                                  child: Icon(
                                    Icons.edit,
                                    size: 12,
                                    color: Colors.blue.shade700,
                                  ),
                                ),
                                SizedBox(width: 10),
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
                        ),
                      ),
                    ),
                    // Hapus Menu
                    PopupMenuItem(
                      value: 'delete',
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(6),
                          onTap: () {
                            Navigator.pop(context);
                            _deleteStokStjin(stokStjin);
                          },
                          splashColor: Colors.red.shade100,
                          highlightColor: Colors.red.shade50.withOpacity(0.3),
                          child: Container(
                            padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                            child: Row(
                              children: [
                                Container(
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    color: Colors.red.shade100,
                                    borderRadius: BorderRadius.circular(5),
                                  ),
                                  child: Icon(
                                    Icons.delete,
                                    size: 12,
                                    color: Colors.red.shade700,
                                  ),
                                ),
                                SizedBox(width: 10),
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
                        ),
                      ),
                    ),
                  ],
                  onSelected: (value) {
                    // Aksi sudah ditangani di InkWell onTap
                  },
                  icon: Icon(
                    Icons.more_vert,
                    size: 16,
                    color: Colors.grey.shade600,
                  ),
                  offset: Offset(0, 0),
                  padding: EdgeInsets.zero,
                  constraints: BoxConstraints(minWidth: 30),
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