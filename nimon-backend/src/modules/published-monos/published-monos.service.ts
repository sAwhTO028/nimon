import { Injectable, NotFoundException } from '@nestjs/common';

import { PrismaService } from '../prisma/prisma.service';

import type { PublishedMonoDetailDto, PublishedMonoListResponseDto } from './published-monos.dto';

import { publishedMonoDetailFromRow, publishedMonoListItemFromRow } from './published-mono-common';



const DEFAULT_DEV_OWNER_ID = '00000000-0000-0000-0000-000000000001';



@Injectable()

export class PublishedMonosService {

  constructor(private readonly prisma: PrismaService) {}



  private getDevOwnerId(): string {

    return process.env.DEV_OWNER_ID ?? DEFAULT_DEV_OWNER_ID;

  }



  async listPublishedMonos(limitRaw?: string): Promise<PublishedMonoListResponseDto> {

    const ownerId = this.getDevOwnerId();

    const limitNum = limitRaw ? Number(limitRaw) : 50;

    const take = Number.isFinite(limitNum)

      ? Math.min(Math.max(limitNum, 1), 100)

      : 50;



    const rows = await this.prisma.publishedMono.findMany({

      where: { ownerId },

      orderBy: { updatedAt: 'desc' },

      take,

      select: {

        id: true,

        ownerId: true,

        createdAt: true,

        updatedAt: true,

        title: true,

        category: true,

        level: true,

        description: true,

        content: true,

      },

    });



    const items = rows.map(publishedMonoListItemFromRow);



    return { items, nextCursor: null };

  }



  async getPublishedMonoById(id: string): Promise<PublishedMonoDetailDto> {

    const ownerId = this.getDevOwnerId();

    const m = await this.prisma.publishedMono.findFirst({

      where: { id, ownerId },

      select: {

        id: true,

        ownerId: true,

        createdAt: true,

        updatedAt: true,

        title: true,

        category: true,

        level: true,

        description: true,

        content: true,

      },

    });

    if (!m) {

      throw new NotFoundException('published_mono_not_found');

    }

    return publishedMonoDetailFromRow(m);

  }

}


