# Demo: Framework Equivalence

This folder contains a small migration validation demo.

- Script: [framework_equivalence.tcl](framework_equivalence.tcl)
- Goal: run equivalent behavior for TclOO, Itcl, and VOO, then compare outputs.

## Run

```sh
tclsh demo/framework_equivalence.tcl
```

If Itcl is not installed in your Tcl environment, the script reports a skip for Itcl and still checks TclOO vs VOO.
