"""A package whose calls the resolver has to follow, re-exporting one name."""

from . import sub
from .helper import double

__all__ = ["Kit", "double", "tool"]


def tool(n):
    """A function of the package itself, imported as `from . import tool`."""
    return n


class Kit:
    """A class of the package itself, imported as `from . import Kit`."""

    def make(self):
        """Reached as `Kit.make()` through that named import."""
        return 1
