import 'package:flutter/material.dart';
import '../../services/library_api_service.dart';
import 'books_list_screen_working.dart';
import 'borrowed_books_screen.dart';

class MemberDashboardScreen extends StatefulWidget {
  MemberDashboardScreen({Key? key}) : super(key: key);

  @override
  _MemberDashboardScreenState createState() => _MemberDashboardScreenState();
}

class _MemberDashboardScreenState extends State<MemberDashboardScreen> {
  final LibraryApiService _apiService = LibraryApiService();

  Map<String, dynamic> _stats = {};
  bool _isLoading = true;
  String? _userName;
  int? _currentMemberId;

  @override
  void initState() {
    super.initState();
    _loadMemberData();
  }

  Future<void> _loadMemberData() async {
    setState(() => _isLoading = true);

    try {
      // Get current user info
      final userName = await _apiService.getUserName();
      int? userId = await _apiService.getUserId();

      // If user ID not found, try from profile
      if (userId == null) {
        final profile = await _apiService.getUserProfile();
        if (profile != null && profile['id'] != null) {
          userId = profile['id'];
        }
      }

      if (userId != null) {
        _currentMemberId = userId;
      } else {
        // Show login error instead of fallback
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'Sesi login tidak valid. Silakan logout dan login kembali.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        _currentMemberId = null;
        setState(() => _isLoading = false);
        return;
      }

      // Get member borrowing statistics
      await _calculateMemberStats();

      setState(() {
        _userName = userName;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading data: $e')),
        );
      }
    }
  }

  Future<void> _calculateMemberStats() async {
    try {
      final allBorrowings = await _apiService.getAllBorrowings();

      // Filter borrowings for current member
      final memberBorrowings = allBorrowings.where((borrowing) {
        // Check id_member field directly (this is the main field in API response)
        if (borrowing['id_member'] != null) {
          return borrowing['id_member'] == _currentMemberId;
        }
        // Fallback: check nested member.id
        final member = borrowing['member'];
        if (member != null && member['id'] != null) {
          return member['id'] == _currentMemberId;
        }
        // Fallback: check member_id field
        if (borrowing['member_id'] != null) {
          return borrowing['member_id'] == _currentMemberId;
        }
        return false;
      }).toList();

      print(
          'DEBUG: Found ${memberBorrowings.length} borrowings for member $_currentMemberId');

      // Debug: Print first few borrowings to understand structure
      for (int i = 0; i < memberBorrowings.length && i < 3; i++) {
        final borrowing = memberBorrowings[i];
        print(
            'DEBUG Borrowing ${i + 1}: ID=${borrowing['id']}, Status=${borrowing['status']}, ReturnDate=${borrowing['tanggal_pengembalian_aktual']}, DueDate=${borrowing['tanggal_pengembalian']}');
      }

      int totalBorrowed = memberBorrowings.length;
      int currentlyBorrowed = 0;
      int returned = 0;
      int overdue = 0;

      final now = DateTime.now();

      for (var borrowing in memberBorrowings) {
        // Check status field first (API uses status: "1" for borrowed, "2" for returned)
        final status = borrowing['status'];
        final returnedDate = borrowing['tanggal_pengembalian_aktual'];

        // A book is considered returned if:
        // 1. It has an actual return date, OR
        // 2. Status is "2" (returned), OR
        // 3. Status is "3" (also returned), OR
        // 4. Status is not "1" (not currently borrowed)
        bool isReturned = returnedDate != null ||
            status == "2" ||
            status == 2 ||
            status == "3" ||
            status == 3 ||
            (status != "1" && status != 1);

        if (isReturned) {
          returned++;
        } else {
          currentlyBorrowed++;

          // Check if overdue (only for currently borrowed books)
          try {
            final dueDate = DateTime.parse(borrowing['tanggal_pengembalian']);
            if (now.isAfter(dueDate)) {
              overdue++;
            }
          } catch (e) {
            // Invalid date format, skip overdue check
          }
        }
      }

      print(
          'DEBUG Final Stats: Total=$totalBorrowed, Currently=$currentlyBorrowed, Returned=$returned, Overdue=$overdue');

      setState(() {
        _stats = {
          'total_borrowed': totalBorrowed,
          'currently_borrowed': currentlyBorrowed,
          'returned': returned,
          'overdue': overdue,
        };
      });
    } catch (e) {
      print('Error calculating member stats: $e');
      setState(() {
        _stats = {
          'total_borrowed': 0,
          'currently_borrowed': 0,
          'returned': 0,
          'overdue': 0,
        };
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard Member'),
        backgroundColor: Colors.blue.shade600,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadMemberData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Welcome Card
                    Card(
                      elevation: 4,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.blue.shade600,
                              Colors.blue.shade400
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Selamat Datang!',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _userName ?? 'Member',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Member ID: ${_currentMemberId ?? 'Unknown'}',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Statistics Grid
                    const Text(
                      'Statistik Peminjaman',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 16),

                    GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 2,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: 1.2,
                      children: [
                        _buildStatCard(
                          'Total Dipinjam',
                          _stats['total_borrowed']?.toString() ?? '0',
                          Icons.library_books,
                          Colors.blue,
                        ),
                        _buildStatCard(
                          'Sedang Dipinjam',
                          _stats['currently_borrowed']?.toString() ?? '0',
                          Icons.book,
                          Colors.orange,
                        ),
                        _buildStatCard(
                          'Sudah Dikembalikan',
                          _stats['returned']?.toString() ?? '0',
                          Icons.assignment_return,
                          Colors.green,
                        ),
                        _buildStatCard(
                          'Terlambat',
                          _stats['overdue']?.toString() ?? '0',
                          Icons.warning,
                          Colors.red,
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Quick Actions
                    const Text(
                      'Aksi Cepat',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 16),

                    Row(
                      children: [
                        Expanded(
                          child: _buildActionCard(
                            'Cari Buku',
                            Icons.search,
                            Colors.blue,
                            () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => MemberBooksListScreen(),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildActionCard(
                            'Riwayat Peminjaman',
                            Icons.history,
                            Colors.green,
                            () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => BorrowedBooksScreen(),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Tips Card
                    Card(
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.lightbulb,
                                    color: Colors.amber.shade600),
                                const SizedBox(width: 8),
                                const Text(
                                  'Tips Peminjaman',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              '• Kembalikan buku tepat waktu untuk menghindari denda\n'
                              '• Maksimal peminjaman adalah 14 hari\n'
                              '• Gunakan fitur pencarian untuk menemukan buku dengan mudah\n'
                              '• Periksa status peminjaman secara berkala',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.black87,
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildStatCard(
      String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 3,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Colors.white,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 32,
              color: color,
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.black54,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionCard(
      String title, IconData icon, Color color, VoidCallback onTap) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Icon(
                icon,
                size: 32,
                color: color,
              ),
              const SizedBox(height: 8),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
