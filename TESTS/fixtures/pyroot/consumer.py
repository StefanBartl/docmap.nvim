"""Imports a name the root package's __init__.py defines."""

from . import tool


def use_tool(n):
    """`tool` is no file `./tool.py`: it is the root package's own function."""
    return tool(n)
