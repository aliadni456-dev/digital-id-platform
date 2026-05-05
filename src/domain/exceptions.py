class DigitalIDException(Exception):
    """Base exception for all Digital ID platform errors."""


class InvalidStateTransition(DigitalIDException):
    def __init__(self, current: str, target: str) -> None:
        super().__init__(f"Cannot transition from '{current}' to '{target}'")
        self.current = current
        self.target = target


class UnauthorizedAccess(DigitalIDException):
    def __init__(self, organisation: str, action: str) -> None:
        super().__init__(
            f"Organisation '{organisation}' is not authorised to perform '{action}'"
        )
        self.organisation = organisation
        self.action = action


class IdentityNotFound(DigitalIDException):
    def __init__(self, identifier: str) -> None:
        super().__init__(f"Digital ID not found: '{identifier}'")
        self.identifier = identifier


class ImmutableAttributeViolation(DigitalIDException):
    def __init__(self, attribute: str) -> None:
        super().__init__(f"Attribute '{attribute}' is immutable and cannot be modified")
        self.attribute = attribute
