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


class AuditLogger:
    """Central audit log. Injected into services — not a singleton."""

    def __init__(self) -> None:
        self._events: list[AuditEvent] = []

    def record(
        self,
        event_type: AuditEventType,
        actor: str,
        subject_id: str,
        detail: str,
    ) -> None:
        event = AuditEvent(
            event_type=event_type,
            actor=actor,
            subject_id=subject_id,
            detail=detail,
        )
        self._events.append(event)
        self._emit(event)

    def _emit(self, event: AuditEvent) -> None:
        ts = event.timestamp.strftime("%H:%M:%S")
        print(
            f"  [AUDIT] {ts} | {event.event_type.value}"
            f" | actor={event.actor} | id={event.subject_id} | {event.detail}"
        )

    @property
    def events(self) -> list[AuditEvent]:
        return list(self._events)

    def events_for(self, subject_id: str) -> list[AuditEvent]:
        return [e for e in self._events if e.subject_id == subject_id]
