# Perpustakaan Flutter App - API Conversion

## Overview

Aplikasi perpustakaan Flutter ini telah dikonversi dari menggunakan Laravel localhost menjadi menggunakan API eksternal dari `http://perpus-api.mamorasoft.com/api`.

## Fitur Utama yang Dikonversi

### 1. Authentication System

- **Base URL**: `http://perpus-api.mamorasoft.com/api`
- **Login Endpoint**: `/login`
- **Format**: `multipart/form-data`
- **Default Credentials**:
  - Username: `Admin123`
  - Password: `12345678`

### 2. Book Management (CRUD)

- **List Books**: `GET /buku`
- **Create Book**: `POST /buku` (multipart/form-data)
- **Update Book**: `PUT /buku/{id}` (multipart/form-data)
- **Delete Book**: `DELETE /buku/{id}`

### 3. Category Management (CRUD)

- **List Categories**: `GET /kategori`
- **Create Category**: `POST /kategori` (form-urlencoded)
- **Update Category**: `PUT /kategori/{id}` (form-urlencoded)
- **Delete Category**: `DELETE /kategori/{id}`

### 4. Borrowing Management (CRUD)

- **List Borrowings**: `GET /peminjaman`
- **Create Borrowing**: `POST /peminjaman` (multipart/form-data)
- **Update Borrowing**: `PUT /peminjaman/{id}` (multipart/form-data)
- **Delete Borrowing**: `DELETE /peminjaman/{id}`

## Architecture Changes

### 1. New Service Layer

- **File**: `lib/services/library_api_service.dart`
- **Purpose**: Menggantikan direct API calls dengan service yang terpusat
- **Features**: Authentication, CRUD operations, error handling

### 2. Enhanced Models

- **Book Model**: Enhanced dengan safe parsing dan helper methods
- **Category Model**: Updated untuk field `nama_kategori`
- **Borrowing Model**: Model baru untuk peminjaman
- **API Response Models**: Enhanced error handling

### 3. Provider State Management

- **AuthProvider**: Login/logout state management
- **BookProvider**: Book CRUD operations
- **CategoryProvider**: Category management
- **BorrowingProvider**: Borrowing operations

### 4. Updated Main App

- **MultiProvider**: Setup untuk semua providers
- **Theme**: Consistent indigo theme
- **Navigation**: Updated routing

## File Changes

### Core Files Modified:

1. `lib/main.dart` - Provider setup
2. `lib/services/library_api_service.dart` - New API service
3. `lib/models/book.dart` - Enhanced model
4. `lib/models/category.dart` - Enhanced model
5. `lib/models/borrowing.dart` - New model
6. `lib/providers/auth_provider.dart` - New provider
7. `lib/providers/book_provider.dart` - New provider
8. `lib/providers/category_provider.dart` - New provider
9. `lib/providers/borrow_provider.dart` - New provider
10. `lib/screens/auth/login_screen.dart` - Updated with provider

### Test Utilities:

- `lib/screens/api_test_screen.dart` - API testing screen

## How to Run

### Prerequisites:

```bash
flutter doctor
```

### Installation:

```bash
cd "Perpustakaan use api"
flutter clean
flutter pub get
```

### Run on Windows:

```bash
flutter run -d windows
```

### Run on Android:

```bash
flutter run -d <device_id>
```

## Testing the Integration

### 1. Login Test

- Open the app
- Use credentials: `Admin123` / `12345678`
- Should redirect to dashboard

### 2. API Test Screen

- Navigate to API test screen (if implemented)
- Test each endpoint individually
- Check error handling

### 3. CRUD Operations

- Test book creation/editing/deletion
- Test category management
- Test borrowing operations

## API Response Format

### Success Response:

```json
{
  "success": true,
  "data": {...},
  "message": "Operation successful"
}
```

### Error Response:

```json
{
  "success": false,
  "error": "Error message",
  "message": "Detailed error description"
}
```

## Known Issues & Warnings

### 1. File Picker Warnings

- Warning tentang `file_picker` plugin implementation
- **Status**: Non-critical, fungsi tetap berjalan
- **Impact**: Tidak mempengaruhi operasi utama

### 2. Deprecated Methods

- `withOpacity()` method deprecated
- **Fix**: Akan diganti dengan `.withValues()` di update selanjutnya

### 3. Build Context Warnings

- `use_build_context_synchronously` warnings
- **Status**: Non-critical untuk development
- **Impact**: Perlu mounted checks di production

## Security Considerations

### 1. Authentication

- Bearer token disimpan di SharedPreferences
- Auto-logout jika token expired
- Secure storage untuk credentials

### 2. API Calls

- HTTPS/SSL untuk production
- Request timeout handling
- Error logging tanpa sensitive data

## Future Enhancements

### 1. Planned Features

- [ ] Export to PDF functionality
- [ ] Import from Excel
- [ ] Push notifications
- [ ] Offline mode
- [ ] File upload progress indicator

### 2. Code Improvements

- [ ] Fix deprecated methods
- [ ] Add proper error logging
- [ ] Implement unit tests
- [ ] Add integration tests

## Troubleshooting

### Build Issues:

```bash
flutter clean
flutter pub get
flutter build windows
```

### API Connection Issues:

1. Check internet connection
2. Verify API base URL: `http://perpus-api.mamorasoft.com/api`
3. Check API server status
4. Verify credentials

### Debug Mode:

```bash
flutter run --debug -d windows
```

## Development Team Notes

### Code Standards:

- Follow Flutter/Dart conventions
- Use Provider for state management
- Implement proper error handling
- Add comments for complex logic

### Git Workflow:

- Create feature branches
- Test before merging
- Document API changes
- Update this README when adding features

---

**Last Updated**: December 2024  
**API Version**: v1  
**Flutter Version**: 3.x  
**Author**: GitHub Copilot Assistant
