//! Functions the other modules call.

/// Twice n.
pub fn double(n: u32) -> u32 {
    n * 2
}

/// Three times n.
pub fn triple(n: u32) -> u32 {
    double(n) + n
}
