---
paths:
  - "sig/**/*.rbs"
  - "lib/stoplight/**/*.rb"
---

# Types: RBS & Steep

Stoplight ships type signatures and checks them with Steep under strict mode.

- Every change in `lib/` needs a corresponding signature in `sig/`. Adding a public
  method, changing arity, or changing a return type without updating the `.rbs` will
  break `bundle exec steep check`.
- **Public/shipped** signatures live in `sig/stoplight/…`. **Internal** interfaces and
  ports live in `sig/_private/…` (e.g. `sig/_private/stoplight/domain/ports/`). The
  domain's collaborator interfaces (like `_DataStore`) are defined here - these are the
  contracts infrastructure must satisfy by duck typing.
- Keep duck-typed implementations conformant to their port. If you add a method to a
  domain port, update every infrastructure implementation **and** its signature.
- Steep is configured strict (`Steep::Diagnostic::Ruby.strict`). `lib/stoplight/admin`
  and `lib/stoplight/rspec` are intentionally **ignored** by the type checker - don't
  spend effort typing them, but don't move typed code into them to avoid checks.
- Workflow when editing `lib/`: change code - update `sig/` -> `bundle exec steep check`
  -> `bundle exec standardrb`.
- To distinguish `nil` and undefined values, use `optional[T]` type and `T.undefined` helper
- To unwrap nilable values, use `T.must()` helper - raises TypeError when nil.

When unsure of a type, model it from the existing port definitions rather than widening
everything to `untyped`.
