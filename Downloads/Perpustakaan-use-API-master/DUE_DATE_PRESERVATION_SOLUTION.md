# Due Date Preservation Solution

## Problem

The backend API has a design flaw where the return operation overwrites the `tanggal_pengembalian` field (due date) with the actual return date, causing incorrect "Terlambat" (overdue) status calculations for books returned on time.

## Root Cause

When calling `/peminjaman/book/{id}/return`, the API changes:

- `tanggal_pengembalian: "2025-07-19"` (original due date)
- `status: "1"` (borrowed)

To:

- `tanggal_pengembalian: "2025-07-17"` (return date overwrites due date!)
- `status: "3"` (returned)

This makes the system think the book was due on the return date, causing status calculation errors.

## Solution Implementation

### 1. API Service Changes

- **api_service.dart**: Modified `returnBook()` to only send status parameter, avoiding date field conflicts
- **library_api_service.dart**: Applied same changes for consistency

### 2. Client-Side Due Date Preservation

- **borrowed_books_screen.dart**:
  - Store original due date before API call
  - Restore preserved due date to `original_due_date` field after API call
  - Updated `_getExpectedReturnDate()` to prioritize preserved due date

### 3. Model Enhancement

- **borrowing.dart**: Enhanced `fromJson()` to handle `original_due_date` field with highest priority

## Field Priority Order

The system now uses this priority for determining due dates:

1. `original_due_date` (preserved from before return operation)
2. `expected_return_date`
3. `due_date`
4. `tanggal_jatuh_tempo`
5. `tanggal_pengembalian` (fallback, can be corrupted)

## Testing

To test this solution:

1. Borrow a book with due date 2025-07-19
2. Return the book on 2025-07-17 (before due date)
3. Verify the book shows as "Dikembalikan" not "Terlambat"
4. Check debug logs to confirm due date preservation

## Debug Logging

Enhanced logging shows:

- BEFORE RETURN: Original due date and status
- AFTER RETURN: Corrupted API response and restored due date
- Field availability and priority resolution

This solution works around the backend limitation without requiring API changes.
