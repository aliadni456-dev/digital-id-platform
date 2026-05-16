"""Pytest suite — verifies core system behaviour end-to-end.

Tests are grouped into five areas:
  1. State machine — valid transitions, rejections, idempotency, terminal state
  2. Management service — create, update, immutability, authorisation
  3. Consumption service — lookup and verify
  4. Organisation portals — Tax, DVLA, Bank strategy logic
  5. Audit logger — event recording
"""

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
from src.portals.tax_portal import TaxVerificationStrategy
from src.portals.driving_licence_portal import DrivingLicenceVerificationStrategy
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

@pytest.fixture
def suspended_id(mgmt, active_id):
    return mgmt.change_status(actor="central_authority", digital_id=active_id.id, target_status=IDStatus.SUSPENDED)

@pytest.fixture
def revoked_id(mgmt, active_id):
    return mgmt.change_status(actor="central_authority", digital_id=active_id.id, target_status=IDStatus.REVOKED)


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
        with pytest.raises(UnauthorizedAccess) as exc_info:
            mgmt.create_identity(
                actor="tax_service",
                national_number="GB-003",
                full_name="Fake User",
                date_of_birth=date(2000, 1, 1),
                nationality="Unknown",
                address="Nowhere",
            )
        assert "tax_service" in str(exc_info.value)

    def test_update_address_success(self, mgmt, active_id):
        updated = mgmt.update_address(actor="central_authority", digital_id=active_id.id, new_address="99 New Road")
        assert updated.address == "99 New Road"

    def test_update_address_on_revoked_raises(self, mgmt, revoked_id):
        with pytest.raises(InvalidStateTransition):
            mgmt.update_address(actor="central_authority", digital_id=revoked_id.id, new_address="Somewhere")

    def test_update_address_unauthorised_actor_raises(self, mgmt, active_id):
        with pytest.raises(UnauthorizedAccess):
            mgmt.update_address(actor="bank", digital_id=active_id.id, new_address="Hacked Address")

    def test_reject_immutable_update_raises(self, mgmt):
        with pytest.raises(ImmutableAttributeViolation) as exc_info:
            mgmt.reject_immutable_update(attribute="date_of_birth")
        assert "date_of_birth" in str(exc_info.value)

    def test_change_status_to_suspended(self, mgmt, active_id):
        result = mgmt.change_status(actor="central_authority", digital_id=active_id.id, target_status=IDStatus.SUSPENDED)
        assert result.status == IDStatus.SUSPENDED

    def test_change_status_revoked_to_active_raises(self, mgmt, revoked_id):
        with pytest.raises(InvalidStateTransition):
            mgmt.change_status(actor="central_authority", digital_id=revoked_id.id, target_status=IDStatus.ACTIVE)

    def test_change_status_idempotent(self, mgmt, active_id):
        result = mgmt.change_status(actor="central_authority", digital_id=active_id.id, target_status=IDStatus.ACTIVE)
        assert result.status == IDStatus.ACTIVE

    def test_set_temporary_restriction(self, mgmt, active_id):
        result = mgmt.set_temporary_restriction(actor="central_authority", digital_id=active_id.id, restricted=True)
        assert result.has_temporary_restriction is True

    def test_set_temporary_restriction_on_revoked_raises(self, mgmt, revoked_id):
        with pytest.raises(InvalidStateTransition):
            mgmt.set_temporary_restriction(actor="central_authority", digital_id=revoked_id.id, restricted=True)

    def test_create_identity_sets_active_status(self, mgmt):
        result = mgmt.create_identity(
            actor="central_authority",
            national_number="GB-010",
            full_name="New Person",
            date_of_birth=date(1995, 3, 20),
            nationality="British",
            address="5 New Lane",
        )
        assert result.status == IDStatus.ACTIVE

    def test_identity_not_found_raises(self, mgmt):
        with pytest.raises(IdentityNotFound):
            mgmt.update_address(actor="central_authority", digital_id=uuid4(), new_address="Ghost Road")


class TestIdentityConsumptionService:
    def test_lookup_returns_read_model(self, consume, mgmt):
        created = mgmt.create_identity(
            actor="central_authority",
            national_number="GB-020",
            full_name="Lookup Person",
            date_of_birth=date(1980, 5, 10),
            nationality="British",
            address="3 Lookup Ave",
        )
        result = consume.lookup(actor="tax_service", digital_id=created.id)
        assert isinstance(result, IdentityReadModel)
        assert result.id == created.id

    def test_lookup_nonexistent_raises(self, consume):
        with pytest.raises(IdentityNotFound):
            consume.lookup(actor="tax_service", digital_id=uuid4())

    def test_read_model_is_immutable(self, consume, mgmt):
        created = mgmt.create_identity(
            actor="central_authority",
            national_number="GB-021",
            full_name="Immutable Person",
            date_of_birth=date(1980, 5, 10),
            nationality="British",
            address="Frozen Street",
        )
        result = consume.lookup(actor="tax_service", digital_id=created.id)
        with pytest.raises(Exception):
            result.address = "hacked"


class TestTaxVerificationStrategy:
    def test_active_identity_is_eligible(self, consume, active_id):
        strategy = TaxVerificationStrategy(reporting_period_start=date(2026, 1, 1), reporting_period_end=date(2026, 12, 31))
        result = consume.verify(actor="tax_service", digital_id=active_id.id, strategy=strategy)
        assert result.is_active is True
        assert result.eligible_for_tax_processing is True

    def test_revoked_identity_is_ineligible(self, consume, revoked_id):
        strategy = TaxVerificationStrategy(reporting_period_start=date(2026, 1, 1), reporting_period_end=date(2026, 12, 31))
        result = consume.verify(actor="tax_service", digital_id=revoked_id.id, strategy=strategy)
        assert result.is_active is False
        assert result.eligible_for_tax_processing is False

    def test_suspended_in_period_is_ineligible(self, consume, suspended_id):
        today = datetime.utcnow().date()
        strategy = TaxVerificationStrategy(reporting_period_start=date(today.year, 1, 1), reporting_period_end=date(today.year, 12, 31))
        result = consume.verify(actor="tax_service", digital_id=suspended_id.id, strategy=strategy)
        assert result.was_suspended_in_period is True
        assert result.eligible_for_tax_processing is False

    def test_response_is_frozen(self, consume, active_id):
        strategy = TaxVerificationStrategy(reporting_period_start=date(2026, 1, 1), reporting_period_end=date(2026, 12, 31))
        result = consume.verify(actor="tax_service", digital_id=active_id.id, strategy=strategy)
        with pytest.raises(Exception):
            result.is_active = False


class TestDrivingLicenceVerificationStrategy:
    def test_active_no_restriction_is_eligible(self, consume, active_id):
        strategy = DrivingLicenceVerificationStrategy()
        result = consume.verify(actor="dvla", digital_id=active_id.id, strategy=strategy)
        assert result.is_active is True
        assert result.has_temporary_restriction is False
        assert result.eligible_for_licence_issue is True

    def test_active_with_restriction_is_ineligible(self, consume, mgmt, active_id):
        mgmt.set_temporary_restriction(actor="central_authority", digital_id=active_id.id, restricted=True)
        strategy = DrivingLicenceVerificationStrategy()
        result = consume.verify(actor="dvla", digital_id=active_id.id, strategy=strategy)
        assert result.has_temporary_restriction is True
        assert result.eligible_for_licence_issue is False

    def test_revoked_identity_is_ineligible(self, consume, revoked_id):
        strategy = DrivingLicenceVerificationStrategy()
        result = consume.verify(actor="dvla", digital_id=revoked_id.id, strategy=strategy)
        assert result.is_active is False
        assert result.eligible_for_licence_issue is False

    def test_response_is_frozen(self, consume, active_id):
        strategy = DrivingLicenceVerificationStrategy()
        result = consume.verify(actor="dvla", digital_id=active_id.id, strategy=strategy)
        with pytest.raises(Exception):
            result.eligible_for_licence_issue = True


class TestBankVerificationStrategy:
    def test_active_identity_returns_valid(self, consume, active_id):
        strategy = BankVerificationStrategy()
        result = consume.verify(actor="national_bank", digital_id=active_id.id, strategy=strategy)
        assert result.is_valid is True

    def test_revoked_identity_returns_invalid(self, consume, revoked_id):
        strategy = BankVerificationStrategy()
        result = consume.verify(actor="national_bank", digital_id=revoked_id.id, strategy=strategy)
        assert result.is_valid is False

    def test_suspended_identity_returns_invalid(self, consume, suspended_id):
        strategy = BankVerificationStrategy()
        result = consume.verify(actor="national_bank", digital_id=suspended_id.id, strategy=strategy)
        assert result.is_valid is False

    def test_response_only_exposes_is_valid_and_timestamp(self, consume, active_id):
        strategy = BankVerificationStrategy()
        result = consume.verify(actor="national_bank", digital_id=active_id.id, strategy=strategy)
        assert hasattr(result, "is_valid")
        assert hasattr(result, "checked_at")
        assert not hasattr(result, "full_name")
        assert not hasattr(result, "national_number")
        assert not hasattr(result, "address")

    def test_response_is_frozen(self, consume, active_id):
        strategy = BankVerificationStrategy()
        result = consume.verify(actor="national_bank", digital_id=active_id.id, strategy=strategy)
        with pytest.raises(Exception):
            result.is_valid = False


class TestAuditLogger:
    def test_create_records_audit_event(self, mgmt, audit):
        created = mgmt.create_identity(
            actor="central_authority",
            national_number="GB-030",
            full_name="Audit Person",
            date_of_birth=date(1990, 1, 1),
            nationality="British",
            address="Audit Lane",
        )
        events = audit.events_for(str(created.id))
        assert any(e.event_type == AuditEventType.IDENTITY_CREATED for e in events)

    def test_status_change_records_audit_event(self, mgmt, audit, active_id):
        mgmt.change_status(actor="central_authority", digital_id=active_id.id, target_status=IDStatus.SUSPENDED)
        events = audit.events_for(str(active_id.id))
        assert any(e.event_type == AuditEventType.STATUS_CHANGED for e in events)

    def test_verification_records_audit_event(self, consume, audit, active_id):
        strategy = BankVerificationStrategy()
        consume.verify(actor="national_bank", digital_id=active_id.id, strategy=strategy)
        events = audit.events_for(str(active_id.id))
        assert any(e.event_type == AuditEventType.VERIFICATION_REQUESTED for e in events)

    def test_audit_events_are_immutable(self, audit):
        audit.record(AuditEventType.IDENTITY_CREATED, actor="central_authority", subject_id="test-id", detail="test")
        event = audit.events[0]
        with pytest.raises(Exception):
            event.actor = "hacked"

    def test_events_for_filters_by_subject(self, mgmt, audit):
        id_a = mgmt.create_identity(actor="central_authority", national_number="GB-040", full_name="Person A", date_of_birth=date(1990, 1, 1), nationality="British", address="A Street")
        id_b = mgmt.create_identity(actor="central_authority", national_number="GB-041", full_name="Person B", date_of_birth=date(1991, 2, 2), nationality="British", address="B Street")
        events_for_a = audit.events_for(str(id_a.id))
        assert all(e.subject_id == str(id_a.id) for e in events_for_a)
