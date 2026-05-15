import pytest
from datetime import date
from uuid import uuid4

from src.domain.models import IDStatus
from src.domain.state_machine import IdentityStateMachine
from src.domain.exceptions import InvalidStateTransition
from src.audit.audit_logger import AuditLogger
from src.repositories.identity_repository import InMemoryIdentityRepository
from src.services.management_service import IdentityManagementService
from src.services.consumption_service import IdentityConsumptionService


@pytest.fixture
def repo():
    return InMemoryIdentityRepository()


@pytest.fixture
def audit():
    return AuditLogger()


@pytest.fixture
def mgmt(repo, audit):
    return IdentityManagementService(repository=repo, audit_logger=audit)


class TestStateMachine:
    def test_active_to_suspended(self):
        result = IdentityStateMachine.transition(IDStatus.ACTIVE, IDStatus.SUSPENDED)
        assert result == IDStatus.SUSPENDED

    def test_active_to_revoked(self):
        result = IdentityStateMachine.transition(IDStatus.ACTIVE, IDStatus.REVOKED)
        assert result == IDStatus.REVOKED

    def test_revoked_to_active_raises(self):
        with pytest.raises(InvalidStateTransition):
            IdentityStateMachine.transition(IDStatus.REVOKED, IDStatus.ACTIVE)

    def test_revoked_is_terminal(self):
        assert IdentityStateMachine.is_terminal(IDStatus.REVOKED) is True
