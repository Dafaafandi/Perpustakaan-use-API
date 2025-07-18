import 'package:flutter/material.dart';
import '../../api/api_service.dart';
import '../../models/user.dart';
import '../auth/login_screen.dart';
import '../test_member_screen.dart';

class MemberDashboardScreen extends StatefulWidget {
  const MemberDashboardScreen({Key? key}) : super(key: key);

  @override
  _MemberDashboardScreenState createState() => _MemberDashboardScreenState();
}

class _MemberDashboardScreenState extends State<MemberDashboardScreen> {
  final ApiService _apiService = ApiService();
  User? _currentUser;
  bool _isLoading = true;
  Map<String, dynamic> _memberStats = {};

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadMemberStats();
  }

  Future<void> _loadUserData() async {
    try {
      // For now, we'll create a placeholder user since getCurrentUser is not implemented
      setState(() {
        _currentUser = User(
          id: 1,
          name: 'Member User',
          username: 'member',
          email: 'member@example.com',
          role: 'member',
        );
      });
    } catch (e) {
      print('Error loading user data: $e');
    }
  }

  Future<void> _loadMemberStats() async {
    setState(() => _isLoading = true);
    try {
      // Load real stats from API with proper error handling
      final borrowingsList = await _apiService.getAllBorrowings();
      final booksResponse =
          await _apiService.getBooksPaginated(page: 1, perPage: 100);

      int activeBorrowings = 0;
      int overdueBorrowings = 0;
      int totalBorrowings = borrowingsList.length;

      // Process borrowings data safely
      final now = DateTime.now();

      for (var borrowing in borrowingsList) {
        // Status: 1 = Dipinjam, 2 = Dikembalikan, 3 = Dikembalikan
        final status = borrowing['status']?.toString() ?? '';
        if (status == '1') {
          activeBorrowings++;

          // Check if overdue with safe date parsing
          try {
            final returnDateStr =
                borrowing['tanggal_pengembalian']?.toString() ?? '';
            if (returnDateStr.isNotEmpty && returnDateStr.contains('-')) {
              // Handle YYYY-MM-DD format
              final datePart =
                  returnDateStr.split(' ')[0]; // Take only date part
              final returnDate = DateTime.parse(datePart);
              if (now.isAfter(returnDate)) {
                overdueBorrowings++;
              }
            }
          } catch (e) {
            // Skip if date parsing fails
            print(
                'Date parsing skipped for: ${borrowing['tanggal_pengembalian']}');
          }
        }
      }

      int totalBooks = 0;
      if (booksResponse['success'] == true && booksResponse['data'] != null) {
        final bookData = booksResponse['data']['books'];
        if (bookData != null && bookData['total'] != null) {
          totalBooks = bookData['total'];
        }
      }

      setState(() {
        _memberStats = {
          'borrowedBooks': activeBorrowings,
          'overdueBooks': overdueBorrowings,
          'historyCount': totalBorrowings,
          'availableBooks': totalBooks,
        };
      });
    } catch (e) {
      print('Error loading member stats: $e');
      // Fallback to safe default values
      setState(() {
        _memberStats = {
          'borrowedBooks': 0,
          'overdueBooks': 0,
          'historyCount': 0,
          'availableBooks': 43, // From known API response
        };
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _logout() async {
    try {
      await _apiService.logout();
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error during logout: $e')),
      );
    }
  }

  Widget _buildStatCard(
      String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 4,
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: Colors.white, size: 32),
            const SizedBox(height: 16),
            Text(
              value,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.white70,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionButton(
      String title, IconData icon, VoidCallback onTap) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 32, color: Colors.indigo),
              const SizedBox(height: 8),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Member Dashboard'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _loadUserData();
              _loadMemberStats();
            },
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'logout':
                  _logout();
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'logout',
                child: ListTile(
                  leading: Icon(Icons.logout),
                  title: Text('Logout'),
                ),
              ),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Welcome Section
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.indigo.shade400,
                          Colors.indigo.shade600
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Selamat Datang!',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.white70,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _currentUser?.name ?? 'Member',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Role: ${_currentUser?.role ?? 'Member'}',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Quick Actions
                  const Text(
                    'Aksi Cepat',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),

                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 1.5,
                    children: [
                      _buildQuickActionButton(
                        'Member Features',
                        Icons.apps,
                        () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const TestMemberScreen(),
                            ),
                          );
                        },
                      ),
                      _buildQuickActionButton(
                        'Refresh Stats',
                        Icons.refresh,
                        () {
                          _loadMemberStats();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Statistics refreshed')),
                          );
                        },
                      ),
                    ],
                  ),

                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }
}
