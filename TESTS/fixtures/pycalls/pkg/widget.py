"""Calls through every binding shape Python has, and three it does not."""

import json  # noqa: F401 -- unused on purpose, the positive case of unused-require
import os

from . import helper
from .helper import double, triple as t


def use(n):
    """A name `from .helper import double` bound."""
    return double(n)


def via_alias(n):
    """A name bound under `as`."""
    return t(n)


def via_module(n):
    """A module `from . import helper` bound."""
    return helper.double(n)


def local_call(n):
    """This file's own function."""
    return same(n)


def same(n):
    """Called by local_call."""
    return n


def outside():
    """An absolute import: outside the tree, so no edge."""
    return os.path.join("a", "b")


def not_a_method():
    """`go` is only a method of Box here, which a bare name cannot reach."""
    return go()  # noqa: F821


def static_call():
    """A class method reached through the module and the class."""
    return helper.Thing.go(None)


class Box:
    """Methods calling methods."""

    def go(self):
        """Through self."""
        return self.size()

    def size(self):
        """Called by go and by_class."""
        return 1

    def chain(self):
        """Through an attribute whose type is unknown: no edge."""
        return self.attr.go()

    def by_class(self):
        """Through the class name."""
        return Box.size(self)

    def inherited(self):
        """Through super(): needs the class hierarchy, no edge."""
        return super().go()
