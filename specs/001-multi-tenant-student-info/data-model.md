# Data Model: Multi-Tenant Student Information Foundation

**Branch**: `001-multi-tenant-student-info` | **Date**: 2026-03-08

---

## Schema Overview

```
PUBLIC SCHEMA (platform-level — no tenant data)
└── Tenant

SCHOOL_{tenantId} SCHEMA (per-school — all tenant data lives here)
├── StaffUser
├── Class
├── Section
├── Subject
├── Student
└── Guardian
```

---

## Entity Definitions

### `Tenant` (public schema)

Represents a registered school on the platform.

| Field | Type | Constraints | Notes |
|---|---|---|---|
| `id` | String (cuid) | PK | Platform-wide unique ID |
| `name` | String | NOT NULL | Human-readable school name |
| `subdomain` | String | UNIQUE, NOT NULL | e.g., `sunrise` |
| `schemaName` | String | UNIQUE, NOT NULL | e.g., `school_abc123` |
| `isActive` | Boolean | DEFAULT true | Soft-disable a school |
| `createdAt` | DateTime | DEFAULT now() | |
| `updatedAt` | DateTime | auto-updated | |

**Relationships**: none (public schema, no FK to tenant schemas)

---

### `StaffUser` (tenant schema)

A school staff member with a specific role.

| Field | Type | Constraints | Notes |
|---|---|---|---|
| `id` | String (cuid) | PK | |
| `fullName` | String | NOT NULL | |
| `cnic` | String | NOT NULL | Stored without dashes: `3520112345671` |
| `phone` | String | NOT NULL | Stored without dashes: `03211234567` |
| `role` | Enum `StaffRole` | NOT NULL | `PRINCIPAL \| CLERK \| TEACHER` |
| `email` | String | UNIQUE, nullable | Optional; for future use |
| `passwordHash` | String | NOT NULL | bcrypt hash |
| `mustChangePassword` | Boolean | DEFAULT true | Force change on first login |
| `deletedAt` | DateTime | nullable | Soft delete |
| `createdById` | String | FK → StaffUser | Who created this account |
| `createdAt` | DateTime | DEFAULT now() | |
| `updatedAt` | DateTime | auto-updated | |

**Indexes**: unique on `cnic` (active records only, via partial index)

---

### `Class` (tenant schema)

A grade level configured by the school.

| Field | Type | Constraints | Notes |
|---|---|---|---|
| `id` | String (cuid) | PK | |
| `name` | String | NOT NULL | e.g., `Class 5`, `Nursery`, `Matric` |
| `displayOrder` | Int | DEFAULT 0 | For ordered display in UI |
| `createdAt` | DateTime | DEFAULT now() | |
| `updatedAt` | DateTime | auto-updated | |

**Constraints**: `@@unique([name])` — class name is unique per school (within the tenant schema).

**Relationships**:
- Has many `Section`
- Has many `Subject`

---

### `Section` (tenant schema)

A subdivision of a class (e.g., Class 5A).

| Field | Type | Constraints | Notes |
|---|---|---|---|
| `id` | String (cuid) | PK | |
| `name` | String | NOT NULL | e.g., `A`, `B`, `Blue` |
| `classId` | String | FK → Class, NOT NULL | Parent class |
| `classTeacherId` | String | FK → StaffUser, nullable | Assigned class teacher |
| `createdAt` | DateTime | DEFAULT now() | |
| `updatedAt` | DateTime | auto-updated | |

**Constraints**: `@@unique([classId, name])` — section name unique within a class.

**Relationships**:
- Belongs to `Class`
- Has many `Student`
- Belongs to `StaffUser` (class teacher, optional)

---

### `Subject` (tenant schema)

A subject taught within a specific class. Completely school-configurable.

| Field | Type | Constraints | Notes |
|---|---|---|---|
| `id` | String (cuid) | PK | |
| `name` | String | NOT NULL | e.g., `Mathematics`, `Urdu` |
| `classId` | String | FK → Class, NOT NULL | Subject belongs to this class only |
| `displayOrder` | Int | DEFAULT 0 | For ordered display in mark sheets |
| `createdAt` | DateTime | DEFAULT now() | |
| `updatedAt` | DateTime | auto-updated | |

**Constraints**: `@@unique([classId, name])` — subject name unique within a class.

**Note**: Same subject name (e.g., "Maths") in two different classes = two independent Subject records. No shared subject list.

---

### `Student` (tenant schema)

The core student record. Soft-deletable.

| Field | Type | Constraints | Notes |
|---|---|---|---|
| `id` | String (cuid) | PK | |
| `fullName` | String | NOT NULL | |
| `bFormNumber` | String | NOT NULL | Format: `12345-1234567-1` (stored as-is with dashes) |
| `dateOfBirth` | DateTime | NOT NULL | |
| `gender` | Enum `Gender` | NOT NULL | `MALE \| FEMALE \| OTHER` |
| `religion` | Enum `Religion` | NOT NULL | `MUSLIM \| CHRISTIAN \| HINDU \| OTHER` |
| `admissionDate` | DateTime | DEFAULT now() | |
| `sectionId` | String | FK → Section, NOT NULL | Which class-section |
| `streetAddress` | String | NOT NULL | House/street |
| `area` | String | NOT NULL | Area/mohallah |
| `city` | String | NOT NULL | Free text |
| `province` | String | NOT NULL | Free text |
| `deletedAt` | DateTime | nullable | Soft delete |
| `createdById` | String | FK → StaffUser | Who admitted this student |
| `updatedById` | String | FK → StaffUser | Who last edited |
| `createdAt` | DateTime | DEFAULT now() | |
| `updatedAt` | DateTime | auto-updated | |

**Indexes**:
- Raw partial unique index: `CREATE UNIQUE INDEX students_bform_active ON students (b_form_number) WHERE deleted_at IS NULL;`
- Index on `sectionId` for filtered list queries.
- Index on `fullName` for search.

**Relationships**:
- Belongs to `Section` (which implies a `Class`)
- Has one (or more) `Guardian`
- Has many `Attendance` (future)
- Has many `ExamResult` (future)

---

### `Guardian` (tenant schema)

Contact information for a student's guardian.

| Field | Type | Constraints | Notes |
|---|---|---|---|
| `id` | String (cuid) | PK | |
| `studentId` | String | FK → Student, NOT NULL | Linked student |
| `fullName` | String | NOT NULL | Guardian's name |
| `relationship` | Enum `Relationship` | NOT NULL | `FATHER \| MOTHER \| GUARDIAN \| OTHER` |
| `cnic` | String | NOT NULL | Stored without dashes |
| `phone` | String | NOT NULL | Stored without dashes |
| `phoneAlt` | String | nullable | Stored without dashes |
| `createdAt` | DateTime | DEFAULT now() | |
| `updatedAt` | DateTime | auto-updated | |

---

## Enums (tenant schema)

```prisma
enum StaffRole {
  PRINCIPAL
  CLERK
  TEACHER
}

enum Gender {
  MALE
  FEMALE
  OTHER
}

enum Religion {
  MUSLIM
  CHRISTIAN
  HINDU
  OTHER
}

enum Relationship {
  FATHER
  MOTHER
  GUARDIAN
  OTHER
}
```

---

## Entity Relationship Diagram

```
[Tenant] (public schema)
    │ (no FK — cross-schema isolation)
    │
[StaffUser] ──── createdBy ──→ [StaffUser]
    │
    ├── [Class] ──→ [Section] ──→ [Student] ──→ [Guardian]
    │       │             │
    │       └──→ [Subject]│
    │                     │
    └── classTeacher ─────┘ (Section.classTeacherId → StaffUser)
```

---

## Key Validation Rules (to be mirrored in DTOs + Zod)

| Field | Rule | Pattern |
|---|---|---|
| B-Form | Format: `DDDDD-DDDDDDD-D` | `/^\d{5}-\d{7}-\d{1}$/` |
| CNIC | Format: `DDDDD-DDDDDDD-D` | `/^\d{5}-\d{7}-\d{1}$/` |
| Phone (primary) | Format: `03xx-xxxxxxx` | `/^03\d{2}-\d{7}$/` |
| Phone (alt) | Same as primary, optional | `/^03\d{2}-\d{7}$/` |
| Date of Birth | Must be in the past, after 1900 | range check |
| Admission Date | Must not be before date of birth | relative check |
| Class name | Unique per school, non-empty | unique constraint |
| Section name | Unique within class, non-empty | unique constraint |
| Subject name | Unique within class, non-empty | unique constraint |

---

## State Transitions

### Student Record

```
[Active] ──── Principal deletes ──→ [Soft-Deleted]
[Soft-Deleted] ──── re-enroll (new record) ──→ [Active] (new row, same bFormNumber allowed)
```

### StaffUser Record

```
[Active, mustChangePassword=true] ──── first login ──→ [Active, mustChangePassword=false]
[Active] ──── Principal deletes ──→ [Soft-Deleted]
```
