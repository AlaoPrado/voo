#!/usr/bin/env tclsh
#
# install.tcl - Install the VOO package into the current Tcl installation's lib/ directory.
#
# Usage:
#   tclsh scripts/install.tcl
#

set vooVersion "1.0.0"
set pkgDir "voo${vooVersion}"

# Determine the Tcl library directory
set libDir [info library]
set installDir [file join [file dirname $libDir] $pkgDir]

# Find the source files relative to this script
set scriptDir [file dirname [file normalize [info script]]]
set repoDir [file dirname $scriptDir]
set vooSrc [file join $repoDir voo.tcl]
set pkgSrc [file join $repoDir pkgIndex.tcl]

# Validate source files exist
foreach f [list $vooSrc $pkgSrc] {
    if {![file exists $f]} {
        puts stderr "Error: source file not found: $f"
        exit 1
    }
}

# Create the installation directory
if {[catch {file mkdir $installDir} err]} {
    puts stderr "Error: could not create directory '$installDir': $err"
    puts stderr "You may need to run this script with elevated privileges (e.g. sudo)."
    exit 1
}

# Copy files
foreach {src name} [list $vooSrc voo.tcl $pkgSrc pkgIndex.tcl] {
    set dst [file join $installDir $name]
    if {[catch {file copy -force $src $dst} err]} {
        puts stderr "Error: could not copy '$name' to '$installDir': $err"
        exit 1
    }
}

puts "VOO $vooVersion installed successfully to:"
puts "  $installDir"
puts ""
puts "You can now use it in Tcl with:"
puts "  package require voo $vooVersion"
