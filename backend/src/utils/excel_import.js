const XLSX = require('xlsx');
const JSZip = require('jszip');
const { XMLParser } = require('fast-xml-parser');
const path = require('path');

// Utility: normalize header keys (trim, lowercase)
function normalizeHeader(h) {
  return String(h || '').trim().toLowerCase();
}

// Read sheet headers and rows; also compute Excel row numbers for each data row
function readSheetRows(workbook, options = {}) {
  const sheetName = workbook.SheetNames[0];
  const ws = workbook.Sheets[sheetName];
  if (!ws) throw new Error('No worksheet found in uploaded Excel');

  // Read as raw 2D array to preserve positions
  const rows2D = XLSX.utils.sheet_to_json(ws, { header: 1, defval: null, raw: false });
  if (!rows2D.length) return { headers: [], rows: [], rowNumbers: [] };

  const headerRow = rows2D[0].map(normalizeHeader);
  const dataRows = rows2D.slice(1);

  // Map data rows to objects with headers
  const rows = dataRows.map(r => {
    const obj = {};
    headerRow.forEach((h, i) => {
      if (!h) return;
      obj[h] = r[i] !== undefined && r[i] !== null ? String(r[i]).trim() : null;
    });
    return obj;
  });

  // Compute the absolute Excel row numbers (1-based). Header assumed at row 1
  const rowNumbers = dataRows.map((_, idx) => idx + 2); // header at 1, first data at 2

  return { headers: headerRow, rows, rowNumbers, ws, sheetName };
}

function getSheetIndexFromName(workbook, sheetName) {
  return Math.max(0, workbook.SheetNames.indexOf(sheetName));
}

// Locate drawing part for a worksheet via its rels file
async function findDrawingPathForSheet(zip, sheetIndex) {
  const sheetRelsPath = `xl/worksheets/_rels/sheet${sheetIndex + 1}.xml.rels`;
  const relsFile = zip.file(sheetRelsPath);
  if (!relsFile) return null;
  const xml = await relsFile.async('text');
  const parser = new XMLParser({ ignoreAttributes: false });
  const rels = parser.parse(xml);
  const list = (rels?.Relationships?.Relationship) || [];
  const relationships = Array.isArray(list) ? list : [list];
  const drawingRel = relationships.find(r => r['@_Type'] && r['@_Type'].includes('/relationships/drawing'));
  if (!drawingRel) return null;
  // Target may be like '../drawings/drawing1.xml' relative to sheet rels folder
  const target = drawingRel['@_Target'];
  if (!target) return null;
  // Normalize path to xl/drawings/drawingN.xml
  const normalized = path.posix.normalize(path.posix.join('xl/worksheets/_rels', target)).replace('worksheets/_rels/../', '');
  return normalized; // typically 'xl/drawings/drawing1.xml'
}

async function parseDrawingAnchors(zip, drawingPath) {
  const file = zip.file(drawingPath);
  if (!file) return { anchors: [], relsMap: {} };

  const xml = await file.async('text');
  const parser = new XMLParser({ ignoreAttributes: false, removeNSPrefix: true });
  const doc = parser.parse(xml);

  const anchors = [];
  const twoCell = doc?.wsDr?.twoCellAnchor || [];
  const oneCell = doc?.wsDr?.oneCellAnchor || [];
  const all = (Array.isArray(twoCell) ? twoCell : [twoCell]).filter(Boolean)
    .concat((Array.isArray(oneCell) ? oneCell : [oneCell]).filter(Boolean));

  for (const a of all) {
    const from = a.from || a['xdr:from'];
    const pic = a.pic || a['xdr:pic'];
    if (!from || !pic) continue;
    const row = parseInt(from.row ?? from['xdr:row'] ?? 0, 10);
    const col = parseInt(from.col ?? from['xdr:col'] ?? 0, 10);
    const blip = pic.blipFill?.blip || pic['a:blipFill']?.['a:blip'];
    const relId = blip?.['@_embed'] || blip?.['@_r:embed'] || blip?.['@_r:link'];
    if (Number.isFinite(row) && Number.isFinite(col) && relId) {
      anchors.push({ row, col, relId });
    }
  }

  // Parse rels for drawing to map relId -> media path
  const relsPath = `${path.posix.dirname(drawingPath)}/_rels/${path.posix.basename(drawingPath)}.rels`;
  const relsFile = zip.file(relsPath);
  const relsMap = {};
  if (relsFile) {
    const relsXml = await relsFile.async('text');
    const relsDoc = new XMLParser({ ignoreAttributes: false }).parse(relsXml);
    const relsList = (relsDoc?.Relationships?.Relationship) || [];
    const arr = Array.isArray(relsList) ? relsList : [relsList];
    for (const r of arr) {
      const id = r['@_Id'];
      const target = r['@_Target'];
      if (id && target) {
        // Normalize to zip path like 'xl/media/image1.png'
        const p = path.posix.normalize(path.posix.join(path.posix.dirname(relsPath), target)).replace('drawings/_rels/../', '');
        relsMap[id] = p;
      }
    }
  }

  return { anchors, relsMap };
}

async function extractEmbeddedImagesByRow(buffer, options = {}) {
  const workbook = XLSX.read(buffer, { type: 'buffer' });
  const { headers, rows, rowNumbers, sheetName } = readSheetRows(workbook, options);
  if (!rows.length) return { headers, rows, imagesByRow: new Map(), warnings: ['No data rows found'] };

  const imageColName = normalizeHeader(options.imageColumn || 'image');
  const imageColIndex = headers.findIndex(h => h === imageColName);

  const zip = await JSZip.loadAsync(buffer);
  const sheetIndex = getSheetIndexFromName(workbook, sheetName);
  const drawingPath = await findDrawingPathForSheet(zip, sheetIndex);
  const warnings = [];
  if (!drawingPath) {
    warnings.push('No drawing part found in worksheet; embedded images may be missing');
    return { headers, rows, imagesByRow: new Map(), warnings };
  }

  const { anchors, relsMap } = await parseDrawingAnchors(zip, drawingPath);
  // Build map of dataRowIndex -> image binary
  const imagesByRow = new Map();

  for (const a of anchors) {
    // Excel anchor rows are 0-based; data starts at Excel row 2 (index 1)
    const excelRow1Based = a.row + 1; // convert to 1-based
    const dataIndex = excelRow1Based - 2; // subtract header row (row 1)
    if (dataIndex < 0 || dataIndex >= rows.length) continue;
    if (Number.isFinite(imageColIndex) && imageColIndex >= 0 && a.col !== imageColIndex) {
      // If an explicit image column is defined, only accept anchors on that column
      continue;
    }
    const mediaPath = relsMap[a.relId];
    if (!mediaPath) continue;
    const mediaFile = zip.file(mediaPath);
    if (!mediaFile) continue;
    const content = await mediaFile.async('nodebuffer');
    const ext = path.extname(mediaPath).toLowerCase() || '.png';
    imagesByRow.set(dataIndex, { buffer: content, ext, mediaPath, excelRow: excelRow1Based });
  }

  return { headers, rows, imagesByRow, warnings };
}

module.exports = {
  extractEmbeddedImagesByRow,
  normalizeHeader,
};
