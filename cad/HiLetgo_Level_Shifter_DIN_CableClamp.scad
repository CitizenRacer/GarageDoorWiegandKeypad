// HiLetgo level-shifter DIN mount — Cable Clamp remix
// Design version: 6
// VERSIONING RULE: Increment design_version by 1 for every repository check-in of this design.
//
// This is the official HiLetgo level-shifter DIN holder for this project.
// It is based on the user-supplied DIN_Rail_Cable_Clamp.step.
//
// What changed from the cable clamp:
//   1. The two center cable-rest arms are removed completely.
//   2. The two rectangular cable-tie slots in the spine are filled.
//   3. A true full-width top/bottom slide cradle is added for the HiLetgo PCB.
//   4. The PCB is parallel to the DIN rail and slides in from either X side.
//   5. v4 flips the PCB cradle to the OPPOSITE (+Y) face of the DIN body.
//      The v3 cradle was on the cable-clamp-arm side; this version mounts the
//      PCB on the other side of the central DIN spine.
//   6. v5 widens the entire DIN clip body to exactly match the PCB cradle width.
//      There is no longer a wider cradle sitting on a narrower DIN body.
//   7. v6 renames the official source file to remove the ChatGPT prefix.
//
// The original STEP is effectively a 6 mm-wide extrusion. To keep this
// OpenSCAD source compact and robust, its center-plane Y/Z profile was captured
// from the STEP-derived mesh and simplified to ~0.03 mm. In v5 that same DIN
// spring/hook profile is extruded to the PCB cradle width instead of the original
// 6 mm, so the complete mount has one consistent width.

$fn = 48;
design_version = 6;

// ---------- HiLetgo PCB ----------
pcb_z = 15.3;             // board height in installed orientation
pcb_x = 12.6;             // board width across the DIN clip
pcb_t = 1.6;              // board thickness (Y)
pcb_edge_clear = 0.30;     // top/bottom clearance
pcb_face_clear = 0.25;     // front/rear clearance

// ---------- Mount / cradle ----------
cradle_side_margin = 0.60;
mount_width = pcb_x + 2*cradle_side_margin;  // 13.8 mm: DIN body and PCB cradle match
spine_front_y = 4.80;      // cable-arm side of the remaining center spine
spine_back_y = 9.00;       // opposite face of the DIN spine

// v4: PCB holder is on the +Y side of the spine (opposite v3).
// The board sits just outside the spine and slides in from either X side.
pcb_inner_y = spine_back_y + 0.80;
pcb_outer_y = pcb_inner_y + pcb_t;
slot_inner_y = pcb_inner_y - pcb_face_clear;
slot_outer_y = pcb_outer_y + pcb_face_clear;

board_half_z = pcb_z/2;
channel_inner_z = board_half_z + pcb_edge_clear;
channel_wall_t = 1.45;
channel_outer_z = channel_inner_z + channel_wall_t;
edge_overlap = 1.10;
outer_lip_t = 0.80;
lead_in = 0.60;

cradle_width_x = mount_width;  // exactly the same width as the DIN clip body

// ---------- STEP-derived 2D DIN profile ----------
// Coordinates are [Y depth, Z vertical].  Only the two DIN-spring voids are
// retained as holes.  The original rectangular cable-tie slots are intentionally
// NOT subtracted, so they become solid in this PCB-mount remix.
source_outer = [
    [0.0000, -16.3500],
    [0.0000, -17.3500],
    [-1.0000, -17.3500],
    [-1.2679, -16.3500],
    [-2.2679, -16.3500],
    [-5.1675, -18.0355],
    [-5.5943, -18.4518],
    [-5.8794, -18.9754],
    [-5.9994, -19.6095],
    [-5.9859, -24.2194],
    [-4.8419, -28.5652],
    [-4.5932, -29.1009],
    [-4.3446, -29.4072],
    [-4.0813, -29.6307],
    [-3.7387, -29.8263],
    [-3.4123, -29.9393],
    [-2.9728, -29.9994],
    [-1.0000, -30.0000],
    [-1.0000, -28.4000],
    [-2.5064, -28.3945],
    [-2.7320, -28.3004],
    [-2.8860, -28.1106],
    [-3.1812, -27.0372],
    [-3.1905, -26.8515],
    [-3.1313, -26.6752],
    [-3.0118, -26.5328],
    [-2.8485, -26.4439],
    [-2.6640, -26.4208],
    [5.4219, -28.5823],
    [5.6620, -28.7130],
    [5.8577, -28.9039],
    [6.1149, -29.4654],
    [6.2722, -29.6858],
    [6.4830, -29.8560],
    [6.7079, -29.9564],
    [6.9753, -29.9997],
    [9.0000, -30.0000],
    [9.0000, 30.0000],
    [3.0550, 29.9975],
    [2.5177, 29.8959],
    [1.9872, 29.6239],
    [1.6886, 29.3603],
    [1.4226, 29.0000],
    [-2.7321, 21.8038],
    [-2.9499, 21.2489],
    [-2.9994, 20.8537],
    [-3.0000, 17.3500],
    [-2.4641, 15.3500],
    [-1.7359, 15.3500],
    [-1.2000, 17.3500],
    [0.0000, 17.3500],
    [0.0099, 14.1509],
    [0.1206, 13.6660],
    [0.3761, 13.1825],
    [0.6035, 12.9183],
    [0.8734, 12.6975],
    [1.1774, 12.5270],
    [1.5550, 12.4001],
    [1.9501, 12.3506],
    [4.0143, 12.3490],
    [4.3492, 12.2596],
    [4.6306, 12.0247],
    [4.7784, 11.7112],
    [4.7805, 11.3446],
    [4.6238, 11.0132],
    [4.2831, 10.7568],
    [4.0647, 10.7016],
    [3.8396, 10.7075],
    [-1.0000, 12.0000],
    [-5.1490, 11.9888],
    [-5.4339, 11.9010],
    [-5.6802, 11.7331],
    [-5.8782, 11.4783],
    [-5.9802, 11.1981],
    [-5.9888, 8.8510],
    [-5.8400, 8.4575],
    [-5.5214, 8.1467],
    [-5.2708, 8.0374],
    [-5.0249, 8.0003],
    [-1.0000, 8.0000],
    [2.7186, 6.9998],
    [3.4513, 6.6486],
    [4.0135, 6.1689],
    [4.4757, 5.5006],
    [4.7262, 4.8053],
    [4.8000, 4.1439],
    [4.7963, -4.2920],
    [4.7262, -4.8053],
    [4.5965, -5.2301],
    [4.4055, -5.6311],
    [4.1573, -5.9994],
    [3.8030, -6.3773],
    [3.4513, -6.6486],
    [3.0634, -6.8649],
    [2.5765, -7.0417],
    [-1.0000, -8.0000],
    [-5.1981, -8.0198],
    [-5.4783, -8.1218],
    [-5.6982, -8.2841],
    [-5.8782, -8.5217],
    [-5.9749, -8.7775],
    [-6.0000, -11.0000],
    [-5.9691, -11.2468],
    [-5.8660, -11.5000],
    [-5.6802, -11.7331],
    [-5.4562, -11.8899],
    [-5.1981, -11.9802],
    [-1.0000, -12.0000],
    [3.5893, -10.7716],
    [3.9095, -10.7551],
    [4.2407, -10.8515],
    [4.5847, -11.1292],
    [4.7753, -11.5281],
    [4.8028, -13.4247],
    [4.8521, -13.6685],
    [4.9600, -13.8925],
    [5.1572, -14.1160],
    [5.4347, -14.2809],
    [5.6757, -14.3422],
    [6.1981, -14.3698],
    [6.5425, -14.5100],
    [6.8400, -14.8075],
    [6.9848, -15.1764],
    [6.9749, -15.5725],
    [6.8119, -15.9337],
    [6.5214, -16.2033],
    [6.1736, -16.3348],
];

lower_spring_void = [
    [-4.5107, -18.7997],
    [-2.0306, -17.3676],
    [-1.7673, -18.3500],
    [1.0000, -18.3500],
    [1.0000, -17.3500],
    [6.0498, -17.3512],
    [6.3420, -17.4103],
    [6.6235, -17.5682],
    [6.8400, -17.8075],
    [6.9691, -18.1032],
    [6.9888, -18.9990],
    [6.9115, -19.2613],
    [6.7660, -19.4928],
    [6.5633, -19.6762],
    [6.2948, -19.8056],
    [6.0000, -19.8500],
    [-2.5996, -19.8550],
    [-2.9113, -19.9385],
    [-3.1982, -20.1341],
    [-3.4010, -20.4161],
    [-3.4950, -20.7504],
    [-3.4851, -22.4854],
    [-3.3429, -22.8514],
    [-3.0504, -23.1483],
    [-2.7588, -23.2793],
    [5.3999, -25.4770],
    [5.7740, -25.7604],
    [5.9721, -26.1589],
    [5.9776, -26.6039],
    [5.7740, -27.0267],
    [5.5736, -27.2127],
    [5.3303, -27.3374],
    [5.0623, -27.3916],
    [4.7896, -27.3712],
    [-4.2588, -24.9479],
    [-4.6301, -24.7585],
    [-4.8919, -24.4342],
    [-4.9973, -24.0560],
    [-4.9997, -19.6345],
    [-4.9626, -19.3886],
    [-4.8660, -19.1594],
    [-4.7159, -18.9612],
];

upper_spring_void = [
    [4.8000, 28.8000],
    [4.8000, 13.5500],
    [1.8415, 13.5659],
    [1.6174, 13.6474],
    [1.4136, 13.8059],
    [1.2708, 14.0210],
    [1.2062, 14.2505],
    [1.2000, 18.5500],
    [-1.8000, 18.5500],
    [-1.7841, 20.9624],
    [-1.6928, 21.2038],
    [2.5419, 28.5142],
    [2.7721, 28.7026],
    [3.0552, 28.7938],
];

module source_profile_2d() {
    difference() {
        polygon(points=source_outer);
        polygon(points=lower_spring_void);
        polygon(points=upper_spring_void);
    }
}

module rect_yz(y0,y1,z0,z1) {
    translate([y0,z0]) square([y1-y0,z1-z0], center=false);
}

module clip_without_cable_arms_2d() {
    difference() {
        source_profile_2d();
        // Removes both center cable-rest arms while stopping just before the
        // central spine.  Upper/lower DIN spring hooks are untouched.
        rect_yz(-6.20, spine_front_y-0.02, -13.25, 13.25);
    }
}

module din_clip_body() {
    // Original DIN clip, with the cable-rest arms removed.
    multmatrix([
        [0,0,1,0],
        [1,0,0,0],
        [0,1,0,0],
        [0,0,0,1]
    ])
        linear_extrude(height=mount_width, center=true, convexity=20)
            clip_without_cable_arms_2d();
}

module pcb_cradle() {
    // v4 holder is on the +Y face of the DIN spine.
    // The PCB slides along X between top/bottom edge channels.
    xw = cradle_width_x;
    bridge_y0 = spine_back_y - 0.25;  // overlap body for a robust union
    bridge_y1 = slot_outer_y + outer_lip_t + lead_in;

    // TOP channel: overhead bridge/wall.
    translate([0, (bridge_y0+bridge_y1)/2,
               (channel_inner_z+channel_outer_z)/2])
        cube([xw, bridge_y1-bridge_y0,
              channel_outer_z-channel_inner_z], center=true);

    // Inner support ledge (spine side).
    translate([0, (bridge_y0+slot_inner_y)/2,
               channel_inner_z-edge_overlap/2])
        cube([xw, slot_inner_y-bridge_y0, edge_overlap], center=true);

    // Outer retaining lip.
    translate([0, slot_outer_y+outer_lip_t/2,
               channel_inner_z-edge_overlap/2])
        cube([xw, outer_lip_t, edge_overlap], center=true);

    // Outer lead-in ramp.
    hull() {
        translate([0, slot_outer_y+outer_lip_t+lead_in-0.05,
                   channel_inner_z-0.15])
            cube([xw,0.10,0.30], center=true);
        translate([0, slot_outer_y+outer_lip_t-0.05,
                   channel_inner_z-edge_overlap/2])
            cube([xw,0.10,edge_overlap], center=true);
    }

    // BOTTOM channel, mirrored in Z.
    translate([0, (bridge_y0+bridge_y1)/2,
               -(channel_inner_z+channel_outer_z)/2])
        cube([xw, bridge_y1-bridge_y0,
              channel_outer_z-channel_inner_z], center=true);

    translate([0, (bridge_y0+slot_inner_y)/2,
               -channel_inner_z+edge_overlap/2])
        cube([xw, slot_inner_y-bridge_y0, edge_overlap], center=true);

    translate([0, slot_outer_y+outer_lip_t/2,
               -channel_inner_z+edge_overlap/2])
        cube([xw, outer_lip_t, edge_overlap], center=true);

    hull() {
        translate([0, slot_outer_y+outer_lip_t+lead_in-0.05,
                   -channel_inner_z+0.15])
            cube([xw,0.10,0.30], center=true);
        translate([0, slot_outer_y+outer_lip_t-0.05,
                   -channel_inner_z+edge_overlap/2])
            cube([xw,0.10,edge_overlap], center=true);
    }
}

module mount() {
    union() {
        din_clip_body();
        pcb_cradle();
    }
}

mount();

// Preview-only PCB envelope. Set to true to verify the actual 15.3 x 12.6 x 1.6 board fit.
show_reference_pcb = false;
if (show_reference_pcb)
    %translate([0, (pcb_inner_y+pcb_outer_y)/2, 0])
        cube([pcb_x, pcb_t, pcb_z], center=true);
