import type { User } from "@prisma/client";

/**
 * Strips `passwordHash` before a User row goes into any API response.
 * Every route that sends a user object back to a client must go through
 * this — see the comment on `User.passwordHash` in schema.prisma.
 */
export function toPublicUser(user: User) {
  const { passwordHash: _passwordHash, pushTokens: _pushTokens, ...publicUser } = user;
  return publicUser;
}
