# Agent instructions

## Comments

- Maintain comments that explain why a non-obvious decision or safeguard exists.
- Prefer comments about intent, constraints, compatibility, safety, or trade-offs over comments that merely restate what the code or command does or how it is implemented.
- Add or update rationale comments when changing the behavior they describe, and remove comments that are no longer accurate.

## Project consistency

- Maintain a consistent level of code style, quality, structure, and conventions throughout the project. Follow established patterns unless there is a clear, documented reason to introduce a different one.

## Documentation

- Check whether a change requires an update to `README.md`, but only modify the README when the change materially affects documented usage, behavior, setup, or project expectations. Do not update it for every small or internal code change.

## Verification

- Run the relevant syntax checks and tests after making changes.
- For shell scripts, at minimum run `bash -n` on each modified script.

## Testing changes

- Always add an appropriate test for new functionality, or update the existing
  tests to account for changes in functionality.
