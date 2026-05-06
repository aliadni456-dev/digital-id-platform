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
