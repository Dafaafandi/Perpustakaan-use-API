# Perpustakaan App - API Integration Update

## Perubahan Utama

Aplikasi Flutter Perpustakaan telah diperbarui untuk menggunakan API endpoint dari `http://perpus-api.mamorasoft.com/api` menggantikan Laravel localhost yang sebelumnya digunakan.

## API Endpoints yang Digunakan

### Authentication

- **POST** `/login` - Login pengguna
- **POST** `/register` - Registrasi pengguna baru

### Books Management

- **GET** `/book/all` - Mengambil semua buku dengan pagination
- **GET** `/book/{id}` - Mengambil detail buku berdasarkan ID
- **POST** `/book/create` - Menambah buku baru (form-data)
- **POST** `/book/{id}/update` - Update buku (form-data)
- **DELETE** `/book/{id}/delete` - Hapus buku
- **GET** `/book/export/pdf` - Export buku ke PDF
- **GET** `/book/export/excel` - Export buku ke Excel
- **POST** `/book/import/excel` - Import buku dari Excel
- **GET** `/book/download/template` - Download template import

### Categories Management

- **GET** `/category/all/all` - Mengambil semua kategori
- **GET** `/category/{id}` - Mengambil detail kategori
- **POST** `/category/create` - Menambah kategori baru (form-data)
- **POST** `/category/update/{id}` - Update kategori (form-data)
- **DELETE** `/category/{id}/delete` - Hapus kategori

### Borrowing (Peminjaman)

- **GET** `/peminjaman` - Mengambil data peminjaman dengan pagination
- **GET** `/peminjaman/all` - Mengambil semua data peminjaman
- **GET** `/peminjaman/show?id={id}` - Detail peminjaman
- **POST** `/peminjaman/book/{bookId}/member/{memberId}` - Buat peminjaman baru
- **POST** `/peminjaman/book/{id}/return` - Kembalikan buku

## Struktur File yang Diperbarui

### Models

- **`lib/models/book.dart`** - Model buku dengan field tambahan dan parsing yang lebih robust
- **`lib/models/category.dart`** - Model kategori dengan field tambahan
- **`lib/models/borrowing.dart`** - Model peminjaman (BARU)
- **`lib/models/user.dart`** - Model pengguna (sudah ada)

### Services

- **`lib/services/library_api_service.dart`** - Service API utama untuk komunikasi dengan endpoint baru
- **`lib/api/api_service.dart`** - Service API lama (diperbarui untuk kompatibilitas)

### Providers (State Management)

- **`lib/providers/auth_provider.dart`** - Provider untuk authentication
- **`lib/providers/book_provider.dart`** - Provider untuk manajemen buku
- **`lib/providers/category_provider.dart`** - Provider untuk manajemen kategori
- **`lib/providers/borrow_provider.dart`** - Provider untuk manajemen peminjaman

### Screens

- **`lib/screens/auth/login_screen.dart`** - Screen login yang diperbarui menggunakan Provider
- **`lib/screens/developer/api_test_screen.dart`** - Screen untuk testing API (BARU)

### Main App

- **`lib/main.dart`** - File utama dengan registrasi semua providers

## Fitur API yang Diintegrasikan

### 1. Authentication

- Login dengan username dan password menggunakan form-data
- Bearer token authentication untuk request selanjutnya
- Automatic token management dengan SharedPreferences

### 2. Books Management

- CRUD lengkap untuk buku
- Export ke PDF dan Excel
- Import dari Excel dengan template
- Search dan filter buku
- Pagination support

### 3. Categories Management

- CRUD lengkap untuk kategori
- Search kategori
- Relasi kategori dengan buku

### 4. Borrowing System

- Buat peminjaman baru
- Kembalikan buku
- Tracking status peminjaman
- History peminjaman

## Penggunaan

### 1. Authentication

```dart
final authProvider = Provider.of<AuthProvider>(context, listen: false);
final success = await authProvider.login('username', 'password');
```

### 2. Books

```dart
final bookProvider = Provider.of<BookProvider>(context, listen: false);
await bookProvider.fetchAllBooks();
final books = bookProvider.books;
```

### 3. Categories

```dart
final categoryProvider = Provider.of<CategoryProvider>(context, listen: false);
await categoryProvider.fetchCategories();
final categories = categoryProvider.categories;
```

### 4. Borrowing

```dart
final borrowProvider = Provider.of<BorrowingProvider>(context, listen: false);
await borrowProvider.createBorrowing(bookId, memberId, borrowDate, returnDate);
```

## Testing

Gunakan `ApiTestScreen` untuk menguji koneksi API:

```dart
Navigator.push(
  context,
  MaterialPageRoute(builder: (_) => const ApiTestScreen()),
);
```

## Konfigurasi API

Base URL API: `http://perpus-api.mamorasoft.com/api`

Untuk mengubah URL API, edit file `lib/services/library_api_service.dart`:

```dart
static const String baseUrl = 'http://perpus-api.mamorasoft.com/api';
```

## Error Handling

Semua provider dan service dilengkapi dengan error handling yang komprehensif:

- Network timeout handling
- HTTP error code handling
- Automatic retry untuk beberapa kasus
- User-friendly error messages

## Dependencies yang Diperlukan

Pastikan semua dependencies berikut sudah ada di `pubspec.yaml`:

```yaml
dependencies:
  dio: ^5.3.2
  shared_preferences: ^2.2.2
  provider: ^6.0.5
  # ... dependencies lainnya
```

## Catatan Penting

1. **Form Data**: API menggunakan `multipart/form-data` untuk sebagian besar POST requests
2. **Authentication**: Menggunakan Bearer token yang disimpan di SharedPreferences
3. **Error Handling**: Semua response error ditangani dengan graceful error messages
4. **Offline Support**: Aplikasi akan menampilkan error message yang sesuai jika tidak ada koneksi
5. **State Management**: Menggunakan Provider pattern untuk state management yang clean dan maintainable

## Troubleshooting

### 1. Koneksi Gagal

- Pastikan device/emulator terhubung internet
- Cek apakah API server sedang online
- Periksa firewall atau proxy settings

### 2. Login Gagal

- Pastikan username dan password benar
- Cek response dari API di debug console
- Pastikan format request sesuai dengan yang diharapkan API

### 3. Data Tidak Muncul

- Cek apakah login berhasil dan token tersimpan
- Periksa struktur response dari API
- Debug menggunakan ApiTestScreen

## Credential untuk Testing

Berdasarkan Postman collection, gunakan credential berikut untuk testing:

- **Username**: Admin123
- **Password**: 12345678

## Pengembangan Selanjutnya

1. Implementasi refresh token
2. Offline caching dengan SQLite
3. Real-time updates dengan WebSocket
4. Push notifications
5. Advanced search dan filtering
6. Reporting dan analytics
