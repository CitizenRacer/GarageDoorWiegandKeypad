// ChatGPT HiLetgo 4-channel BSS138 level-shifter DIN rail mount
// Design version: 3
// VERSIONING RULE: Increment design_version by 1 for every repository check-in of this file.
//
// Design intent for v3:
//   * One-piece, side-profile DIN clip inspired by common printable PCB DIN mounts.
//   * Fixed DIN hook on one side + flexible snap hook on the other.
//   * PCB slides into two edge channels; no screws and no enclosure around the board.
//   * The model is a nearly constant cross-section, so it prints flat on its side with no supports.
//
// Standard rail: 35 mm x 7.5 mm top-hat DIN rail (EN 60715 / TH35-7.5).
// PCB envelope supplied by customer Q&A: approximately 15.3 x 12.6 x 1.6 mm.
// The 15.3 mm dimension is oriented ACROSS the DIN rail so the clips grip the two
// short, unpopulated PCB edges. The two 6-pin solder/header rows remain exposed.

$fn = 48;

// ---------- VERSION ----------
design_version = 3;  // Increment by 1 on every repository check-in

// ---------- OUTPUT / DEBUG ----------
// true = exported STL is already laid on its broad side for support-free printing.
// false = show the mount in its installed orientation.
print_orientation = true;
show_reference_pcb = false;  // useful only with print_orientation = false
show_reference_din = false;  // useful only with print_orientation = false

// ---------- PCB PARAMETERS ----------
pcb_x = 15.3;           // across DIN rail; clips grip the two short PCB edges
pcb_y = 12.6;           // along DIN rail; pin rows are near these two edges
pcb_t = 1.6;
pcb_side_clearance = 0.25;  // per side in the slide channel
pcb_z_clearance = 0.25;     // above PCB in the slide channel

// The mount only grips the center portion of the PCB so the pin rows/solder joints
// at both long edges remain unobstructed.
mount_depth = 8.0;      // along DIN rail

// PCB slide-channel geometry
channel_wall_t = 1.6;
lower_lip_overlap = 1.25;
lower_lip_t = 1.20;
upper_lip_overlap = 0.85;
upper_lip_t = 0.90;
under_pcb_gap = 1.35;   // clearance under the PCB center

// ---------- DIN RAIL PARAMETERS ----------
din_width = 35.0;
din_height = 7.5;
din_thickness = 1.0;       // common steel TH35 rail thickness
rail_side_clearance = 0.30;

// DIN clip geometry
backplate_t = 3.0;
fixed_hook_t = 2.2;
spring_arm_t = 1.8;
hook_overlap = 1.65;
hook_t = 1.25;
hook_extra_drop = 0.45;

// ---------- BODY PARAMETERS ----------
// The body narrows toward the tiny PCB, but stays a simple 2D profile.
body_shoulder_half_w = 16.4;
body_neck_half_w = 9.4;
body_neck_z = 8.8;

// ---------- DERIVED DIMENSIONS ----------
rail_half = din_width/2;
rail_flange_top_z = -din_height;
rail_flange_bottom_z = rail_flange_top_z - din_thickness;

fixed_inner_x = -(rail_half + rail_side_clearance);
fixed_outer_x = fixed_inner_x - fixed_hook_t;
spring_inner_x = rail_half + rail_side_clearance;
spring_outer_x = spring_inner_x + spring_arm_t;

hook_top_z = rail_flange_bottom_z + 0.10;
hook_bottom_z = hook_top_z - hook_t;
arm_bottom_z = hook_bottom_z - hook_extra_drop;

pcb_half = pcb_x/2;
channel_inner_x = pcb_half + pcb_side_clearance;
channel_outer_x = channel_inner_x + channel_wall_t;

channel_base_z = body_neck_z + 0.55;
pcb_bottom_z = channel_base_z + lower_lip_t;
pcb_top_z = pcb_bottom_z + pcb_t;
upper_lip_bottom_z = pcb_top_z + pcb_z_clearance;
channel_top_z = upper_lip_bottom_z + upper_lip_t;

// ---------- 2D HELPERS ----------
module rect2d(x0, x1, z0, z1) {
    translate([x0, z0]) square([x1-x0, z1-z0], center=false);
}

module body_profile_2d() {
    // Rail contact/backplate.
    rect2d(fixed_outer_x, spring_outer_x, 0, backplate_t);

    // Tapered body up to the PCB holder. Since the complete part is printed on
    // its side, these slopes do not create unsupported print overhangs.
    polygon(points=[
        [-body_shoulder_half_w, backplate_t],
        [ body_shoulder_half_w, backplate_t],
        [ body_neck_half_w, body_neck_z],
        [-body_neck_half_w, body_neck_z]
    ]);

    // Short neck connecting the tapered body to the PCB channels.
    rect2d(-body_neck_half_w, body_neck_half_w,
           body_neck_z, channel_base_z + 0.15);
}

module fixed_din_hook_2d() {
    // Rigid left wall.
    rect2d(fixed_outer_x, fixed_inner_x, arm_bottom_z, backplate_t);

    // Inward catch under the left DIN flange. The chamfer at the tip makes it
    // easier to engage the fixed side before snapping the spring side down.
    polygon(points=[
        [fixed_inner_x, hook_top_z],
        [fixed_inner_x + hook_overlap, hook_top_z],
        [fixed_inner_x + hook_overlap - 0.35, hook_bottom_z],
        [fixed_inner_x, hook_bottom_z]
    ]);
}

module spring_din_hook_2d() {
    // Long, simple spring arm attached only at the backplate. This is the part
    // that flexes outward while the mount is pushed onto the rail.
    rect2d(spring_inner_x, spring_outer_x, arm_bottom_z, backplate_t);

    // Snap hook with a generous diagonal lead-in. The rail flange rides along
    // the diagonal, pushes the arm outward, then the hook snaps underneath.
    polygon(points=[
        [spring_inner_x, hook_top_z + 1.65],
        [spring_inner_x, hook_bottom_z],
        [spring_inner_x - hook_overlap + 0.35, hook_bottom_z],
        [spring_inner_x - hook_overlap, hook_top_z],
        [spring_inner_x, hook_top_z + 1.65]
    ]);

    // Small outward pry tab at the bottom for a flat screwdriver during removal.
    polygon(points=[
        [spring_outer_x, arm_bottom_z + 0.15],
        [spring_outer_x + 3.0, arm_bottom_z + 0.15],
        [spring_outer_x + 3.0, arm_bottom_z + 1.55],
        [spring_outer_x, arm_bottom_z + 1.05]
    ]);
}

module pcb_channels_2d() {
    // Left and right channels are mirror images. The PCB slides in from either
    // end along Y; there are no snap tabs to fight and no hardware required.
    for (sx=[-1,1]) {
        // Vertical outside wall.
        x0 = sx < 0 ? -channel_outer_x : channel_inner_x;
        x1 = sx < 0 ? -channel_inner_x : channel_outer_x;
        rect2d(x0, x1, channel_base_z, channel_top_z);

        // Lower support ledge: only the outer edge of the PCB is supported,
        // leaving the board center and bottom-side soldering clear.
        lx0 = sx < 0 ? -channel_inner_x : channel_inner_x - lower_lip_overlap;
        lx1 = sx < 0 ? -channel_inner_x + lower_lip_overlap : channel_inner_x;
        rect2d(lx0, lx1, channel_base_z, pcb_bottom_z);

        // Upper retaining lip.
        ux0 = sx < 0 ? -channel_inner_x : channel_inner_x - upper_lip_overlap;
        ux1 = sx < 0 ? -channel_inner_x + upper_lip_overlap : channel_inner_x;
        rect2d(ux0, ux1, upper_lip_bottom_z, channel_top_z);
    }

    // Two tiny feet connect the edge channels to the neck while preserving most
    // of the under-PCB air gap.
    foot_w = 2.2;
    for (sx=[-1,1]) {
        cx = sx * (channel_inner_x - lower_lip_overlap/2);
        rect2d(cx-foot_w/2, cx+foot_w/2,
               body_neck_z, channel_base_z + 0.10);
    }
}

module mount_profile_2d() {
    union() {
        body_profile_2d();
        fixed_din_hook_2d();
        spring_din_hook_2d();
        pcb_channels_2d();
    }
}

module mount_installed_orientation() {
    // Extruding a single side profile is the key to the easy-print design.
    rotate([90,0,0])
        linear_extrude(height=mount_depth, center=true, convexity=10)
            mount_profile_2d();
}

module reference_pcb() {
    color([0.05,0.35,0.65,0.45])
        translate([0,0,pcb_bottom_z + pcb_t/2])
            cube([pcb_x, pcb_y, pcb_t], center=true);
}

module reference_din() {
    // Simplified TH35-7.5 reference rail for fit visualization only.
    // 35 mm overall width, 27 mm crown width, 7.5 mm height, 1 mm material.
    crown_half = 13.5;
    rail_len = mount_depth + 12;
    color([0.55,0.55,0.55,0.35])
    rotate([90,0,0])
        linear_extrude(height=rail_len, center=true)
            polygon(points=[
                [-crown_half, 0], [ crown_half, 0],
                [ rail_half, rail_flange_top_z],
                [ rail_half, rail_flange_bottom_z],
                [ crown_half-0.8, rail_flange_top_z+0.15],
                [-crown_half+0.8, rail_flange_top_z+0.15],
                [-rail_half, rail_flange_bottom_z],
                [-rail_half, rail_flange_top_z]
            ]);
}

module final_model() {
    if (print_orientation) {
        // Put one broad X-Z side directly on the print bed. The spring flexes in
        // the layer plane, which is both strong and support-free.
        translate([0,0,mount_depth/2])
            rotate([90,0,0])
                mount_installed_orientation();
    } else {
        mount_installed_orientation();
        if (show_reference_pcb) reference_pcb();
        if (show_reference_din) reference_din();
    }
}

final_model();
