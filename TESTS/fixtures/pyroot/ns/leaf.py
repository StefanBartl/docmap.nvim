"""A module of a namespace package (no __init__.py) below the root package."""

from .. import tool


def leaf(n):
    """`..` is the root package, and `tool` is its own function."""
    return tool(n)
