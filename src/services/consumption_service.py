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
