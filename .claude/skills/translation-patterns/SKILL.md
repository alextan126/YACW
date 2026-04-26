---
name: translation-patterns
description: The catalogue of recurring C to idiomatic-Rust mappings and the absolute "no unsafe unless justified" rule. Use whenever translating C constructs to Rust (in the translator and test-translator subagents) or planning such translations (in the planners). Lists the safe-construct-of-first-resort for each common C pattern.
---

This skill is the translator's first-resort lookup table. When you
see a C pattern, the right Rust shape usually lives below. Reach for
`unsafe` only when none of the safe options fit; when you do, you
must comment it. (See "The `unsafe` rule" at the end.)

## Pointers and references

- `const T*` parameter — `&T`
  - Pure borrow.
- `T*` parameter, mutated — `&mut T`
  - Single mutable borrow.
- `T*` parameter, nullable — `Option<&T>` / `Option<&mut T>`
  - Or `Option<NonNull<T>>` for FFI seams only.
- `T*` returned, caller frees — `Box<T>` or by-value `T`
  - Ownership moves out of the function.
- `T*` returned, callee owns — `&T` with a tied lifetime
  - Borrow into caller-supplied storage.
- `T**` out-parameter, owning — return a `T` directly
  - Rust returns aren't expensive; drop the out-parameter pattern.
- Function-pointer field in a struct — trait + `Box<dyn Trait>` or generics
  - "Vtable slot".

## Collections and buffers

- `T*` + `size_t len` (non-owning) — `&[T]` (or `&mut [T]`)
- `T*` + `size_t len` (owning) — `Vec<T>`
- `char*` + length, UTF-8 — `&str` / `String`
- `char*` + length, bytes — `&[u8]` / `Vec<u8>`
- Manual linked list of `T` — `Vec<T>`, or `VecDeque<T>` if pop-front is hot
- Manual hash table — `HashMap<K, V>` (or `BTreeMap` if ordered)
- Manual ring buffer — `VecDeque<T>`
- Stack-allocated array `T arr[N]` — `[T; N]`

## Errors and absence

- Integer error code return — `Result<T, ErrEnum>`
- `errno`-style global — a returned `Result` with a typed error
- Sentinel return value (`-1`, `NULL`) — `Result` or `Option`
- Multiple error categories in one int — enum variants, not a flat `i32`
- Panic-on-error in C (`abort()`) — `panic!` only when truly unrecoverable; otherwise `Result`

Design **one error enum per crate** by default (or per module if the
crate is large), with `#[non_exhaustive]` and a `Display`
implementation. Use `thiserror` if the plan adds it as a dependency.

## Flags and bitfields

- `#define FLAG_A 1`, `FLAG_B 2`, … — `bitflags!` macro from the `bitflags` crate
- `enum { A, B, C }` — Rust `enum`
- Discriminated union (`tag` + `union`) — Rust `enum` with payload-bearing variants

Hand-rolled flag handling with `&` / `|` on bare integers is an
anti-pattern in idiomatic Rust. Reach for `bitflags` instead.

## Control flow

- `for (i = 0; i < n; i++) a[i] = …` — `a.iter_mut().for_each(...)` or `(0..n).for_each(...)`
- `while (p) { …; p = p->next; }` — `for x in list_iter { … }` after collection design
- `goto cleanup:` cleanup chain — `?` operator on `Result`, with `Drop` for resources
- `setjmp` / `longjmp` — `Result` propagation, never replicate
- `signal` handlers in pure C — out of scope; surface as an open question

## Object-orientation in C

- Struct + table of function pointers (`vtable`) — `trait` + concrete impls
- "Subclass" struct with parent as first field — composition: parent-as-field, deref or methods
- Opaque pointer in a public header (`typedef struct foo foo_t;`) — public type, private fields, accessor methods

## Concurrency

- `pthread_mutex_t` around a struct — `Mutex<T>` (wrap the *data*, not next to it)
- `pthread_rwlock_t` — `RwLock<T>`
- Atomic int with manual barriers — `AtomicUsize` / `AtomicU64` with explicit `Ordering`
- Thread-local (`__thread`) — `thread_local!` macro

## FFI seams (when you cannot avoid them)

These are the patterns where `unsafe` is acceptable:

- `extern "C"` declarations for an external C library you must call.
- `#[repr(C)]` structs that must match a C ABI.
- Constructing a `&[T]` from a raw pointer + length you got from C.
- Implementing a callback that C will call back into.

Wrap the unsafe call in a safe Rust wrapper at the module boundary.
The rest of the crate must not see raw pointers.

## The `unsafe` rule

> **Every `unsafe` block must be immediately preceded by a comment
> that names the C pattern that forced it, explains why none of the
> safe constructs above apply, and states the invariants the unsafe
> block relies on.**

Reviewers will reject `unsafe` blocks that lack this comment. If you
cannot write the justification, you cannot write the block — surface
it as an open question instead.

A correct example:

```rust
// FFI seam: libfoo's `foo_get_buffer` returns a borrowed pointer
// owned by libfoo with a lifetime tied to `handle`. We expose it as
// a `&[u8]` whose lifetime is tied to `&self`, which holds `handle`.
// Safety invariants:
//   - `ptr` is non-null when `len > 0` (libfoo guarantees this).
//   - The buffer is not mutated while `&self` is live (we hold the
//     only handle).
let slice = unsafe { std::slice::from_raw_parts(ptr, len) };
```



