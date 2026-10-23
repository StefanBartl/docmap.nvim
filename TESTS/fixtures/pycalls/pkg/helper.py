"""Functions and a class the other modules call."""


def double(n):
    """Twice n."""
    return n * 2


def triple(n):
    """Three times n."""
    return n * 3


class Thing:
    """A class whose methods are reachable only through a receiver."""

    def go(self):
        """Take one step."""
        return self.step()

    def step(self):
        """Call a module-level function by its bare name."""
        return double(1)
