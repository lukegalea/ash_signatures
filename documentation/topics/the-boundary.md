<!--
SPDX-FileCopyrightText: 2026 Luke Galea
SPDX-License-Identifier: MIT
-->

# The boundary

The package must work in any Ash host. Two checks keep it that way, run in CI by `scripts/check-boundary.sh`:

1. **Dependencies.** No Phoenix package and no application-specific package may appear in the dependency tree.
2. **References.** No module compiled from this repository may refer to a module whose name starts with `Phoenix`,
   `AshEnterprise` or `AshBpmn`.

`scripts/check-boundary-self-test.sh` shows both checks fail when they should.
