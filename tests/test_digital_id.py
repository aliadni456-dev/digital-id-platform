import pytest
from datetime import date, datetime
from uuid import uuid4

from src.domain.models import DigitalID, IDStatus, IdentityReadModel
from src.domain.state_machine import IdentityStateMachine
from src.domain.exceptions import (
    InvalidStateTransition,
    UnauthorizedAccess,
    IdentityNotFound,
    ImmutableAttributeViolation,
)
from src.audit.audit_logger import AuditLogger, AuditEventType
from src.repositories.identity_repository import InMemoryIdentityRepository
from src.services.management_service import IdentityManagementService
from src.services.consumption_service import IdentityConsumptionService
from src.portals.bank_portal import BankVerificationStrategy


@pytest.fixture
def repo():
    return InMemoryIdentityRepository()

@pytest.fixture
def audit():
    return AuditLogger()

@pytest.fixture
def mgmt(repo, audit):
    return IdentityManagementService(repository=repo, audit_logger=audit)

@pytest.fixture
def consume(repo, audit):
    return IdentityConsumptionService(repository=repo, audit_logger=audit)

@pytest.fixture
def active_id(mgmt):
    return mgmt.create_identity(
        actor="central_authority",
        national_number="GB-001",
        full_name="Jane Doe",
        date_of_birth=date(1990, 1, 1),
        nationality="British",
        address="1 Test Street",
    )


class TestStateMachine:
    def test_active_to_suspended(self):
        assert IdentityStateMachine.transition(IDStatus.ACTIVE, IDStatus.SUSPENDED) == IDStatus.SUSPENDED

    def test_active_to_revoked(self):
        assert IdentityStateMachine.transition(IDStatus.ACTIVE, IDStatus.REVOKED) == IDStatus.REVOKED

    def test_suspended_to_active(self):
        assert IdentityStateMachine.transition(IDStatus.SUSPENDED, IDStatus.ACTIVE) == IDStatus.ACTIVE

    def test_suspended_to_revoked(self):
        assert IdentityStateMachine.transition(IDStatus.SUSPENDED, IDStatus.REVOKED) == IDStatus.REVOKED

    def test_revoked_to_active_raises(self):
        with pytest.raises(InvalidStateTransition) as exc_info:
            IdentityStateMachine.transition(IDStatus.REVOKED, IDStatus.ACTIVE)
        assert "revoked" in str(exc_info.value).lower()

    def test_revoked_to_suspended_raises(self):
        with pytest.raises(InvalidStateTransition):
            IdentityStateMachine.transition(IDStatus.REVOKED, IDStatus.SUSPENDED)

    def test_active_to_active_is_idempotent(self):
        assert IdentityStateMachine.transition(IDStatus.ACTIVE, IDStatus.ACTIVE) == IDStatus.ACTIVE

    def test_suspended_to_suspended_is_idempotent(self):
        assert IdentityStateMachine.transition(IDStatus.SUSPENDED, IDStatus.SUSPENDED) == IDStatus.SUSPENDED

    def test_revoked_is_terminal(self):
        assert IdentityStateMachine.is_terminal(IDStatus.REVOKED) is True

    def test_active_is_not_terminal(self):
        assert IdentityStateMachine.is_terminal(IDStatus.ACTIVE) is False

    def test_suspended_is_not_terminal(self):
        assert IdentityStateMachine.is_terminal(IDStatus.SUSPENDED) is False


class TestIdentityManagementService:
    def test_create_identity_returns_read_model(self, mgmt):
        result = mgmt.create_identity(
            actor="central_authority",
            national_number="GB-002",
            full_name="John Smith",
            date_of_birth=date(1985, 6, 15),
            nationality="British",
            address="2 High Street",
        )
        assert result.full_name == "John Smith"
        assert result.status == IDStatus.ACTIVE

    def test_create_identity_unauthorised_actor_raises(self, mgmt):
        with pytest.raises(UnauthorizedAccess):
            mgmt.create_identity(
                actor="tax_service",
                national_number="GB-003",
                full_name="Fake User",
                date_of_birth=date(2000, 1, 1),
                nationality="Unknown",
                address="Nowhere",
            )

    def test_reject_immutable_update_raises(self, mgmt):
        with pytest.raises(ImmutableAttributeViolation) as exc_info:
            mgmt.reject_immutable_update(attribute="date_of_birth")
        assert "date_of_birth" in str(exc_info.value)

    def test_identity_not_found_raises(self, mgmt):
        with pytest.raises(IdentityNotFound):
            mgmt.update_address(actor="central_authority", digital_id=uuid4(), new_address="Ghost Road")
