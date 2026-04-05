# Changelog

## Unreleased — Sync from eop_core

### Bug Fixes

- `valid?` now resets errors between calls — previously errors accumulated across invocations
- `typecast` no longer swallows `false` return values (used `|| value` which treated `false` as nil)
- `instantiate_type` returns nil for nil input instead of raising NoMethodError
- `validate_recognized_types` uses `!value.nil?` instead of `value != nil` to avoid ActiveSupport DateTime comparison bug

### Behavioral Changes

- `assert_not_blank` is now a distinct validation from `assert_required` — checks for non-whitespace (`/\S/`) rather than just empty/nil
- `Errors#to_h` added for accessing the underlying error hash
- Mapping key attribute assignment now works bidirectionally (set via name or mapping_key)
- Removed deprecated `Fixnum` from `PRIMITIVE_CLASSES`

### Code Quality

- Modern Ruby syntax: safe navigation, guard clauses, `rescue StandardError`, symbol method names
- Extracted `build_validators`, `build_seq_of`, `build_map_of` helpers in `TypeDef`
- Extracted `recognized_scalar_type?` and `merge_value_errors` in `TypeDef`
- `Errors#each_error` uses `yield` instead of `blk.call`
- `ModelValidations#each_error` uses anonymous block forwarding (`&`)
- Added `# frozen_string_literal: true` to `type_def.rb`

### Tests

- Expanded `assert_not_blank` coverage (nil, empty, whitespace, non-blank, leading/trailing whitespace)
- `valid?` error reset between calls
- Boolean typecast with falsey values
- `instantiate_type` nil handling
- DateTime `<=>` nil edge case in validate
- Mapping key bidirectional assignment
- Nested association messages with mapping key
