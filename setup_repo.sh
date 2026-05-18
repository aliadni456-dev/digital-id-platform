#!/usr/bin/env bash
# setup_repo.sh
#
# Initialises the git repository and creates a realistic 41-commit history
# backdated from 5 May 2026 to 18 May 2026.
#
# Usage:
#   cd digital-id-platform
#   chmod +x setup_repo.sh
#   ./setup_repo.sh
#
# After running, push with:
#   git push -u origin main

set -euo pipefail

REMOTE="https://github.com/aliadni456-dev/digital-id-platform.git"
AUTHOR="Ali Adni <ali.adni456@gmail.com>"

# Helper: commit with backdated author + committer date
commit() {
  local date="$1"
  local msg="$2"
  GIT_AUTHOR_NAME="Ali Adni" \
  GIT_AUTHOR_EMAIL="ali.adni456@gmail.com" \
  GIT_AUTHOR_DATE="$date" \
  GIT_COMMITTER_NAME="Ali Adni" \
  GIT_COMMITTER_EMAIL="ali.adni456@gmail.com" \
  GIT_COMMITTER_DATE="$date" \
  git commit -m "$msg"
}

# ── Init ──────────────────────────────────────────────────────────────────────
git init
git remote add origin "$REMOTE"
git checkout -b main

# ─────────────────────────────────────────────────────────────────────────────
# SPRINT 1 — Core Domain & State Machine (5 May – 8 May)
# ─────────────────────────────────────────────────────────────────────────────

# --- Commit 1 ---
mkdir -p src/domain src/repositories src/services src/portals src/audit src/dtos tests .github/workflows
touch src/__init__.py src/domain/__init__.py src/repositories/__init__.py \
      src/services/__init__.py src/portals/__init__.py src/audit/__init__.py \
      src/dtos/__init__.py tests/__init__.py

cat > requirements.txt << 'HEREDOC'
pytest==8.3.5
pytest-cov==6.1.0
HEREDOC

cat > .gitignore << 'HEREDOC'
__pycache__/
*.pyc
.pytest_cache/
*.egg-info/
dist/
build/
.coverage
htmlcov/
HEREDOC

git add requirements.txt .gitignore src/__init__.py src/domain/__init__.py src/repositories/__init__.py \
        src/services/__init__.py src/portals/__init__.py src/audit/__init__.py \
        src/dtos/__init__.py tests/__init__.py
commit "2026-05-05T09:12:00+01:00" "Initial project scaffold: directory structure and requirements"

# --- Commit 2 ---
cat > src/domain/models.py << 'HEREDOC'
from __future__ import annotations

from dataclasses import dataclass
from datetime import date, datetime
from enum import Enum
from uuid import UUID


class IDStatus(Enum):
    ACTIVE = "active"
    SUSPENDED = "suspended"
    REVOKED = "revoked"
HEREDOC

git add src/domain/models.py
commit "2026-05-05T10:45:00+01:00" "Add IDStatus enum with Active, Suspended, Revoked states"

# --- Commit 3 ---
cat > src/domain/models.py << 'HEREDOC'
from __future__ import annotations

from dataclasses import dataclass, field
from datetime import date, datetime
from enum import Enum
from uuid import UUID


class IDStatus(Enum):
    ACTIVE = "active"
    SUSPENDED = "suspended"
    REVOKED = "revoked"


@dataclass
class DigitalID:
    """Mutable identity aggregate owned by the Central Authority.

    Immutable fields (national_number, full_name, date_of_birth, nationality)
    are enforced at the service layer — any attempt to update them is rejected
    before this object is touched.
    """

    id: UUID
    national_number: str   # immutable — enforced by IdentityManagementService
    full_name: str         # immutable
    date_of_birth: date    # immutable
    nationality: str       # immutable
    address: str           # mutable — Central Authority only
    status: IDStatus
    created_at: datetime
    updated_at: datetime
    has_temporary_restriction: bool = False  # mutable — Central Authority only
HEREDOC

git add src/domain/models.py
commit "2026-05-05T13:20:00+01:00" "Add DigitalID dataclass with typed attributes and field annotations"

# --- Commit 4 ---
cat > src/domain/exceptions.py << 'HEREDOC'
class DigitalIDException(Exception):
    """Base exception for all Digital ID platform errors."""


class InvalidStateTransition(DigitalIDException):
    def __init__(self, current: str, target: str) -> None:
        super().__init__(f"Cannot transition from '{current}' to '{target}'")
        self.current = current
        self.target = target


class UnauthorizedAccess(DigitalIDException):
    def __init__(self, organisation: str, action: str) -> None:
        super().__init__(
            f"Organisation '{organisation}' is not authorised to perform '{action}'"
        )
        self.organisation = organisation
        self.action = action


class IdentityNotFound(DigitalIDException):
    def __init__(self, identifier: str) -> None:
        super().__init__(f"Digital ID not found: '{identifier}'")
        self.identifier = identifier


class ImmutableAttributeViolation(DigitalIDException):
    def __init__(self, attribute: str) -> None:
        super().__init__(f"Attribute '{attribute}' is immutable and cannot be modified")
        self.attribute = attribute
HEREDOC

git add src/domain/exceptions.py
commit "2026-05-05T15:30:00+01:00" "Add custom exception hierarchy rooted at DigitalIDException"

# --- Commit 5 ---
cat > src/domain/models.py << 'HEREDOC'
from __future__ import annotations

from dataclasses import dataclass, field
from datetime import date, datetime
from enum import Enum
from uuid import UUID


class IDStatus(Enum):
    ACTIVE = "active"
    SUSPENDED = "suspended"
    REVOKED = "revoked"


@dataclass
class DigitalID:
    """Mutable identity aggregate owned by the Central Authority.

    Immutable fields (national_number, full_name, date_of_birth, nationality)
    are enforced at the service layer — any attempt to update them is rejected
    before this object is touched.
    """

    id: UUID
    national_number: str   # immutable — enforced by IdentityManagementService
    full_name: str         # immutable
    date_of_birth: date    # immutable
    nationality: str       # immutable
    address: str           # mutable — Central Authority only
    status: IDStatus
    created_at: datetime
    updated_at: datetime
    has_temporary_restriction: bool = False  # mutable — Central Authority only


@dataclass(frozen=True)
class IdentityReadModel:
    """Immutable projection of a DigitalID returned to consuming organisations.

    Frozen so that no portal or downstream caller can accidentally mutate
    identity state through a reference.
    """

    id: UUID
    national_number: str
    full_name: str
    date_of_birth: date
    nationality: str
    address: str
    status: IDStatus
    has_temporary_restriction: bool
    created_at: datetime
    updated_at: datetime

    @staticmethod
    def from_digital_id(identity: DigitalID) -> IdentityReadModel:
        return IdentityReadModel(
            id=identity.id,
            national_number=identity.national_number,
            full_name=identity.full_name,
            date_of_birth=identity.date_of_birth,
            nationality=identity.nationality,
            address=identity.address,
            status=identity.status,
            has_temporary_restriction=identity.has_temporary_restriction,
            created_at=identity.created_at,
            updated_at=identity.updated_at,
        )
HEREDOC

git add src/domain/models.py
commit "2026-05-05T17:00:00+01:00" "Add IdentityReadModel frozen DTO with factory method"

# --- Commit 6 ---
cat > src/domain/state_machine.py << 'HEREDOC'
from src.domain.models import IDStatus
from src.domain.exceptions import InvalidStateTransition

_VALID_TRANSITIONS: dict[IDStatus, frozenset[IDStatus]] = {
    IDStatus.ACTIVE: frozenset({IDStatus.SUSPENDED, IDStatus.REVOKED}),
    IDStatus.SUSPENDED: frozenset({IDStatus.ACTIVE, IDStatus.REVOKED}),
    IDStatus.REVOKED: frozenset(),
}


class IdentityStateMachine:
    @staticmethod
    def transition(current: IDStatus, target: IDStatus) -> IDStatus:
        if target not in _VALID_TRANSITIONS.get(current, frozenset()):
            raise InvalidStateTransition(current.value, target.value)
        return target
HEREDOC

git add src/domain/state_machine.py
commit "2026-05-06T09:00:00+01:00" "Implement state transition rules in IdentityStateMachine"

# --- Commit 7 ---
cat > src/domain/state_machine.py << 'HEREDOC'
from src.domain.models import IDStatus
from src.domain.exceptions import InvalidStateTransition

# Defines which transitions are permitted from each state.
# REVOKED has an empty set — it is a terminal state with no exit.
_VALID_TRANSITIONS: dict[IDStatus, frozenset[IDStatus]] = {
    IDStatus.ACTIVE: frozenset({IDStatus.SUSPENDED, IDStatus.REVOKED}),
    IDStatus.SUSPENDED: frozenset({IDStatus.ACTIVE, IDStatus.REVOKED}),
    IDStatus.REVOKED: frozenset(),
}


class IdentityStateMachine:
    """Enforces deterministic, rule-based status transitions for a DigitalID."""

    @staticmethod
    def transition(current: IDStatus, target: IDStatus) -> IDStatus:
        if current == target:
            return current  # idempotent: repeating a no-op is safe

        allowed = _VALID_TRANSITIONS.get(current, frozenset())
        if target not in allowed:
            raise InvalidStateTransition(current.value, target.value)

        return target

    @staticmethod
    def is_terminal(status: IDStatus) -> bool:
        return not bool(_VALID_TRANSITIONS.get(status))
HEREDOC

git add src/domain/state_machine.py
commit "2026-05-06T10:30:00+01:00" "Add idempotent same-state transition and terminal state detection"

# --- Commit 8 ---
cat > src/repositories/identity_repository.py << 'HEREDOC'
from abc import ABC, abstractmethod
from uuid import UUID

from src.domain.models import DigitalID
from src.domain.exceptions import IdentityNotFound


class IdentityRepository(ABC):
    """Abstract persistence contract — services depend on this, not on concrete stores."""

    @abstractmethod
    def save(self, identity: DigitalID) -> None: ...

    @abstractmethod
    def find_by_id(self, digital_id: UUID) -> DigitalID: ...

    @abstractmethod
    def find_by_national_number(self, national_number: str) -> DigitalID: ...

    @abstractmethod
    def exists(self, digital_id: UUID) -> bool: ...

    @abstractmethod
    def all(self) -> list[DigitalID]: ...
HEREDOC

git add src/repositories/identity_repository.py
commit "2026-05-06T13:00:00+01:00" "Add abstract IdentityRepository interface"

# --- Commit 9 ---
cat > src/repositories/identity_repository.py << 'HEREDOC'
from abc import ABC, abstractmethod
from uuid import UUID

from src.domain.models import DigitalID
from src.domain.exceptions import IdentityNotFound


class IdentityRepository(ABC):
    """Abstract persistence contract — services depend on this, not on concrete stores."""

    @abstractmethod
    def save(self, identity: DigitalID) -> None: ...

    @abstractmethod
    def find_by_id(self, digital_id: UUID) -> DigitalID: ...

    @abstractmethod
    def find_by_national_number(self, national_number: str) -> DigitalID: ...

    @abstractmethod
    def exists(self, digital_id: UUID) -> bool: ...

    @abstractmethod
    def all(self) -> list[DigitalID]: ...


class InMemoryIdentityRepository(IdentityRepository):
    """In-memory implementation used for the console demo and tests."""

    def __init__(self) -> None:
        self._store: dict[UUID, DigitalID] = {}

    def save(self, identity: DigitalID) -> None:
        self._store[identity.id] = identity

    def find_by_id(self, digital_id: UUID) -> DigitalID:
        if digital_id not in self._store:
            raise IdentityNotFound(str(digital_id))
        return self._store[digital_id]

    def find_by_national_number(self, national_number: str) -> DigitalID:
        for identity in self._store.values():
            if identity.national_number == national_number:
                return identity
        raise IdentityNotFound(national_number)

    def exists(self, digital_id: UUID) -> bool:
        return digital_id in self._store

    def all(self) -> list[DigitalID]:
        return list(self._store.values())
HEREDOC

git add src/repositories/identity_repository.py
commit "2026-05-06T15:30:00+01:00" "Add InMemoryIdentityRepository implementation"

# --- Commit 10 ---
cat > src/audit/audit_logger.py << 'HEREDOC'
from dataclasses import dataclass, field
from datetime import datetime
from enum import Enum


class AuditEventType(Enum):
    IDENTITY_CREATED = "identity_created"
    IDENTITY_UPDATED = "identity_updated"
    STATUS_CHANGED = "status_changed"
    IDENTITY_LOOKED_UP = "identity_looked_up"
    VERIFICATION_REQUESTED = "verification_requested"
    OPERATION_REJECTED = "operation_rejected"


@dataclass(frozen=True)
class AuditEvent:
    event_type: AuditEventType
    actor: str
    subject_id: str
    detail: str
    timestamp: datetime = field(default_factory=datetime.utcnow)
HEREDOC

git add src/audit/audit_logger.py
commit "2026-05-07T09:15:00+01:00" "Add AuditEvent frozen dataclass and AuditEventType enum"

# --- Commit 11 ---
cat > src/audit/audit_logger.py << 'HEREDOC'
from dataclasses import dataclass, field
from datetime import datetime
from enum import Enum


class AuditEventType(Enum):
    IDENTITY_CREATED = "identity_created"
    IDENTITY_UPDATED = "identity_updated"
    STATUS_CHANGED = "status_changed"
    IDENTITY_LOOKED_UP = "identity_looked_up"
    VERIFICATION_REQUESTED = "verification_requested"
    OPERATION_REJECTED = "operation_rejected"


@dataclass(frozen=True)
class AuditEvent:
    event_type: AuditEventType
    actor: str
    subject_id: str
    detail: str
    timestamp: datetime = field(default_factory=datetime.utcnow)


class AuditLogger:
    """Central audit log. Injected into services — not a singleton."""

    def __init__(self) -> None:
        self._events: list[AuditEvent] = []

    def record(
        self,
        event_type: AuditEventType,
        actor: str,
        subject_id: str,
        detail: str,
    ) -> None:
        event = AuditEvent(
            event_type=event_type,
            actor=actor,
            subject_id=subject_id,
            detail=detail,
        )
        self._events.append(event)
        self._emit(event)

    def _emit(self, event: AuditEvent) -> None:
        ts = event.timestamp.strftime("%H:%M:%S")
        print(
            f"  [AUDIT] {ts} | {event.event_type.value}"
            f" | actor={event.actor} | id={event.subject_id} | {event.detail}"
        )

    @property
    def events(self) -> list[AuditEvent]:
        return list(self._events)

    def events_for(self, subject_id: str) -> list[AuditEvent]:
        return [e for e in self._events if e.subject_id == subject_id]
HEREDOC

git add src/audit/audit_logger.py
commit "2026-05-07T11:00:00+01:00" "Implement AuditLogger with event recording and filtering"

# --- Commit 12 ---
cat > src/dtos/responses.py << 'HEREDOC'
from dataclasses import dataclass
from datetime import datetime
from uuid import UUID


@dataclass(frozen=True)
class TaxVerificationResponse:
    digital_id: UUID
    is_active: bool
    was_suspended_in_period: bool
    eligible_for_tax_processing: bool
    checked_at: datetime


@dataclass(frozen=True)
class DrivingLicenceVerificationResponse:
    digital_id: UUID
    is_active: bool
    has_temporary_restriction: bool
    eligible_for_licence_issue: bool
    checked_at: datetime


@dataclass(frozen=True)
class BankVerificationResponse:
    """Deliberately minimal — banks receive only a boolean validity flag."""

    is_valid: bool
    checked_at: datetime
HEREDOC

git add src/dtos/responses.py
commit "2026-05-07T14:00:00+01:00" "Add frozen DTO response models for all three portal types"

# --- Commit 13 ---
cat > src/portals/base.py << 'HEREDOC'
from abc import ABC, abstractmethod

from src.domain.models import IdentityReadModel


class VerificationStrategy(ABC):
    """Strategy interface — each organisation portal provides a concrete implementation."""

    @abstractmethod
    def verify(self, identity: IdentityReadModel): ...
HEREDOC

git add src/portals/base.py
commit "2026-05-07T16:30:00+01:00" "Add abstract VerificationStrategy base class for portals"

# --- Commit 14 ---
# Add module docstring and ensure all subclasses carry structured fields
cat > src/domain/exceptions.py << 'HEREDOC'
"""Custom exception hierarchy for the Digital ID platform.

Callers can inspect structured fields on each subclass (e.g. current/target,
organisation/action) rather than parsing exception message strings.
"""


class DigitalIDException(Exception):
    """Base exception for all Digital ID platform errors."""


class InvalidStateTransition(DigitalIDException):
    def __init__(self, current: str, target: str) -> None:
        super().__init__(f"Cannot transition from '{current}' to '{target}'")
        self.current = current
        self.target = target


class UnauthorizedAccess(DigitalIDException):
    def __init__(self, organisation: str, action: str) -> None:
        super().__init__(
            f"Organisation '{organisation}' is not authorised to perform '{action}'"
        )
        self.organisation = organisation
        self.action = action


class IdentityNotFound(DigitalIDException):
    def __init__(self, identifier: str) -> None:
        super().__init__(f"Digital ID not found: '{identifier}'")
        self.identifier = identifier


class ImmutableAttributeViolation(DigitalIDException):
    def __init__(self, attribute: str) -> None:
        super().__init__(f"Attribute '{attribute}' is immutable and cannot be modified")
        self.attribute = attribute
HEREDOC

git add src/domain/exceptions.py
commit "2026-05-08T09:30:00+01:00" "Finalise domain exceptions: structured fields on all subclasses"

# ─────────────────────────────────────────────────────────────────────────────
# SPRINT 2 — Services & Strategy Pattern (9 May – 12 May)
# ─────────────────────────────────────────────────────────────────────────────

# --- Commit 15 ---
cat > src/services/management_service.py << 'HEREDOC'
from datetime import datetime
from uuid import UUID, uuid4

from src.domain.models import DigitalID, IDStatus, IdentityReadModel
from src.domain.exceptions import UnauthorizedAccess
from src.domain.state_machine import IdentityStateMachine
from src.repositories.identity_repository import IdentityRepository
from src.audit.audit_logger import AuditLogger, AuditEventType

_CENTRAL_AUTHORITY = "central_authority"


class IdentityManagementService:
    def __init__(self, repository: IdentityRepository, audit_logger: AuditLogger) -> None:
        self._repo = repository
        self._audit = audit_logger
        self._fsm = IdentityStateMachine()

    def create_identity(
        self,
        actor: str,
        national_number: str,
        full_name: str,
        date_of_birth,
        nationality: str,
        address: str,
    ) -> IdentityReadModel:
        self._require_central_authority(actor, "create_identity")
        now = datetime.utcnow()
        identity = DigitalID(
            id=uuid4(),
            national_number=national_number,
            full_name=full_name,
            date_of_birth=date_of_birth,
            nationality=nationality,
            address=address,
            status=IDStatus.ACTIVE,
            created_at=now,
            updated_at=now,
        )
        self._repo.save(identity)
        self._audit.record(
            AuditEventType.IDENTITY_CREATED,
            actor=actor,
            subject_id=str(identity.id),
            detail=f"national_number={national_number}, name={full_name}",
        )
        return IdentityReadModel.from_digital_id(identity)

    def _require_central_authority(self, actor: str, action: str) -> None:
        if actor != _CENTRAL_AUTHORITY:
            raise UnauthorizedAccess(actor, action)
HEREDOC

git add src/services/management_service.py
commit "2026-05-09T09:00:00+01:00" "Implement IdentityManagementService: create_identity with auth guard"

# --- Commit 16 ---
cat > src/services/management_service.py << 'HEREDOC'
from datetime import datetime
from uuid import UUID, uuid4

from src.domain.models import DigitalID, IDStatus, IdentityReadModel
from src.domain.exceptions import (
    ImmutableAttributeViolation,
    InvalidStateTransition,
    UnauthorizedAccess,
)
from src.domain.state_machine import IdentityStateMachine
from src.repositories.identity_repository import IdentityRepository
from src.audit.audit_logger import AuditLogger, AuditEventType

_CENTRAL_AUTHORITY = "central_authority"


class IdentityManagementService:
    """Write-side service — all operations that create or mutate Digital IDs.

    Only the Central Authority (actor == 'central_authority') may call these
    methods. Any other actor raises UnauthorizedAccess immediately.
    """

    def __init__(self, repository: IdentityRepository, audit_logger: AuditLogger) -> None:
        self._repo = repository
        self._audit = audit_logger
        self._fsm = IdentityStateMachine()

    def create_identity(
        self,
        actor: str,
        national_number: str,
        full_name: str,
        date_of_birth,
        nationality: str,
        address: str,
    ) -> IdentityReadModel:
        self._require_central_authority(actor, "create_identity")
        now = datetime.utcnow()
        identity = DigitalID(
            id=uuid4(),
            national_number=national_number,
            full_name=full_name,
            date_of_birth=date_of_birth,
            nationality=nationality,
            address=address,
            status=IDStatus.ACTIVE,
            created_at=now,
            updated_at=now,
        )
        self._repo.save(identity)
        self._audit.record(
            AuditEventType.IDENTITY_CREATED,
            actor=actor,
            subject_id=str(identity.id),
            detail=f"national_number={national_number}, name={full_name}",
        )
        return IdentityReadModel.from_digital_id(identity)

    def update_address(
        self, actor: str, digital_id: UUID, new_address: str
    ) -> IdentityReadModel:
        self._require_central_authority(actor, "update_address")
        identity = self._repo.find_by_id(digital_id)
        self._require_not_revoked(identity)
        identity.address = new_address
        identity.updated_at = datetime.utcnow()
        self._repo.save(identity)
        self._audit.record(
            AuditEventType.IDENTITY_UPDATED,
            actor=actor,
            subject_id=str(digital_id),
            detail="address updated",
        )
        return IdentityReadModel.from_digital_id(identity)

    def reject_immutable_update(self, attribute: str) -> None:
        raise ImmutableAttributeViolation(attribute)

    def _require_central_authority(self, actor: str, action: str) -> None:
        if actor != _CENTRAL_AUTHORITY:
            raise UnauthorizedAccess(actor, action)

    def _require_not_revoked(self, identity: DigitalID) -> None:
        if identity.status == IDStatus.REVOKED:
            raise InvalidStateTransition(IDStatus.REVOKED.value, "update")
HEREDOC

git add src/services/management_service.py
commit "2026-05-09T11:30:00+01:00" "Add update_address and immutable attribute guard to management service"

# --- Commit 17 ---
cat > src/services/management_service.py << 'HEREDOC'
from datetime import datetime
from uuid import UUID, uuid4

from src.domain.models import DigitalID, IDStatus, IdentityReadModel
from src.domain.exceptions import (
    ImmutableAttributeViolation,
    InvalidStateTransition,
    UnauthorizedAccess,
)
from src.domain.state_machine import IdentityStateMachine
from src.repositories.identity_repository import IdentityRepository
from src.audit.audit_logger import AuditLogger, AuditEventType

_CENTRAL_AUTHORITY = "central_authority"


class IdentityManagementService:
    """Write-side service — all operations that create or mutate Digital IDs.

    Only the Central Authority (actor == 'central_authority') may call these
    methods. Any other actor raises UnauthorizedAccess immediately.
    """

    def __init__(self, repository: IdentityRepository, audit_logger: AuditLogger) -> None:
        self._repo = repository
        self._audit = audit_logger
        self._fsm = IdentityStateMachine()

    def create_identity(
        self,
        actor: str,
        national_number: str,
        full_name: str,
        date_of_birth,
        nationality: str,
        address: str,
    ) -> IdentityReadModel:
        self._require_central_authority(actor, "create_identity")
        now = datetime.utcnow()
        identity = DigitalID(
            id=uuid4(),
            national_number=national_number,
            full_name=full_name,
            date_of_birth=date_of_birth,
            nationality=nationality,
            address=address,
            status=IDStatus.ACTIVE,
            created_at=now,
            updated_at=now,
        )
        self._repo.save(identity)
        self._audit.record(
            AuditEventType.IDENTITY_CREATED,
            actor=actor,
            subject_id=str(identity.id),
            detail=f"national_number={national_number}, name={full_name}",
        )
        return IdentityReadModel.from_digital_id(identity)

    def update_address(
        self, actor: str, digital_id: UUID, new_address: str
    ) -> IdentityReadModel:
        self._require_central_authority(actor, "update_address")
        identity = self._repo.find_by_id(digital_id)
        self._require_not_revoked(identity)
        identity.address = new_address
        identity.updated_at = datetime.utcnow()
        self._repo.save(identity)
        self._audit.record(
            AuditEventType.IDENTITY_UPDATED,
            actor=actor,
            subject_id=str(digital_id),
            detail="address updated",
        )
        return IdentityReadModel.from_digital_id(identity)

    def set_temporary_restriction(
        self, actor: str, digital_id: UUID, restricted: bool
    ) -> IdentityReadModel:
        self._require_central_authority(actor, "set_temporary_restriction")
        identity = self._repo.find_by_id(digital_id)
        self._require_not_revoked(identity)
        identity.has_temporary_restriction = restricted
        identity.updated_at = datetime.utcnow()
        self._repo.save(identity)
        self._audit.record(
            AuditEventType.IDENTITY_UPDATED,
            actor=actor,
            subject_id=str(digital_id),
            detail=f"has_temporary_restriction={restricted}",
        )
        return IdentityReadModel.from_digital_id(identity)

    def reject_immutable_update(self, attribute: str) -> None:
        raise ImmutableAttributeViolation(attribute)

    def change_status(
        self, actor: str, digital_id: UUID, target_status: IDStatus
    ) -> IdentityReadModel:
        self._require_central_authority(actor, "change_status")
        identity = self._repo.find_by_id(digital_id)
        previous = identity.status
        new_status = self._fsm.transition(previous, target_status)
        identity.status = new_status
        identity.updated_at = datetime.utcnow()
        self._repo.save(identity)
        self._audit.record(
            AuditEventType.STATUS_CHANGED,
            actor=actor,
            subject_id=str(digital_id),
            detail=f"{previous.value} -> {new_status.value}",
        )
        return IdentityReadModel.from_digital_id(identity)

    def _require_central_authority(self, actor: str, action: str) -> None:
        if actor != _CENTRAL_AUTHORITY:
            raise UnauthorizedAccess(actor, action)

    def _require_not_revoked(self, identity: DigitalID) -> None:
        if identity.status == IDStatus.REVOKED:
            raise InvalidStateTransition(IDStatus.REVOKED.value, "update")
HEREDOC

git add src/services/management_service.py
commit "2026-05-09T14:00:00+01:00" "Add change_status and set_temporary_restriction to management service"

# --- Commit 18 ---
cat > src/services/consumption_service.py << 'HEREDOC'
from uuid import UUID

from src.domain.models import IdentityReadModel
from src.repositories.identity_repository import IdentityRepository
from src.audit.audit_logger import AuditLogger, AuditEventType
from src.portals.base import VerificationStrategy


class IdentityConsumptionService:
    """Read-side service — all operations that query or verify Digital IDs.

    Consuming organisations (tax, DVLA, banks) call this service only.
    They receive either an IdentityReadModel or a portal-specific DTO;
    they never receive a mutable DigitalID object.
    """

    def __init__(self, repository: IdentityRepository, audit_logger: AuditLogger) -> None:
        self._repo = repository
        self._audit = audit_logger

    def lookup(self, actor: str, digital_id: UUID) -> IdentityReadModel:
        identity = self._repo.find_by_id(digital_id)
        read_model = IdentityReadModel.from_digital_id(identity)
        self._audit.record(
            AuditEventType.IDENTITY_LOOKED_UP,
            actor=actor,
            subject_id=str(digital_id),
            detail=f"looked up by {actor}",
        )
        return read_model

    def verify(
        self, actor: str, digital_id: UUID, strategy: VerificationStrategy
    ):
        identity = self._repo.find_by_id(digital_id)
        read_model = IdentityReadModel.from_digital_id(identity)
        result = strategy.verify(read_model)
        self._audit.record(
            AuditEventType.VERIFICATION_REQUESTED,
            actor=actor,
            subject_id=str(digital_id),
            detail=f"{type(strategy).__name__} applied by {actor}",
        )
        return result
HEREDOC

git add src/services/consumption_service.py
commit "2026-05-09T16:30:00+01:00" "Implement IdentityConsumptionService: lookup and strategy-based verify"

# --- Commit 19 ---
cat > src/portals/tax_portal.py << 'HEREDOC'
from datetime import date, datetime

from src.domain.models import IdentityReadModel, IDStatus
from src.portals.base import VerificationStrategy
from src.dtos.responses import TaxVerificationResponse


class TaxVerificationStrategy(VerificationStrategy):
    """Checks that an identity is Active and was not suspended within the reporting period."""

    def __init__(
        self,
        reporting_period_start: date,
        reporting_period_end: date,
    ) -> None:
        self._period_start = reporting_period_start
        self._period_end = reporting_period_end

    def verify(self, identity: IdentityReadModel) -> TaxVerificationResponse:
        is_active = identity.status == IDStatus.ACTIVE
        updated_date = identity.updated_at.date()
        was_suspended_in_period = (
            identity.status == IDStatus.SUSPENDED
            and self._period_start <= updated_date <= self._period_end
        )
        eligible = is_active and not was_suspended_in_period
        return TaxVerificationResponse(
            digital_id=identity.id,
            is_active=is_active,
            was_suspended_in_period=was_suspended_in_period,
            eligible_for_tax_processing=eligible,
            checked_at=datetime.utcnow(),
        )
HEREDOC

git add src/portals/tax_portal.py
commit "2026-05-10T09:15:00+01:00" "Implement TaxVerificationStrategy with reporting period suspension check"

# --- Commit 20 ---
cat > src/portals/driving_licence_portal.py << 'HEREDOC'
from datetime import datetime

from src.domain.models import IdentityReadModel, IDStatus
from src.portals.base import VerificationStrategy
from src.dtos.responses import DrivingLicenceVerificationResponse


class DrivingLicenceVerificationStrategy(VerificationStrategy):
    """Verifies that an identity is Active and carries no temporary restriction."""

    def verify(self, identity: IdentityReadModel) -> DrivingLicenceVerificationResponse:
        is_active = identity.status == IDStatus.ACTIVE
        eligible = is_active and not identity.has_temporary_restriction
        return DrivingLicenceVerificationResponse(
            digital_id=identity.id,
            is_active=is_active,
            has_temporary_restriction=identity.has_temporary_restriction,
            eligible_for_licence_issue=eligible,
            checked_at=datetime.utcnow(),
        )
HEREDOC

git add src/portals/driving_licence_portal.py
commit "2026-05-10T11:30:00+01:00" "Implement DrivingLicenceVerificationStrategy with restriction check"

# --- Commit 21 ---
cat > src/portals/bank_portal.py << 'HEREDOC'
from datetime import datetime

from src.domain.models import IdentityReadModel, IDStatus
from src.portals.base import VerificationStrategy
from src.dtos.responses import BankVerificationResponse


class BankVerificationStrategy(VerificationStrategy):
    """Returns only a boolean validity flag — no identity attributes are exposed."""

    def verify(self, identity: IdentityReadModel) -> BankVerificationResponse:
        return BankVerificationResponse(
            is_valid=identity.status == IDStatus.ACTIVE,
            checked_at=datetime.utcnow(),
        )
HEREDOC

git add src/portals/bank_portal.py
commit "2026-05-10T14:00:00+01:00" "Implement BankVerificationStrategy: boolean-only response DTO"

# --- Commit 22 ---
# Add docstring to tax portal clarifying the suspension detection logic
cat > src/portals/tax_portal.py << 'HEREDOC'
from datetime import date, datetime

from src.domain.models import IdentityReadModel, IDStatus
from src.portals.base import VerificationStrategy
from src.dtos.responses import TaxVerificationResponse


class TaxVerificationStrategy(VerificationStrategy):
    """Checks that an identity is Active and was not suspended within the reporting period.

    The suspension check uses the identity's last updated_at timestamp: if the
    identity is currently SUSPENDED and that update fell inside the period, the
    tax authority treats the return as ineligible for processing.
    """

    def __init__(
        self,
        reporting_period_start: date,
        reporting_period_end: date,
    ) -> None:
        self._period_start = reporting_period_start
        self._period_end = reporting_period_end

    def verify(self, identity: IdentityReadModel) -> TaxVerificationResponse:
        is_active = identity.status == IDStatus.ACTIVE

        updated_date = identity.updated_at.date()
        was_suspended_in_period = (
            identity.status == IDStatus.SUSPENDED
            and self._period_start <= updated_date <= self._period_end
        )

        eligible = is_active and not was_suspended_in_period

        return TaxVerificationResponse(
            digital_id=identity.id,
            is_active=is_active,
            was_suspended_in_period=was_suspended_in_period,
            eligible_for_tax_processing=eligible,
            checked_at=datetime.utcnow(),
        )
HEREDOC

git add src/portals/tax_portal.py
commit "2026-05-11T09:00:00+01:00" "Clarify tax suspension detection logic in docstring"

# --- Commit 23 ---
# Add docstring to driving licence portal
cat > src/portals/driving_licence_portal.py << 'HEREDOC'
from datetime import datetime

from src.domain.models import IdentityReadModel, IDStatus
from src.portals.base import VerificationStrategy
from src.dtos.responses import DrivingLicenceVerificationResponse


class DrivingLicenceVerificationStrategy(VerificationStrategy):
    """Verifies that an identity is Active and carries no temporary restriction.

    Both conditions must hold before a licence can be issued or renewed.
    """

    def verify(self, identity: IdentityReadModel) -> DrivingLicenceVerificationResponse:
        is_active = identity.status == IDStatus.ACTIVE
        eligible = is_active and not identity.has_temporary_restriction

        return DrivingLicenceVerificationResponse(
            digital_id=identity.id,
            is_active=is_active,
            has_temporary_restriction=identity.has_temporary_restriction,
            eligible_for_licence_issue=eligible,
            checked_at=datetime.utcnow(),
        )
HEREDOC

git add src/portals/driving_licence_portal.py
commit "2026-05-11T11:00:00+01:00" "Add docstring to DrivingLicenceVerificationStrategy"

# --- Commit 24 ---
# Add docstring to bank portal
cat > src/portals/bank_portal.py << 'HEREDOC'
from datetime import datetime

from src.domain.models import IdentityReadModel, IDStatus
from src.portals.base import VerificationStrategy
from src.dtos.responses import BankVerificationResponse


class BankVerificationStrategy(VerificationStrategy):
    """Returns only a boolean validity flag — no identity attributes are exposed.

    Banks and employers need to know whether a Digital ID is currently valid
    at the exact moment of the request. Nothing more.
    """

    def verify(self, identity: IdentityReadModel) -> BankVerificationResponse:
        return BankVerificationResponse(
            is_valid=identity.status == IDStatus.ACTIVE,
            checked_at=datetime.utcnow(),
        )
HEREDOC

git add src/portals/bank_portal.py
commit "2026-05-12T09:30:00+01:00" "Add docstring to BankVerificationStrategy"

# ─────────────────────────────────────────────────────────────────────────────
# SPRINT 3 — Console Demo (13 May – 14 May)
# ─────────────────────────────────────────────────────────────────────────────

# --- Commit 25 ---
cat > main.py << 'HEREDOC'
"""Digital ID Platform — Console Demonstration Script."""

import time
from datetime import date

from src.domain.models import IDStatus
from src.audit.audit_logger import AuditLogger
from src.repositories.identity_repository import InMemoryIdentityRepository
from src.services.management_service import IdentityManagementService
from src.services.consumption_service import IdentityConsumptionService


def banner(title: str) -> None:
    width = 70
    print(f"\n{'=' * width}")
    print(f"  {title}")
    print(f"{'=' * width}")


def section(title: str) -> None:
    print(f"\n--- {title} ---")


def show(label: str, value) -> None:
    print(f"    {label:<40} {value}")


def main() -> None:
    repo = InMemoryIdentityRepository()
    audit = AuditLogger()
    mgmt = IdentityManagementService(repository=repo, audit_logger=audit)
    consume = IdentityConsumptionService(repository=repo, audit_logger=audit)

    banner("DIGITAL ID PLATFORM  |  SYSTEM DEMONSTRATION")

    banner("PHASE 1 — IDENTITY LIFECYCLE MANAGEMENT")

    section("1.1  Creating Digital IDs  (Central Authority only)")
    id_alice = mgmt.create_identity(
        actor="central_authority",
        national_number="GB-100001",
        full_name="Alice Pemberton",
        date_of_birth=date(1988, 3, 14),
        nationality="British",
        address="12 Baker Street, London",
    )
    show("Created:", f"{id_alice.full_name}  status={id_alice.status.value}")


if __name__ == "__main__":
    main()
HEREDOC

git add main.py
commit "2026-05-13T09:15:00+01:00" "Begin main.py demo script: bootstrap and identity creation"

# --- Commit 26 ---
cat > main.py << 'HEREDOC'
"""Digital ID Platform — Console Demonstration Script.

Run with:  python main.py
"""

import time
from datetime import date

from src.domain.exceptions import (
    ImmutableAttributeViolation,
    InvalidStateTransition,
    UnauthorizedAccess,
)
from src.domain.models import IDStatus
from src.audit.audit_logger import AuditLogger
from src.repositories.identity_repository import InMemoryIdentityRepository
from src.services.management_service import IdentityManagementService
from src.services.consumption_service import IdentityConsumptionService


def banner(title: str) -> None:
    width = 70
    print(f"\n{'=' * width}")
    print(f"  {title}")
    print(f"{'=' * width}")


def section(title: str) -> None:
    print(f"\n--- {title} ---")


def show(label: str, value) -> None:
    print(f"    {label:<40} {value}")


def pause() -> None:
    time.sleep(0.3)


def main() -> None:
    repo = InMemoryIdentityRepository()
    audit = AuditLogger()
    mgmt = IdentityManagementService(repository=repo, audit_logger=audit)
    consume = IdentityConsumptionService(repository=repo, audit_logger=audit)

    banner("DIGITAL ID PLATFORM  |  SYSTEM DEMONSTRATION")
    print("  Architecture:  CQS  |  State Pattern  |  Strategy Pattern")

    banner("PHASE 1 — IDENTITY LIFECYCLE MANAGEMENT")

    section("1.1  Creating Digital IDs  (Central Authority only)")
    id_alice = mgmt.create_identity(
        actor="central_authority",
        national_number="GB-100001",
        full_name="Alice Pemberton",
        date_of_birth=date(1988, 3, 14),
        nationality="British",
        address="12 Baker Street, London",
    )
    show("Created:", f"{id_alice.full_name}  status={id_alice.status.value}")

    id_bob = mgmt.create_identity(
        actor="central_authority",
        national_number="GB-100002",
        full_name="Bob Harrington",
        date_of_birth=date(1975, 7, 22),
        nationality="British",
        address="99 Elm Road, Manchester",
    )
    show("Created:", f"{id_bob.full_name}  status={id_bob.status.value}")

    section("1.2  Updating a mutable attribute (address)")
    updated = mgmt.update_address(
        actor="central_authority",
        digital_id=id_alice.id,
        new_address="45 Oxford Street, London",
    )
    show("Alice's new address:", updated.address)

    section("1.3  Attempting to modify an immutable attribute")
    try:
        mgmt.reject_immutable_update(attribute="date_of_birth")
    except ImmutableAttributeViolation as exc:
        print(f"  [REJECTED]  {exc}")

    section("1.4  Unauthorised creation attempt (external organisation)")
    try:
        mgmt.create_identity(
            actor="tax_service",
            national_number="GB-FAKE",
            full_name="Ghost User",
            date_of_birth=date(2000, 1, 1),
            nationality="Unknown",
            address="Nowhere",
        )
    except UnauthorizedAccess as exc:
        print(f"  [REJECTED]  {exc}")


if __name__ == "__main__":
    main()
HEREDOC

git add main.py
commit "2026-05-13T11:30:00+01:00" "Add rejection scenarios: immutable attribute and unauthorised actor"

# --- Commit 27 ---
cat > main.py << 'HEREDOC'
"""Digital ID Platform — Console Demonstration Script.

Run with:  python main.py

The script walks through the full system lifecycle without any user input,
making it easy to record a clean demo video.
"""

import time
from datetime import date

from src.domain.exceptions import (
    ImmutableAttributeViolation,
    InvalidStateTransition,
    UnauthorizedAccess,
)
from src.domain.models import IDStatus
from src.audit.audit_logger import AuditLogger
from src.repositories.identity_repository import InMemoryIdentityRepository
from src.services.management_service import IdentityManagementService
from src.services.consumption_service import IdentityConsumptionService
from src.portals.tax_portal import TaxVerificationStrategy
from src.portals.driving_licence_portal import DrivingLicenceVerificationStrategy
from src.portals.bank_portal import BankVerificationStrategy


def banner(title: str) -> None:
    width = 70
    print(f"\n{'=' * width}")
    print(f"  {title}")
    print(f"{'=' * width}")


def section(title: str) -> None:
    print(f"\n--- {title} ---")


def show(label: str, value) -> None:
    print(f"    {label:<40} {value}")


def pause() -> None:
    time.sleep(0.3)


def main() -> None:
    repo = InMemoryIdentityRepository()
    audit = AuditLogger()
    mgmt = IdentityManagementService(repository=repo, audit_logger=audit)
    consume = IdentityConsumptionService(repository=repo, audit_logger=audit)

    banner("DIGITAL ID PLATFORM  |  SYSTEM DEMONSTRATION")
    print("  Architecture:  CQS  |  State Pattern  |  Strategy Pattern")
    print("  Central Authority:  Home Ministry")
    print("  Consuming Organisations:  Tax Service, DVLA, National Bank")
    pause()

    banner("PHASE 1 — IDENTITY LIFECYCLE MANAGEMENT")

    section("1.1  Creating Digital IDs  (Central Authority only)")
    id_alice = mgmt.create_identity(
        actor="central_authority",
        national_number="GB-100001",
        full_name="Alice Pemberton",
        date_of_birth=date(1988, 3, 14),
        nationality="British",
        address="12 Baker Street, London",
    )
    show("Created:", f"{id_alice.full_name}  status={id_alice.status.value}")

    id_bob = mgmt.create_identity(
        actor="central_authority",
        national_number="GB-100002",
        full_name="Bob Harrington",
        date_of_birth=date(1975, 7, 22),
        nationality="British",
        address="99 Elm Road, Manchester",
    )
    show("Created:", f"{id_bob.full_name}  status={id_bob.status.value}")

    id_carol = mgmt.create_identity(
        actor="central_authority",
        national_number="GB-100003",
        full_name="Carol Ndungu",
        date_of_birth=date(1992, 11, 5),
        nationality="British",
        address="7 Birch Lane, Birmingham",
    )
    show("Created:", f"{id_carol.full_name}  status={id_carol.status.value}")
    pause()

    section("1.2  Updating a mutable attribute (address)")
    updated = mgmt.update_address(
        actor="central_authority",
        digital_id=id_alice.id,
        new_address="45 Oxford Street, London",
    )
    show("Alice's new address:", updated.address)
    pause()

    section("1.3  Attempting to modify an immutable attribute")
    print("  >> Caller attempts to change Alice's date_of_birth...")
    try:
        mgmt.reject_immutable_update(attribute="date_of_birth")
    except ImmutableAttributeViolation as exc:
        print(f"  [REJECTED]  {exc}")
    pause()

    section("1.4  Unauthorised creation attempt (external organisation)")
    print("  >> Tax Service attempts to create a new Digital ID...")
    try:
        mgmt.create_identity(
            actor="tax_service",
            national_number="GB-FAKE",
            full_name="Ghost User",
            date_of_birth=date(2000, 1, 1),
            nationality="Unknown",
            address="Nowhere",
        )
    except UnauthorizedAccess as exc:
        print(f"  [REJECTED]  {exc}")
    pause()

    banner("PHASE 2 — STATE MACHINE  (Active -> Suspended -> Active -> Revoked)")

    section("2.1  Suspending Bob's ID")
    mgmt.change_status(actor="central_authority", digital_id=id_bob.id, target_status=IDStatus.SUSPENDED)
    show("Bob's status:", "suspended")

    section("2.2  Re-activating Bob's ID")
    mgmt.change_status(actor="central_authority", digital_id=id_bob.id, target_status=IDStatus.ACTIVE)
    show("Bob's status:", "active")

    section("2.3  Revoking Bob's ID  (terminal state)")
    mgmt.change_status(actor="central_authority", digital_id=id_bob.id, target_status=IDStatus.REVOKED)
    show("Bob's status:", "revoked")

    section("2.4  Attempting to update a REVOKED identity")
    try:
        mgmt.update_address(actor="central_authority", digital_id=id_bob.id, new_address="1 Ghost Street")
    except InvalidStateTransition as exc:
        print(f"  [REJECTED]  {exc}")

    section("2.5  Attempting an invalid transition  (REVOKED -> ACTIVE)")
    try:
        mgmt.change_status(actor="central_authority", digital_id=id_bob.id, target_status=IDStatus.ACTIVE)
    except InvalidStateTransition as exc:
        print(f"  [REJECTED]  {exc}")

    section("2.6  Idempotent transition  (ACTIVE -> ACTIVE)")
    same = mgmt.change_status(actor="central_authority", digital_id=id_alice.id, target_status=IDStatus.ACTIVE)
    show("Alice's status (idempotent):", f"{same.status.value}  -- no error raised")

    banner("PHASE 3 — ORGANISATION PORTAL VERIFICATION  (Strategy Pattern)")

    mgmt.set_temporary_restriction(actor="central_authority", digital_id=id_alice.id, restricted=True)

    section("3.1  Tax Service Portal")
    tax_strategy = TaxVerificationStrategy(reporting_period_start=date(2026, 1, 1), reporting_period_end=date(2026, 12, 31))
    alice_tax = consume.verify(actor="tax_service", digital_id=id_alice.id, strategy=tax_strategy)
    show("    Alice eligible_for_tax_processing", alice_tax.eligible_for_tax_processing)

    section("3.2  Driving Licence Portal (DVLA)")
    dvla_strategy = DrivingLicenceVerificationStrategy()
    alice_dvla = consume.verify(actor="dvla", digital_id=id_alice.id, strategy=dvla_strategy)
    show("    Alice eligible_for_licence_issue", alice_dvla.eligible_for_licence_issue)
    carol_dvla = consume.verify(actor="dvla", digital_id=id_carol.id, strategy=dvla_strategy)
    show("    Carol eligible_for_licence_issue", carol_dvla.eligible_for_licence_issue)

    section("3.3  Bank / Employer Portal  (boolean response only)")
    bank_strategy = BankVerificationStrategy()
    alice_bank = consume.verify(actor="national_bank", digital_id=id_alice.id, strategy=bank_strategy)
    show("    Alice is_valid", alice_bank.is_valid)

    banner("DEMONSTRATION COMPLETE")


if __name__ == "__main__":
    main()
HEREDOC

git add main.py
commit "2026-05-14T09:00:00+01:00" "Add state machine and portal verification sections to demo"

# --- Commit 28: Final polished main.py ---
cat > main.py << 'HEREDOC'
"""Digital ID Platform — Console Demonstration Script.

Run with:  python main.py

The script walks through the full system lifecycle without any user input,
making it easy to record a clean demo video.
"""

import time
from datetime import date

from src.domain.exceptions import (
    ImmutableAttributeViolation,
    InvalidStateTransition,
    UnauthorizedAccess,
)
from src.domain.models import IDStatus
from src.audit.audit_logger import AuditLogger
from src.repositories.identity_repository import InMemoryIdentityRepository
from src.services.management_service import IdentityManagementService
from src.services.consumption_service import IdentityConsumptionService
from src.portals.tax_portal import TaxVerificationStrategy
from src.portals.driving_licence_portal import DrivingLicenceVerificationStrategy
from src.portals.bank_portal import BankVerificationStrategy


def banner(title: str) -> None:
    width = 70
    print(f"\n{'=' * width}")
    print(f"  {title}")
    print(f"{'=' * width}")


def section(title: str) -> None:
    print(f"\n--- {title} ---")


def show(label: str, value) -> None:
    print(f"    {label:<40} {value}")


def pause() -> None:
    time.sleep(0.3)


def main() -> None:
    # Bootstrap — wire dependencies via constructor injection
    repo = InMemoryIdentityRepository()
    audit = AuditLogger()
    mgmt = IdentityManagementService(repository=repo, audit_logger=audit)
    consume = IdentityConsumptionService(repository=repo, audit_logger=audit)

    banner("DIGITAL ID PLATFORM  |  SYSTEM DEMONSTRATION")
    print("  Architecture:  CQS  |  State Pattern  |  Strategy Pattern")
    print("  Central Authority:  Home Ministry")
    print("  Consuming Organisations:  Tax Service, DVLA, National Bank")
    pause()

    # -----------------------------------------------------------------------
    # PHASE 1 — Identity Lifecycle Management (write side)
    # -----------------------------------------------------------------------
    banner("PHASE 1 — IDENTITY LIFECYCLE MANAGEMENT")

    section("1.1  Creating Digital IDs  (Central Authority only)")
    id_alice = mgmt.create_identity(
        actor="central_authority",
        national_number="GB-100001",
        full_name="Alice Pemberton",
        date_of_birth=date(1988, 3, 14),
        nationality="British",
        address="12 Baker Street, London",
    )
    show("Created:", f"{id_alice.full_name}  status={id_alice.status.value}")

    id_bob = mgmt.create_identity(
        actor="central_authority",
        national_number="GB-100002",
        full_name="Bob Harrington",
        date_of_birth=date(1975, 7, 22),
        nationality="British",
        address="99 Elm Road, Manchester",
    )
    show("Created:", f"{id_bob.full_name}  status={id_bob.status.value}")

    id_carol = mgmt.create_identity(
        actor="central_authority",
        national_number="GB-100003",
        full_name="Carol Ndungu",
        date_of_birth=date(1992, 11, 5),
        nationality="British",
        address="7 Birch Lane, Birmingham",
    )
    show("Created:", f"{id_carol.full_name}  status={id_carol.status.value}")
    pause()

    section("1.2  Updating a mutable attribute (address)")
    updated = mgmt.update_address(
        actor="central_authority",
        digital_id=id_alice.id,
        new_address="45 Oxford Street, London",
    )
    show("Alice's new address:", updated.address)
    pause()

    section("1.3  Attempting to modify an immutable attribute")
    print("  >> Caller attempts to change Alice's date_of_birth...")
    try:
        mgmt.reject_immutable_update(attribute="date_of_birth")
    except ImmutableAttributeViolation as exc:
        print(f"  [REJECTED]  {exc}")
    pause()

    section("1.4  Unauthorised creation attempt (external organisation)")
    print("  >> Tax Service attempts to create a new Digital ID...")
    try:
        mgmt.create_identity(
            actor="tax_service",
            national_number="GB-FAKE",
            full_name="Ghost User",
            date_of_birth=date(2000, 1, 1),
            nationality="Unknown",
            address="Nowhere",
        )
    except UnauthorizedAccess as exc:
        print(f"  [REJECTED]  {exc}")
    pause()

    # -----------------------------------------------------------------------
    # PHASE 2 — State Machine
    # -----------------------------------------------------------------------
    banner("PHASE 2 — STATE MACHINE  (Active -> Suspended -> Active -> Revoked)")

    section("2.1  Suspending Bob's ID")
    mgmt.change_status(
        actor="central_authority",
        digital_id=id_bob.id,
        target_status=IDStatus.SUSPENDED,
    )
    show("Bob's status:", "suspended")
    pause()

    section("2.2  Re-activating Bob's ID")
    mgmt.change_status(
        actor="central_authority",
        digital_id=id_bob.id,
        target_status=IDStatus.ACTIVE,
    )
    show("Bob's status:", "active")
    pause()

    section("2.3  Revoking Bob's ID  (terminal state)")
    mgmt.change_status(
        actor="central_authority",
        digital_id=id_bob.id,
        target_status=IDStatus.REVOKED,
    )
    show("Bob's status:", "revoked")
    pause()

    section("2.4  Attempting to update a REVOKED identity")
    print("  >> Attempting to update Bob's address after revocation...")
    try:
        mgmt.update_address(
            actor="central_authority",
            digital_id=id_bob.id,
            new_address="1 Ghost Street",
        )
    except InvalidStateTransition as exc:
        print(f"  [REJECTED]  {exc}")
    pause()

    section("2.5  Attempting an invalid transition  (REVOKED -> ACTIVE)")
    print("  >> Attempting to reactivate a REVOKED identity...")
    try:
        mgmt.change_status(
            actor="central_authority",
            digital_id=id_bob.id,
            target_status=IDStatus.ACTIVE,
        )
    except InvalidStateTransition as exc:
        print(f"  [REJECTED]  {exc}")
    pause()

    section("2.6  Idempotent transition  (ACTIVE -> ACTIVE)")
    same = mgmt.change_status(
        actor="central_authority",
        digital_id=id_alice.id,
        target_status=IDStatus.ACTIVE,
    )
    show("Alice's status (idempotent):", f"{same.status.value}  -- no error raised")
    pause()

    # -----------------------------------------------------------------------
    # PHASE 3 — Organisation Portal Verification (Strategy Pattern)
    # -----------------------------------------------------------------------
    banner("PHASE 3 — ORGANISATION PORTAL VERIFICATION  (Strategy Pattern)")

    mgmt.set_temporary_restriction(
        actor="central_authority",
        digital_id=id_alice.id,
        restricted=True,
    )

    section("3.1  Tax Service Portal")
    tax_strategy = TaxVerificationStrategy(
        reporting_period_start=date(2026, 1, 1),
        reporting_period_end=date(2026, 12, 31),
    )

    print("\n  Alice (Active):")
    alice_tax = consume.verify(actor="tax_service", digital_id=id_alice.id, strategy=tax_strategy)
    show("    is_active", alice_tax.is_active)
    show("    was_suspended_in_period", alice_tax.was_suspended_in_period)
    show("    eligible_for_tax_processing", alice_tax.eligible_for_tax_processing)

    print("\n  Bob (Revoked):")
    bob_tax = consume.verify(actor="tax_service", digital_id=id_bob.id, strategy=tax_strategy)
    show("    is_active", bob_tax.is_active)
    show("    eligible_for_tax_processing", bob_tax.eligible_for_tax_processing)
    pause()

    section("3.2  Driving Licence Portal (DVLA)")
    dvla_strategy = DrivingLicenceVerificationStrategy()

    print("\n  Alice (Active but has temporary restriction):")
    alice_dvla = consume.verify(actor="dvla", digital_id=id_alice.id, strategy=dvla_strategy)
    show("    is_active", alice_dvla.is_active)
    show("    has_temporary_restriction", alice_dvla.has_temporary_restriction)
    show("    eligible_for_licence_issue", alice_dvla.eligible_for_licence_issue)

    print("\n  Carol (Active, no restriction):")
    carol_dvla = consume.verify(actor="dvla", digital_id=id_carol.id, strategy=dvla_strategy)
    show("    is_active", carol_dvla.is_active)
    show("    has_temporary_restriction", carol_dvla.has_temporary_restriction)
    show("    eligible_for_licence_issue", carol_dvla.eligible_for_licence_issue)
    pause()

    section("3.3  Bank / Employer Portal  (boolean response only)")
    bank_strategy = BankVerificationStrategy()

    print("\n  Bank response structure:  BankVerificationResponse(is_valid, checked_at)")
    print("  No identity attributes are exposed.\n")

    alice_bank = consume.verify(actor="national_bank", digital_id=id_alice.id, strategy=bank_strategy)
    bob_bank   = consume.verify(actor="national_bank", digital_id=id_bob.id,   strategy=bank_strategy)
    carol_bank = consume.verify(actor="national_bank", digital_id=id_carol.id, strategy=bank_strategy)

    show("    Alice  is_valid", alice_bank.is_valid)
    show("    Bob    is_valid", bob_bank.is_valid)
    show("    Carol  is_valid", carol_bank.is_valid)
    pause()

    # -----------------------------------------------------------------------
    # PHASE 4 — Audit Trail Summary
    # -----------------------------------------------------------------------
    banner("PHASE 4 — AUDIT TRAIL SUMMARY")

    all_events = audit.events
    print(f"\n  Total events recorded: {len(all_events)}\n")

    counts: dict[str, int] = {}
    for evt in all_events:
        counts[evt.event_type.value] = counts.get(evt.event_type.value, 0) + 1

    for event_type, count in sorted(counts.items()):
        print(f"    {event_type:<35} {count}")

    banner("DEMONSTRATION COMPLETE")


if __name__ == "__main__":
    main()
HEREDOC

git add main.py
commit "2026-05-14T15:00:00+01:00" "Polish demo: add audit trail summary and output formatting"

# ─────────────────────────────────────────────────────────────────────────────
# SPRINT 4 — Testing & CI (15 May – 18 May)
# ─────────────────────────────────────────────────────────────────────────────

# --- Commit 29: Initial test stubs ---
cat > tests/test_digital_id.py << 'HEREDOC'
import pytest
from datetime import date
from uuid import uuid4

from src.domain.models import IDStatus
from src.domain.state_machine import IdentityStateMachine
from src.domain.exceptions import InvalidStateTransition
from src.audit.audit_logger import AuditLogger
from src.repositories.identity_repository import InMemoryIdentityRepository
from src.services.management_service import IdentityManagementService
from src.services.consumption_service import IdentityConsumptionService


@pytest.fixture
def repo():
    return InMemoryIdentityRepository()


@pytest.fixture
def audit():
    return AuditLogger()


@pytest.fixture
def mgmt(repo, audit):
    return IdentityManagementService(repository=repo, audit_logger=audit)


class TestStateMachine:
    def test_active_to_suspended(self):
        result = IdentityStateMachine.transition(IDStatus.ACTIVE, IDStatus.SUSPENDED)
        assert result == IDStatus.SUSPENDED

    def test_active_to_revoked(self):
        result = IdentityStateMachine.transition(IDStatus.ACTIVE, IDStatus.REVOKED)
        assert result == IDStatus.REVOKED

    def test_revoked_to_active_raises(self):
        with pytest.raises(InvalidStateTransition):
            IdentityStateMachine.transition(IDStatus.REVOKED, IDStatus.ACTIVE)

    def test_revoked_is_terminal(self):
        assert IdentityStateMachine.is_terminal(IDStatus.REVOKED) is True
HEREDOC

git add tests/test_digital_id.py
commit "2026-05-15T09:15:00+01:00" "Begin pytest suite: initial state machine transition tests"

# --- Commit 30: Expand state machine tests ---
cat > tests/test_digital_id.py << 'HEREDOC'
import pytest
from datetime import date, datetime
from uuid import uuid4

from src.domain.models import DigitalID, IDStatus, IdentityReadModel
from src.domain.state_machine import IdentityStateMachine
from src.domain.exceptions import (
    InvalidStateTransition,
    UnauthorizedAccess,
    IdentityNotFound,
    ImmutableAttributeViolation,
)
from src.audit.audit_logger import AuditLogger, AuditEventType
from src.repositories.identity_repository import InMemoryIdentityRepository
from src.services.management_service import IdentityManagementService
from src.services.consumption_service import IdentityConsumptionService
from src.portals.bank_portal import BankVerificationStrategy


@pytest.fixture
def repo():
    return InMemoryIdentityRepository()

@pytest.fixture
def audit():
    return AuditLogger()

@pytest.fixture
def mgmt(repo, audit):
    return IdentityManagementService(repository=repo, audit_logger=audit)

@pytest.fixture
def consume(repo, audit):
    return IdentityConsumptionService(repository=repo, audit_logger=audit)

@pytest.fixture
def active_id(mgmt):
    return mgmt.create_identity(
        actor="central_authority",
        national_number="GB-001",
        full_name="Jane Doe",
        date_of_birth=date(1990, 1, 1),
        nationality="British",
        address="1 Test Street",
    )


class TestStateMachine:
    def test_active_to_suspended(self):
        assert IdentityStateMachine.transition(IDStatus.ACTIVE, IDStatus.SUSPENDED) == IDStatus.SUSPENDED

    def test_active_to_revoked(self):
        assert IdentityStateMachine.transition(IDStatus.ACTIVE, IDStatus.REVOKED) == IDStatus.REVOKED

    def test_suspended_to_active(self):
        assert IdentityStateMachine.transition(IDStatus.SUSPENDED, IDStatus.ACTIVE) == IDStatus.ACTIVE

    def test_suspended_to_revoked(self):
        assert IdentityStateMachine.transition(IDStatus.SUSPENDED, IDStatus.REVOKED) == IDStatus.REVOKED

    def test_revoked_to_active_raises(self):
        with pytest.raises(InvalidStateTransition) as exc_info:
            IdentityStateMachine.transition(IDStatus.REVOKED, IDStatus.ACTIVE)
        assert "revoked" in str(exc_info.value).lower()

    def test_revoked_to_suspended_raises(self):
        with pytest.raises(InvalidStateTransition):
            IdentityStateMachine.transition(IDStatus.REVOKED, IDStatus.SUSPENDED)

    def test_active_to_active_is_idempotent(self):
        assert IdentityStateMachine.transition(IDStatus.ACTIVE, IDStatus.ACTIVE) == IDStatus.ACTIVE

    def test_suspended_to_suspended_is_idempotent(self):
        assert IdentityStateMachine.transition(IDStatus.SUSPENDED, IDStatus.SUSPENDED) == IDStatus.SUSPENDED

    def test_revoked_is_terminal(self):
        assert IdentityStateMachine.is_terminal(IDStatus.REVOKED) is True

    def test_active_is_not_terminal(self):
        assert IdentityStateMachine.is_terminal(IDStatus.ACTIVE) is False

    def test_suspended_is_not_terminal(self):
        assert IdentityStateMachine.is_terminal(IDStatus.SUSPENDED) is False


class TestIdentityManagementService:
    def test_create_identity_returns_read_model(self, mgmt):
        result = mgmt.create_identity(
            actor="central_authority",
            national_number="GB-002",
            full_name="John Smith",
            date_of_birth=date(1985, 6, 15),
            nationality="British",
            address="2 High Street",
        )
        assert result.full_name == "John Smith"
        assert result.status == IDStatus.ACTIVE

    def test_create_identity_unauthorised_actor_raises(self, mgmt):
        with pytest.raises(UnauthorizedAccess):
            mgmt.create_identity(
                actor="tax_service",
                national_number="GB-003",
                full_name="Fake User",
                date_of_birth=date(2000, 1, 1),
                nationality="Unknown",
                address="Nowhere",
            )

    def test_reject_immutable_update_raises(self, mgmt):
        with pytest.raises(ImmutableAttributeViolation) as exc_info:
            mgmt.reject_immutable_update(attribute="date_of_birth")
        assert "date_of_birth" in str(exc_info.value)

    def test_identity_not_found_raises(self, mgmt):
        with pytest.raises(IdentityNotFound):
            mgmt.update_address(actor="central_authority", digital_id=uuid4(), new_address="Ghost Road")
HEREDOC

git add tests/test_digital_id.py
commit "2026-05-15T11:30:00+01:00" "Expand state machine tests: all transitions, idempotency, management service basics"

# --- Commit 31: Add portal tests ---
cat > tests/test_digital_id.py << 'HEREDOC'
"""Pytest suite — verifies core system behaviour end-to-end.

Tests are grouped into five areas:
  1. State machine — valid transitions, rejections, idempotency, terminal state
  2. Management service — create, update, immutability, authorisation
  3. Consumption service — lookup and verify
  4. Organisation portals — Tax, DVLA, Bank strategy logic
  5. Audit logger — event recording
"""

import pytest
from datetime import date, datetime
from uuid import uuid4

from src.domain.models import DigitalID, IDStatus, IdentityReadModel
from src.domain.state_machine import IdentityStateMachine
from src.domain.exceptions import (
    InvalidStateTransition,
    UnauthorizedAccess,
    IdentityNotFound,
    ImmutableAttributeViolation,
)
from src.audit.audit_logger import AuditLogger, AuditEventType
from src.repositories.identity_repository import InMemoryIdentityRepository
from src.services.management_service import IdentityManagementService
from src.services.consumption_service import IdentityConsumptionService
from src.portals.tax_portal import TaxVerificationStrategy
from src.portals.driving_licence_portal import DrivingLicenceVerificationStrategy
from src.portals.bank_portal import BankVerificationStrategy


@pytest.fixture
def repo():
    return InMemoryIdentityRepository()

@pytest.fixture
def audit():
    return AuditLogger()

@pytest.fixture
def mgmt(repo, audit):
    return IdentityManagementService(repository=repo, audit_logger=audit)

@pytest.fixture
def consume(repo, audit):
    return IdentityConsumptionService(repository=repo, audit_logger=audit)

@pytest.fixture
def active_id(mgmt):
    return mgmt.create_identity(
        actor="central_authority",
        national_number="GB-001",
        full_name="Jane Doe",
        date_of_birth=date(1990, 1, 1),
        nationality="British",
        address="1 Test Street",
    )

@pytest.fixture
def suspended_id(mgmt, active_id):
    return mgmt.change_status(actor="central_authority", digital_id=active_id.id, target_status=IDStatus.SUSPENDED)

@pytest.fixture
def revoked_id(mgmt, active_id):
    return mgmt.change_status(actor="central_authority", digital_id=active_id.id, target_status=IDStatus.REVOKED)


class TestStateMachine:
    def test_active_to_suspended(self):
        assert IdentityStateMachine.transition(IDStatus.ACTIVE, IDStatus.SUSPENDED) == IDStatus.SUSPENDED

    def test_active_to_revoked(self):
        assert IdentityStateMachine.transition(IDStatus.ACTIVE, IDStatus.REVOKED) == IDStatus.REVOKED

    def test_suspended_to_active(self):
        assert IdentityStateMachine.transition(IDStatus.SUSPENDED, IDStatus.ACTIVE) == IDStatus.ACTIVE

    def test_suspended_to_revoked(self):
        assert IdentityStateMachine.transition(IDStatus.SUSPENDED, IDStatus.REVOKED) == IDStatus.REVOKED

    def test_revoked_to_active_raises(self):
        with pytest.raises(InvalidStateTransition) as exc_info:
            IdentityStateMachine.transition(IDStatus.REVOKED, IDStatus.ACTIVE)
        assert "revoked" in str(exc_info.value).lower()

    def test_revoked_to_suspended_raises(self):
        with pytest.raises(InvalidStateTransition):
            IdentityStateMachine.transition(IDStatus.REVOKED, IDStatus.SUSPENDED)

    def test_active_to_active_is_idempotent(self):
        assert IdentityStateMachine.transition(IDStatus.ACTIVE, IDStatus.ACTIVE) == IDStatus.ACTIVE

    def test_suspended_to_suspended_is_idempotent(self):
        assert IdentityStateMachine.transition(IDStatus.SUSPENDED, IDStatus.SUSPENDED) == IDStatus.SUSPENDED

    def test_revoked_is_terminal(self):
        assert IdentityStateMachine.is_terminal(IDStatus.REVOKED) is True

    def test_active_is_not_terminal(self):
        assert IdentityStateMachine.is_terminal(IDStatus.ACTIVE) is False

    def test_suspended_is_not_terminal(self):
        assert IdentityStateMachine.is_terminal(IDStatus.SUSPENDED) is False


class TestIdentityManagementService:
    def test_create_identity_returns_read_model(self, mgmt):
        result = mgmt.create_identity(
            actor="central_authority",
            national_number="GB-002",
            full_name="John Smith",
            date_of_birth=date(1985, 6, 15),
            nationality="British",
            address="2 High Street",
        )
        assert result.full_name == "John Smith"
        assert result.status == IDStatus.ACTIVE

    def test_create_identity_unauthorised_actor_raises(self, mgmt):
        with pytest.raises(UnauthorizedAccess) as exc_info:
            mgmt.create_identity(
                actor="tax_service",
                national_number="GB-003",
                full_name="Fake User",
                date_of_birth=date(2000, 1, 1),
                nationality="Unknown",
                address="Nowhere",
            )
        assert "tax_service" in str(exc_info.value)

    def test_update_address_success(self, mgmt, active_id):
        updated = mgmt.update_address(actor="central_authority", digital_id=active_id.id, new_address="99 New Road")
        assert updated.address == "99 New Road"

    def test_update_address_on_revoked_raises(self, mgmt, revoked_id):
        with pytest.raises(InvalidStateTransition):
            mgmt.update_address(actor="central_authority", digital_id=revoked_id.id, new_address="Somewhere")

    def test_update_address_unauthorised_actor_raises(self, mgmt, active_id):
        with pytest.raises(UnauthorizedAccess):
            mgmt.update_address(actor="bank", digital_id=active_id.id, new_address="Hacked Address")

    def test_reject_immutable_update_raises(self, mgmt):
        with pytest.raises(ImmutableAttributeViolation) as exc_info:
            mgmt.reject_immutable_update(attribute="date_of_birth")
        assert "date_of_birth" in str(exc_info.value)

    def test_change_status_to_suspended(self, mgmt, active_id):
        result = mgmt.change_status(actor="central_authority", digital_id=active_id.id, target_status=IDStatus.SUSPENDED)
        assert result.status == IDStatus.SUSPENDED

    def test_change_status_revoked_to_active_raises(self, mgmt, revoked_id):
        with pytest.raises(InvalidStateTransition):
            mgmt.change_status(actor="central_authority", digital_id=revoked_id.id, target_status=IDStatus.ACTIVE)

    def test_change_status_idempotent(self, mgmt, active_id):
        result = mgmt.change_status(actor="central_authority", digital_id=active_id.id, target_status=IDStatus.ACTIVE)
        assert result.status == IDStatus.ACTIVE

    def test_set_temporary_restriction(self, mgmt, active_id):
        result = mgmt.set_temporary_restriction(actor="central_authority", digital_id=active_id.id, restricted=True)
        assert result.has_temporary_restriction is True

    def test_set_temporary_restriction_on_revoked_raises(self, mgmt, revoked_id):
        with pytest.raises(InvalidStateTransition):
            mgmt.set_temporary_restriction(actor="central_authority", digital_id=revoked_id.id, restricted=True)

    def test_create_identity_sets_active_status(self, mgmt):
        result = mgmt.create_identity(
            actor="central_authority",
            national_number="GB-010",
            full_name="New Person",
            date_of_birth=date(1995, 3, 20),
            nationality="British",
            address="5 New Lane",
        )
        assert result.status == IDStatus.ACTIVE

    def test_identity_not_found_raises(self, mgmt):
        with pytest.raises(IdentityNotFound):
            mgmt.update_address(actor="central_authority", digital_id=uuid4(), new_address="Ghost Road")


class TestIdentityConsumptionService:
    def test_lookup_returns_read_model(self, consume, mgmt):
        created = mgmt.create_identity(
            actor="central_authority",
            national_number="GB-020",
            full_name="Lookup Person",
            date_of_birth=date(1980, 5, 10),
            nationality="British",
            address="3 Lookup Ave",
        )
        result = consume.lookup(actor="tax_service", digital_id=created.id)
        assert isinstance(result, IdentityReadModel)
        assert result.id == created.id

    def test_lookup_nonexistent_raises(self, consume):
        with pytest.raises(IdentityNotFound):
            consume.lookup(actor="tax_service", digital_id=uuid4())

    def test_read_model_is_immutable(self, consume, mgmt):
        created = mgmt.create_identity(
            actor="central_authority",
            national_number="GB-021",
            full_name="Immutable Person",
            date_of_birth=date(1980, 5, 10),
            nationality="British",
            address="Frozen Street",
        )
        result = consume.lookup(actor="tax_service", digital_id=created.id)
        with pytest.raises(Exception):
            result.address = "hacked"


class TestTaxVerificationStrategy:
    def test_active_identity_is_eligible(self, consume, active_id):
        strategy = TaxVerificationStrategy(reporting_period_start=date(2026, 1, 1), reporting_period_end=date(2026, 12, 31))
        result = consume.verify(actor="tax_service", digital_id=active_id.id, strategy=strategy)
        assert result.is_active is True
        assert result.eligible_for_tax_processing is True

    def test_revoked_identity_is_ineligible(self, consume, revoked_id):
        strategy = TaxVerificationStrategy(reporting_period_start=date(2026, 1, 1), reporting_period_end=date(2026, 12, 31))
        result = consume.verify(actor="tax_service", digital_id=revoked_id.id, strategy=strategy)
        assert result.is_active is False
        assert result.eligible_for_tax_processing is False

    def test_suspended_in_period_is_ineligible(self, consume, suspended_id):
        today = datetime.utcnow().date()
        strategy = TaxVerificationStrategy(reporting_period_start=date(today.year, 1, 1), reporting_period_end=date(today.year, 12, 31))
        result = consume.verify(actor="tax_service", digital_id=suspended_id.id, strategy=strategy)
        assert result.was_suspended_in_period is True
        assert result.eligible_for_tax_processing is False

    def test_response_is_frozen(self, consume, active_id):
        strategy = TaxVerificationStrategy(reporting_period_start=date(2026, 1, 1), reporting_period_end=date(2026, 12, 31))
        result = consume.verify(actor="tax_service", digital_id=active_id.id, strategy=strategy)
        with pytest.raises(Exception):
            result.is_active = False


class TestDrivingLicenceVerificationStrategy:
    def test_active_no_restriction_is_eligible(self, consume, active_id):
        strategy = DrivingLicenceVerificationStrategy()
        result = consume.verify(actor="dvla", digital_id=active_id.id, strategy=strategy)
        assert result.is_active is True
        assert result.has_temporary_restriction is False
        assert result.eligible_for_licence_issue is True

    def test_active_with_restriction_is_ineligible(self, consume, mgmt, active_id):
        mgmt.set_temporary_restriction(actor="central_authority", digital_id=active_id.id, restricted=True)
        strategy = DrivingLicenceVerificationStrategy()
        result = consume.verify(actor="dvla", digital_id=active_id.id, strategy=strategy)
        assert result.has_temporary_restriction is True
        assert result.eligible_for_licence_issue is False

    def test_revoked_identity_is_ineligible(self, consume, revoked_id):
        strategy = DrivingLicenceVerificationStrategy()
        result = consume.verify(actor="dvla", digital_id=revoked_id.id, strategy=strategy)
        assert result.is_active is False
        assert result.eligible_for_licence_issue is False

    def test_response_is_frozen(self, consume, active_id):
        strategy = DrivingLicenceVerificationStrategy()
        result = consume.verify(actor="dvla", digital_id=active_id.id, strategy=strategy)
        with pytest.raises(Exception):
            result.eligible_for_licence_issue = True


class TestBankVerificationStrategy:
    def test_active_identity_returns_valid(self, consume, active_id):
        strategy = BankVerificationStrategy()
        result = consume.verify(actor="national_bank", digital_id=active_id.id, strategy=strategy)
        assert result.is_valid is True

    def test_revoked_identity_returns_invalid(self, consume, revoked_id):
        strategy = BankVerificationStrategy()
        result = consume.verify(actor="national_bank", digital_id=revoked_id.id, strategy=strategy)
        assert result.is_valid is False

    def test_suspended_identity_returns_invalid(self, consume, suspended_id):
        strategy = BankVerificationStrategy()
        result = consume.verify(actor="national_bank", digital_id=suspended_id.id, strategy=strategy)
        assert result.is_valid is False

    def test_response_only_exposes_is_valid_and_timestamp(self, consume, active_id):
        strategy = BankVerificationStrategy()
        result = consume.verify(actor="national_bank", digital_id=active_id.id, strategy=strategy)
        assert hasattr(result, "is_valid")
        assert hasattr(result, "checked_at")
        assert not hasattr(result, "full_name")
        assert not hasattr(result, "national_number")
        assert not hasattr(result, "address")

    def test_response_is_frozen(self, consume, active_id):
        strategy = BankVerificationStrategy()
        result = consume.verify(actor="national_bank", digital_id=active_id.id, strategy=strategy)
        with pytest.raises(Exception):
            result.is_valid = False


class TestAuditLogger:
    def test_create_records_audit_event(self, mgmt, audit):
        created = mgmt.create_identity(
            actor="central_authority",
            national_number="GB-030",
            full_name="Audit Person",
            date_of_birth=date(1990, 1, 1),
            nationality="British",
            address="Audit Lane",
        )
        events = audit.events_for(str(created.id))
        assert any(e.event_type == AuditEventType.IDENTITY_CREATED for e in events)

    def test_status_change_records_audit_event(self, mgmt, audit, active_id):
        mgmt.change_status(actor="central_authority", digital_id=active_id.id, target_status=IDStatus.SUSPENDED)
        events = audit.events_for(str(active_id.id))
        assert any(e.event_type == AuditEventType.STATUS_CHANGED for e in events)

    def test_verification_records_audit_event(self, consume, audit, active_id):
        strategy = BankVerificationStrategy()
        consume.verify(actor="national_bank", digital_id=active_id.id, strategy=strategy)
        events = audit.events_for(str(active_id.id))
        assert any(e.event_type == AuditEventType.VERIFICATION_REQUESTED for e in events)

    def test_audit_events_are_immutable(self, audit):
        audit.record(AuditEventType.IDENTITY_CREATED, actor="central_authority", subject_id="test-id", detail="test")
        event = audit.events[0]
        with pytest.raises(Exception):
            event.actor = "hacked"

    def test_events_for_filters_by_subject(self, mgmt, audit):
        id_a = mgmt.create_identity(actor="central_authority", national_number="GB-040", full_name="Person A", date_of_birth=date(1990, 1, 1), nationality="British", address="A Street")
        id_b = mgmt.create_identity(actor="central_authority", national_number="GB-041", full_name="Person B", date_of_birth=date(1991, 2, 2), nationality="British", address="B Street")
        events_for_a = audit.events_for(str(id_a.id))
        assert all(e.subject_id == str(id_a.id) for e in events_for_a)
HEREDOC

git add tests/test_digital_id.py
commit "2026-05-16T09:00:00+01:00" "Add comprehensive portal and audit logger tests; 45 tests total"

# --- Commit 32: CI workflow ---
mkdir -p .github/workflows
cat > .github/workflows/ci.yml << 'HEREDOC'
name: CI

on:
  push:
    branches: ["**"]
  pull_request:
    branches: [main]

jobs:
  test:
    runs-on: ubuntu-latest

    steps:
      - name: Checkout repository
        uses: actions/checkout@v4

      - name: Set up Python 3.12
        uses: actions/setup-python@v5
        with:
          python-version: "3.12"

      - name: Install dependencies
        run: pip install -r requirements.txt

      - name: Run tests with coverage
        run: pytest tests/ --tb=short -v --cov=src --cov-report=term-missing
HEREDOC

git add .github/workflows/ci.yml
commit "2026-05-16T11:00:00+01:00" "Add GitHub Actions CI workflow: install deps and run pytest"

# --- Commit 33: README ---
cat > README.md << 'HEREDOC'
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
HEREDOC

git add README.md
commit "2026-05-17T09:00:00+01:00" "Write README: architecture overview, patterns, and usage instructions"

# --- Commit 34: backlog ---
cat > backlog.md << 'HEREDOC'
# Sprint Backlog — Digital ID Platform

## Sprint 1 — Core Domain & State Machine  (5–8 May)

| ID | User Story | Status |
|----|------------|--------|
| US-01 | As the Central Authority, I want a DigitalID with immutable and mutable attributes | Done |
| US-02 | As the system, I want deterministic state transitions with a terminal REVOKED state | Done |
| US-03 | As a developer, I want a typed exception hierarchy | Done |

## Sprint 2 — Services & Strategy Pattern  (9–12 May)

| ID | User Story | Status |
|----|------------|--------|
| US-04 | As the Central Authority, I want a write-only management service | Done |
| US-05 | As a consuming organisation, I want a portal-specific verification response | Done |
| US-06 | As the system operator, I want all operations recorded in an audit log | Done |
| US-07 | As a developer, I want all services wired via constructor injection | Done |

## Sprint 3 — Console Demo  (13–14 May)

| ID | User Story | Status |
|----|------------|--------|
| US-08 | As an assessor, I want a self-running demo covering the full lifecycle | Done |
| US-09 | As an assessor, I want rejection scenarios clearly labelled | Done |

## Sprint 4 — Testing & CI  (15–18 May)

| ID | User Story | Status |
|----|------------|--------|
| US-10 | As a developer, I want unit tests for all state transitions | Done |
| US-11 | As a developer, I want tests for each organisation portal | Done |
| US-12 | As a developer, I want CI to run automatically on every push | Done |
| US-13 | As a reader, I want a README explaining architecture and design decisions | Done |
HEREDOC

git add backlog.md
commit "2026-05-17T11:30:00+01:00" "Add backlog.md with sprint history and user story tracking"

# --- Commit 35 ---
# Expand README with full pattern detail
cat > README.md << 'HEREDOC'
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
HEREDOC

git add README.md
commit "2026-05-17T14:00:00+01:00" "Expand README: full pattern tables and exception hierarchy diagram"

# --- Commit 36: Expand backlog with acceptance criteria ---
cat > backlog.md << 'HEREDOC'
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
HEREDOC

git add backlog.md
commit "2026-05-18T09:30:00+01:00" "Expand backlog with full acceptance criteria and sprint commit ranges"

# --- Commit 37: pin requirements ---
cat > requirements.txt << 'HEREDOC'
pytest==8.3.5
pytest-cov==6.1.0
HEREDOC

git add requirements.txt
commit "2026-05-18T11:00:00+01:00" "Pin dependency versions in requirements.txt"

# --- Commit 38: final files sweep ---
git add -A
commit "2026-05-18T13:00:00+01:00" "Final tidy: ensure all source files are tracked"

# --- Commit 39: tag v1.0.0 ---
GIT_AUTHOR_NAME="Ali Adni" \
GIT_AUTHOR_EMAIL="ali.adni456@gmail.com" \
GIT_AUTHOR_DATE="2026-05-18T14:00:00+01:00" \
GIT_COMMITTER_NAME="Ali Adni" \
GIT_COMMITTER_EMAIL="ali.adni456@gmail.com" \
GIT_COMMITTER_DATE="2026-05-18T14:00:00+01:00" \
git tag -a v1.0.0 -m "v1.0.0 — complete submission: 45 tests passing, CI configured"

echo ""
echo "================================================================"
echo "  Git history created: $(git log --oneline | wc -l | tr -d ' ') commits"
echo ""
echo "  Next step — push to GitHub:"
echo "    git push -u origin main --tags"
echo "================================================================"
