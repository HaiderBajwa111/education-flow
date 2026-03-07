# Research: Multi-Tenant Student Information Foundation

**Branch**: `001-multi-tenant-student-info` | **Date**: 2026-03-08

---

## 1. Multi-Tenancy Strategy

### Decision: PostgreSQL Schema-Per-Tenant

**Chosen approach**: Each school gets its own PostgreSQL schema named `school_{tenantId}` inside the single `education_flow` database. All student, class, section, subject, and staff data live in the tenant schema. The `public` schema holds only platform-level data (the `tenants` table).

**Rationale**:
- **Strong isolation**: Native PostgreSQL `search_path` mechanism ensures queries can never cross schema boundaries without an explicit schema-qualified reference.
- **Single database**: Simpler operational overhead than per-database multi-tenancy; one connection pool, one Docker container, one backup job.
- **Prisma compatibility**: Prisma supports dynamic schema switching via the `search_path` connection string option (`?schema=school_abc`). A fresh `PrismaClient` per request with the correct `search_path` achieves full isolation.
- **Migration scalability**: For Phase 1 (small number of schools), tenant schema migrations can be applied in sequence. A migration runner iterates all tenant schemas and applies migrations.

**Alternatives considered**:

| Strategy | Why Rejected |
|---|---|
| Row-level tenancy (single schema, `tenant_id` column everywhere) | Risk of forgotten `WHERE tenant_id = ?` leaking data; no native DB-level isolation boundary |
| Database-per-tenant | Higher operational cost; connection pool explosion with many schools; overkill for Phase 1 |
| ORM-level virtual tenancy (shared schema, Prisma middleware) | More complex middleware; relies on application-level guarantees rather than DB guarantees |

---

## 2. Prisma Dynamic Schema Switching

### Decision: New PrismaClient per Request via `search_path`

**Pattern**:
```
PrismaClient({ datasourceUrl: `${BASE_URL}?schema=school_${tenantId}` })
```

The `TenantMiddleware` resolves the tenant from the subdomain and stores the `schemaName` on the request. A `PrismaService` factory creates and caches a `PrismaClient` instance per `schemaName`. Client instances are cached in a `Map<schemaName, PrismaClient>` to avoid reconnection overhead on every request.

**Rationale**: Prisma v7 supports `datasourceUrl` override at client instantiation. This is simpler and more reliable than raw SQL `SET search_path TO` statements which have connection-pooling risks.

**Risk**: If connection pooling (PgBouncer) is added later, `search_path` persistence across pooled connections must be validated. For Phase 1 with direct connections, this is safe.

---

## 3. Tenant Middleware Design

### Decision: NestJS Functional Middleware + Global Registration with Exclusions

**Pattern**:
1. `TenantMiddleware` extracts the subdomain from `req.hostname`.
2. Looks up the tenant in `public.tenants` table (via a dedicated `GlobalPrismaService` using the `public` schema).
3. On match: attaches `tenantId` and `schemaName` to `req` object.
4. On no match: returns `404 { message: 'School not found' }` immediately.
5. Routes excluded: `/api/health`, auth routes handled by pre-provisioning only.

**Subdomain extraction** (development vs. production):
- Development: `localhost` has no subdomain → use `X-Tenant-ID` header for testing.
- Production: extract first segment of `req.hostname` (e.g., `sunrise` from `sunrise.educationflow.pk`).

---

## 4. JWT Authentication Strategy

### Decision: Passport-local + JWT Strategy (NestJS standard)

**Packages**: `@nestjs/passport`, `passport-local`, `passport-jwt`, `@nestjs/jwt`.

**Token structure**:
```json
{
  "sub": "userId",
  "role": "Clerk",
  "tenantId": "abc123",
  "schemaName": "school_abc123",
  "iat": 1234567890,
  "exp": 1234568790
}
```

**Token lifetimes**:
- Access token: 15 minutes
- Refresh token: 7 days (stored in HTTP-only cookie)

**Guards**:
- `JwtAuthGuard` — validates token signature and expiry; applied globally.
- `RolesGuard` — checks `req.user.role` against `@Roles()` decorator metadata.

---

## 5. Staff Account Creation (Onboarding Flow)

### Decision: Two-phase onboarding

**Phase 1 — School Registration (Platform Admin)**:
- A platform admin (outside this feature scope) registers the school tenant via a seed script or admin CLI.
- This creates the `tenants` record in `public` and provisions the `school_{tenantId}` schema.
- A Principal account is created in the same operation with a system-generated temporary password.

**Phase 2 — In-App Staff Creation (Principal)**:
- Principal logs in and creates Clerk/Teacher accounts via the `POST /api/staff` endpoint.
- Temporary password is set; `mustChangePassword: true` flag is stored on the `StaffUser` record.
- On next login, if `mustChangePassword === true`, the auth flow redirects to a forced password change screen before any other screen.

---

## 6. B-Form Uniqueness Among Active Records

### Decision: Unique constraint on active records only via `deletedAt` null check

**Implementation**: No partial unique index in Prisma schema (Prisma does not support partial indexes directly). Instead:
- A unique index `@@unique([bFormNumber, schoolSchema])` is NOT used.
- Instead, the `StudentsService.create()` checks for existing active records with the same B-Form **at the service layer** before insert.
- A database-level unique partial index can be added manually via a raw migration: `CREATE UNIQUE INDEX students_bform_active_unique ON students (b_form_number) WHERE deleted_at IS NULL;`
- This raw migration is added as a `-- raw SQL --` step in the Prisma migration file after `npx prisma migrate dev` generates the base migration.

---

## 7. Password Hashing

### Decision: bcrypt via `bcryptjs`

**Package**: `bcryptjs` (pure JS, no native bindings needed).
**Salt rounds**: 10 (good balance of security vs. performance for authentication use case).
**Storage**: `passwordHash` column on `StaffUser` table; raw password is never stored or logged.

---

## 8. Phone Number Storage

### Decision: Store without dashes, display with dashes

**Storage format**: `03211234567` (digits only, 11 characters).
**Display format**: `0321-1234567` (formatted on read).
**Reason**: Consistent storage simplifies searching, sorting, and SMS sending integrations. Formatting is a presentation concern.

---

## 9. Class Structure

### Decision: Fully school-configurable, no seeded reference data

Classes and sections are created by the Clerk as simple name strings. The spec originally mentioned seeded Pakistani class names — this is dropped in favour of full configurability. The Clerk types the class name (e.g., "Class 5" or "Matric") and the system stores it as-is. No enum or validation on class name; only uniqueness per school.

---

## 10. Resolved Unknowns Summary

| Unknown | Resolution |
|---|---|
| Multi-tenancy isolation mechanism | Schema-per-tenant via `search_path` |
| Prisma schema switching | `PrismaClient` per tenant, cached by `schemaName` |
| Tenant identification | Subdomain in production; `X-Tenant-ID` header in development |
| JWT structure | Includes `role`, `tenantId`, `schemaName` |
| Staff onboarding mechanism | Platform admin creates Principal; Principal creates all others |
| B-Form uniqueness boundary | Active records only; enforced via service-layer check + raw partial index |
| Class/section seeding | No seeding — fully Clerk-configured per school |
| Password hashing | `bcryptjs`, 10 salt rounds |
| Phone storage | Digits-only storage, dashes added on display |
