# Migration Guide: TclOO and Itcl to VOO

This guide maps common TclOO and Itcl patterns to VOO equivalents.
It focuses on practical migration of class/object code, including cget/configure style APIs.

---

## Table of Contents

- [Migration Mindset](#migration-mindset)
- [Quick Reference Table](#quick-reference-table)
- [Feature Mapping Examples](#feature-mapping-examples)
  - [Class and Object Basics](#class-and-object-basics)
  - [cget and configure Migration](#cget-and-configure-migration)
  - [Inheritance and Overrides](#inheritance-and-overrides)
  - [By-Reference Updates](#by-reference-updates)
- [Checklist for Real Projects](#checklist-for-real-projects)
- [Try the Equivalence Demo](#try-the-equivalence-demo)

---

## Migration Mindset

VOO objects are plain Tcl lists, not command objects.

- TclOO/Itcl style: object command dispatch (`$obj method ...`)
- VOO style: namespace proc dispatch (`Class::method $obj ...`) and explicit field access via generated accessors (`get.field`, `set.field`, `update.field`)

Think of migration as replacing implicit object state with explicit data plus generated accessors.

---

## Quick Reference Table

| Concept | TclOO | Itcl | VOO Migration |
|---|---|---|---|
| Class declaration | `oo::class create Name { ... }` | `itcl::class Name { ... }` | `voo::class Name { ... }` |
| Object creation | `set o [Name new ...]` | `set o [Name #auto ...]` | `set o [Name::new ...]` or `Name::new.args -field value` |
| Method call | `$o method ...` | `$o method ...` | `Name::method $o ...` |
| Field declaration | `variable x` (manual init/access) | `public variable x ...` | `int_t x`, `string_t name`, etc. |
| Getter | custom method | `cget -x` (for options/public vars) | `Name::get.x $o` |
| Setter | custom method / custom configure | `configure -x v` | `Name::set.x o v` |
| cget migration | typically custom method | built-in `cget -opt` usage pattern | replace with `get.<field>` |
| configure migration | typically custom method | built-in `configure -opt val ...` usage pattern | replace with `set.<field>` calls (or `new.args` at construction) |
| Inheritance | `superclass Parent` | `inherit Parent` | `voo::class Child -extends Parent { ... }` |
| Override guard | implicit (method name match) | implicit | explicit `-override` on `method` |
| Virtual dispatch | standard OO dynamic dispatch | standard OO dynamic dispatch | explicit `-virtual` methods in `-virtual` class |
| Parent method call | `next` | `chain` | `Parent::base.method $this ...` |
| Static/class state | class vars / class methods | common vars / class methods | typed field with `-static`, access via `class.get.*`, `class.set.*` |
| Destructor/finalize | `destructor` support | `destructor` support | usually not needed for list-backed objects; move cleanup to explicit APIs if required |

Notes:
- TclOO does not provide universal built-in cget/configure semantics for all classes; many projects implement them manually.
- Itcl commonly uses cget/configure for option-style public variables.

---

## Feature Mapping Examples

### Class and Object Basics

```tcl
# TclOO
oo::class create PointOO {
    variable x y
    constructor {{x0 0.0} {y0 0.0}} {
        set x $x0
        set y $y0
    }
    method length {} {
        expr {sqrt($x*$x + $y*$y)}
    }
}
set p [PointOO new 3.0 4.0]
puts [$p length]
```

```tcl
# Itcl
package require Itcl
itcl::class PointItcl {
    public variable x 0.0
    public variable y 0.0
    constructor {args} {
        eval configure $args
    }
    method length {} {
        expr {sqrt($x*$x + $y*$y)}
    }
}
set p [PointItcl #auto -x 3.0 -y 4.0]
puts [$p length]
```

```tcl
# VOO
voo::class PointVOO {
    public {
        double_t x 0.0
        double_t y 0.0
    }
    method length {} {
        expr {sqrt([get.x $this]**2 + [get.y $this]**2)}
    }
}
set p [PointVOO::new 3.0 4.0]
puts [PointVOO::length $p]
```

### cget and configure Migration

Itcl style and many TclOO codebases use option-style APIs.
In VOO, map those to explicit accessors.

```tcl
# Itcl / option-style usage
set obj [Thing #auto -name alpha -count 1]
puts [$obj cget -name]
$obj configure -name beta -count 5
```

```tcl
# VOO equivalent
set obj [Thing::new.args -name alpha -count 1]
puts [Thing::get.name $obj]
Thing::set.name obj beta
Thing::set.count obj 5
```

For constructor-time options, prefer `new.args` over writing a custom parser unless required.

### Inheritance and Overrides

```tcl
# TclOO / Itcl idea
# Child overrides Parent::area and parent behavior can still be reused.
```

```tcl
# VOO
voo::class Shape -virtual {
    method area -virtual {} { return 0.0 }
}

voo::class Circle -extends Shape {
    public { double_t radius 1.0 }
    method area -override {} {
        expr {3.14159 * [get.radius $this] ** 2}
    }
}

voo::class ColoredCircle -extends Circle {
    method area -override {} {
        set parentArea [Circle::base.area $this]
        expr {$parentArea * 1.1}
    }
}
```

### By-Reference Updates

When mutating large/list/dict fields repeatedly, migrate to `-update`.

```tcl
# VOO
voo::class Acc {
    public { list_t items [list] }
    method add {value} -update {items} {
        lappend items $value
    }
}
```

For virtual methods, `-virtual` can be combined with `-upvar` and `-update`.
Parent calls via `Parent::base.method this ...` are supported.

---

## Checklist for Real Projects

1. Inventory classes and tag each method as read-only, simple write, or heavy mutation.
2. Migrate public state to typed VOO fields (`int_t`, `string_t`, `list_t`, `dict_t`, ...).
3. Replace `$obj cget -x` with `Class::get.x $obj`.
4. Replace `$obj configure -x v` with `Class::set.x obj v`.
5. Replace option-style constructors with `Class::new.args -x v ...` where possible.
6. For heavy list/dict changes, use `-update {field}` methods.
7. For polymorphism, mark root classes `-virtual`, and use `-override` in children.
8. Add/adjust regression tests before and after each class migration.

---

## Try the Equivalence Demo

A runnable demo is provided in [demo/framework_equivalence.tcl](demo/framework_equivalence.tcl).

It compares equivalent behavior across:
- TclOO
- Itcl (if available in the local Tcl installation)
- VOO

Run it with:

```sh
tclsh demo/framework_equivalence.tcl
```

If Itcl is not installed, the demo reports a skip for Itcl and still compares TclOO and VOO.
