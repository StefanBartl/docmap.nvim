//! Calls through every path shape Rust has, and two it does not resolve.

mod helper;
mod widget;

use crate::helper::double;
use crate::helper::{self as h, triple as t};
use crate::widget::Widget;

/// A name `use` bound.
pub fn by_use(n: u32) -> u32 {
    double(n)
}

/// A name bound under `as`.
pub fn by_alias(n: u32) -> u32 {
    t(n)
}

/// A module bound under `as`.
pub fn by_module_alias(n: u32) -> u32 {
    h::double(n)
}

/// An absolute path.
pub fn by_crate_path(n: u32) -> u32 {
    crate::helper::triple(n)
}

/// A child module declared with `mod helper;`.
pub fn by_child(n: u32) -> u32 {
    helper::double(n)
}

/// An associated function of an imported type; `.size()` on its result has
/// a receiver of unknown type and is no edge.
pub fn by_type() -> u32 {
    Widget::new().size()
}

/// This file's own function.
pub fn local_call() -> u32 {
    same()
}

fn same() -> u32 {
    inner::deep()
}

/// Outside the crate, and a macro: no edges.
pub fn outside() -> String {
    println!("x");
    String::from("x")
}

mod inner {
    /// Its sibling in the inline module, by its bare name.
    pub fn deep() -> u32 {
        helper_in()
    }

    fn helper_in() -> u32 {
        super::same_level()
    }
}

fn same_level() -> u32 {
    1
}
