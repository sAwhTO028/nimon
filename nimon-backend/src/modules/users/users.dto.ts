export type PublicCreatorProfileResponseDto = {
  userId: string;
  handle: string | null;
  displayName: string | null;
  avatarUrl: string | null;
  coverImageUrl: string | null;
  bio: string | null;
  followersCount: number;
  followingCount: number;
  isFollowingByMe: boolean;
};

