package main
import "core:fmt"

IVec2 :: distinct [2]int

Data :: struct {
	a: IVec2,
	b: IVec2,
}

foo :: proc(data: ^Data, a: IVec2) {
	bar(data, a)
}

bar :: proc(data: ^Data, a: IVec2) {
	fmt.println("a =", a)
	data.a = data.b
	data.b = a
	fmt.println("a =", a)
}

main :: proc() {
	data := Data {
		a = {1, 2},
		b = {3, 4},
	}
	bar(&data, data.a)
}
