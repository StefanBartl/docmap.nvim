"""`ns` has no __init__.py, so `from . import gone` can only be a submodule."""

from . import gone


def call_gone():
    """`gone` is outside this tree: an external call, not the directory `ns`."""
    return gone.run()
