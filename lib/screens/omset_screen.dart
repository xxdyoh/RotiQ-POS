import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';
import 'package:syncfusion_flutter_xlsio/xlsio.dart' hide Row, Border, Column;
import 'package:universal_html/html.dart' as html;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart';
import '../services/omset_service.dart';
import '../services/api_service.dart';
import '../models/omset_model.dart';
import '../models/cabang_model.dart';
import '../widgets/base_layout.dart';
import '../utils/responsive_helper.dart';

class OmsetScreen extends StatefulWidget {
  const OmsetScreen({super.key});

  @override
  State<OmsetScreen> createState() => _OmsetScreenState();
}

class _OmsetScreenState extends State<OmsetScreen> {
  String _selectedTahun = DateTime.now().year.toString();
  String _selectedTipe = 'daily';
  Cabang? _selectedCabang;
  List<Cabang> _cabangList = [];
  List<OmsetData> _data = [];
  bool _isLoading = false;

  final NumberFormat _currencyFormat =
  NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

  final Color _primaryDark = const Color(0xFF2C3E50);
  final Color _accentGold = const Color(0xFFF6A918);
  final Color _accentMint = const Color(0xFF06D6A0);
  final Color _accentRed = const Color(0xFFEF4444);
  final Color _bgSoft = const Color(0xFFF8FAFC);
  final Color _surfaceWhite = Colors.white;
  final Color _textDark = const Color(0xFF1A202C);
  final Color _textMedium = const Color(0xFF718096);
  final Color _textLight = const Color(0xFFA0AEC0);
  final Color _borderSoft = const Color(0xFFE2E8F0);

  List<String> get _tahunList {
    final currentYear = DateTime.now().year;
    return List.generate(5, (i) => (currentYear - i).toString());
  }

  @override
  void initState() {
    super.initState();
    _loadCabangList();
  }

  Future<void> _loadCabangList() async {
    try {
      final cabangs = await ApiService.getCabangList();
      setState(() {
        _cabangList = cabangs;
        if (cabangs.isNotEmpty) {
          _selectedCabang = cabangs.first;
          _loadData();
        }
      });
    } catch (e) {
      debugPrint('Gagal load cabang: $e');
    }
  }

  Future<void> _loadData() async {
    if (_selectedCabang == null) return;

    setState(() => _isLoading = true);

    try {
      final response = await OmsetService.getOmset(
        tahun: _selectedTahun,
        tipe: _selectedTipe,
        cabangKode: _selectedCabang!.kode,
      );

      if (response['success'] == true) {
        final List<dynamic> rawData = response['data'];
        setState(() {
          _data = rawData.map((json) => OmsetData.fromJson(json)).toList();
        });
      }
    } catch (e) {
      _showSnackbar('Gagal memuat data: $e', true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  String _getLabel(OmsetData item) {
    switch (_selectedTipe) {
      case 'daily':
        return item.tanggal;
      case 'weekly':
        return item.week;
      case 'monthly':
        return item.bulan;
      default:
        return '';
    }
  }

  String _getHeaderLabel() {
    switch (_selectedTipe) {
      case 'daily':
        return 'Tanggal';
      case 'weekly':
        return 'Week';
      case 'monthly':
        return 'Bulan';
      default:
        return '';
    }
  }

  Future<void> _exportToExcel() async {
    if (_data.isEmpty) {
      _showSnackbar('Tidak ada data untuk di-export', true);
      return;
    }

    try {
      final Workbook workbook = Workbook();
      final Worksheet sheet = workbook.worksheets[0];
      sheet.name = 'Laporan Omset';

      final isDaily = _selectedTipe == 'daily';
      final colCount = isDaily ? 4 : 3;

      // Judul
      sheet.getRangeByIndex(1, 1, 1, colCount).merge();
      sheet.getRangeByIndex(1, 1).setText(
          'Laporan Omset - ${_selectedCabang?.nama ?? ''}');
      sheet.getRangeByIndex(1, 1).cellStyle.fontSize = 14;
      sheet.getRangeByIndex(1, 1).cellStyle.bold = true;
      sheet.getRangeByIndex(1, 1).cellStyle.hAlign = HAlignType.center;

      // Periode
      sheet.getRangeByIndex(2, 1, 2, colCount).merge();
      sheet.getRangeByIndex(2, 1).setText(
          'Tahun: $_selectedTahun | Tipe: ${_selectedTipe.toUpperCase()}');
      sheet.getRangeByIndex(2, 1).cellStyle.fontSize = 11;
      sheet.getRangeByIndex(2, 1).cellStyle.hAlign = HAlignType.center;

      // Lebar kolom
      if (isDaily) {
        sheet.getRangeByIndex(1, 1).columnWidth = 16;
        sheet.getRangeByIndex(1, 2).columnWidth = 14;
        sheet.getRangeByIndex(1, 3).columnWidth = 20;
        sheet.getRangeByIndex(1, 4).columnWidth = 12;
      } else {
        sheet.getRangeByIndex(1, 1).columnWidth = 18;
        sheet.getRangeByIndex(1, 2).columnWidth = 20;
        sheet.getRangeByIndex(1, 3).columnWidth = 12;
      }

      // Header
      int headerRow = 4;
      final hdr = sheet.getRangeByIndex(headerRow, 1, headerRow, colCount);
      hdr.cellStyle.backColor = '#2C3E50';
      hdr.cellStyle.fontColor = '#FFFFFF';
      hdr.cellStyle.bold = true;
      hdr.cellStyle.fontSize = 10;
      hdr.cellStyle.hAlign = HAlignType.center;

      if (isDaily) {
        sheet.getRangeByIndex(headerRow, 1).setText('Tanggal');
        sheet.getRangeByIndex(headerRow, 2).setText('Hari');
        sheet.getRangeByIndex(headerRow, 3).setText('Nilai');
        sheet.getRangeByIndex(headerRow, 4).setText('Growth');
      } else {
        sheet.getRangeByIndex(headerRow, 1).setText(
            _selectedTipe == 'weekly' ? 'Week' : 'Bulan');
        sheet.getRangeByIndex(headerRow, 2).setText('Nilai');
        sheet.getRangeByIndex(headerRow, 3).setText('Growth');
      }

      // Data
      int row = headerRow + 1;
      double totalNilai = 0;

      for (var item in _data) {
        if (isDaily) {
          sheet.getRangeByIndex(row, 1).setText(item.tanggal);
          sheet.getRangeByIndex(row, 2).setText(item.hari);
          sheet.getRangeByIndex(row, 3).setNumber(item.nilai);
          sheet.getRangeByIndex(row, 4).setText(item.growth);
        } else {
          sheet.getRangeByIndex(row, 1)
              .setText(_selectedTipe == 'weekly' ? item.week : item.bulan);
          sheet.getRangeByIndex(row, 2).setNumber(item.nilai);
          sheet.getRangeByIndex(row, 3).setText(item.growth);
        }

        sheet.getRangeByIndex(row, colCount).cellStyle.hAlign =
            HAlignType.right;
        totalNilai += item.nilai;

        if (row % 2 == 0) {
          sheet.getRangeByIndex(row, 1, row, colCount).cellStyle.backColor =
          '#F8F9FA';
        }
        row++;
      }

      // Total
      sheet.getRangeByIndex(row, 1).setText('TOTAL');
      sheet.getRangeByIndex(row, 1).cellStyle.bold = true;
      sheet.getRangeByIndex(row, 1).cellStyle.backColor = '#E9ECEF';
      sheet.getRangeByIndex(row, isDaily ? 3 : 2).setNumber(totalNilai);
      sheet.getRangeByIndex(row, isDaily ? 3 : 2).cellStyle.bold = true;
      sheet.getRangeByIndex(row, isDaily ? 3 : 2).cellStyle.backColor =
      '#E9ECEF';
      sheet.getRangeByIndex(row, isDaily ? 3 : 2).cellStyle.hAlign =
          HAlignType.right;

      final List<int> bytes = workbook.saveAsStream();
      workbook.dispose();

      final fileName =
          'Omset_${_selectedCabang?.kode ?? ''}_$_selectedTahun$_selectedTipe.xlsx';

      if (kIsWeb) {
        final blob = html.Blob([bytes],
            'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
        final url = html.Url.createObjectUrlFromBlob(blob);
        html.AnchorElement(href: url)
          ..target = 'blank'
          ..download = fileName
          ..click();
        html.Url.revokeObjectUrl(url);
      } else {
        final directory = await getApplicationDocumentsDirectory();
        final file = File('${directory.path}/$fileName');
        await file.writeAsBytes(bytes);
      }
      _showSnackbar('Export berhasil', false);
    } catch (e) {
      _showSnackbar('Gagal export: ${e.toString()}', true);
    }
  }

  void _showSnackbar(String message, bool isError) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message,
          style: GoogleFonts.montserrat(fontSize: 11, color: Colors.white)),
      backgroundColor: isError ? _accentRed : _accentMint,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      margin: const EdgeInsets.all(12),
      duration: const Duration(seconds: 2),
    ));
  }

  Widget _buildGrowthCell(String growth) {
    Color color;
    IconData? icon;

    if (growth == '-') {
      color = _textMedium;
    } else {
      final value = double.tryParse(growth.replaceAll('%', ''));
      if (value == null) {
        color = _textMedium;
      } else if (value > 0) {
        color = _accentMint;
        icon = Icons.trending_up;
      } else if (value < 0) {
        color = _accentRed;
        icon = Icons.trending_down;
      } else {
        color = _textMedium;
      }
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) Icon(icon, size: 14, color: color),
        if (icon != null) const SizedBox(width: 4),
        Text(growth,
            style: GoogleFonts.montserrat(
                fontSize: 11, fontWeight: FontWeight.w600, color: color)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveHelper.isMobile(context);
    final isDaily = _selectedTipe == 'daily';
    final totalNilai = _data.fold<double>(0, (sum, d) => sum + d.nilai);

    return BaseLayout(
      title: 'Laporan Omset',
      showBackButton: false,
      showSidebar: !isMobile,
      isFormScreen: false,
      child: Container(
        color: _bgSoft,
        child: Column(
          children: [
            // Filter
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _surfaceWhite,
                border: Border(bottom: BorderSide(color: _borderSoft)),
              ),
              child: Wrap(
                spacing: 10,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  // Tahun
                  Container(
                    height: 40,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: _bgSoft,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _borderSoft),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedTahun,
                        isExpanded: false,
                        style: GoogleFonts.montserrat(
                            fontSize: 12, color: _textDark),
                        items: _tahunList
                            .map((t) =>
                            DropdownMenuItem(value: t, child: Text(t)))
                            .toList(),
                        onChanged: (v) =>
                            setState(() => _selectedTahun = v!),
                        icon: Icon(Icons.arrow_drop_down, color: _accentGold),
                      ),
                    ),
                  ),

                  // Tipe
                  Container(
                    height: 40,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: _bgSoft,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _borderSoft),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedTipe,
                        isExpanded: false,
                        style: GoogleFonts.montserrat(
                            fontSize: 12, color: _textDark),
                        items: const [
                          DropdownMenuItem(
                              value: 'daily', child: Text('Daily')),
                          DropdownMenuItem(
                              value: 'weekly', child: Text('Weekly')),
                          DropdownMenuItem(
                              value: 'monthly', child: Text('Monthly')),
                        ],
                        onChanged: (v) =>
                            setState(() => _selectedTipe = v!),
                        icon: Icon(Icons.arrow_drop_down, color: _accentGold),
                      ),
                    ),
                  ),

                  // Cabang
                  Container(
                    height: 40,
                    width: 180,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: _bgSoft,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _borderSoft),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedCabang?.kode,
                        isExpanded: true,
                        style: GoogleFonts.montserrat(
                            fontSize: 12, color: _textDark),
                        hint: Text('Pilih Cabang',
                            style: GoogleFonts.montserrat(
                                fontSize: 12, color: _textLight)),
                        items: _cabangList
                            .map((c) => DropdownMenuItem(
                          value: c.kode,
                          child: Text('${c.kode} - ${c.nama}',
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.montserrat(
                                  fontSize: 12)),
                        ))
                            .toList(),
                        onChanged: (v) {
                          setState(() => _selectedCabang =
                              _cabangList.firstWhere((c) => c.kode == v));
                        },
                        icon: Icon(Icons.arrow_drop_down, color: _accentGold),
                      ),
                    ),
                  ),

                  // Load Button
                  Container(
                    height: 40,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                          colors: [_accentGold, _accentGold.withOpacity(0.8)]),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: _isLoading ? null : _loadData,
                        borderRadius: BorderRadius.circular(8),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.refresh_rounded,
                                size: 16, color: Colors.white),
                            const SizedBox(width: 6),
                            Text('Load',
                                style: GoogleFonts.montserrat(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white)),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Export Button
                  Container(
                    height: 40,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                          colors: [_accentMint, _accentMint.withOpacity(0.8)]),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: _data.isEmpty ? null : _exportToExcel,
                        borderRadius: BorderRadius.circular(8),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.download,
                                size: 16, color: Colors.white),
                            const SizedBox(width: 6),
                            Text('Export',
                                style: GoogleFonts.montserrat(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Data
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _data.isEmpty
                  ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.trending_up,
                        size: 48, color: _textLight),
                    const SizedBox(height: 12),
                    Text('Tidak ada data',
                        style: GoogleFonts.montserrat(
                            fontSize: 14, color: _textMedium)),
                    const SizedBox(height: 4),
                    Text('Pilih filter dan klik Load',
                        style: GoogleFonts.montserrat(
                            fontSize: 11, color: _textLight)),
                  ],
                ),
              )
                  : Column(
                children: [
                  // Grid full width
                  Expanded(
                    child: Container(
                      margin: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _surfaceWhite,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _borderSoft),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: SfDataGrid(
                          source: _OmsetDataSource(
                            data: _data,
                            isDaily: isDaily,
                            currencyFormat: _currencyFormat,
                            totalNilai: totalNilai,
                            growthBuilder: _buildGrowthCell,
                            getLabel: _getLabel,
                          ),
                          columnWidthMode: ColumnWidthMode.fill,
                          headerRowHeight: 38,
                          rowHeight: 36,
                          gridLinesVisibility:
                          GridLinesVisibility.both,
                          headerGridLinesVisibility:
                          GridLinesVisibility.both,
                          columns: [
                            GridColumn(
                              columnName: 'label',
                              label: Container(
                                alignment: Alignment.centerLeft,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12),
                                child: Text(_getHeaderLabel(),
                                    style: GoogleFonts.montserrat(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 11,
                                        color: _textDark)),
                              ),
                            ),
                            if (isDaily)
                              GridColumn(
                                columnName: 'sub',
                                width: 100,
                                label: Container(
                                  alignment: Alignment.center,
                                  child: Text('Hari',
                                      style: GoogleFonts.montserrat(
                                          fontWeight:
                                          FontWeight.w600,
                                          fontSize: 11,
                                          color: _textDark)),
                                ),
                              ),
                            GridColumn(
                              columnName: 'nilai',
                              width: isDaily ? 150 : 180,
                              label: Container(
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12),
                                child: Text('Nilai',
                                    style: GoogleFonts.montserrat(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 11,
                                        color: _textDark)),
                              ),
                            ),
                            GridColumn(
                              columnName: 'growth',
                              width: 110,
                              label: Container(
                                alignment: Alignment.centerLeft,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12),
                                child: Text('Growth',
                                    style: GoogleFonts.montserrat(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 11,
                                        color: _textDark)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Footer
                  Container(
                    margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: _surfaceWhite,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _borderSoft),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: _accentGold.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                              'Total: ${_currencyFormat.format(totalNilai)}',
                              style: GoogleFonts.montserrat(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: _accentGold)),
                        ),
                        const Spacer(),
                        Icon(Icons.info_outline,
                            size: 14, color: _textLight),
                        const SizedBox(width: 6),
                        Text(
                            'Tahun $_selectedTahun • ${_selectedTipe.toUpperCase()}',
                            style: GoogleFonts.montserrat(
                                fontSize: 10, color: _textMedium)),
                        const SizedBox(width: 12),
                        Text('${_data.length} data',
                            style: GoogleFonts.montserrat(
                                fontSize: 10, color: _textMedium)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ========== DATASOURCE ==========
class _OmsetDataSource extends DataGridSource {
  final List<OmsetData> data;
  final bool isDaily;
  final NumberFormat currencyFormat;
  final double totalNilai;
  final Widget Function(String) growthBuilder;
  final String Function(OmsetData) getLabel;

  _OmsetDataSource({
    required this.data,
    required this.isDaily,
    required this.currencyFormat,
    required this.totalNilai,
    required this.growthBuilder,
    required this.getLabel,
  }) {
    _buildRows();
  }

  List<DataGridRow> _rows = [];

  void _buildRows() {
    _rows = [];

    // Data rows
    for (int i = 0; i < data.length; i++) {
      final item = data[i];
      if (isDaily) {
        _rows.add(DataGridRow(cells: [
          DataGridCell<String>(columnName: 'label', value: getLabel(item)),
          DataGridCell<String>(columnName: 'sub', value: item.hari),
          DataGridCell<double>(columnName: 'nilai', value: item.nilai),
          DataGridCell<String>(columnName: 'growth', value: item.growth),
        ]));
      } else {
        _rows.add(DataGridRow(cells: [
          DataGridCell<String>(columnName: 'label', value: getLabel(item)),
          DataGridCell<double>(columnName: 'nilai', value: item.nilai),
          DataGridCell<String>(columnName: 'growth', value: item.growth),
        ]));
      }
    }

    // Total row
    if (isDaily) {
      _rows.add(DataGridRow(cells: [
        const DataGridCell<String>(columnName: 'label', value: 'TOTAL'),
        const DataGridCell<String>(columnName: 'sub', value: ''),
        DataGridCell<double>(columnName: 'nilai', value: totalNilai),
        const DataGridCell<String>(columnName: 'growth', value: ''),
      ]));
    } else {
      _rows.add(DataGridRow(cells: [
        const DataGridCell<String>(columnName: 'label', value: 'TOTAL'),
        DataGridCell<double>(columnName: 'nilai', value: totalNilai),
        const DataGridCell<String>(columnName: 'growth', value: ''),
      ]));
    }
  }

  @override
  List<DataGridRow> get rows => _rows;

  @override
  DataGridRowAdapter? buildRow(DataGridRow row) {
    final cells = row.getCells();
    final isTotalRow = cells[0].value == 'TOTAL';

    return DataGridRowAdapter(
      color: isTotalRow ? const Color(0xFFF6A918).withOpacity(0.08) : null,
      cells: cells.map<Widget>((cell) {
        // Label
        if (cell.columnName == 'label') {
          return Container(
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(cell.value.toString(),
                style: GoogleFonts.montserrat(
                    fontSize: 11,
                    fontWeight:
                    isTotalRow ? FontWeight.w700 : FontWeight.w500,
                    color: isTotalRow
                        ? const Color(0xFFF6A918)
                        : const Color(0xFF1A202C))),
          );
        }

        // Sub (hari)
        if (cell.columnName == 'sub') {
          return Container(
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(cell.value.toString(),
                style: GoogleFonts.montserrat(
                    fontSize: 11, color: const Color(0xFF718096))),
          );
        }

        // Nilai
        if (cell.columnName == 'nilai') {
          return Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(currencyFormat.format(cell.value),
                style: GoogleFonts.montserrat(
                    fontSize: 12,
                    fontWeight:
                    isTotalRow ? FontWeight.w800 : FontWeight.w600,
                    color: const Color(0xFFF6A918))),
          );
        }

        // Growth
        if (cell.columnName == 'growth') {
          return Container(
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: growthBuilder(cell.value.toString()),
          );
        }

        return Container();
      }).toList(),
    );
  }
}