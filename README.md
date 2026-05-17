# Digital ID Platform

A console-based backend system for managing federated digital identities across a multi-organisation ecosystem. The Central Authority creates and manages identities; consuming organisations (Tax, DVLA, Banks) verify them through role-specific portals without ever modifying identity data.

**GitHub repository:** https://github.com/aliadni456-dev/digital-id-platform

---

## Running the system

```bash
git clone https://github.com/aliadni456-dev/digital-id-platform.git
cd digital-id-platform
pip install -r requirements.txt
python main.py
pytest tests/ -v
```

---

## System structure

```
digital-id-platform/
├── src/
│   ├── domain/
│   │   ├── models.py          # DigitalID aggregate, IDStatus enum, IdentityReadModel DTO
│   │   ├── exceptions.py      # Custom exception hierarchy
│   │   └── state_machine.py   # Deterministic status transition rules
│   ├── repositories/
│   │   └── identity_repository.py  # Abstract repo + InMemory implementation
│   ├── services/
│   │   ├── management_service.py   # Write side — Central Authority only
│   │   └── consumption_service.py  # Read side — consuming organisations
│   ├── portals/
│   │   ├── base.py                       # VerificationStrategy ABC
│   │   ├── tax_portal.py                 # Tax period eligibility check
│   │   ├── driving_licence_portal.py     # Restriction-aware licence check
│   │   └── bank_portal.py                # Boolean-only validity check
│   ├── audit/
│   │   └── audit_logger.py    # Central audit event log
│   └── dtos/
│       └── responses.py       # Frozen DTO response models
├── tests/
│   └── test_digital_id.py     # Full pytest suite (~45 tests)
├── main.py                    # Scripted demo walkthrough
├── requirements.txt
└── .github/workflows/ci.yml   # GitHub Actions CI
```

---

## Architecture and design patterns

### Command-Query Separation (CQS)

Identity management (create, update, status changes) and identity consumption (lookup, verify) are implemented as two completely separate services: `IdentityManagementService` and `IdentityConsumptionService`. They share a repository but never call each other. This prevents write-side logic from leaking into read paths and vice versa.

### State Pattern — `IdentityStateMachine`

Each `DigitalID` has one of three statuses: `ACTIVE`, `SUSPENDED`, or `REVOKED`. A static transition table defines which moves are legal:

| From      | To        | Allowed |
|-----------|-----------|---------|
| ACTIVE    | SUSPENDED | Yes     |
| ACTIVE    | REVOKED   | Yes     |
| SUSPENDED | ACTIVE    | Yes     |
| SUSPENDED | REVOKED   | Yes     |
| REVOKED   | *any*     | **No — terminal state** |

Repeating a same-to-same transition is silently accepted (idempotent). Any other invalid move raises `InvalidStateTransition`.

### Strategy Pattern — Organisation Portals

Each consuming organisation provides its own `VerificationStrategy` implementation. The `IdentityConsumptionService.verify()` method accepts any strategy and returns a portal-specific frozen DTO. Adding a new organisation portal requires only a new strategy class — no changes to the service layer.

| Portal | Strategy | Response DTO |
|--------|----------|--------------|
| Tax Service | `TaxVerificationStrategy` | `TaxVerificationResponse` (includes period suspension check) |
| DVLA | `DrivingLicenceVerificationStrategy` | `DrivingLicenceVerificationResponse` (includes restriction flag) |
| Bank / Employer | `BankVerificationStrategy` | `BankVerificationResponse` (boolean only — no identity attributes) |

### Dependency Injection

Services receive their `IdentityRepository` and `AuditLogger` through constructor arguments. Nothing is hardcoded or global. This keeps tests clean — each test creates a fresh repo and logger, so there is no shared state between tests.

### Immutability

`IdentityReadModel` and all DTO response objects are `dataclass(frozen=True)`. Consuming organisations receive these objects and cannot accidentally or deliberately mutate identity data through them.

The `DigitalID` aggregate itself is mutable (so the management service can apply updates), but its core fields (`national_number`, `full_name`, `date_of_birth`, `nationality`) are enforced as immutable at the service layer: any attempt to update them triggers an `ImmutableAttributeViolation` exception.

### Exception hierarchy

```
DigitalIDException
├── InvalidStateTransition
├── UnauthorizedAccess
├── IdentityNotFound
└── ImmutableAttributeViolation
```

All exceptions carry structured fields (e.g. `current`, `target`, `organisation`, `attribute`) so callers can inspect them programmatically rather than parsing strings.

---

## Continuous Integration

GitHub Actions runs on every push. The workflow installs dependencies and runs the full pytest suite with coverage reporting. See `.github/workflows/ci.yml`.
