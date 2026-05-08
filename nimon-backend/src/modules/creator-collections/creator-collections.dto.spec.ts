import { validate } from 'class-validator';

import { CreateCreatorMonoCollectionDto } from './creator-collections.dto';

describe('CreateCreatorMonoCollectionDto', () => {
  it('accepts title', async () => {
    const dto = new CreateCreatorMonoCollectionDto();
    dto.title = 'N1 Collections';
    const errors = await validate(dto);
    expect(errors).toHaveLength(0);
  });

  it('rejects empty title', async () => {
    const dto = new CreateCreatorMonoCollectionDto();
    dto.title = '';
    const errors = await validate(dto);
    expect(errors.length).toBeGreaterThan(0);
  });
});

