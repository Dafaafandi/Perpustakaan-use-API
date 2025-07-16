import 'package:flutter/material.dart';
import './member/book                    () {
                      // Untuk sementara menggunakan SnackBar
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Navigasi ke halaman Buku Dipinjam'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                      
                      // TODO: Implementasi navigasi ke BorrowedBooksScreen
                      // Navigator.push(
                      //   context,
                      //   MaterialPageRoute(
                      //     builder: (context) => const BorrowedBooksScreen(),
                      //   ),
                      // );
                    },reen.dart';
import './member/borrowed_books_screen.dart';

class TestMemberScreen extends StatelessWidget {
  const TestMemberScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Member Features'),
        backgroundColor: Colors.blue.shade600,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text(
              'Library Member Features',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),

            // Feature Cards
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                children: [
                  _buildFeatureCard(
                    context,
                    'Cari Buku',
                    Icons.search,
                    Colors.blue,
                    'Browse dan cari buku dengan infinite scroll',
                    () {
                      // Untuk sementara menggunakan SnackBar
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Navigasi ke halaman Cari Buku'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                      
                      // TODO: Implementasi navigasi ke MemberBooksListScreen
                      // Navigator.push(
                      //   context,
                      //   MaterialPageRoute(
                      //     builder: (context) => const MemberBooksListScreen(),
                      //   ),
                      // );
                    },
                  ),
                  _buildFeatureCard(
                    context,
                    'Buku Dipinjam',
                    Icons.library_books,
                    Colors.green,
                    'Lihat dan kembalikan buku yang dipinjam',
                    () {
                      // Navigasi ke halaman buku dipinjam
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const BorrowedBooksScreen(),
                        ),
                      );
                    },
                  ),
                  _buildFeatureCard(
                    context,
                    'Status',
                    Icons.check_circle,
                    Colors.orange,
                    'Refresh data dan status member',
                    () {
                      // Kembali ke dashboard untuk refresh data
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content:
                              Text('Kembali ke dashboard untuk refresh data'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    },
                  ),
                  _buildFeatureCard(
                    context,
                    'Info',
                    Icons.info,
                    Colors.purple,
                    'Bantuan dan informasi aplikasi',
                    () => _showInfoDialog(context),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureCard(BuildContext context, String title, IconData icon,
      Color color, String description, VoidCallback onTap) {
    return Card(
      elevation: 4,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [color.withOpacity(0.7), color],
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 40, color: Colors.white),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                description,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.white70,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showInfoDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('📚 Bantuan Member'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Cara menggunakan aplikasi:',
                style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Text('🔍 Cari Buku: Browse dan cari koleksi buku perpustakaan'),
            Text('📚 Buku Dipinjam: Lihat status peminjaman Anda'),
            Text('🔄 Status: Kembali ke dashboard untuk refresh'),
            Text('ℹ️ Info: Tampilkan bantuan ini'),
            SizedBox(height: 16),
            Text('Fitur tersedia:',
                style: TextStyle(fontWeight: FontWeight.bold)),
            Text('• Pencarian buku dengan filter kategori'),
            Text('• Peminjaman buku langsung'),
            Text('• Tracking status peminjaman'),
            Text('• Pengembalian buku'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
  }
}
