import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';
import '../services/minta_service.dart';
import '../widgets/base_layout.dart';
import '../routes/app_routes.dart';
import '../screens/minta_form_screen.dart';

class MintaListScreen extends StatefulWidget {
  const MintaListScreen({super.key});

  @override
  State<MintaListScreen> createState() => _MintaListScreenState();
}

class _MintaListScreenState extends State<MintaListScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = false;
  bool _showDateFilter = false;
  List<Map<String, dynamic>> _mintaList = [];

  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now();
  final TextEditingController _startDateController = TextEditingController();
  final TextEditingController _endDateController = TextEditingController();

  final DataGridController _dataGridController = DataGridController();
  late MintaDataSource _dataSource;

  @override
  void initState() {
    super.initState();
    _endDate = DateTime.now();
    _startDate = DateTime(_endDate.year, _endDate.month, 1);
    _updateDateControllers();
    _dataSource = MintaDataSource(
      mintaList: [],
      onEdit: _openEditMinta,
      onDelete: _deleteMinta,
    );
    _loadMintaData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _startDateController.dispose();
    _endDateController.dispose();
    super.dispose();
  }

  void _updateDateControllers() {
    _startDateController.text = DateFormat('dd/MM/yyyy').format(_startDate);
    _endDateController.text = DateFormat('dd/MM/yyyy').format(_endDate);
  }

  String _formatDateForApi(DateTime date) {
    return DateFormat('yyyy-MM-dd').format(date);
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return DateFormat('dd/MM/yy').format(date);
    } catch (e) {
      return dateString;
    }
  }

  Future<void> _loadMintaData() async {
    setState(() => _isLoading = true);
    try {
      final mintaData = await MintaService.getMintaList(
        search: _searchController.text.isEmpty ? null : _searchController.text,
        startDate: _formatDateForApi(_startDate),
        endDate: _formatDateForApi(_endDate),
      );
      setState(() {
        _mintaList = mintaData;
        _dataSource = MintaDataSource(
          mintaList: _mintaList,
          onEdit: _openEditMinta,
          onDelete: _deleteMinta,
        );
      });
    } catch (e) {
      _showSnackbar('Gagal memuat data permintaan barang: ${e.toString()}', Colors.red);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _filterMinta(String query) {
    _loadMintaData();
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
            const SizedBox(width: 6),
            Text(message, style: GoogleFonts.montserrat(fontSize: 12)),
          ],
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        margin: const EdgeInsets.all(12),
      ),
    );
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

      _loadMintaData();
    }
  }

  void _resetDateFilter() {
    setState(() {
      _startDate = DateTime.now();
      _endDate = DateTime.now();
      _startDate = DateTime(_endDate.year, _endDate.month, 1);
      _updateDateControllers();
      _loadMintaData();
    });
  }

  void _toggleDateFilter() {
    setState(() {
      _showDateFilter = !_showDateFilter;
    });
  }

  void _openAddMinta() {
    Navigator.pushNamed(
      context,
      AppRoutes.mintaForm,
      arguments: {
        'onSaved': _loadMintaData,
      },
    );
  }

  void _openEditMinta(Map<String, dynamic> minta) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MintaFormScreen(
          mintaHeader: minta,
          onMintaSaved: _loadMintaData,
        ),
      ),
    );
  }

  void _deleteMinta(Map<String, dynamic> minta) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 20),
            const SizedBox(width: 8),
            Text('Hapus Permintaan Barang?', style: GoogleFonts.montserrat(fontSize: 14)),
          ],
        ),
        content: Text(
          'Apakah Anda yakin ingin menghapus "${minta['mt_nomor']}"?',
          style: GoogleFonts.montserrat(fontSize: 12),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Batal',
              style: GoogleFonts.montserrat(fontSize: 12, color: Colors.grey[600]),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _performDelete(minta);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            ),
            child: Text(
              'Hapus',
              style: GoogleFonts.montserrat(fontSize: 12, color: Colors.white),
            ),
          ),
        ],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _performDelete(Map<String, dynamic> minta) async {
    setState(() => _isLoading = true);
    try {
      final result = await MintaService.deleteMinta(minta['mt_nomor'].toString());
      if (result['success']) {
        _showSnackbar(result['message'], Colors.green);
        await _loadMintaData();
      } else {
        _showSnackbar(result['message'], Colors.red);
      }
    } catch (e) {
      _showSnackbar('Error: ${e.toString()}', Colors.red);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BaseLayout(
      title: 'Permintaan Barang',
      showBackButton: false,
      showSidebar: true,
      isFormScreen: false,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Column(
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
                                  hintText: 'Cari nomor/keterangan...',
                                  hintStyle: GoogleFonts.montserrat(
                                    fontSize: 11,
                                    color: Colors.grey.shade500,
                                  ),
                                  border: InputBorder.none,
                                  isDense: true,
                                ),
                                style: GoogleFonts.montserrat(fontSize: 11),
                                onChanged: _filterMinta,
                              ),
                            ),
                            if (_searchController.text.isNotEmpty)
                              IconButton(
                                icon: Icon(Icons.clear, size: 12, color: Colors.grey.shade500),
                                onPressed: () {
                                  _searchController.clear();
                                  _filterMinta('');
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
                        onPressed: _openAddMinta,
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
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

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
                          'Total: ${_mintaList.length} permintaan',
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
                          color: const Color(0xFFF6A918),
                        ),
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 8),

              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator(color: Color(0xFFF6A918)))
                    : _mintaList.isEmpty
                    ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.inbox_outlined, size: 40, color: Colors.grey.shade400),
                      const SizedBox(height: 8),
                      Text(
                        _searchController.text.isEmpty
                            ? 'Tidak ada data permintaan barang\npada periode yang dipilih'
                            : 'Permintaan barang tidak ditemukan',
                        textAlign: TextAlign.center,
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

                      onCellTap: (details) {
                        if (details.rowColumnIndex.rowIndex > 0) {
                          final dataRowIndex = details.rowColumnIndex.rowIndex - 2;

                          // Pastikan index valid
                          if (dataRowIndex >= 0 && dataRowIndex < _mintaList.length) {
                            final minta = _mintaList[dataRowIndex];
                            _showMintaDetailBottomSheet(minta);
                          }
                        }
                      },

                      columns: [
                        GridColumn(
                          columnName: 'no',
                          minimumWidth: 80,
                          maximumWidth: 100,
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
                          columnName: 'keterangan',
                          minimumWidth: 250,
                          maximumWidth: 350,
                          label: Container(
                            padding: const EdgeInsets.only(left: 4, top: 4),
                            alignment: Alignment.centerLeft,
                            child: const Text(
                              'Keterangan',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                            ),
                          ),
                        ),
                        GridColumn(
                          columnName: 'status',
                          minimumWidth: 80,
                          maximumWidth: 100,
                          label: Container(
                            padding: const EdgeInsets.only(left: 4, top: 4),
                            alignment: Alignment.center,
                            child: const Text(
                              'Status',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                            ),
                          ),
                        ),
                        GridColumn(
                          columnName: 'aksi',
                          minimumWidth: 80,
                          maximumWidth: 90,
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

  void _showMintaDetailBottomSheet(Map<String, dynamic> minta) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => FutureBuilder<Map<String, dynamic>>(
        future: MintaService.getMintaDetail(minta['mt_nomor']),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.85,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: const Center(
                child: CircularProgressIndicator(color: Color(0xFFF6A918)),
              ),
            );
          }

          if (snapshot.hasError || !snapshot.hasData) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.85,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, size: 40, color: Colors.grey.shade400),
                    const SizedBox(height: 8),
                    Text(
                      'Gagal memuat detail',
                      style: GoogleFonts.montserrat(color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
            );
          }

          final data = snapshot.data!;
          final header = data['header'];
          final details = List<Map<String, dynamic>>.from(data['details']);

          return _buildDetailBottomSheet(header, details);
        },
      ),
    );
  }

  Widget _buildDetailBottomSheet(Map<String, dynamic> header, List<Map<String, dynamic>> details) {
    final isTerkirim = header['mt_status_kirim'] == 1;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Bottom Sheet
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF6A918).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.inbox_rounded, color: Color(0xFFF6A918), size: 20),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          header['mt_nomor'] ?? '-',
                          style: GoogleFonts.montserrat(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF2C3E50),
                          ),
                        ),
                        Text(
                          DateFormat('dd MMM yyyy').format(DateTime.parse(header['mt_tanggal'])),
                          style: GoogleFonts.montserrat(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                IconButton(
                  icon: Icon(Icons.close, color: Colors.grey.shade600),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Info Card
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _buildInfoItem('Keterangan', header['mt_keterangan'] ?? '-'),
                            ),
                            Expanded(
                              child: _buildInfoItem('Status', isTerkirim ? 'Terkirim' : 'Pending'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: _buildInfoItem('User Create', header['user_create'] ?? '-'),
                            ),
                            Expanded(
                              child: _buildInfoItem('Date Create',
                                  header['date_create'] != null
                                      ? DateFormat('dd/MM/yy HH:mm').format(DateTime.parse(header['date_create']))
                                      : '-'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Detail Items
                  Text(
                    'Detail Items',
                    style: GoogleFonts.montserrat(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF2C3E50),
                    ),
                  ),

                  const SizedBox(height: 8),

                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          columnSpacing: 12,
                          horizontalMargin: 12,
                          headingRowHeight: 36,
                          dataRowHeight: 32,
                          headingRowColor: MaterialStateProperty.all(Colors.grey.shade100),
                          columns: const [
                            DataColumn(label: Text('No', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                            DataColumn(label: Text('Nama Item', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                            DataColumn(label: Text('Qty', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                            DataColumn(label: Text('Keterangan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                          ],
                          rows: details.asMap().entries.map((entry) {
                            final index = entry.key + 1;
                            final item = entry.value;
                            return DataRow(
                              cells: [
                                DataCell(Text(index.toString(), style: const TextStyle(fontSize: 10))),
                                DataCell(Text(item['item_nama'] ?? 'Item ${item['mtd_brg_kode']}', style: const TextStyle(fontSize: 10))),
                                DataCell(Text(item['mtd_qty'].toString(),
                                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFFF6A918)))),
                                DataCell(Text(item['mtd_keterangan']?.isNotEmpty == true ? item['mtd_keterangan'] : '-',
                                    style: const TextStyle(fontSize: 10))),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Footer Buttons
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _openEditMinta(header);
                    },
                    icon: const Icon(Icons.edit, size: 14),
                    label: Text(
                      'Edit',
                      style: GoogleFonts.montserrat(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.blue,
                      side: const BorderSide(color: Colors.blue),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, size: 14),
                    label: Text(
                      'Tutup',
                      style: GoogleFonts.montserrat(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF6A918),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.montserrat(
            fontSize: 10,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: GoogleFonts.montserrat(
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class MintaDataSource extends DataGridSource {
  MintaDataSource({
    required List<Map<String, dynamic>> mintaList,
    required Function(Map<String, dynamic>) onEdit,
    required Function(Map<String, dynamic>) onDelete,
  }) {
    _onEdit = onEdit;
    _onDelete = onDelete;

    _data = mintaList.asMap().entries.map((entry) {
      final index = entry.key + 1;
      final minta = entry.value;

      return DataGridRow(cells: [
        DataGridCell<int>(columnName: 'no', value: index),
        DataGridCell<String>(columnName: 'nomor', value: minta['mt_nomor']?.toString() ?? '-'),
        DataGridCell<String>(columnName: 'tanggal', value: _formatDate(minta['mt_tanggal'])),
        DataGridCell<String>(columnName: 'keterangan', value: minta['mt_keterangan']?.toString() ?? '-'),
        DataGridCell<String>(columnName: 'status', value: minta['mt_status_kirim'] == 1 ? 'Terkirim' : 'Pending'),
        DataGridCell<Map<String, dynamic>>(columnName: 'aksi', value: minta),
      ]);
    }).toList();
  }

  String _formatDate(String? dateString) {
    if (dateString == null || dateString.isEmpty) return '-';
    try {
      final date = DateTime.parse(dateString);
      return DateFormat('dd/MM/yy').format(date);
    } catch (e) {
      return dateString;
    }
  }

  List<DataGridRow> _data = [];
  late Function(Map<String, dynamic>) _onEdit;
  late Function(Map<String, dynamic>) _onDelete;

  @override
  List<DataGridRow> get rows => _data;

  @override
  DataGridRowAdapter buildRow(DataGridRow row) {
    return DataGridRowAdapter(
      cells: row.getCells().map<Widget>((cell) {
        if (cell.columnName == 'aksi') {
          final minta = cell.value as Map<String, dynamic>;
          return Container(
            alignment: Alignment.center,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Tombol Edit
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: IconButton(
                    icon: Icon(Icons.edit, size: 12, color: Colors.blue.shade700),
                    onPressed: () => _onEdit(minta),
                    padding: EdgeInsets.zero,
                  ),
                ),
                const SizedBox(width: 2),
                // Tombol Delete
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: IconButton(
                    icon: Icon(Icons.delete, size: 12, color: Colors.red.shade700),
                    onPressed: () => _onDelete(minta),
                    padding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
          );
        }

        if (cell.columnName == 'status') {
          final status = cell.value.toString();
          final isTerkirim = status == 'Terkirim';
          return Container(
            alignment: Alignment.center,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isTerkirim ? Colors.green.shade50 : Colors.orange.shade50,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: isTerkirim ? Colors.green.shade200 : Colors.orange.shade200,
                ),
              ),
              child: Text(
                status,
                style: GoogleFonts.montserrat(
                  fontSize: 9,
                  fontWeight: FontWeight.w500,
                  color: isTerkirim ? Colors.green.shade700 : Colors.orange.shade700,
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
      case 'aksi':
      case 'status':
        return Alignment.center;
      default:
        return Alignment.centerLeft;
    }
  }

  TextAlign _getTextAlign(String columnName) {
    switch (columnName) {
      case 'aksi':
      case 'status':
        return TextAlign.center;
      default:
        return TextAlign.left;
    }
  }

  FontWeight _getFontWeight(String columnName) {
    return FontWeight.normal;
  }
}