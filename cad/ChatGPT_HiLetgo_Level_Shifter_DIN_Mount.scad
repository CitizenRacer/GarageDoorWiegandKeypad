// ChatGPT HiLetgo 4-channel BSS138 level-shifter DIN rail mount
// Design version: 1
// VERSIONING RULE: Increment design_version by 1 for every repository check-in of this file.
// Standard 35 mm x 7.5 mm top-hat DIN rail
// Designed for the common tiny 4-channel BSS138 board sold by HiLetgo.
// IMPORTANT: HiLetgo does not publish the PCB dimensions on the Amazon listing.
// Measure your actual board and adjust pcb_x / pcb_y if needed before final printing.

$fn = 48;

// ---------- VERSION ----------
design_version = 1;  // Increment by 1 on every repository check-in

// ---------- PCB PARAMETERS ----------
// Default envelope for the common 4-channel BSS138 breakout.
pcb_x = 13.5;          // PCB width, mm (across the two pin rows)
pcb_y = 16.2;          // PCB length, mm (along each 6-pin row)
pcb_t = 1.6;           // PCB thickness
pcb_clearance = 0.35;  // per side; increase to 0.45-0.55 for a looser fit

// ---------- DIN RAIL PARAMETERS ----------
din_width = 35.0;
din_height = 7.5;
din_clearance = 0.35;
rail_thickness_allowance = 1.4;

// ---------- PRINT / STRUCTURE PARAMETERS ----------
mount_depth = 24;      // length along DIN rail
base_width = 43;       // overall width across DIN rail
base_t = 3.0;
wall_t = 2.2;
flex_t = 2.2;
hook_drop = 6.0;
hook_lip = 1.45;
hook_lip_h = 1.45;

// PCB stand-off / clip geometry
pcb_standoff = 2.4;
pad = 3.0;
clip_t = 1.6;
clip_h_above_pcb = 1.6;
clip_lip = 0.75;
clip_lip_h = 0.8;
side_guide_t = 1.2;
side_guide_len = 4.0;

// Coordinate system:
// X = across DIN rail
// Y = along DIN rail
// Z = outward from rail / upward toward PCB
eps = 0.15;
rail_top_z = hook_drop;
base_z0 = rail_top_z;
base_z1 = base_z0 + base_t;
pcb_bottom_z = base_z1 + pcb_standoff;
pcb_top_z = pcb_bottom_z + pcb_t;

module rounded_box(size=[10,10,2], r=1) {
    // simple XY-rounded prism
    linear_extrude(height=size[2], center=true)
        offset(r=r)
            offset(delta=-r)
                square([size[0], size[1]], center=true);
}

module wedge_lip(x_sign=1, y_depth=mount_depth-4) {
    // Chamfered inward lip for DIN rail insertion.
    // x_sign = -1 left, +1 right.
    lip_outer_x = x_sign * (din_width/2 + din_clearance + wall_t/2);
    lip_inner_x = x_sign * (din_width/2 - hook_lip);
    z0 = 0.35;
    z1 = z0 + hook_lip_h;
    z2 = z1 + 1.0;

    // 2D polygon in X-Z, extruded in Y.
    pts_right = [
        [din_width/2 + din_clearance + wall_t, z0],
        [din_width/2 - hook_lip, z0],
        [din_width/2 - hook_lip, z1],
        [din_width/2 + din_clearance + wall_t, z2]
    ];
    pts_left = [for (p=pts_right) [-p[0], p[1]]];
    pts = (x_sign > 0) ? pts_right : pts_left;

    rotate([90,0,0])
        linear_extrude(height=y_depth, center=true)
            polygon(points=pts);
}

module din_clip() {
    // Top/base plate that bears on the DIN rail.
    translate([0,0,base_z0 + base_t/2])
        rounded_box([base_width, mount_depth, base_t], 1.1);

    // Fixed hook, left side.
    left_x = -(din_width/2 + din_clearance + wall_t/2);
    translate([left_x, 0, (hook_drop+eps)/2])
        cube([wall_t, mount_depth-4, hook_drop+eps], center=true);
    wedge_lip(-1, mount_depth-4);

    // Flexible snap arm, right side. Narrower Y span makes it easier to flex.
    right_x = din_width/2 + din_clearance + flex_t/2;
    flex_depth = mount_depth - 8;
    translate([right_x, 0, (hook_drop+eps)/2])
        cube([flex_t, flex_depth, hook_drop+eps], center=true);
    wedge_lip(1, flex_depth);

    // Small thumb tab on flexible side for removal with a screwdriver/finger.
    translate([din_width/2 + din_clearance + flex_t + 1.8, 0, 2.6])
        cube([3.6, 7.0, 1.8], center=true);
}

module pcb_supports() {
    ex = pcb_x/2 + pcb_clearance;
    ey = pcb_y/2 + pcb_clearance;

    // Four corner pads. They leave the pin rows / solder tails mostly unobstructed.
    for (sx=[-1,1], sy=[-1,1]) {
        translate([
            sx*(ex - pad/2),
            sy*(ey - pad/2),
            base_z1 + (pcb_standoff+eps)/2 - eps
        ])
            cube([pad, pad, pcb_standoff+eps], center=true);
    }

    // Tiny side guides keep the PCB centered without blocking the pin rows.
    for (sx=[-1,1]) {
        guide_h = pcb_standoff + 1.6 + eps;
        translate([
            sx*(ex + side_guide_t/2),
            0,
            base_z1 + guide_h/2 - eps
        ])
            cube([side_guide_t, side_guide_len, guide_h], center=true);
    }
}

module pcb_end_clip(y_sign=1) {
    ex = pcb_x/2 + pcb_clearance;
    ey = pcb_y/2 + pcb_clearance;

    // Flexible end wall: PCB goes under one lip, then snaps under the other.
    y_wall = y_sign * (ey + clip_t/2);
    wall_h = pcb_standoff + pcb_t + clip_h_above_pcb;
    translate([0, y_wall, base_z1 + wall_h/2 - eps/2])
        cube([pcb_x + 2*pcb_clearance + 3.0, clip_t, wall_h+eps], center=true);

    // Inward retaining lip at the top.
    lip_y = y_sign * (ey - clip_lip/2);
    translate([0, lip_y, pcb_top_z + clip_lip_h/2])
        cube([pcb_x + 2*pcb_clearance + 2.4, clip_lip, clip_lip_h], center=true);

    // Lead-in chamfer / ramp above the lip to make insertion easier.
    ramp_depth = 1.4;
    ramp_h = 1.1;
    hull() {
        translate([0,
                   y_sign*(ey + 0.05),
                   pcb_top_z + clip_lip_h])
            cube([pcb_x + 2*pcb_clearance + 2.4, 0.25, 0.25], center=true);
        translate([0,
                   y_sign*(ey + ramp_depth),
                   pcb_top_z + clip_lip_h + ramp_h])
            cube([pcb_x + 2*pcb_clearance + 2.4, 0.25, 0.25], center=true);
    }
}

module pcb_cradle() {
    pcb_supports();
    pcb_end_clip(-1);
    pcb_end_clip(1);
}

module mount() {
    union() {
        din_clip();
        pcb_cradle();
    }
}

mount();

// Uncomment to visualize a translucent PCB in OpenSCAD preview:
// %translate([0,0,pcb_bottom_z + pcb_t/2]) cube([pcb_x, pcb_y, pcb_t], center=true);
