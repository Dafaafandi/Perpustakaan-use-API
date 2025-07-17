import 'package:flutter/material.dart';
import 'package:perpus_app/api/api_service.dart';
import 'package:perpus_app/screens/auth/login_screen.dart';
import 'package:perpus_app/screens/admin/admin_book_management_screen.dart';
import 'package:perpus_app/screens/admin/admin_category_management_screen.dart';
import 'package:perpus_app/screens/admin/admin_member_management_screen.dart';
import 'package:perpus_app/screens/admin/admin_borrowing_management_screen.dart';
import 'dart:html' as html;
import 'package:file_picker/file_picker.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final ApiService _apiService = ApiService();
  String? _userName;
  Map<String, dynamic>? _dashboardStats;

  @override
  void initState() {
    super.initState();
    _loadAdminData();
  }

  void _loadAdminData() async {
    final name = await _apiService.getUserName();
    final stats = await _apiService.getDashboardStats();
    setState(() {
      _userName = name;
      _dashboardStats = stats;
    });
  }

  void _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Konfirmasi Logout'),
        content: const Text('Apakah Anda yakin ingin keluar dari Admin Panel?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Batal')),
          TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Logout', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm == true) {
      await _apiService.logout();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        backgroundColor: Colors.red.shade600,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
              icon: const Icon(Icons.logout),
              onPressed: _logout,
              tooltip: 'Logout Admin'),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // Welcome Card
          Card(
            color: Colors.red.shade50,
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.admin_panel_settings,
                          color: Colors.red.shade600, size: 32),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Selamat Datang, Administrator',
                              style: TextStyle(
                                  fontSize: 18, color: Colors.grey.shade700)),
                          const SizedBox(height: 4),
                          _userName == null
                              ? const SizedBox(
                                  height: 28,
                                  width: 200,
                                  child: LinearProgressIndicator())
                              : Text(_userName!,
                                  style: TextStyle(
                                      fontSize: 26,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.red.shade700)),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Statistics Cards
          if (_dashboardStats != null) ...[
            const Text('Statistik Perpustakaan',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                    child: _buildStatCard(
                        'Total Buku',
                        _dashboardStats!['total_books'] ?? 0,
                        Icons.menu_book,
                        Colors.blue)),
                const SizedBox(width: 8),
                Expanded(
                    child: _buildStatCard(
                        'Total Member',
                        _dashboardStats!['total_members'] ?? 0,
                        Icons.people,
                        Colors.green)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                    child: _buildStatCard(
                        'Dipinjam',
                        _dashboardStats!['books_borrowed'] ?? 0,
                        Icons.bookmark_added,
                        Colors.orange)),
                const SizedBox(width: 8),
                Expanded(
                    child: _buildStatCard(
                        'Tersedia',
                        _dashboardStats!['books_available'] ?? 0,
                        Icons.bookmark_border,
                        Colors.purple)),
              ],
            ),
            const SizedBox(height: 24),
          ],

          // Management Menu
          const Text('Menu Manajemen',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          GridView.count(
            physics: const NeverScrollableScrollPhysics(),
            shrinkWrap: true,
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            children: [
              _buildAdminMenuItem(context,
                  icon: Icons.menu_book,
                  label: 'Manajemen Buku',
                  color: Colors.indigo,
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => const AdminBookManagementScreen()))),
              _buildAdminMenuItem(context,
                  icon: Icons.category,
                  label: 'Manajemen Kategori',
                  color: Colors.teal,
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => const AdminCategoryManagementScreen()))),
              _buildAdminMenuItem(context,
                  icon: Icons.people,
                  label: 'Manajemen Member',
                  color: Colors.green,
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => const AdminMemberManagementScreen()))),
              _buildAdminMenuItem(context,
                  icon: Icons.library_books,
                  label: 'Peminjaman Buku',
                  color: Colors.orange,
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => const AdminBorrowingManagementScreen()))),
              _buildAdminMenuItem(context,
                  icon: Icons.file_download,
                  label: 'Export Excel',
                  color: Colors.blue,
                  onTap: _exportExcel),
              _buildAdminMenuItem(context,
                  icon: Icons.picture_as_pdf,
                  label: 'Export PDF',
                  color: Colors.red,
                  onTap: _exportPDF),
              _buildAdminMenuItem(context,
                  icon: Icons.cloud_download,
                  label: 'Download Template',
                  color: Colors.purple,
                  onTap: _downloadTemplate),
              _buildAdminMenuItem(context,
                  icon: Icons.cloud_upload,
                  label: 'Import Excel',
                  color: Colors.deepOrange,
                  onTap: _importExcel),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, int value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              value.toString(),
              style: TextStyle(
                  fontSize: 24, fontWeight: FontWeight.bold, color: color),
            ),
            Text(title,
                style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  Widget _buildAdminMenuItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 40),
              const SizedBox(height: 12),
              Text(
                label,
                textAlign: TextAlign.center,
                style:
                    const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _exportExcel() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('Menyiapkan file Excel...'),
          ],
        ),
      ),
    );

    final downloadUrl = await _apiService.exportBooksToExcel();
    Navigator.of(context).pop(); // Close loading dialog

    if (downloadUrl != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('File Excel berhasil dibuat!'),
          action: SnackBarAction(
            label: 'Download',
            onPressed: () {
              _downloadFile(downloadUrl, 'buku_export.xlsx');
            },
          ),
        ),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal membuat file Excel')),
      );
    }
  }

  // Helper method to download file in web browser
  void _downloadFile(String url, String fileName) {
    // Create an anchor element for download
    final html.AnchorElement anchor = html.AnchorElement(href: url)
      ..download = fileName
      ..style.display = 'none';

    // Add to DOM, click, and remove
    html.document.body!.children.add(anchor);
    anchor.click();
    html.document.body!.children.remove(anchor);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('File $fileName mulai didownload...'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  void _exportPDF() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('Menyiapkan file PDF...'),
          ],
        ),
      ),
    );

    final downloadUrl = await _apiService.exportBooksToPdf();
    Navigator.of(context).pop(); // Close loading dialog

    if (downloadUrl != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('File PDF berhasil dibuat!'),
          action: SnackBarAction(
            label: 'Download',
            onPressed: () {
              _downloadFile(downloadUrl, 'buku_export.pdf');
            },
          ),
        ),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal membuat file PDF')),
      );
    }
  }

  void _downloadTemplate() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('Menyiapkan template Excel...'),
          ],
        ),
      ),
    );

    final downloadUrl = await _apiService.downloadBookTemplate();
    Navigator.of(context).pop(); // Close loading dialog

    if (downloadUrl != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Template Excel berhasil dibuat!'),
          action: SnackBarAction(
            label: 'Download',
            onPressed: () {
              _downloadFile(downloadUrl, 'template_buku_import.xlsx');
            },
          ),
        ),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal membuat template Excel')),
      );
    }
  }

  void _importExcel() async {
    try {
      // Pick Excel file
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
        allowMultiple: false,
        withData: true,
      );

      if (result != null && result.files.single.bytes != null) {
        final file = result.files.single;

        // Show loading dialog
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const AlertDialog(
            content: Row(
              children: [
                CircularProgressIndicator(),
                SizedBox(width: 16),
                Text('Mengimpor data dari Excel...'),
              ],
            ),
          ),
        );

        // Call import API
        final importResult = await _apiService.importBooksFromExcel(
          file.bytes!,
          file.name,
        );

        Navigator.of(context).pop(); // Close loading dialog

        if (mounted) {
          if (importResult['success']) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(importResult['message']),
                backgroundColor: Colors.green,
                action: SnackBarAction(
                  label: 'Refresh',
                  onPressed: () {
                    _loadAdminData(); // Refresh data
                  },
                ),
              ),
            );
          } else {
            String errorMessage = importResult['message'] ?? 'Import gagal';

            // Check if this is an authentication error
            if (errorMessage.contains('Sesi telah berakhir') ||
                errorMessage.contains('login kembali') ||
                errorMessage.contains('Token tidak valid')) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(errorMessage),
                  backgroundColor: Colors.orange,
                  duration: const Duration(seconds: 5),
                  action: SnackBarAction(
                    label: 'Login',
                    textColor: Colors.white,
                    onPressed: () {
                      Navigator.pushReplacementNamed(context, '/login');
                    },
                  ),
                ),
              );
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(errorMessage),
                  backgroundColor: Colors.red,
                  duration: const Duration(seconds: 5),
                ),
              );
            }
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Tidak ada file yang dipilih')),
          );
        }
      }
    } catch (e) {
      Navigator.of(context).pop(); // Close loading dialog if still open
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Terjadi kesalahan: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
