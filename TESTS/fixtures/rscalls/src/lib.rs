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

    /// A local closure named like the file's `same_level`: no edge, the
    /// file's functions are not visible in here.
    pub fn shadowed() -> u32 {
        let same_level = || 2;
        same_level()
    }
}

fn same_level() -> u32 {
    1
}

/// An error type converted into a `String`.
pub struct MyErr;

impl From<MyErr> for String {
    fn from(_: MyErr) -> String {
        String::new()
    }
}

/// `String::from` here is std's `From<&str>`, not the impl above: no edge.
pub fn label() -> String {
    String::from("x")
}

mod scoped {
    use crate::helper::triple as double;

    /// A type implemented inside an inline module.
    pub struct S;

    impl S {
        /// `double` here is the name bound in this module: helper's triple.
        pub fn m(&self) -> u32 {
            double(1)
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn through_the_glob() {
        assert_eq!(by_use(1), 2);
        let _ = by_use(2);
    }

    /// Shadows the parent's `same`, which the glob would otherwise bring in.
    fn same() -> u32 {
        0
    }

    #[test]
    fn local_beats_glob() {
        let _ = same();
    }

    #[test]
    fn a_path_through_the_glob() {
        let _ = inner::deep();
    }
}
