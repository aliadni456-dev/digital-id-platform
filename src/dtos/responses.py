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
