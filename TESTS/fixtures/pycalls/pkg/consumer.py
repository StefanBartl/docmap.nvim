"""Imports a name the package's __init__.py defines, not a submodule."""

from . import Kit, tool
from .helper import Thing


def use_tool(n):
    """`tool` is no file `./tool.py`: it is the package's own function."""
    return tool(n)


def tool_attr():
    """An attribute of that function: neither an edge nor an external call."""
    return tool.__name__.upper()


def use_class():
    """`Thing` is a class a named import bound: `Thing.go` is its method."""
    return Thing.go(None)


def use_own_class():
    """`Kit` is a class of the package's __init__.py, bound the same way."""
    return Kit.make(None)
