import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../services/uangmuka_service.dart';
import '../routes/app_routes.dart';
import '../widgets/base_layout.dart';
import 'uangmuka_form_screen.dart';
import '../services/universal_printer_service.dart';

class UangMukaListScreen extends StatefulWidget {
  const UangMukaListScreen({super.key});

  @override
  State<UangMukaListScreen> createState() => _UangMukaListScreenState();
}

class _UangMukaListScreenState extends State<UangMukaListScreen> {
  final TextEditingController _searchController = TextEditingController();

  bool _isLoading = false;
  List<Map<String, dynamic>> _uangMukaList = [];
  List<Map<String, dynamic>> _filteredList = [];

  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now();
  bool _showDateFilter = false;
  final TextEditingController _startDateController = TextEditingController();
  final TextEditingController _endDateController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _endDate = DateTime.now();
    _startDate = DateTime(_endDate.year, _endDate.month, 1);
    _updateDateControllers();
    _loadUangMukaData();
  }

  Future<void> _loadUangMukaData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final uangMukaData = await UangMukaService.getUangMukaList(
        search: _searchController.text.isEmpty ? null : _searchController.text,
        startDate: _formatDateForApi(_startDate),
        endDate: _formatDateForApi(_endDate),
      );
      setState(() {
        _uangMukaList = uangMukaData;
        _filteredList = uangMukaData;
      });
    } catch (e) {
      _showErrorSnackbar('Gagal memuat data uang muka: ${e.toString()}');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _filterUangMuka(String query) {
    setState(() {
      _filteredList = _uangMukaList.where((um) {
        final nomor = um['um_nomor']?.toString().toLowerCase() ?? '';
        final customer = um['um_customer']?.toString().toLowerCase() ?? '';
        final keterangan = um['um_keterangan']?.toString().toLowerCase() ?? '';
        return nomor.contains(query.toLowerCase()) ||
            customer.contains(query.toLowerCase()) ||
            keterangan.contains(query.toLowerCase());
      }).toList();
    });
  }

  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isStartDate ? _startDate : _endDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFFF6A918),
              onPrimary: Colors.white,
            ),
            dialogBackgroundColor: Colors.white,
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        if (isStartDate) {
          _startDate = picked;
          if (_startDate.isAfter(_endDate)) {
            _endDate = _startDate;
          }
        } else {
          _endDate = picked;
          if (_endDate.isBefore(_startDate)) {
            _startDate = _endDate;
          }
        }
        _updateDateControllers();
      });

      _loadUangMukaData();
    }
  }

  void _resetDateFilter() {
    setState(() {
      _endDate = DateTime.now();
      _startDate = DateTime(_endDate.year, _endDate.month, 1);
      _updateDateControllers();
      _loadUangMukaData();
    });
  }

  void _toggleDateFilter() {
    setState(() {
      _showDateFilter = !_showDateFilter;
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

  void _openAddUangMuka() {
    Navigator.pushNamed(
      context,
      AppRoutes.uangMukaForm, // ← GUNAKAN NAMED ROUTE
      arguments: {
        'onSaved': _loadUangMukaData,
      },
    );
  }

  void _openEditUangMuka(Map<String, dynamic> uangMuka) {
    Navigator.pushNamed(
      context,
      AppRoutes.uangMukaForm, // ← GUNAKAN NAMED ROUTE
      arguments: {
        'uangMuka': uangMuka,
        'onSaved': _loadUangMukaData,
      },
    );
  }

  void _deleteUangMuka(Map<String, dynamic> uangMuka) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 20),
            SizedBox(width: 8),
            Text(
              'Hapus Uang Muka?',
              style: GoogleFonts.montserrat(fontSize: 14),
            ),
          ],
        ),
        content: Text(
          'Apakah Anda yakin ingin menghapus "${uangMuka['um_nomor']}"?',
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
              await _performDelete(uangMuka);
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

  void _updateDateControllers() {
    _startDateController.text = DateFormat('dd/MM/yyyy').format(_startDate);
    _endDateController.text = DateFormat('dd/MM/yyyy').format(_endDate);
  }

  String _formatDateForApi(DateTime date) {
    return DateFormat('yyyy-MM-dd').format(date);
  }

  Future<void> _performDelete(Map<String, dynamic> uangMuka) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final result = await UangMukaService.deleteUangMuka(uangMuka['um_nomor'].toString());

      if (result['success']) {
        _showSuccessSnackbar(result['message']);
        await _loadUangMukaData();
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

  String _formatCurrency(dynamic amount) {
    final num value = amount is int ? amount : (amount ?? 0);
    return NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    ).format(value);
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
    } catch (e) {
      return dateString;
    }
  }

  Color _getStatusColor(int isRealisasi) {
    return isRealisasi == 1 ? Colors.green : Colors.orange;
  }

  String _getStatusText(int isRealisasi) {
    return isRealisasi == 1 ? 'Realisasi' : 'Belum Realisasi';
  }

  @override
  Widget build(BuildContext context) {
    return BaseLayout( // ← GUNAKAN BASELAYOUT
      title: 'Uang Muka',
      showBackButton: false,
      showSidebar: true,
      isFormScreen: false,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Filter Tanggal',
                    style: GoogleFonts.montserrat(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      _showDateFilter ? Icons.expand_less : Icons.expand_more,
                      size: 18,
                      color: const Color(0xFFF6A918),
                    ),
                    onPressed: _toggleDateFilter,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 30),
                  ),
                ],
              ),
            ),

            if (_showDateFilter) ...[
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                padding: const EdgeInsets.all(12),
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
                child: Column(
                  children: [
                    // Tanggal Mulai
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Tanggal Mulai',
                                style: GoogleFonts.montserrat(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(6),
                                  onTap: () => _selectDate(context, true),
                                  child: Container(
                                    height: 36,
                                    padding: const EdgeInsets.symmetric(horizontal: 10),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade50,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: Colors.grey.shade300, width: 1),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.calendar_today, size: 14, color: Color(0xFFF6A918)),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: TextField(
                                            controller: _startDateController,
                                            style: GoogleFonts.montserrat(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w500,
                                              color: Colors.black87,
                                            ),
                                            decoration: const InputDecoration(
                                              border: InputBorder.none,
                                              isDense: true,
                                            ),
                                            enabled: false,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        // Tanggal Selesai
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Tanggal Selesai',
                                style: GoogleFonts.montserrat(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(6),
                                  onTap: () => _selectDate(context, false),
                                  child: Container(
                                    height: 36,
                                    padding: const EdgeInsets.symmetric(horizontal: 10),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade50,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: Colors.grey.shade300, width: 1),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.calendar_today, size: 14, color: Color(0xFFF6A918)),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: TextField(
                                            controller: _endDateController,
                                            style: GoogleFonts.montserrat(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w500,
                                              color: Colors.black87,
                                            ),
                                            decoration: const InputDecoration(
                                              border: InputBorder.none,
                                              isDense: true,
                                            ),
                                            enabled: false,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    // Tombol Reset Filter
                    SizedBox(
                      width: double.infinity,
                      height: 34,
                      child: ElevatedButton.icon(
                        onPressed: _resetDateFilter,
                        icon: const Icon(Icons.refresh, size: 14, color: Colors.white),
                        label: Text(
                          'Reset ke Awal Bulan',
                          style: GoogleFonts.montserrat(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey.shade600,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],

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
                                hintText: 'Cari nomor/customer...',
                                hintStyle: GoogleFonts.montserrat(
                                  fontSize: 11,
                                  color: Colors.grey.shade500,
                                ),
                                border: InputBorder.none,
                                isDense: true,
                              ),
                              style: GoogleFonts.montserrat(fontSize: 11),
                              onChanged: _filterUangMuka,
                            ),
                          ),
                          if (_searchController.text.isNotEmpty)
                            IconButton(
                              icon: Icon(Icons.clear, size: 12, color: Colors.grey.shade500),
                              onPressed: () {
                                _searchController.clear();
                                _filterUangMuka('');
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
                      onPressed: _openAddUangMuka,
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
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Total: ${_filteredList.length} uang muka',
                        style: GoogleFonts.montserrat(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      Text(
                        'Periode: ${DateFormat('dd/MM/yy').format(_startDate)} - ${DateFormat('dd/MM/yy').format(_endDate)}',
                        style: GoogleFonts.montserrat(
                          fontSize: 9,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
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

            // ========== UANG MUKA LIST ==========
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
                      Icons.payment_outlined,
                      size: 36,
                      color: Colors.grey.shade400,
                    ),
                    SizedBox(height: 8),
                    Text(
                      _searchController.text.isEmpty
                          ? 'Tidak ada data uang muka'
                          : 'Uang muka tidak ditemukan',
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
                  itemBuilder: (context, index) => _buildUangMukaCard(_filteredList[index]),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUangMukaCard(Map<String, dynamic> uangMuka) {
    final nomor = uangMuka['um_nomor']?.toString() ?? '-';
    final tanggal = uangMuka['um_tanggal']?.toString() ?? '';
    final customer = uangMuka['um_customer']?.toString() ?? '-';
    final nilai = uangMuka['um_nilai'] ?? 0;
    final jenisBayar = uangMuka['um_jenisbayar']?.toString() ?? 'Cash';
    final isRealisasi = uangMuka['um_isrealisasi'] ?? 0;
    final bool canEditDelete = isRealisasi == 0; // Bisa edit/hapus jika belum realisasi

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
          onTap: () {
            if (canEditDelete) {
              _openEditUangMuka(uangMuka);
            } else {
              _showInfoSnackbar('Uang muka sudah direalisasi, tidak dapat diubah');
            }
          },
          child: Padding(
            padding: EdgeInsets.all(10),
            child: Row(
              children: [
                // Status Icon
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: isRealisasi == 1 ? Colors.green.shade50 : Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(
                    isRealisasi == 1 ? Icons.check_circle : Icons.payment_rounded,
                    size: 14,
                    color: isRealisasi == 1 ? Colors.green.shade700 : Colors.blue.shade700,
                  ),
                ),
                SizedBox(width: 10),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              nomor,
                              style: GoogleFonts.montserrat(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: isRealisasi == 1 ? Colors.green.shade700 : Colors.black87,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 4),
                      Text(
                        customer,
                        style: GoogleFonts.montserrat(
                          fontSize: 10,
                          color: Colors.grey.shade600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 4),
                      Row(
                        children: [
                          // Jenis Bayar Badge
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: Colors.grey.shade300,
                                width: 1,
                              ),
                            ),
                            child: Text(
                              jenisBayar,
                              style: GoogleFonts.montserrat(
                                fontSize: 8,
                                fontWeight: FontWeight.w700,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ),
                          SizedBox(width: 6),
                          // Status Realisasi Badge
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: isRealisasi == 1 ? Colors.green.shade50 : Colors.orange.shade50,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: isRealisasi == 1 ? Colors.green.shade200 : Colors.orange.shade200,
                                width: 1,
                              ),
                            ),
                            child: Text(
                              isRealisasi == 1 ? 'Sudah Realisasi' : 'Belum Realisasi',
                              style: GoogleFonts.montserrat(
                                fontSize: 8,
                                fontWeight: FontWeight.w700,
                                color: isRealisasi == 1 ? Colors.green.shade700 : Colors.orange.shade700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                SizedBox(width: 8),

                // Jumlah Uang
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
                        _formatCurrency(nilai),
                        style: GoogleFonts.montserrat(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFF6A918),
                        ),
                      ),
                      Text(
                        'NILAI',
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

                PopupMenuButton(
                    itemBuilder: (context) {
                      final menuItems = <PopupMenuEntry>[];

                      menuItems.add(
                        PopupMenuItem(
                          value: 'print',
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(6),
                              onTap: () {
                                Navigator.pop(context);
                                _printUangMuka(uangMuka);
                              },
                              splashColor: Colors.green.shade100,
                              highlightColor: Colors.green.shade50.withOpacity(0.3),
                              child: Container(
                                padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 24,
                                      height: 24,
                                      decoration: BoxDecoration(
                                        color: Colors.green.shade100,
                                        borderRadius: BorderRadius.circular(5),
                                      ),
                                      child: Icon(
                                        Icons.print,
                                        size: 12,
                                        color: Colors.green.shade700,
                                      ),
                                    ),
                                    SizedBox(width: 10),
                                    Text(
                                      'Cetak',
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
                      );

                      // Menu Edit & Hapus - HANYA untuk yang BELUM realisasi
                      if (canEditDelete) {
                        menuItems.add(
                          PopupMenuItem(
                            value: 'edit',
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(6),
                                onTap: () {
                                  Navigator.pop(context);
                                  _openEditUangMuka(uangMuka);
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
                        );

                        menuItems.add(
                          PopupMenuItem(
                            value: 'delete',
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(6),
                                onTap: () {
                                  Navigator.pop(context);
                                  _deleteUangMuka(uangMuka);
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
                        );
                      }

                      return menuItems;
                    },
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
                  )
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _printUangMuka(Map<String, dynamic> uangMuka) async {
    try {
      final tanggal = DateTime.parse(uangMuka['um_tanggal']?.toString() ?? DateTime.now().toString());
      final customer = uangMuka['um_customer']?.toString() ?? '-';
      final nilai = double.tryParse(uangMuka['um_nilai']?.toString() ?? '0') ?? 0;
      final jenisBayar = uangMuka['um_jenisbayar']?.toString() ?? 'Cash';
      final keterangan = uangMuka['um_keterangan']?.toString();
      final isRealisasi = (uangMuka['um_isrealisasi'] ?? 0) == 1;
      final nomor = uangMuka['um_nomor']?.toString() ?? '';

      final success = await UniversalPrinterService().printUangMukaReceipt(
        nomor: nomor,
        tanggal: tanggal,
        customer: customer,
        nilai: nilai,
        jenisBayar: jenisBayar,
        keterangan: keterangan,
        isRealisasi: isRealisasi,
      );

      if (success) {
        _showSuccessSnackbar('Berhasil mencetak uang muka');
      } else {
        _showErrorSnackbar('Gagal mencetak. Pastikan printer terhubung.');
      }
    } catch (e) {
      _showErrorSnackbar('Error saat mencetak: ${e.toString()}');
    }
  }

  void _showInfoSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.info_outline, color: Colors.white, size: 16),
            SizedBox(width: 6),
            Text(
              message,
              style: GoogleFonts.montserrat(fontSize: 12),
            ),
          ],
        ),
        backgroundColor: Colors.blue,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        margin: EdgeInsets.all(12),
      ),
    );
  }
}