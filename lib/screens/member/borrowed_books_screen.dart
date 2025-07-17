import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../services/library_api_service.dart';

class BorrowedBooksScreen extends StatefulWidget {
  BorrowedBooksScreen({Key? key}) : super(key: key);

  @override
  _BorrowedBooksScreenState createState() => _BorrowedBooksScreenState();
}

class _BorrowedBooksScreenState extends State<BorrowedBooksScreen> {
  final LibraryApiService _apiService = LibraryApiService();

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
      // Get current user ID from LibraryApiService
      int? userId = await _apiService.getUserId();
      if (kDebugMode) {
        print('Current User ID from SharedPreferences: $userId');
      }

      if (userId != null) {
        setState(() {
          _currentMemberId = userId;
        });
        _loadBorrowings();
      } else {
        // Try to get from user profile
        final profile = await _apiService.getUserProfile();
        if (profile != null && profile['id'] != null) {
          userId = profile['id'];
          setState(() {
            _currentMemberId = userId;
          });
          _loadBorrowings();
        } else {
          if (kDebugMode) {
            print('Could not determine current user ID');
          }
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                    'Tidak dapat mengidentifikasi user. Silakan login ulang.'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error loading current member: $e');
      }
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

  Future<void> _loadBorrowings() async {
    if (_currentMemberId == null) return;

    setState(() => _isLoading = true);

    try {
      final allBorrowings = await _apiService.getAllBorrowings();

      if (kDebugMode) {
        print('All borrowings count: ${allBorrowings.length}');
        print('Current member ID: $_currentMemberId');
        print(
            'Sample borrowing structure: ${allBorrowings.isNotEmpty ? allBorrowings.first : 'No data'}');
      }

      // Filter borrowings for current member only
      final memberBorrowings = allBorrowings.where((borrowing) {
        // Check if borrowing belongs to current member
        final member = borrowing['member'];
        if (member != null && member['id'] != null) {
          final memberId = member['id'];
          if (kDebugMode && allBorrowings.indexOf(borrowing) < 3) {
            print(
                'Checking borrowing ${borrowing['id']}: member.id = $memberId vs current = $_currentMemberId');
          }
          return memberId == _currentMemberId;
        }
        // Check id_member field directly
        if (borrowing['id_member'] != null) {
          final idMember = borrowing['id_member'];
          if (kDebugMode && allBorrowings.indexOf(borrowing) < 3) {
            print(
                'Checking borrowing ${borrowing['id']}: id_member = $idMember vs current = $_currentMemberId');
          }
          return idMember == _currentMemberId;
        }
        // Fallback: check member_id field
        if (borrowing['member_id'] != null) {
          final memberId = borrowing['member_id'];
          if (kDebugMode && allBorrowings.indexOf(borrowing) < 3) {
            print(
                'Checking borrowing ${borrowing['id']}: member_id = $memberId vs current = $_currentMemberId');
          }
          return memberId == _currentMemberId;
        }
        return false;
      }).toList();

      if (kDebugMode) {
        print(
            'Filtered borrowings for member $_currentMemberId: ${memberBorrowings.length}');
      }

      setState(() => _borrowings = memberBorrowings);
    } catch (e) {
      if (kDebugMode) {
        print('Error loading borrowings: $e');
      }
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
      final status = borrowing['status'];
      final tanggalKembali = _getActualReturnDate(borrowing);
      final tanggalJatuhTempo = _getExpectedReturnDate(borrowing);
      final now = DateTime.now();

      // Check if book is returned (status "2", or has actual return date)
      bool isReturned =
          (status == "2" || status == 2) || (tanggalKembali != null);

      switch (_filterStatus) {
        case 'dipinjam':
          return !isReturned && (status == "1" || status == 1);
        case 'dikembalikan':
          return isReturned;
        case 'terlambat':
          // Status "3" langsung dianggap terlambat
          if (status == "3" || status == 3) return true;
          if (isReturned) return false;
          try {
            if (tanggalJatuhTempo != null) {
              final jatuhTempo = DateTime.parse(tanggalJatuhTempo);
              return now.isAfter(jatuhTempo);
            }
            return false;
          } catch (e) {
            return false;
          }
        default:
          return true;
      }
    }).toList();
  }

  String _getStatusText(dynamic borrowing) {
    // Check API status field first
    final status = borrowing['status'];
    final tanggalKembali = _getActualReturnDate(borrowing);
    final tanggalJatuhTempo = _getExpectedReturnDate(borrowing);

    // Status mapping baru:
    // "1" = Dipinjam (Borrowed)
    // "2" = Dikembalikan (Returned)
    // "3" = Terlambat (Overdue)

    if (status == "2" || status == 2) {
      return 'Dikembalikan';
    }

    if (status == "3" || status == 3) {
      return 'Terlambat';
    }

    // If there's an actual return date, book is returned
    if (tanggalKembali != null) {
      return 'Dikembalikan';
    }

    // For status "1" (currently borrowed), check if overdue
    if (status == "1" || status == 1) {
      try {
        if (tanggalJatuhTempo != null) {
          final jatuhTempo = DateTime.parse(tanggalJatuhTempo);
          final now = DateTime.now();

          if (now.isAfter(jatuhTempo)) {
            return 'Terlambat';
          } else {
            return 'Dipinjam';
          }
        } else {
          return 'Dipinjam';
        }
      } catch (e) {
        return 'Dipinjam';
      }
    }

    // Fallback: check due date if no clear status
    try {
      if (tanggalJatuhTempo != null) {
        final jatuhTempo = DateTime.parse(tanggalJatuhTempo);
        final now = DateTime.now();

        if (now.isAfter(jatuhTempo)) {
          return 'Terlambat';
        } else {
          return 'Dipinjam';
        }
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

  String? _getExpectedReturnDate(dynamic borrowing) {
    // Debug: print available fields (hanya untuk beberapa record pertama)
    if (kDebugMode && _borrowings.indexOf(borrowing) < 2) {
      print('=== DEBUG BORROWING ${borrowing['id']} ===');
      print('Available fields: ${borrowing.keys.toList()}');
      print('tanggal_pengembalian: ${borrowing['tanggal_pengembalian']}');
      print('expected_return_date: ${borrowing['expected_return_date']}');
      print('due_date: ${borrowing['due_date']}');
      print('tanggal_jatuh_tempo: ${borrowing['tanggal_jatuh_tempo']}');
      print('original_due_date: ${borrowing['original_due_date']}');
      print('actual_return_date: ${borrowing['actual_return_date']}');
      print('tanggal_kembali: ${borrowing['tanggal_kembali']}');
      print(
          'tanggal_pengembalian_aktual: ${borrowing['tanggal_pengembalian_aktual']}');
      print('returned_at: ${borrowing['returned_at']}');
      print('status: ${borrowing['status']}');
      print('==============================');
    }

    // Prioritas field untuk tanggal jatuh tempo:
    // 1. original_due_date (preserved from before return)
    // 2. expected_return_date (paling reliable)
    // 3. due_date
    // 4. tanggal_jatuh_tempo
    // 5. tanggal_pengembalian (fallback, tapi bisa berubah saat pengembalian)
    return borrowing['original_due_date'] ??
        borrowing['expected_return_date'] ??
        borrowing['due_date'] ??
        borrowing['tanggal_jatuh_tempo'] ??
        borrowing['tanggal_pengembalian'];
  }

  String? _getActualReturnDate(dynamic borrowing) {
    // Try multiple possible fields for actual return date (expanded list)
    final actualReturnDate = borrowing['actual_return_date'] ??
        borrowing['tanggal_kembali'] ??
        borrowing['returned_at'] ??
        borrowing['tanggal_pengembalian_aktual'] ??
        borrowing['tanggal_dikembalikan'] ??
        borrowing['return_date'] ??
        borrowing['date_returned'] ??
        borrowing['tanggal_return'] ??
        borrowing['actual_date'] ??
        borrowing['returned_date'] ??
        borrowing['return_datetime'] ??
        borrowing['updated_at']; // As last resort, use when it was last updated

    // Special case: If status is "2" (returned) and no explicit return date field is found,
    // use tanggal_pengembalian as it might have been updated with actual return date
    if (actualReturnDate == null &&
        (borrowing['status'] == "2" || borrowing['status'] == 2)) {
      final fallbackDate = borrowing['tanggal_pengembalian'];
      if (kDebugMode && _borrowings.indexOf(borrowing) < 2) {
        print(
            'Using tanggal_pengembalian as fallback for returned book: $fallbackDate');
      }
      return fallbackDate;
    }

    // Debug: Log ALL date-related fields
    if (kDebugMode && _borrowings.indexOf(borrowing) < 2) {
      print('=== ACTUAL RETURN DATE DEBUG ${borrowing['id']} ===');
      print('All date-related fields in borrowing:');
      borrowing.forEach((key, value) {
        if (key.toString().toLowerCase().contains('date') ||
            key.toString().toLowerCase().contains('tanggal') ||
            key.toString().toLowerCase().contains('return') ||
            key.toString().toLowerCase().contains('kembali') ||
            key.toString().toLowerCase().contains('at')) {
          print('  $key: $value');
        }
      });

      if (actualReturnDate != null) {
        print('Selected return date: $actualReturnDate');
        if (borrowing['actual_return_date'] != null)
          print('From: actual_return_date');
        else if (borrowing['tanggal_kembali'] != null)
          print('From: tanggal_kembali');
        else if (borrowing['returned_at'] != null)
          print('From: returned_at');
        else if (borrowing['tanggal_pengembalian_aktual'] != null)
          print('From: tanggal_pengembalian_aktual');
        else if (borrowing['tanggal_dikembalikan'] != null)
          print('From: tanggal_dikembalikan');
        else if (borrowing['return_date'] != null)
          print('From: return_date');
        else if (borrowing['date_returned'] != null)
          print('From: date_returned');
        else if (borrowing['tanggal_return'] != null)
          print('From: tanggal_return');
        else if (borrowing['actual_date'] != null)
          print('From: actual_date');
        else if (borrowing['returned_date'] != null)
          print('From: returned_date');
        else if (borrowing['return_datetime'] != null)
          print('From: return_datetime');
        else if (borrowing['updated_at'] != null)
          print('From: updated_at (fallback)');
      } else {
        print('No return date found in any field!');
      }
      print('============================================');
    }

    return actualReturnDate;
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
      await _returnBook(borrowing['id']);
    }
  }

  Future<void> _returnBook(int borrowingId) async {
    try {
      // Debug: Log data sebelum pengembalian
      final borrowingBefore = _borrowings
          .firstWhere((b) => b['id'] == borrowingId, orElse: () => null);

      // PRESERVE the original due date before API call
      String? originalDueDate;
      if (borrowingBefore != null) {
        originalDueDate = _getExpectedReturnDate(borrowingBefore);

        if (kDebugMode) {
          print('BEFORE RETURN:');
          print(
              '  tanggal_pengembalian: ${borrowingBefore['tanggal_pengembalian']}');
          print(
              '  expected_return_date: ${borrowingBefore['expected_return_date']}');
          print('  originalDueDate preserved: $originalDueDate');
          print('  status: ${borrowingBefore['status']}');
        }
      }

      final success = await _apiService.returnBook(borrowingId);

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Buku berhasil dikembalikan'),
              backgroundColor: Colors.green,
            ),
          );

          // Refresh data and restore due date if needed
          await _loadBorrowings();

          // RESTORE the original due date after API call corrupts it
          if (originalDueDate != null) {
            final borrowingAfter = _borrowings
                .firstWhere((b) => b['id'] == borrowingId, orElse: () => null);

            if (borrowingAfter != null) {
              // Restore the original due date to prevent status calculation errors
              borrowingAfter['original_due_date'] = originalDueDate;

              // MANUAL FIX: If API didn't set actual return date, set it manually
              if (_getActualReturnDate(borrowingAfter) == null &&
                  (borrowingAfter['status'] == "2" ||
                      borrowingAfter['status'] == 2)) {
                final today = DateTime.now().toIso8601String().split('T')[0];
                borrowingAfter['actual_return_date'] = today;
                borrowingAfter['tanggal_kembali'] = today;
                borrowingAfter['returned_at'] = today;
                if (kDebugMode) {
                  print('MANUALLY SET return date to: $today');
                }
              }

              if (kDebugMode) {
                print('=== COMPLETE BORROWING DATA AFTER RETURN ===');
                print('All available fields: ${borrowingAfter.keys.toList()}');
                print('Full borrowing object: $borrowingAfter');
                print('=== SPECIFIC DATE FIELDS ===');
                print(
                    '  tanggal_pengembalian: ${borrowingAfter['tanggal_pengembalian']}');
                print(
                    '  expected_return_date: ${borrowingAfter['expected_return_date']}');
                print(
                    '  actual_return_date: ${borrowingAfter['actual_return_date']}');
                print(
                    '  tanggal_kembali: ${borrowingAfter['tanggal_kembali']}');
                print('  returned_at: ${borrowingAfter['returned_at']}');
                print(
                    '  tanggal_pengembalian_aktual: ${borrowingAfter['tanggal_pengembalian_aktual']}');
                print(
                    '  tanggal_dikembalikan: ${borrowingAfter['tanggal_dikembalikan']}');
                print('  return_date: ${borrowingAfter['return_date']}');
                print('  created_at: ${borrowingAfter['created_at']}');
                print('  updated_at: ${borrowingAfter['updated_at']}');
                print(
                    '  original_due_date restored: ${borrowingAfter['original_due_date']}');
                print('  status: ${borrowingAfter['status']}');
                print(
                    '  _getActualReturnDate result: ${_getActualReturnDate(borrowingAfter)}');
                print('===============================================');
              }
            }
          }
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
            Text('Buku: ${borrowing['book']?['judul'] ?? 'Unknown'}'),
            Text('Pengarang: ${borrowing['book']?['pengarang'] ?? 'Unknown'}'),
            const SizedBox(height: 8),
            Text('Member: ${borrowing['member']?['name'] ?? 'Unknown'}'),
            const SizedBox(height: 8),
            Text(
                'Tanggal Pinjam: ${_formatDate(borrowing['tanggal_peminjaman'])}'),
            Text(
                'Tanggal Jatuh Tempo: ${_formatDate(_getExpectedReturnDate(borrowing))}'),
            Text(
                'Tanggal Kembali: ${_formatDate(_getActualReturnDate(borrowing))}'),
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
                                  borrowing['book']?['judul'] ?? 'Unknown Book',
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
                                    if (borrowing['actual_return_date'] != null)
                                      Text(
                                          'Dikembalikan: ${_formatDate(_getActualReturnDate(borrowing))}'),
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
                                        if (borrowing['actual_return_date'] ==
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
