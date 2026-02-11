import { Router } from 'express';

export const authRouter = Router();

// Placeholder: OAuth, 2FA, JWT implementation in Phase 1
authRouter.post('/login', (_req, res) => {
  res.status(501).json({ message: 'Auth endpoint - Phase 1 implementation' });
});

authRouter.post('/register', (_req, res) => {
  res.status(501).json({ message: 'Auth endpoint - Phase 1 implementation' });
});
