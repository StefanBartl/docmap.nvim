"""A repository that is the package itself: the scan root holds __init__.py."""


def tool(n):
    """A function of the root package, imported as `from . import tool`."""
    return n
