const XLSX = require('xlsx');
const JSZip = require('jszip');
const { XMLParser } = require('fast-xml-parser');
const fs = require('fs');
const path = require('path');

async function debugExcel(filePath) {
    console.log(`Reading ${filePath}...`);
    const buffer = fs.readFileSync(filePath);
    const zip = await JSZip.loadAsync(buffer);
    
    // 1. Check workbook rels to find sheets
    const workbookRels = await zip.file('xl/_rels/workbook.xml.rels').async('text');
    console.log('\n--- Workbook Rels ---');
    console.log(workbookRels);

    // 2. Find sheet 1 rels
    const sheetRelsPath = 'xl/worksheets/_rels/sheet1.xml.rels';
    const sheetRelsFile = zip.file(sheetRelsPath);
    if (sheetRelsFile) {
        const sheetRels = await sheetRelsFile.async('text');
        console.log(`\n--- Sheet 1 Rels (${sheetRelsPath}) ---`);
        console.log(sheetRels);
    } else {
        console.log(`\n--- Sheet 1 Rels NOT FOUND at ${sheetRelsPath} ---`);
        // List all rels
        const allRels = Object.keys(zip.files).filter(f => f.includes('_rels/sheet'));
        console.log('Available sheet rels:', allRels);
    }

    // 3. Look for drawings
    const drawingFiles = Object.keys(zip.files).filter(f => f.includes('drawing') && f.endsWith('.xml'));
    console.log('\n--- Drawing Files ---');
    console.log(drawingFiles);

    for (const df of drawingFiles) {
        const content = await zip.file(df).async('text');
        console.log(`\n--- Content of ${df} (first 1000 chars) ---`);
        console.log(content.substring(0, 1000));
        
        // Parse and log keys
        const parser = new XMLParser({ ignoreAttributes: false, removeNSPrefix: true });
        const doc = parser.parse(content);
        const root = Object.keys(doc)[0];
        console.log(`Root: ${root}, Keys: ${Object.keys(doc[root] || {}).join(', ')}`);
        
        // Check for rels of this drawing
        const drelsPath = `${path.posix.dirname(df)}/_rels/${path.posix.basename(df)}.rels`;
        const drelsFile = zip.file(drelsPath);
        if (drelsFile) {
            console.log(`\n--- Drawing Rels (${drelsPath}) ---`);
            console.log(await drelsFile.async('text'));
        }
    }
}

const target = process.argv[2] || 'Shaam 5.xlsx';
debugExcel(target).catch(console.error);
