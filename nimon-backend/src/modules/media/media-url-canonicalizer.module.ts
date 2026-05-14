import { Module } from '@nestjs/common';

import { MediaUrlCanonicalizerService } from './media-url-canonicalizer.service';

@Module({
  providers: [MediaUrlCanonicalizerService],
  exports: [MediaUrlCanonicalizerService],
})
export class MediaUrlCanonicalizerModule {}
