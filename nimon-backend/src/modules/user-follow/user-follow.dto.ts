export type FollowStateDto = {
  userId: string;
  isFollowing: boolean;
  followersCount: number;
  followingCount: number;
};

export type MeFollowingListItemDto = {
  userId: string;
  handle: string | null;
  displayName: string | null;
  avatarUrl: string | null;
  followedAt: string;
};

export type MeFollowingListResponseDto = {
  items: MeFollowingListItemDto[];
  nextCursor: string | null;
  hasMore: boolean;
};

/** Same envelope as [MeFollowingListResponseDto] — used by GET /v1/users/:userId/followers. */
export type UserFollowersListResponseDto = MeFollowingListResponseDto;

