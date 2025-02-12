import { Module } from '@nestjs/common';
import { AppController } from './app.controller';
import { AppService } from './app.service';
import { MongooseModule } from '@nestjs/mongoose';
import { UserModule } from './user/user.module';
import { UserController } from './user/user.controller';

@Module({
  imports: [MongooseModule.forRoot('mongodb+srv://amiragharbi:amirapassword@cluster0.r9xkn.mongodb.net/'),UserModule],
  providers: [AppService],
  controllers: [AppController,UserController],
})
export class AppModule {}

