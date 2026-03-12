# Feature Specification: Multi-Tenant Student Information Management Foundation

**Feature Branch**: `001-multi-tenant-student-info`  
**Created**: 2026-03-07  
**Status**: Draft  
**Input**: User description: "Read the constitution and implement the basic multi-tenant foundation of our system for managing the student information"

---

## Overview

This feature establishes the foundational data layer and management capability for student information within a multi-tenant school management system. Each school (tenant) operates in complete isolation — their student records are visible only to their own staff. This is the core module that all attendance, examination, and reporting features will build upon.

**Scope of this feature:**
- Multi-tenancy infrastructure (tenant resolution, schema isolation)
- Student record creation, retrieval, update, and soft-deletion
- Guardian (parent) information linked to students
- Pakistani-specific validations (B-Form, phone, gender, religion, class/section structure)
- Role-based access for Principal, Clerk, and Teacher

**Out of scope (future features):**
- Document uploads (e.g., student B-Form scans) — File Upload module
- Attendance marking — Attendance module
- Fee management — Fee module
- SMS notifications — Phase 2
- Student photo uploads — File Upload module

---

## User Scenarios & Testing *(mandatory)*

### User Story 1 — Clerk Admits a New Student (Priority: P1)

A school Clerk opens the system on the school's subdomain (e.g., `greenwood.educationflow.pk`) and fills out the student admission form. They enter the student's full name, B-Form number, date of birth, gender, religion, class, section, residential address, and guardian information — including the guardian's full name, their relationship to the student (Father, Mother, Guardian, etc.), CNIC, and phone number. The system validates all Pakistani-specific fields in real time, prevents duplicate B-Form numbers within the same school, and saves the student record under the correct school's isolated data store.

**Why this priority**: Student admission is the entry point for all downstream operations (attendance, marks, report cards). Without it, nothing else works.

**Independent Test**: Fully testable by having a Clerk-role user fill out and submit the admission form, then verifying the student appears in the student list. Delivers the core value: a digitized student register.

**Acceptance Scenarios**:

1. **Given** a Clerk is logged in on `school-a.educationflow.pk`, **When** they submit the admission form with valid Pakistani fields, **Then** the student record is created and visible in the student list for School A only.
2. **Given** a Clerk tries to register a student with a B-Form number already registered at the same school, **When** they submit the form, **Then** the system rejects it with a clear "B-Form number already registered" error.
3. **Given** a Clerk submits a form with an invalid B-Form format (e.g., `1234-123-1` instead of `12345-1234567-1`), **When** they try to submit, **Then** the form shows an inline validation error before submission.
4. **Given** a Clerk is logged in on `school-a.educationflow.pk`, **When** they view the student list, **Then** they see ONLY students from School A — no students from School B appear.
5. **Given** a Phone number is entered without dashes (e.g., `03211234567`), **When** the form is submitted, **Then** the system reformats and stores it correctly, displaying as `0321-1234567`.

---

### User Story 2 — Principal Views and Searches the Student Directory (Priority: P2)

A Principal logs in and views a paginated list of all students in their school. They can filter by class, section, or search by student name or B-Form number to quickly locate a specific record.

**Why this priority**: The student directory is the primary navigation hub for all school management tasks. Principals need rapid access to any student's record.

**Independent Test**: Testable by logging in as a Principal, viewing the student list, and using the search/filter controls. Delivers value as a functional digital student register with search.

**Acceptance Scenarios**:

1. **Given** a Principal is logged in, **When** they open the student directory, **Then** all students of their school are displayed in a paginated list (20 per page by default).
2. **Given** the directory is open, **When** the Principal filters by "Class 5, Section A", **Then** only students in Class 5A of their school are shown.
3. **Given** the directory is open, **When** the Principal types a student's name in the search box, **Then** matching results appear within one second.
4. **Given** a Teacher is logged in, **When** they open the student directory, **Then** they only see students from their assigned sections, not the entire school roster.

> **Staff Management Rights** *(for role-model completeness — implemented in the Staff Management module)*:
> - **Principal**: Can view the full staff list AND delete staff accounts.
> - **Clerk**: Can view the full staff list but **cannot** delete staff accounts.
> - **Teacher**: No access to staff management whatsoever.
>
> Delete rights for staff are exclusively reserved for the Principal. This permission model MUST be enforced at the API level and captured in the Staff Management module spec.

---

### User Story 3 — Clerk Views and Edits an Existing Student's Profile (Priority: P2)

A Clerk selects a student from the list to view their full profile, which includes personal details and guardian information. They can edit any field (e.g., update a phone number or correct a date of birth), and changes are saved immediately.

**Why this priority**: Data accuracy is critical for report cards, SMS notifications, and compliance. Clerks routinely need to update records as student information changes.

**Independent Test**: Testable by opening an existing student record, modifying a field (e.g., correcting a phone number), saving, and verifying the change persists on reload.

**Acceptance Scenarios**:

1. **Given** a Clerk opens a student's profile, **When** they update the guardian's phone number, **Then** the change is saved and the new number is displayed on reload.
2. **Given** a Clerk tries to update a student's B-Form to one already registered at the school, **When** they save, **Then** the system rejects the change with a conflict error.
3. **Given** a Teacher opens a student profile in their section, **When** they view it, **Then** the edit controls are NOT visible — they can view but not modify.

---

### User Story 4 — Principal Soft-Deletes a Student Record (Priority: P3)

A Principal removes a student who has left the school. The student is marked as inactive and no longer appears in the active student list, but their record is retained in the system for historical reporting.

**Why this priority**: Deleted students' historical data (attendance, marks, report cards) must remain intact for reporting purposes. Only the Principal can perform this action.

**Independent Test**: Testable by soft-deleting a student as Principal, verifying they disappear from the active list, and confirming their record remains accessible in an "inactive" or "archived" view.

**Acceptance Scenarios**:

1. **Given** a Principal removes a student, **When** they view the active student directory, **Then** the student no longer appears.
2. **Given** a student is soft-deleted, **When** an admin queries historical data, **Then** the student record and all linked data (attendance, marks) remain intact.
3. **Given** a Clerk is logged in, **When** they try to delete a student, **Then** the delete option is not available — the action is restricted to Principal only.
4. **Given** a student was previously enrolled, left, and was soft-deleted, **When** the same student re-enrolls in a new class with the same B-Form, **Then** the system ALLOWS the new enrollment — a returning student is a legitimate new active record.
5. **Given** two distinct students have the same B-Form (data entry error) and both are currently active, **When** the second one is submitted, **Then** the system rejects it as a duplicate.

---

### User Story 5 — Tenant Onboarding (School Registration) (Priority: P1)

A new school is registered on the platform. A dedicated school record is created in the global data store with a unique subdomain identifier, and a fully isolated data schema is provisioned for that school. All subsequent operations for that school are scoped to this schema.

**Why this priority**: Without tenant onboarding, no school can use the system. This is the bootstrapping operation that must work before any student data can be managed.

**Independent Test**: Testable by running the tenant provisioning process and verifying that the new school's subdomain resolves, a staff member can log in, and no data from other schools appears.

**Acceptance Scenarios**:

1. **Given** a new school is onboarded with subdomain `sunrise`, **When** a staff member logs in at `sunrise.educationflow.pk`, **Then** they see an empty student list specific to their school.
2. **Given** School A and School B both have students, **When** a user of School A accesses any endpoint, **Then** the response contains only School A's data, never School B's.
3. **Given** a request arrives without a valid tenant subdomain, **When** it hits any protected endpoint, **Then** the system returns a 400 or 404 response with a clear "School not found" message.

---

### User Story 6 — Staff Account Onboarding (Priority: P1)

When a new school is onboarded, the Principal's account is created first as part of the school registration process. That Principal then logs in and issues invites to create Clerk and Teacher accounts from within the system. Each staff account is tied to the school's tenant, assigned a role, and receives an invite email to set up their credentials.

**Why this priority**: Without staff accounts, no one can log in or operate the system. The Principal is the first user; all other accounts flow from them via secure invites.

**Independent Test**: Testable by completing the onboarding sequence — Principal account exists after school registration, Principal sends an invite to a Clerk email, Clerk clicks the link, sets their password, and can immediately log in and access their permitted features.

**Acceptance Scenarios**:

1. **Given** a new school is registered on the platform, **When** onboarding completes, **Then** a Principal account is created with login credentials scoped to that school's subdomain.
2. **Given** a Principal is logged in, **When** they invite a new Clerk account (providing name, CNIC, phone, email, and role), **Then** the system sends an email with a secure invite link to the Clerk.
3. **Given** an invited user clicks their invite link, **When** they complete the setup by choosing a password, **Then** they can log in at the school's subdomain.
4. **Given** a Principal creates a new Teacher account, **When** the Teacher logs in, **Then** they can access their account but see no students until they are assigned to a class-section through the Academics module.
5. **Given** a Clerk is logged in, **When** they attempt to create another staff account or send an invite, **Then** the system rejects it — only Principals can invite staff.
6. **Given** a Principal tries to invite a second Principal account for the same school, **When** they submit, **Then** the system allows it — a school may have more than one Principal-role user.

---

### User Story 7 — Clerk Configures Classes, Sections, and Subjects (Priority: P1)

After a school is onboarded, a Clerk (or Principal) sets up the school's academic structure before any students can be admitted. They create the classes the school uses (e.g., only Nursery to Class 8 for a primary school), add sections to each class (e.g., A and B), and define the subjects taught in each class independently. Different classes can have entirely different subject lists — for example, Class 1 may have Urdu, English, Maths, and Islamiyat, while Class 9 may have Physics, Chemistry, Biology, and Computer Science. No subjects are hardcoded — every school configures its own.

**Why this priority**: Without classes, sections, and subjects defined, student admission cannot be completed (a student must be assigned to a class and section), and exam/mark entry has no structure to attach to.

**Independent Test**: Testable by creating a class with two sections and assigning different subject lists to each, then verifying that the admission form presents only the configured classes and sections.

**Acceptance Scenarios**:

1. **Given** a Clerk is logged in, **When** they create a new class (e.g., "Class 5") and add sections "A" and "B", **Then** "Class 5A" and "Class 5B" appear as options on the student admission form.
2. **Given** a Clerk adds a subject "Islamiyat" to Class 3, **When** they view Class 5's subject list, **Then** "Islamiyat" does NOT appear there — subjects are per-class, not global.
3. **Given** two schools are configured differently — School A has Class 9 with Physics while School B does not — **When** a user of School A views their subjects, **Then** they see Physics; School B's configuration is unaffected.
4. **Given** a Clerk removes a subject from a class, **When** staff tries to enter marks for that subject, **Then** the subject no longer appears as an option for mark entry.
5. **Given** a Teacher is logged in, **When** they attempt to add or remove a subject from a class, **Then** the system rejects it — only Principals and Clerks may configure subjects.
6. **Given** a class has no sections yet, **When** a Clerk tries to assign a student to that class, **Then** the system prevents it and prompts the Clerk to create a section first.

---

### Edge Cases

- **No students enrolled yet**: The student list displays an empty state with a prompt to add the first student, not an error.
- **Class with no sections defined**: Students cannot be assigned to a class unless at least one section exists for it. Form must enforce this dependency.
- **B-Form format enforcement**: B-Form validation fires on field blur, not only on form submit, so the user gets immediate feedback.
- **Phone number without dashes**: The system auto-formats `03211234567` → `0321-1234567` on input normalization; both input formats should be accepted and stored consistently.
- **Tenant subdomain with no match**: Requests to unknown subdomains receive a clear `404 School Not Found` response.
- **Concurrent duplicate B-Form submissions**: System must handle two simultaneous admissions with the same B-Form (race condition) — only one should succeed; the second returns a conflict error.
- **Teacher accessing students outside assigned section**: Must return a `403 Forbidden` response, not a filtered empty list (to avoid confusion).
- **Returning student re-enrollment**: A student who left (soft-deleted) and returns later CAN be re-enrolled with the same B-Form — B-Form uniqueness is enforced among **active** students only. The new enrollment creates a fresh active record; the historical soft-deleted record is preserved separately.
- **Pagination boundary**: Requesting page 10 when only 5 pages of data exist returns an empty `data: []` with total count, not an error.

---

## Requirements *(mandatory)*

### Functional Requirements

#### Tenant Infrastructure
- **FR-001**: System MUST resolve the tenant from the subdomain of every incoming request and attach the tenant context to the request lifecycle.
- **FR-002**: System MUST reject all requests to protected routes where the subdomain does not match a registered school, returning a clear error response.
- **FR-003**: System MUST isolate all student data per school — queries for one school MUST NEVER return data from another school.
- **FR-004**: System MUST provision a separate data schema for each school upon onboarding.

#### Student Records
- **FR-005**: System MUST allow users with the Principal or Clerk role to create a new student record with the required fields.
- **FR-006**: System MUST validate the B-Form number (`DDDDD-DDDDDDD-D` format) on every create and update operation.
- **FR-007**: System MUST enforce uniqueness of B-Form number among **active** student records within a school. A returning student whose previous record is soft-deleted MUST be permitted to re-enroll with the same B-Form.
- **FR-008**: System MUST validate the guardian's phone number in `03xx-xxxxxxx` format.
- **FR-009**: System MUST accept gender values of: Male, Female, Other.
- **FR-010**: System MUST accept religion values of: Muslim, Christian, Hindu, Other.
- **FR-011**: System MUST accept class values matching the Pakistani class structure (Playgroup through Class 12/FSc Part 2).
- **FR-012**: System MUST allow a student to be assigned to a specific section within a class.
- **FR-013**: System MUST allow users with Principal or Clerk role to update any field of a student record.
- **FR-014**: System MUST restrict Teachers to view-only access for student records in their assigned sections.
- **FR-015**: System MUST restrict Teachers so they cannot view students outside their assigned sections.
- **FR-016**: System MUST allow only Principals to soft-delete a student record.
- **FR-017**: System MUST retain all data linked to a soft-deleted student record (attendance, marks, etc.).
- **FR-018**: System MUST return paginated student lists with support for filtering by class and section, and search by name or B-Form.

#### Guardian Information
- **FR-019**: System MUST collect the following for at least one guardian per student: full name, relationship to student (Father / Mother / Guardian / Other), primary phone number, and CNIC (`DDDDD-DDDDDDD-D` format).
- **FR-020**: System MUST validate the guardian's CNIC format (`DDDDD-DDDDDDD-D`).
- **FR-021**: System MUST allow storing an optional secondary phone number for the guardian, subject to the same `03xx-xxxxxxx` format validation.
- **FR-022**: System MUST accept relationship values of: Father, Mother, Guardian, Other.

#### Student Address
- **FR-023**: System MUST collect the student's residential address, comprising: house/street, area/mohallah, city, and province.
- **FR-024**: City and Province are free-text fields; no fixed enum is enforced in Phase 1 to accommodate Pakistan's diverse geography.

#### Staff Onboarding
- **FR-027**: System MUST create a Principal account as part of the school onboarding process; no school subdomain can be used without at least one Principal account.
- **FR-028**: System MUST allow only Principals to send invites for new staff accounts (Clerk or Teacher) within their school.
- **FR-029**: System MUST require the following fields when inviting a staff account: full name, CNIC (`DDDDD-DDDDDDD-D`), phone number (`03xx-xxxxxxx`), mandatory email address, and role (Principal / Clerk / Teacher). No class or section assignment is done at account creation time.
- **FR-030**: System MUST send a secure, single-use invite link to the provided email address, allowing the invited user to set their password.
- **FR-031**: System MUST allow Principals and Clerks to view the full staff list; only Principals may delete a staff account or revoke/resend pending invites.
- **FR-034**: A Teacher account with no class-section assignments yet MUST be a valid state — the system shows an empty student view, not an error. Class-section assignments are managed separately in the Academics module.

#### Subject Configurability
- **FR-035**: System MUST allow Principals and Clerks to create, rename, and remove subjects within any class of their school.
- **FR-036**: Subjects MUST be scoped per class — adding a subject to Class 5 does NOT add it to Class 6 or any other class.
- **FR-037**: Each school defines its own subject list independently — no global or cross-tenant subject list exists.
- **FR-038**: System MUST allow a class to have zero subjects configured (valid transitional state during setup), but the student admission form MUST warn the Clerk if the selected class has no subjects yet.
- **FR-039**: Teachers MUST NOT be able to add, edit, or remove subjects — this permission is restricted to Principal and Clerk roles only.
- **FR-040**: Removing a subject from a class MUST be blocked if there are existing exam mark records linked to that subject, to prevent data loss. The Clerk must be shown a clear message listing the conflict.

#### Audit & Integrity
- **FR-032**: System MUST record the date and time of student record creation and last modification.
- **FR-033**: System MUST record which staff user created and last modified each student record.

### Key Entities

- **Tenant (School)**: Represents a registered school. Has a unique subdomain identifier, school name, and provisioning status. Global entity, not scoped to a tenant schema.
- **Student**: Core entity within a tenant schema. Has personal details (name, date of birth, gender, religion, B-Form), residential address (house/street, area, city, province), admission metadata (admission date, class, section), and a link to one or more guardians. Supports soft deletion.
- **Guardian**: Linked to one student. Holds full name, relationship to student (Father / Mother / Guardian / Other), CNIC, primary phone number, and optional secondary phone number.
- **Class**: Represents a grade level configured per school (e.g., Class 5, Nursery). Schools can choose which classes to activate — no class is hardcoded as mandatory.
- **Section**: A subdivision of a class (e.g., Class 5A). One or more sections can be added to any class. Configured per school.
- **Subject**: Represents a subject taught within a specific class (e.g., "Maths" in Class 5). Subjects are configured individually per class by the school. The same subject name may exist in multiple classes but are treated as independent records. No global subject list.

---

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A Clerk can complete a full student admission form in under 3 minutes from opening the form to receiving a confirmation.
- **SC-002**: The student directory search returns results in under 1 second for schools with up to 2,000 active students.
- **SC-003**: 100% of student records across all tenants remain strictly isolated — zero cross-tenant data leakage in any query or API response.
- **SC-004**: 100% of B-Form duplicates within a school are rejected at the point of entry — no duplicate B-Forms can be persisted for active or inactive students.
- **SC-005**: Tenant subdomain resolution succeeds for every valid school request, and fails with a clear error for every invalid subdomain — 0% false positives or silent failures.
- **SC-006**: The paginated student list loads within 2 seconds for the largest class/section filter (up to 500 students in a single section).
- **SC-007**: Role-based access is enforced on all endpoints — a Teacher MUST NOT be able to access or modify student records outside their assignments under any conditions, including direct API calls.
- **SC-008**: All Pakistani validation rules (B-Form, CNIC, phone format) are enforced both in the UI (inline, on blur) and on the server side — server-side validation alone is a complete safety net.

---

## Assumptions

- Authentication (login, JWT issuance, role assignment) is implemented as a prerequisite or parallel feature. This spec assumes JWTs carry `userId`, `role`, and `tenantId` claims.
- Classes, Sections, and Subjects are configured BY the Clerk within this same feature — there is no external dependency or seed data required. A school starts with zero classes and builds its structure from scratch.
- No student photo upload in this phase — photo field may be left empty.
- Admission date defaults to the current date if not explicitly provided.
- Guardian CNIC is mandatory; however, if it is genuinely unavailable (e.g., for foreign guardians), the Clerk can enter a placeholder approved value — this is a Clerk-level override, not a system bypass.

---

## Scope Boundaries

| In Scope | Out of Scope |
|---|---|
| Tenant provisioning & schema isolation | Fee management |
| Student CRUD (create, read, update, soft-delete) | Document / photo upload |
| Guardian information (name, relationship, CNIC, phone) | Attendance marking |
| Student residential address | Examination and marks |
| Role-based access control for 3 roles | Report card generation |
| Pakistani field validation | SMS notifications |
| Class & Section configuration (by Clerk per school) | Bulk student import (CSV) |
| Subject configuration (per class, per school, by Clerk) | Student transfer between schools |
| Pagination & search | Staff management (captured in Staff Management module) |
| Staff onboarding (Principal creates Clerk/Teacher accounts) | | 
| Audit trail (who/when) | |

---

## Environment & Configuration Requirements

To support this module (especially tenant provisioning and the email-based invite system), the following environment variables (or equivalent secrets) MUST be configured in the operating environment:

### Database & Security
- `DATABASE_URL` — Connection string for the PostgreSQL database (handling multi-tenant schemas).
- `JWT_SECRET` — Secret key used to sign and verify authentication tokens (must support tenant-based claims).

### Email / SMTP Configuration (for Invites/Password Resets)
- `SMTP_HOST` — Outer mail server host (e.g., `smtp.sendgrid.net` or `smtp.eu.mailgun.org`).
- `SMTP_PORT` — Mail server port (e.g., `587` or `465`).
- `SMTP_USER` — SMTP authentication username.
- `SMTP_PASSWORD` — SMTP authentication password or API key.
- `EMAIL_FROM_ADDRESS` — The default sender address for system emails (e.g., `noreply@educationflow.pk`).
- `FRONTEND_URL` — The base URL of the frontend application (e.g., `https://educationflow.pk`). This is required to construct the dynamic invite activation link (e.g., `https://{tenant}.educationflow.pk/activate?token=...`).
