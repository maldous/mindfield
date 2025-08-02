import { Module } from "@nestjs/common";
import { LoggerModule } from "nestjs-pino";

@Module({
    imports: [
        LoggerModule.forRoot({
            pinoHttp: {
                level: process.env.LOG_LEVEL ?? "info",
            },
        }),
    ],
})
export class AppModule {}
