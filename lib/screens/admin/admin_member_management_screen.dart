import 'package:flutter/material.dart';
import '../../api/api_service.dart';
import '../../models/user.dart';

class AdminMemberManagementScreen extends StatefulWidget {
  const AdminMemberManagementScreen({Key? key}) : super(key: key);

  @override
  _AdminMemberManagementScreenState createState() =>
      _AdminMemberManagementScreenState();
}

class _AdminMemberManagementScreenState
    extends State<AdminMemberManagementScreen> {
  final ApiService _apiService = ApiService();
  List<User> _allMembers = [];
  List<User> _displayedMembers = [];
  bool _isLoading = false;
  String _searchQuery = '';

  // Pagination variables
  int _currentPage = 1;
  int _itemsPerPage = 5;
  int _totalPages = 1;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadMembers();
    });
  }

  Future<void> _loadMembers() async {
    setState(() => _isLoading = true);
    try {
      // Get all members from API
      final members = await _apiService.getMembers();
      setState(() {
        _allMembers = members;
        _applySearchAndPagination();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading members: $e')),
        );
      }
      // Fallback to empty list if API call fails
      setState(() {
        _allMembers = [];
        _displayedMembers = [];
        _totalPages = 1;
        _currentPage = 1;
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _applySearchAndPagination() {
    List<User> filteredMembers = _searchQuery.isEmpty
        ? _allMembers
        : _allMembers
            .where((member) =>
                member.name.toLowerCase().contains(_searchQuery.toLowerCase()))
            .toList();

    _totalPages = (filteredMembers.length / _itemsPerPage).ceil();
    if (_totalPages == 0) _totalPages = 1;

    // Ensure current page is valid
    if (_currentPage > _totalPages) _currentPage = _totalPages;
    if (_currentPage < 1) _currentPage = 1;

    int startIndex = (_currentPage - 1) * _itemsPerPage;
    int endIndex = startIndex + _itemsPerPage;
    if (endIndex > filteredMembers.length) endIndex = filteredMembers.length;

    _displayedMembers = filteredMembers.sublist(
        startIndex, endIndex.clamp(0, filteredMembers.length));
  }

  void _goToNextPage() {
    if (_currentPage < _totalPages) {
      setState(() {
        _currentPage++;
        _applySearchAndPagination();
      });
    }
  }

  void _goToPreviousPage() {
    if (_currentPage > 1) {
      setState(() {
        _currentPage--;
        _applySearchAndPagination();
      });
    }
  }

  void _goToPage(int page) {
    if (page >= 1 && page <= _totalPages) {
      setState(() {
        _currentPage = page;
        _applySearchAndPagination();
      });
    }
  }

  void _showMemberDetails(User member) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Detail Member: ${member.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Email: ${member.email}'),
            const SizedBox(height: 8),
            Text('Username: ${member.username}'),
            const SizedBox(height: 8),
            Text('Role: ${member.role}'),
            const SizedBox(height: 8),
            if (member.createdAt != null)
              Text(
                  'Joined: ${member.createdAt!.day}/${member.createdAt!.month}/${member.createdAt!.year}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Tutup'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            onPressed: () {
              Navigator.pop(context);
              _showChangeRoleDialog(member);
            },
            child: const Text('Ubah Role'),
          ),
        ],
      ),
    );
  }

  void _showChangeRoleDialog(User member) {
    String selectedRole = member.role;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text('Ubah Role: ${member.name}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Role saat ini: ${member.role}'),
              const SizedBox(height: 16),
              const Text('Pilih role baru:'),
              const SizedBox(height: 8),
              RadioListTile<String>(
                title: const Text('Member'),
                subtitle: const Text('Akses terbatas untuk peminjaman buku'),
                value: 'member',
                groupValue: selectedRole,
                onChanged: (value) {
                  setState(() {
                    selectedRole = value!;
                  });
                },
              ),
              RadioListTile<String>(
                title: const Text('Admin'),
                subtitle: const Text('Akses penuh untuk mengelola sistem'),
                value: 'admin',
                groupValue: selectedRole,
                onChanged: (value) {
                  setState(() {
                    selectedRole = value!;
                  });
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              onPressed: selectedRole == member.role
                  ? null
                  : () async {
                      try {
                        Navigator.pop(context);
                        // Show loading indicator
                        showDialog(
                          context: context,
                          barrierDismissible: false,
                          builder: (context) => const AlertDialog(
                            content: Row(
                              children: [
                                CircularProgressIndicator(),
                                SizedBox(width: 16),
                                Text('Mengubah role...'),
                              ],
                            ),
                          ),
                        );

                        final success = await _apiService.updateUserRole(
                            member.id, selectedRole);

                        // Check if widget is still mounted before using context
                        if (mounted) {
                          Navigator.pop(context); // Close loading dialog

                          if (success) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                    'Role ${member.name} berhasil diubah menjadi $selectedRole'),
                                backgroundColor: Colors.green,
                              ),
                            );
                            _loadMembers(); // Reload data
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                    'Fitur ubah role belum tersedia di backend API. Backend perlu menambahkan endpoint PUT untuk update user role.'),
                                backgroundColor: Colors.orange,
                                duration: Duration(seconds: 4),
                              ),
                            );
                          }
                        }
                      } catch (e) {
                        // Check if widget is still mounted before using context
                        if (mounted) {
                          Navigator.pop(context); // Close loading dialog
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                  'Fitur ubah role belum tersedia di backend API. Silakan hubungi pengembang untuk menambahkan endpoint yang diperlukan.'),
                              backgroundColor: Colors.orange,
                              duration: Duration(seconds: 4),
                            ),
                          );
                        }
                      }
                    },
              child: const Text('Ubah Role'),
            ),
          ],
        ),
      ),
    );
  }

  void _deleteMember(User member) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Member'),
        content: Text(
            'Apakah Anda yakin ingin menghapus member "${member.name}"?\n\nTindakan ini tidak dapat dibatalkan.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              try {
                Navigator.pop(context);
                // Show loading indicator
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) => const AlertDialog(
                    content: Row(
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(width: 16),
                        Text('Menghapus member...'),
                      ],
                    ),
                  ),
                );

                final success = await _apiService.deleteUser(member.id);

                // Check if widget is still mounted before using context
                if (mounted) {
                  Navigator.pop(context); // Close loading dialog

                  if (success) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Member ${member.name} berhasil dihapus'),
                        backgroundColor: Colors.green,
                      ),
                    );
                    _loadMembers(); // Reload data
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                            'Fitur hapus member belum tersedia di backend API. Backend perlu menambahkan endpoint DELETE untuk user.'),
                        backgroundColor: Colors.orange,
                        duration: Duration(seconds: 4),
                      ),
                    );
                  }
                }
              } catch (e) {
                // Check if widget is still mounted before using context
                if (mounted) {
                  Navigator.pop(context); // Close loading dialog
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                          'Fitur hapus member belum tersedia di backend API. Silakan hubungi pengembang untuk menambahkan endpoint yang diperlukan.'),
                      backgroundColor: Colors.orange,
                      duration: Duration(seconds: 4),
                    ),
                  );
                }
              }
            },
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manajemen Member'),
        backgroundColor: Colors.red.shade600,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadMembers,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Container(
            padding: const EdgeInsets.all(16),
            child: TextField(
              decoration: const InputDecoration(
                labelText: 'Cari member...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                  _currentPage = 1; // Reset to first page when searching
                  _applySearchAndPagination();
                });
              },
            ),
          ),

          // Members List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _displayedMembers.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.people, size: 64, color: Colors.grey),
                            SizedBox(height: 16),
                            Text(
                              'Tidak ada member ditemukan',
                              style:
                                  TextStyle(fontSize: 16, color: Colors.grey),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Coba kata kunci pencarian lain',
                              style:
                                  TextStyle(fontSize: 14, color: Colors.grey),
                            ),
                          ],
                        ),
                      )
                    : Column(
                        children: [
                          // Member List
                          Expanded(
                            child: ListView.builder(
                              itemCount: _displayedMembers.length,
                              itemBuilder: (context, index) {
                                final member = _displayedMembers[index];

                                return Card(
                                  margin: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 8),
                                  child: ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor: member.isAdmin
                                          ? Colors.red
                                          : Colors.blue,
                                      child: Text(
                                        member.name.isNotEmpty
                                            ? member.name[0].toUpperCase()
                                            : 'U',
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                    title: Text(
                                      member.name,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold),
                                    ),
                                    subtitle: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text('Email: ${member.email}'),
                                        Text('Username: ${member.username}'),
                                        Text('Role: ${member.role}'),
                                        Text(
                                          'Type: ${member.isAdmin ? "Admin" : member.isMember ? "Member" : "Visitor"}',
                                          style: TextStyle(
                                            color: member.isAdmin
                                                ? Colors.red
                                                : Colors.blue,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.info,
                                              color: Colors.blue),
                                          onPressed: () =>
                                              _showMemberDetails(member),
                                        ),
                                        if (!member.isAdmin)
                                          IconButton(
                                            icon: const Icon(Icons.delete,
                                                color: Colors.red),
                                            onPressed: () =>
                                                _deleteMember(member),
                                          ),
                                      ],
                                    ),
                                    isThreeLine: true,
                                  ),
                                );
                              },
                            ),
                          ),

                          // Pagination Controls
                          if (_allMembers.isNotEmpty)
                            _buildPaginationControls(),
                        ],
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaginationControls() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        border: Border(top: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Column(
        children: [
          // Page info
          Text(
            'Halaman $_currentPage dari $_totalPages (${_allMembers.length} total member)',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),

          // Navigation buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Previous button
              ElevatedButton.icon(
                onPressed: _currentPage > 1 ? _goToPreviousPage : null,
                icon: const Icon(Icons.chevron_left),
                label: const Text('Previous'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey.shade300,
                  disabledForegroundColor: Colors.grey.shade600,
                ),
              ),

              // Page numbers
              Row(
                children: _buildPageNumbers(),
              ),

              // Next button
              ElevatedButton.icon(
                onPressed: _currentPage < _totalPages ? _goToNextPage : null,
                icon: const Icon(Icons.chevron_right),
                label: const Text('Next'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey.shade300,
                  disabledForegroundColor: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> _buildPageNumbers() {
    List<Widget> pageNumbers = [];

    // Show page numbers around current page
    int start = (_currentPage - 2).clamp(1, _totalPages);
    int end = (_currentPage + 2).clamp(1, _totalPages);

    // Always show first page
    if (start > 1) {
      pageNumbers.add(_buildPageButton(1));
      if (start > 2) {
        pageNumbers.add(const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4),
          child: Text('...', style: TextStyle(color: Colors.grey)),
        ));
      }
    }

    // Show page numbers in range
    for (int i = start; i <= end; i++) {
      pageNumbers.add(_buildPageButton(i));
    }

    // Always show last page
    if (end < _totalPages) {
      if (end < _totalPages - 1) {
        pageNumbers.add(const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4),
          child: Text('...', style: TextStyle(color: Colors.grey)),
        ));
      }
      pageNumbers.add(_buildPageButton(_totalPages));
    }

    return pageNumbers;
  }

  Widget _buildPageButton(int pageNumber) {
    bool isCurrentPage = pageNumber == _currentPage;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: GestureDetector(
        onTap: () => _goToPage(pageNumber),
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: isCurrentPage ? Colors.blue : Colors.transparent,
            border: Border.all(
              color: isCurrentPage ? Colors.blue : Colors.grey.shade400,
            ),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Center(
            child: Text(
              pageNumber.toString(),
              style: TextStyle(
                color: isCurrentPage ? Colors.white : Colors.grey.shade700,
                fontWeight: isCurrentPage ? FontWeight.bold : FontWeight.normal,
                fontSize: 14,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
