const XLSX = require('xlsx');
const JSZip = require('jszip');
const { XMLParser } = require('fast-xml-parser');
const path = require('path');

// Utility: normalize header keys (trim, lowercase)
function normalizeHeader(h) {
  const normalized = String(h || '').trim().toLowerCase();
  
  // Header aliases for common fields
  const aliases = {
    'sku': ['sku', 'item code', 'product code', 'product sku', 's.k.u', 'reference', 'ref'],
    'barcode': ['barcode', 'upc', 'ean', 'bar code', 'qr code', 'code'],
    'name': ['name', 'product name', 'item name', 'title', 'product', 'label'],
    'price': ['price', 'sale price', 'retail price', 'selling price', 'unit price', 'rate'],
    'cost': ['cost', 'cost price', 'purchase price', 'buying price', 'unit cost', 'avg cost'],
    'quantity': ['quantity', 'qty', 'stock', 'stock quantity', 'count', 'amount', 'on hand'],
    'category': ['category', 'department', 'group', 'type', 'cat', 'classification'],
    'description': ['description', 'desc', 'details', 'notes', 'about', 'summary'],
    'wholesale_price': ['wholesale price', 'wholesale', 'trade price', 'bulk price']
  };

  for (const [canonical, list] of Object.entries(aliases)) {
    if (list.includes(normalized)) return canonical;
  }
  
  return normalized;
}

// Read sheet headers and rows; also compute Excel row numbers for each data row
function readSheetRows(workbook, options = {}) {
  let sheetName = workbook.SheetNames[0];
  let ws = workbook.Sheets[sheetName];
  let headerRowIndex = 0;
  
  const targetHeaders = ['name', 'price', 'cost', 'sku', 'barcode'];
  
  // Try to find the best worksheet and header row
  for (const name of workbook.SheetNames) {
    const currentWS = workbook.Sheets[name];
    const rows2D = XLSX.utils.sheet_to_json(currentWS, { header: 1, defval: null, raw: false });
    if (!rows2D || rows2D.length === 0) continue;
    
    let foundHeader = false;
    for (let i = 0; i < Math.min(20, rows2D.length); i++) {
      const hRow = (rows2D[i] || []).map(normalizeHeader);
      const matchCount = hRow.filter(h => targetHeaders.includes(h)).length;
      if (matchCount >= 2) {
        sheetName = name;
        ws = currentWS;
        headerRowIndex = i;
        foundHeader = true;
        break;
      }
    }
    if (foundHeader) break;
  }

  if (!ws) throw new Error('No worksheet found in uploaded Excel');

  const rows2D = XLSX.utils.sheet_to_json(ws, { header: 1, defval: null, raw: false });
  if (!rows2D.length || headerRowIndex >= rows2D.length) {
    return { headers: [], rows: [], rowNumbers: [], ws, sheetName, headerRowIndex: 0 };
  }

  const headerRow = rows2D[headerRowIndex].map(normalizeHeader);
  const dataRows = rows2D.slice(headerRowIndex + 1);

  const rows = dataRows.map(r => {
    const obj = {};
    headerRow.forEach((h, i) => {
      if (!h) return;
      obj[h] = r[i] !== undefined && r[i] !== null ? String(r[i]).trim() : null;
    });
    return obj;
  });

  const rowNumbers = dataRows.map((_, idx) => idx + headerRowIndex + 2); 

  return { headers: headerRow, rows, rowNumbers, ws, sheetName, headerRowIndex };
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
    const xml = await relsFile.async('text');
    const parser = new XMLParser({ ignoreAttributes: false });
    const rels = parser.parse(xml);
    const list = (rels?.Relationships?.Relationship) || [];
    const relationships = Array.isArray(list) ? list : [list];
    const drawingRel = relationships.find(r => r['@_Type'] && r['@_Type'].includes('/relationships/drawing'));
    
    if (drawingRel) {
      const target = drawingRel['@_Target'];
      if (!target) continue;
      
      // Resolve path relative to xl/worksheets/
      let normalized;
      if (target.startsWith('/')) {
        normalized = target.substring(1); // Absolute from zip root
      } else {
        // Resolve relative to the rels folder
        normalized = path.posix.normalize(path.posix.join(path.posix.dirname(relsPath), target));
      }
      
      // Common fix for some Excel producers that use weird relative paths
      if (!zip.file(normalized) && normalized.includes('worksheets/drawings/')) {
        const alt = normalized.replace('worksheets/drawings/', 'drawings/');
        if (zip.file(alt)) normalized = alt;
      }
      if (zip.file(normalized)) return normalized;
    }
  }
  return null;
}

async function parseDrawingAnchors(zip, drawingPath) {
  const file = zip.file(drawingPath);
  if (!file) return { anchors: [], relsMap: {} };
  const xml = await file.async('text');
  const parser = new XMLParser({ 
    ignoreAttributes: false, 
    removeNSPrefix: true,
    attributeNamePrefix: '' 
  });
  const doc = parser.parse(xml);
  
  // Find the actual root content key (skip ?xml, etc.)
  let rootKey = Object.keys(doc).find(k => !k.startsWith('?'));
  // If the root key has a prefix and we don't have a clean wsDr, map it
  if (rootKey && rootKey.includes(':') && !doc.wsDr) {
    const parts = rootKey.split(':');
    const localName = parts[parts.length - 1];
    if (localName === 'wsDr') {
      doc.wsDr = doc[rootKey];
      rootKey = 'wsDr';
    }
  }

  const anchors = [];
  const wsDr = rootKey ? doc[rootKey] : null;
  if (!wsDr) return { anchors: [], relsMap: {} };

  // Helper to get array regardless of prefix
  const getAnchorArray = (obj, baseName) => {
    const key = Object.keys(obj).find(k => k === baseName || k.endsWith(':' + baseName));
    const val = key ? obj[key] : [];
    return Array.isArray(val) ? val : [val];
  };

  const all = [
    ...getAnchorArray(wsDr, 'twoCellAnchor'),
    ...getAnchorArray(wsDr, 'oneCellAnchor'),
    ...getAnchorArray(wsDr, 'absoluteAnchor')
  ].filter(Boolean);
  if (all.length > 0) {
  }

  // If no anchors found, fuzzy search for anything containing "Anchor"
  if (all.length === 0) {
    for (const key in wsDr) {
      if (key.toLowerCase().includes('anchor')) {
        const found = Array.isArray(wsDr[key]) ? wsDr[key] : [wsDr[key]];
        all.push(...found.filter(Boolean));
      }
    }
  }

  for (const a of all) {
    // Try to find 'from' and 'pic' elements anywhere in the anchor object
    // to handle variations in nesting or naming
    let from = a.from || a['xdr:from'];
    let pic = a.pic || a['xdr:pic'];
    
    // Recursive search for 'from' if not found
    if (!from) {
      const findKey = (obj, target) => {
        if (!obj || typeof obj !== 'object') return null;
        if (obj[target]) return obj[target];
        for (const k in obj) {
          const res = findKey(obj[k], target);
          if (res) return res;
        }
        return null;
      };
      from = findKey(a, 'from') || findKey(a, 'xdr:from');
    }

    // Recursive search for 'pic' if not found
    if (!pic) {
      const findPic = (obj) => {
        if (!obj || typeof obj !== 'object') return null;
        if (obj.pic || obj['xdr:pic']) return obj.pic || obj['xdr:pic'];
        if (obj.graphic?.graphicData?.pic) return obj.graphic.graphicData.pic;
        for (const k in obj) {
          const res = findPic(obj[k]);
          if (res) return res;
        }
        return null;
      };
      pic = findPic(a);
    }
    
    if (!from) {
      continue;
    }
    
    if (!pic) {
      continue;
    }
    
    const row = parseInt(from.row ?? from['xdr:row'] ?? 0, 10);
    const col = parseInt(from.col ?? from['xdr:col'] ?? 0, 10);
    
    // Find the blip element
    const findBlip = (obj) => {
      if (!obj || typeof obj !== 'object') return null;
      if (obj.blipFill?.blip) return obj.blipFill.blip;
      if (obj['a:blipFill']?.['a:blip']) return obj['a:blipFill']['a:blip'];
      for (const k in obj) {
        const res = findBlip(obj[k]);
        if (res) return res;
      }
      return null;
    };

    const blip = findBlip(pic);
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
    }
  }

  // Parse DRAWING RELS
  const relsMap = {};
  const standardRelsPath = drawingPath.replace(/([^/]+)\.xml$/, '_rels/$1.xml.rels');
  let relsFile = zip.file(standardRelsPath);
  
  if (!relsFile) {
    const drawingFileName = path.posix.basename(drawingPath);
    const relsSearch = Object.keys(zip.files).find(f => f.includes('_rels') && f.includes(drawingFileName) && f.endsWith('.rels'));
    if (relsSearch) {
      relsFile = zip.file(relsSearch);
    }
  }

  if (relsFile) {
    const relsXml = await relsFile.async('text');
    const relsParser = new XMLParser({ ignoreAttributes: false });
    const relsDoc = relsParser.parse(relsXml);
    const relsList = relsDoc?.Relationships?.Relationship || [];
    const arr = Array.isArray(relsList) ? relsList : [relsList];
    
    for (const r of arr) {
      const id = r['@_Id'] || r.Id || r['r:id'] || r['@_r:id'];
      const target = r['@_Target'] || r.Target || r['@_r:Target'];
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
  }

  return { anchors, relsMap };
}

async function extractEmbeddedImagesByRow(buffer, options = {}) {
  const workbook = XLSX.read(buffer, { type: 'buffer' });
  const { headers, rows, rowNumbers, sheetName, headerRowIndex } = readSheetRows(workbook, options);
  if (!rows.length) {
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
        break;
      }
    }
  }
  const zip = await JSZip.loadAsync(buffer);
  
  const sheetIndex = getSheetIndexFromName(workbook, sheetName);
  let drawingPath = await findDrawingPathForSheet(zip, sheetIndex);
  
  if (!drawingPath) {
    // Try to find ANY drawing file as a fallback
    const allFiles = Object.keys(zip.files);
    drawingPath = allFiles.find(f => f.startsWith('xl/drawings/drawing') && f.endsWith('.xml'));
    if (drawingPath) {
    }
  }

  const warnings = [];
  if (!drawingPath) {
    warnings.push('No drawing part found in worksheet; embedded images may be missing');
    return { headers, rows, imagesByRow: new Map(), warnings };
  }
  // DEBUG: Log ZIP structure if needed
  const allZipFiles = Object.keys(zip.files);
  const drawingRelsSearch = allZipFiles.filter(f => f.includes('drawing') && f.includes('.rels'));
  const { anchors, relsMap } = await parseDrawingAnchors(zip, drawingPath);
  const imagesByRow = new Map();

  for (const a of anchors) {
    const excelRow1Based = a.row + 1;
    const dataIndex = a.row - (headerRowIndex + 1);
    if (dataIndex < 0 || dataIndex >= rows.length) {
      continue;
    }
    
    // If we have multiple images on the same row, the first one found wins
    if (imagesByRow.has(dataIndex)) continue;
    
    const mediaPath = relsMap[a.relId];
    if (!mediaPath) {
      continue;
    }
    
    const mediaFile = zip.file(mediaPath);
    if (!mediaFile) {
      continue;
    }
    const content = await mediaFile.async('nodebuffer');
    const ext = path.extname(mediaPath).toLowerCase() || '.png';
    
    if (!imagesByRow.has(dataIndex)) {
      imagesByRow.set(dataIndex, { buffer: content, ext, mediaPath, excelRow: excelRow1Based });
    }
  }

  return { headers, rows, imagesByRow, warnings };
}

module.exports = {
  extractEmbeddedImagesByRow,
  normalizeHeader,
};

