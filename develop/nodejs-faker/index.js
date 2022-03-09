var express = require('express');
var app = express();

app.get('/*', (req, res) => {
    console.log(`${req.protocol} ${req.method} ${req.path}`, req.headers, '\n');
    res.send(req.headers)
});

app.listen(80);
