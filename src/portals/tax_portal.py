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
