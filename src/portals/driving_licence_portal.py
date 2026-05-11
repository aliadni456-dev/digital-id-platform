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
