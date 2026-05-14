import { Module } from '@nestjs/common';

import { PublicWebBaseUrlService } from './public-web-base-url.service';

@Module({
  providers: [PublicWebBaseUrlService],
  exports: [PublicWebBaseUrlService],
})
export class PublicWebBaseUrlModule {}
