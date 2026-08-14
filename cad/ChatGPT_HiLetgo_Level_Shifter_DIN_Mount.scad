// ChatGPT HiLetgo 4-channel BSS138 level-shifter DIN rail mount
// Design version: 8
// VERSIONING RULE: Increment design_version by 1 for every repository check-in of this file.
//
// v8 rebuilds the complete mount as ONE closed 2D outline extruded through the
// full 10 mm width. This eliminates overlapping/coplanar solids from prior
// versions, which could create non-manifold edges, duplicate faces, inverted
// normals, or degenerate triangles in some STL validators/repair services.
//
// Geometry retained from v7:
//   * no center hole
//   * no rectangular side openings
//   * PCB clip spans the full width of the DIN mount
//   * broad-side, support-free print orientation
//
// HiLetgo PCB envelope used for the cradle: ~15.3 x 12.6 x 1.6 mm.

$fn = 48;
design_version = 8;
mount_width = 10.0;  // full extrusion width / DIN-rail-axis dimension

// Final cleaned side profile. It is intentionally a single polygon with no
// internal holes. Extruding one polygon guarantees a single closed solid.
profile = [
    [-5.000000, 3.416350],
    [-14.330100, 0.916351],
    [-17.750000, 0.000000],
    [-17.750000, -1.500000],
    [-16.250000, -2.500000],
    [-19.250000, -3.500000],
    [-22.250000, -3.500000],
    [-22.250000, 5.416350],
    [-21.250000, 6.416350],
    [-9.500000, 6.416350],
    [-9.500000, 10.100000],
    [-8.145450, 10.100000],
    [-9.100000, 11.100000],
    [-9.100000, 11.300000],
    [-8.900000, 11.300000],
    [-7.850000, 10.200000],
    [-7.850000, 10.100000],
    [-7.150000, 10.100000],
    [-7.150000, 9.200000],
    [-8.000000, 9.200000],
    [-8.000000, 7.400000],
    [-6.450000, 7.400000],
    [-6.450000, 6.450000],
    [6.450000, 6.450000],
    [6.450000, 7.400000],
    [8.000000, 7.400000],
    [8.000000, 9.200000],
    [7.150000, 9.200000],
    [7.150000, 10.100000],
    [7.850000, 10.100000],
    [7.850000, 10.200000],
    [8.900000, 11.300000],
    [9.100000, 11.300000],
    [9.100000, 11.100000],
    [8.145450, 10.100000],
    [9.500000, 10.100000],
    [9.500000, 6.416350],
    [21.250000, 6.416350],
    [22.250000, 5.416350],
    [22.250000, -3.500000],
    [19.250000, -3.500000],
    [16.250000, -2.500000],
    [17.750000, -1.500000],
    [17.750000, 0.000000],
    [14.330100, 0.916351],
    [5.000000, 3.416350]
];

linear_extrude(height=mount_width, center=false, convexity=10)
    polygon(points=profile, convexity=10);
