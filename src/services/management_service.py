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
