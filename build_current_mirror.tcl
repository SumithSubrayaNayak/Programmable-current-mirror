# =====================================================================
# build_current_mirror.tcl
# 3-leg binary-weighted programmable current mirror, sky130A, Magic VLSI
#
# Schematic (all NMOS sky130_fd_pr__nfet_01v8, W=1um, L=0.15um, nf=1):
#   M1  reference, diode connected (gate = drain = vbias), M=1
#   M2/M3/M4  mirror units, gate = vbias, source = gnd, M = 1 / 2 / 4
#   M5/M6/M7  enable switches, gate = en1/en2/en3, between the mirror
#             drain and iout, M = 1 each
#
# How to run (inside TKcon, started with:  magic -T sky130A ):
#   1. cd to an EMPTY folder
#   2. source build_current_mirror.tcl
# The script paints the layout, saves current_mirror.mag, reloads it,
# runs full DRC, extracts, and writes current_mirror.spice for LVS.
# Tested with W = 1.0 and the gaps below.
# =====================================================================

# ---------- parameters (um) ----------
set W      1.0    ;# diffusion width of every unit
set gapleg 1.2    ;# gap between legs (room for the en pads)
set gapcol 0.4    ;# gap between columns inside one leg

# ---------- helpers ----------
proc R {layer x1 y1 x2 y2} {
    box values ${x1}um ${y1}um ${x2}um ${y2}um
    paint $layer
}
set portnum 0
proc lab {name x y layer} {
    global portnum
    box values ${x}um ${y}um ${x}um ${y}um
    label $name c $layer
    select area labels
    incr portnum
    port make $portnum
    select clear
}

load current_mirror
snap internal

# ---------- vertical stack of one column (y, um) ----------
#   0.00 - 0.29   source contact strip (to gnd)
#   0.29 - 0.44   mirror gate  (poly row, vbias)
#   0.44 - 0.73   middle node contact strip
#   0.73 - 0.88   switch gate  (poly, enN)
#   0.88 - 1.17   drain contact strip (to iout)
# A column without a switch ends at y = 0.73.
proc column {x0 sw} {
    global W
    if {$sw} {set ytop 1.17} else {set ytop 0.73}
    R ndiffusion $x0 0 [expr {$x0+$W}] $ytop
    R ndcontact  [expr {$x0+0.06}] 0.06 [expr {$x0+$W-0.06}] 0.23
    R ndcontact  [expr {$x0+0.06}] 0.50 [expr {$x0+$W-0.06}] 0.67
    R viali      [expr {$x0+0.06}] 0.06 [expr {$x0+$W-0.06}] 0.23
    if {$sw} {
        R ndcontact [expr {$x0+0.06}] 0.94 [expr {$x0+$W-0.06}] 1.11
        R locali    [expr {$x0-0.1}]  0.94 [expr {$x0+$W+0.1}]  1.11
        R viali     [expr {$x0+0.06}] 0.94 [expr {$x0+$W-0.06}] 1.11
        R metal1    $x0 0.88 [expr {$x0+$W}] 1.55
    }
}

# ---------- column positions (x, um) ----------
set xR   0.0                              ;# M1  (reference)
set x1   [expr {$xR+$W+$gapleg}]          ;# M2 + M5  (1x leg)
set x2a  [expr {$x1+$W+$gapleg}]          ;# M3 unit a + M6 (2x leg)
set x2b  [expr {$x2a+$W+$gapcol}]         ;# M3 unit b
set x4a  [expr {$x2b+$W+$gapleg}]         ;# M4 unit a + M7 (4x leg)
set x4b  [expr {$x4a+$W+$gapcol}]
set x4c  [expr {$x4b+$W+$gapcol}]
set x4d  [expr {$x4c+$W+$gapcol}]
set xend [expr {$x4d+$W}]

column $xR  0
column $x1  1
column $x2a 1
column $x2b 0
column $x4a 1
column $x4b 0
column $x4c 0
column $x4d 0

# ---------- mirror poly row: one strip, all mirror gates = vbias ----------
set padx [expr {$xR-0.75}]
R polysilicon [expr {$padx-0.165}] 0.29 [expr {$xend+0.3}] 0.44
R polysilicon [expr {$padx-0.165}] 0.20 [expr {$padx+0.165}] 0.53
R pcontact    [expr {$padx-0.085}] 0.28 [expr {$padx+0.085}] 0.45
R locali      [expr {$padx-0.165}] 0.20 [expr {$padx+0.165}] 0.53
# diode connection: M1 drain (middle contact) -> gate pad
R locali      [expr {$padx-0.165}] 0.50 [expr {$xR+$W+0.1}] 0.67
R viali       [expr {$padx-0.085}] 0.50 [expr {$padx+0.085}] 0.67
R metal1      [expr {$padx-0.15}]  0.43 [expr {$padx+0.15}]  0.74
lab vbias $padx 0.46 metal1

# ---------- mid-node straps: join the mirror units of one leg ----------
R locali [expr {$x1-0.1}]  0.50 [expr {$x1+$W+0.1}]  0.67
R locali [expr {$x2a-0.1}] 0.50 [expr {$x2b+$W+0.1}] 0.67
R locali [expr {$x4a-0.1}] 0.50 [expr {$x4d+$W+0.1}] 0.67

# ---------- enable switch gates + pads ----------
proc enable {xA name} {
    global W
    set px [expr {$xA-0.55}]
    R polysilicon [expr {$px-0.165}] 0.73 [expr {$xA+$W+0.15}] 0.88
    R polysilicon [expr {$px-0.165}] 0.65 [expr {$px+0.165}] 0.98
    R pcontact    [expr {$px-0.085}] 0.735 [expr {$px+0.085}] 0.905
    R locali      [expr {$px-0.165}] 0.65 [expr {$px+0.165}] 0.98
    R viali       [expr {$px-0.085}] 0.735 [expr {$px+0.085}] 0.905
    R metal1      [expr {$px-0.15}]  0.67 [expr {$px+0.15}]  0.97
    lab $name $px 0.69 metal1
}
enable $x1  en1
enable $x2a en2
enable $x4a en3

# ---------- gnd: source li strip, p-tap row, met1 bar ----------
R locali [expr {$xR-0.1}] 0.06 [expr {$xend+0.1}] 0.23
R psubstratepdiff    [expr {$xR-0.2}]  -0.70 [expr {$xend+0.2}]  -0.29
R psubstratepcontact [expr {$xR-0.04}] -0.58 [expr {$xend+0.04}] -0.41
R locali [expr {$xR-0.14}] -0.58 [expr {$xend+0.14}] -0.41
R viali  [expr {$xR-0.04}] -0.58 [expr {$xend+0.04}] -0.41
R metal1 [expr {$xR-0.2}]  -0.64 [expr {$xend+0.2}]  0.29
lab gnd [expr {$xR+0.5}] -0.2 metal1

# ---------- iout bar (joins the three switch drains) ----------
R metal1 [expr {$x1+0.1}] 1.25 [expr {$x4a+$W-0.1}] 1.55
lab iout [expr {$x2a+0.5}] 1.4 metal1

# ---------- save, reload from disk, full DRC ----------
save current_mirror
flush current_mirror
drc style drc(full)
drc check
drc catchup
select top cell
set errs [drc listall why]
if {[string length $errs] == 0} {
    puts "RESULT: DRC = 0"
} else {
    puts "RESULT: DRC ERRORS -> $errs"
}

# ---------- extract for LVS ----------
extract all
ext2spice lvs
ext2spice -o current_mirror.spice
puts "RESULT: wrote current_mirror.spice  (next: sh run_lvs.sh)"
