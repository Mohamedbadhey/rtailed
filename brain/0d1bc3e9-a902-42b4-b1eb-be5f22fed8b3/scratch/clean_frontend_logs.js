const fs = require('fs');
const path = require('path');

function walk(dir) {
    let results = [];
    if (!fs.existsSync(dir)) return results;
    const list = fs.readdirSync(dir);
    list.forEach(file => {
        const fullPath = path.join(dir, file);
        const stat = fs.statSync(fullPath);
        if (stat && stat.isDirectory()) {
            results = results.concat(walk(fullPath));
        } else if (file.endsWith('.dart')) {
            results.push(fullPath);
        }
    });
    return results;
}

const baseDir = 'c:/Users/hp/Documents/rtail/frontend/lib';
const files = walk(baseDir);

let cleanedCount = 0;
files.forEach(file => {
    try {
        let content = fs.readFileSync(file, 'utf8');
        // Match print(...) or debugPrint(...)
        // Requirement: Must be at start of line or after whitespace to avoid qz.print
        const regex = /(^|\s)(print|debugPrint)\([\s\S]*?\);(\s*[\r\n]+)?/gm;
        const newContent = content.replace(regex, '$1');
        
        if (content !== newContent) {
            fs.writeFileSync(file, newContent);
            cleanedCount++;
        }
    } catch (e) {
        console.error(`Error processing ${file}: ${e.message}`);
    }
});

console.log(`Successfully cleaned ${cleanedCount} files.`);
