import 'package:flutter/material.dart';
import '../../api/api_service.dart';
import '../../models/book.dart';

class BorrowBookScreen extends StatefulWidget {
  final Book book;

  const BorrowBookScreen({Key? key, required this.book}) : super(key: key);

  @override
  _BorrowBookScreenState createState() => _BorrowBookScreenState();
}

class _BorrowBookScreenState extends State<BorrowBookScreen> {
  final ApiService _apiService = ApiService();
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _memberIdController = TextEditingController();
  final TextEditingController _borrowDateController = TextEditingController();
  final TextEditingController _returnDateController = TextEditingController();

  bool _isLoading = false;
  DateTime? _selectedBorrowDate;
  DateTime? _selectedReturnDate;

  @override
  void initState() {
    super.initState();
    // Set default dates
    _selectedBorrowDate = DateTime.now();
    _selectedReturnDate =
        DateTime.now().add(const Duration(days: 14)); // 2 weeks default

    _borrowDateController.text = _formatDate(_selectedBorrowDate!);
    _returnDateController.text = _formatDate(_selectedReturnDate!);

    // Set default member ID (placeholder - in real app, get from logged in user)
    _memberIdController.text = '1'; // Default member ID
  }

  @override
  void dispose() {
    _memberIdController.dispose();
    _borrowDateController.dispose();
    _returnDateController.dispose();
    super.dispose();
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  Future<void> _selectDate(BuildContext context, bool isBorrowDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isBorrowDate ? _selectedBorrowDate! : _selectedReturnDate!,
      firstDate:
          isBorrowDate ? DateTime.now() : _selectedBorrowDate ?? DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (picked != null) {
      setState(() {
        if (isBorrowDate) {
          _selectedBorrowDate = picked;
          _borrowDateController.text = _formatDate(picked);

          // Auto-adjust return date if it's before borrow date
          if (_selectedReturnDate!.isBefore(picked)) {
            _selectedReturnDate = picked.add(const Duration(days: 14));
            _returnDateController.text = _formatDate(_selectedReturnDate!);
          }
        } else {
          _selectedReturnDate = picked;
          _returnDateController.text = _formatDate(picked);
        }
      });
    }
  }

  Future<void> _borrowBook() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      final int memberId = int.parse(_memberIdController.text);
      final String borrowDate = _formatDate(_selectedBorrowDate!);
      final String returnDate = _formatDate(_selectedReturnDate!);

      final success = await _apiService.borrowBook(
        widget.book.id,
        memberId,
        borrowDate,
        returnDate,
      );

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Berhasil meminjam buku "${widget.book.judul}"'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context, true); // Return true to indicate success
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Gagal meminjam buku. Silakan coba lagi.'),
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
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pinjam Buku'),
        backgroundColor: Colors.blue.shade600,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Book Information Card
              Card(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Informasi Buku',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Container(
                            width: 80,
                            height: 100,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade300,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: widget.book.path != null
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.network(
                                      widget.book.path!,
                                      fit: BoxFit.cover,
                                      errorBuilder:
                                          (context, error, stackTrace) =>
                                              const Icon(Icons.book, size: 40),
                                    ),
                                  )
                                : const Icon(Icons.book, size: 40),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.book.judul,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text('Pengarang: ${widget.book.pengarang}'),
                                Text('Penerbit: ${widget.book.penerbit}'),
                                Text('Tahun: ${widget.book.tahun}'),
                                Text('Kategori: ${widget.book.category.name}'),
                                Text(
                                  'Stok: ${widget.book.stok}',
                                  style: TextStyle(
                                    color: widget.book.stok > 0
                                        ? Colors.green
                                        : Colors.red,
                                    fontWeight: FontWeight.bold,
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
              ),

              const SizedBox(height: 24),

              // Borrowing Form
              Card(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Informasi Peminjaman',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Member ID Field
                      TextFormField(
                        controller: _memberIdController,
                        decoration: const InputDecoration(
                          labelText: 'ID Member',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.person),
                          helperText: 'Masukkan ID Member yang akan meminjam',
                        ),
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'ID Member tidak boleh kosong';
                          }
                          if (int.tryParse(value) == null) {
                            return 'ID Member harus berupa angka';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Borrow Date Field
                      TextFormField(
                        controller: _borrowDateController,
                        decoration: const InputDecoration(
                          labelText: 'Tanggal Pinjam',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.calendar_today),
                          suffixIcon: Icon(Icons.arrow_drop_down),
                        ),
                        readOnly: true,
                        onTap: () => _selectDate(context, true),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Tanggal pinjam tidak boleh kosong';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Return Date Field
                      TextFormField(
                        controller: _returnDateController,
                        decoration: const InputDecoration(
                          labelText: 'Tanggal Kembali',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.calendar_today),
                          suffixIcon: Icon(Icons.arrow_drop_down),
                          helperText:
                              'Tanggal kembali harus setelah tanggal pinjam',
                        ),
                        readOnly: true,
                        onTap: () => _selectDate(context, false),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Tanggal kembali tidak boleh kosong';
                          }
                          if (_selectedReturnDate != null &&
                              _selectedBorrowDate != null &&
                              _selectedReturnDate!
                                  .isBefore(_selectedBorrowDate!)) {
                            return 'Tanggal kembali harus setelah tanggal pinjam';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 24),

                      // Duration Info
                      if (_selectedBorrowDate != null &&
                          _selectedReturnDate != null)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.blue.shade200),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.info, color: Colors.blue.shade600),
                              const SizedBox(width: 8),
                              Text(
                                'Durasi pinjam: ${_selectedReturnDate!.difference(_selectedBorrowDate!).inDays} hari',
                                style: TextStyle(
                                  color: Colors.blue.shade700,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              const Spacer(),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed:
                          _isLoading ? null : () => Navigator.pop(context),
                      child: const Text('Batal'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isLoading || widget.book.stok <= 0
                          ? null
                          : _borrowBook,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade600,
                        foregroundColor: Colors.white,
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Text('Pinjam Buku'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
