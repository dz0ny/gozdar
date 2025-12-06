import proj4 from 'proj4';

// Define Projections
proj4.defs('EPSG:3794', '+proj=tmerc +lat_0=0 +lon_0=15 +k=0.9999 +x_0=500000 +y_0=-5000000 +ellps=GRS80 +towgs84=0,0,0,0,0,0,0 +units=m +no_defs +type=crs');
proj4.defs('EPSG:3857', '+proj=merc +a=6378137 +b=6378137 +lat_ts=0 +lon_0=0 +x_0=0 +y_0=0 +k=1 +units=m +nadgrids=@null +wktext +no_defs +type=crs');

const R = 6378137;

function xyzToBbox(x, y, z) {
  const resolution = (2 * Math.PI * R) / (256 * Math.pow(2, z));
  const originX = -Math.PI * R;
  const originY = Math.PI * R;

  const minX = originX + x * 256 * resolution;
  const maxX = originX + (x + 1) * 256 * resolution;
  const maxY = originY - y * 256 * resolution;
  const minY = originY - (y + 1) * 256 * resolution;

  return { minX, minY, maxX, maxY };
}

function reprojectBbox(bbox, sourceCrs, destCrs) {
  const corners = [
    [bbox.minX, bbox.minY],
    [bbox.maxX, bbox.minY],
    [bbox.maxX, bbox.maxY],
    [bbox.minX, bbox.maxY],
  ];

  let minX = Infinity, minY = Infinity, maxX = -Infinity, maxY = -Infinity;

  corners.forEach(corner => {
    const projected = proj4(sourceCrs, destCrs, corner);
    if (projected[0] < minX) minX = projected[0];
    if (projected[0] > maxX) maxX = projected[0];
    if (projected[1] < minY) minY = projected[1];
    if (projected[1] > maxY) maxY = projected[1];
  });

  return { minX, minY, maxX, maxY };
}

// Test Case: Ortofoto Tile 15/17500/11500 (Center of Slovenia approx)
const x = 17500;
const y = 11500;
const z = 15;

console.log(`Testing Tile: ${z}/${x}/${y}`);

const bbox3857 = xyzToBbox(x, y, z);
console.log('Web Mercator BBOX:', bbox3857);

const bbox3794 = reprojectBbox(bbox3857, 'EPSG:3857', 'EPSG:3794');
console.log('EPSG:3794 BBOX:', bbox3794);

// Validation
// Slovenia coordinates are roughly X: 370000-620000, Y: 30000-190000
const valid = (
    bbox3794.minX > 300000 && bbox3794.maxX < 700000 &&
    bbox3794.minY > 0 && bbox3794.maxY < 300000
);

if (valid) {
    console.log('SUCCESS: Coordinates look valid for Slovenia');
} else {
    console.error('FAILURE: Coordinates out of expected range for Slovenia');
    process.exit(1);
}
