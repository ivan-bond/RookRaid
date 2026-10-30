'use strict';
// Rook-Raid-Regeln in JavaScript für Node: lädt RookRaid/Engine/rookraid-rules.json und reicht den Kern (core.js) durch.
// Für den Server (Deno) gibt es das Bündel aus build-server.js – dort kommen die Regeln aus der Tabelle rules_config.
const fs = require('fs');
const path = require('path');
const core = require('./core');

const RULES_FILE = path.join(__dirname, '..', '..', 'RookRaid', 'Engine', 'rookraid-rules.json');

function loadRules(file = RULES_FILE) {
  return core.applyRules(JSON.parse(fs.readFileSync(file, 'utf8')));
}

module.exports = { ...core, loadRules };
