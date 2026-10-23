"""A package whose calls the resolver has to follow, re-exporting one name."""

from . import sub
from .helper import double

__all__ = ["double"]
