"""Imports a name the package's __init__.py defines, not a submodule."""

from . import tool


def use_tool(n):
    """`tool` is no file `./tool.py`: it is the package's own function."""
    return tool(n)


def tool_attr():
    """An attribute of that function: neither an edge nor an external call."""
    return tool.__name__.upper()
