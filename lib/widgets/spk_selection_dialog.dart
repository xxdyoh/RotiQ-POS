import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../services/serah_terima_service.dart';

class SpkSelectionDialog extends StatefulWidget {
  final Function(Map<String, dynamic>) onSpkSelected;

  const SpkSelectionDialog({
    super.key,
    required this.onSpkSelected,
  });

  @override
  State<SpkSelectionDialog> createState() => _SpkSelectionDialogState();
}

class _SpkSelectionDialogState extends State<SpkSelectionDialog> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _spkList = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSpkList();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadSpkList() async {
    setState(() => _isLoading = true);
    try {
      final spkData = await SerahTerimaService.getSpkList(
        search: _searchController.text.isEmpty ? null : _searchController.text,
      );
      setState(() => _spkList = spkData);
    } catch (e) {
      // Handle error
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _filterSpk(String query) {
    _loadSpkList();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Pilih SPK',
                  style: GoogleFonts.montserrat(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, color: Colors.grey.shade600),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Container(
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Row(
                children: [
                  Icon(Icons.search, size: 16, color: Colors.grey.shade500),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Cari nomor atau keterangan SPK...',
                        hintStyle: GoogleFonts.montserrat(fontSize: 12, color: Colors.grey.shade500),
                        border: InputBorder.none,
                        isDense: true,
                      ),
                      style: GoogleFonts.montserrat(fontSize: 12),
                      onChanged: _filterSpk,
                    ),
                  ),
                  if (_searchController.text.isNotEmpty)
                    IconButton(
                      icon: Icon(Icons.clear, size: 14, color: Colors.grey.shade500),
                      onPressed: () {
                        _searchController.clear();
                        _filterSpk('');
                      },
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                ],
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFFF6A918)))
                : _spkList.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inbox_outlined, size: 40, color: Colors.grey.shade400),
                  const SizedBox(height: 8),
                  Text(
                    'Tidak ada SPK tersedia',
                    style: GoogleFonts.montserrat(color: Colors.grey.shade500),
                  ),
                ],
              ),
            )
                : ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _spkList.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final spk = _spkList[index];
                return ListTile(
                  onTap: () {
                    widget.onSpkSelected(spk);
                  },
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF6A918).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.assignment, color: Color(0xFFF6A918), size: 20),
                  ),
                  title: Text(
                    spk['spk_nomor'],
                    style: GoogleFonts.montserrat(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    spk['spk_keterangan'] ?? '-',
                    style: GoogleFonts.montserrat(
                      fontSize: 11,
                      color: Colors.grey.shade600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Text(
                    DateFormat('dd/MM/yy').format(DateTime.parse(spk['spk_tanggal'])),
                    style: GoogleFonts.montserrat(
                      fontSize: 11,
                      color: Colors.grey.shade500,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}