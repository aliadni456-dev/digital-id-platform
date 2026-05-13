"""Digital ID Platform — Console Demonstration Script."""

import time
from datetime import date

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


def main() -> None:
    repo = InMemoryIdentityRepository()
    audit = AuditLogger()
    mgmt = IdentityManagementService(repository=repo, audit_logger=audit)
    consume = IdentityConsumptionService(repository=repo, audit_logger=audit)

    banner("DIGITAL ID PLATFORM  |  SYSTEM DEMONSTRATION")

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


if __name__ == "__main__":
    main()
