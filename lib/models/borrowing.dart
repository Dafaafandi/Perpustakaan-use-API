import 'package:perpus_app/models/book.dart';
import 'package:perpus_app/models/user.dart';

class Borrowing {
  final int id;
  final int bookId;
  final int memberId;
  final DateTime borrowDate;
  final DateTime expectedReturnDate;
  final DateTime? actualReturnDate;
  final String status; // 'borrowed', 'returned', 'overdue'
  final Book? book;
  final User? member;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Borrowing({
    required this.id,
    required this.bookId,
    required this.memberId,
    required this.borrowDate,
    required this.expectedReturnDate,
    this.actualReturnDate,
    required this.status,
    this.book,
    this.member,
    this.createdAt,
    this.updatedAt,
  });

  factory Borrowing.fromJson(Map<String, dynamic> json) {
    return Borrowing(
      id: _parseId(json['id']),
      bookId: _parseId(json['book_id'] ?? json['bookId']),
      memberId: _parseId(json['member_id'] ?? json['memberId']),
      borrowDate:
          _parseDateTime(json['tanggal_peminjaman'] ?? json['borrow_date']) ??
              DateTime.now(),
      expectedReturnDate: _parseDateTime(
              json['tanggal_pengembalian'] ?? json['expected_return_date']) ??
          DateTime.now(),
      actualReturnDate:
          _parseDateTime(json['actual_return_date'] ?? json['returned_at']),
      status: _parseStatus(json),
      book: json['book'] != null ? Book.fromJson(json['book']) : null,
      member: json['member'] != null ? User.fromJson(json['member']) : null,
      createdAt: _parseDateTime(json['created_at']),
      updatedAt: _parseDateTime(json['updated_at']),
    );
  }

  // Helper method to parse ID safely
  static int _parseId(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is String) {
      final parsed = int.tryParse(value);
      return parsed ?? 0;
    }
    return 0;
  }

  // Helper method to parse DateTime
  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is String) {
      try {
        return DateTime.parse(value);
      } catch (e) {
        // Try alternative date format
        try {
          final parts = value.split('-');
          if (parts.length == 3) {
            return DateTime(
              int.parse(parts[0]),
              int.parse(parts[1]),
              int.parse(parts[2]),
            );
          }
        } catch (e) {
          return null;
        }
        return null;
      }
    }
    return null;
  }

  // Helper method to parse status
  static String _parseStatus(Map<String, dynamic> json) {
    // Try different possible status field names
    if (json['status'] != null) {
      return json['status'].toString().toLowerCase();
    }

    // Determine status based on return date
    if (json['actual_return_date'] != null || json['returned_at'] != null) {
      return 'returned';
    }

    // Check if overdue
    final returnDate = _parseDateTime(
        json['tanggal_pengembalian'] ?? json['expected_return_date']);
    if (returnDate != null && returnDate.isBefore(DateTime.now())) {
      return 'overdue';
    }

    return 'borrowed';
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'book_id': bookId,
      'member_id': memberId,
      'tanggal_peminjaman': borrowDate.toIso8601String(),
      'tanggal_pengembalian': expectedReturnDate.toIso8601String(),
      'actual_return_date': actualReturnDate?.toIso8601String(),
      'status': status,
    };
  }

  // Convert to form data for API submission
  Map<String, String> toFormData() {
    return {
      'tanggal_peminjaman': _formatDate(borrowDate),
      'tanggal_pengembalian': _formatDate(expectedReturnDate),
      if (actualReturnDate != null)
        'actual_return_date': _formatDate(actualReturnDate!),
    };
  }

  // Helper method to format date for API
  static String _formatDate(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  bool get isOverdue {
    if (actualReturnDate != null) return false; // Already returned
    return expectedReturnDate.isBefore(DateTime.now());
  }

  bool get isReturned {
    return actualReturnDate != null || status.toLowerCase() == 'returned';
  }

  int get daysOverdue {
    if (!isOverdue) return 0;
    return DateTime.now().difference(expectedReturnDate).inDays;
  }

  Borrowing copyWith({
    int? id,
    int? bookId,
    int? memberId,
    DateTime? borrowDate,
    DateTime? expectedReturnDate,
    DateTime? actualReturnDate,
    String? status,
    Book? book,
    User? member,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Borrowing(
      id: id ?? this.id,
      bookId: bookId ?? this.bookId,
      memberId: memberId ?? this.memberId,
      borrowDate: borrowDate ?? this.borrowDate,
      expectedReturnDate: expectedReturnDate ?? this.expectedReturnDate,
      actualReturnDate: actualReturnDate ?? this.actualReturnDate,
      status: status ?? this.status,
      book: book ?? this.book,
      member: member ?? this.member,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'Borrowing(id: $id, bookId: $bookId, memberId: $memberId, status: $status)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Borrowing && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
