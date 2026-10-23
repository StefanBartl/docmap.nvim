//! A binary target: a crate root of its own, so `crate::` here is the bin.

mod helper;

fn main() {
    let x = crate::helper::double(1);
    println!("{x}");
}
