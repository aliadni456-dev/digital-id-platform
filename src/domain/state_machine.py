from src.domain.models import IDStatus
from src.domain.exceptions import InvalidStateTransition

_VALID_TRANSITIONS: dict[IDStatus, frozenset[IDStatus]] = {
    IDStatus.ACTIVE: frozenset({IDStatus.SUSPENDED, IDStatus.REVOKED}),
    IDStatus.SUSPENDED: frozenset({IDStatus.ACTIVE, IDStatus.REVOKED}),
    IDStatus.REVOKED: frozenset(),
}


class IdentityStateMachine:
    @staticmethod
    def transition(current: IDStatus, target: IDStatus) -> IDStatus:
        if target not in _VALID_TRANSITIONS.get(current, frozenset()):
            raise InvalidStateTransition(current.value, target.value)
        return target
