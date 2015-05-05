# gluonjs
Node module to integrate with an external non-javascript process.

This was written to be a way to use non-javascript languages to act as the controlling
logic for electron (formerly know as atom-shell). However, this does not have any dependencies on electron and can be used to interface with any non-javascript process.
This is inspired by https://github.com/hoytech/valence but uses a different mechanism.

It inverts the usage in order to make use of electrons packaging and crash reporting capabilities.

## TODO

  - [ ] Describe the library better
