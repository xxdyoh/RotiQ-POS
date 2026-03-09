import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';
import '../services/do_service.dart';
import '../services/cabang_service.dart';
import '../models/cabang_model.dart';
import '../widgets/base_layout.dart';
import '../routes/app_routes.dart';
import 'do_form_screen.dart';

class DoListScreen extends StatefulWidget {
  const DoListScreen({super.key});

  @override
  State<DoListScreen> createState() => _DoListScreenState();
}

class _DoListScreenState extends State<DoListScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = false;
  bool _showDateFilter = false;
  List<Map<String, dynamic>> _doList = [];

  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now();
  final TextEditingController _startDateController = TextEditingController();
  final TextEditingController _endDateController = TextEditingController();

  final DataGridController _dataGridController = DataGridController();
  late DoDataSource _dataSource;

  @override
  void initState() {
    super.initState();
    _endDate = DateTime.now();
    _startDate = DateTime(_endDate.year, _endDate.month, 1);
    _updateDateControllers();
    _dataSource = DoDataSource(
      doList: [],
      onEdit: _openEditDo,
      onDelete: _deleteDo,
    );
    _loadDoData();
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

  Future<void> _loadDoData() async {
    setState(() => _isLoading = true);
    try {
      final data = await DoService.getDoList(
        search: _searchController.text.isEmpty ? null : _searchController.text,
        startDate: _formatDateForApi(_startDate),
        endDate: _formatDateForApi(_endDate),
      );
      setState(() {
        _doList = data;
        _dataSource = DoDataSource(
          doList: _doList,
          onEdit: _openEditDo,
          onDelete: _deleteDo,
        );
      });
    } catch (e) {
      _showSnackbar('Gagal memuat data pengiriman: ${e.toString()}', Colors.red);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _filterDo(String query) {
    _loadDoData();
  }

  void _showSnackbar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(color == Colors.green ? Icons.check_circle : Icons.error_outline, color: Colors.white, size: 16),
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
            colorScheme: const ColorScheme.light(primary: Color(0xFFF6A918), onPrimary: Colors.white),
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
          if (_startDate.isAfter(_endDate)) _endDate = _startDate;
        } else {
          _endDate = picked;
          if (_endDate.isBefore(_startDate)) _startDate = _endDate;
        }
        _updateDateControllers();
      });
      _loadDoData();
    }
  }

  void _resetDateFilter() {
    setState(() {
      _startDate = DateTime.now();
      _endDate = DateTime.now();
      _startDate = DateTime(_endDate.year, _endDate.month, 1);
      _updateDateControllers();
      _loadDoData();
    });
  }

  void _toggleDateFilter() {
    setState(() => _showDateFilter = !_showDateFilter);
  }

  void _openAddDo() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DoFormScreen(
          onDoSaved: _loadDoData,
        ),
      ),
    );
  }

  void _openEditDo(Map<String, dynamic> doData) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DoFormScreen(
          doHeader: doData,
          onDoSaved: _loadDoData,
        ),
      ),
    );
  }

  void _deleteDo(Map<String, dynamic> doData) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 20),
            const SizedBox(width: 8),
            Text('Hapus Pengiriman?', style: GoogleFonts.montserrat(fontSize: 14)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Apakah Anda yakin ingin menghapus:',
              style: GoogleFonts.montserrat(fontSize: 12),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    doData['do_nomor'],
                    style: GoogleFonts.montserrat(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  Text(
                    'Tanggal: ${_formatDate(doData['do_tanggal'])}',
                    style: GoogleFonts.montserrat(fontSize: 11, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Catatan: Hanya dapat menghapus data dengan tanggal yang sama dengan tanggal server.',
              style: GoogleFonts.montserrat(fontSize: 11, color: Colors.orange.shade800, fontStyle: FontStyle.italic),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Batal', style: GoogleFonts.montserrat(fontSize: 12, color: Colors.grey[600])),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _performDelete(doData);
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

  Future<void> _performDelete(Map<String, dynamic> doData) async {
    setState(() => _isLoading = true);
    try {
      final result = await DoService.deleteDo(doData['do_nomor'].toString());
      if (result['success']) {
        _showSnackbar(result['message'], Colors.green);
        await _loadDoData();
      } else {
        _showSnackbar(result['message'], Colors.red);
      }
    } catch (e) {
      _showSnackbar('Error: ${e.toString()}', Colors.red);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showDetailBottomSheet(Map<String, dynamic> doData) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => FutureBuilder<Map<String, dynamic>>(
        future: DoService.getDoDetail(doData['do_nomor']),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.85,
              decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
              child: const Center(child: CircularProgressIndicator(color: Color(0xFFF6A918))),
            );
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.85,
              decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, size: 40, color: Colors.grey.shade400),
                    const SizedBox(height: 8),
                    Text('Gagal memuat detail', style: GoogleFonts.montserrat(color: Colors.grey.shade600)),
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
    final isClosed = header['do_isclosed'] == 1;
    final totalQty = details.fold<int>(0, (sum, item) {
      final qty = item['dod_qty'];
      if (qty is int) return sum + qty;
      if (qty is double) return sum + qty.toInt();
      if (qty is String) return sum + (int.tryParse(qty) ?? 0);
      return sum;
    });

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey.shade200))),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: isClosed ? Colors.green.withOpacity(0.1) : const Color(0xFFF6A918).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        isClosed ? Icons.check_circle : Icons.local_shipping,
                        color: isClosed ? Colors.green : const Color(0xFFF6A918),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          header['do_nomor'] ?? '-',
                          style: GoogleFonts.montserrat(fontSize: 16, fontWeight: FontWeight.w700, color: const Color(0xFF2C3E50)),
                        ),
                        Text(
                          DateFormat('dd MMM yyyy').format(DateTime.parse(header['do_tanggal'])),
                          style: GoogleFonts.montserrat(fontSize: 11, color: Colors.grey.shade600),
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
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(10)),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(child: _buildInfoItem('No. Permintaan', header['do_mt_nomor'] ?? '-')),
                            Expanded(child: _buildInfoItem('Memo', header['do_memo'] ?? '-')),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: _buildInfoItem(
                                'Status',
                                isClosed ? 'Closed' : 'Open',
                                color: isClosed ? Colors.green : const Color(0xFFF6A918),
                              ),
                            ),
                            Expanded(
                              child: _buildInfoItem(
                                'Total Qty',
                                totalQty.toString(),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Detail Items',
                    style: GoogleFonts.montserrat(fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFF2C3E50)),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
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
                            DataColumn(label: Text('Qty Kirim', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                            DataColumn(label: Text('Keterangan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                          ],
                          rows: details.asMap().entries.map((entry) {
                            final index = entry.key + 1;
                            final item = entry.value;

                            int qty = 0;
                            final rawQty = item['dod_qty'];
                            if (rawQty is int) qty = rawQty;
                            else if (rawQty is double) qty = rawQty.toInt();
                            else if (rawQty is String) qty = int.tryParse(rawQty) ?? 0;

                            return DataRow(
                              cells: [
                                DataCell(Text(index.toString(), style: const TextStyle(fontSize: 10))),
                                DataCell(Text(item['item_nama'] ?? '-', style: const TextStyle(fontSize: 10))),
                                DataCell(Text(qty.toString(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFFF6A918)))),
                                DataCell(Text(item['dod_keterangan']?.isNotEmpty == true ? item['dod_keterangan'] : '-', style: const TextStyle(fontSize: 10))),
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
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Colors.grey.shade200))),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _openEditDo(header);
                    },
                    icon: const Icon(Icons.edit, size: 14),
                    label: Text('Edit', style: GoogleFonts.montserrat(fontSize: 12, fontWeight: FontWeight.w600)),
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
                    label: Text('Tutup', style: GoogleFonts.montserrat(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
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

  Widget _buildInfoItem(String label, String value, {Color? color}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.montserrat(fontSize: 10, color: Colors.grey.shade600)),
        const SizedBox(height: 2),
        Text(value, style: GoogleFonts.montserrat(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return BaseLayout(
      title: 'Pengiriman (DO)',
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
                    Text('Filter Tanggal', style: GoogleFonts.montserrat(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
                    IconButton(
                      icon: Icon(_showDateFilter ? Icons.expand_less : Icons.expand_more, size: 18, color: const Color(0xFFF6A918)),
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
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 3, offset: const Offset(0, 1))],
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Tanggal Mulai', style: GoogleFonts.montserrat(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
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
                                              style: GoogleFonts.montserrat(fontSize: 11, fontWeight: FontWeight.w500, color: Colors.black87),
                                              decoration: const InputDecoration(border: InputBorder.none, isDense: true),
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
                                Text('Tanggal Selesai', style: GoogleFonts.montserrat(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
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
                                              style: GoogleFonts.montserrat(fontSize: 11, fontWeight: FontWeight.w500, color: Colors.black87),
                                              decoration: const InputDecoration(border: InputBorder.none, isDense: true),
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
                          label: Text('Reset ke Awal Bulan', style: GoogleFonts.montserrat(fontSize: 11, fontWeight: FontWeight.w500)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey.shade600,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 3, offset: const Offset(0, 1))],
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
                                  hintText: 'Cari nomor/no permintaan/memo...',
                                  hintStyle: GoogleFonts.montserrat(fontSize: 11, color: Colors.grey.shade500),
                                  border: InputBorder.none,
                                  isDense: true,
                                ),
                                style: GoogleFonts.montserrat(fontSize: 11),
                                onChanged: _filterDo,
                              ),
                            ),
                            if (_searchController.text.isNotEmpty)
                              IconButton(
                                icon: Icon(Icons.clear, size: 12, color: Colors.grey.shade500),
                                onPressed: () {
                                  _searchController.clear();
                                  _filterDo('');
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
                        onPressed: _openAddDo,
                        icon: const Icon(Icons.add, size: 14, color: Colors.white),
                        label: Text('Tambah', style: GoogleFonts.montserrat(fontSize: 11, fontWeight: FontWeight.w500)),
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
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Total: ${_doList.length} pengiriman',
                          style: GoogleFonts.montserrat(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey.shade700),
                        ),
                        Text(
                          'Periode: ${DateFormat('dd/MM/yy').format(_startDate)} - ${DateFormat('dd/MM/yy').format(_endDate)}',
                          style: GoogleFonts.montserrat(fontSize: 9, color: Colors.grey.shade500),
                        ),
                      ],
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
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator(color: Color(0xFFF6A918)))
                    : _doList.isEmpty
                    ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.inbox_outlined, size: 40, color: Colors.grey.shade400),
                      const SizedBox(height: 8),
                      Text(
                        _searchController.text.isEmpty
                            ? 'Tidak ada data pengiriman\npada periode yang dipilih'
                            : 'Pengiriman tidak ditemukan',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.montserrat(color: Colors.grey.shade500, fontSize: 12),
                      ),
                    ],
                  ),
                )
                    : Container(
                  margin: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))],
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
                          if (dataRowIndex >= 0 && dataRowIndex < _doList.length) {
                            final data = _doList[dataRowIndex];
                            _showDetailBottomSheet(data);
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
                            child: const Text('No', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                          ),
                        ),
                        GridColumn(
                          columnName: 'nomor',
                          minimumWidth: 180,
                          maximumWidth: 220,
                          label: Container(
                            padding: const EdgeInsets.only(left: 4, top: 4),
                            alignment: Alignment.centerLeft,
                            child: const Text('Nomor DO', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                          ),
                        ),
                        GridColumn(
                          columnName: 'tanggal',
                          minimumWidth: 80,
                          maximumWidth: 100,
                          label: Container(
                            padding: const EdgeInsets.only(left: 4, top: 4),
                            alignment: Alignment.centerLeft,
                            child: const Text('Tanggal', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                          ),
                        ),
                        GridColumn(
                          columnName: 'mt_nomor',
                          minimumWidth: 150,
                          maximumWidth: 180,
                          label: Container(
                            padding: const EdgeInsets.only(left: 4, top: 4),
                            alignment: Alignment.centerLeft,
                            child: const Text('No. Permintaan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                          ),
                        ),
                        GridColumn(
                          columnName: 'memo',
                          minimumWidth: 200,
                          maximumWidth: 300,
                          label: Container(
                            padding: const EdgeInsets.only(left: 4, top: 4),
                            alignment: Alignment.centerLeft,
                            child: const Text('Memo', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                          ),
                        ),
                        GridColumn(
                          columnName: 'status',
                          minimumWidth: 80,
                          maximumWidth: 100,
                          label: Container(
                            padding: const EdgeInsets.only(left: 4, top: 4),
                            alignment: Alignment.center,
                            child: const Text('Status', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                          ),
                        ),
                        GridColumn(
                          columnName: 'aksi',
                          minimumWidth: 80,
                          maximumWidth: 90,
                          label: Container(
                            padding: const EdgeInsets.only(left: 4, top: 4),
                            alignment: Alignment.center,
                            child: const Text('Aksi', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
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

class DoDataSource extends DataGridSource {
  DoDataSource({
    required List<Map<String, dynamic>> doList,
    required Function(Map<String, dynamic>) onEdit,
    required Function(Map<String, dynamic>) onDelete,
  }) {
    _onEdit = onEdit;
    _onDelete = onDelete;

    _data = doList.asMap().entries.map((entry) {
      final index = entry.key + 1;
      final data = entry.value;

      return DataGridRow(cells: [
        DataGridCell<int>(columnName: 'no', value: index),
        DataGridCell<String>(columnName: 'nomor', value: data['do_nomor']?.toString() ?? '-'),
        DataGridCell<String>(columnName: 'tanggal', value: _formatDate(data['do_tanggal'])),
        DataGridCell<String>(columnName: 'mt_nomor', value: data['do_mt_nomor']?.toString() ?? '-'),
        DataGridCell<String>(columnName: 'memo', value: data['do_memo']?.toString() ?? '-'),
        DataGridCell<String>(columnName: 'status', value: data['do_isclosed'] == 1 ? 'Closed' : 'Open'),
        DataGridCell<Map<String, dynamic>>(columnName: 'aksi', value: data),
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
          final data = cell.value as Map<String, dynamic>;
          return Container(
            alignment: Alignment.center,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(4)),
                  child: IconButton(
                    icon: Icon(Icons.edit, size: 12, color: Colors.blue.shade700),
                    onPressed: () => _onEdit(data),
                    padding: EdgeInsets.zero,
                  ),
                ),
                const SizedBox(width: 2),
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(4)),
                  child: IconButton(
                    icon: Icon(Icons.delete, size: 12, color: Colors.red.shade700),
                    onPressed: () => _onDelete(data),
                    padding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
          );
        }

        if (cell.columnName == 'status') {
          final status = cell.value.toString();
          final isClosed = status == 'Closed';
          return Container(
            alignment: Alignment.center,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isClosed ? Colors.green.shade50 : Colors.orange.shade50,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: isClosed ? Colors.green.shade200 : Colors.orange.shade200),
              ),
              child: Text(
                status,
                style: GoogleFonts.montserrat(
                  fontSize: 9,
                  fontWeight: FontWeight.w500,
                  color: isClosed ? Colors.green.shade700 : Colors.orange.shade700,
                ),
              ),
            ),
          );
        }

        return Container(
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Text(
            cell.value.toString(),
            style: GoogleFonts.montserrat(fontSize: 10, color: Colors.black87),
          ),
        );
      }).toList(),
    );
  }
}