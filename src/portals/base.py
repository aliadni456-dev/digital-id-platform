from abc import ABC, abstractmethod

from src.domain.models import IdentityReadModel


class VerificationStrategy(ABC):
    """Strategy interface — each organisation portal provides a concrete implementation."""

    @abstractmethod
    def verify(self, identity: IdentityReadModel): ...
