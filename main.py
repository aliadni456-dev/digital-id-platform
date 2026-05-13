"""Digital ID Platform — Console Demonstration Script.

Run with:  python main.py
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

    section("1.2  Updating a mutable attribute (address)")
    updated = mgmt.update_address(
        actor="central_authority",
        digital_id=id_alice.id,
        new_address="45 Oxford Street, London",
    )
    show("Alice's new address:", updated.address)

    section("1.3  Attempting to modify an immutable attribute")
    try:
        mgmt.reject_immutable_update(attribute="date_of_birth")
    except ImmutableAttributeViolation as exc:
        print(f"  [REJECTED]  {exc}")

    section("1.4  Unauthorised creation attempt (external organisation)")
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


if __name__ == "__main__":
    main()
