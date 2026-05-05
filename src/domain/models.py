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
