"""Write-side service — all identity creation and mutation operations.

Only the Central Authority (actor == 'central_authority') may call any method
here. Any other actor raises UnauthorizedAccess immediately, before any state
is read or changed.
"""

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

_IMMUTABLE_FIELDS: frozenset[str] = frozenset(
    {"national_number", "full_name", "date_of_birth", "nationality"}
)
_MUTABLE_FIELDS: frozenset[str] = frozenset({"address", "has_temporary_restriction"})


class IdentityManagementService:
    """Write-side service — all operations that create or mutate Digital IDs."""

    def __init__(self, repository: IdentityRepository, audit_logger: AuditLogger) -> None:
        self._repo = repository
        self._audit = audit_logger

    # ------------------------------------------------------------------
    # Creation
    # ------------------------------------------------------------------

    def create_identity(
        self,
        actor: str,
        national_number: str,
        full_name: str,
        date_of_birth: object,
        nationality: str,
        address: str,
    ) -> IdentityReadModel:
        self._require_central_authority(actor, "create_identity")

        now = datetime.utcnow()
        identity = DigitalID(
            id=uuid4(),
            national_number=national_number,
            full_name=full_name,
            date_of_birth=date_of_birth,  # type: ignore[arg-type]
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

    # ------------------------------------------------------------------
    # General-purpose attribute update dispatcher
    # ------------------------------------------------------------------

    def update_attribute(
        self, actor: str, digital_id: UUID, field_name: str, value: object
    ) -> IdentityReadModel:
        """Validates and routes an incoming attribute update request.

        Simulates the service boundary receiving an arbitrary field update.
        Immutable fields are rejected immediately with ImmutableAttributeViolation.
        Valid mutable updates are routed to the appropriate handler.
        """
        self._require_central_authority(actor, "update_attribute")

        if field_name in _IMMUTABLE_FIELDS:
            raise ImmutableAttributeViolation(field_name)

        if field_name == "address":
            return self.update_address(actor, digital_id, str(value))

        if field_name == "has_temporary_restriction":
            return self.set_temporary_restriction(actor, digital_id, bool(value))

        raise ImmutableAttributeViolation(field_name)

    # ------------------------------------------------------------------
    # Specific mutable-field updaters (also callable directly)
    # ------------------------------------------------------------------

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

    # ------------------------------------------------------------------
    # Status transitions
    # ------------------------------------------------------------------

    def change_status(
        self, actor: str, digital_id: UUID, target_status: IDStatus
    ) -> IdentityReadModel:
        self._require_central_authority(actor, "change_status")
        identity = self._repo.find_by_id(digital_id)

        previous = identity.status
        new_status = IdentityStateMachine.transition(previous, target_status)

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

    # ------------------------------------------------------------------
    # Internal guards
    # ------------------------------------------------------------------

    def _require_central_authority(self, actor: str, action: str) -> None:
        if actor != _CENTRAL_AUTHORITY:
            raise UnauthorizedAccess(actor, action)

    def _require_not_revoked(self, identity: DigitalID) -> None:
        if identity.status == IDStatus.REVOKED:
            raise InvalidStateTransition(
                IDStatus.REVOKED.value,
                "mutable_update — revoked identities are permanently locked",
            )
