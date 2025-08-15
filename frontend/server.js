const express = require('express');
const cors = require('cors');
const path = require('path');

const app = express();
const PORT = process.env.PORT || 3000;

// Enable CORS
app.use(cors());

// Serve static files from the build/web directory
app.use(express.static(path.join(__dirname, 'build', 'web')));

// Handle all routes by serving index.html (for Flutter routing)
app.get('*', (req, res) => {
  res.sendFile(path.join(__dirname, 'build', 'web', 'index.html'));
});

app.listen(PORT, () => {
  console.log(`🚀 Flutter Frontend Server running on port ${PORT}`);
  console.log(`🌐 Access your app at: http://localhost:${PORT}`);
});
