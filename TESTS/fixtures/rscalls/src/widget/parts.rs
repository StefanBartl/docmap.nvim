//! Parts, two levels below the crate root.

/// The base size, through `super::super::`.
pub fn base() -> u32 {
    super::super::helper::double(1)
}
