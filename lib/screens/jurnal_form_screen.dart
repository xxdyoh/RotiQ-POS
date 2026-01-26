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
      _showErrorSnackbar('Gagal memuat data: ${e.toString()}');
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

        _loadRekeningHeader();
      });
    } catch (e) {
      _showErrorSnackbar('Gagal memuat detail: ${e.toString()}');
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
    super.dispose();
  }

  String _formatNumberForInput(dynamic value) {
    if (value == null) return '';
    final num = value is int ? value : (value is double ? value.toInt() : 0);
    final formatter = NumberFormat('#,###', 'id_ID');
    return formatter.format(num);
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

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: ColorScheme.light(
              primary: const Color(0xFFF6A918),
              onPrimary: Colors.white,
            ),
            dialogBackgroundColor: Colors.white,
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
      _details.add(JurnalDetailInput(
        account: '',
        accountName: '',
        nilai: 0,
        keterangan: '',
        costcenter: '',
        costcenterName: '',
      ));
    });
  }

  void _removeDetail(int index) {
    setState(() {
      _details.removeAt(index);
    });
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
      _showErrorSnackbar('Pilih account header!');
      return;
    }

    if (_details.isEmpty) {
      _showErrorSnackbar('Minimal satu detail harus diisi!');
      return;
    }

    for (var detail in _details) {
      if (detail.account.isEmpty || detail.nilai <= 0) {
        _showErrorSnackbar('Semua detail harus memiliki account dan nilai > 0!');
        return;
      }
    }

    final cleanValue = _nilaiController.text.replaceAll('.', '');
    final nilaiHeader = double.tryParse(cleanValue) ?? 0;
    if ((_totalDetail - nilaiHeader).abs() > 0.01) {
      _showErrorSnackbar('Total detail harus sama dengan nilai header!');
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
        _showSuccessSnackbar(result['message']);
        widget.onJurnalSaved();
        Navigator.pop(context);
      } else {
        _showErrorSnackbar(result['message']);
      }
    } catch (e) {
      _showErrorSnackbar('Error: ${e.toString()}');
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  String _formatCurrency(double amount) {
    return NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    ).format(amount);
  }

  Future<void> _showRekeningHeaderDialog() async {
    final selected = await showDialog<Rekening>(
      context: context,
      builder: (context) => _buildRekeningDialog(
        title: 'Pilih Account Header',
        rekeningList: _rekeningHeaderList,
        selected: _selectedRekeningHeader,
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
      builder: (context) => _buildRekeningDialog(
        title: 'Pilih Account Detail',
        rekeningList: _rekeningDetailList,
        selected: _details[index].account.isNotEmpty
            ? Rekening(rekKode: _details[index].account, rekNama: _details[index].accountName)
            : null,
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
      builder: (context) => _buildCostCenterDialog(
        costCenterList: _costCenterList,
        selected: _details[index].costcenter.isNotEmpty
            ? CostCenter(ccKode: _details[index].costcenter, ccNama: _details[index].costcenterName)
            : null,
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

  Widget _buildRekeningDialog({
    required String title,
    required List<Rekening> rekeningList,
    required Rekening? selected,
  }) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        height: 400,
        padding: EdgeInsets.all(12),
        child: Column(
          children: [
            Text(
              title,
              style: GoogleFonts.montserrat(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
            ),
            SizedBox(height: 12),
            Expanded(
              child: rekeningList.isEmpty
                  ? Center(
                child: Text(
                  'Tidak ada data',
                  style: GoogleFonts.montserrat(
                    color: Colors.grey.shade500,
                    fontSize: 12,
                  ),
                ),
              )
                  : ListView.builder(
                itemCount: rekeningList.length,
                itemBuilder: (context, index) {
                  final item = rekeningList[index];
                  final isSelected = selected?.rekKode == item.rekKode;

                  return Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => Navigator.pop(context, item),
                      child: Container(
                        padding: EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color: Colors.grey.shade200,
                              width: 1,
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.account_balance_wallet,
                              size: 14,
                              color: isSelected ? Color(0xFFF6A918) : Colors.grey.shade600,
                            ),
                            SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.rekKode,
                                    style: GoogleFonts.montserrat(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: isSelected ? Color(0xFFF6A918) : Colors.black87,
                                    ),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    item.rekNama,
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
                            if (isSelected)
                              Icon(
                                Icons.check,
                                size: 14,
                                color: Color(0xFFF6A918),
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 36,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Colors.grey.shade300),
                ),
                child: Text(
                  'Batal',
                  style: GoogleFonts.montserrat(
                    fontSize: 12,
                    color: Colors.grey.shade700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCostCenterDialog({
    required List<CostCenter> costCenterList,
    required CostCenter? selected,
  }) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        height: 300,
        padding: EdgeInsets.all(12),
        child: Column(
          children: [
            Text(
              'Pilih Cost Center',
              style: GoogleFonts.montserrat(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
            ),
            SizedBox(height: 12),
            Expanded(
              child: costCenterList.isEmpty
                  ? Center(
                child: Text(
                  'Tidak ada data',
                  style: GoogleFonts.montserrat(
                    color: Colors.grey.shade500,
                    fontSize: 12,
                  ),
                ),
              )
                  : ListView.builder(
                itemCount: costCenterList.length,
                itemBuilder: (context, index) {
                  final item = costCenterList[index];
                  final isSelected = selected?.ccKode == item.ccKode;

                  return Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => Navigator.pop(context, item),
                      child: Container(
                        padding: EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color: Colors.grey.shade200,
                              width: 1,
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.business,
                              size: 14,
                              color: isSelected ? Color(0xFFF6A918) : Colors.grey.shade600,
                            ),
                            SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.ccKode,
                                    style: GoogleFonts.montserrat(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: isSelected ? Color(0xFFF6A918) : Colors.black87,
                                    ),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    item.ccNama,
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
                            if (isSelected)
                              Icon(
                                Icons.check,
                                size: 14,
                                color: Color(0xFFF6A918),
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 36,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Colors.grey.shade300),
                ),
                child: Text(
                  'Batal',
                  style: GoogleFonts.montserrat(
                    fontSize: 12,
                    color: Colors.grey.shade700,
                  ),
                ),
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

    if (_isLoadingData) {
      return BaseLayout(
        title: isEdit ? 'Edit Biaya' : 'Tambah Biaya',
        showBackButton: true,
        showSidebar: true,
        isFormScreen: true,
        child: Center(
          child: CircularProgressIndicator(color: Color(0xFFF6A918)),
        ),
      );
    }

    return BaseLayout(
      title: isEdit ? 'Edit Biaya' : 'Tambah Biaya',
      showBackButton: true,
      showSidebar: true,
      isFormScreen: true,
      child: Form(
        key: _formKey,
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      // Header Card
                      Container(
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
                        padding: EdgeInsets.all(12),
                        child: Column(
                          children: [
                            if (_nomorJurnal != null) ...[
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade50,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: Colors.grey.shade200, width: 1),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.confirmation_number, size: 14, color: Colors.grey.shade600),
                                    SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        _nomorJurnal!,
                                        style: GoogleFonts.montserrat(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.grey.shade700,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(height: 10),
                            ],

                            // Tanggal
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Tanggal',
                                  style: GoogleFonts.montserrat(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(6),
                                    onTap: () => _selectDate(context),
                                    child: Container(
                                      height: 36,
                                      padding: EdgeInsets.symmetric(horizontal: 10),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade50,
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: Colors.grey.shade300, width: 1),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(Icons.calendar_today, size: 14, color: Color(0xFFF6A918)),
                                          SizedBox(width: 6),
                                          Expanded(
                                            child: Text(
                                              DateFormat('dd/MM/yy').format(_selectedDate),
                                              style: GoogleFonts.montserrat(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w500,
                                                color: Colors.black87,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            SizedBox(height: 12),

                            // Jenis Pembayaran
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Jenis Pembayaran',
                                  style: GoogleFonts.montserrat(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                                SizedBox(height: 6),
                                Row(
                                  children: [
                                    // Kas Radio
                                    Expanded(
                                      child: _buildPaymentTypeRadio(
                                        value: 'kas',
                                        label: 'Kas',
                                        isSelected: _selectedJenis == 'kas',
                                      ),
                                    ),
                                    SizedBox(width: 8),
                                    // Bank Radio
                                    Expanded(
                                      child: _buildPaymentTypeRadio(
                                        value: 'bank',
                                        label: 'Bank',
                                        isSelected: _selectedJenis == 'bank',
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),

                            SizedBox(height: 12),

                            // Account Header
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Account Header *',
                                  style: GoogleFonts.montserrat(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                                SizedBox(height: 4),
                                InkWell(
                                  borderRadius: BorderRadius.circular(6),
                                  onTap: _showRekeningHeaderDialog,
                                  child: Container(
                                    height: 36,
                                    padding: EdgeInsets.symmetric(horizontal: 10),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade50,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: Colors.grey.shade300, width: 1),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(Icons.account_balance_wallet, size: 14, color: Colors.grey.shade600),
                                        SizedBox(width: 6),
                                        Expanded(
                                          child: _selectedRekeningHeader == null
                                              ? Text(
                                            'Pilih Account Header',
                                            style: GoogleFonts.montserrat(
                                              fontSize: 11,
                                              color: Colors.grey.shade500,
                                            ),
                                          )
                                              : Column(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                _selectedRekeningHeader!.rekKode,
                                                style: GoogleFonts.montserrat(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.black87,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ],
                                          ),
                                        ),
                                        Icon(Icons.arrow_drop_down, size: 16, color: Colors.grey.shade600),
                                      ],
                                    ),
                                  ),
                                ),
                                if (_selectedRekeningHeader != null) ...[
                                  SizedBox(height: 2),
                                  Text(
                                    _selectedRekeningHeader!.rekNama,
                                    style: GoogleFonts.montserrat(
                                      fontSize: 9,
                                      color: Colors.grey.shade600,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ],
                            ),

                            SizedBox(height: 12),

                            // Keterangan Header
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Keterangan *',
                                  style: GoogleFonts.montserrat(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Container(
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade50,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: Colors.grey.shade300, width: 1),
                                  ),
                                  padding: EdgeInsets.symmetric(horizontal: 10),
                                  alignment: Alignment.centerLeft,
                                  child: TextFormField(
                                    controller: _keteranganController,
                                    style: GoogleFonts.montserrat(fontSize: 11),
                                    decoration: InputDecoration(
                                      hintText: 'Keterangan biaya...',
                                      hintStyle: GoogleFonts.montserrat(
                                        fontSize: 10,
                                        color: Colors.grey.shade500,
                                      ),
                                      border: InputBorder.none,
                                      isDense: true,
                                      contentPadding: EdgeInsets.zero,
                                    ),
                                    validator: (value) {
                                      if (value == null || value.trim().isEmpty) {
                                        return 'Keterangan harus diisi';
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                              ],
                            ),

                            SizedBox(height: 12),

                            // Nilai Header
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Nilai Total *',
                                  style: GoogleFonts.montserrat(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Container(
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade50,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: Colors.grey.shade300, width: 1),
                                  ),
                                  padding: EdgeInsets.symmetric(horizontal: 10),
                                  alignment: Alignment.centerLeft,
                                  child: Row(
                                    children: [
                                      Text(
                                        'Rp ',
                                        style: GoogleFonts.montserrat(
                                          fontSize: 11,
                                          color: Colors.grey.shade700,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      Expanded(
                                        child: TextFormField(
                                          controller: _nilaiController,
                                          keyboardType: TextInputType.number,
                                          style: GoogleFonts.montserrat(fontSize: 11),
                                          decoration: InputDecoration(
                                            hintText: '0',
                                            hintStyle: GoogleFonts.montserrat(
                                              fontSize: 10,
                                              color: Colors.grey.shade500,
                                            ),
                                            border: InputBorder.none,
                                            isDense: true,
                                            contentPadding: EdgeInsets.zero,
                                          ),
                                          onChanged: _onNilaiChanged,
                                          validator: (value) {
                                            if (value == null || value.trim().isEmpty) {
                                              return 'Nilai harus diisi';
                                            }
                                            final cleanValue = value.replaceAll('.', '');
                                            final nilai = double.tryParse(cleanValue);
                                            if (nilai == null || nilai <= 0) {
                                              return 'Nilai harus > 0';
                                            }
                                            return null;
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      SizedBox(height: 16),

                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Detail Biaya',
                                  style: GoogleFonts.montserrat(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.black87,
                                  ),
                                ),
                                Container(
                                  height: 30,
                                  child: ElevatedButton.icon(
                                    onPressed: _addDetail,
                                    icon: Icon(Icons.add, size: 12, color: Colors.white),
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
                                      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            SizedBox(height: 12),

                            // Total Summary
                            Container(
                              padding: EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.grey.shade300, width: 1),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Total Detail:',
                                    style: GoogleFonts.montserrat(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey.shade700,
                                    ),
                                  ),
                                  Text(
                                    _formatCurrency(_totalDetail),
                                    style: GoogleFonts.montserrat(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: (_totalDetail - (double.tryParse(_nilaiController.text.replaceAll('.', '')) ?? 0)).abs() <= 0.01
                                          ? Colors.green
                                          : Colors.red,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      SizedBox(height: 12),

                      // Details List
                      if (_details.isEmpty)
                        Container(
                          padding: EdgeInsets.all(20),
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
                          child: Column(
                            children: [
                              Icon(
                                Icons.list_alt_outlined,
                                size: 36,
                                color: Colors.grey.shade400,
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Belum ada detail biaya',
                                style: GoogleFonts.montserrat(
                                  color: Colors.grey.shade500,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        ..._details.asMap().entries.map((entry) {
                          final index = entry.key;
                          final detail = entry.value;
                          return _buildDetailCard(index, detail);
                        }).toList(),
                    ],
                  ),
                ),
              ),

              SizedBox(height: 12),

              SizedBox(
                width: double.infinity,
                height: 42,
                child: ElevatedButton.icon(
                  onPressed: _isSaving ? null : _saveJurnal,
                  icon: _isSaving
                      ? SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                      : Icon(
                    isEdit ? Icons.edit_rounded : Icons.save_rounded,
                    size: 16,
                    color: Colors.white,
                  ),
                  label: Text(
                    isEdit ? 'UPDATE BIAYA' : 'SIMPAN BIAYA',
                    style: GoogleFonts.montserrat(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFFF6A918),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: EdgeInsets.symmetric(horizontal: 16),
                  ),
                ),
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
        borderRadius: BorderRadius.circular(6),
        onTap: () => _onJenisChanged(value),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            border: Border.all(
              color: isSelected ? Color(0xFFF6A918) : Colors.grey.shade300,
              width: isSelected ? 1.5 : 1,
            ),
            borderRadius: BorderRadius.circular(6),
            color: isSelected ? Color(0xFFF6A918).withOpacity(0.1) : Colors.white,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? Color(0xFFF6A918) : Colors.grey.shade400,
                    width: isSelected ? 5 : 1,
                  ),
                ),
              ),
              SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.montserrat(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? Color(0xFFF6A918) : Colors.grey.shade700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailCard(int index, JurnalDetailInput detail) {
    return Container(
      margin: EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 2,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
              ),
              border: Border(
                bottom: BorderSide(color: Colors.grey.shade200, width: 1),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Detail ${index + 1}',
                  style: GoogleFonts.montserrat(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700,
                  ),
                ),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(4),
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: Text(
                            'Hapus Detail?',
                            style: GoogleFonts.montserrat(fontSize: 14),
                          ),
                          content: Text(
                            'Apakah Anda yakin ingin menghapus detail ini?',
                            style: GoogleFonts.montserrat(fontSize: 12),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: Text(
                                'Batal',
                                style: GoogleFonts.montserrat(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ),
                            ElevatedButton(
                              onPressed: () {
                                Navigator.pop(context);
                                _removeDetail(index);
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
                        ),
                      );
                    },
                    child: Container(
                      padding: EdgeInsets.all(4),
                      child: Icon(
                        Icons.delete_outline,
                        size: 12,
                        color: Colors.red.shade600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: EdgeInsets.all(10),
            child: Column(
              children: [
                // Account Detail
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Account *',
                      style: GoogleFonts.montserrat(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    SizedBox(height: 4),
                    InkWell(
                      borderRadius: BorderRadius.circular(6),
                      onTap: () => _showRekeningDetailDialog(index),
                      child: Container(
                        height: 36,
                        padding: EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.grey.shade300, width: 1),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.account_balance_wallet, size: 14, color: Colors.grey.shade600),
                            SizedBox(width: 6),
                            Expanded(
                              child: detail.account.isEmpty
                                  ? Text(
                                'Pilih Account',
                                style: GoogleFonts.montserrat(
                                  fontSize: 11,
                                  color: Colors.grey.shade500,
                                ),
                              )
                                  : Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    detail.account,
                                    style: GoogleFonts.montserrat(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.black87,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            Icon(Icons.arrow_drop_down, size: 16, color: Colors.grey.shade600),
                          ],
                        ),
                      ),
                    ),
                    if (detail.account.isNotEmpty) ...[
                      SizedBox(height: 2),
                      Text(
                        detail.accountName,
                        style: GoogleFonts.montserrat(
                          fontSize: 9,
                          color: Colors.grey.shade600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),

                SizedBox(height: 10),

                // Nilai dan Cost Center
                Row(
                  children: [
                    // Nilai
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Nilai *',
                            style: GoogleFonts.montserrat(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade700,
                            ),
                          ),
                          SizedBox(height: 4),
                          Container(
                            height: 36,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.grey.shade300, width: 1),
                            ),
                            padding: EdgeInsets.symmetric(horizontal: 10),
                            alignment: Alignment.centerLeft,
                            child: Row(
                              children: [
                                Text(
                                  'Rp ',
                                  style: GoogleFonts.montserrat(
                                    fontSize: 11,
                                    color: Colors.grey.shade700,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Expanded(
                                  child: TextField(
                                    controller: TextEditingController(
                                      text: detail.nilai > 0
                                          ? NumberFormat('#,###', 'id_ID').format(detail.nilai.toInt())
                                          : '',
                                    ),
                                    keyboardType: TextInputType.number,
                                    style: GoogleFonts.montserrat(fontSize: 11),
                                    decoration: InputDecoration(
                                      hintText: '0',
                                      hintStyle: GoogleFonts.montserrat(
                                        fontSize: 10,
                                        color: Colors.grey.shade500,
                                      ),
                                      border: InputBorder.none,
                                      isDense: true,
                                      contentPadding: EdgeInsets.zero,
                                    ),
                                    onChanged: (value) {
                                      final cleanValue = value.replaceAll('.', '');
                                      final newNilai = double.tryParse(cleanValue) ?? 0;
                                      _updateDetail(index, JurnalDetailInput(
                                        account: detail.account,
                                        accountName: detail.accountName,
                                        nilai: newNilai,
                                        keterangan: detail.keterangan,
                                        costcenter: detail.costcenter,
                                        costcenterName: detail.costcenterName,
                                      ));
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    SizedBox(width: 10),

                    // Cost Center
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Cost Center',
                            style: GoogleFonts.montserrat(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade700,
                            ),
                          ),
                          SizedBox(height: 4),
                          InkWell(
                            borderRadius: BorderRadius.circular(6),
                            onTap: () => _showCostCenterDialog(index),
                            child: Container(
                              height: 36,
                              padding: EdgeInsets.symmetric(horizontal: 10),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.grey.shade300, width: 1),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.business, size: 14, color: Colors.grey.shade600),
                                  SizedBox(width: 6),
                                  Expanded(
                                    child: detail.costcenter.isEmpty
                                        ? Text(
                                      'Pilih',
                                      style: GoogleFonts.montserrat(
                                        fontSize: 11,
                                        color: Colors.grey.shade500,
                                      ),
                                    )
                                        : Text(
                                      detail.costcenter,
                                      style: GoogleFonts.montserrat(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.black87,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Icon(Icons.arrow_drop_down, size: 16, color: Colors.grey.shade600),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                // SizedBox(height: 10),
                //
                // // Keterangan Detail
                // Column(
                //   crossAxisAlignment: CrossAxisAlignment.start,
                //   children: [
                //     Text(
                //       'Keterangan',
                //       style: GoogleFonts.montserrat(
                //         fontSize: 10,
                //         fontWeight: FontWeight.w600,
                //         color: Colors.grey.shade700,
                //       ),
                //     ),
                //     SizedBox(height: 4),
                //     Container(
                //       height: 36,
                //       decoration: BoxDecoration(
                //         color: Colors.grey.shade50,
                //         borderRadius: BorderRadius.circular(6),
                //         border: Border.all(color: Colors.grey.shade300, width: 1),
                //       ),
                //       padding: EdgeInsets.symmetric(horizontal: 10),
                //       alignment: Alignment.centerLeft,
                //       child: TextField(
                //         style: GoogleFonts.montserrat(fontSize: 11),
                //         decoration: InputDecoration(
                //           hintText: 'Keterangan detail...',
                //           hintStyle: GoogleFonts.montserrat(
                //             fontSize: 10,
                //             color: Colors.grey.shade500,
                //           ),
                //           border: InputBorder.none,
                //           isDense: true,
                //           contentPadding: EdgeInsets.zero,
                //         ),
                //         onChanged: (value) {
                //           _updateDetail(index, JurnalDetailInput(
                //             account: detail.account,
                //             accountName: detail.accountName,
                //             nilai: detail.nilai,
                //             keterangan: value,
                //             costcenter: detail.costcenter,
                //             costcenterName: detail.costcenterName,
                //           ));
                //         },
                //       ),
                //     ),
                //   ],
                // ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}