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
  // Try standard path first
  const pathsToTry = [
    `xl/worksheets/_rels/sheet${sheetIndex + 1}.xml.rels`,
    `xl/worksheets/_rels/sheet1.xml.rels`, // Fallback to first sheet if index is weird
  ];
  
  // Also try to find ANY sheet rels that might match
  const allFiles = Object.keys(zip.files);
  const sheetRelsFiles = allFiles.filter(f => f.startsWith('xl/worksheets/_rels/sheet') && f.endsWith('.xml.rels'));
  
  for (const relsPath of [...pathsToTry, ...sheetRelsFiles]) {
    const relsFile = zip.file(relsPath);
    if (!relsFile) continue;
    
    console.log(`🔍 Checking rels file: ${relsPath}`);
    const xml = await relsFile.async('text');
    const parser = new XMLParser({ ignoreAttributes: false });
    const rels = parser.parse(xml);
    const list = (rels?.Relationships?.Relationship) || [];
    const relationships = Array.isArray(list) ? list : [list];
    const drawingRel = relationships.find(r => r['@_Type'] && r['@_Type'].includes('/relationships/drawing'));
    
    if (drawingRel) {
      const target = drawingRel['@_Target'];
      if (!target) continue;
      // Normalize path to xl/drawings/drawingN.xml
      const normalized = path.posix.normalize(path.posix.join(path.posix.dirname(relsPath), target)).replace('worksheets/_rels/', '');
      console.log(`🎯 Found drawing rel in ${relsPath} -> ${normalized}`);
      return normalized;
    }
  }
  return null;
}

async function parseDrawingAnchors(zip, drawingPath) {
  const file = zip.file(drawingPath);
  if (!file) return { anchors: [], relsMap: {} };

  console.log(`📖 Parsing drawing XML: ${drawingPath}`);
  const xml = await file.async('text');
  const parser = new XMLParser({ 
    ignoreAttributes: false, 
    removeNSPrefix: true,
    attributeNamePrefix: '' 
  });
  const doc = parser.parse(xml);
  
  // Find the actual root content key (skip ?xml, etc.)
  const rootKey = Object.keys(doc).find(k => !k.startsWith('?'));
  console.log(`🎨 Drawing XML Root Key: ${rootKey}. Top-level keys: ${rootKey && doc[rootKey] ? Object.keys(doc[rootKey]).join(',') : 'none'}`);

  const anchors = [];
  const wsDr = rootKey ? doc[rootKey] : null;
  const twoCell = wsDr?.twoCellAnchor || [];
  const oneCell = wsDr?.oneCellAnchor || [];
  const absCell = wsDr?.absoluteAnchor || [];
  
  const all = (Array.isArray(twoCell) ? twoCell : [twoCell]).filter(Boolean)
    .concat((Array.isArray(oneCell) ? oneCell : [oneCell]).filter(Boolean))
    .concat((Array.isArray(absCell) ? absCell : [absCell]).filter(Boolean));

  console.log(`⚓ Total anchors found in XML: ${all.length}`);
  
  if (all.length > 0) {
    console.log(`🔍 DEBUG: First anchor structure: ${JSON.stringify(all[0]).substring(0, 500)}`);
  }

  // If no anchors found, maybe they are nested deeper or under different names
  if (all.length === 0 && wsDr) {    console.log('🧐 No standard anchors found. Searching all keys for "Anchor"...');
    for (const key in wsDr) {
      if (key.toLowerCase().includes('anchor')) {
        console.log(`💡 Found potential anchor key: ${key}`);
        const found = Array.isArray(wsDr[key]) ? wsDr[key] : [wsDr[key]];
        all.push(...found.filter(Boolean));
      }
    }
    console.log(`⚓ After fuzzy search, anchors: ${all.length}`);
  }

  for (const a of all) {
    const from = a.from;
    const pic = a.pic;
    
    if (!from) {
      console.log('❓ Anchor missing "from" element');
      continue;
    }
    
    // Sometimes images are in groups or other structures
    const picElement = pic || a.graphicFrame?.graphic?.graphicData?.pic;
    
    if (!picElement) {
      console.log('❓ Anchor missing "pic" or recognized image element');
      continue;
    }
    
    const row = parseInt(from.row ?? 0, 10);
    const col = parseInt(from.col ?? 0, 10);
    
    // Check all possible locations for the embed ID (now with no @_ prefix)
    const blip = picElement.blipFill?.blip || picElement['a:blipFill']?.['a:blip'];
    const relId = blip?.embed || 
                  blip?.['r:embed'] || 
                  blip?.['r:id'] ||
                  blip?.link ||
                  blip?.['r:link'] ||
                  blip?.id ||
                  blip?.['@_embed'] || 
                  blip?.['@_r:embed']; 
    
    if (Number.isFinite(row) && Number.isFinite(col) && relId) {
      anchors.push({ row, col, relId });
    } else {
      console.log(`❓ Anchor incomplete: row=${row}, col=${col}, relId=${relId}. Keys: ${blip ? Object.keys(blip).join(',') : 'none'}`);
    }
  }

  // Parse rels for drawing to map relId -> media path
  const relsPath = `${path.posix.dirname(drawingPath)}/_rels/${path.posix.basename(drawingPath)}.rels`;
  const altRelsPath = `xl/drawings/_rels/${path.posix.basename(drawingPath)}.rels`;
  
  console.log(`📖 Checking drawing rels at: ${relsPath} or ${altRelsPath}`);
  const relsFile = zip.file(relsPath) || zip.file(altRelsPath);
  const relsMap = {};
  if (relsFile) {
    console.log(`✅ Found drawing rels at: ${relsFile.name}`);
    const relsXml = await relsFile.async('text');
    const relsDoc = new XMLParser({ 
      ignoreAttributes: false, 
      removeNSPrefix: true,
      attributeNamePrefix: '' 
    }).parse(relsXml);
    
    const root = relsDoc.Relationships || relsDoc[Object.keys(relsDoc)[0]];
    const list = root?.Relationship || [];
    const arr = Array.isArray(list) ? list : [list];
    for (const r of arr) {
      const id = r.Id || r['@_Id'];
      const target = r.Target || r['@_Target'];
      if (id && target) {
        // Normalize to zip path. If target starts with ../media, it's relative to drawings folder
        let p;
        if (target.includes('media/')) {
           // Standard media path is xl/media/
           p = `xl/media/${path.posix.basename(target)}`;
        } else {
           p = path.posix.normalize(path.posix.join(path.posix.dirname(drawingPath), target));
        }
        relsMap[id] = p;
      }
    }
  } else {
    console.log('❌ Drawing rels file NOT found');
  }

  return { anchors, relsMap };
}

async function extractEmbeddedImagesByRow(buffer, options = {}) {
  console.log('📊 Starting embedded image extraction...');
  const workbook = XLSX.read(buffer, { type: 'buffer' });
  const { headers, rows, rowNumbers, sheetName } = readSheetRows(workbook, options);
  console.log(`📊 Worksheet name: ${sheetName}, Headers: [${headers.join(', ')}]`);
  
  if (!rows.length) {
    console.log('⚠️ No rows found in Excel');
    return { headers, rows, imagesByRow: new Map(), warnings: ['No data rows found'] };
  }

  // Try to find image column index
  const commonImageNames = ['image', 'photo', 'picture', 'product image', 'img', 'file'];
  let imageColIndex = -1;
  
  if (options.imageColumn) {
    const target = normalizeHeader(options.imageColumn);
    imageColIndex = headers.findIndex(h => h === target);
  }
  
  if (imageColIndex === -1) {
    for (const name of commonImageNames) {
      imageColIndex = headers.findIndex(h => h === name);
      if (imageColIndex !== -1) {
        console.log(`🔍 Detected image column: "${headers[imageColIndex]}" at index ${imageColIndex}`);
        break;
      }
    }
  }

  console.log('📦 Loading Excel ZIP structure...');
  const zip = await JSZip.loadAsync(buffer);
  
  const sheetIndex = getSheetIndexFromName(workbook, sheetName);
  console.log(`📄 Sheet index: ${sheetIndex}`);
  
  const drawingPath = await findDrawingPathForSheet(zip, sheetIndex);
  const warnings = [];
  if (!drawingPath) {
    console.log(`⚠️ No drawing path found for sheet ${sheetIndex}. Checked sheet rels.`);
    // Try to find ANY drawing file as a fallback
    const fallbackDrawing = allFiles.find(f => f.startsWith('xl/drawings/drawing') && f.endsWith('.xml'));
    if (fallbackDrawing) {
      console.log(`💡 Fallback: Found drawing at ${fallbackDrawing}`);
      // Using fallback drawing might be risky but worth a try if the rels are broken
    }
    warnings.push('No drawing part found in worksheet; embedded images may be missing');
    return { headers, rows, imagesByRow: new Map(), warnings };
  }

  console.log(`🎨 Drawing path: ${drawingPath}`);
  const { anchors, relsMap } = await parseDrawingAnchors(zip, drawingPath);
  console.log(`🖼️ Found ${anchors.length} image anchors. Rels map size: ${Object.keys(relsMap).length}`);
  
  const imagesByRow = new Map();

  for (const a of anchors) {
    const excelRow1Based = a.row + 1;
    const dataIndex = excelRow1Based - 2;
    
    console.log(`📍 Processing anchor: Row=${a.row} (Excel ${excelRow1Based}), Col=${a.col}, RelID=${a.relId}`);
    
    if (dataIndex < 0 || dataIndex >= rows.length) {
      console.log(`⏭️ Anchor Row ${excelRow1Based} is outside data rows (1-based row must be > 1 and <= ${rows.length + 1})`);
      continue;
    }
    
    if (imageColIndex !== -1 && a.col !== imageColIndex) {
      console.log(`ℹ️ Image at col ${a.col} doesn't match image column ${imageColIndex}. Fuzzing...`);
      if (Math.abs(a.col - imageColIndex) > 1) {
         continue;
      }
    }
    
    const mediaPath = relsMap[a.relId];
    if (!mediaPath) {
      console.log(`❌ No media path found for RelID ${a.relId} in drawing rels`);
      continue;
    }
    
    const mediaFile = zip.file(mediaPath);
    if (!mediaFile) {
      console.log(`❌ Media file NOT found in ZIP: ${mediaPath}`);
      continue;
    }
    
    console.log(`📥 Extracting media: ${mediaPath} (${mediaFile._data.uncompressedSize} bytes)`);
    const content = await mediaFile.async('nodebuffer');
    const ext = path.extname(mediaPath).toLowerCase() || '.png';
    
    if (!imagesByRow.has(dataIndex)) {
      imagesByRow.set(dataIndex, { buffer: content, ext, mediaPath, excelRow: excelRow1Based });
      console.log(`✅ SUCCESS: Mapped image to data row ${dataIndex}`);
    }
  }

  return { headers, rows, imagesByRow, warnings };
}

module.exports = {
  extractEmbeddedImagesByRow,
  normalizeHeader,
};
