import 'dotenv/config';
import express from 'express';
import cors from 'cors';
import helmet from 'helmet';

import { API_VERSION } from '@training-triangle/shared';

import { authRouter } from './routes/auth.js';
import { healthRouter } from './routes/health.js';

const app = express();
const PORT = process.env.PORT ?? 3000;

// Middleware
app.use(helmet());
app.use(cors({ origin: process.env.CORS_ORIGIN ?? '*' }));
app.use(express.json());

// Routes
app.use(`/api/${API_VERSION}/health`, healthRouter);
app.use(`/api/${API_VERSION}/auth`, authRouter);

// Placeholder routes for future phases
// app.use(`/api/${API_VERSION}/courses`, coursesRouter);
// app.use(`/api/${API_VERSION}/trainers`, trainersRouter);
// app.use(`/api/${API_VERSION}/clients`, clientsRouter);
// app.use(`/api/${API_VERSION}/documents`, documentsRouter);

app.listen(PORT, () => {
  console.log(`Training Triangle API running on http://localhost:${PORT}`);
});
