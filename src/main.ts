import * as dotenv from 'dotenv';
dotenv.config();

import { NestFactory } from '@nestjs/core';
import { AppModule } from './app.module';
import { IoAdapter } from '@nestjs/platform-socket.io';
import * as bodyParser from 'body-parser';
import { SwaggerModule, DocumentBuilder } from '@nestjs/swagger';

// ⬇️ pour exposer /uploads
import * as express from 'express';
import { join } from 'path';

async function bootstrap() {
  const app = await NestFactory.create(AppModule);
  console.log('✅ Starting NestJS Server...');

  // payload limits
  app.use(bodyParser.json({ limit: '10mb' }));
  app.use(bodyParser.urlencoded({ limit: '10mb', extended: true }));
  app.useWebSocketAdapter(new IoAdapter(app));

  // CORS (OK pour images /uploads en GET)
  app.enableCors({
    origin: '*',
    methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
    allowedHeaders: ['Content-Type', 'Authorization'],
    credentials: false,
  });

  // ⬇️ REND LES FICHIERS D'UPLOAD ACCESSIBLES : http://<host>:3000/uploads/<fileName>
  const uploadsPath = join(process.cwd(), 'uploads');
  app.use('/uploads', express.static(uploadsPath));
  console.log('📁 Serving /uploads from:', uploadsPath);

  // Swagger
  const config = new DocumentBuilder()
      .setTitle('NestJS API Documentation')
      .setDescription('API endpoints for the project')
      .setVersion('1.0')
      .addBearerAuth()
      .build();

  const document = SwaggerModule.createDocument(app, config);
  SwaggerModule.setup('api', app, document);

  const PORT = Number(process.env.PORT) || 3000;
  await app.listen(PORT, '0.0.0.0');

  console.log(`✅ Serveur en cours d'exécution sur http://localhost:${PORT}`);
  console.log(`📘 Swagger disponible sur http://localhost:${PORT}/api`);
  console.log(`🖼️ Images accessibles sur http://localhost:${PORT}/uploads/<fileName>`);
}

bootstrap();
