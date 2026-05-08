/**
 * JSON response for successful media upload (M5b).
 */
export type MediaUploadResponseDto = {
  url: string;
  mediaType: string;
  originalName: string;
  sizeBytes: number;
  durationSeconds: null;
};
