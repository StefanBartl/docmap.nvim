"""Imports from the package above."""

from .. import helper as h
from ..helper import double


def deep(n):
    """Two calls on one line, two edges."""
    return double(n) + h.triple(n)
