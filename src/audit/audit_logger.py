from dataclasses import dataclass, field
from datetime import datetime
from enum import Enum


class AuditEventType(Enum):
    IDENTITY_CREATED = "identity_created"
    IDENTITY_UPDATED = "identity_updated"
    STATUS_CHANGED = "status_changed"
    IDENTITY_LOOKED_UP = "identity_looked_up"
    VERIFICATION_REQUESTED = "verification_requested"
    OPERATION_REJECTED = "operation_rejected"


@dataclass(frozen=True)
class AuditEvent:
    event_type: AuditEventType
    actor: str
    subject_id: str
    detail: str
    timestamp: datetime = field(default_factory=datetime.utcnow)
