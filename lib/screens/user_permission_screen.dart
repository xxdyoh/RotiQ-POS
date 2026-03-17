import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/base_layout.dart';
import '../services/api_service.dart';
import '../services/session_manager.dart';

class UserPermissionScreen extends StatefulWidget {
  const UserPermissionScreen({super.key});

  @override
  State<UserPermissionScreen> createState() => _UserPermissionScreenState();
}

class _UserPermissionScreenState extends State<UserPermissionScreen> {
  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _menus = [];
  Map<String, Map<int, Map<String, int>>> _permissions = {};
  String? _selectedUserKode;
  bool _isLoading = true;
  bool _isSaving = false;

  final Color _primaryDark = const Color(0xFF2C3E50);
  final Color _accentGold = const Color(0xFFF6A918);
  final Color _bgLight = const Color(0xFFFAFAFA);
  final Color _textPrimary = const Color(0xFF1A202C);
  final Color _textSecondary = const Color(0xFF718096);
  final Color _borderColor = const Color(0xFFE2E8F0);

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    setState(() => _isLoading = true);

    try {
      await _initMenuData();
      await _loadUsers();
      await _loadMenus();
    } catch (e) {
      _showError('Gagal memuat data: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _initMenuData() async {
    try {
      await ApiService.post('/permissions/init-menu', {});
    } catch (e) {
      print('Init menu error: $e');
    }
  }

  Future<void> _loadUsers() async {
    try {
      final response = await ApiService.getData('/permissions/users');
      if (response['success'] == true) {
        setState(() {
          _users = List<Map<String, dynamic>>.from(response['data']);
        });
      }
    } catch (e) {
      _showError('Gagal memuat daftar user: $e');
    }
  }

  Future<void> _loadMenus() async {
    try {
      final response = await ApiService.getData('/permissions/menu');
      if (response['success'] == true) {
        setState(() {
          _menus = List<Map<String, dynamic>>.from(response['data']);
        });
      }
    } catch (e) {
      _showError('Gagal memuat daftar menu: $e');
    }
  }

  Future<void> _loadUserPermissions(String kduser) async {
    try {
      final response = await ApiService.getData('/permissions/user/$kduser');
      if (response['success'] == true) {
        setState(() {
          _permissions[kduser] = {};
          final data = response['data'] as Map<String, dynamic>;
          data.forEach((menuId, value) {
            final menuIdInt = int.parse(menuId);
            _permissions[kduser]![menuIdInt] = {
              'insert': value['insert'] ?? 0,
              'edit': value['edit'] ?? 0,
              'delete': value['delete'] ?? 0,
            };
          });
        });
      }
    } catch (e) {
      _showError('Gagal memuat hak akses: $e');
    }
  }

  Future<void> _savePermissions() async {
    if (_selectedUserKode == null) return;

    final selectedKode = _selectedUserKode!;
    setState(() => _isSaving = true);

    try {
      final userPermissions = _permissions[selectedKode] ?? {};

      await ApiService.post(
          '/permissions/user/$selectedKode',
          {'permissions': userPermissions}
      );

      _showSuccess('Hak akses berhasil disimpan');
    } catch (e) {
      _showError('Gagal menyimpan: $e');
    } finally {
      setState(() => _isSaving = false);
    }
  }

  void _updatePermission(int menuId, String type, int value) {
    if (_selectedUserKode == null) return;

    final selectedKode = _selectedUserKode!;
    setState(() {
      _permissions[selectedKode] ??= {};
      _permissions[selectedKode]![menuId] ??= {
        'insert': 0,
        'edit': 0,
        'delete': 0,
      };
      _permissions[selectedKode]![menuId]![type] = value;
    });
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BaseLayout(
      title: 'User Permissions',
      showBackButton: true,
      showSidebar: true,
      child: _isLoading
          ? Center(child: CircularProgressIndicator(color: _accentGold))
          : Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildUserList(),
          VerticalDivider(width: 1, color: _borderColor),
          Expanded(
            child: _selectedUserKode == null
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.admin_panel_settings, size: 64, color: _borderColor),
                  SizedBox(height: 16),
                  Text(
                    'Pilih user di samping',
                    style: GoogleFonts.montserrat(
                      fontSize: 16,
                      color: _textSecondary,
                    ),
                  ),
                ],
              ),
            )
                : _buildPermissionList(),
          ),
        ],
      ),
    );
  }

  Widget _buildUserList() {
    return Container(
      width: 250,
      decoration: BoxDecoration(
        border: Border(right: BorderSide(color: _borderColor)),
      ),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: _borderColor)),
            ),
            child: Text(
              'Daftar User',
              style: GoogleFonts.montserrat(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: _textPrimary,
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _users.length,
              itemBuilder: (context, index) {
                final user = _users[index];
                final isSelected = _selectedUserKode == user['kduser'];

                return Material(
                  color: isSelected ? _accentGold.withOpacity(0.1) : Colors.transparent,
                  child: InkWell(
                    onTap: () async {
                      setState(() {
                        _selectedUserKode = user['kduser'];
                      });
                      await _loadUserPermissions(user['kduser']);
                    },
                    child: Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: _borderColor.withOpacity(0.5)),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: _accentGold.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(Icons.person, size: 16, color: _accentGold),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  user['nmuser'] ?? '',
                                  style: GoogleFonts.montserrat(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: _textPrimary,
                                  ),
                                ),
                                Text(
                                  user['kduser'] ?? '',
                                  style: GoogleFonts.montserrat(
                                    fontSize: 10,
                                    color: _textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
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

  Widget _buildPermissionList() {
    final selectedKode = _selectedUserKode!;
    final userPermissions = _permissions[selectedKode] ?? {};

    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: _borderColor)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Atur Hak Akses',
                  style: GoogleFonts.montserrat(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _textPrimary,
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: _isSaving ? null : _savePermissions,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _accentGold,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                child: _isSaving
                    ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
                    : Text(
                  'Simpan',
                  style: GoogleFonts.montserrat(fontSize: 12),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: EdgeInsets.all(16),
            itemCount: _menus.length,
            itemBuilder: (context, index) {
              final menu = _menus[index];
              final menuId = menu['MEN_ID'] as int;
              final permission = userPermissions[menuId] ?? {
                'insert': 0,
                'edit': 0,
                'delete': 0,
              };

              return Container(
                margin: EdgeInsets.only(bottom: 8),
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _bgLight,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _borderColor),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            menu['MEN_NAMA'] ?? '',
                            style: GoogleFonts.montserrat(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: _textPrimary,
                            ),
                          ),
                          if (menu['MEN_KETERANGAN'] != null)
                            Text(
                              menu['MEN_KETERANGAN'],
                              style: GoogleFonts.montserrat(
                                fontSize: 11,
                                color: _textSecondary,
                              ),
                            ),
                        ],
                      ),
                    ),
                    Row(
                      children: [
                        _buildPermissionCheck('Insert', menuId, 'insert', permission['insert'] == 1),
                        SizedBox(width: 16),
                        _buildPermissionCheck('Edit', menuId, 'edit', permission['edit'] == 1),
                        SizedBox(width: 16),
                        _buildPermissionCheck('Delete', menuId, 'delete', permission['delete'] == 1),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPermissionCheck(String label, int menuId, String type, bool value) {
    return InkWell(
      onTap: () => _updatePermission(menuId, type, value ? 0 : 1),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: value ? _accentGold.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: value ? _accentGold : _borderColor,
          ),
        ),
        child: Row(
          children: [
            Icon(
              value ? Icons.check_box : Icons.check_box_outline_blank,
              size: 16,
              color: value ? _accentGold : _textSecondary,
            ),
            SizedBox(width: 4),
            Text(
              label,
              style: GoogleFonts.montserrat(
                fontSize: 11,
                color: value ? _accentGold : _textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}