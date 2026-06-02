const express = require('express');
const mongoose = require('mongoose');

const router = express.Router();

const SERVICE_NAME = 'fusion-electronics-backend';

function getMongoStatus() {
  return mongoose.connection.readyState === 1 ? 'connected' : 'disconnected';
}

router.get('/health', (req, res) => {
  res.status(200).json({
    status: 'ok',
    service: SERVICE_NAME,
  });
});

router.get('/health/ready', (req, res) => {
  const mongodb = getMongoStatus();
  const ready = mongodb === 'connected';

  res.status(ready ? 200 : 503).json({
    status: ready ? 'ready' : 'not_ready',
    service: SERVICE_NAME,
    dependencies: {
      mongodb,
    },
  });
});

module.exports = router;
