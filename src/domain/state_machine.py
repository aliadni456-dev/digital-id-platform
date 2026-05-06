from src.domain.models import IDStatus
from src.domain.exceptions import InvalidStateTransition

# Defines which transitions are permitted from each state.
# REVOKED has an empty set — it is a terminal state with no exit.
_VALID_TRANSITIONS: dict[IDStatus, frozenset[IDStatus]] = {
    IDStatus.ACTIVE: frozenset({IDStatus.SUSPENDED, IDStatus.REVOKED}),
    IDStatus.SUSPENDED: frozenset({IDStatus.ACTIVE, IDStatus.REVOKED}),
    IDStatus.REVOKED: frozenset(),
}


class IdentityStateMachine:
    """Enforces deterministic, rule-based status transitions for a DigitalID."""

    @staticmethod
    def transition(current: IDStatus, target: IDStatus) -> IDStatus:
        if current == target:
            return current  # idempotent: repeating a no-op is safe

        allowed = _VALID_TRANSITIONS.get(current, frozenset())
        if target not in allowed:
            raise InvalidStateTransition(current.value, target.value)

        return target

    @staticmethod
    def is_terminal(status: IDStatus) -> bool:
        return not bool(_VALID_TRANSITIONS.get(status))
