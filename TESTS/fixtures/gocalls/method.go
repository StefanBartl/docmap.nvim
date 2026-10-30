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

// Stack is generic, and its pointer receiver `*Stack[T]` nests the type
// name one level deeper than `*Widget` does.
type Stack[T any] struct{}

// Push is a method all the same: a bare `Push()` never reaches it.
func (s *Stack[T]) Push() int {
	return 0
}

// Fill calls the bare name `Push`, the package-level `func Push` of launch.go.
func Fill() int {
	return Push()
}
