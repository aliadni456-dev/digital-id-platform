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
