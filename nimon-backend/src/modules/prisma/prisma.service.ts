import { Injectable, Logger, OnModuleInit } from '@nestjs/common';
import { PrismaClient } from '@prisma/client';
import { PrismaPg } from '@prisma/adapter-pg';

import { parseDatabaseUrlForM17e9Log } from '../../common/database-url-safe-log';

@Injectable()
export class PrismaService extends PrismaClient implements OnModuleInit {
  private readonly logger = new Logger(PrismaService.name);

  constructor() {
    const connectionString =
      process.env.DATABASE_URL ??
      'postgresql://nimon:nimon@localhost:5432/nimon?schema=public';

    const adapter = new PrismaPg({ connectionString });

    super({ adapter });
  }

  async onModuleInit() {
    const cs =
      process.env.DATABASE_URL ??
      'postgresql://nimon:nimon@localhost:5432/nimon?schema=public';
    const { host, database } = parseDatabaseUrlForM17e9Log(cs);
    this.logger.log(`[M17E-9 db-target] host=${host} database=${database}`);
    await this.$connect();
  }
}

