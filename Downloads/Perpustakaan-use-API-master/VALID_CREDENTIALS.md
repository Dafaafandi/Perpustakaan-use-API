# Valid API Credentials untuk Testing

Berdasarkan hasil testing terhadap API `http://perpus-api.mamorasoft.com/api`, berikut adalah credentials yang valid:

## ✅ Valid Credentials (Berhasil Login)

### User 1:

- **Username**: `12345678`
- **Password**: `12345678`
- **Role**: member
- **Status**: ✅ Confirmed working
- **User Info**:
  - Name: "12345678"
  - Email: "adaf@gmail.com"
  - ID: 119

### User 2:

- **Username**: `abidafaaa`
- **Password**: `[Unknown - berhasil di log tapi password tidak terlihat]`
- **Role**: member
- **Status**: ✅ Confirmed working
- **User Info**:
  - Name: "Muhammad Abi Dafa Afandi"
  - Email: "dafaafandi946@gmail.com"
  - ID: 106

## ❌ Invalid Credentials (Gagal Login)

### Attempted Credentials:

- **Username**: `Admin123` / **Password**: `12345678` ❌
- **Username**: `admin` / **Password**: `admin123` ❌

**Error Response**:

```json
{
  "status": 409,
  "message": "User tidak ditemukan, username dan password tidak cocok"
}
```

## 📝 Notes untuk Development

1. **Default Admin Credentials** yang disebutkan dalam dokumentasi (`Admin123`/`12345678`) **TIDAK VALID** di server ini.

2. **User Role System**:

   - API menggunakan role array: `[{"name": "member", ...}]`
   - Belum ditemukan user dengan role "admin"

3. **API Response Structure**:

   ```json
   {
     "status": 200,
     "message": "Login berhasil dilakukan",
     "data": {
       "user": {...},
       "token": "Bearer token...",
       "token_type": "Bearer",
       "expire_in": 1200
     }
   }
   ```

4. **Token Expiry**: 1200 seconds (20 menit)

## 🔧 Recommendations

1. **Untuk Testing**: Gunakan credentials `12345678`/`12345678`
2. **Untuk Admin Features**: Perlu mendapatkan credentials admin yang valid atau membuat user admin baru
3. **Fallback**: Implementasi local admin credentials sudah ada di kode

## 🚀 Testing Commands

Gunakan **Credential Test Screen** di aplikasi untuk:

- Test berbagai kombinasi username/password
- Melihat response structure
- Verify API connection
- Test CRUD operations setelah login

**Akses**: Login Screen → "TEST API CREDENTIALS" button
