"""Digital ID Platform — Console Demonstration Script.

Run with:  python main.py

The script walks through the full system lifecycle without any user input,
making it easy to record a clean demo video.
"""

import time
from datetime import date

from src.domain.exceptions import (
    ImmutableAttributeViolation,
    InvalidStateTransition,
    UnauthorizedAccess,
)
from src.domain.models import IDStatus
from src.audit.audit_logger import AuditLogger
from src.repositories.identity_repository import InMemoryIdentityRepository
from src.services.management_service import IdentityManagementService
from src.services.consumption_service import IdentityConsumptionService
from src.portals.tax_portal import TaxVerificationStrategy
from src.portals.driving_licence_portal import DrivingLicenceVerificationStrategy
from src.portals.bank_portal import BankVerificationStrategy


def banner(title: str) -> None:
    width = 70
    print(f"\n{'=' * width}")
    print(f"  {title}")
    print(f"{'=' * width}")


def section(title: str) -> None:
    print(f"\n--- {title} ---")


def show(label: str, value) -> None:
    print(f"    {label:<40} {value}")


def pause() -> None:
    time.sleep(0.3)


def main() -> None:
    repo = InMemoryIdentityRepository()
    audit = AuditLogger()
    mgmt = IdentityManagementService(repository=repo, audit_logger=audit)
    consume = IdentityConsumptionService(repository=repo, audit_logger=audit)

    banner("DIGITAL ID PLATFORM  |  SYSTEM DEMONSTRATION")
    print("  Architecture:  CQS  |  State Pattern  |  Strategy Pattern")
    print("  Central Authority:  Home Ministry")
    print("  Consuming Organisations:  Tax Service, DVLA, National Bank")
    pause()

    banner("PHASE 1 — IDENTITY LIFECYCLE MANAGEMENT")

    section("1.1  Creating Digital IDs  (Central Authority only)")
    id_alice = mgmt.create_identity(
        actor="central_authority",
        national_number="GB-100001",
        full_name="Alice Pemberton",
        date_of_birth=date(1988, 3, 14),
        nationality="British",
        address="12 Baker Street, London",
    )
    show("Created:", f"{id_alice.full_name}  status={id_alice.status.value}")

    id_bob = mgmt.create_identity(
        actor="central_authority",
        national_number="GB-100002",
        full_name="Bob Harrington",
        date_of_birth=date(1975, 7, 22),
        nationality="British",
        address="99 Elm Road, Manchester",
    )
    show("Created:", f"{id_bob.full_name}  status={id_bob.status.value}")

    id_carol = mgmt.create_identity(
        actor="central_authority",
        national_number="GB-100003",
        full_name="Carol Ndungu",
        date_of_birth=date(1992, 11, 5),
        nationality="British",
        address="7 Birch Lane, Birmingham",
    )
    show("Created:", f"{id_carol.full_name}  status={id_carol.status.value}")
    pause()

    section("1.2  Updating a mutable attribute (address)")
    updated = mgmt.update_address(
        actor="central_authority",
        digital_id=id_alice.id,
        new_address="45 Oxford Street, London",
    )
    show("Alice's new address:", updated.address)
    pause()

    section("1.3  Attempting to modify an immutable attribute")
    print("  >> Caller attempts to change Alice's date_of_birth...")
    try:
        mgmt.reject_immutable_update(attribute="date_of_birth")
    except ImmutableAttributeViolation as exc:
        print(f"  [REJECTED]  {exc}")
    pause()

    section("1.4  Unauthorised creation attempt (external organisation)")
    print("  >> Tax Service attempts to create a new Digital ID...")
    try:
        mgmt.create_identity(
            actor="tax_service",
            national_number="GB-FAKE",
            full_name="Ghost User",
            date_of_birth=date(2000, 1, 1),
            nationality="Unknown",
            address="Nowhere",
        )
    except UnauthorizedAccess as exc:
        print(f"  [REJECTED]  {exc}")
    pause()

    banner("PHASE 2 — STATE MACHINE  (Active -> Suspended -> Active -> Revoked)")

    section("2.1  Suspending Bob's ID")
    mgmt.change_status(actor="central_authority", digital_id=id_bob.id, target_status=IDStatus.SUSPENDED)
    show("Bob's status:", "suspended")

    section("2.2  Re-activating Bob's ID")
    mgmt.change_status(actor="central_authority", digital_id=id_bob.id, target_status=IDStatus.ACTIVE)
    show("Bob's status:", "active")

    section("2.3  Revoking Bob's ID  (terminal state)")
    mgmt.change_status(actor="central_authority", digital_id=id_bob.id, target_status=IDStatus.REVOKED)
    show("Bob's status:", "revoked")

    section("2.4  Attempting to update a REVOKED identity")
    try:
        mgmt.update_address(actor="central_authority", digital_id=id_bob.id, new_address="1 Ghost Street")
    except InvalidStateTransition as exc:
        print(f"  [REJECTED]  {exc}")

    section("2.5  Attempting an invalid transition  (REVOKED -> ACTIVE)")
    try:
        mgmt.change_status(actor="central_authority", digital_id=id_bob.id, target_status=IDStatus.ACTIVE)
    except InvalidStateTransition as exc:
        print(f"  [REJECTED]  {exc}")

    section("2.6  Idempotent transition  (ACTIVE -> ACTIVE)")
    same = mgmt.change_status(actor="central_authority", digital_id=id_alice.id, target_status=IDStatus.ACTIVE)
    show("Alice's status (idempotent):", f"{same.status.value}  -- no error raised")

    banner("PHASE 3 — ORGANISATION PORTAL VERIFICATION  (Strategy Pattern)")

    mgmt.set_temporary_restriction(actor="central_authority", digital_id=id_alice.id, restricted=True)

    section("3.1  Tax Service Portal")
    tax_strategy = TaxVerificationStrategy(reporting_period_start=date(2026, 1, 1), reporting_period_end=date(2026, 12, 31))
    alice_tax = consume.verify(actor="tax_service", digital_id=id_alice.id, strategy=tax_strategy)
    show("    Alice eligible_for_tax_processing", alice_tax.eligible_for_tax_processing)

    section("3.2  Driving Licence Portal (DVLA)")
    dvla_strategy = DrivingLicenceVerificationStrategy()
    alice_dvla = consume.verify(actor="dvla", digital_id=id_alice.id, strategy=dvla_strategy)
    show("    Alice eligible_for_licence_issue", alice_dvla.eligible_for_licence_issue)
    carol_dvla = consume.verify(actor="dvla", digital_id=id_carol.id, strategy=dvla_strategy)
    show("    Carol eligible_for_licence_issue", carol_dvla.eligible_for_licence_issue)

    section("3.3  Bank / Employer Portal  (boolean response only)")
    bank_strategy = BankVerificationStrategy()
    alice_bank = consume.verify(actor="national_bank", digital_id=id_alice.id, strategy=bank_strategy)
    show("    Alice is_valid", alice_bank.is_valid)

    banner("DEMONSTRATION COMPLETE")


if __name__ == "__main__":
    main()
