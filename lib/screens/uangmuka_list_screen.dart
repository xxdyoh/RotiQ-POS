import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';
import '../services/uangmuka_service.dart';
import '../routes/app_routes.dart';
import '../widgets/base_layout.dart';
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

  final DataGridController _dataGridController = DataGridController();
  late UangMukaDataSource _dataSource;

  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now();
  bool _showDateFilter = false;
  final TextEditingController _startDateController = TextEditingController();
  final TextEditingController _endDateController = TextEditingController();

  final NumberFormat _currencyFormat = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
  final NumberFormat _numberFormat = NumberFormat('#,##0');

  @override
  void initState() {
    super.initState();
    _endDate = DateTime.now();
    _startDate = DateTime(_endDate.year, _endDate.month, 1);
    _updateDateControllers();
    _dataSource = UangMukaDataSource(
      uangMukaList: [],
      currencyFormat: _currencyFormat,
      onEdit: _openEditUangMuka,
      onDelete: _deleteUangMuka,
      onPrint: _printUangMuka,
    );
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
        _dataSource = UangMukaDataSource(
          uangMukaList: _uangMukaList,
          currencyFormat: _currencyFormat,
          onEdit: _openEditUangMuka,
          onDelete: _deleteUangMuka,
          onPrint: _printUangMuka,
        );
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
    _loadUangMukaData();
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

  void _openAddUangMuka() {
    Navigator.pushNamed(
      context,
      AppRoutes.uangMukaForm,
      arguments: {
        'onSaved': _loadUangMukaData,
      },
    );
  }

  void _openEditUangMuka(Map<String, dynamic> uangMuka) {
    final isRealisasi = uangMuka['um_isrealisasi'] ?? 0;
    if (isRealisasi == 1) {
      _showInfoSnackbar('Uang muka sudah direalisasi, tidak dapat diubah');
      return;
    }

    Navigator.pushNamed(
      context,
      AppRoutes.uangMukaForm,
      arguments: {
        'uangMuka': uangMuka,
        'onSaved': _loadUangMukaData,
      },
    );
  }

  void _deleteUangMuka(Map<String, dynamic> uangMuka) {
    final isRealisasi = uangMuka['um_isrealisasi'] ?? 0;
    if (isRealisasi == 1) {
      _showInfoSnackbar('Uang muka sudah direalisasi, tidak dapat dihapus');
      return;
    }

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
    return _currencyFormat.format(value);
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return DateFormat('dd/MM/yy').format(date);
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

  @override
  Widget build(BuildContext context) {
    return BaseLayout(
      title: 'Uang Muka',
      showBackButton: false,
      showSidebar: true,
      isFormScreen: false,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isTablet = constraints.maxWidth >= 600;

          return Column(
            children: [
              // ========== FILTER TANGGAL SECTION ==========
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
                                    )),
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

              // ========== SEARCH SECTION ==========
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
                                constraints: const BoxConstraints(minWidth: 20),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      height: 34,
                      child: ElevatedButton.icon(
                        onPressed: _openAddUangMuka,
                        icon: const Icon(Icons.add, size: 14, color: Colors.white),
                        label: Text(
                          'Tambah',
                          style: GoogleFonts.montserrat(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFF6A918),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ========== SUMMARY ==========
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
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Total: ${_dataSource.rows.length} uang muka',
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
                      const SizedBox(
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

              const SizedBox(height: 8),

              // ========== DATA GRID ==========
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator(color: Color(0xFFF6A918)))
                    : _uangMukaList.isEmpty
                    ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.payment_outlined,
                        size: 36,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 8),
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
                  margin: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SfDataGrid(
                      controller: _dataGridController,
                      source: _dataSource,
                      allowColumnsResizing: true,
                      columnResizeMode: ColumnResizeMode.onResize,
                      columnWidthMode: ColumnWidthMode.auto,
                      headerRowHeight: 32,
                      rowHeight: 30,
                      allowSorting: true,
                      allowFiltering: true,
                      gridLinesVisibility: GridLinesVisibility.both,
                      headerGridLinesVisibility: GridLinesVisibility.both,
                      selectionMode: SelectionMode.single,

                      stackedHeaderRows: [
                        StackedHeaderRow(
                          cells: [
                            StackedHeaderCell(
                              columnNames: [
                                'no', 'nomor', 'tanggal', 'customer', 'nilai',
                                'jenis_bayar', 'status', 'aksi'
                              ],
                              child: Container(
                                height: 12,
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.only(right: 4),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    Icon(Icons.filter_list, size: 10, color: Colors.grey[500]),
                                    const SizedBox(width: 2),
                                    Icon(Icons.unfold_more, size: 10, color: Colors.grey[500]),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],

                      columns: [
                        GridColumn(
                          columnName: 'no',
                          minimumWidth: 50,
                          maximumWidth: 60,
                          label: Container(
                            padding: const EdgeInsets.only(left: 4, top: 4),
                            alignment: Alignment.centerLeft,
                            child: const Text(
                              'No',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                            ),
                          ),
                        ),
                        GridColumn(
                          columnName: 'nomor',
                          minimumWidth: 150,
                          maximumWidth: 180,
                          label: Container(
                            padding: const EdgeInsets.only(left: 4, top: 4),
                            alignment: Alignment.centerLeft,
                            child: const Text(
                              'Nomor',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                            ),
                          ),
                        ),
                        GridColumn(
                          columnName: 'tanggal',
                          minimumWidth: 80,
                          maximumWidth: 100,
                          label: Container(
                            padding: const EdgeInsets.only(left: 4, top: 4),
                            alignment: Alignment.centerLeft,
                            child: const Text(
                              'Tanggal',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                            ),
                          ),
                        ),
                        GridColumn(
                          columnName: 'customer',
                          minimumWidth: 150,
                          maximumWidth: 200,
                          label: Container(
                            padding: const EdgeInsets.only(left: 4, top: 4),
                            alignment: Alignment.centerLeft,
                            child: const Text(
                              'Customer',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                            ),
                          ),
                        ),
                        GridColumn(
                          columnName: 'nilai',
                          minimumWidth: 120,
                          maximumWidth: 150,
                          label: Container(
                            padding: const EdgeInsets.only(left: 4, top: 4),
                            alignment: Alignment.centerLeft,
                            child: const Text(
                              'Nilai',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                            ),
                          ),
                        ),
                        GridColumn(
                          columnName: 'jenis_bayar',
                          minimumWidth: 80,
                          maximumWidth: 100,
                          label: Container(
                            padding: const EdgeInsets.only(left: 4, top: 4),
                            alignment: Alignment.centerLeft,
                            child: const Text(
                              'Jenis Bayar',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                            ),
                          ),
                        ),
                        GridColumn(
                          columnName: 'status',
                          minimumWidth: 90,
                          maximumWidth: 110,
                          label: Container(
                            padding: const EdgeInsets.only(left: 4, top: 4),
                            alignment: Alignment.centerLeft,
                            child: const Text(
                              'Status',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                            ),
                          ),
                        ),
                        GridColumn(
                          columnName: 'aksi',
                          minimumWidth: 100,
                          maximumWidth: 110,
                          label: Container(
                            padding: const EdgeInsets.only(left: 4, top: 4),
                            alignment: Alignment.center,
                            child: const Text(
                              'Aksi',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class UangMukaDataSource extends DataGridSource {
  UangMukaDataSource({
    required List<Map<String, dynamic>> uangMukaList,
    required NumberFormat currencyFormat,
    required Function(Map<String, dynamic>) onEdit,
    required Function(Map<String, dynamic>) onDelete,
    required Function(Map<String, dynamic>) onPrint,
  }) {
    _currencyFormat = currencyFormat;
    _onEdit = onEdit;
    _onDelete = onDelete;
    _onPrint = onPrint;

    _data = uangMukaList.asMap().entries.map((entry) {
      final index = entry.key + 1;
      final um = entry.value;

      final nomor = um['um_nomor']?.toString() ?? '-';
      final tanggal = _formatDate(um['um_tanggal']?.toString() ?? '');
      final customer = um['um_customer']?.toString() ?? '-';
      final nilai = double.tryParse(um['um_nilai']?.toString() ?? '0') ?? 0;
      final jenisBayar = um['um_jenisbayar']?.toString() ?? 'Cash';
      final isRealisasi = um['um_isrealisasi'] ?? 0;

      return DataGridRow(cells: [
        DataGridCell<int>(columnName: 'no', value: index),
        DataGridCell<String>(columnName: 'nomor', value: nomor),
        DataGridCell<String>(columnName: 'tanggal', value: tanggal),
        DataGridCell<String>(columnName: 'customer', value: customer),
        DataGridCell<double>(columnName: 'nilai', value: nilai),
        DataGridCell<String>(columnName: 'jenis_bayar', value: jenisBayar),
        DataGridCell<int>(columnName: 'status', value: isRealisasi),
        DataGridCell<Map<String, dynamic>>(columnName: 'aksi', value: um),
      ]);
    }).toList();
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return DateFormat('dd/MM/yy').format(date);
    } catch (e) {
      return dateString;
    }
  }

  List<DataGridRow> _data = [];
  late NumberFormat _currencyFormat;
  late Function(Map<String, dynamic>) _onEdit;
  late Function(Map<String, dynamic>) _onDelete;
  late Function(Map<String, dynamic>) _onPrint;

  @override
  List<DataGridRow> get rows => _data;

  @override
  DataGridRowAdapter buildRow(DataGridRow row) {
    return DataGridRowAdapter(
      cells: row.getCells().map<Widget>((cell) {
        if (cell.columnName == 'aksi') {
          final um = cell.value as Map<String, dynamic>;
          final isRealisasi = um['um_isrealisasi'] ?? 0;

          return Container(
            alignment: Alignment.center,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Tombol Print (selalu ada)
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: IconButton(
                    icon: Icon(Icons.print, size: 12, color: Colors.green.shade700),
                    onPressed: () => _onPrint(um),
                    padding: EdgeInsets.zero,
                  ),
                ),
                const SizedBox(width: 2),

                // Tombol Edit (hanya jika belum realisasi)
                if (isRealisasi == 0)
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: IconButton(
                      icon: Icon(Icons.edit, size: 12, color: Colors.blue.shade700),
                      onPressed: () => _onEdit(um),
                      padding: EdgeInsets.zero,
                    ),
                  )
                else
                  Container(
                    width: 24,
                    height: 24,
                  ),

                const SizedBox(width: 2),

                // Tombol Delete (hanya jika belum realisasi)
                if (isRealisasi == 0)
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: IconButton(
                      icon: Icon(Icons.delete, size: 12, color: Colors.red.shade700),
                      onPressed: () => _onDelete(um),
                      padding: EdgeInsets.zero,
                    ),
                  )
                else
                  Container(
                    width: 24,
                    height: 24,
                  ),
              ],
            ),
          );
        }

        if (cell.columnName == 'status') {
          final isRealisasi = cell.value as int;
          final statusText = isRealisasi == 1 ? 'Realisasi' : 'Belum';
          final color = isRealisasi == 1 ? Colors.green : Colors.orange;

          return Container(
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: color.withOpacity(0.3), width: 1),
              ),
              child: Text(
                statusText,
                style: GoogleFonts.montserrat(
                  fontSize: 8,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ),
          );
        }

        if (cell.columnName == 'nilai') {
          final nilai = cell.value as double;
          return Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Text(
              _currencyFormat.format(nilai),
              textAlign: TextAlign.right,
              style: GoogleFonts.montserrat(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: const Color(0xFFF6A918),
              ),
            ),
          );
        }

        if (cell.columnName == 'jenis_bayar') {
          final jenisBayar = cell.value.toString();
          return Container(
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.grey.shade300, width: 1),
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
          );
        }

        return Container(
          alignment: _getAlignment(cell.columnName),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Text(
            cell.value.toString(),
            textAlign: _getTextAlign(cell.columnName),
            style: GoogleFonts.montserrat(
              fontSize: 10,
              fontWeight: _getFontWeight(cell.columnName),
              color: Colors.black87,
            ),
          ),
        );
      }).toList(),
    );
  }

  Alignment _getAlignment(String columnName) {
    switch (columnName) {
      case 'nilai':
        return Alignment.centerRight;
      case 'aksi':
        return Alignment.center;
      default:
        return Alignment.centerLeft;
    }
  }

  TextAlign _getTextAlign(String columnName) {
    switch (columnName) {
      case 'nilai':
        return TextAlign.right;
      case 'aksi':
        return TextAlign.center;
      default:
        return TextAlign.left;
    }
  }

  FontWeight _getFontWeight(String columnName) {
    if (columnName == 'nilai') {
      return FontWeight.w600;
    }
    return FontWeight.normal;
  }
}