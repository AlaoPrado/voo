# VOO — Vanilla Object Orientation for Tcl

**VOO** is a lightweight OO framework that composes classes from Tcl's
native data structures — lists and dictionaries — rather than introducing additional
framework infrastructure. VOO objects are plain Tcl lists with automatic memory management
through copy-on-write semantics, eliminating the destructor burden inherent in TclOO and
Itcl.

Benchmarks on Tcl 8.6.13 and Tcl 9.0 show VOO achieves **7–18× faster object creation**
and **4–6× superior memory efficiency** compared to TclOO. A companion C++ migration path
further improves field-access speed and memory usage while preserving an identical Tcl
call-site API.

---

## Table of Contents

- [Quickstart](#quickstart)
- [Quick Reference](#quick-reference)
- [Install](#install)
- [API](#api)
  - [voo::class](#vooclass)
  - [Field Types](#field-types)
  - [public / private](#public--private)
  - [constructor](#constructor)
  - [method](#method)
  - [importMethods](#importmethods)
  - [getter / setter / updater](#getter--setter--updater)
  - [Generated Accessors](#generated-accessors)
  - [Generated Constructors](#generated-constructors)
  - [class.defaultObj / class.fields](#classdefaultobj--classfields)
- [Benchmarks](#benchmarks)
- [Tests](#tests)
- [Migration](#migration)
- [Demos](#demos)
- [Documentation](#documentation)
- [License](#license)

---

## Quickstart

```tcl
source voo.tcl

voo::class Point {
    public {
        double_t x 0.0
        double_t y 0.0
    }

    method distance {} {
        set dx [get.x $this]
        set dy [get.y $this]
        return [expr {sqrt($dx*$dx + $dy*$dy)}]
    }
}

set p [Point::new 3.0 4.0]
puts [Point::get.x $p]       ;# 3.0
puts [Point::distance $p]    ;# 5.0

Point::set.x p 6.0
puts [Point::get.x $p]       ;# 6.0
```

---

## Quick Reference

### Class Declaration

```tcl
voo::class ClassName ?-virtual? ?-extends ParentClass? {
    public {
        type_t fieldName defaultValue
        type_t -static staticFieldName defaultValue
    }
    private {
        type_t fieldName defaultValue
    }
    method name {args} { body }
    constructor {args} { body }
    importMethods {parentMethod1 parentMethod2}
}
```

### Field Types

| Type        | Description     | Default | Example                          |
|-------------|-----------------|---------|----------------------------------|
| `double_t`  | Floating-point  | `0.0`   | `double_t x 0.0`                |
| `int_t`     | Integer         | `0`     | `int_t count 0`                 |
| `string_t`  | String          | `""`    | `string_t name ""`              |
| `bool_t`    | Boolean         | `0`     | `bool_t active 1`               |
| `list_t`    | List            | `{}`    | `list_t items [list]`           |
| `dict_t`    | Dictionary      | `{}`    | `dict_t data [dict create]`     |
| `obj_t`     | Any object      | `{}`    | `obj_t nested {}`               |

### Constructors (auto-generated)

```tcl
set obj [Class::new arg1 arg2 ...]        ;# Positional
set obj [Class::new()]                     ;# Default values
set obj [Class::new.args -field1 val ...]  ;# Named arguments
```

### Accessors (auto-generated per field)

```tcl
set val [Class::get.field $obj]                       ;# Getter
Class::set.field obj value                             ;# Setter
Class::update.field obj temp { modify $temp }          ;# Updater (COW-safe)

set val [Class::class.get.staticField]                 ;# Static getter
Class::class.set.staticField value                     ;# Static setter
```

### Method Modifiers

| Modifier              | Description                                        |
|-----------------------|----------------------------------------------------|
| *(none)*              | `$this` passed by value                            |
| `-static`             | No `this` argument                                 |
| `-upvar`              | `this` passed by reference                         |
| `-update {fields}`    | Named fields detached during body (COW-safe)       |
| `-override`           | Validates parent method exists                     |
| `-virtual`            | Enables polymorphic dispatch (supports `-upvar` and `-update`) |

### Inheritance

```tcl
voo::class Child -extends Parent {
    # Inherits parent fields and accessors
    method parentMethod -override {} { ... }
    importMethods {parentMethod1 parentMethod2}
}
```

### Virtual Polymorphism

```tcl
voo::class Shape -virtual {
    method area -virtual {} { return 0.0 }
}
voo::class Circle -extends Shape {
    public { double_t radius 1.0 }
    method area -override {} {
        return [expr {3.14159 * [get.radius $this] ** 2}]
    }
}
set s [Circle::new 5.0]
puts [Shape::area $s]   ;# dispatches to Circle::area -> 78.54
```

> **Note:** a `base.<name>` method is automatically created for virtual methods, so the original implementation can be called by child classes when overriding it.

### Visibility

Fields and methods in `private { }` blocks receive a `my.` prefix and are not exported.

---

## API

### `voo::class`

Declare a new VOO class.

```tcl
voo::class ClassName ?-virtual? ?-extends ParentClass? body
```

| Parameter   | Description                                                  |
|-------------|--------------------------------------------------------------|
| `ClassName` | Name of the class (becomes a Tcl namespace)                  |
| `-virtual`  | Enable virtual polymorphic dispatch for this class           |
| `-extends`  | Inherit from `ParentClass` (single inheritance only)         |
| `body`      | Class body containing field declarations, methods, etc.      |

```tcl
# Basic class
voo::class Person {
    public {
        string_t name "unknown"
        int_t age 0
    }
    method greet {} {
        return "Hello, I'm [get.name $this]"
    }
}

# Virtual root class
voo::class Shape -virtual {
    method area -virtual {} { return 0.0 }
}

# Inheriting class
voo::class Circle -extends Shape {
    public { double_t radius 1.0 }
    method area -override {} {
        return [expr {3.14159 * [get.radius $this] ** 2}]
    }
}
```

---

### Field Types

Declare typed fields inside a class body. Each creates a field with a default value and
auto-generates accessors.

```tcl
double_t  ?-static? name ?initialValue?
int_t     ?-static? name ?initialValue?
string_t  ?-static? name ?initialValue?
bool_t    ?-static? name ?initialValue?
list_t    ?-static? name ?initialValue?
dict_t    ?-static? name ?initialValue?
obj_t     ?-static? name ?initialValue?
```

| Parameter      | Description                                           |
|----------------|-------------------------------------------------------|
| `-static`      | Store as class-level variable instead of instance field|
| `name`         | Field name                                            |
| `initialValue` | Optional initial value (type default if omitted)      |

```tcl
voo::class Config {
    public {
        # Non-static fields
        string_t  host "localhost"
        int_t     port 8080
        bool_t    verbose 0
        list_t    tags [list]
        dict_t    metadata [dict create]
        obj_t     nested {}

        # Static field
        int_t     -static instanceCount 0
    }

    private {
        # Private field => my.get.secret, my.set.secret, my.update.secret
        string_t secret "token"
    }
}
```

---

### `public` / `private`

Control visibility of field and method declarations.

```tcl
public { body }
private { body }
```

Fields and methods declared inside `private` receive a `my.` prefix and are not namespace-exported. Fields and methods inside `public` (the default) are exported normally.

```tcl
voo::class Account {
    # default mode is public
    string_t id ""

    public {
        string_t owner ""
        method ownerLabel {} {
            return "Owner: [get.owner $this]"
        }
    }

    private {
        double_t balance 0.0
        method rawBalance {} {
            return [my.get.balance $this]
        }
    }
}

set a [Account::new "A-1" "Alice" 0.0]
puts [Account::get.owner $a]           ;# public accessor
puts [Account::ownerLabel $a]          ;# public method
puts [Account::my.rawBalance $a]       ;# private method name has my. prefix
# Account::get.owner   - accessible
# Account::my.get.balance - not exported
```

---

### `constructor`

Define a custom constructor for the class. If no constructors are declared, VOO
auto-generates `new` (positional), `new()` (no-args), and `new.args` (named).

```tcl
constructor ?options? ?argList body?
```

| Option           | Description                                          |
|------------------|------------------------------------------------------|
| `-name ctorName` | Use a custom constructor name                        |
| `-noargs body`   | No-argument constructor with the given body          |
| `-typed types`   | Constructor named `new(type1,type2,...)`              |

```tcl
# All constructor scenarios for the same class
voo::class Color {
    public {
        int_t r 0
        int_t g 0
        int_t b 0
    }

    # 1) Explicit positional constructor (same role as auto new)
    constructor {r g b} {
        return [list $r $g $b]
    }

    # 2) Explicit no-args constructor (same role as auto new())
    constructor -noargs {
        variable __defaultObj
        return $__defaultObj
    }

    # 3) Explicit named constructor (same role as auto new.args)
    constructor -name new.args {args} {
        variable __defaultObj
        set obj $__defaultObj
        dict for {key value} $args {
            set field [string range $key 1 end]
            set setter set.$field
            if {[info commands $setter] ne ""} {
                $setter obj $value
            } else {
                error "Unknown field option: $field"
            }
        }
        return $obj
    }

    # 4) Custom named constructor
    constructor -name fromHex {hex} {
        set hex [string trimleft $hex "#"]
        scan [string range $hex 0 1] %x r
        scan [string range $hex 2 3] %x g
        scan [string range $hex 4 5] %x b
        return [list $r $g $b]
    }

    # 5) Typed constructor name
    constructor -typed {int int int} {r g b} {
        return [list $r $g $b]
    }
}

set c1 [Color::new 255 128 0]
set c2 [Color::new()]
set c3 [Color::new.args -r 255 -g 128 -b 0]
set c4 [Color::fromHex "#FF8000"]
set c5 [Color::new(int,int,int) 10 20 30]
```

> **Note:** Prefer using positional or default constructor for performance.

---

### `method`

Declare a method in the class.

```tcl
method name ?-virtual? argList ?-static? ?-upvar? ?-update {fields}? ?-override? body
```

| Parameter          | Description                                                     |
|--------------------|-----------------------------------------------------------------|
| `name`             | Method name                                                     |
| `argList`          | Tcl argument list                                               |
| `body`             | Method body                                                     |
| `-static`          | No `this` argument                                              |
| `-upvar`           | `this` passed by reference (variable name)                      |
| `-update {fields}` | Fields detached into locals during body (implies `-upvar`)      |
| `-override`        | Validates that the method exists in parent class                |
| `-virtual`         | Enable polymorphic dispatch (class must be `-virtual`)          |

```tcl
# Mixed method option scenarios
voo::class Vec2 {
    public {
        double_t x 0.0
        double_t y 0.0
        list_t tags [list]
    }

    # By value (default)
    method length {} {
        return [expr {sqrt([get.x $this]**2 + [get.y $this]**2)}]
    }

    # By reference
    method scale {factor} -upvar {
        set.x this [expr {[get.x $this] * $factor}]
        set.y this [expr {[get.y $this] * $factor}]
    }

    # With update (COW-safe field detach)
    method appendTag {tag} -update {tags} {
        lappend tags $tag
    }

    # Static
    method origin {} -static {
        return [new 0.0 0.0]
    }
}

set v [Vec2::new 3.0 4.0 [list]]
puts [Vec2::length $v]
Vec2::scale v 2.0
Vec2::appendTag v "scaled"
set o [Vec2::origin]

# Virtual + override + parent original body via base.<name>
voo::class Shape -virtual {
    method area -virtual {} { return 0.0 }
}

voo::class Circle -extends Shape {
    public { double_t radius 1.0 }
    method area -override {} {
        return [expr {3.14159 * [get.radius $this] ** 2}]
    }
}

voo::class ColoredCircle -extends Circle {
    public { string_t color "red" }
    method area -override {} {
        # Calls Circle's original implementation body directly
        set parentArea [Circle::base.area $this]
        return [expr {$parentArea * 1.1}]
    }
}

set s [ColoredCircle::new 5.0 "blue"]
puts [Shape::area $s]   ;# dynamic dispatch => ColoredCircle::area

# Virtual + upvar (by-reference dispatch)
voo::class CounterRoot -virtual {
    public { int_t n 0 }
    method bump {delta} -virtual -upvar {
        set.n this [expr {[get.n $this] + $delta}]
    }
}

voo::class CounterChild -extends CounterRoot {
    method bump {delta} -override -upvar {
        set.n this [expr {[get.n $this] + ($delta * 2)}]
    }
}

set c0 [CounterRoot::new 10]
CounterRoot::bump c0 3
puts [CounterRoot::get.n $c0] ;# 13

set c1 [CounterChild::new 10]
CounterRoot::bump c1 3
puts [CounterChild::get.n $c1] ;# 16 (virtual dispatch to child by reference)

# Virtual + update (COW-safe dispatch)
voo::class BufferRoot -virtual {
    public {
        int_t writes 0
        list_t entries [list]
    }
    method appendEntry {value} -virtual -update {writes entries} {
        incr writes
        lappend entries "root:$value"
    }
}

voo::class BufferChild -extends BufferRoot {
    method appendEntry {value} -override -update {writes entries} {
        BufferRoot::base.appendEntry this $value
        incr writes 2
        lappend entries "child:$value"
    }
}

set b0 [BufferRoot::new 0 [list]]
BufferRoot::appendEntry b0 one
puts [BufferRoot::get.writes $b0]   ;# 1
puts [BufferRoot::get.entries $b0]  ;# root:one

set b1 [BufferChild::new 0 [list]]
BufferRoot::appendEntry b1 one
puts [BufferChild::get.writes $b1]  ;# 3
puts [BufferChild::get.entries $b1] ;# root:one child:one
```

> **Note:** Virtual dispatch uses `tailcall` internally, so methods declared with `-upvar` or `-update` execute in the original caller frame while preserving by-reference behavior. This also allows `Parent::base.<name> this ...` calls inside `-update` overrides.

---

### `importMethods`

Import methods from the parent class into the current child class.

```tcl
importMethods {method1 method2 ...}
```

| Parameter | Description                                       |
|-----------|---------------------------------------------------|
| `methods` | List of method names to import from parent class  |

Must be called inside a class declared with `-extends`.

```tcl
voo::class Base {
    method hello {} { return "hello" }
    method world {} { return "world" }
    method ping {} { return "ping" }
}

# Import a list of methods
voo::class ChildList -extends Base {
    importMethods {hello world}
}

# Import a single method name
voo::class ChildSingle -extends Base {
    importMethods ping
}

set c1 [ChildList::new]
puts [ChildList::hello $c1]

set c2 [ChildSingle::new]
puts [ChildSingle::ping $c2]
```

---

### `getter` / `setter` / `updater`

Manually generate accessor procedures for a field. These are normally auto-generated
by field declarations but can be called explicitly.

```tcl
getter methodName fieldName
setter methodName fieldName
updater methodName fieldName
```

| Parameter    | Description                                      |
|--------------|--------------------------------------------------|
| `methodName` | Name of the generated procedure                  |
| `fieldName`  | Name of the field to access                      |

```tcl
voo::class Item {
    public {
        string_t label ""
        list_t tags [list]
    }

    # Custom names
    getter getLabel label
    setter setLabel label
    updater updateTags tags
}

set it [Item::new "pen" [list blue office]]
puts [Item::getLabel $it]
Item::setLabel it "marker"
Item::updateTags it tmp {
    lappend tmp stationery
}
# After updater returns, tmp is reset to {}.
puts $tmp   ;# {}
puts [Item::getLabel $it]
```

> **Note:** The tmp variable is reset to {} to avoid accidental copy-on-write operations.

---

### Generated Accessors

For each instance field `fieldName`, VOO generates:

| Accessor                                         | Signature                                     | Description                            |
|--------------------------------------------------|-----------------------------------------------|----------------------------------------|
| `Class::get.fieldName`                           | `{this}`                                      | Return field value                     |
| `Class::set.fieldName`                           | `{thisVar value}`                             | Set field in-place                     |
| `Class::update.fieldName`                        | `{thisVar tempVar body}`                      | Detach field for COW-safe update       |

For static fields:

| Accessor                                         | Signature                                     | Description                            |
|--------------------------------------------------|-----------------------------------------------|----------------------------------------|
| `Class::class.get.fieldName`                     | `{}`                                          | Return static field value              |
| `Class::class.set.fieldName`                     | `{value}`                                     | Set static field value                 |
| `Class::class.update.fieldName`                  | `{tempVar body}`                              | Update static field with COW safety    |

Private fields use the `my.` prefix (e.g. `Class::my.get.fieldName`).

```tcl
voo::class Point {
    public {
        double_t x 0.0
        double_t y 0.0
        int_t -static count 0
    }
    private {
        string_t note "n/a"
    }
}

# Note: When private fields exist, positional new also includes them if constructor isn't manually defined
set p [Point::new 1.0 2.0 "n/a"]

# One could use named args to set only selected public fields.
set p [Point::new.args -x 1.0 -y 2.0]

# Instance public accessors
puts [Point::get.x $p]
Point::set.x p 5.0
Point::update.x p tmp { set tmp [expr {$tmp * 2}] }

# Static public accessors
puts [Point::class.get.count]
Point::class.set.count 10
Point::class.update.count tmp { incr tmp }

# Instance private accessor naming
puts [Point::my.get.note $p]
```

---

### Generated Constructors

Unless overridden, VOO generates three constructors per class:

| Constructor                                      | Description                                    |
|--------------------------------------------------|------------------------------------------------|
| `Class::new arg1 arg2 ...`                       | Positional — one argument per field            |
| `Class::new()`                                   | No-args — returns the default object           |
| `Class::new.args -field1 val -field2 val ...`    | Named — set fields by name with `-` prefix     |

```tcl
voo::class Person {
    public {
        string_t name "unknown"
        int_t age 0
    }
}

# Positional
set p1 [Person::new "Alice" 30]

# No-args (defaults)
set p2 [Person::new()]

# Named args
set p3 [Person::new.args -name "Bob" -age 25]

# Named args can set partial fields
set p4 [Person::new.args -name "Carol"]
```

---

### `class.defaultObj` / `class.fields`

Introspection procedures auto-generated for every class.

| Procedure            | Returns                                           |
|----------------------|---------------------------------------------------|
| `Class::class.defaultObj` | The default object (list of default values)  |
| `Class::class.fields`    | List of field names in declaration order      |

```tcl
voo::class Point {
    public {
        double_t x 0.0
        double_t y 0.0
    }
}

set defaults [Point::class.defaultObj]
set fields [Point::class.fields]

puts $defaults   ;# 0.0 0.0
puts $fields     ;# x y

# Works with inherited classes as well
voo::class ColorPoint -extends Point {
    public { string_t color "red" }
}
puts [ColorPoint::class.fields]       ;# x y color
puts [ColorPoint::class.defaultObj]   ;# 0.0 0.0 red
```

---

## Install

### Using the Install Script

Run the provided install script to copy VOO into your Tcl installation's `lib/` directory:

```sh
tclsh scripts/install.tcl
```

> **Note:** You may need elevated privileges (e.g. `sudo`) if the Tcl `lib/` directory
> is not writable by your user.

### Manual Installation

1. Locate your Tcl installation's `lib/` directory (e.g. `/usr/lib/tcl8.6/..` or the
   parent of `[info library]`).
2. Create a `voo1.0.0` folder inside that `lib/` directory.
3. Copy `voo.tcl` and `pkgIndex.tcl` into the new folder:

```sh
mkdir -p /usr/lib/tcl8.6/../voo1.0.0
cp voo.tcl pkgIndex.tcl /usr/lib/tcl8.6/../voo1.0.0/
```

### Usage After Installation

```tcl
package require voo 1.0.0
```

---

## Benchmarks

VOO achieves significant performance and memory advantages compared to TclOO and Itcl.
All benchmarks ran on a Dual-Core Intel Xeon Gold 6240 CPU under Tcl 8.6.13 and Tcl 9.0,
testing a `Point` class with 5 fields. Memory benchmarks instantiate 100,000 objects;
time benchmarks use Tcl's `time` command with 1,000 iterations.

### Object Creation Performance

**Tcl 8.6.13**

| Framework | Explicit (μs) | Default (μs) | Relative to VOO |
|-----------|--------------|--------------|------------------|
| VOO       | 0.414        | 0.397        | 1.00× (baseline) |
| VOO C++   | 0.565        | 0.334        | 1.36× slower / 1.19× faster |
| TclOO     | 3.536        | 2.972        | **8.5× / 7.5× slower** |
| Itcl      | 26.222       | 25.734       | **63× / 65× slower** |

**Tcl 9.0**

| Framework | Explicit (μs) | Default (μs) | Relative to VOO |
|-----------|--------------|--------------|------------------|
| VOO       | 0.525        | 0.550        | 1.00× (baseline) |
| VOO C++   | 0.576        | 0.458        | 1.10× slower / 1.20× faster |
| TclOO     | 9.246        | 3.829        | **17.6× / 7.0× slower** |
| Itcl      | 27.808       | 27.444       | **53× / 50× slower** |

VOO achieves direct list allocation with minimal overhead. TclOO's explicit constructor
overhead increased dramatically in Tcl 9.0 (+161%).

### Field Access Performance

**Tcl 8.6.13**

| Operation | VOO (μs) | VOO C++ (μs) | TclOO (μs) | Itcl (μs) |
|-----------|----------|-------------|-----------|----------|
| Getter    | 0.393    | 0.298       | 0.502     | 1.153    |
| Setter    | 0.799    | 0.306       | 0.563     | 1.169    |

**Tcl 9.0**

| Operation | VOO (μs) | VOO C++ (μs) | TclOO (μs) | Itcl (μs) |
|-----------|----------|-------------|-----------|----------|
| Getter    | 0.366    | 0.286       | 0.615     | 1.291    |
| Setter    | 0.823    | 0.365       | 0.613     | 1.102    |

VOO C++ delivers the fastest getters (~1.3× faster than VOO Tcl) and setters
(2.3–2.6× faster) across all frameworks. VOO delivers good results for getters and setters.

### Real-World Scenario: 100,000 Objects

**Tcl 8.6.13**

| Framework | Time   | Memory | Bytes/Obj | vs. VOO (Time) | vs. VOO (Mem) |
|-----------|--------|--------|-----------|----------------|---------------|
| VOO       | 147 ms | 58 MB  | ~580      | 1.00×          | 1.00×         |
| VOO C++   | 149 ms | 38 MB  | ~380      | 1.01× slower   | **1.53× lighter** |
| TclOO     | 466 ms | 257 MB | ~2,570    | **3.2× slower**    | **4.4× heavier**  |
| Itcl      | 2,781 ms | 882 MB | ~8,820   | **18.9× slower**   | **15.2× heavier** |

**Tcl 9.0**

| Framework | Time   | Memory | Bytes/Obj | vs. VOO (Time) | vs. VOO (Mem) |
|-----------|--------|--------|-----------|----------------|---------------|
| VOO       | 170 ms | 66.5 MB | ~665     | 1.00×          | 1.00×         |
| VOO C++   | 169 ms | 40.3 MB | ~403     | 1.01× faster   | **1.65× lighter** |
| TclOO     | 577 ms | 395 MB | ~3,950    | **3.4× slower**    | **5.9× heavier**  |
| Itcl      | 3,014 ms | 1,118 MB | ~11,180  | **17.7× slower**   | **16.8× heavier** |

VOO and VOO C++ are virtually identical in wall-clock time (~147–170 ms), while TclOO
takes 3.2–3.4× longer and Itcl is 18–19× slower. For million-object applications, VOO
projects ~665 MB versus TclOO's ~3.95 GB on Tcl 9.0.

### Cross-Version Stability

**Performance Change (Tcl 8.6.13 → 9.0)**

| Operation | VOO | VOO C++ | TclOO | Itcl |
|-----------|-----|---------|-------|------|
| Creation (Explicit) | +26.8% | +1.9% | **+161.5%** | +6.1% |
| Creation (Default)  | +38.5% | +37.1% | +28.8% | +6.6% |
| Getter              | -6.9%  | -4.0%  | +22.5% | +12.0% |
| Setter              | +3.0%  | +19.3% | +8.9%  | -5.7%  |

**Memory Change (Tcl 8.6.13 → 9.0)**

| Framework | Memory (8.6) | Memory (9.0) | Change |
|-----------|--------------|--------------|--------|
| VOO       | 58 MB        | 66.5 MB      | +14.7% |
| VOO C++   | 38 MB        | 40.3 MB      | **+6.1%** |
| TclOO     | 257 MB       | 395 MB       | +53.7% |
| Itcl      | 882 MB       | 1,118 MB     | +26.8% |

VOO C++ is virtually immune to interpreter changes, making it the most stable framework
across versions. TclOO's 161.5% explicit-construction regression and 53.7% memory increase
in Tcl 9.0 are the largest among all frameworks.

---

## Tests

Automated API behavior tests are available in the `test/` folder.

To run the full test suite:

```sh
tclsh test/test.tcl
```

The script validates expected behavior for constructors, methods, inheritance,
virtual dispatch, accessors, and error scenarios documented in this README.

---

## Migration

Migration guidelines for TclOO and Itcl users are documented in [MIGRATION.md](MIGRATION.md).

It includes:
- A quick reference mapping table (TclOO/Itcl to VOO)
- Code examples for class, inheritance, and method migration
- cget/configure migration patterns to `get.*`, `set.*`, and `new.args`

---

## Demos

Framework equivalence examples are available in [demo/](demo/).

Run the cross-framework demo:

```sh
tclsh demo/framework_equivalence.tcl
```

---

## Documentation

Project documentation is available in the `docs/` folder.

In `docs/arxiv`, you can find the LaTeX source files (`.tex`) used for the
arXiv white paper publication.

White paper link: https://arxiv.org/abs/2604.10399

---

## License

MIT License — see [LICENSE.md](LICENSE.md) for details.
