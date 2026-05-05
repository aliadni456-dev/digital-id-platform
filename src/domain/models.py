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
