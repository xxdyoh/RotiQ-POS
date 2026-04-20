import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../services/jurnal_service.dart';
import '../models/jurnal_model.dart';
import '../widgets/base_layout.dart';

class JurnalFormScreen extends StatefulWidget {
  final JurnalHeader? jurnalHeader;
  final VoidCallback onJurnalSaved;

  const JurnalFormScreen({
    super.key,
    this.jurnalHeader,
    required this.onJurnalSaved,
  });

  @override
  State<JurnalFormScreen> createState() => _JurnalFormScreenState();
}

class _JurnalFormScreenState extends State<JurnalFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _keteranganController = TextEditingController();
  final _nilaiController = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  String _selectedJenis = 'kas';
  Rekening? _selectedRekeningHeader;
  List<JurnalDetailInput> _details = [];

  List<Rekening> _rekeningHeaderList = [];
  List<Rekening> _rekeningDetailList = [];
  List<CostCenter> _costCenterList = [];

  bool _isLoading = false;
  bool _isSaving = false;
  bool _isLoadingData = false;

  String? _nomorJurnal;

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

  final Map<int, TextEditingController> _nilaiControllers = {};
  final Map<int, TextEditingController> _keteranganControllers = {};

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    setState(() {
      _isLoadingData = true;
    });

    try {
      await Future.wait([
        _loadRekeningHeader(),
        _loadRekeningDetail(),
        _loadCostCenter(),
      ]);

      if (widget.jurnalHeader != null) {
        await _loadJurnalDetail();
      }
    } catch (e) {
      _showToast('Gagal memuat data: ${e.toString()}', type: ToastType.error);
    } finally {
      setState(() {
        _isLoadingData = false;
      });
    }
  }

  Future<void> _loadRekeningHeader() async {
    final rekening = await JurnalService.getRekeningForHeader(_selectedJenis);
    setState(() {
      _rekeningHeaderList = rekening;
    });
  }

  Future<void> _loadRekeningDetail() async {
    final rekening = await JurnalService.getRekeningForDetail();
    setState(() {
      _rekeningDetailList = rekening;
    });
  }

  Future<void> _loadCostCenter() async {
    final costCenter = await JurnalService.getCostCenter();
    setState(() {
      _costCenterList = costCenter;
    });
  }

  Future<void> _loadJurnalDetail() async {
    if (widget.jurnalHeader == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final detail = await JurnalService.getJurnalDetail(widget.jurnalHeader!.jurNo);
      final headerData = detail['header'];
      final detailsData = List<Map<String, dynamic>>.from(detail['details']);

      setState(() {
        _nomorJurnal = headerData['jur_no'];
        _selectedDate = DateTime.parse(headerData['jur_tanggal']);
        _keteranganController.text = headerData['jur_keterangan'] ?? '';

        final headerItem = detailsData.firstWhere(
              (item) => item['jurd_nourut'] == 0,
          orElse: () => {},
        );

        if (headerItem.isNotEmpty) {
          final rekKode = headerItem['jurd_rek_kode'] ?? '';
          _selectedJenis = rekKode.startsWith('11') ? 'kas' : 'bank';
          _selectedRekeningHeader = Rekening(
            rekKode: rekKode,
            rekNama: headerItem['rek_nama'] ?? '',
          );
          _nilaiController.text = _formatNumberForInput(headerItem['jurd_kredit'] ?? 0);
        }

        _details = detailsData
            .where((item) => item['jurd_nourut'] > 0)
            .map((item) => JurnalDetailInput(
          account: item['jurd_rek_kode'] ?? '',
          accountName: item['rek_nama'] ?? '',
          nilai: double.tryParse(item['jurd_debet']?.toString() ?? '0') ?? 0,
          keterangan: item['jurd_keterangan'] ?? '',
          costcenter: item['jurd_cc_kode'] ?? '',
          costcenterName: item['cc_nama'] ?? '',
        ))
            .toList();

        _disposeAllControllers();
        for (int i = 0; i < _details.length; i++) {
          final detail = _details[i];
          _nilaiControllers[i] = TextEditingController(
            text: detail.nilai > 0 ? NumberFormat('#,###', 'id_ID').format(detail.nilai.toInt()) : '',
          );
          _keteranganControllers[i] = TextEditingController(text: detail.keterangan);
        }

        _loadRekeningHeader();
      });
    } catch (e) {
      _showToast('Gagal memuat detail: ${e.toString()}', type: ToastType.error);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _keteranganController.dispose();
    _nilaiController.dispose();
    _disposeAllControllers();
    super.dispose();
  }

  String _formatNumberForInput(dynamic value) {
    if (value == null) return '';
    final num = value is int ? value : (value is double ? value.toInt() : 0);
    final formatter = NumberFormat('#,###', 'id_ID');
    return formatter.format(num);
  }

  void _showToast(String message, {required ToastType type}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Container(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Icon(
                type == ToastType.success ? Icons.check_circle_rounded : Icons.error_rounded,
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
        backgroundColor: type == ToastType.success ? _accentMint : _accentCoral,
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
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  void _onJenisChanged(String? value) {
    if (value != null) {
      setState(() {
        _selectedJenis = value;
        _selectedRekeningHeader = null;
      });
      _loadRekeningHeader();
    }
  }

  void _addDetail() {
    setState(() {
      final newIndex = _details.length;
      _details.add(JurnalDetailInput(
        account: '',
        accountName: '',
        nilai: 0,
        keterangan: '',
        costcenter: '',
        costcenterName: '',
      ));
      // Buat controller baru
      _nilaiControllers[newIndex] = TextEditingController();
      _keteranganControllers[newIndex] = TextEditingController();
    });
  }

  void _removeDetail(int index) {
    setState(() {
      _details.removeAt(index);
      // Hapus dan dispose controller
      _nilaiControllers[index]?.dispose();
      _keteranganControllers[index]?.dispose();

      // Re-index controllers
      final newNilaiControllers = <int, TextEditingController>{};
      final newKeteranganControllers = <int, TextEditingController>{};

      for (int i = 0; i < _details.length; i++) {
        // Cari controller dengan index lama yang sesuai
        for (var entry in _nilaiControllers.entries) {
          if (entry.key > index) {
            newNilaiControllers[entry.key - 1] = entry.value;
          } else if (entry.key < index) {
            newNilaiControllers[entry.key] = entry.value;
          }
        }
        for (var entry in _keteranganControllers.entries) {
          if (entry.key > index) {
            newKeteranganControllers[entry.key - 1] = entry.value;
          } else if (entry.key < index) {
            newKeteranganControllers[entry.key] = entry.value;
          }
        }
      }

      _nilaiControllers.clear();
      _keteranganControllers.clear();
      _nilaiControllers.addAll(newNilaiControllers);
      _keteranganControllers.addAll(newKeteranganControllers);
    });
  }

  void _disposeAllControllers() {
    for (var controller in _nilaiControllers.values) {
      controller.dispose();
    }
    for (var controller in _keteranganControllers.values) {
      controller.dispose();
    }
    _nilaiControllers.clear();
    _keteranganControllers.clear();
  }

  void _updateDetail(int index, JurnalDetailInput newDetail) {
    setState(() {
      _details[index] = newDetail;
    });
  }

  double get _totalDetail {
    return _details.fold(0, (sum, item) => sum + item.nilai);
  }

  void _onNilaiChanged(String value) {
    if (value.isNotEmpty) {
      final cleanValue = value.replaceAll('.', '');
      final number = int.tryParse(cleanValue) ?? 0;
      if (number > 0) {
        final formatter = NumberFormat('#,###', 'id_ID');
        final formatted = formatter.format(number);

        _nilaiController.value = _nilaiController.value.copyWith(
          text: formatted,
          selection: TextSelection.collapsed(offset: formatted.length),
        );
      }
    }
  }

  Future<void> _saveJurnal() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedRekeningHeader == null) {
      _showToast('Pilih account header!', type: ToastType.error);
      return;
    }

    if (_details.isEmpty) {
      _showToast('Minimal satu detail harus diisi!', type: ToastType.error);
      return;
    }

    for (var detail in _details) {
      if (detail.account.isEmpty || detail.nilai <= 0) {
        _showToast('Semua detail harus memiliki account dan nilai > 0!', type: ToastType.error);
        return;
      }
    }

    final cleanValue = _nilaiController.text.replaceAll('.', '');
    final nilaiHeader = double.tryParse(cleanValue) ?? 0;
    if ((_totalDetail - nilaiHeader).abs() > 0.01) {
      _showToast('Total detail harus sama dengan nilai header!', type: ToastType.error);
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final tanggalStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
      final detailsJson = _details.map((detail) => detail.toJson()).toList();

      final result = widget.jurnalHeader == null
          ? await JurnalService.createJurnal(
        tanggal: tanggalStr,
        jenis: _selectedJenis,
        accountHeader: _selectedRekeningHeader!.rekKode,
        keteranganHeader: _keteranganController.text.trim(),
        nilaiHeader: nilaiHeader,
        details: detailsJson,
      )
          : await JurnalService.updateJurnal(
        nomor: _nomorJurnal!,
        tanggal: tanggalStr,
        jenis: _selectedJenis,
        accountHeader: _selectedRekeningHeader!.rekKode,
        keteranganHeader: _keteranganController.text.trim(),
        nilaiHeader: nilaiHeader,
        details: detailsJson,
      );

      if (result['success']) {
        _showToast(result['message'], type: ToastType.success);
        widget.onJurnalSaved();
        Navigator.pop(context);
      } else {
        _showToast(result['message'], type: ToastType.error);
      }
    } catch (e) {
      _showToast('Error: ${e.toString()}', type: ToastType.error);
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  String _formatCurrency(double amount) {
    return NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(amount);
  }

  Future<void> _showRekeningHeaderDialog() async {
    final selected = await showDialog<Rekening>(
      context: context,
      builder: (context) => _buildSelectionDialog(
        title: 'Pilih Account Header',
        items: _rekeningHeaderList,
        selected: _selectedRekeningHeader,
        itemBuilder: (item, isSelected) => ListTile(
          leading: Icon(Icons.account_balance_wallet, size: 16, color: isSelected ? _accentGold : _textLight),
          title: Text(item.rekNama, style: GoogleFonts.montserrat(fontSize: 11, fontWeight: FontWeight.w600)),
          subtitle: Text(item.rekKode, style: GoogleFonts.montserrat(fontSize: 10, color: _textMedium)),
          trailing: isSelected ? Icon(Icons.check, size: 14, color: _accentGold) : null,
          onTap: () => Navigator.pop(context, item),
        ),
      ),
    );

    if (selected != null) {
      setState(() {
        _selectedRekeningHeader = selected;
      });
    }
  }

  Future<void> _showRekeningDetailDialog(int index) async {
    final selected = await showDialog<Rekening>(
      context: context,
      builder: (context) => _buildSelectionDialog(
        title: 'Pilih Account Detail',
        items: _rekeningDetailList,
        selected: _details[index].account.isNotEmpty
            ? Rekening(rekKode: _details[index].account, rekNama: _details[index].accountName)
            : null,
        itemBuilder: (item, isSelected) => ListTile(
          leading: Icon(Icons.account_balance_wallet, size: 16, color: isSelected ? _accentGold : _textLight),
          title: Text(item.rekNama, style: GoogleFonts.montserrat(fontSize: 11, fontWeight: FontWeight.w600)),
          subtitle: Text(item.rekKode, style: GoogleFonts.montserrat(fontSize: 10, color: _textMedium)),
          trailing: isSelected ? Icon(Icons.check, size: 14, color: _accentGold) : null,
          onTap: () => Navigator.pop(context, item),
        ),
      ),
    );

    if (selected != null) {
      setState(() {
        _details[index] = JurnalDetailInput(
          account: selected.rekKode,
          accountName: selected.rekNama,
          nilai: _details[index].nilai,
          keterangan: _details[index].keterangan,
          costcenter: _details[index].costcenter,
          costcenterName: _details[index].costcenterName,
        );
      });
    }
  }

  Future<void> _showCostCenterDialog(int index) async {
    final selected = await showDialog<CostCenter>(
      context: context,
      builder: (context) => _buildSelectionDialog(
        title: 'Pilih Cost Center',
        items: _costCenterList,
        selected: _details[index].costcenter.isNotEmpty
            ? CostCenter(ccKode: _details[index].costcenter, ccNama: _details[index].costcenterName)
            : null,
        itemBuilder: (item, isSelected) => ListTile(
          leading: Icon(Icons.business, size: 16, color: isSelected ? _accentGold : _textLight),
          title: Text(item.ccNama, style: GoogleFonts.montserrat(fontSize: 11, fontWeight: FontWeight.w600)),
          subtitle: Text(item.ccKode, style: GoogleFonts.montserrat(fontSize: 10, color: _textMedium)),
          trailing: isSelected ? Icon(Icons.check, size: 14, color: _accentGold) : null,
          onTap: () => Navigator.pop(context, item),
        ),
      ),
    );

    if (selected != null) {
      setState(() {
        _details[index] = JurnalDetailInput(
          account: _details[index].account,
          accountName: _details[index].accountName,
          nilai: _details[index].nilai,
          keterangan: _details[index].keterangan,
          costcenter: selected.ccKode,
          costcenterName: selected.ccNama,
        );
      });
    }
  }

  Widget _buildSelectionDialog<T>({
    required String title,
    required List<T> items,
    required T? selected,
    required Widget Function(T item, bool isSelected) itemBuilder,
  }) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        height: 400,
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Text(
              title,
              style: GoogleFonts.montserrat(fontSize: 13, fontWeight: FontWeight.w600, color: _textDark),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: items.isEmpty
                  ? Center(
                child: Text(
                  'Tidak ada data',
                  style: GoogleFonts.montserrat(fontSize: 11, color: _textLight),
                ),
              )
                  : ListView.builder(
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final item = items[index];
                  bool isSelected = false;
                  if (item is Rekening && selected is Rekening) {
                    isSelected = selected.rekKode == item.rekKode;
                  } else if (item is CostCenter && selected is CostCenter) {
                    isSelected = selected.ccKode == item.ccKode;
                  }
                  return itemBuilder(item, isSelected);
                },
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 36,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: _borderSoft),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
                child: Text('Batal', style: GoogleFonts.montserrat(fontSize: 11, color: _textMedium)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.jurnalHeader != null;
    final isMobile = MediaQuery.of(context).size.width < 600;
    final cleanValue = _nilaiController.text.replaceAll('.', '');
    final nilaiHeader = double.tryParse(cleanValue) ?? 0;
    final isBalance = (_totalDetail - nilaiHeader).abs() <= 0.01;

    if (_isLoadingData) {
      return BaseLayout(
        title: isEdit ? 'Edit Biaya' : 'Tambah Biaya',
        showBackButton: true,
        showSidebar: !isMobile,
        isFormScreen: true,
        child: Center(
          child: CircularProgressIndicator(color: _accentGold),
        ),
      );
    }

    return BaseLayout(
      title: isEdit ? 'Edit Biaya' : 'Tambah Biaya',
      showBackButton: true,
      showSidebar: !isMobile,
      isFormScreen: true,
      child: Container(
        color: _bgSoft,
        child: Form(
          key: _formKey,
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
                            if (_nomorJurnal != null) ...[
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
                                      _nomorJurnal!,
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

                            // Row 1: Tanggal & Jenis
                            Row(
                              children: [
                                Expanded(
                                  flex: 2,
                                  child: _buildFieldLabel('Tanggal'),
                                ),
                                Expanded(
                                  flex: 3,
                                  child: _buildFieldLabel('Jenis Pembayaran'),
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
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: _buildPaymentTypeRadio(
                                          value: 'kas',
                                          label: 'Kas',
                                          isSelected: _selectedJenis == 'kas',
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: _buildPaymentTypeRadio(
                                          value: 'bank',
                                          label: 'Bank',
                                          isSelected: _selectedJenis == 'bank',
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 16),

                            // Row 2: Account Header & Nilai
                            Row(
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: _buildFieldLabel('Account Header *'),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: _buildFieldLabel('Nilai Total *'),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: _buildAccountHeaderField(),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  flex: 2,
                                  child: _buildNilaiField(),
                                ),
                              ],
                            ),

                            const SizedBox(height: 16),

                            // Keterangan
                            _buildFieldLabel('Keterangan *'),
                            const SizedBox(height: 6),
                            _buildKeteranganField(),
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
                                  child: Icon(Icons.list_alt, size: 14, color: _accentMint),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Detail Biaya',
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
                                // Total & Balance indicator
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: isBalance ? _accentMint.withOpacity(0.1) : _accentCoral.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: isBalance ? _accentMint.withOpacity(0.3) : _accentCoral.withOpacity(0.3),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        'Total: ',
                                        style: GoogleFonts.montserrat(
                                          fontSize: 10,
                                          color: _textMedium,
                                        ),
                                      ),
                                      Text(
                                        _formatCurrency(_totalDetail),
                                        style: GoogleFonts.montserrat(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: isBalance ? _accentMint : _accentCoral,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  height: 32,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [_primaryDark, _primaryLight],
                                    ),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      onTap: _addDetail,
                                      borderRadius: BorderRadius.circular(6),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 12),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.add, size: 12, color: Colors.white),
                                            const SizedBox(width: 4),
                                            Text(
                                              'Tambah',
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

                      // Detail Grid Header
                      if (_details.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: _primaryDark,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 40,
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
                                flex: 2,
                                child: Text(
                                  'Account',
                                  style: GoogleFonts.montserrat(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  'Keterangan',
                                  style: GoogleFonts.montserrat(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 1,
                                child: Text(
                                  'Nilai',
                                  style: GoogleFonts.montserrat(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  'Cost Center',
                                  style: GoogleFonts.montserrat(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              SizedBox(
                                width: 40,
                                child: Center(
                                  child: Text(
                                    'Aksi',
                                    style: GoogleFonts.montserrat(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                      // Detail Rows
                      if (_details.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: _surfaceWhite,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: _borderSoft),
                          ),
                          child: Column(
                            children: [
                              Icon(Icons.list_alt_outlined, size: 36, color: _textLight),
                              const SizedBox(height: 8),
                              Text(
                                'Belum ada detail biaya',
                                style: GoogleFonts.montserrat(fontSize: 11, color: _textLight),
                              ),
                            ],
                          ),
                        )
                      else
                        ..._details.asMap().entries.map((entry) {
                          final index = entry.key;
                          final detail = entry.value;
                          return _buildDetailRow(index, detail);
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
                child: SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: Container(
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
                        onTap: _isSaving ? null : _saveJurnal,
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
                                isEdit ? 'UPDATE BIAYA' : 'SIMPAN BIAYA',
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

  Widget _buildPaymentTypeRadio({
    required String value,
    required String label,
    required bool isSelected,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _onJenisChanged(value),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: isSelected ? _accentGold.withOpacity(0.1) : _bgSoft,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? _accentGold : _borderSoft,
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? _accentGold : _textLight,
                    width: isSelected ? 5 : 1.5,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.montserrat(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected ? _accentGold : _textMedium,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAccountHeaderField() {
    return InkWell(
      onTap: _showRekeningHeaderDialog,
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
            Icon(Icons.account_balance_wallet, size: 14, color: _textLight),
            const SizedBox(width: 8),
            Expanded(
              child: _selectedRekeningHeader == null
                  ? Text(
                'Pilih Account Header',
                style: GoogleFonts.montserrat(fontSize: 11, color: _textLight),
              )
                  : Text(
                _selectedRekeningHeader!.rekNama,
                style: GoogleFonts.montserrat(fontSize: 11, fontWeight: FontWeight.w500, color: _textDark),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(Icons.arrow_drop_down, size: 16, color: _textLight),
          ],
        ),
      ),
    );
  }

  Widget _buildNilaiField() {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: _bgSoft,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _borderSoft),
      ),
      child: Row(
        children: [
          Text(
            'Rp',
            style: GoogleFonts.montserrat(fontSize: 11, fontWeight: FontWeight.w600, color: _textMedium),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextFormField(
              controller: _nilaiController,
              keyboardType: TextInputType.number,
              style: GoogleFonts.montserrat(fontSize: 11, fontWeight: FontWeight.w600, color: _textDark),
              decoration: InputDecoration(
                hintText: '0',
                hintStyle: GoogleFonts.montserrat(fontSize: 11, color: _textLight),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
              onChanged: _onNilaiChanged,
              validator: (value) {
                if (value == null || value.trim().isEmpty) return 'Nilai harus diisi';
                final cleanValue = value.replaceAll('.', '');
                final nilai = double.tryParse(cleanValue);
                if (nilai == null || nilai <= 0) return 'Nilai harus > 0';
                return null;
              },
            ),
          ),
        ],
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
          hintText: 'Keterangan biaya...',
          hintStyle: GoogleFonts.montserrat(fontSize: 11, color: _textLight),
          border: InputBorder.none,
          isDense: true,
          contentPadding: EdgeInsets.zero,
        ),
        validator: (value) {
          if (value == null || value.trim().isEmpty) return 'Keterangan harus diisi';
          return null;
        },
      ),
    );
  }

  Widget _buildDetailRow(int index, JurnalDetailInput detail) {
    final isEven = index % 2 == 0;

    // Dapatkan atau buat controller
    if (!_nilaiControllers.containsKey(index)) {
      _nilaiControllers[index] = TextEditingController(
        text: detail.nilai > 0 ? NumberFormat('#,###', 'id_ID').format(detail.nilai.toInt()) : '',
      );
    }
    if (!_keteranganControllers.containsKey(index)) {
      _keteranganControllers[index] = TextEditingController(text: detail.keterangan);
    }

    final nilaiController = _nilaiControllers[index]!;
    final keteranganController = _keteranganControllers[index]!;

    return Container(
      margin: const EdgeInsets.only(bottom: 1),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
            width: 40,
            child: Text(
              '${index + 1}',
              style: GoogleFonts.montserrat(fontSize: 10, fontWeight: FontWeight.w500, color: _textMedium),
            ),
          ),

          // Account - tampilkan nama saja
          Expanded(
            flex: 2,
            child: InkWell(
              onTap: () => _showRekeningDetailDialog(index),
              borderRadius: BorderRadius.circular(6),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Row(
                  children: [
                    Icon(Icons.account_balance_wallet, size: 12, color: _textLight),
                    const SizedBox(width: 6),
                    Expanded(
                      child: detail.account.isEmpty
                          ? Text(
                        'Pilih Account',
                        style: GoogleFonts.montserrat(fontSize: 10, color: _textLight),
                      )
                          : Text(
                        detail.accountName,
                        style: GoogleFonts.montserrat(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: _textDark,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Icon(Icons.arrow_drop_down, size: 14, color: _textLight),
                  ],
                ),
              ),
            ),
          ),

          // Keterangan - TANPA SETSTATE
          Expanded(
            flex: 2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: TextField(
                controller: keteranganController,
                style: GoogleFonts.montserrat(fontSize: 10, color: _textDark),
                decoration: InputDecoration(
                  hintText: 'Keterangan',
                  hintStyle: GoogleFonts.montserrat(fontSize: 10, color: _textLight),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
                onChanged: (value) {
                  // Update detail langsung di list TANPA setState
                  _details[index] = JurnalDetailInput(
                    account: detail.account,
                    accountName: detail.accountName,
                    nilai: detail.nilai,
                    keterangan: value,
                    costcenter: detail.costcenter,
                    costcenterName: detail.costcenterName,
                  );
                  // TIDAK PANGGIL setState() di sini!
                },
              ),
            ),
          ),

          // Nilai - dengan format currency
          Expanded(
            flex: 1,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  Text(
                    'Rp',
                    style: GoogleFonts.montserrat(fontSize: 9, fontWeight: FontWeight.w500, color: _textMedium),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: TextField(
                      controller: nilaiController,
                      keyboardType: TextInputType.numberWithOptions(signed: false, decimal: false),
                      style: GoogleFonts.montserrat(fontSize: 10, fontWeight: FontWeight.w600, color: _accentGold),
                      decoration: InputDecoration(
                        hintText: '0',
                        hintStyle: GoogleFonts.montserrat(fontSize: 10, color: _textLight),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                      onChanged: (value) {
                        // Hapus titik dan parse angka
                        final cleanValue = value.replaceAll('.', '');
                        final newNilai = double.tryParse(cleanValue) ?? 0;

                        // Format dengan titik (1000 -> 1.000)
                        if (newNilai > 0) {
                          final formatter = NumberFormat('#,###', 'id_ID');
                          final formatted = formatter.format(newNilai.toInt());

                          // Update controller tanpa kehilangan cursor position
                          final currentSelection = nilaiController.selection;
                          nilaiController.value = nilaiController.value.copyWith(
                            text: formatted,
                            selection: TextSelection.collapsed(
                              offset: formatted.length,
                            ),
                          );
                        } else if (value.isEmpty) {
                          // Biarkan kosong
                        }

                        // Update detail TANPA setState
                        _details[index] = JurnalDetailInput(
                          account: detail.account,
                          accountName: detail.accountName,
                          nilai: newNilai,
                          keterangan: detail.keterangan,
                          costcenter: detail.costcenter,
                          costcenterName: detail.costcenterName,
                        );
                        // TIDAK PANGGIL setState() di sini!
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Cost Center - tampilkan nama saja
          Expanded(
            flex: 2,
            child: InkWell(
              onTap: () => _showCostCenterDialog(index),
              borderRadius: BorderRadius.circular(6),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Row(
                  children: [
                    Icon(Icons.business, size: 12, color: _textLight),
                    const SizedBox(width: 6),
                    Expanded(
                      child: detail.costcenter.isEmpty
                          ? Text(
                        'Pilih CC',
                        style: GoogleFonts.montserrat(fontSize: 10, color: _textLight),
                      )
                          : Text(
                        detail.costcenterName,
                        style: GoogleFonts.montserrat(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: _textDark,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Icon(Icons.arrow_drop_down, size: 14, color: _textLight),
                  ],
                ),
              ),
            ),
          ),

          // Aksi (Delete)
          SizedBox(
            width: 40,
            child: Center(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        title: Text('Hapus Detail?', style: GoogleFonts.montserrat(fontSize: 13, fontWeight: FontWeight.w600)),
                        content: Text('Apakah Anda yakin ingin menghapus detail ini?',
                            style: GoogleFonts.montserrat(fontSize: 11, color: _textMedium)),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: Text('Batal', style: GoogleFonts.montserrat(fontSize: 11, color: _textMedium)),
                          ),
                          ElevatedButton(
                            onPressed: () {
                              Navigator.pop(context);
                              _removeDetail(index);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _accentCoral,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                            ),
                            child: Text('Hapus', style: GoogleFonts.montserrat(fontSize: 11, color: Colors.white)),
                          ),
                        ],
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(4),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    child: Icon(Icons.delete_outline, size: 14, color: _accentCoral),
                  ),
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