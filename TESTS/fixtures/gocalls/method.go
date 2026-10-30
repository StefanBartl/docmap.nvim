package widgets

// Widget has a method named like a package-level function of a sibling file.
type Widget struct{}

// Go is a method: only `w.Go()` or `Widget.Go(w)` reach it, never `Go()`.
func (w Widget) Go() int {
	return 0
}

// Run calls the bare name `Go`, which in Go is the package-level `func Go`
// in launch.go — never the method `Widget.Go` declared above.
func Run() int {
	return Go()
}
