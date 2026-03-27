import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import '../widgets/base_layout.dart';
import '../services/dashboard_service.dart';
import '../models/dashboard_model.dart';
import '../services/session_manager.dart';
import '../services/api_service.dart';

class ChartData {
  final String x;
  final double y;
  ChartData({required this.x, required this.y});
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _isLoading = true;
  DashboardResponse? _dashboardData;

  DateTime? _startDate;
  DateTime? _endDate;
  String _groupBy = 'day';
  String _selectedJenis = 'all';

  DateTime? _tempStartDate;
  DateTime? _tempEndDate;
  String _tempGroupBy = 'day';
  String _tempSelectedJenis = 'all';

  List<Map<String, dynamic>> _cabangList = [];
  List<String> _jenisList = [];
  bool _isPusat = false;
  List<bool> _selectedCabangVisibility = [];
  List<String> _selectedCabangKodes = [];

  final AppTheme _theme = AppTheme();
  final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );
  final NumberFormat _numberFormat = NumberFormat('#,##0');

  @override
  void initState() {
    super.initState();
    _endDate = DateTime.now();
    _startDate = _endDate!.subtract(const Duration(days: 30));
    _tempStartDate = _startDate;
    _tempEndDate = _endDate;
    _tempGroupBy = _groupBy;
    _tempSelectedJenis = _selectedJenis;
    _checkUserRole();
    _loadInitialData();
  }

  void _checkUserRole() {
    final user = SessionManager.getCurrentUser();
    final cabang = SessionManager.getCurrentCabang();
    setState(() {
      _isPusat = user?.kduser == '00' || cabang?.kode == '00';
    });
  }

  Future<void> _loadInitialData() async {
    if (_isPusat) {
      await _loadCabangList();
    } else {
      await _loadDashboardData();
    }
  }

  Future<void> _loadCabangList() async {
    try {
      final data = await DashboardService.getCabangList();
      setState(() {
        _jenisList = ['all', ...(data['jenis'] as List?)?.cast<String>() ?? []];
        _cabangList = (data['cabangs'] as List?)?.cast<Map<String, dynamic>>() ?? [];
        _selectedCabangKodes = _cabangList.map((c) => c['kode'] as String).toList();
        _selectedCabangVisibility = List.generate(_cabangList.length, (index) => true);
      });
      await _loadDashboardData();
    } catch (e) {
      setState(() => _isLoading = false);
      _showErrorSnackBar('Gagal memuat data cabang');
    }
  }

  Future<void> _loadDashboardData() async {
    if (_tempStartDate == null || _tempEndDate == null) return;

    setState(() => _isLoading = true);
    try {
      String? jenisParam = _tempSelectedJenis != 'all' ? _tempSelectedJenis : null;
      final data = await DashboardService.getDashboardData(
        startDate: _tempStartDate!,
        endDate: _tempEndDate!,
        groupBy: _tempGroupBy,
        jenis: jenisParam,
      );

      if (_tempGroupBy == 'year' && data.sales.isNotEmpty) {
        final Map<String, double> yearMap = {};

        for (var sale in data.sales) {
          String dateStr = sale.label;
          String year = dateStr.substring(0, 4);
          yearMap[year] = (yearMap[year] ?? 0) + sale.totalSales;
        }

        final sortedYears = yearMap.keys.toList()..sort((a, b) => int.parse(a).compareTo(int.parse(b)));
        final newSales = sortedYears.map((year) => DashboardSalesData(
          label: year,
          totalSales: yearMap[year] ?? 0,
        )).toList();

        data.sales = newSales;
      }

      if (data.multiSeriesSales != null && data.multiSeriesSales!.dates.isNotEmpty && _tempGroupBy == 'year') {
        final originalDates = data.multiSeriesSales!.dates;
        final originalSeries = data.multiSeriesSales!.series;

        final Map<String, Map<String, double>> yearDataMap = {};

        for (var cabangData in originalSeries) {
          final cabangNama = cabangData['cabang_nama'] as String;
          final oldData = List<double>.from(cabangData['data']);

          for (int i = 0; i < originalDates.length; i++) {
            final dateStr = originalDates[i];
            final year = dateStr.substring(0, 4);
            final sales = oldData[i];

            yearDataMap.putIfAbsent(cabangNama, () => {});
            yearDataMap[cabangNama]![year] = (yearDataMap[cabangNama]![year] ?? 0) + sales;
          }
        }

        final allYears = <String>{};
        for (var cabangData in yearDataMap.values) {
          allYears.addAll(cabangData.keys);
        }
        final sortedYears = allYears.toList()..sort((a, b) => int.parse(a).compareTo(int.parse(b)));

        final newSeries = <Map<String, dynamic>>[];
        for (var entry in yearDataMap.entries) {
          final dataByYear = entry.value;
          final dataList = sortedYears.map((year) => dataByYear[year] ?? 0).toList();
          newSeries.add({
            'cabang_nama': entry.key,
            'data': dataList,
          });
        }

        newSeries.sort((a, b) {
          final totalA = (a['data'] as List<double>).reduce((sum, val) => sum + val);
          final totalB = (b['data'] as List<double>).reduce((sum, val) => sum + val);
          return totalB.compareTo(totalA);
        });

        data.multiSeriesSales = MultiSeriesSalesData(
          dates: sortedYears,
          series: newSeries,
        );
      } else if (data.multiSeriesSales != null && data.multiSeriesSales!.dates.isNotEmpty) {
        final originalDates = data.multiSeriesSales!.dates;
        final originalSeries = data.multiSeriesSales!.series;

        final indices = List.generate(originalDates.length, (i) => i);
        indices.sort((a, b) {
          final dateA = DateTime.tryParse(originalDates[a]);
          final dateB = DateTime.tryParse(originalDates[b]);
          if (dateA == null || dateB == null) return 0;
          return dateA.compareTo(dateB);
        });

        final sortedDates = indices.map((i) => originalDates[i]).toList();

        final sortedSeries = originalSeries.map((cabangData) {
          final oldData = List<double>.from(cabangData['data']);
          final newData = indices.map((i) => oldData[i]).toList();
          return {
            'cabang_nama': cabangData['cabang_nama'],
            'data': newData,
          };
        }).toList();

        data.multiSeriesSales = MultiSeriesSalesData(
          dates: sortedDates,
          series: sortedSeries,
        );
      }

      setState(() {
        _dashboardData = data;
        _isLoading = false;
      });
      if (_isPusat) await _loadSecondaryData();
    } catch (e) {
      setState(() => _isLoading = false);
      _showErrorSnackBar('Gagal memuat data: $e');
    }
  }

  Future<Map<String, String>> _getHeaders() async {
    final token = await ApiService.getToken();
    final cabang = SessionManager.getCurrentCabang();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
      if (cabang != null) 'X-Cabang-Kode': cabang.kode,
    };
  }

  Future<void> _loadSecondaryData() async {
    if (!_isPusat) return;

    final selectedKodes = _selectedCabangKodes.isEmpty
        ? _cabangList.map((c) => c['kode'] as String).toList()
        : _selectedCabangKodes;

    if (selectedKodes.isEmpty) {
      setState(() {
        _dashboardData?.categories.clear();
        _dashboardData?.kasir.clear();
        _dashboardData?.topItems.clear();
      });
      return;
    }

    try {
      final headers = await _getHeaders();
      final cabangKodesParam = selectedKodes.join(',');
      final jenisParam = _tempSelectedJenis != 'all' ? _tempSelectedJenis : null;
      final baseUrl = '${ApiService.baseUrl}/dashboard/data-by-cabang?'
          'start_date=${DateFormat('yyyy-MM-dd').format(_tempStartDate!)}'
          '&end_date=${DateFormat('yyyy-MM-dd').format(_tempEndDate!)}'
          '${jenisParam != null ? '&jenis=$jenisParam' : ''}';

      final results = await Future.wait([
        http.get(Uri.parse('$baseUrl&data_type=category&cabang_kodes=$cabangKodesParam'), headers: headers),
        http.get(Uri.parse('$baseUrl&data_type=kasir&cabang_kodes=$cabangKodesParam'), headers: headers),
        http.get(Uri.parse('$baseUrl&data_type=topItems&cabang_kodes=$cabangKodesParam'), headers: headers),
      ]);

      if (results.every((r) => r.statusCode == 200)) {
        final categoryData = jsonDecode(results[0].body);
        final kasirData = jsonDecode(results[1].body);
        final topItemsData = jsonDecode(results[2].body);

        final categories = _aggregateCategoryData(categoryData);
        final kasir = _aggregateKasirData(kasirData);
        final topItems = _aggregateTopItemsData(topItemsData);

        setState(() {
          if (_dashboardData != null) {
            _dashboardData!.categories = categories;
            _dashboardData!.kasir = kasir;
            _dashboardData!.topItems = topItems.take(10).toList();
          }
        });
      }
    } catch (e) {
      debugPrint('Error loading secondary data: $e');
    }
  }

  List<DashboardCategoryData> _aggregateCategoryData(Map<String, dynamic> data) {
    final aggregated = <String, double>{};
    if (data['success'] == true) {
      for (var cabang in data['data']) {
        for (var item in cabang['data']) {
          final category = item['category'] as String;
          final amount = (item['total_amount'] ?? 0).toDouble();
          aggregated[category] = (aggregated[category] ?? 0) + amount;
        }
      }
    }
    return aggregated.entries
        .map((e) => DashboardCategoryData(category: e.key, totalAmount: e.value))
        .toList()
      ..sort((a, b) => b.totalAmount.compareTo(a.totalAmount));
  }

  List<DashboardKasirData> _aggregateKasirData(Map<String, dynamic> data) {
    final aggregated = <String, double>{};
    if (data['success'] == true) {
      for (var cabang in data['data']) {
        for (var item in cabang['data']) {
          final kasir = item['kasir'] as String;
          final amount = (item['total_amount'] ?? 0).toDouble();
          aggregated[kasir] = (aggregated[kasir] ?? 0) + amount;
        }
      }
    }
    return aggregated.entries
        .map((e) => DashboardKasirData(kasir: e.key, totalAmount: e.value))
        .toList()
      ..sort((a, b) => b.totalAmount.compareTo(a.totalAmount));
  }

  List<DashboardTopItem> _aggregateTopItemsData(Map<String, dynamic> data) {
    final aggregated = <String, Map<String, dynamic>>{};
    if (data['success'] == true) {
      for (var cabang in data['data']) {
        for (var item in cabang['data']) {
          final itemId = item['item_id'].toString();
          aggregated.putIfAbsent(itemId, () => {
            'item_name': item['item_name'],
            'category': item['category'] ?? '',
            'total_qty': 0,
            'total_amount': 0.0,
          });
          aggregated[itemId]!['total_qty'] += (item['total_qty'] ?? 0).toInt();
          aggregated[itemId]!['total_amount'] += (item['total_amount'] ?? 0).toDouble();
        }
      }
    }
    return aggregated.values
        .map((e) => DashboardTopItem(
      itemName: e['item_name'],
      category: e['category'],
      totalQty: e['total_qty'],
      totalAmount: e['total_amount'],
    ))
        .toList()
      ..sort((a, b) => b.totalQty.compareTo(a.totalQty));
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: _theme.caption),
        backgroundColor: _theme.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(12),
      ),
    );
  }

  Future<void> _selectStartDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: ColorScheme.light(
              primary: _theme.primary,
              onPrimary: Colors.white,
            ),
            dialogBackgroundColor: Colors.white,
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _startDate) {
      setState(() {
        _startDate = picked;
      });
    }
  }

  Future<void> _selectEndDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: ColorScheme.light(
              primary: _theme.primary,
              onPrimary: Colors.white,
            ),
            dialogBackgroundColor: Colors.white,
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _endDate) {
      setState(() {
        _endDate = picked;
      });
    }
  }

  Future<void> _refreshDashboard() async {
    setState(() {
      _tempStartDate = _startDate;
      _tempEndDate = _endDate;
      _tempGroupBy = _groupBy;
      _tempSelectedJenis = _selectedJenis;
    });
    await _loadDashboardData();
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    return BaseLayout(
      title: 'Dashboard',
      showBackButton: false,
      showSidebar: true,
      isFormScreen: false,
      child: Container(
        color: _theme.background,
        child: Column(
          children: [
            _FilterBar(
              startDate: _startDate,
              endDate: _endDate,
              groupBy: _groupBy,
              selectedJenis: _selectedJenis,
              jenisList: _jenisList,
              isPusat: _isPusat,
              onStartDateTap: () => _selectStartDate(context),
              onEndDateTap: () => _selectEndDate(context),
              onGroupByChanged: (value) {
                if (value != null) {
                  setState(() => _groupBy = value);
                }
              },
              onJenisChanged: (value) {
                if (value != null) {
                  setState(() => _selectedJenis = value);
                }
              },
              onRefresh: _refreshDashboard,
              theme: _theme,
            ),
            Expanded(
              child: _isLoading
                  ? _LoadingState(theme: _theme)
                  : _dashboardData == null
                  ? _EmptyState(theme: _theme)
                  : _DashboardContent(
                data: _dashboardData!,
                isPusat: _isPusat,
                cabangList: _cabangList,
                selectedVisibility: _selectedCabangVisibility,
                selectedKodes: _selectedCabangKodes,
                groupBy: _groupBy,
                currencyFormat: _currencyFormat,
                numberFormat: _numberFormat,
                theme: _theme,
                onCabangVisibilityChanged: (index, selected) {
                  setState(() {
                    if (index < _selectedCabangVisibility.length) {
                      _selectedCabangVisibility[index] = selected;
                      if (_dashboardData?.multiSeriesSales != null &&
                          index < _dashboardData!.multiSeriesSales!.series.length) {
                        final kode = _cabangList.firstWhere(
                              (c) => c['nama'] == _dashboardData!.multiSeriesSales!.series[index]['cabang_nama'],
                          orElse: () => {'kode': ''},
                        )['kode'] as String;
                        if (selected) {
                          if (!_selectedCabangKodes.contains(kode)) {
                            _selectedCabangKodes.add(kode);
                          }
                        } else {
                          _selectedCabangKodes.remove(kode);
                        }
                      }
                    }
                  });
                  _loadSecondaryData();
                },
                onLoadSecondaryData: _loadSecondaryData,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AppTheme {
  final Color primary = const Color(0xFF0F3B5C);
  final Color primaryDark = const Color(0xFF0A2A42);
  final Color primaryLight = const Color(0xFFE8F0F7);
  final Color secondary = const Color(0xFFE67E22);
  final Color accent = const Color(0xFF3498DB);
  final Color success = const Color(0xFF27AE60);
  final Color error = const Color(0xFFE74C3C);
  final Color warning = const Color(0xFFF39C12);

  final Color background = const Color(0xFFF5F7FA);
  final Color surface = const Color(0xFFFFFFFF);
  final Color surfaceAlt = const Color(0xFFF8FAFD);

  final Color textPrimary = const Color(0xFF2C3E50);
  final Color textSecondary = const Color(0xFF5D6E7F);
  final Color textTertiary = const Color(0xFF8A99AA);

  final Color border = const Color(0xFFE4E9F0);
  final Color borderLight = const Color(0xFFF0F3F8);

  List<BoxShadow> get cardShadow => [
    BoxShadow(
      color: Colors.black.withOpacity(0.03),
      blurRadius: 12,
      offset: const Offset(0, 2),
    ),
    BoxShadow(
      color: Colors.black.withOpacity(0.02),
      blurRadius: 4,
      offset: const Offset(0, 1),
    ),
  ];

  TextStyle get headlineLarge => GoogleFonts.plusJakartaSans(
    fontSize: 28,
    fontWeight: FontWeight.w700,
    color: textPrimary,
    letterSpacing: -0.5,
  );
  TextStyle get headlineMedium => GoogleFonts.plusJakartaSans(
    fontSize: 24,
    fontWeight: FontWeight.w700,
    color: textPrimary,
    letterSpacing: -0.3,
  );
  TextStyle get titleLarge => GoogleFonts.plusJakartaSans(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: textPrimary,
    letterSpacing: -0.2,
  );
  TextStyle get titleMedium => GoogleFonts.plusJakartaSans(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: textPrimary,
  );
  TextStyle get titleSmall => GoogleFonts.plusJakartaSans(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: textPrimary,
  );
  TextStyle get bodyLarge => GoogleFonts.plusJakartaSans(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: textPrimary,
  );
  TextStyle get bodyMedium => GoogleFonts.plusJakartaSans(
    fontSize: 13,
    fontWeight: FontWeight.w500,
    color: textPrimary,
  );
  TextStyle get bodySmall => GoogleFonts.plusJakartaSans(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: textSecondary,
  );
  TextStyle get caption => GoogleFonts.plusJakartaSans(
    fontSize: 11,
    fontWeight: FontWeight.w400,
    color: textTertiary,
  );
  TextStyle get labelLarge => GoogleFonts.plusJakartaSans(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: secondary,
  );

  BorderRadius get cardRadius => BorderRadius.circular(20);
  BorderRadius get buttonRadius => BorderRadius.circular(10);
  BorderRadius get chipRadius => BorderRadius.circular(30);

  BoxDecoration get cardDecoration => BoxDecoration(
    color: surface,
    borderRadius: cardRadius,
    boxShadow: cardShadow,
  );
}

class _FilterBar extends StatelessWidget {
  final DateTime? startDate;
  final DateTime? endDate;
  final String groupBy;
  final String selectedJenis;
  final List<String> jenisList;
  final bool isPusat;
  final VoidCallback onStartDateTap;
  final VoidCallback onEndDateTap;
  final ValueChanged<String?> onGroupByChanged;
  final ValueChanged<String?> onJenisChanged;
  final VoidCallback onRefresh;
  final AppTheme theme;

  const _FilterBar({
    required this.startDate,
    required this.endDate,
    required this.groupBy,
    required this.selectedJenis,
    required this.jenisList,
    required this.isPusat,
    required this.onStartDateTap,
    required this.onEndDateTap,
    required this.onGroupByChanged,
    required this.onJenisChanged,
    required this.onRefresh,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 24, vertical: 12),
      color: theme.surface,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _DateField(
              label: 'Dari',
              date: startDate,
              onTap: onStartDateTap,
              theme: theme,
            ),
            const SizedBox(width: 8),
            _DateField(
              label: 'Sampai',
              date: endDate,
              onTap: onEndDateTap,
              theme: theme,
            ),
            const SizedBox(width: 8),
            _CompactDropdown(
              value: groupBy,
              items: const [
                DropdownMenuItem(value: 'day', child: Text('Harian')),
                DropdownMenuItem(value: 'month', child: Text('Bulanan')),
                DropdownMenuItem(value: 'year', child: Text('Tahunan')),
              ],
              onChanged: onGroupByChanged,
              theme: theme,
            ),
            if (isPusat) ...[
              const SizedBox(width: 8),
              _CompactDropdown(
                value: selectedJenis,
                items: jenisList.map((jenis) => DropdownMenuItem(
                  value: jenis,
                  child: Text(jenis == 'all' ? 'Semua Jenis' : jenis),
                )).toList(),
                onChanged: onJenisChanged,
                theme: theme,
              ),
            ],
            const SizedBox(width: 8),
            _RefreshButton(onPressed: onRefresh, theme: theme),
          ],
        ),
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  final String label;
  final DateTime? date;
  final VoidCallback onTap;
  final AppTheme theme;

  const _DateField({
    required this.label,
    required this.date,
    required this.onTap,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: theme.buttonRadius,
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: theme.surface,
          borderRadius: theme.buttonRadius,
          border: Border.all(color: theme.border, width: 1),
          boxShadow: theme.cardShadow,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.calendar_today, size: 14, color: theme.secondary),
            const SizedBox(width: 6),
            Text(
              '$label: ${date != null ? DateFormat('dd/MM/yy').format(date!) : 'Pilih'}',
              style: theme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _CompactDropdown extends StatelessWidget {
  final String value;
  final List<DropdownMenuItem<String>> items;
  final ValueChanged<String?> onChanged;
  final AppTheme theme;

  const _CompactDropdown({required this.value, required this.items, required this.onChanged, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: theme.buttonRadius,
        border: Border.all(color: theme.border, width: 1),
        boxShadow: theme.cardShadow,
      ),
      child: DropdownButton<String>(
        value: value,
        underline: const SizedBox(),
        icon: Icon(Icons.arrow_drop_down, size: 18, color: theme.secondary),
        style: theme.bodySmall,
        dropdownColor: theme.surface,
        items: items,
        onChanged: onChanged,
      ),
    );
  }
}

class _RefreshButton extends StatelessWidget {
  final VoidCallback onPressed;
  final AppTheme theme;

  const _RefreshButton({required this.onPressed, required this.theme});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      borderRadius: theme.buttonRadius,
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: theme.secondary,
          borderRadius: theme.buttonRadius,
          boxShadow: [
            BoxShadow(
              color: theme.secondary.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.refresh_rounded, size: 16, color: Colors.white),
            const SizedBox(width: 6),
            Text('Load', style: theme.bodySmall.copyWith(color: Colors.white, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

class _LoadingState extends StatelessWidget {
  final AppTheme theme;
  const _LoadingState({required this.theme});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: theme.primaryLight,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation(theme.primary),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text('Memuat data dashboard...', style: theme.caption),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final AppTheme theme;
  const _EmptyState({required this.theme});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              color: theme.surfaceAlt,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.dashboard_outlined, size: 48, color: theme.textTertiary),
          ),
          const SizedBox(height: 24),
          Text('Belum Ada Data', style: theme.titleMedium),
          const SizedBox(height: 8),
          Text('Pilih rentang tanggal untuk melihat data', style: theme.caption),
        ],
      ),
    );
  }
}

class _DashboardContent extends StatelessWidget {
  final DashboardResponse data;
  final bool isPusat;
  final List<Map<String, dynamic>> cabangList;
  final List<bool> selectedVisibility;
  final List<String> selectedKodes;
  final String groupBy;
  final NumberFormat currencyFormat;
  final NumberFormat numberFormat;
  final AppTheme theme;
  final Function(int, bool) onCabangVisibilityChanged;
  final VoidCallback onLoadSecondaryData;

  const _DashboardContent({
    required this.data,
    required this.isPusat,
    required this.cabangList,
    required this.selectedVisibility,
    required this.selectedKodes,
    required this.groupBy,
    required this.currencyFormat,
    required this.numberFormat,
    required this.theme,
    required this.onCabangVisibilityChanged,
    required this.onLoadSecondaryData,
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    final isMultiCabang = data.isAllCabang && data.multiSeriesSales != null && data.multiSeriesSales!.series.isNotEmpty;

    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (isMultiCabang)
            _MultiCabangChart(
              data: data.multiSeriesSales!,
              cabangList: cabangList,
              selectedVisibility: selectedVisibility,
              currencyFormat: currencyFormat,
              groupBy: groupBy,
              theme: theme,
              onVisibilityChanged: onCabangVisibilityChanged,
            )
          else
            _SalesChart(
              sales: data.sales,
              groupBy: groupBy,
              currencyFormat: currencyFormat,
              theme: theme,
            ),
          const SizedBox(height: 24),
          _SecondaryCharts(
            categories: data.categories,
            kasir: data.kasir,
            topItems: data.topItems,
            currencyFormat: currencyFormat,
            numberFormat: numberFormat,
            theme: theme,
          ),
        ],
      ),
    );
  }
}

class _SalesChart extends StatelessWidget {
  final List<DashboardSalesData> sales;
  final String groupBy;
  final NumberFormat currencyFormat;
  final AppTheme theme;

  const _SalesChart({
    required this.sales,
    required this.groupBy,
    required this.currencyFormat,
    required this.theme,
  });

  String get _title {
    switch(groupBy) {
      case 'day': return 'Tren Penjualan by Harian';
      case 'month': return 'Tren Penjualan Bulanan';
      default: return 'Tren Penjualan Tahunan';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (sales.isEmpty) return _EmptyCard(message: 'Data penjualan tidak tersedia', theme: theme);

    final processedSales = sales.map((item) {
      String labelStr;
      if (item.label is int) {
        labelStr = item.label.toString();
      } else {
        labelStr = item.label;
      }
      return DashboardSalesData(
        label: labelStr,
        totalSales: item.totalSales,
      );
    }).toList();

    final dataCount = processedSales.length;
    final isMobile = MediaQuery.of(context).size.width < 600;
    final bool isDayView = groupBy == 'day';
    final bool isYearView = groupBy == 'year';
    final bool needScroll = (isDayView && dataCount > 7) || (isYearView && dataCount > 8);

    double barWidth = 0;
    double chartWidth = 0;
    int labelRotation;
    double labelFontSize;
    double seriesWidth;

    if (isDayView) {
      if (dataCount <= 7) {
        barWidth = isMobile ? 90 : 110;
        labelRotation = 0;
        labelFontSize = isMobile ? 10 : 11;
        seriesWidth = 0.85;
      } else if (dataCount <= 15) {
        barWidth = isMobile ? 70 : 85;
        labelRotation = 45;
        labelFontSize = isMobile ? 9 : 10;
        seriesWidth = 0.8;
      } else {
        barWidth = isMobile ? 55 : 70;
        labelRotation = 45;
        labelFontSize = isMobile ? 8 : 9;
        seriesWidth = 0.75;
      }
      chartWidth = barWidth * dataCount;
    } else if (groupBy == 'month') {
      if (dataCount <= 6) {
        labelRotation = 0;
        labelFontSize = isMobile ? 12 : 13;
        seriesWidth = 0.85;
      } else if (dataCount <= 12) {
        labelRotation = 45;
        labelFontSize = isMobile ? 11 : 12;
        seriesWidth = 0.8;
      } else {
        labelRotation = 45;
        labelFontSize = isMobile ? 10 : 11;
        seriesWidth = 0.75;
      }
    } else {
      labelRotation = 0;
      labelFontSize = isMobile ? 14 : 16;
      seriesWidth = 0.85;
      if (dataCount > 8) {
        barWidth = isMobile ? 100 : 120;
        chartWidth = barWidth * dataCount;
      }
    }

    return Container(
      width: double.infinity,
      decoration: theme.cardDecoration,
      padding: EdgeInsets.all(isMobile ? 20 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 24,
                decoration: BoxDecoration(
                  color: theme.secondary,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 12),
              Text(_title, style: theme.titleLarge),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            decoration: BoxDecoration(
              color: theme.primaryLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'Total: ${currencyFormat.format(processedSales.fold<double>(0, (sum, item) => sum + item.totalSales))}',
              style: theme.labelLarge,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 400,
            width: double.infinity,
            child: needScroll
                ? SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: chartWidth > 0 ? chartWidth : null,
                child: _buildChart(processedSales, dataCount, labelFontSize, labelRotation, seriesWidth, true, isYearView),
              ),
            )
                : _buildChart(processedSales, dataCount, labelFontSize, labelRotation, seriesWidth, false, isYearView),
          ),
        ],
      ),
    );
  }

  Widget _buildChart(
      List<DashboardSalesData> salesData,
      int dataCount,
      double labelFontSize,
      int labelRotation,
      double seriesWidth,
      bool isScrollable,
      bool isYearView) {
    return SfCartesianChart(
      plotAreaBorderWidth: 0,
      margin: EdgeInsets.fromLTRB(10, 20, isScrollable ? 20 : 10, 20),
      primaryXAxis: CategoryAxis(
        labelRotation: isYearView ? 0 : labelRotation,
        labelStyle: theme.caption.copyWith(
          fontSize: labelFontSize,
          fontWeight: isYearView ? FontWeight.w600 : FontWeight.w400,
        ),
        majorGridLines: const MajorGridLines(width: 0),
        axisLine: const AxisLine(width: 0),
        labelPlacement: LabelPlacement.betweenTicks,
      ),
      primaryYAxis: NumericAxis(
        title: AxisTitle(text: 'Total Penjualan'),
        numberFormat: currencyFormat,
        labelStyle: theme.caption,
        axisLine: const AxisLine(width: 0),
        majorGridLines: MajorGridLines(width: 0.5, color: theme.border),
      ),
      series: [
        ColumnSeries<DashboardSalesData, String>(
          dataSource: salesData,
          xValueMapper: (d, _) => d.label,
          yValueMapper: (d, _) => d.totalSales,
          color: theme.primary,
          enableTooltip: true,
          width: seriesWidth,
          spacing: isYearView ? 0.2 : 0.1,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
        ),
      ],
      tooltipBehavior: TooltipBehavior(
        enable: true,
        canShowMarker: false,
        textStyle: theme.bodySmall,
        color: theme.surface,
        borderColor: theme.border,
        borderWidth: 1,
      ),
    );
  }
}

class _MultiCabangChart extends StatelessWidget {
  final MultiSeriesSalesData data;
  final List<Map<String, dynamic>> cabangList;
  final List<bool> selectedVisibility;
  final NumberFormat currencyFormat;
  final String groupBy;
  final AppTheme theme;
  final Function(int, bool) onVisibilityChanged;

  const _MultiCabangChart({
    required this.data,
    required this.cabangList,
    required this.selectedVisibility,
    required this.currencyFormat,
    required this.groupBy,
    required this.theme,
    required this.onVisibilityChanged,
  });

  List<Color> get _colors => [
    const Color(0xFF0F3B5C), const Color(0xFFE67E22), const Color(0xFF3498DB),
    const Color(0xFF27AE60), const Color(0xFF9B59B6), const Color(0xFFE74C3C),
    const Color(0xFF1ABC9C), const Color(0xFFF39C12), const Color(0xFF34495E),
  ];

  double _getTotalPenjualan() {
    final visibleSeries = data.series.asMap().entries
        .where((e) => e.key < selectedVisibility.length && selectedVisibility[e.key])
        .toList();

    double total = 0;
    for (var entry in visibleSeries) {
      final cabangData = entry.value;
      final dataList = List<double>.from(cabangData['data']);
      total += dataList.reduce((sum, val) => sum + val);
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    final dates = data.dates;
    final series = data.series;

    final dataCount = dates.length;
    final isMobile = MediaQuery.of(context).size.width < 600;
    final bool isYearView = groupBy == 'year';
    final double totalPenjualan = _getTotalPenjualan();

    bool needScroll = false;
    double barWidth = 0;
    double chartWidth = 0;
    int labelRotation;
    double labelFontSize;
    double seriesWidth;

    if (isYearView) {
      labelRotation = 0;
      labelFontSize = isMobile ? 14 : 16;
      seriesWidth = 0.85;
      needScroll = dataCount > 8;
      if (needScroll) {
        barWidth = isMobile ? 100 : 120;
        chartWidth = barWidth * dataCount;
      }
    } else {
      if (dataCount <= 6) {
        labelRotation = 0;
        labelFontSize = isMobile ? 12 : 13;
        seriesWidth = 0.85;
      } else if (dataCount <= 12) {
        labelRotation = 45;
        labelFontSize = isMobile ? 11 : 12;
        seriesWidth = 0.8;
      } else {
        labelRotation = 45;
        labelFontSize = isMobile ? 10 : 11;
        seriesWidth = 0.75;
      }
      needScroll = dataCount > 7;
      if (needScroll) {
        barWidth = isMobile ? 70 : 85;
        chartWidth = barWidth * dataCount;
      }
    }

    final visibleSeries = series.asMap().entries
        .where((e) => e.key < selectedVisibility.length && selectedVisibility[e.key])
        .toList();

    return Container(
      width: double.infinity,
      decoration: theme.cardDecoration,
      padding: EdgeInsets.all(isMobile ? 20 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 24,
                decoration: BoxDecoration(
                  color: theme.secondary,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 12),
              Text('Penjualan by Cabang', style: theme.titleLarge),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                decoration: BoxDecoration(
                  color: theme.primaryLight,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${selectedVisibility.where((e) => e).length} dari ${series.length} cabang ditampilkan',
                  style: theme.caption,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                decoration: BoxDecoration(
                  color: theme.secondary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: theme.secondary.withOpacity(0.3)),
                ),
                child: Text(
                  'Total: ${currencyFormat.format(totalPenjualan)}',
                  style: theme.labelLarge.copyWith(
                    fontSize: 12,
                    color: theme.secondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _CabangFilterChips(
            series: series,
            selectedVisibility: selectedVisibility,
            colors: _colors,
            theme: theme,
            onVisibilityChanged: onVisibilityChanged,
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 430,
            width: double.infinity,
            child: needScroll
                ? SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: chartWidth,
                child: _buildChart(dates, visibleSeries, dataCount, labelRotation, labelFontSize, seriesWidth, true, isYearView),
              ),
            )
                : _buildChart(dates, visibleSeries, dataCount, labelRotation, labelFontSize, seriesWidth, false, isYearView),
          ),
        ],
      ),
    );
  }

  Widget _buildChart(
      List<String> dates,
      List<MapEntry<int, Map<String, dynamic>>> visibleSeries,
      int dataCount,
      int labelRotation,
      double labelFontSize,
      double seriesWidth,
      bool isScrollable,
      bool isYearView,
      ) {
    return SfCartesianChart(
      plotAreaBorderWidth: 0,
      margin: EdgeInsets.fromLTRB(10, 20, isScrollable ? 20 : 10, 20),
      primaryXAxis: CategoryAxis(
        labelRotation: isYearView ? 0 : labelRotation,
        labelStyle: theme.caption.copyWith(fontSize: labelFontSize, fontWeight: isYearView ? FontWeight.w600 : FontWeight.w400),
        majorGridLines: const MajorGridLines(width: 0),
        axisLine: const AxisLine(width: 0),
        labelPlacement: LabelPlacement.betweenTicks,
      ),
      primaryYAxis: NumericAxis(
        title: AxisTitle(text: 'Total Penjualan'),
        numberFormat: currencyFormat,
        labelStyle: theme.caption,
        axisLine: const AxisLine(width: 0),
        majorGridLines: MajorGridLines(width: 0.5, color: theme.border),
      ),
      series: visibleSeries.map((entry) {
        final index = entry.key;
        final cabangData = entry.value;
        final points = List.generate(dates.length, (i) =>
            ChartData(x: dates[i], y: cabangData['data'][i] ?? 0.0));

        return ColumnSeries<ChartData, String>(
          dataSource: points,
          xValueMapper: (d, _) => d.x,
          yValueMapper: (d, _) => d.y,
          name: cabangData['cabang_nama'],
          color: _colors[index % _colors.length],
          enableTooltip: true,
          width: seriesWidth,
          spacing: isYearView ? 0.2 : 0.08,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
        );
      }).toList(),
      tooltipBehavior: TooltipBehavior(
        enable: true,
        canShowMarker: false,
        textStyle: theme.bodySmall,
        color: theme.surface,
        borderColor: theme.border,
        borderWidth: 1,
      ),
    );
  }
}

class _CabangFilterChips extends StatelessWidget {
  final List<Map<String, dynamic>> series;
  final List<bool> selectedVisibility;
  final List<Color> colors;
  final AppTheme theme;
  final Function(int, bool) onVisibilityChanged;

  const _CabangFilterChips({
    required this.series,
    required this.selectedVisibility,
    required this.colors,
    required this.theme,
    required this.onVisibilityChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: series.asMap().entries.map((entry) {
        final index = entry.key;
        final cabang = entry.value;
        final isSelected = index < selectedVisibility.length && selectedVisibility[index];
        return FilterChip(
          selected: isSelected,
          label: Text(
            cabang['cabang_nama'],
            style: theme.bodySmall.copyWith(fontWeight: FontWeight.w500),
          ),
          backgroundColor: Colors.transparent,
          selectedColor: colors[index % colors.length].withOpacity(0.1),
          checkmarkColor: colors[index % colors.length],
          side: BorderSide(
            color: isSelected ? colors[index % colors.length] : theme.border,
            width: 1,
          ),
          onSelected: (selected) => onVisibilityChanged(index, selected),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        );
      }).toList(),
    );
  }
}

class _SecondaryCharts extends StatelessWidget {
  final List<DashboardCategoryData> categories;
  final List<DashboardKasirData> kasir;
  final List<DashboardTopItem> topItems;
  final NumberFormat currencyFormat;
  final NumberFormat numberFormat;
  final AppTheme theme;

  const _SecondaryCharts({
    required this.categories,
    required this.kasir,
    required this.topItems,
    required this.currencyFormat,
    required this.numberFormat,
    required this.theme,
  });

  double _getTotalCategories() {
    return categories.fold<double>(0, (sum, item) => sum + item.totalAmount);
  }

  double _getTotalKasir() {
    return kasir.fold<double>(0, (sum, item) => sum + item.totalAmount);
  }

  double _getTotalTopItems() {
    return topItems.fold<double>(0, (sum, item) => sum + item.totalAmount);
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 900;

    if (isMobile) {
      return Column(
        children: [
          _PieChartCard(
            title: 'Penjualan by Kategori',
            data: categories.map((e) => (e.category, e.totalAmount)).toList(),
            total: _getTotalCategories(),
            theme: theme,
            currencyFormat: currencyFormat,
          ),
          const SizedBox(height: 20),
          _PieChartCard(
            title: 'Penjualan by Kasir',
            data: kasir.map((e) => (e.kasir, e.totalAmount)).toList(),
            total: _getTotalKasir(),
            theme: theme,
            currencyFormat: currencyFormat,
          ),
          const SizedBox(height: 20),
          _TopItemsTable(
            items: topItems,
            total: _getTotalTopItems(),
            currencyFormat: currencyFormat,
            numberFormat: numberFormat,
            theme: theme,
          ),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 1,
          child: Column(
            children: [
              _PieChartCard(
                title: 'Penjualan by Kategori',
                data: categories.map((e) => (e.category, e.totalAmount)).toList(),
                total: _getTotalCategories(),
                theme: theme,
                currencyFormat: currencyFormat,
              ),
              const SizedBox(height: 20),
              _PieChartCard(
                title: 'Penjualan by Kasir',
                data: kasir.map((e) => (e.kasir, e.totalAmount)).toList(),
                total: _getTotalKasir(),
                theme: theme,
                currencyFormat: currencyFormat,
              ),
            ],
          ),
        ),
        const SizedBox(width: 20),
        Expanded(
          flex: 1,
          child: _TopItemsTable(
            items: topItems,
            total: _getTotalTopItems(),
            currencyFormat: currencyFormat,
            numberFormat: numberFormat,
            theme: theme,
          ),
        ),
      ],
    );
  }
}

class _PieChartCard extends StatelessWidget {
  final String title;
  final List<(String, double)> data;
  final double total;
  final AppTheme theme;
  final NumberFormat currencyFormat;

  const _PieChartCard({
    required this.title,
    required this.data,
    required this.total,
    required this.theme,
    required this.currencyFormat,
  });

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty || data.every((e) => e.$2 == 0)) {
      return _EmptyCard(message: 'Data $title tidak tersedia', theme: theme);
    }

    final colors = [
      const Color(0xFF0F3B5C), const Color(0xFFE67E22), const Color(0xFF3498DB),
      const Color(0xFF27AE60), const Color(0xFF9B59B6), const Color(0xFFE74C3C),
    ];

    return Container(
      width: double.infinity,
      decoration: theme.cardDecoration,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 3,
                height: 18,
                decoration: BoxDecoration(
                  color: theme.secondary,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: 10),
              Text(title, style: theme.titleMedium),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: theme.secondary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: theme.secondary.withOpacity(0.3)),
                ),
                child: Text(
                  'Total: ${currencyFormat.format(total)}',
                  style: theme.caption.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.secondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 280,
            width: double.infinity,
            child: SfCircularChart(
              legend: Legend(
                isVisible: true,
                position: LegendPosition.right,
                overflowMode: LegendItemOverflowMode.wrap,
                textStyle: theme.caption,
              ),
              series: [
                PieSeries<(String, double), String>(
                  dataSource: data,
                  xValueMapper: (d, _) => d.$1,
                  yValueMapper: (d, _) => d.$2,
                  enableTooltip: true,
                  dataLabelSettings: const DataLabelSettings(isVisible: false),
                  explode: true,
                  explodeIndex: 0,
                  explodeOffset: '8%',
                  pointColorMapper: (d, _) => colors[data.indexOf(d) % colors.length],
                ),
              ],
              tooltipBehavior: TooltipBehavior(
                enable: true,
                builder: (dynamic data, dynamic point, dynamic series,
                    int pointIndex, int seriesIndex) {
                  try {
                    final category = data[pointIndex].$1;
                    final value = data[pointIndex].$2;
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: theme.surface,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                        border: Border.all(color: theme.border),
                      ),
                      child: Text(
                        '$category: ${currencyFormat.format(value)}',
                        style: theme.bodySmall.copyWith(
                          fontWeight: FontWeight.w500,
                          color: theme.textPrimary,
                        ),
                      ),
                    );
                  } catch (e) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: theme.surface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: theme.border),
                      ),
                      child: Text(
                        '${point.x}: ${currencyFormat.format(point.y)}',
                        style: theme.bodySmall,
                      ),
                    );
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TopItemsTable extends StatelessWidget {
  final List<DashboardTopItem> items;
  final double total;
  final NumberFormat currencyFormat;
  final NumberFormat numberFormat;
  final AppTheme theme;

  const _TopItemsTable({
    required this.items,
    required this.total,
    required this.currencyFormat,
    required this.numberFormat,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return _EmptyCard(message: 'Data item terlaris tidak tersedia', theme: theme);
    }

    final isMobile = MediaQuery.of(context).size.width < 600;

    return Container(
      width: double.infinity,
      decoration: theme.cardDecoration,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 3,
                height: 18,
                decoration: BoxDecoration(
                  color: theme.secondary,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: 10),
              Text('10 Item Terlaris', style: theme.titleMedium),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: theme.secondary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: theme.secondary.withOpacity(0.3)),
                ),
                child: Text(
                  'Total: ${currencyFormat.format(total)}',
                  style: theme.caption.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.secondary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.emoji_events, size: 20, color: theme.warning),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 580,
            width: double.infinity,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                border: TableBorder.all(
                  color: theme.border,
                  borderRadius: BorderRadius.circular(16),
                  width: 1,
                ),
                columnSpacing: isMobile ? 16 : 24,
                headingRowColor: WidgetStateProperty.all(theme.surfaceAlt),
                headingTextStyle: theme.titleSmall.copyWith(fontSize: 12),
                dataTextStyle: theme.bodySmall,
                columns: const [
                  DataColumn(label: Text('#', style: TextStyle(fontWeight: FontWeight.w600))),
                  DataColumn(label: Text('Nama Item', style: TextStyle(fontWeight: FontWeight.w600))),
                  DataColumn(label: Text('Qty', style: TextStyle(fontWeight: FontWeight.w600))),
                  DataColumn(label: Text('Total', style: TextStyle(fontWeight: FontWeight.w600))),
                ],
                rows: List.generate(items.length, (index) {
                  final item = items[index];
                  return DataRow(
                    cells: [
                      DataCell(Container(
                        width: 40,
                        child: Text(
                          '${index + 1}',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: index < 3 ? theme.warning : theme.textSecondary,
                          ),
                        ),
                      )),
                      DataCell(SizedBox(
                        width: isMobile ? 120 : 180,
                        child: Text(
                          item.itemName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      )),
                      DataCell(Text(numberFormat.format(item.totalQty))),
                      DataCell(Text(currencyFormat.format(item.totalAmount))),
                    ],
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  final String message;
  final AppTheme theme;

  const _EmptyCard({required this.message, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: theme.cardDecoration,
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox_outlined, size: 48, color: theme.textTertiary),
          const SizedBox(height: 16),
          Text(message, style: theme.caption),
        ],
      ),
    );
  }
}