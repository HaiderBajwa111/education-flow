# API Contracts: Multi-Tenant Student Information Foundation

**Branch**: `001-multi-tenant-student-info` | **Date**: 2026-03-08  
**Base URL**: `https://{subdomain}.educationflow.pk/api`  
**Auth**: All endpoints require `Authorization: Bearer {accessToken}` except `/auth/*`

---

## Auth Endpoints

### `POST /api/auth/login`
**Roles**: Public (on valid tenant subdomain)

**Request**:
```json
{ "cnic": "35201-1234567-5", "password": "tempPassword123" }
```
**Response 200**:
```json
{
  "success": true,
  "data": {
    "accessToken": "eyJ...",
    "user": { "id": "cuid", "fullName": "Ahmed Khan", "role": "CLERK" }
  }
}
```
**Response 401**: Invalid credentials  
**Response 404**: School subdomain not found

---

### `POST /api/auth/change-password`
**Roles**: Any authenticated staff (required if `mustChangePassword === true`)

**Request**:
```json
{ "currentPassword": "tempPass", "newPassword": "securePass123!" }
```
**Response 200**: `{ "success": true, "message": "Password updated successfully" }`

---

### `POST /api/auth/refresh`
**Roles**: Any (uses HTTP-only refresh token cookie)

**Response 200**: `{ "success": true, "data": { "accessToken": "eyJ..." } }`

---

## Staff Endpoints

### `POST /api/staff`
**Roles**: `PRINCIPAL`

**Request**:
```json
{
  "fullName": "Sara Malik",
  "cnic": "35201-7654321-3",
  "phone": "0321-1234567",
  "role": "TEACHER"
}
```
**Response 201**:
```json
{
  "success": true,
  "data": { "id": "cuid", "fullName": "Sara Malik", "role": "TEACHER", "mustChangePassword": true }
}
```
**Response 409**: CNIC already registered

---

### `GET /api/staff`
**Roles**: `PRINCIPAL`, `CLERK`  
**Query**: `?page=1&limit=20&role=TEACHER`

**Response 200**:
```json
{
  "success": true,
  "data": [{ "id": "cuid", "fullName": "Sara Malik", "role": "TEACHER", "cnic": "35201-7654321-3", "phone": "0321-1234567" }],
  "total": 12, "page": 1, "limit": 20
}
```

---

### `DELETE /api/staff/:id`
**Roles**: `PRINCIPAL` only  
**Response 200**: `{ "success": true, "message": "Staff member removed" }`  
**Response 403**: Clerk or Teacher attempts deletion  
**Response 404**: Staff not found

---

## Classes & Sections Endpoints

### `POST /api/classes`
**Roles**: `PRINCIPAL`, `CLERK`

**Request**: `{ "name": "Class 5", "displayOrder": 5 }`  
**Response 201**: `{ "success": true, "data": { "id": "cuid", "name": "Class 5" } }`  
**Response 409**: Class name already exists

---

### `GET /api/classes`
**Roles**: All authenticated  
**Response 200**: Array of classes with their sections.

---

### `POST /api/classes/:classId/sections`
**Roles**: `PRINCIPAL`, `CLERK`

**Request**: `{ "name": "A", "classTeacherId": "cuid_optional" }`  
**Response 201**: Section object  
**Response 409**: Section name already exists in this class

---

### `DELETE /api/classes/:classId/sections/:sectionId`
**Roles**: `PRINCIPAL`, `CLERK`  
**Response 400**: Cannot delete if active students are assigned to this section

---

## Subjects Endpoints

### `POST /api/classes/:classId/subjects`
**Roles**: `PRINCIPAL`, `CLERK`

**Request**: `{ "name": "Mathematics", "displayOrder": 1 }`  
**Response 201**: Subject object  
**Response 409**: Subject name already exists in this class

---

### `GET /api/classes/:classId/subjects`
**Roles**: All authenticated  
**Response 200**: Array of subjects for the given class

---

### `DELETE /api/classes/:classId/subjects/:subjectId`
**Roles**: `PRINCIPAL`, `CLERK`  
**Response 200**: Deleted  
**Response 400**: Cannot delete — existing exam records linked to this subject  
**Response 403**: Teacher attempt

---

## Students Endpoints

### `POST /api/students`
**Roles**: `PRINCIPAL`, `CLERK`

**Request**:
```json
{
  "fullName": "Zainab Fatima",
  "bFormNumber": "35200-1234567-4",
  "dateOfBirth": "2012-03-15",
  "gender": "FEMALE",
  "religion": "MUSLIM",
  "admissionDate": "2026-03-08",
  "sectionId": "cuid_section",
  "streetAddress": "House 12, Street 4",
  "area": "Gulshan-e-Iqbal",
  "city": "Karachi",
  "province": "Sindh",
  "guardian": {
    "fullName": "Muhammad Fatima",
    "relationship": "FATHER",
    "cnic": "35201-9876543-1",
    "phone": "0300-1234567",
    "phoneAlt": "0321-7654321"
  }
}
```
**Response 201**: Full student object with nested guardian  
**Response 409**: B-Form already registered to an active student  
**Response 400**: Validation failure (inline field errors)

---

### `GET /api/students`
**Roles**: All (Teacher sees own sections only)  
**Query**: `?page=1&limit=20&classId=cuid&sectionId=cuid&search=Zainab`

**Response 200**:
```json
{
  "success": true,
  "data": [{ "id": "cuid", "fullName": "Zainab Fatima", "bFormNumber": "35200-1234567-4", "section": { "name": "A", "class": { "name": "Class 5" } } }],
  "total": 145, "page": 1, "limit": 20
}
```

---

### `GET /api/students/:id`
**Roles**: All (Teacher: own sections only)  
**Response 200**: Full student object including guardian  
**Response 403**: Teacher accessing student outside their section  
**Response 404**: Student not found

---

### `PATCH /api/students/:id`
**Roles**: `PRINCIPAL`, `CLERK`  
**Request**: Partial student object (any fields to update)  
**Response 200**: Updated student object  
**Response 409**: B-Form conflict with another active student

---

### `DELETE /api/students/:id`
**Roles**: `PRINCIPAL` only  
**Response 200**: `{ "success": true, "message": "Student record archived" }`  
**Response 403**: Clerk or Teacher attempt  
**Response 404**: Not found

---

## Standard Response Envelope

All responses follow this structure:
```json
{
  "success": true | false,
  "data": {} | [],
  "message": "Optional human-readable message",
  "errors": { "fieldName": "Validation error message" }
}
```

## Standard Error Codes

| HTTP Code | When |
|---|---|
| 400 | Validation failure |
| 401 | Missing or invalid JWT |
| 403 | Valid JWT but insufficient role |
| 404 | Resource or tenant not found |
| 409 | Unique constraint conflict (B-Form, CNIC, class name) |
| 500 | Unexpected server error (never exposes stack trace) |
