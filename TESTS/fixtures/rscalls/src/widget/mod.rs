//! A type with methods, and a trait implemented for it.

pub mod parts;

/// A widget.
pub struct Widget {
    n: u32,
}

/// Something that can be sized.
pub trait Sized2 {
    /// The size.
    fn size2(&self) -> u32;
}

impl Widget {
    /// Construct, through `Self::` and a child module.
    pub fn new() -> Self {
        Self::with(parts::base())
    }

    /// Construct with a size.
    pub fn with(n: u32) -> Self {
        Widget { n }
    }

    /// Through `self.`.
    pub fn size(&self) -> u32 {
        self.scaled()
    }

    fn scaled(&self) -> u32 {
        self.n * 2
    }
}

impl Sized2 for Widget {
    fn size2(&self) -> u32 {
        self.n
    }
}
