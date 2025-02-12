import { NestFactory } from '@nestjs/core';
import { AppModule } from './app.module';

async function bootstrap() {
  // Créez l'application NestJS
  const app = await NestFactory.create(AppModule);
  
  // Activez CORS pour permettre les requêtes d'autres origines
  app.enableCors();

  // Écoutez sur le port spécifié ou sur le port 3000 par défaut
  await app.listen(process.env.PORT ?? 3000);
}

// Démarrez l'application
bootstrap();