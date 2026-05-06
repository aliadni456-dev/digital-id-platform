from abc import ABC, abstractmethod
from uuid import UUID

from src.domain.models import DigitalID
from src.domain.exceptions import IdentityNotFound


class IdentityRepository(ABC):
    """Abstract persistence contract — services depend on this, not on concrete stores."""

    @abstractmethod
    def save(self, identity: DigitalID) -> None: ...

    @abstractmethod
    def find_by_id(self, digital_id: UUID) -> DigitalID: ...

    @abstractmethod
    def find_by_national_number(self, national_number: str) -> DigitalID: ...

    @abstractmethod
    def exists(self, digital_id: UUID) -> bool: ...

    @abstractmethod
    def all(self) -> list[DigitalID]: ...


class InMemoryIdentityRepository(IdentityRepository):
    """In-memory implementation used for the console demo and tests."""

    def __init__(self) -> None:
        self._store: dict[UUID, DigitalID] = {}

    def save(self, identity: DigitalID) -> None:
        self._store[identity.id] = identity

    def find_by_id(self, digital_id: UUID) -> DigitalID:
        if digital_id not in self._store:
            raise IdentityNotFound(str(digital_id))
        return self._store[digital_id]

    def find_by_national_number(self, national_number: str) -> DigitalID:
        for identity in self._store.values():
            if identity.national_number == national_number:
                return identity
        raise IdentityNotFound(national_number)

    def exists(self, digital_id: UUID) -> bool:
        return digital_id in self._store

    def all(self) -> list[DigitalID]:
        return list(self._store.values())
