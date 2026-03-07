# Education Flow — Project Constitution

> **The North Star:** Operational Efficiency. Every design and implementation decision MUST minimize clicks and cognitive load for Pakistani school staff.

---

## Table of Contents

1. [Project Identity](#1-project-identity)
2. [Core Principles](#2-core-principles)
3. [Technical Architecture](#3-technical-architecture)
4. [Multi-Tenancy Architecture](#4-multi-tenancy-architecture)
5. [User Roles & Access Control](#5-user-roles--access-control)
6. [Pakistani Context & Validation Rules](#6-pakistani-context--validation-rules)
7. [Database & Migration Policy](#7-database--migration-policy)
8. [Backend Standards (NestJS)](#8-backend-standards-nestjs)
9. [Frontend Standards (Next.js)](#9-frontend-standards-nextjs)
10. [Naming Conventions](#10-naming-conventions)
11. [File Upload Standards](#11-file-upload-standards)
12. [Code Quality Gates](#12-code-quality-gates)
13. [Core Modules](#13-core-modules)
14. [Feature Development Workflow](#14-feature-development-workflow)
15. [Guiding Questions for Feature Specification](#15-guiding-questions-for-feature-specification)
16. [Governance](#16-governance)

---

## 1. Project Identity

| Property       | Value                                                                   |
| -------------- | ----------------------------------------------------------------------- |
| **Name**       | Education Flow                                                          |
| **Type**       | Multi-tenant School Management System                                   |
| **Users**      | Staff Only — Principal, Clerk, Teacher                                  |
| **Non-Users**  | Students and Parents have **NO system login**                           |
| **Parents**    | Receive SMS notifications only (Phase 2); never access the application  |
| **Target**     | Pakistani private/public schools                                        |
| **Language**   | English UI (Urdu support is a future consideration, not Phase 1)        |

---

## 2. Core Principles

### I. Staff-Only System (NON-NEGOTIABLE)
- This system is **exclusively for school staff**: Principal, Clerk, and Teacher.
- **Students and Parents MUST NOT have login access** at any point in Phase 1 or beyond without an explicit constitution amendment.
- Parents only interact with the system as data recipients (SMS notifications).
- Every feature specification MUST explicitly state which staff role(s) it targets.

### II. Operational Efficiency First
- Every UI screen should be completable with the **minimum possible clicks**.
- Prefer smart defaults, auto-fill from existing data, and bulk operations over individual record edits.
- Forms must display inline validation without page reloads.

### III. Multi-Tenancy by Design (NON-NEGOTIABLE)
- Every database query, API endpoint, and service method MUST be tenant-aware.
- **Never allow cross-tenant data leakage**. This is a critical security requirement.
- Tenant isolation is enforced at the database schema level (`school_{tenantId}`).
- Any feature that ignores tenancy context MUST be flagged as CRITICAL in `/speckit.analyze`.

### IV. Type Safety Across the Stack
- TypeScript strict mode is **mandatory** on both backend and frontend.
- Shared types MUST live in `/shared-types` and be imported by both sides.
- No use of `any` type is permitted without a documented justification comment.

### V. Migrations Over Direct DB Access (NON-NEGOTIABLE)
- **ALL** schema changes MUST go through Prisma migrations.
- Direct database modification (psql, Adminer edits to schema) is **strictly forbidden**.
- No exceptions, including hotfixes in production.

### VI. Pakistani Context Compliance
- All data collection and validation MUST respect the Pakistani regulatory and cultural context (B-Form, CNIC, phone formats, religion, class structures).
- These are not optional fields; they are core to the data model's integrity.

### VII. Feature-First Modularity
- Backend code is organized as NestJS feature modules. No "catch-all" modules.
- A feature module owns its own controller, service, DTOs, and repository logic.
- Cross-module dependencies MUST go through a shared service or event, never direct injection between feature modules across domain boundaries.

---

## 3. Technical Architecture

### Project Structure

```
education-flow/
├── backend/              # NestJS application (port 3001)
│   ├── src/
│   │   ├── app.module.ts
│   │   ├── main.ts
│   │   ├── common/       # Guards, interceptors, decorators, pipes
│   │   ├── config/       # Environment configuration
│   │   ├── prisma/       # PrismaService, PrismaModule
│   │   └── modules/      # Feature modules (students, staff, etc.)
│   ├── prisma/
│   │   ├── schema.prisma
│   │   └── migrations/
│   └── test/
├── frontend/             # Next.js application (port 3000)
│   ├── app/              # App Router pages
│   ├── components/       # Reusable UI components
│   ├── lib/              # Utilities, API clients
│   └── hooks/            # Custom React hooks
└── shared-types/         # TypeScript shared interfaces and enums
    └── src/
```

### Technology Stack

| Layer           | Technology                              | Version    |
| --------------- | --------------------------------------- | ---------- |
| Backend         | NestJS                                  | v11        |
| Backend Lang.   | TypeScript (strict mode)               | v5.x       |
| ORM             | Prisma                                  | v7.x       |
| Database        | PostgreSQL (Docker)                     | v15+       |
| Auth            | JWT (access + refresh tokens)           | —          |
| Frontend        | Next.js (App Router)                    | v16        |
| UI Library      | React                                   | v19        |
| Styling         | Tailwind CSS                            | v4         |
| Components      | shadcn/ui                               | Latest     |
| Form Validation | React Hook Form + Zod                   | Latest     |
| Server State    | TanStack Query (React Query)            | v5         |
| HTTP Client     | Axios (backend API calls from frontend) | Latest     |
| Infrastructure  | Docker Compose                          | —          |

### Port Assignments

| Service   | Port  |
| --------- | ----- |
| Frontend  | 3000  |
| Backend   | 3001  |
| PostgreSQL | 5432  |
| Adminer   | 8080  |

---

## 4. Multi-Tenancy Architecture

### Tenancy Model

- **Strategy**: Database schema-per-tenant (PostgreSQL schemas).
- **Schema Naming**: `school_{tenantId}` (e.g., `school_abc123`).
- **Identification**: Tenant is identified via **subdomain** (e.g., `greenwood.educationflow.pk`).
- **Default Schema**: `public` schema is reserved for global/platform-level data only (e.g., `tenants` table, `super_admin` users).

### Tenant Resolution Flow

```
Incoming Request
      │
      ▼
TenantMiddleware (extracts subdomain)
      │
      ▼
Validate tenant exists in public.tenants
      │
      ▼
Attach tenantId + schemaName to Request object
      │
      ▼
PrismaService sets search_path per request
      │
      ▼
All queries execute within tenant's schema
```

### MUST Rules for Multi-Tenancy

- **MUST**: `TenantMiddleware` MUST be applied globally, with explicit exclusions only for `/auth/*` and `/health` routes.
- **MUST**: Every service method that touches the database MUST accept and use a `tenantId` or a tenant-scoped Prisma client.
- **MUST**: API responses MUST NEVER include data from another tenant's schema.
- **MUST NOT**: Use a single Prisma client with a static schema for tenant data.
- **SHOULD**: Tenant schema provisioning (migration) should be handled via a dedicated service during school onboarding.

---

## 5. User Roles & Access Control

### Role Definitions

| Role          | Access Level                                                                                 |
| ------------- | ---------------------------------------------------------------------------------------------|
| **Principal** | Full read/write access to all school data, settings, reports, and staff management.         |
| **Clerk**     | Student admission, document upload, fee records, data entry. Cannot manage staff roles.      |
| **Teacher**   | Mark attendance for assigned sections. Enter exam marks. View own students only.             |

### Authentication Rules

- **MUST**: Authentication uses JWT (access token: 15 min, refresh token: 7 days).
- **MUST**: All protected routes require a valid JWT containing `userId`, `role`, and `tenantId`.
- **MUST**: Role is enforced via a `@Roles()` decorator + `RolesGuard` on every controller method.
- **MUST NOT**: Trust the role from the request body or query params — always use the JWT payload.
- **MUST**: On login, the JWT `tenantId` must match the subdomain's `tenantId`. Mismatches result in 401.

### Permission Matrix

| Feature                    | Principal | Clerk | Teacher |
| -------------------------- | :-------: | :---: | :-----: |
| View all students          | ✅        | ✅    | ✅*     |
| Add/Edit students          | ✅        | ✅    | ❌      |
| Delete students            | ✅        | ❌    | ❌      |
| Manage staff               | ✅        | ❌    | ❌      |
| Mark attendance            | ✅        | ❌    | ✅*     |
| Enter exam marks           | ✅        | ❌    | ✅*     |
| Generate report cards      | ✅        | ✅    | ❌      |
| View school settings       | ✅        | ❌    | ❌      |
| Edit school settings       | ✅        | ❌    | ❌      |
| Send SMS                   | ✅        | ✅    | ❌      |

> `✅*` = Access restricted to teacher's **assigned** sections/subjects only.

### Super Admin Creation & Management

| Aspect | Rule |
|--------|------|
| **Creation Method** | Seed script / CLI command / Manual DB insert ONLY |
| **API Endpoint** | ❌ NONE - Never exposed via API |
| **Public Signup** | ❌ Absolutely forbidden |
| **Max Count** | 1-2 per platform instance |
| **Created By** | System owner / DevOps engineer |
| **Password Storage** | Environment variables / Secrets manager |

---

## 6. Pakistani Context & Validation Rules

### Required Formats (ALL are regex-validated)

| Field       | Format                    | Regex Pattern                              | Example             |
| ----------- | --------------------------| ------------------------------------------ | ------------------- |
| B-Form No.  | `DDDDD-DDDDDDD-D`         | `/^\d{5}-\d{7}-\d{1}$/`                   | `35200-1234567-1`   |
| CNIC        | `DDDDD-DDDDDDD-D`         | `/^\d{5}-\d{7}-\d{1}$/`                   | `35201-9876543-5`   |
| Phone       | `03xx-xxxxxxx`            | `/^03\d{2}-\d{7}$/`                        | `0321-1234567`      |
| Alt. Phone  | Same as Phone (optional)  | `/^03\d{2}-\d{7}$/`                        | `0300-7654321`      |

### Standard Enum Values

#### Gender
```
Male | Female | Other
```

#### Religion
```
Muslim | Christian | Hindu | Other
```

#### Class Structure (Nursery → Matric/FSc)
```
Playgroup | Nursery | Prep | Class 1 | Class 2 | Class 3 | Class 4 | Class 5 |
Class 6 | Class 7 | Class 8 | Class 9 | Class 10 (Matric) | Class 11 (FSc Part 1) | Class 12 (FSc Part 2)
```

#### Sections
- Multiple sections per class: `A`, `B`, `C`, `D`, etc.
- Sections are configurable per school (not hardcoded beyond letters).

### Validation Rules (Backend DTOs + Frontend Zod Schemas)

- **MUST**: B-Form validation is **mandatory** for all student records.
- **MUST**: CNIC validation is **mandatory** for all staff and guardian records.
- **MUST**: All phone numbers follow the `03xx-xxxxxxx` format; stored without dashes in DB, displayed with dashes.
- **SHOULD**: Date of Birth must be a logical value (not in the future, not before 1900).
- **SHOULD**: Admission date cannot be earlier than the student's date of birth.

---

## 7. Database & Migration Policy

### Migration Workflow (NON-NEGOTIABLE)

```
1. Update schema in backend/prisma/schema.prisma
2. Run: npx prisma migrate dev --name descriptive_migration_name
3. Review the generated SQL migration file
4. Test migration on local DB
5. Commit schema.prisma + the new migration file together
```

### Production Deployment

```bash
npx prisma migrate deploy
```

### MUST Rules

- **MUST NOT**: Modify the database schema directly via Adminer, psql, or any SQL client.
- **MUST NOT**: Commit `schema.prisma` without the corresponding migration file.
- **MUST**: Every migration file must have a descriptive name (`add_guardian_bform_field` not `migration1`).
- **MUST**: Run `npx prisma generate` after every schema change to regenerate the Prisma client.
- **MUST**: The `prisma/migrations` folder is version controlled alongside code.
- **SHOULD**: Migration names follow `snake_case` and describe the change (e.g., `add_attendance_table`, `rename_student_id_column`).

### Prisma Schema Conventions

- Table names: `snake_case` (enforced via `@@map("table_name")` if needed).
- All tables MUST have: `id` (cuid), `createdAt`, `updatedAt`.
- Soft delete: use `deletedAt DateTime?` — never hard delete student or academic records.

---

## 8. Backend Standards (NestJS)

### Module Structure

Each feature module MUST follow this structure:
```
modules/students/
├── students.module.ts
├── students.controller.ts
├── students.service.ts
├── dto/
│   ├── create-student.dto.ts
│   └── update-student.dto.ts
└── students.service.spec.ts
```

### Controller Rules

- Controllers handle **HTTP only**: request parsing, response formatting, auth guards.
- No business logic in controllers.
- All routes use `@Roles()` decorator explicitly.
- Use `@ApiTags()` and `@ApiOperation()` for Swagger documentation.
- Return standard response envelope: `{ success: boolean, data: T, message?: string }`.

### Service Rules

- Services contain **all business logic**.
- Services MUST accept `tenantId` as a parameter for all DB operations.
- Throw `HttpException` with appropriate status codes:
  - `404 NotFoundException` for missing records.
  - `409 ConflictException` for duplicate records (e.g., duplicate B-Form).
  - `403 ForbiddenException` for role violations.
  - `400 BadRequestException` for validation failures.

### DTO Rules

- All DTOs use `class-validator` decorators.
- All DTOs use `class-transformer` (enable `transform: true` in `ValidationPipe`).
- Create DTOs and Update DTOs are separate files.
- Validation messages MUST be descriptive and human-readable.

### Global NestJS Configuration (main.ts)

```typescript
app.useGlobalPipes(new ValidationPipe({
  whitelist: true,      // Strip unknown fields
  forbidNonWhitelisted: true,
  transform: true,      // Auto-transform types
}));
app.setGlobalPrefix('api');
app.enableCors({ origin: process.env.FRONTEND_URL });
```

### API Design

- All endpoints are prefixed with `/api`.
- Routes use kebab-case: `/api/students/:id/report-cards`.
- Pagination: All list endpoints accept `?page=1&limit=20` and return `{ data, total, page, limit }`.
- Filtering: Pass filters as query params.
- Use HTTP verbs correctly: GET (read), POST (create), PATCH (partial update), DELETE (soft delete).

---

## 9. Frontend Standards (Next.js)

### Rendering Strategy

- **Default**: Server Components for all pages and layouts.
- **Client Components**: Only when interactivity is needed (forms, dropdowns, modals). Mark with `'use client'`.
- **Never** fetch data in Client Components directly — fetch in Server Components or via TanStack Query.

### File & Folder Structure

```
frontend/app/
├── (auth)/
│   └── login/
│       └── page.tsx
├── (dashboard)/
│   ├── layout.tsx          # Protected layout with sidebar
│   ├── students/
│   │   ├── page.tsx        # Student list (Server Component)
│   │   └── [id]/
│   │       └── page.tsx    # Student detail
│   └── ...
└── api/                    # Next.js route handlers (if needed)
```

### Component Architecture

- **Pages** (`page.tsx`): Data fetching only, pass data to components.
- **Components** (`components/`): UI rendering. Split into `ui/` (shadcn primitives) and feature-specific components.
- **Hooks** (`hooks/`): Custom hooks for reusable logic (e.g., `useStudents`, `useTenant`).
- **Lib** (`lib/`): API client (Axios instance), utility functions, Zod schemas.

### Form Handling

- **MUST**: All forms use `react-hook-form` + `zod` resolver.
- **MUST**: Zod schemas are defined in `lib/schemas/` and shared with the API client for consistency.
- **MUST**: Show inline field-level validation errors, not alerts.
- **MUST**: Disable submit button while request is pending.

### State Management

- **Server State**: TanStack Query (`useQuery`, `useMutation`).
- **Client/UI State**: React `useState` and `useReducer` only. No global client state library unless justified.
- **Auth State**: Stored in a secure HTTP-only cookie (handled by backend).

### UI Components

- **MUST**: Use `shadcn/ui` for all UI primitives (Button, Input, Table, Modal, etc.).
- **MUST NOT**: Build custom primitives that duplicate shadcn components.
- **SHOULD**: All data tables use `shadcn/ui`'s `Table` component with pagination.
- **SHOULD**: All confirmation actions (delete, bulk operations) use a `Dialog` component.

---

## 10. Naming Conventions

| Scope                 | Convention   | Example                          |
| --------------------- | ------------ | -------------------------------- |
| Files (all)           | kebab-case   | `student-service.ts`             |
| Classes               | PascalCase   | `StudentsService`                |
| Variables/Functions   | camelCase    | `getStudentById`                 |
| Constants             | UPPER_SNAKE  | `MAX_FILE_SIZE_MB`               |
| Database Tables       | snake_case   | `exam_subjects`, `class_sections`|
| Database Columns      | snake_case   | `date_of_birth`, `b_form_number` |
| API Routes            | kebab-case   | `/api/students/:id/report-cards` |
| React Components      | PascalCase   | `StudentAdmissionForm`           |
| React Hooks           | camelCase    | `useStudentList`                 |
| Enums                 | PascalCase   | `UserRole.Principal`             |
| Zod Schemas           | camelCase    | `createStudentSchema`            |
| DTOs                  | PascalCase   | `CreateStudentDto`               |
| Environment Variables | UPPER_SNAKE  | `DATABASE_URL`, `JWT_SECRET`     |
| Prisma Models         | PascalCase   | `Student`, `ExamResult`          |

---

## 11. File Upload Standards

| Type             | Allowed Formats       | Max Size | Storage Path                         |
| ---------------- | --------------------- | -------- | ------------------------------------ |
| Student Photo    | JPEG, PNG             | 2 MB     | `uploads/{tenantId}/students/photos/`|
| Documents (Docs) | PDF, JPEG, PNG        | 5 MB     | `uploads/{tenantId}/documents/`      |
| Staff Photo      | JPEG, PNG             | 2 MB     | `uploads/{tenantId}/staff/photos/`   |

### File Naming Rules

- Filenames MUST be unique: use pattern `{entityId}_{timestamp}_{originalName}`.
- Original filenames from users MUST NOT be used directly (security risk).
- **MUST**: Validate MIME type server-side (not just extension).
- **MUST**: Files are organized in tenant-specific folders to prevent cross-tenant access.

---

## 12. Code Quality Gates

### Linting & Formatting

- **ESLint**: Configured with `typescript-eslint`. Run before every commit.
- **Prettier**: Enforced formatting. Integrated with ESLint via `eslint-plugin-prettier`.
- `no-console`: Warn on `console.log`; use a Logger service instead.
- `no-any`: Error — no `any` type without documented `// eslint-disable-next-line` justification.

### TypeScript

- `strict: true` in all `tsconfig.json` files.
- No implicit `any`.
- Null checks enforced (`strictNullChecks: true`).

### Testing

- Unit tests: Required for all **service** methods containing business logic.
- E2E tests: Required for all **authentication** and **critical API paths**.
- Test framework: **Jest** (backend), **Jest + React Testing Library** (frontend, Phase 2).
- Test files: Co-located with source (`students.service.spec.ts`).
- Minimum coverage target: **70%** on service files.

### Error Handling

- Backend: All unhandled errors MUST be caught by a global `HttpExceptionFilter`.
- Frontend: All failed mutations show a `toast` notification with the error message from the API.
- Never expose raw stack traces to frontend clients.

---

## 13. Core Modules

These modules constitute the **Phase 1** scope (in priority order):

| # | Module                       | Key Responsibilities                                          |
| - | ---------------------------- | ------------------------------------------------------------- |
| 1 | **Auth**                     | Login, JWT issue/refresh, role guards, tenant validation      |
| 2 | **Student Information**      | Admission, profiles, B-Form, guardian info, documents        |
| 3 | **Academics**                | Classes, sections, subjects, class-section-subject mapping   |
| 4 | **Staff Management**         | Staff profiles, CNIC, role assignment, teaching assignments  |
| 5 | **Attendance**               | Daily student attendance per section, teacher-marked         |
| 6 | **Examination & Grading**    | Exam setup, mark entry, grade calculation                    |
| 7 | **Report Card Generation**   | Auto-generated report cards based on exam results            |
| 8 | **SMS Integration**          | Phase 2 — parent notifications for attendance/results        |

---

## 14. Feature Development Workflow

Every new feature MUST follow these steps in order:

```
1. /speckit.specify  →  Define the feature in .specify/{feature}/spec.md
2. /speckit.clarify  →  Answer ambiguities (run if spec has gaps)
3. /speckit.plan     →  Create technical plan in .specify/{feature}/plan.md
4. /speckit.tasks    →  Generate tasks.md with dependency-ordered tasks
5. /speckit.analyze  →  Validate consistency across spec, plan, tasks
6. /speckit.implement→  Execute tasks (only after analyze passes)
```

**MUST**: No implementation starts before `tasks.md` exists and `/speckit.analyze` shows no CRITICAL issues.

---

## 15. Guiding Questions for Feature Specification

Before writing any spec, answer **all** of the following:

1. **Roles**: Which staff role(s) can access this feature? (Principal / Clerk / Teacher)
2. **Pakistani Validation**: What Pakistani-specific formats or fields are involved? (B-Form, CNIC, phone, class structure)
3. **Multi-Tenancy**: How does this feature interact with the tenant context? Is every data point scoped to a single school?
4. **Staff-Only Confirmation**: Is this feature exclusively for staff? Could any data be inadvertently exposed to non-staff?
5. **Edge Cases**: What happens when the class has no students? What if a student is in multiple sections?
6. **Reports/Exports**: Does this feature need a PDF or CSV export? If so, specify format.
7. **SMS Notifications**: Should this trigger a parent notification? (Phase 2 only)
8. **Soft Delete**: Should deleted records be recoverable? (Default: Yes for academic records)
9. **Bulk Operations**: Are there bulk actions needed (e.g., bulk attendance marking, bulk mark entry)?
10. **Audit Trail**: Does this feature require tracking who changed what and when?

---

## 16. Governance

### Constitution Authority

- This constitution is the **supreme authority** for all development decisions on Education Flow.
- In any conflict between a spec, plan, task, or developer preference — **this document wins**.
- Constitution violations in specifications are automatically **CRITICAL** in `/speckit.analyze`.

### Amendment Process

1. A proposed amendment must be explicitly stated (not implied by a spec or plan).
2. The amendment must be ratified by the project owner before being merged.
3. After amendment, all existing specs, plans, and tasks must be validated for conflicts with the new principle.
4. Amendment is tracked in this file's **Version** metadata.

### Compliance

- All PRs/code reviews MUST verify compliance with this constitution.
- Task complexity must be justified in `tasks.md` — no over-engineering without documented rationale.
- Any deviation that is approved must be documented with a `// CONSTITUTION-EXCEPTION:` comment.

---

**Version**: 1.0.0 | **Ratified**: 2026-03-07 | **Last Amended**: 2026-03-07
