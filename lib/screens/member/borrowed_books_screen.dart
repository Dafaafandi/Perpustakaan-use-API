import 'package:flutter/material.dart';
import '../../api/api_service.dart';

class BorrowedBooksScreen extends StatefulWidget {
  BorrowedBooksScreen({Key? key}) : super(key: key);

  @override
  _BorrowedBooksScreenState createState() => _BorrowedBooksScreenState();
}

class _BorrowedBooksScreenState extends State<BorrowedBooksScreen> {
  final ApiService _apiService = ApiService();

  List<dynamic> _borrowings = [];
  bool _isLoading = false;
  String _filterStatus = 'semua'; // semua, dipinjam, dikembalikan, terlambat
  int? _currentMemberId;

  @override
  void initState() {
    super.initState();
    _loadCurrentMember();
  }

  Future<void> _loadCurrentMember() async {
    try {
      // Get current user ID from stored login data
      final userId = await _apiService.getUserId();
      if (userId != null) {
        setState(() {
          _currentMemberId = userId;
        });
        _loadBorrowings();
      } else {
        // Try to get from user profile
        final profile = await _apiService.getUserProfile();
        if (profile != null && profile['id'] != null) {
          setState(() {
            _currentMemberId = profile['id'];
          });
          _loadBorrowings();
        } else {
          // Show error - user not logged in
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Anda harus login terlebih dahulu'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memuat data user: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _loadBorrowings() async {
    if (_currentMemberId == null) return;

    setState(() => _isLoading = true);

    try {
      final allBorrowings = await _apiService.getAllBorrowings();

      // Filter borrowings for current member only
      final memberBorrowings = allBorrowings.where((borrowing) {
        // Check if borrowing belongs to current member
        final member = borrowing['member'];
        if (member != null && member['id'] != null) {
          return member['id'] == _currentMemberId;
        }
        // Check id_member field directly
        if (borrowing['id_member'] != null) {
          return borrowing['id_member'] == _currentMemberId;
        }
        // Fallback: check member_id field
        if (borrowing['member_id'] != null) {
          return borrowing['member_id'] == _currentMemberId;
        }
        return false;
      }).toList();

      setState(() => _borrowings = memberBorrowings);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memuat data peminjaman: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  List<dynamic> get _filteredBorrowings {
    if (_filterStatus == 'semua') {
      return _borrowings;
    }

    return _borrowings.where((borrowing) {
      final tanggalKembali = borrowing['tanggal_pengembalian_aktual'];
      final tanggalJatuhTempo = borrowing['tanggal_pengembalian'];
      final now = DateTime.now();

      switch (_filterStatus) {
        case 'dipinjam':
          return tanggalKembali == null;
        case 'dikembalikan':
          return tanggalKembali != null;
        case 'terlambat':
          if (tanggalKembali != null) return false;
          try {
            final jatuhTempo = DateTime.parse(tanggalJatuhTempo);
            return now.isAfter(jatuhTempo);
          } catch (e) {
            return false;
          }
        default:
          return true;
      }
    }).toList();
  }

  String _getStatusText(dynamic borrowing) {
    final tanggalKembali = borrowing['tanggal_pengembalian_aktual'];
    final tanggalJatuhTempo = borrowing['tanggal_pengembalian'];

    if (tanggalKembali != null) {
      return 'Dikembalikan';
    }

    try {
      final jatuhTempo = DateTime.parse(tanggalJatuhTempo);
      final now = DateTime.now();

      if (now.isAfter(jatuhTempo)) {
        return 'Terlambat';
      } else {
        return 'Dipinjam';
      }
    } catch (e) {
      return 'Dipinjam';
    }
  }

  Color _getStatusColor(dynamic borrowing) {
    final status = _getStatusText(borrowing);
    switch (status) {
      case 'Dikembalikan':
        return Colors.green;
      case 'Terlambat':
        return Colors.red;
      case 'Dipinjam':
      default:
        return Colors.orange;
    }
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return '-';
    try {
      final date = DateTime.parse(dateString);
      return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
    } catch (e) {
      return dateString;
    }
  }

  Future<void> _showReturnDialog(dynamic borrowing) async {
    final TextEditingController dateController = TextEditingController();
    DateTime selectedDate = DateTime.now();
    dateController.text =
        _formatDate(selectedDate.toIso8601String().split('T')[0]);

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Kembalikan Buku'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Buku: ${borrowing['buku']?['judul'] ?? 'Unknown'}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: dateController,
                decoration: const InputDecoration(
                  labelText: 'Tanggal Pengembalian',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.calendar_today),
                  suffixIcon: Icon(Icons.arrow_drop_down),
                ),
                readOnly: true,
                onTap: () async {
                  final DateTime? picked = await showDatePicker(
                    context: context,
                    initialDate: selectedDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                  );

                  if (picked != null) {
                    setDialogState(() {
                      selectedDate = picked;
                      dateController.text =
                          _formatDate(picked.toIso8601String().split('T')[0]);
                    });
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Kembalikan'),
            ),
          ],
        ),
      ),
    );

    if (result == true) {
      await _returnBook(
          borrowing['id'], selectedDate.toIso8601String().split('T')[0]);
    }
  }

  Future<void> _returnBook(int borrowingId, String returnDate) async {
    try {
      final success = await _apiService.returnBook(borrowingId, returnDate);

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Buku berhasil dikembalikan'),
              backgroundColor: Colors.green,
            ),
          );
          _loadBorrowings(); // Refresh the list
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Gagal mengembalikan buku'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showBorrowingDetail(dynamic borrowing) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Detail Peminjaman'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('ID: ${borrowing['id']}'),
            const SizedBox(height: 8),
            Text('Buku: ${borrowing['buku']?['judul'] ?? 'Unknown'}'),
            Text('Pengarang: ${borrowing['buku']?['pengarang'] ?? 'Unknown'}'),
            const SizedBox(height: 8),
            Text('Member: ${borrowing['member']?['name'] ?? 'Unknown'}'),
            const SizedBox(height: 8),
            Text(
                'Tanggal Pinjam: ${_formatDate(borrowing['tanggal_peminjaman'])}'),
            Text(
                'Tanggal Jatuh Tempo: ${_formatDate(borrowing['tanggal_pengembalian'])}'),
            Text(
                'Tanggal Kembali: ${_formatDate(borrowing['tanggal_pengembalian_aktual'])}'),
            const SizedBox(height: 8),
            Row(
              children: [
                const Text('Status: '),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getStatusColor(borrowing),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _getStatusText(borrowing),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
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

  @override
  Widget build(BuildContext context) {
    final filteredBorrowings = _filteredBorrowings;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Buku Dipinjam'),
        backgroundColor: Colors.blue.shade600,
        foregroundColor: Colors.white,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list),
            onSelected: (value) {
              setState(() => _filterStatus = value);
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'semua', child: Text('Semua')),
              const PopupMenuItem(
                  value: 'dipinjam', child: Text('Sedang Dipinjam')),
              const PopupMenuItem(
                  value: 'dikembalikan', child: Text('Sudah Dikembalikan')),
              const PopupMenuItem(value: 'terlambat', child: Text('Terlambat')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Info
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: Colors.blue.shade50,
            child: Text(
              'Menampilkan: ${_getFilterText(_filterStatus)} (${filteredBorrowings.length} item)',
              style: TextStyle(
                color: Colors.blue.shade700,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),

          // Borrowings List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : filteredBorrowings.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.book_outlined,
                              size: 64,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Tidak ada data peminjaman',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadBorrowings,
                        child: ListView.builder(
                          itemCount: filteredBorrowings.length,
                          itemBuilder: (context, index) {
                            final borrowing = filteredBorrowings[index];
                            final status = _getStatusText(borrowing);
                            final statusColor = _getStatusColor(borrowing);

                            return Card(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: statusColor,
                                  child: const Icon(
                                    Icons.book,
                                    color: Colors.white,
                                  ),
                                ),
                                title: Text(
                                  borrowing['buku']?['judul'] ?? 'Unknown Book',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                        'Pinjam: ${_formatDate(borrowing['tanggal_peminjaman'])}'),
                                    Text(
                                        'Jatuh tempo: ${_formatDate(borrowing['tanggal_pengembalian'])}'),
                                    if (borrowing[
                                            'tanggal_pengembalian_aktual'] !=
                                        null)
                                      Text(
                                          'Dikembalikan: ${_formatDate(borrowing['tanggal_pengembalian_aktual'])}'),
                                  ],
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: statusColor,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        status,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    PopupMenuButton<String>(
                                      onSelected: (value) {
                                        switch (value) {
                                          case 'detail':
                                            _showBorrowingDetail(borrowing);
                                            break;
                                          case 'return':
                                            _showReturnDialog(borrowing);
                                            break;
                                        }
                                      },
                                      itemBuilder: (context) => [
                                        const PopupMenuItem(
                                          value: 'detail',
                                          child: Row(
                                            children: [
                                              Icon(Icons.info_outline),
                                              SizedBox(width: 8),
                                              Text('Detail'),
                                            ],
                                          ),
                                        ),
                                        if (borrowing[
                                                'tanggal_pengembalian_aktual'] ==
                                            null)
                                          const PopupMenuItem(
                                            value: 'return',
                                            child: Row(
                                              children: [
                                                Icon(Icons.assignment_return),
                                                SizedBox(width: 8),
                                                Text('Kembalikan'),
                                              ],
                                            ),
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  String _getFilterText(String filter) {
    switch (filter) {
      case 'dipinjam':
        return 'Sedang Dipinjam';
      case 'dikembalikan':
        return 'Sudah Dikembalikan';
      case 'terlambat':
        return 'Terlambat';
      case 'semua':
      default:
        return 'Semua Peminjaman';
    }
  }
}
