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
│   └── test_digital_id.py     # Full pytest suite (45 tests)
├── main.py                    # Scripted demo walkthrough
├── requirements.txt
└── .github/workflows/ci.yml   # GitHub Actions CI
```

---

## Architecture and design patterns

### Command-Query Separation (CQS)

`IdentityManagementService` (write) and `IdentityConsumptionService` (read) are completely separate. They share a repository but never call each other.

### State Pattern

Status transitions enforce: ACTIVE <-> SUSPENDED <-> REVOKED (terminal). Invalid moves raise `InvalidStateTransition`. Same-to-same is idempotent.

### Strategy Pattern

Each organisation portal implements `VerificationStrategy`. Tax checks period suspension. DVLA checks restrictions. Bank returns boolean only. Adding a new portal requires only a new strategy class.

### Dependency Injection

Services receive `IdentityRepository` and `AuditLogger` via constructor — no global state.

### Immutability

`IdentityReadModel` and all DTO responses are `dataclass(frozen=True)`.
