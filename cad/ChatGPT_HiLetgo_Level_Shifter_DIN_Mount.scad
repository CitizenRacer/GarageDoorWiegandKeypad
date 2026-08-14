// ChatGPT HiLetgo 4-channel BSS138 level-shifter DIN rail mount
// Design version: 7
// VERSIONING RULE: Increment design_version by 1 for every repository check-in of this file.
//
// The DIN-rail spring geometry below is embedded directly from the STL supplied
// by the user. Its shape is preserved exactly; the only new geometry is the
// compact HiLetgo PCB snap cradle joined to its center.
// v7 removes ALL mounting/lightening holes from the supplied DIN clip.
// The former center hole and both rectangular side openings are filled flush
// with the surrounding clip surfaces; no bump-outs are added.
// The PCB cradle spans the full 10 mm width of the DIN clip so, when printed
// on its broad side, every cradle feature starts at the build plate and needs no supports.
//
// HiLetgo PCB envelope used here: approximately 15.3 x 12.6 x 1.6 mm.

$fn = 48;
design_version = 7;
print_orientation = true;  // true = broad side on build plate for support-free printing

// ---------- PCB ----------
pcb_x = 15.3;           // long dimension; cradle grips these two ends
pcb_y = 12.6;           // pin-row edges overhang the narrow cradle in Y
pcb_t = 1.6;
pcb_xy_clearance = 0.35;
pcb_z_clearance = 0.20;

// ---------- CRADLE ----------
clip_center_y = 5.0;
cradle_depth_y = 10.0;  // full clip width: y=0..10, eliminating support-only overhangs
wall_t = 1.5;
ledge_inset = 1.55;
ledge_t = 1.2;
lip_inset = 0.85;
lip_t = 0.9;
ramp_out = 1.0;
ramp_depth = 1.1;

// The source spring engages the rail on +Z, so the PCB faces outward toward -Z.
pcb_inner_z = -7.40;
pcb_outer_z = pcb_inner_z - pcb_t;
lip_inner_z = pcb_outer_z - pcb_z_clearance;

// Legacy neck dimensions retained for cradle geometry reference; v6 does not add
// the square center neck to the rail-facing surface.
neck_x = 8.0;
neck_y = 8.0;
neck_z_top = -3.20;
neck_z_bottom = -6.45;

// ---------- EMBEDDED SOURCE DIN SPRING ----------
// Exact triangle mesh from the user-supplied din_rail_spring_with_hole.stl.
module source_din_clip() {
    polyhedron(
        points=[
    [2.120677, 4.646122, -6.416352],
    [2.120677, 4.646122, -3.416352],
    [2.15, 5, -6.416352],
    [2.15, 5, -3.416352],
    [2.120677, 5.353878, -6.416352],
    [2.120677, 5.353878, -3.416352],
    [2.033507, 5.698104, -6.416352],
    [2.033507, 5.698104, -3.416352],
    [1.890869, 6.023287, -6.416352],
    [1.890869, 6.023287, -3.416352],
    [1.696652, 6.320557, -6.416352],
    [1.696652, 6.320557, -3.416352],
    [1.456155, 6.581806, -6.416352],
    [1.456155, 6.581806, -3.416352],
    [1.175938, 6.799908, -6.416352],
    [1.175938, 6.799908, -3.416352],
    [0.863645, 6.968913, -6.416352],
    [0.863645, 6.968913, -3.416352],
    [0.527794, 7.08421, -6.416352],
    [0.527794, 7.08421, -3.416352],
    [0.177546, 7.142657, -6.416352],
    [0.177546, 7.142657, -3.416352],
    [-0.177546, 7.142657, -6.416352],
    [-0.177546, 7.142657, -3.416352],
    [-0.527794, 7.08421, -6.416352],
    [-0.527794, 7.08421, -3.416352],
    [-0.863645, 6.968913, -6.416352],
    [-0.863645, 6.968913, -3.416352],
    [-1.175938, 6.799908, -6.416352],
    [-1.175938, 6.799908, -3.416352],
    [-1.456155, 6.581806, -6.416352],
    [-1.456155, 6.581806, -3.416352],
    [-1.696652, 6.320557, -6.416352],
    [-1.696652, 6.320557, -3.416352],
    [-1.890869, 6.023287, -6.416352],
    [-1.890869, 6.023287, -3.416352],
    [-2.033507, 5.698104, -6.416352],
    [-2.033507, 5.698104, -3.416352],
    [-2.120677, 5.353878, -6.416352],
    [-2.120677, 5.353878, -3.416352],
    [-2.15, 5, -6.416352],
    [-2.15, 5, -3.416352],
    [-2.120677, 4.646122, -6.416352],
    [-2.120677, 4.646122, -3.416352],
    [-2.033507, 4.301896, -6.416352],
    [-2.033507, 4.301896, -3.416352],
    [-1.890869, 3.976713, -6.416352],
    [-1.890869, 3.976713, -3.416352],
    [-1.696652, 3.679443, -6.416352],
    [-1.696652, 3.679443, -3.416352],
    [-1.456155, 3.418194, -6.416352],
    [-1.456155, 3.418194, -3.416352],
    [-1.175938, 3.200092, -6.416352],
    [-1.175938, 3.200092, -3.416352],
    [-0.863645, 3.031087, -6.416352],
    [-0.863645, 3.031087, -3.416352],
    [-0.527794, 2.915789, -6.416352],
    [-0.527794, 2.915789, -3.416352],
    [-0.177546, 2.857343, -6.416352],
    [-0.177546, 2.857343, -3.416352],
    [0.177546, 2.857343, -6.416352],
    [0.177546, 2.857343, -3.416352],
    [0.527794, 2.915789, -6.416352],
    [0.527794, 2.915789, -3.416352],
    [0.863645, 3.031087, -6.416352],
    [0.863645, 3.031087, -3.416352],
    [1.175938, 3.200092, -6.416352],
    [1.175938, 3.200092, -3.416352],
    [1.456155, 3.418194, -6.416352],
    [1.456155, 3.418194, -3.416352],
    [1.696652, 3.679443, -6.416352],
    [1.696652, 3.679443, -3.416352],
    [1.890869, 3.976713, -6.416352],
    [1.890869, 3.976713, -3.416352],
    [2.033507, 4.301896, -6.416352],
    [2.033507, 4.301896, -3.416352],
    [21.25, 10, -6.416352],
    [22.25, 10, -5.416352],
    [21.25, 0, -6.416352],
    [22.25, 0, -5.416352],
    [-21.25, 0, -6.416352],
    [-21.25, 10, -6.416352],
    [5, 0, -3.416352],
    [-5, 0, -3.416352],
    [-22.25, 0, -5.416352],
    [-17.75, 0, -0],
    [-22.25, 0, 3.5],
    [-17.75, 0, 1.5],
    [-16.25, 0, 2.5],
    [17.75, 0, 0],
    [22.25, 0, 3.5],
    [17.75, 0, 1.5],
    [16.25, 0, 2.5],
    [19.25, 0, 3.5],
    [-19.25, 0, 3.5],
    [-22.25, 10, -5.416352],
    [5, 7, -3.416352],
    [22.25, 7, -3.416352],
    [14.330127, 7, -0.916352],
    [22.25, 7, -0.916352],
    [14.330127, 3, -0.916352],
    [22.25, 3, -0.916352],
    [5, 3, -3.416352],
    [22.25, 3, -3.416352],
    [5, 10, -3.416352],
    [-5, 10, -3.416352],
    [-5, 3, -3.416352],
    [-22.25, 3, -3.416352],
    [-22.25, 7, -3.416352],
    [-5, 7, -3.416352],
    [-14.330127, 7, -0.916352],
    [-14.330127, 3, -0.916352],
    [-22.25, 7, -0.916352],
    [-22.25, 3, -0.916352],
    [-17.75, 10, -0],
    [-22.25, 10, 3.5],
    [-19.25, 10, 3.5],
    [22.25, 10, 3.5],
    [19.25, 10, 3.5],
    [16.25, 10, 2.5],
    [17.75, 10, 1.5],
    [17.75, 10, 0],
    [-17.75, 10, 1.5],
    [-16.25, 10, 2.5]
        ],
        faces=[
    [0, 1, 2],
    [2, 1, 3],
    [2, 3, 4],
    [4, 3, 5],
    [4, 5, 6],
    [6, 5, 7],
    [6, 7, 8],
    [8, 7, 9],
    [8, 9, 10],
    [10, 9, 11],
    [10, 11, 12],
    [12, 11, 13],
    [12, 13, 14],
    [14, 13, 15],
    [14, 15, 16],
    [16, 15, 17],
    [16, 17, 18],
    [18, 17, 19],
    [18, 19, 20],
    [20, 19, 21],
    [20, 21, 22],
    [22, 21, 23],
    [22, 23, 24],
    [24, 23, 25],
    [24, 25, 26],
    [26, 25, 27],
    [26, 27, 28],
    [28, 27, 29],
    [28, 29, 30],
    [30, 29, 31],
    [30, 31, 32],
    [32, 31, 33],
    [32, 33, 34],
    [34, 33, 35],
    [34, 35, 36],
    [36, 35, 37],
    [36, 37, 38],
    [38, 37, 39],
    [38, 39, 40],
    [40, 39, 41],
    [40, 41, 42],
    [42, 41, 43],
    [42, 43, 44],
    [44, 43, 45],
    [44, 45, 46],
    [46, 45, 47],
    [46, 47, 48],
    [48, 47, 49],
    [48, 49, 50],
    [50, 49, 51],
    [50, 51, 52],
    [52, 51, 53],
    [52, 53, 54],
    [54, 53, 55],
    [54, 55, 56],
    [56, 55, 57],
    [56, 57, 58],
    [58, 57, 59],
    [58, 59, 60],
    [60, 59, 61],
    [60, 61, 62],
    [62, 61, 63],
    [62, 63, 64],
    [64, 63, 65],
    [64, 65, 66],
    [66, 65, 67],
    [66, 67, 68],
    [68, 67, 69],
    [68, 69, 70],
    [70, 69, 71],
    [70, 71, 72],
    [72, 71, 73],
    [72, 73, 74],
    [74, 73, 75],
    [74, 75, 0],
    [0, 75, 1],
    [76, 77, 78],
    [78, 77, 79],
    [4, 76, 2],
    [2, 76, 78],
    [2, 78, 0],
    [0, 78, 74],
    [74, 78, 72],
    [72, 78, 70],
    [70, 78, 68],
    [68, 78, 66],
    [66, 78, 64],
    [64, 78, 62],
    [62, 78, 60],
    [60, 78, 80],
    [60, 80, 58],
    [58, 80, 56],
    [56, 80, 54],
    [54, 80, 52],
    [52, 80, 50],
    [50, 80, 48],
    [48, 80, 46],
    [46, 80, 44],
    [44, 80, 42],
    [42, 80, 40],
    [40, 80, 81],
    [40, 81, 38],
    [38, 81, 36],
    [36, 81, 34],
    [34, 81, 32],
    [32, 81, 30],
    [30, 81, 28],
    [28, 81, 26],
    [26, 81, 24],
    [24, 81, 22],
    [22, 81, 76],
    [22, 76, 20],
    [20, 76, 18],
    [18, 76, 16],
    [16, 76, 14],
    [14, 76, 12],
    [12, 76, 10],
    [10, 76, 8],
    [8, 76, 6],
    [6, 76, 4],
    [79, 82, 78],
    [78, 82, 83],
    [78, 83, 80],
    [80, 83, 84],
    [84, 83, 85],
    [84, 85, 86],
    [86, 85, 87],
    [86, 87, 88],
    [82, 79, 89],
    [89, 79, 90],
    [89, 90, 91],
    [91, 90, 92],
    [92, 90, 93],
    [88, 94, 86],
    [95, 81, 84],
    [84, 81, 80],
    [96, 97, 98],
    [98, 97, 99],
    [100, 98, 101],
    [101, 98, 99],
    [102, 100, 103],
    [103, 100, 101],
    [1, 103, 3],
    [3, 103, 97],
    [3, 97, 5],
    [5, 97, 96],
    [5, 96, 7],
    [7, 96, 9],
    [9, 96, 11],
    [11, 96, 13],
    [13, 96, 15],
    [15, 96, 17],
    [17, 96, 19],
    [19, 96, 21],
    [21, 96, 104],
    [21, 104, 105],
    [103, 1, 102],
    [102, 1, 75],
    [102, 75, 73],
    [73, 71, 102],
    [102, 71, 69],
    [102, 69, 67],
    [67, 65, 102],
    [102, 65, 63],
    [102, 63, 61],
    [102, 61, 82],
    [82, 61, 59],
    [82, 59, 83],
    [83, 59, 106],
    [106, 59, 57],
    [106, 57, 55],
    [55, 53, 106],
    [106, 53, 51],
    [106, 51, 49],
    [49, 47, 106],
    [106, 47, 45],
    [106, 45, 43],
    [106, 43, 107],
    [107, 43, 41],
    [107, 41, 108],
    [108, 41, 39],
    [108, 39, 109],
    [109, 39, 37],
    [109, 37, 35],
    [35, 33, 109],
    [109, 33, 31],
    [109, 31, 29],
    [29, 27, 109],
    [109, 27, 25],
    [109, 25, 23],
    [109, 23, 105],
    [105, 23, 21],
    [110, 111, 112],
    [112, 111, 113],
    [109, 110, 108],
    [108, 110, 112],
    [106, 107, 111],
    [111, 107, 113],
    [106, 111, 83],
    [83, 111, 85],
    [85, 111, 110],
    [85, 110, 114],
    [114, 110, 105],
    [105, 110, 109],
    [86, 94, 115],
    [115, 94, 116],
    [84, 108, 95],
    [95, 108, 112],
    [95, 112, 115],
    [115, 112, 86],
    [86, 112, 113],
    [86, 113, 84],
    [84, 113, 107],
    [84, 107, 108],
    [77, 97, 79],
    [79, 97, 103],
    [79, 103, 101],
    [97, 77, 99],
    [99, 77, 117],
    [99, 117, 90],
    [99, 90, 101],
    [101, 90, 79],
    [93, 90, 118],
    [118, 90, 117],
    [92, 93, 119],
    [119, 93, 118],
    [91, 92, 120],
    [120, 92, 119],
    [89, 91, 121],
    [121, 91, 120],
    [102, 82, 100],
    [100, 82, 89],
    [100, 89, 98],
    [98, 89, 121],
    [98, 121, 104],
    [104, 96, 98],
    [87, 85, 122],
    [122, 85, 114],
    [88, 87, 123],
    [123, 87, 122],
    [94, 88, 116],
    [116, 88, 123],
    [76, 104, 77],
    [77, 104, 121],
    [77, 121, 117],
    [117, 121, 120],
    [117, 120, 119],
    [76, 81, 104],
    [104, 81, 105],
    [105, 81, 95],
    [105, 95, 114],
    [114, 95, 115],
    [114, 115, 122],
    [122, 115, 123],
    [123, 115, 116],
    [119, 118, 117]
        ],
        convexity=10
    );
}

module center_hole_filler() {
    // Fill ONLY the original cylindrical mounting hole, exactly between the two
    // original plate faces. This produces a continuous flat plate with no hole
    // and no square/rectangular bump on either face.
    translate([0, clip_center_y, -6.416352])
        cylinder(h=3.0, r=2.15, center=false, $fn=64);
}

module side_opening_fillers() {
    // Fill the two original side openings using the exact trapezoidal side
    // profile defined by the supplied mesh. This closes the openings without
    // extending beyond the clip's original exterior surfaces.
    slot_y0 = 3.0;
    slot_y1 = 7.0;
    slot_z0 = -3.416352;
    slot_z1 = -0.916352;
    slot_x_inner_bottom = 5.0;
    slot_x_inner_top = 14.330127;
    slot_x_outer = 22.25;

    module right_fill() {
        translate([0, slot_y1, 0])
            rotate([90,0,0])
                linear_extrude(height=slot_y1-slot_y0, convexity=4)
                    polygon(points=[
                        [slot_x_inner_bottom, slot_z0],
                        [slot_x_outer,        slot_z0],
                        [slot_x_outer,        slot_z1],
                        [slot_x_inner_top,    slot_z1]
                    ]);
    }

    right_fill();
    mirror([1,0,0]) right_fill();
}

module center_neck() {
    translate([0, clip_center_y, (neck_z_top + neck_z_bottom)/2])
        cube([neck_x, neck_y, neck_z_top - neck_z_bottom], center=true);
}

// One flexible PCB end wall. sx=-1 left, sx=+1 right.
// The wall, ledge, retaining lip, and lead-in ramp form a simple side profile
// extruded along Y, making the complete mount easy to print on either Y face.
module pcb_snap_wall(sx=1) {
    // Flexible wall beside the PCB end.
    translate([
        sx * (pcb_x/2 + pcb_xy_clearance + wall_t/2),
        clip_center_y,
        (neck_z_bottom + lip_inner_z - lip_t)/2
    ])
        cube([
            wall_t,
            cradle_depth_y,
            abs((lip_inner_z - lip_t) - neck_z_bottom)
        ], center=true);

    // Rail-facing ledge supporting the PCB underside/end.
    translate([
        sx * (pcb_x/2 + pcb_xy_clearance - ledge_inset/2),
        clip_center_y,
        pcb_inner_z + ledge_t/2
    ])
        cube([ledge_inset, cradle_depth_y, ledge_t], center=true);

    // Small inward lip retaining the PCB after it snaps into place.
    translate([
        sx * (pcb_x/2 + pcb_xy_clearance - lip_inset/2),
        clip_center_y,
        lip_inner_z - lip_t/2
    ])
        cube([lip_inset, cradle_depth_y, lip_t], center=true);

    // Chamfered lead-in ramp so the PCB can be pressed straight into the clip.
    hull() {
        translate([
            sx * (pcb_x/2 + pcb_xy_clearance - 0.05),
            clip_center_y,
            lip_inner_z - lip_t
        ])
            cube([0.20, cradle_depth_y, 0.20], center=true);

        translate([
            sx * (pcb_x/2 + pcb_xy_clearance + ramp_out),
            clip_center_y,
            lip_inner_z - lip_t - ramp_depth
        ])
            cube([0.20, cradle_depth_y, 0.20], center=true);
    }
}

module pcb_cradle() {
    // Crossbar ties both snap walls into the center neck.
    translate([0, clip_center_y, neck_z_bottom + 0.65])
        cube([
            pcb_x + 2*(pcb_xy_clearance + wall_t),
            cradle_depth_y,
            1.30
        ], center=true);

    pcb_snap_wall(-1);
    pcb_snap_wall(1);
}

module mount_installed() {
    // No holes remain. The center hole and both rectangular side openings are
    // filled only to their original surrounding surfaces; no bump-outs are added.
    union() {
        source_din_clip();
        center_hole_filler();
        side_opening_fillers();
        pcb_cradle();
    }
}

module final_model() {
    if (print_orientation) {
        // Rotate the original Y=0 broad face onto Z=0. The clip and PCB cradle
        // are then built in the layer plane, matching the easy-print concept.
        rotate([90,0,0])
            mount_installed();
    } else {
        mount_installed();
    }
}

final_model();

// Preview only: uncomment to visualize the PCB envelope.
// %translate([0, clip_center_y, pcb_inner_z - pcb_t/2])
//     cube([pcb_x, pcb_y, pcb_t], center=true);
