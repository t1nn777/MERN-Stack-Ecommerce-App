const express = require('express');
const mongoose = require('mongoose');
const request = require('supertest');

jest.mock('mongoose', () => ({
  connection: {
    readyState: 0,
  },
}));

const healthRouter = require('../routes/health');

describe('Health API', () => {
  let app;

  beforeEach(() => {
    app = express();
    app.use('/', healthRouter);
  });

  afterEach(() => {
    mongoose.connection.readyState = 0;
  });

  it('GET /health returns alive status', async () => {
    const res = await request(app).get('/health');

    expect(res.status).toBe(200);
    expect(res.body).toEqual({
      status: 'ok',
      service: 'fusion-electronics-backend',
    });
  });

  it('GET /health/ready returns ready when MongoDB is connected', async () => {
    mongoose.connection.readyState = 1;

    const res = await request(app).get('/health/ready');

    expect(res.status).toBe(200);
    expect(res.body).toEqual({
      status: 'ready',
      service: 'fusion-electronics-backend',
      dependencies: {
        mongodb: 'connected',
      },
    });
  });

  it('GET /health/ready returns 503 when MongoDB is not connected', async () => {
    mongoose.connection.readyState = 0;

    const res = await request(app).get('/health/ready');

    expect(res.status).toBe(503);
    expect(res.body).toEqual({
      status: 'not_ready',
      service: 'fusion-electronics-backend',
      dependencies: {
        mongodb: 'disconnected',
      },
    });
  });
});
