# Sprint Backlog — Digital ID Platform

Tracked iteratively across four development sprints, mapped to the Git commit history.

---

## Sprint 1 — Core Domain & State Machine
**Dates:** 5 May – 8 May 2026
**Goal:** Establish the foundational domain model, enforce identity immutability, and implement the deterministic state machine.

| ID | User Story | Acceptance Criteria | Tasks | Status |
|----|------------|---------------------|-------|--------|
| US-01 | As the Central Authority, I want to represent a Digital ID with both immutable and mutable attributes so that core identity fields cannot be accidentally changed. | `DigitalID` dataclass exists with typed fields; `IdentityReadModel` is frozen. | Define `IDStatus` enum; implement `DigitalID`; add `IdentityReadModel` frozen DTO | Done |
| US-02 | As the system, I want status transitions to be deterministic so that a Digital ID can never reach an invalid state. | `REVOKED` is terminal; `ACTIVE<->SUSPENDED` is bidirectional; same-to-same is idempotent; invalid transitions raise `InvalidStateTransition`. | Implement `IdentityStateMachine` with transition table; add edge-case handling | Done |
| US-03 | As a developer, I want a clear exception hierarchy so that callers can handle different failure modes programmatically. | `DigitalIDException` base class; four typed subclasses with structured fields. | Define exception hierarchy in `exceptions.py` | Done |

**Commits:** 5 May 09:12 -> 8 May 09:30 (commits 1-14)

---

## Sprint 2 — Services, Strategy Pattern & Audit
**Dates:** 9 May – 12 May 2026
**Goal:** Implement the CQS service split, DI-wired portals, and a central audit logger.

| ID | User Story | Acceptance Criteria | Tasks | Status |
|----|------------|---------------------|-------|--------|
| US-04 | As the Central Authority, I want a management service that is the sole writer of identity data, so that consuming organisations cannot modify identities. | `IdentityManagementService` rejects any actor that is not `central_authority`; all write methods are unavailable to consumers. | Implement `create_identity`, `update_address`, `set_temporary_restriction`, `change_status`; add `UnauthorizedAccess` guard | Done |
| US-05 | As a consuming organisation, I want to verify identities through a portal that applies my domain rules, without receiving more information than I need. | Each portal returns a distinct frozen DTO; bank portal returns boolean only. | Implement `VerificationStrategy` ABC; implement Tax, DVLA, Bank strategies | Done |
| US-06 | As the system operator, I want all key operations to be recorded in an audit log so that system behaviour can be examined after the fact. | Every create, update, status change, lookup, and verification call produces an `AuditEvent`; events are filterable by subject ID. | Implement `AuditLogger`, `AuditEvent` frozen dataclass, `AuditEventType` enum | Done |
| US-07 | As a developer, I want all services to receive their dependencies via constructor injection so that test isolation is clean. | No global state; each test can create fresh repo + logger instances independently. | Inject `IdentityRepository` and `AuditLogger` into both services | Done |

**Commits:** 9 May 09:00 -> 12 May 09:30 (commits 15-24)

---

## Sprint 3 — Console Demo & Rejection Scenarios
**Dates:** 13 May – 14 May 2026
**Goal:** Produce a self-running demo script that clearly demonstrates all system behaviours for video assessment.

| ID | User Story | Acceptance Criteria | Tasks | Status |
|----|------------|---------------------|-------|--------|
| US-08 | As an assessor, I want to see a complete identity lifecycle demonstrated without manual interaction so that system behaviour is unambiguous. | `main.py` runs end-to-end without errors, covers creation, updates, transitions, all three portals, and an audit summary. | Implement scripted demo with section banners; add all four phases | Done |
| US-09 | As an assessor, I want to see rejection scenarios clearly labelled so that I can verify that the system enforces its rules correctly. | Each rejection prints `[REJECTED]` with the exception message; immutable update, unauthorised access, and invalid transitions are all shown. | Add rejection demos for immutable attributes, external-actor creation, post-revocation updates, and invalid state transitions | Done |

**Commits:** 13 May 09:15 -> 14 May 15:00 (commits 25-28)

---

## Sprint 4 — Testing, CI & Documentation
**Dates:** 15 May – 18 May 2026
**Goal:** Deliver a comprehensive pytest suite, a working CI pipeline, and professional documentation.

| ID | User Story | Acceptance Criteria | Tasks | Status |
|----|------------|---------------------|-------|--------|
| US-10 | As a developer, I want unit tests for all state transitions so that regressions in the state machine are caught automatically. | Tests cover all valid transitions, all invalid transitions, idempotency, and terminal-state detection. | Write `TestStateMachine` class with 11 test cases | Done |
| US-11 | As a developer, I want tests for each organisation portal so that verification logic is independently verified. | Each portal has tests for eligibility, ineligibility, and DTO immutability. | Write `TestTaxVerificationStrategy`, `TestDrivingLicenceVerificationStrategy`, `TestBankVerificationStrategy` | Done |
| US-12 | As a developer, I want CI to run automatically on every push so that the test suite is always verified against the latest code. | GitHub Actions workflow installs dependencies and runs pytest; all tests pass. | Write `.github/workflows/ci.yml`; verify locally with `pytest tests/ -v` | Done |
| US-13 | As a reader, I want a README that clearly explains the architecture and design decisions so that the system structure is understandable without reading all the code. | README covers: running the system, directory structure, CQS, State Pattern, Strategy Pattern, DI, immutability, exception hierarchy, CI. | Write `README.md` with architecture section and pattern tables | Done |

**Commits:** 15 May 09:15 -> 18 May 14:00 (commits 29-41)

---

## Summary

| Sprint | Stories | Status |
|--------|---------|--------|
| 1 — Core Domain | US-01, US-02, US-03 | Complete |
| 2 — Services & Strategy | US-04, US-05, US-06, US-07 | Complete |
| 3 — Console Demo | US-08, US-09 | Complete |
| 4 — Testing & CI | US-10, US-11, US-12, US-13 | Complete |
