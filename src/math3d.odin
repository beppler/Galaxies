package main

import "core:math"
import "core:math/linalg"

Vec3 :: [3]f32

// Orientation as three orthonormal axes: right, up, forward (left-handed view space).
Basis :: struct {
	r, u, f: Vec3,
}

basis_identity :: proc() -> Basis {
	return Basis{{1, 0, 0}, {0, 1, 0}, {0, 0, 1}}
}

orthonormalize :: proc(b: ^Basis) {
	b.f = linalg.normalize(b.f)
	b.r = linalg.normalize(linalg.cross(b.u, b.f))
	b.u = linalg.cross(b.f, b.r)
}

// Positive angle: nose up.
pitch :: proc(b: ^Basis, a: f32) {
	c, s := math.cos(a), math.sin(a)
	f := b.f * c + b.u * s
	u := b.u * c - b.f * s
	b.f, b.u = f, u
}

// Positive angle: nose right.
yaw :: proc(b: ^Basis, a: f32) {
	c, s := math.cos(a), math.sin(a)
	f := b.f * c + b.r * s
	r := b.r * c - b.f * s
	b.f, b.r = f, r
}

// Positive angle: roll right (right wing down).
roll :: proc(b: ^Basis, a: f32) {
	c, s := math.cos(a), math.sin(a)
	r := b.r * c - b.u * s
	u := b.u * c + b.r * s
	b.r, b.u = r, u
}

to_local :: proc(b: Basis, v: Vec3) -> Vec3 {
	return {linalg.dot(v, b.r), linalg.dot(v, b.u), linalg.dot(v, b.f)}
}

to_world :: proc(b: Basis, v: Vec3) -> Vec3 {
	return b.r * v.x + b.u * v.y + b.f * v.z
}

random_unit :: proc(rnd: proc() -> f32) -> Vec3 {
	for {
		v := Vec3{rnd() * 2 - 1, rnd() * 2 - 1, rnd() * 2 - 1}
		l := linalg.length(v)
		if l > 0.05 && l <= 1 {
			return v / l
		}
	}
}
