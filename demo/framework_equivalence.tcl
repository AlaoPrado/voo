#!/usr/bin/env tclsh

# Compare equivalent class behavior across TclOO, Itcl, and VOO.
# Itcl is optional; if unavailable, this script still checks TclOO vs VOO.

set here [file dirname [file normalize [info script]]]
source [file join $here .. voo.tcl]

proc cleanupVooClass {name} {
    if {[namespace exists ::$name]} {
        namespace delete ::$name
    }
}

proc setupTclOO {} {
    if {[info commands DemoTclOO] ne ""} {
        catch {DemoTclOO destroy}
    }

    oo::class create DemoTclOO {
        variable name count tags

        constructor {args} {
            set name "unknown"
            set count 0
            set tags [list]
            if {[llength $args] > 0} {
                my configure {*}$args
            }
        }

        method configure {args} {
            if {[llength $args] == 0} {
                return [list -name $name -count $count -tags $tags]
            }
            if {[expr {[llength $args] % 2}] != 0} {
                error "configure expects -option value pairs"
            }
            foreach {opt val} $args {
                switch -- $opt {
                    -name  { set name $val }
                    -count { set count $val }
                    -tags  { set tags $val }
                    default { error "unknown option '$opt'" }
                }
            }
            return
        }

        method cget {opt} {
            switch -- $opt {
                -name  { return $name }
                -count { return $count }
                -tags  { return $tags }
                default { error "unknown option '$opt'" }
            }
        }

        method inc {delta} {
            incr count $delta
            lappend tags "inc:$delta"
        }

        method snapshot {} {
            return [list name $name count $count tags $tags]
        }
    }
}

proc runTclOOScenario {} {
    set obj [DemoTclOO new -name alpha -count 1 -tags [list init]]
    set seenName [$obj cget -name]
    $obj configure -name beta -count 5
    $obj inc 2
    set snapshot [$obj snapshot]
    $obj destroy
    return [dict create seenName $seenName snapshot $snapshot]
}

proc setupItcl {} {
    if {[catch {package require Itcl}]} {
        return 0
    }

    catch {itcl::delete class DemoItcl}

    itcl::class DemoItcl {
        public variable name "unknown"
        public variable count 0
        public variable tags [list]

        constructor {args} {
            eval configure $args
        }

        method inc {delta} {
            incr count $delta
            lappend tags "inc:$delta"
        }

        method snapshot {} {
            return [list name $name count $count tags $tags]
        }
    }
    return 1
}

proc runItclScenario {} {
    set obj [DemoItcl #auto -name alpha -count 1 -tags [list init]]
    set seenName [$obj cget -name]
    $obj configure -name beta -count 5
    $obj inc 2
    set snapshot [$obj snapshot]
    itcl::delete object $obj
    return [dict create seenName $seenName snapshot $snapshot]
}

proc setupVOO {} {
    cleanupVooClass DemoVOO

    voo::class DemoVOO {
        public {
            string_t name "unknown"
            int_t count 0
            list_t tags [list]
        }

        method inc {delta} -update {count tags} {
            incr count $delta
            lappend tags "inc:$delta"
        }

        method snapshot {} {
            return [list name [get.name $this] count [get.count $this] tags [get.tags $this]]
        }
    }
}

proc runVOOScenario {} {
    set obj [DemoVOO::new.args -name alpha -count 1 -tags [list init]]
    set seenName [DemoVOO::get.name $obj]
    DemoVOO::set.name obj beta
    DemoVOO::set.count obj 5
    DemoVOO::inc obj 2
    set snapshot [DemoVOO::snapshot $obj]
    return [dict create seenName $seenName snapshot $snapshot]
}

setupTclOO
setupVOO
set hasItcl [setupItcl]

set results [dict create]
dict set results TclOO [runTclOOScenario]
dict set results VOO [runVOOScenario]
if {$hasItcl} {
    dict set results Itcl [runItclScenario]
}

puts "Framework snapshots:"
foreach framework {TclOO Itcl VOO} {
    if {[dict exists $results $framework]} {
        set r [dict get $results $framework]
        puts [format "- %-5s seenName=%s snapshot=%s" $framework [dict get $r seenName] [dict get $r snapshot]]
    } elseif {$framework eq "Itcl"} {
        puts "- Itcl  skipped (package Itcl not available)"
    }
}

set baseline [dict get $results VOO]
set mismatch 0
foreach framework {TclOO Itcl} {
    if {![dict exists $results $framework]} {
        continue
    }
    if {[dict get $results $framework] ne $baseline} {
        puts "Mismatch detected: $framework differs from VOO"
        set mismatch 1
    }
}

catch {DemoTclOO destroy}
if {$hasItcl} {
    catch {itcl::delete class DemoItcl}
}
cleanupVooClass DemoVOO

if {$mismatch} {
    exit 1
}
puts "PASS: equivalent behavior across available frameworks."
exit 0
