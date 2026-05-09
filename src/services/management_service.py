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
